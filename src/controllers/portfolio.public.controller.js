const { Portfolio, CVParsedProfile } = require('../models');



function escapeHtml(s) {

  if (s == null) return '';

  return String(s)

    .replace(/&/g, '&amp;')

    .replace(/</g, '&lt;')

    .replace(/>/g, '&gt;')

    .replace(/"/g, '&quot;');

}



function safeOgImageSrc(raw) {

  const t = String(raw || '').trim();

  if (!t || t.length > 2048) return null;

  if (!/^https:\/\/opengraph\.githubassets\.com\//i.test(t)) return null;

  return t;

}



/** User-upload JPEG data URL saved in previewSnapshot (validated again at save time). */

function safePortfolioCustomImgSrc(raw) {

  const s = String(raw || '').trim();

  const maxLen = 320000;

  if (!s || s.length < 32 || s.length > maxLen) return null;

  const low = s.toLowerCase();

  if (!low.startsWith('data:image/jpeg;base64,')) return null;

  const idx = s.indexOf(',');

  if (idx < 23 || idx >= s.length - 2) return null;

  const b64 = s.slice(idx + 1).replace(/\s/g, '');

  if (!/^[A-Za-z0-9+/=]+$/.test(b64.slice(0, Math.min(b64.length, 300)))) return null;

  try {

    const bytes = Buffer.from(b64, 'base64').length;

    if (bytes <= 256 || bytes > 220000) return null;

  } catch {

    return null;

  }

  return `data:image/jpeg;base64,${b64}`;

}



function repoPathSegment(name) {

  return String(name || '')

    .trim()

    .replace(/\s+/g, '-');

}



/** Deterministic banner gradient per project (pairs with Flutter preview banners). */

function portfolioCoverCssGradient(githubUser, projectName) {

  const key = `${String(githubUser || '').toLowerCase()}|${String(projectName || '')}`;

  let h = 2166136261 >>> 0;

  for (let i = 0; i < key.length; i += 1) {

    h ^= key.charCodeAt(i);

    h = Math.imul(h, 16777619) >>> 0;

  }

  const hue1 = h % 360;

  const hue2 = (h >>> 11) % 360;

  return `linear-gradient(135deg, hsl(${hue1}, 62%, 34%) 0%, hsl(${hue2}, 55%, 24%) 100%)`;

}



/** 12 hex chars from randomBytes(6) */

function isValidPublicSlug(slug) {

  return typeof slug === 'string' && /^[a-f0-9]{12}$/.test(slug);

}



const THEMES = {

  classic: {

    pageBg: '#f1f5f9',

    heroBg: 'linear-gradient(135deg, #0f172a 0%, #1e3a8a 45%, #2563eb 100%)',

    heroText: '#ffffff',

    accent: '#2563eb',

    cardBg: '#ffffff',

    bodyText: '#334155',

    muted: '#64748b',

    cardExtras: '',

    avatarBg: '#334155',

    avatarBorder: 'rgba(255,255,255,0.35)',

    projRowBg: 'rgba(248,250,252,0.92)',

    h1Family: 'system-ui,-apple-system,Segoe UI,Roboto,sans-serif',

  },

  minimal: {

    pageBg: '#fafafa',

    heroBg: '#ffffff',

    heroText: '#111827',

    accent: '#111827',

    cardBg: '#ffffff',

    bodyText: '#374151',

    muted: '#6b7280',

    cardExtras: '',

    avatarBg: '#e5e7eb',

    avatarBorder: '#d1d5db',

    projRowBg: '#fafafa',

    h1Family: 'system-ui,-apple-system,Segoe UI,Roboto,sans-serif',

  },

  darkneon: {

    pageBg: '#0b0f19',

    heroBg: '#111827',

    heroText: '#f9fafb',

    accent: '#39ffb5',

    cardBg: 'rgba(255,255,255,0.06)',

    bodyText: '#d1d5db',

    muted: '#9ca3af',

    cardExtras: 'border-color: rgba(57,255,181,0.22); box-shadow: none;',

    avatarBg: '#1f2937',

    avatarBorder: 'rgba(57,255,181,0.35)',

    projRowBg: 'rgba(255,255,255,0.05)',

    h1Family: 'system-ui,-apple-system,Segoe UI,Roboto,sans-serif',

  },

  warmcreative: {

    pageBg: '#fff7ed',

    heroBg: 'linear-gradient(180deg, #ffedd5 0%, #fed7aa 100%)',

    heroText: '#431407',

    accent: '#ea580c',

    cardBg: '#ffffff',

    bodyText: '#422006',

    muted: '#9a3412',

    cardExtras: '',

    avatarBg: '#fff7ed',

    avatarBorder: '#fdba74',

    projRowBg: '#ffffff',

    h1Family: 'system-ui,-apple-system,Segoe UI,Roboto,sans-serif',

  },

  editorial: {

    pageBg: '#fdfcfa',

    heroBg: '#f4f4f5',

    heroText: '#0c0c0d',

    accent: '#18181b',

    cardBg: '#ffffff',

    bodyText: '#27272a',

    muted: '#71717a',

    cardExtras: '',

    avatarBg: '#e4e4e7',

    avatarBorder: '#d4d4d8',

    projRowBg: '#fafafa',

    h1Family: 'Georgia, "Times New Roman", serif',

  },

};



function normalizeTemplateId(id) {

  const k = String(id || 'classic')

    .trim()

    .toLowerCase()

    .replace(/[^a-z]/g, '');

  const map = {

    default: 'classic',

    classic: 'classic',

    minimal: 'minimal',

    darkneon: 'darkneon',

    warmcreative: 'warmcreative',

    editorial: 'editorial',

  };

  return map[k] || 'classic';

}



function initialsFrom(name) {

  const parts = String(name || '')

    .trim()

    .split(/\s+/)

    .filter(Boolean)

    .slice(0, 2);

  if (parts.length === 0) return '?';

  return parts.map((p) => p[0].toUpperCase()).join('');

}



/**

 * Same content as PortfolioPreviewData JSON from the Flutter app.

 * @returns {Record<string, unknown>|null}

 */

function parseSnapshot(row) {

  const raw = row.previewSnapshot;

  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;

  return raw;

}



function projectList(row, snap) {

  const fromSnapEff =

    snap && Array.isArray(snap.effectiveProjects) && snap.effectiveProjects.length > 0

      ? snap.effectiveProjects

      : null;

  if (fromSnapEff) {

    return fromSnapEff.map((r) => String(r).trim()).filter(Boolean).slice(0, 48);

  }

  const fromSnapProj =

    snap && Array.isArray(snap.projectNames) && snap.projectNames.length > 0

      ? snap.projectNames

      : null;

  if (fromSnapProj) {

    return fromSnapProj.map((r) => String(r).trim()).filter(Boolean).slice(0, 48);

  }

  if (Array.isArray(row.projectRepos) && row.projectRepos.length > 0) {

    return row.projectRepos.map((r) => String(r).trim()).filter(Boolean).slice(0, 48);

  }

  return [];

}



function renderPublicPortfolio(row, profile) {

  const snap = parseSnapshot(row);

  const themeKey = normalizeTemplateId(

    snap && snap.template ? String(snap.template) : row.templateId,

  );

  const theme = THEMES[themeKey] || THEMES.classic;



  const displayName =

    snap && snap.displayName

      ? String(snap.displayName).trim()

      : profile.fullNameExtracted || 'Portfolio';

  const headline =

    snap && snap.headline

      ? String(snap.headline).trim()

      : profile.specializationDetected || '';

  const bio = snap && snap.bio ? String(snap.bio).trim() : '';

  const emailRaw =

    snap && snap.email

      ? String(snap.email).trim()

      : profile.emailExtracted

        ? String(profile.emailExtracted).trim()

        : '';

  const phoneRaw = snap && snap.phone ? String(snap.phone).trim() : '';

  const locationRaw = snap && snap.location ? String(snap.location).trim() : '';

  const linkedinRaw =

    snap && snap.linkedinUrl ? String(snap.linkedinUrl).trim() : '';



  let ghUser = '';

  if (snap && snap.githubUsername) {

    ghUser = String(snap.githubUsername).trim();

  }

  if (!ghUser && row.githubUsername) {

    ghUser = String(row.githubUsername).trim();

  }



  let skillsList = [];

  if (snap && Array.isArray(snap.skills) && snap.skills.length > 0) {

    skillsList = snap.skills.map((s) => String(s).trim()).filter(Boolean).slice(0, 40);

  }



  const repos = projectList(row, snap);

  const nameEsc = escapeHtml(displayName);

  const subtitleParts = [];

  if (ghUser) subtitleParts.push(`@${escapeHtml(ghUser)}`);

  if (headline) subtitleParts.push(escapeHtml(headline));

  const subtitleHtml =

    subtitleParts.length > 0

      ? `<p class="sub">${subtitleParts.join(' · ')}</p>`

      : '';



  const emailEscAttr = escapeHtml(emailRaw.replace(/"/g, ''));

  const emailDisp = escapeHtml(emailRaw);



  const chipHtmlParts = [];

  if (locationRaw) {

    chipHtmlParts.push(`<span class="chip">${escapeHtml(locationRaw)}</span>`);

  }

  if (emailRaw) {

    chipHtmlParts.push(

      `<span class="chip"><a href="mailto:${emailEscAttr}">${emailDisp}</a></span>`,

    );

  }

  if (phoneRaw) {

    const tel = String(phoneRaw).replace(/[^\d+]/g, '');

    chipHtmlParts.push(

      `<span class="chip"><a href="tel:${escapeHtml(tel)}">${escapeHtml(phoneRaw)}</a></span>`,

    );

  }

  const chipsRow =

    chipHtmlParts.length > 0 ? `<div class="chips">${chipHtmlParts.join('')}</div>` : '';



  const initials = initialsFrom(displayName);



  let actionsHtml = '';

  if (ghUser) {

    const ghe = encodeURIComponent(ghUser);

    actionsHtml += `<a class="btn primary" href="https://github.com/${ghe}" target="_blank" rel="noopener noreferrer">GitHub profile</a>`;

  }

  if (emailRaw) {

    actionsHtml += `<a class="btn secondary" href="mailto:${emailEscAttr}">Email</a>`;

  }



  const ghMuted =

    ghUser !== ''

      ? `<p class="muted small"><a href="https://github.com/${escapeHtml(ghUser)}" target="_blank" rel="noopener noreferrer">github.com/${escapeHtml(ghUser)}</a></p>`

      : '';



  const ogMap =

    snap && typeof snap.projectOgImages === 'object' && snap.projectOgImages !== null && !Array.isArray(snap.projectOgImages)

      ? snap.projectOgImages

      : {};



  const customMap =

    snap && typeof snap.projectCustomImages === 'object' && snap.projectCustomImages !== null && !Array.isArray(snap.projectCustomImages)

      ? snap.projectCustomImages

      : {};



  const projectCards = repos

    .map((repo) => {

      const slug = repoPathSegment(repo);

      const href =

        ghUser && slug

          ? `https://github.com/${encodeURIComponent(ghUser)}/${encodeURIComponent(slug)}`

          : '#';

      const title = escapeHtml(repo);

      const pathLabel =

        ghUser && slug

          ? `${escapeHtml(ghUser)}/${escapeHtml(slug)}`

          : title;

      const coverGrad = portfolioCoverCssGradient(ghUser, repo);

      const inlineUrl = safePortfolioCustomImgSrc(customMap[repo]);

      const ogUrl = safeOgImageSrc(ogMap[repo]);

      const imgSrcEscaped = escapeHtml(inlineUrl || ogUrl || '');

      const coverBlock = inlineUrl

        ? `<div class="proj-cover"><img class="proj-cover-img" src="${imgSrcEscaped}" alt="" loading="lazy" referrerpolicy="no-referrer" decoding="async" /></div>`

        : ogUrl

          ? `<div class="proj-cover"><img class="proj-cover-img" src="${imgSrcEscaped}" alt="" loading="lazy" referrerpolicy="no-referrer" decoding="async" /></div>`

          : `<div class="proj-cover" style="background:${coverGrad};"></div>`;

      return `<a class="proj" href="${href}" target="_blank" rel="noopener noreferrer">${coverBlock}<div class="proj-body"><span class="proj-name">${title}</span><span class="proj-path">github.com/${pathLabel}</span><span class="proj-go">View on GitHub →</span></div></a>`;

    })

    .join('\n');



  const projectsSection =

    repos.length > 0

      ? `<section class="card"><h2>Projects</h2><div class="grid">${projectCards}</div></section>`

      : ghUser !== ''

        ? `<section class="card"><p class="muted">No projects listed in your saved portfolio.</p></section>`

        : '';



  const aboutSection =

    bio !== ''

      ? `<section class="card"><h2>About</h2><p class="body-text">${escapeHtml(bio)}</p></section>`

      : '';



  const skillsSection =

    skillsList.length > 0

      ? `<section class="card"><h2>Skills</h2><div class="skills">${skillsList

          .map((s) => `<span class="skill">${escapeHtml(s)}</span>`)

          .join('')}</div></section>`

      : '';



  let linkedinFooter = '';

  if (linkedinRaw) {
    const hrefLi = String(linkedinRaw).replace(/&/g, '&amp;').replace(/"/g, '&quot;');

    linkedinFooter = `<p><a href="${hrefLi}" target="_blank" rel="noopener noreferrer">LinkedIn</a></p>`;

  }



  const styleHint =

    themeKey === 'minimal'

      ? '.hero-row { border: 1px solid #e5e7eb; }'

      : themeKey === 'editorial'

        ? '.hero h1 { letter-spacing: -0.03em; }'

        : '';



  return `<!DOCTYPE html>

<html lang="en" data-template="${themeKey}">

<head>

  <meta charset="utf-8"/>

  <meta name="viewport" content="width=device-width, initial-scale=1"/>

  <title>${nameEsc} — CareerPath</title>

  <style>

    * { box-sizing: border-box; }

    body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;

      background: ${theme.pageBg}; color: ${theme.bodyText}; line-height: 1.55; }

    main { max-width: 52rem; margin: 0 auto; padding: 1.25rem 1rem 3rem; }

    .hero-row { display: flex; gap: 1.25rem; align-items: flex-start; padding: 0; border-radius: 1rem;}

    ${styleHint}

    .hero {

      border-radius: 1rem; padding: 2rem 1.5rem; background: ${theme.heroBg}; color: ${theme.heroText};

      margin-bottom: 1.5rem; box-shadow: 0 18px 40px rgba(15,23,42,0.08); }

    .avatar {

      flex-shrink: 0; width: 4rem; height: 4rem; border-radius: 50%; border: 3px solid ${theme.avatarBorder};

      background: ${theme.avatarBg}; display: flex; align-items: center; justify-content: center;

      font-size: 1.5rem; font-weight: 800;

    }

    .hero-main { flex: 1; min-width: 0; }

    .hero h1 { margin: 0 0 0.35rem; font-family: ${theme.h1Family}; font-size: clamp(1.5rem, 4vw, 2rem); letter-spacing: -0.02em; }

    .sub { margin: 0.25rem 0 0; font-size: 0.95rem; opacity: 0.92; line-height: 1.35; }

    .chips { margin-top: 1rem; display: flex; flex-wrap: wrap; gap: 0.5rem; }

    .chip {

      padding: 0.35rem 0.65rem; border-radius: 999px; font-size: 0.8125rem; font-weight: 600;

      background: rgba(255,255,255,0.14); border: 1px solid rgba(255,255,255,0.25);

    }

    .chip a { color: inherit; text-decoration: underline; opacity: 0.95; }

    .muted { margin: 0.35rem 0 0; color: ${theme.muted}; font-size: 1rem; }

    .muted.small { font-size: 0.875rem; }

    .muted a { color: ${theme.accent}; }

    .actions { margin-top: 1.15rem; display: flex; flex-wrap: wrap; gap: 0.65rem; }

    .btn {

      display: inline-flex; align-items: center; padding: 0.55rem 1rem; border-radius: 0.65rem;

      font-weight: 700; font-size: 0.9rem; text-decoration: none; border: none; cursor: pointer;

    }

    .btn.primary { background: rgba(255,255,255,0.92); color: #1e40af; }

    .btn.secondary { background: transparent; color: inherit; border: 1px solid rgba(255,255,255,0.45); }

    html[data-template="minimal"] .btn.primary { background: #111827; color: #fafafa; }

    html[data-template="minimal"] .btn.secondary { border-color: #d1d5db; color: #111827; }

    html[data-template="minimal"] .chip { background: #f9fafb; border-color: #e5e7eb; color: #374151; }

    html[data-template="minimal"] .chip a { color: #2563eb; }

    html[data-template="darkneon"] .btn.primary { background: ${theme.accent}; color: #0b0f19; }

    html[data-template="darkneon"] .btn.secondary { border-color: rgba(57,255,181,0.45); }

    html[data-template="warmcreative"] .chip { background: rgba(254,243,199,0.7); border-color: #fcd34d; color: ${theme.heroText}; }

    html[data-template="warmcreative"] .btn.secondary { border-color: rgba(67,20,7,0.35); }

    html[data-template="warmcreative"] .btn.primary { background: #431407; color: #fff7ed; }

    html[data-template="editorial"] .chip { background: #fafafa; border-color: #e4e4e7; color: #27272a; }

    html[data-template="editorial"] .btn.primary { background: #18181b; color: #fafafa; }

    html[data-template="editorial"] .btn.secondary { border-color: #a1a1aa; }

    .card { background: ${theme.cardBg}; border-radius: 0.875rem; padding: 1.25rem 1.35rem;

      margin-bottom: 1rem; border: 1px solid rgba(148,163,184,0.35); box-shadow: 0 8px 24px rgba(15,23,42,0.05);

      ${theme.cardExtras || ''} }

    .card h2 { margin: 0 0 0.85rem; font-size: 1.05rem; color: ${theme.accent}; letter-spacing: 0.03em;

      text-transform: uppercase; }

    .body-text { margin: 0; white-space: pre-wrap; }

    .skills { display: flex; flex-wrap: wrap; gap: 0.45rem; }

    .skill {

      padding: 0.4rem 0.85rem; border-radius: 0.55rem; font-size: 0.8125rem; font-weight: 700;

      background: rgba(37,99,235,0.09); border: 1px solid rgba(59,130,246,0.35); color: #1d4ed8;

    }

    html[data-template="darkneon"] .skill { background: rgba(57,255,181,0.08); border-color: rgba(57,255,181,0.35); color: ${theme.accent}; }

    html[data-template="warmcreative"] .skill { background: #fff7ed; border-color: #fdba74; color: #9a3412; }

    html[data-template="editorial"] .skill { background: #fafafa; border-color: #d4d4d8; color: #18181b; }

    html[data-template="minimal"] .skill { background: #f4f4f5; border-color: #d4d4d8; color: #111827; }

    .grid { display: flex; flex-direction: column; gap: 0.65rem; }

    a.proj { display: flex; flex-direction: column; align-items: stretch; gap: 0;

      padding: 0; overflow: hidden; border-radius: 0.65rem; text-decoration: none; color: ${theme.bodyText};

      border: 1px solid rgba(148,163,184,0.45); background: ${theme.projRowBg}; transition: border-color 0.15s, transform 0.15s; }

    a.proj:hover { border-color: ${theme.accent}; transform: translateY(-1px); }

    .proj-cover { height: 6.5rem; width: 100%; flex-shrink: 0; position: relative; overflow: hidden; }

    .proj-cover-img { display: block; width: 100%; height: 100%; object-fit: cover; }

    .proj-body { padding: 0.75rem 1rem; display: flex; flex-direction: column; gap: 0.2rem; align-items: flex-start; }

    .proj-name { font-weight: 700; font-size: 1.02rem; }

    .proj-path { font-size: 0.8rem; color: ${theme.muted}; font-weight: 600; word-break: break-all; }

    .proj-go { font-size: 0.85rem; color: ${theme.accent}; font-weight: 700; }

    footer.site { margin-top: 2rem; font-size: 0.8125rem; color: ${theme.muted}; text-align: center; }

    footer.site a { color: ${theme.accent}; font-weight: 600; }

    @media (min-width: 640px) { .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); } }

    @media (max-width: 520px) { .hero-row { flex-direction: column; align-items: center; text-align: center; }

      .hero-main { display: flex; flex-direction: column; align-items: center; }

      .chips { justify-content: center; } .actions { justify-content: center; } }

  </style>

</head>

<body>

  <main>

    <header class="hero">

      <div class="hero-row">

        <div class="avatar" aria-hidden="true">${escapeHtml(initials)}</div>

        <div class="hero-main">

          <h1>${nameEsc}</h1>

          ${subtitleHtml}

          ${chipsRow}

          ${actionsHtml ? `<div class="actions">${actionsHtml}</div>` : ''}

          ${ghMuted}

        </div>

      </div>

    </header>

    ${aboutSection}

    ${skillsSection}

    ${projectsSection}

    <footer class="site">

      ${linkedinFooter}

      <p>CareerPath AI — portfolio</p>

    </footer>

  </main>

</body>

</html>`;

}



async function publicPortfolioPage(req, res) {

  try {

    const slug = String(req.params.slug || '').trim().toLowerCase();

    if (!isValidPublicSlug(slug)) {

      return res

        .status(404)

        .type('html')

        .send('<!DOCTYPE html><html><body><p>Not found</p></body></html>');

    }

    const row = await Portfolio.findOne({ publicSlug: slug }).lean();

    if (!row) {

      return res

        .status(404)

        .type('html')

        .send('<!DOCTYPE html><html><body><p>Portfolio not found</p></body></html>');

    }

    const profile = await CVParsedProfile.findById(row.profileId).lean();

    if (!profile) {

      return res

        .status(404)

        .type('html')

        .send('<!DOCTYPE html><html><body><p>Profile not found</p></body></html>');

    }

    const html = renderPublicPortfolio(row, profile);

    return res.type('html').send(html);

  } catch (err) {

    console.error('[portfolio public]', err);

    return res

      .status(500)

      .type('html')

      .send('<!DOCTYPE html><html><body><p>Server error</p></body></html>');

  }

}



module.exports = { publicPortfolioPage };


