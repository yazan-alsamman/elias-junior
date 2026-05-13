/**
 * FastAPI ATS bridge for uploaded CV files.
 *
 * Expects FastAPI endpoint:
 *   POST {ATS_FASTAPI_URL}/ats-format/check (multipart field: "file")
 * Response shape:
 *   { decision, failed_basic, failed_rules_count, recommendation, failures, ... }
 */

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

function mapFastapiDecisionToInternal(report, fileName) {
  const decision = String(report?.decision || 'FAIL').toUpperCase();
  const failedBasic = Boolean(report?.failed_basic);
  const failedRulesCount = toInt(report?.failed_rules_count, 0);
  const failures = Array.isArray(report?.failures) ? report.failures : [];
  const improvementBullets = Array.isArray(report?.recommendation?.improvements)
    ? report.recommendation.improvements
    : [];

  const uniqueFixes = [...new Set(improvementBullets.concat(failures.map((f) => f?.fix).filter(Boolean)))];
  const issues = failures.map((f) => f?.issue).filter(Boolean);

  let score;
  if (decision === 'PASS') {
    score = 90;
  } else if (failedBasic) {
    score = clamp(65 - failedRulesCount * 8, 15, 64);
  } else {
    score = clamp(78 - failedRulesCount * 6, 35, 77);
  }

  return {
    score,
    status: decision === 'PASS' ? 'Optimized' : 'Parsed',
    extractedTextLength: 0,
    keywordsChecked: clamp(12 + (decision === 'PASS' ? 18 : Math.max(0, 18 - failedRulesCount * 2)), 0, 48),
    keywordsTotal: 48,
    formatScore: decision === 'PASS' ? 92 : clamp(82 - failedRulesCount * 9, 20, 90),
    sectionMatch: decision === 'PASS' ? '6/6' : `${clamp(6 - failedRulesCount, 2, 5)}/6`,
    estimatedSecondsLeft: 0,
    missingKeywords: issues.slice(0, 6),
    recommendationBullets:
      uniqueFixes.length > 0
        ? uniqueFixes.slice(0, 6)
        : ['Use ATS-friendly layout: single column, clear section headings, and plain text contact info.'],
    suitabilityHeadline:
      decision === 'PASS'
        ? 'ATS format check passed'
        : failedBasic
          ? 'Critical ATS format issues found'
          : 'ATS check found improvements',
    issuesSummary: `FastAPI ATS (${fileName}) — ${decision} (${failedRulesCount} failed rules)`,
    severity: decision === 'PASS' ? 'low' : failedBasic ? 'high' : 'medium',
    canAutoFix: false,
    autoFixApplied: false,
    failureReason: issues.join(' | '),
    templateId: 'fastapi-ats-format-v1',
  };
}

async function analyzeCvFileViaFastapi({ fileBuffer, fileName }) {
  const base = process.env.ATS_FASTAPI_URL?.trim();
  if (!base) {
    throw new Error('ATS_FASTAPI_URL is not set on backend');
  }

  const timeoutMs = toInt(process.env.ATS_FASTAPI_TIMEOUT_MS, 20000);
  const url = joinUrl(base, '/ats-format/check');

  const form = new FormData();
  const blob = new Blob([fileBuffer], {
    type: fileName.toLowerCase().endsWith('.pdf')
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  });
  form.append('file', blob, fileName);

  const token = process.env.ATS_FASTAPI_BEARER_TOKEN?.trim();
  const headers = token ? { Authorization: `Bearer ${token}` } : {};

  const controller = new AbortController();
  const tid = setTimeout(() => controller.abort(), timeoutMs);

  let res;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers,
      body: form,
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(tid);
    const msg = err?.name === 'AbortError' ? `timeout after ${timeoutMs}ms` : err?.message;
    throw new Error(`FastAPI request failed: ${msg}`);
  }
  clearTimeout(tid);

  let json;
  try {
    json = await res.json();
  } catch (_e) {
    throw new Error(`FastAPI returned non-JSON response (HTTP ${res.status})`);
  }

  if (!res.ok) {
    throw new Error(`FastAPI error HTTP ${res.status}: ${JSON.stringify(json).slice(0, 220)}`);
  }

  return mapFastapiDecisionToInternal(json, fileName);
}

module.exports = {
  analyzeCvFileViaFastapi,
};

