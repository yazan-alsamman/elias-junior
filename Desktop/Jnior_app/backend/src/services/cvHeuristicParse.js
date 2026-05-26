/**
 * "Cheat" CV parser: extract plain text from PDF/DOCX, then regex/section heuristics
 * → portfolio JSON (same shape as Llama parser / make_portfolio_json).
 *
 * Use when CV_PARSER_URL (Llama) is unavailable.
 */

const { extractTextFromUpload } = require('./cvTextExtract');
const { isPortfolioShape } = require('./parsedCvStore');

const EMAIL_RE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;
const PHONE_RE = /(\+?\d[\d\s().-]{6,}\d)/;
const SEP_LINE_RE = /^[-_=]{4,}$/;

const SECTION_ENDS = [
  'education',
  'academic',
  'experience',
  'work history',
  'employment',
  'professional experience',
  'projects',
  'project',
  'certifications',
  'languages',
  'volunteering',
  'summary',
  'professional summary',
  'references',
];

function cleanLine(s) {
  return String(s || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function sliceSection(text, headers, endHeaders = SECTION_ENDS) {
  const lines = text.split(/\r?\n/);
  let start = -1;
  const headerLow = headers.map((h) => h.toLowerCase());

  for (let i = 0; i < lines.length; i++) {
    const line = cleanLine(lines[i]);
    const low = line.toLowerCase();
    if (!line) continue;
    if (SEP_LINE_RE.test(line)) continue;
    for (const h of headerLow) {
      if (low === h || low.startsWith(`${h}:`) || low.startsWith(`${h} `)) {
        start = i + 1;
        break;
      }
    }
    if (start >= 0) break;
  }
  if (start < 0) return '';

  const out = [];
  for (let i = start; i < lines.length; i++) {
    const line = cleanLine(lines[i]);
    if (!line) {
      out.push('');
      continue;
    }
    if (SEP_LINE_RE.test(line)) continue;
    const low = line.toLowerCase();
    let isEnd = false;
    for (const end of endHeaders) {
      if (low === end || low.startsWith(`${end}:`) || low.startsWith(`${end} `)) {
        isEnd = true;
        break;
      }
    }
    if (isEnd && out.length > 0) break;
    out.push(line);
  }
  return out.join('\n').trim();
}

function guessName(text) {
  for (const line of text.split(/\r?\n/).slice(0, 8)) {
    const t = cleanLine(line);
    if (!t || t.length > 80) continue;
    if (EMAIL_RE.test(t) || PHONE_RE.test(t)) continue;
    if (/^(email|phone|location|linkedin|github)\s*:/i.test(t)) continue;
    if (/^[A-Z][A-Z\s.'-]{2,}$/.test(t)) return t;
    if (/^[A-Z][a-z]+(\s+[A-Z][a-z'.-]+)+$/.test(t)) return t;
  }
  return '';
}

function extractContact(text) {
  const emailM = text.match(EMAIL_RE);
  let phone = '';
  for (const line of text.split(/\r?\n/).slice(0, 25)) {
    if (/\b(phone|mobile|tel)\b/i.test(line)) {
      const m = line.match(PHONE_RE);
      if (m) {
        phone = m[1].trim();
        break;
      }
    }
  }
  if (!phone) {
    const m = text.match(PHONE_RE);
    if (m) phone = m[1].trim();
  }
  let location = '';
  const locM = text.match(/^\s*location\s*:\s*(.+)$/im);
  if (locM) location = cleanLine(locM[1]);

  return {
    name: guessName(text),
    email: emailM ? emailM[0].trim() : '',
    phone,
    location,
  };
}

function extractSkills(text) {
  let block = sliceSection(
    text,
    ['technical skills', 'core skills', 'key skills', 'skills & tools', 'skills', 'competencies'],
    SECTION_ENDS,
  );
  if (!block) {
    const m = text.match(
      /(?:technical\s+)?skills?\s*:\s*(.+?)(?:\n\s*\n|\n\s*(?:education|experience)\b)/is,
    );
    if (m) block = m[1];
  }
  if (!block) return [];

  const parts = [];
  for (const line of block.split(/\r?\n/)) {
    const t = cleanLine(line);
    if (!t || SEP_LINE_RE.test(t)) continue;
    const chunk = t.includes(':') && !/^https?:/i.test(t) ? t.split(':').slice(1).join(':') : t;
    for (const p of chunk.split(/[,;|•/]+/)) {
      const s = cleanLine(p);
      if (s.length > 1 && s.length < 80) parts.push(s);
    }
  }
  const seen = new Set();
  return parts.filter((s) => {
    const k = s.toLowerCase();
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  }).slice(0, 40);
}

function extractSummary(text) {
  const block = sliceSection(
    text,
    ['professional summary', 'summary', 'profile', 'about me', 'objective'],
    SECTION_ENDS,
  );
  if (!block) return '';
  return block
    .split(/\r?\n/)
    .map(cleanLine)
    .filter(Boolean)
    .join(' ')
    .slice(0, 1200);
}

function extractExperience(text) {
  const block = sliceSection(
    text,
    [
      'experience',
      'work experience',
      'professional experience',
      'work history',
      'employment',
      'career history',
    ],
    [
      'education',
      'academic',
      'projects',
      'certifications',
      'languages',
      'volunteering',
      'skills',
      'technical skills',
      'summary',
      'professional summary',
    ],
  );
  if (!block) return [];

  const jobRe = /^(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+)$/;
  const items = [];
  let current = null;
  let bullets = [];

  const flush = () => {
    if (current) {
      current.description = bullets.join(' ').trim();
      items.push(current);
      current = null;
      bullets = [];
    }
  };

  for (const raw of block.split(/\r?\n/)) {
    const line = cleanLine(raw);
    if (!line) continue;
    const jm = line.match(jobRe);
    if (jm) {
      flush();
      const [, position, company, loc, period] = jm.map((x) => x.trim());
      const periodOut =
        /^(remote|hybrid)$/i.test(loc) ? `${period} (${loc})` : `${period} · ${loc}`;
      current = {
        company,
        position,
        role: position,
        period: periodOut,
        description: '',
      };
      bullets = [];
    } else if (current) {
      if (/^[•\-–*]/.test(line) || /^\d+[\).]/.test(line)) {
        bullets.push(line.replace(/^[•\-–*\d\).]+\s*/, '').trim());
      } else if (bullets.length) {
        bullets[bullets.length - 1] = `${bullets[bullets.length - 1]} ${line}`.trim();
      } else {
        bullets.push(line);
      }
    }
  }
  flush();
  return items.slice(0, 12);
}

function extractEducation(text) {
  const block = sliceSection(
    text,
    ['education', 'academic background', 'qualifications'],
    [
      'experience',
      'work',
      'projects',
      'skills',
      'languages',
      'certifications',
      'volunteering',
      'summary',
    ],
  );
  if (!block) return [];

  const lineRe = /^(.+?)\s*\|\s*(.+?)(?:\s*\|\s*(.+?))?(?:\s*\|\s*(.+))?$/;
  const items = [];
  for (const raw of block.split(/\r?\n/)) {
    const line = cleanLine(raw);
    if (!line || SEP_LINE_RE.test(line)) continue;
    const m = line.match(lineRe);
    if (m) {
      const degree = cleanLine(m[1]);
      const school = cleanLine(m[2]);
      const extra = [m[3], m[4]].filter(Boolean).map(cleanLine).join(' ');
      items.push({
        degree,
        school,
        major: degree,
        period: extra,
      });
    } else if (items.length) {
      const last = items[items.length - 1];
      last.period = `${last.period} ${line}`.trim();
    } else {
      items.push({ degree: line, school: '', major: '', period: '' });
    }
  }
  return items.slice(0, 8);
}

function extractProjects(text) {
  const block = sliceSection(
    text,
    ['projects & open source', 'projects', 'personal projects', 'open source'],
    SECTION_ENDS,
  );
  if (!block) return [];
  const projects = [];
  for (const raw of block.split(/\r?\n/)) {
    const line = cleanLine(raw);
    if (!line) continue;
    if (/^[•\-–*]/.test(line)) {
      projects.push({
        name: line.replace(/^[•\-–*\d\).]+\s*/, '').slice(0, 120),
        title: '',
        description: '',
      });
    }
  }
  return projects.slice(0, 12);
}

/**
 * @param {string} resumeText
 * @returns {object|null}
 */
function textToPortfolioJson(resumeText) {
  const text = String(resumeText || '').trim();
  if (text.length < 20) {
    return null;
  }

  const contact = extractContact(text);
  const parsed = {
    profile: {
      name: contact.name,
      headline: '',
      location: contact.location,
      contact: {
        email: contact.email,
        phone: contact.phone,
      },
      summary: extractSummary(text),
    },
    skills: extractSkills(text),
    experience: extractExperience(text),
    education: extractEducation(text),
    projects: extractProjects(text),
    certifications: [],
    languages: [],
  };

  const langBlock = sliceSection(text, ['languages'], SECTION_ENDS);
  if (langBlock) {
    parsed.languages = langBlock
      .split(/[,;•\n]+/)
      .map(cleanLine)
      .filter((s) => s.length > 2 && s.length < 60)
      .slice(0, 12);
  }

  return isPortfolioShape(parsed) ? parsed : null;
}

/**
 * @param {Buffer} fileBuffer
 * @param {string} fileName
 * @returns {Promise<{ parsedCv: object, engine: string } | null>}
 */
async function parseCvFromFileHeuristic(fileBuffer, fileName) {
  const text = await extractTextFromUpload(fileBuffer, fileName);
  const parsedCv = textToPortfolioJson(text);
  if (!parsedCv) {
    return null;
  }
  return { parsedCv, engine: 'text-heuristic-v1' };
}

module.exports = {
  textToPortfolioJson,
  parseCvFromFileHeuristic,
};
