/**
 * Placeholder ATS analysis — swap for AI service later.
 * Deterministic scoring from text length + keyword presence.
 */
function analyzeExtractedText(raw) {
  const text = String(raw || '');
  const lower = text.toLowerCase();
  const len = text.length;

  let score = 28;
  if (len > 400) score += 12;
  if (len > 1200) score += 10;
  if (len > 2500) score += 8;

  const mustHave = [
    'experience',
    'education',
    'skill',
    'project',
    'summary',
    'work',
  ];
  let hits = 0;
  for (const w of mustHave) {
    if (lower.includes(w)) hits += 1;
  }
  score += hits * 6;

  const tech = [
    'javascript',
    'typescript',
    'python',
    'react',
    'flutter',
    'node',
    'sql',
    'aws',
    'docker',
    'git',
  ];
  let techHits = 0;
  for (const w of tech) {
    if (lower.includes(w)) techHits += 1;
  }
  score += Math.min(14, techHits * 2);

  score = Math.min(97, Math.max(16, Math.round(score)));

  const keywordsTotal = 48;
  const keywordsChecked = Math.min(keywordsTotal, 12 + Math.floor(len / 120) + hits * 3);

  const missingKeywords = [];
  if (!lower.includes('education')) missingKeywords.push('Education');
  if (!lower.includes('experience') && !lower.includes('work history')) {
    missingKeywords.push('Experience');
  }
  if (techHits < 3) {
    missingKeywords.push('Cloud / DevOps keywords');
  }
  if (missingKeywords.length < 3) {
    missingKeywords.push('Quantified outcomes (%, users, revenue)');
  }

  const formatScore = Math.min(95, 58 + hits * 4 + Math.min(12, Math.floor(techHits * 1.5)));
  const sectionMatch =
    hits >= 5 ? '5/6' : hits >= 3 ? '4/6' : hits >= 2 ? '3/6' : '2/6';

  const suitable = score >= 65;
  const recommendationBullets = [
    suitable
      ? 'Good baseline — mirror job-post terminology in a short skills line.'
      : 'Add standard ATS section titles (Summary, Experience, Skills, Education).',
    'Quantify impact: metrics, scale, or timelines in each role.',
    'Align keywords with 2–3 target job descriptions in your field.',
  ];

  const suitabilityHeadline = suitable
    ? 'Strong ATS alignment for typical screening'
    : 'Improve keyword coverage and section structure before volume applications';

  const status = suitable ? 'Optimized' : 'Parsed';

  return {
    score,
    status,
    extractedTextLength: len,
    keywordsChecked,
    keywordsTotal,
    formatScore,
    sectionMatch,
    estimatedSecondsLeft: 0,
    missingKeywords: missingKeywords.slice(0, 6),
    recommendationBullets,
    suitabilityHeadline,
    issuesSummary: `Heuristic scan v1 — ${keywordsChecked}/${keywordsTotal} keyword signals`,
    severity: suitable ? 'low' : 'medium',
    canAutoFix: false,
    autoFixApplied: false,
    failureReason: '',
    templateId: 'heuristic-v1',
  };
}

function inferSpecialization(raw) {
  const t = String(raw || '').toLowerCase();
  if (t.includes('flutter') || t.includes('mobile')) return 'Mobile / Flutter';
  if (t.includes('react') || t.includes('frontend')) return 'Frontend';
  if (t.includes('backend') || t.includes('node')) return 'Backend';
  if (t.includes('product') || t.includes('design')) return 'Product / Design';
  if (t.includes('data') || t.includes('ml')) return 'Data / ML';
  return 'Software / General';
}

module.exports = { analyzeExtractedText, inferSpecialization };
