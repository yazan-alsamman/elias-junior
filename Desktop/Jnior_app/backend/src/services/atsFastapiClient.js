/**
 * FastAPI ATS bridge for uploaded CV files.
 *
 *   POST {ATS_FASTAPI_URL}/ats-format/check (multipart field: "file")
 */

const http = require('http');
const https = require('https');
const { URL } = require('url');
const FormData = require('form-data');

function toInt(n, fallback = 0) {
  const v = Number(n);
  return Number.isFinite(v) ? Math.round(v) : fallback;
}

function clamp(n, lo, hi) {
  return Math.min(hi, Math.max(lo, n));
}

function joinUrl(base, path) {
  const b = String(base || '').trim().replace(/\/+$/, '');
  const p = String(path || '').trim();
  const q = p.startsWith('/') ? p : `/${p}`;
  return `${b}${q}`;
}

function mimeForFileName(fileName) {
  return String(fileName || '').toLowerCase().endsWith('.pdf')
    ? 'application/pdf'
    : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
}

function normalizeFailures(report) {
  const failures = Array.isArray(report?.failures) ? report.failures : [];
  return failures
    .map((f) => ({
      ruleId: String(f?.rule_id || f?.ruleId || '').trim(),
      severity: String(f?.severity || '').trim(),
      issue: String(f?.issue || '').trim(),
      fix: String(f?.fix || '').trim(),
    }))
    .filter((f) => f.issue || f.fix);
}

/**
 * Map real Uvicorn ATS JSON → fields stored in Mongo + sent to the Flutter app.
 * Score = format-rule compliance (100 when PASS).
 */
function mapFastapiDecisionToInternal(report, fileName) {
  const decision = String(report?.decision || 'FAIL').toUpperCase();
  const failedBasic = Boolean(report?.failed_basic);
  const failedRulesCount = toInt(report?.failed_rules_count, 0);
  const failures = normalizeFailures(report);
  const recommendation =
    report?.recommendation && typeof report.recommendation === 'object'
      ? report.recommendation
      : {};
  const improvementBullets = Array.isArray(recommendation.improvements)
    ? recommendation.improvements.map((s) => String(s).trim()).filter(Boolean)
    : [];
  const uniqueFixes = [
    ...new Set(
      improvementBullets.concat(failures.map((f) => f.fix).filter(Boolean)),
    ),
  ];
  const issues = failures.map((f) => f.issue).filter(Boolean);

  const score =
    decision === 'PASS'
      ? 100
      : clamp(100 - failedRulesCount * 10 - (failedBasic ? 25 : 0), 5, 99);

  const PASS_SCORE_THRESHOLD = 70;
  const scoreDecision = score > PASS_SCORE_THRESHOLD ? 'PASS' : 'FAIL';

  return {
    score,
    status: scoreDecision,
    extractedTextLength: 0,
    keywordsChecked: failedRulesCount,
    keywordsTotal: failedRulesCount + (scoreDecision === 'PASS' ? 0 : 1),
    formatScore: score,
    sectionMatch:
      scoreDecision === 'PASS'
        ? 'All format rules passed'
        : `${failedRulesCount} format rule${failedRulesCount === 1 ? '' : 's'} failed`,
    estimatedSecondsLeft: 0,
    missingKeywords: issues.slice(0, 12),
    recommendationBullets:
      uniqueFixes.length > 0
        ? uniqueFixes.slice(0, 8)
        : [
            String(recommendation.message || '').trim() ||
              'Review ATS format rules for your CV file.',
          ],
    suitabilityHeadline:
      String(recommendation.message || '').trim() ||
      (scoreDecision === 'PASS'
        ? 'ATS format check passed'
        : failedBasic
          ? 'Critical ATS format issues found'
          : 'ATS format check found issues to fix'),
    issuesSummary: `Uvicorn ATS (${fileName}) — ${decision}, ${failedRulesCount} failed rule(s)`,
    severity: scoreDecision === 'PASS' ? 'low' : failedBasic ? 'high' : 'medium',
    canAutoFix: false,
    autoFixApplied: false,
    failureReason: issues.join(' | '),
    templateId: 'fastapi-ats-format-v1',
    engine: 'fastapi-ats-format-v1',
    decision: scoreDecision,
    failedRulesCount,
    failedBasic,
    failures,
  };
}

/** Quick ping so logs show whether ATS is reachable before upload. */
async function pingAtsFastapi() {
  const base = process.env.ATS_FASTAPI_URL?.trim();
  if (!base) {
    return { ok: false, reason: 'ATS_FASTAPI_URL not set' };
  }
  const url = joinUrl(base, '/');
  const timeoutMs = toInt(process.env.ATS_FASTAPI_TIMEOUT_MS, 20000);
  const controller = new AbortController();
  const tid = setTimeout(() => controller.abort(), Math.min(timeoutMs, 8000));
  try {
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(tid);
    if (!res.ok) {
      return { ok: false, reason: `HTTP ${res.status} from ${url}` };
    }
    return { ok: true, url };
  } catch (err) {
    clearTimeout(tid);
    return { ok: false, reason: err?.message || 'unreachable' };
  }
}

function postMultipart(urlString, form, extraHeaders, timeoutMs) {
  return new Promise((resolve, reject) => {
    const target = new URL(urlString);
    const lib = target.protocol === 'https:' ? https : http;
    const headers = { ...form.getHeaders(), ...extraHeaders };

    const req = lib.request(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port || (target.protocol === 'https:' ? 443 : 80),
        path: `${target.pathname}${target.search}`,
        method: 'POST',
        headers,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          resolve({
            status: res.statusCode || 0,
            headers: res.headers,
            body: Buffer.concat(chunks).toString('utf8'),
          });
        });
      },
    );

    req.on('error', reject);
    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error(`timeout after ${timeoutMs}ms`));
    });
    form.pipe(req);
  });
}

async function analyzeCvFileViaFastapi({ fileBuffer, fileName }) {
  const base = process.env.ATS_FASTAPI_URL?.trim();
  if (!base) {
    throw new Error('ATS_FASTAPI_URL is not set on backend');
  }

  const timeoutMs = toInt(process.env.ATS_FASTAPI_TIMEOUT_MS, 20000);
  const url = joinUrl(base, '/ats-format/check');

  const form = new FormData();
  form.append('file', fileBuffer, {
    filename: fileName,
    contentType: mimeForFileName(fileName),
  });

  const token = process.env.ATS_FASTAPI_BEARER_TOKEN?.trim();
  const extraHeaders = {
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'CareerPath-Backend/1.0',
  };
  if (token) {
    extraHeaders.Authorization = `Bearer ${token}`;
  }

  let res;
  try {
    res = await postMultipart(url, form, extraHeaders, timeoutMs);
  } catch (err) {
    throw new Error(`FastAPI request failed (${url}): ${err?.message || err}`);
  }

  const contentType = String(res.headers['content-type'] || '');
  let json;
  if (contentType.includes('application/json')) {
    try {
      json = JSON.parse(res.body);
    } catch (_e) {
      throw new Error(`FastAPI returned invalid JSON (HTTP ${res.status})`);
    }
  } else {
    throw new Error(
      `FastAPI returned non-JSON (HTTP ${res.status}): ${res.body.slice(0, 200)}`,
    );
  }

  if (res.status < 200 || res.status >= 300) {
    throw new Error(
      `FastAPI error HTTP ${res.status}: ${JSON.stringify(json).slice(0, 220)}`,
    );
  }

  if (!json || typeof json.decision !== 'string') {
    throw new Error(
      `FastAPI JSON missing "decision" field — got: ${JSON.stringify(json).slice(0, 120)}`,
    );
  }

  return mapFastapiDecisionToInternal(json, fileName);
}

module.exports = {
  analyzeCvFileViaFastapi,
  mapFastapiDecisionToInternal,
  pingAtsFastapi,
};
