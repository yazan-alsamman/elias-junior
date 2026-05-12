const crypto = require('crypto');
const mongoose = require('mongoose');
const { CVDocument, CVParsedProfile, Portfolio } = require('../models');

async function generateUniquePublicSlug() {
  for (let i = 0; i < 12; i += 1) {
    const slug = crypto.randomBytes(6).toString('hex');
    // eslint-disable-next-line no-await-in-loop
    const clash = await Portfolio.findOne({ publicSlug: slug }).select('_id').lean();
    if (!clash) return slug;
  }
  throw new Error('Could not allocate publicSlug');
}

async function listPortfolios(req, res) {
  try {
    const docs = await CVDocument.find({ userId: req.userId }).select('_id').lean();
    const docIds = docs.map((d) => d._id);
    const profiles = await CVParsedProfile.find({
      documentId: { $in: docIds },
    })
      .select('_id')
      .lean();
    const profileIds = profiles.map((p) => p._id);
    const rows = await Portfolio.find({ profileId: { $in: profileIds } })
      .sort({ createdAt: -1 })
      .lean();
    return res.json({
      portfolios: rows.map((row) => ({
        id: row._id.toString(),
        profileId: row.profileId.toString(),
        templateId: row.templateId || '',
        portfolioUrl: row.portfolioUrl || '',
        publicSlug: row.publicSlug || '',
        createdAt: row.createdAt,
      })),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

function normalizeProjects(body) {
  const raw = body.projectRepos;
  if (Array.isArray(raw)) {
    return raw.map((x) => String(x).trim()).filter(Boolean).slice(0, 48);
  }
  if (raw != null && typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map((x) => String(x).trim()).filter(Boolean).slice(0, 48);
      }
    } catch (_) {
      return String(raw)
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
        .slice(0, 48);
    }
  }
  return [];
}

function sanitizeOgGithubImageUrl(s) {
  const t = String(s || '').trim();
  if (!t || t.length > 2048) return null;
  if (!/^https:\/\/opengraph\.githubassets\.com\//i.test(t)) return null;
  return t;
}

function sanitizeInlinePortfolioImage(v) {

  const s = String(v || '').trim();

  const maxLen = 320000;

  if (!s || s.length < 32 || s.length > maxLen) return null;

  const low = s.toLowerCase();

  if (!low.startsWith('data:image/jpeg;base64,')) {

    return null;

  }

  const idx = s.indexOf(',');

  if (idx < 23 || idx >= s.length - 2) return null;

  const b64 = s.slice(idx + 1).replace(/\s/g, '');

  if (!/^[A-Za-z0-9+/=]+$/.test(b64.slice(0, 400))) return null;

  try {

    const bytes = Buffer.from(b64, 'base64').length;

    if (bytes <= 256 || bytes > 220000) return null;

  } catch {

    return null;

  }

  return `data:image/jpeg;base64,${b64}`;

}



function sanitizePreviewSnapshot(input) {
  if (input == null) {
    return null;
  }
  let raw = input;
  if (typeof raw === 'string') {
    try {
      raw = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  try {
    if (JSON.stringify(raw).length > 950000) {
      return null;
    }
  } catch {
    return null;
  }
  const skills = Array.isArray(raw.skills)
    ? raw.skills.map((s) => String(s).slice(0, 100)).filter(Boolean).slice(0, 40)
    : [];
  const projectNames = Array.isArray(raw.projectNames)
    ? raw.projectNames.map((s) => String(s).slice(0, 200)).filter(Boolean).slice(0, 48)
    : [];
  const effIn =
    Array.isArray(raw.effectiveProjects) && raw.effectiveProjects.length > 0
      ? raw.effectiveProjects.map((s) => String(s).slice(0, 200)).filter(Boolean).slice(0, 48)
      : null;
  const effectiveProjects =
    effIn != null && effIn.length > 0 ? effIn : [...projectNames];

  const projectOgImages = {};
  const rawOg = raw.projectOgImages;
  if (rawOg && typeof rawOg === 'object' && !Array.isArray(rawOg)) {
    for (const [k, v] of Object.entries(rawOg)) {
      const name = String(k).trim().slice(0, 200);
      const u = sanitizeOgGithubImageUrl(v);
      if (name && u) projectOgImages[name] = u;
    }
  }
  const projectCustomImages = {};
  const rawCust = raw.projectCustomImages;
  if (rawCust && typeof rawCust === 'object' && !Array.isArray(rawCust)) {
    for (const [k, v] of Object.entries(rawCust)) {
      const name = String(k).trim().slice(0, 200);
      const u = sanitizeInlinePortfolioImage(v);
      if (name && u) projectCustomImages[name] = u;
    }
  }
  return {
    displayName: String(raw.displayName || '').slice(0, 200),
    headline: String(raw.headline || '').slice(0, 400),
    bio: String(raw.bio || '').slice(0, 12000),
    email: String(raw.email || '').slice(0, 320),
    phone: String(raw.phone || '').slice(0, 80),
    linkedinUrl: String(raw.linkedinUrl || '').slice(0, 2048),
    location: String(raw.location || '').slice(0, 400),
    skills,
    githubUsername: String(raw.githubUsername || '').slice(0, 120),
    template: String(raw.template || '').slice(0, 64),
    projectNames,
    effectiveProjects,
    projectOgImages,
    projectCustomImages,
  };
}

async function upsertPortfolio(req, res) {
  try {
    const {
      documentId,
      templateId = 'classic',
      portfolioUrl = '',
      githubUsername = '',
    } = req.body;
    const projectRepos = normalizeProjects(req.body);
    const previewSnapshot = sanitizePreviewSnapshot(req.body.previewSnapshot);
    if (!documentId || !mongoose.isValidObjectId(documentId)) {
      return res.status(400).json({ error: 'valid documentId required' });
    }
    const doc = await CVDocument.findOne({
      _id: documentId,
      userId: req.userId,
    });
    if (!doc) {
      return res.status(404).json({ error: 'Document not found' });
    }
    let profile = await CVParsedProfile.findOne({ documentId: doc._id });
    if (!profile) {
      return res.status(400).json({
        error: 'Run ATS analysis on this document before creating a portfolio',
      });
    }
    const existing = await Portfolio.findOne({ profileId: profile._id }).lean();
    let publicSlug = existing && existing.publicSlug ? existing.publicSlug : null;
    if (!publicSlug) {
      publicSlug = await generateUniquePublicSlug();
    }
    const port = Number(process.env.PORT) || 3001;
    const baseRaw = process.env.PUBLIC_BASE_URL || `http://localhost:${port}`;
    const base = String(baseRaw).replace(/\/$/, '');
    const defaultUrl = `${base}/p/${publicSlug}`;
    const trimmedCustom =
      portfolioUrl != null && String(portfolioUrl).trim() !== ''
        ? String(portfolioUrl).trim()
        : '';
    const finalUrl = trimmedCustom || defaultUrl;

    const gh = String(githubUsername || '').trim().replace(/^@/, '');

    const row = await Portfolio.findOneAndUpdate(
      { profileId: profile._id },
      {
        profileId: profile._id,
        templateId: String(templateId || 'classic'),
        portfolioUrl: finalUrl,
        publicSlug,
        githubUsername: gh,
        projectRepos,
        previewSnapshot,
      },
      { upsert: true, new: true },
    );
    return res.status(201).json({
      portfolio: {
        id: row._id.toString(),
        profileId: row.profileId.toString(),
        templateId: row.templateId,
        portfolioUrl: row.portfolioUrl,
        publicSlug: row.publicSlug || publicSlug,
        createdAt: row.createdAt,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { listPortfolios, upsertPortfolio };
