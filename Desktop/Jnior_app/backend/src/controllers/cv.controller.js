const mongoose = require('mongoose');
const {
  CVDocument,
  CVVersion,
  ATSCheckReport,
  CVParsedProfile,
  SkillAssessment,
  Recommendation,
  Portfolio,
} = require('../models');
const { analyzeExtractedText, inferSpecialization } = require('../services/atsHeuristic');
const { analyzeUploadedCvFile } = require('../services/atsAnalyzeUpload');
const {
  parseCvFileViaParser,
  previewTextFromParsedCv,
  contactFromParsedCv,
} = require('../services/cvParserClient');
const {
  parseStoredParsedCv,
  envelopeForStorage,
  portfolioSnapshotFromParsedCv,
} = require('../services/parsedCvStore');

async function cascadeDeleteAnalysisForDocument(documentId) {
  const profiles = await CVParsedProfile.find({ documentId });
  for (const p of profiles) {
    const assessments = await SkillAssessment.find({ profileId: p._id });
    for (const a of assessments) {
      await Recommendation.deleteMany({ assessmentId: a._id });
      await a.deleteOne();
    }
    await Portfolio.deleteMany({ profileId: p._id });
    await p.deleteOne();
  }
  await ATSCheckReport.deleteMany({ documentId });
}

function serializeAts(doc) {
  if (!doc) return null;
  const o = doc.toObject ? doc.toObject() : doc;
  const engine = o.engine || o.templateId || '';
  return {
    id: o._id.toString(),
    score: o.score ?? 0,
    status: o.status,
    checkedAt: o.createdAt,
    keywordsChecked: o.keywordsChecked ?? 0,
    keywordsTotal: o.keywordsTotal ?? 0,
    formatScore: o.formatScore ?? 0,
    sectionMatch: o.sectionMatch ?? '',
    estimatedSecondsLeft: o.estimatedSecondsLeft ?? 0,
    missingKeywords: o.missingKeywords ?? [],
    recommendations: o.recommendationBullets ?? [],
    suitabilityHeadline: o.suitabilityHeadline ?? '',
    issuesSummary: o.issuesSummary ?? '',
    engine,
    decision: o.decision ?? '',
    failedRulesCount: o.failedRulesCount ?? 0,
    failedBasic: Boolean(o.failedBasic),
    failures: Array.isArray(o.failures) ? o.failures : [],
    isRealAts: engine === 'fastapi-ats-format-v1',
  };
}

function atsCreateFields(ats) {
  return {
    score: ats.score,
    status: ats.status,
    extractedTextLength: ats.extractedTextLength ?? 0,
    keywordsChecked: ats.keywordsChecked ?? 0,
    keywordsTotal: ats.keywordsTotal ?? 0,
    formatScore: ats.formatScore ?? 0,
    sectionMatch: ats.sectionMatch ?? '',
    estimatedSecondsLeft: ats.estimatedSecondsLeft ?? 0,
    missingKeywords: ats.missingKeywords ?? [],
    recommendationBullets: ats.recommendationBullets ?? [],
    suitabilityHeadline: ats.suitabilityHeadline ?? '',
    issuesSummary: ats.issuesSummary ?? '',
    severity: ats.severity ?? '',
    canAutoFix: Boolean(ats.canAutoFix),
    autoFixApplied: Boolean(ats.autoFixApplied),
    failureReason: ats.failureReason ?? '',
    templateId: ats.templateId ?? ats.engine ?? '',
    engine: ats.engine ?? ats.templateId ?? '',
    decision: ats.decision ?? '',
    failedRulesCount: ats.failedRulesCount ?? 0,
    failedBasic: Boolean(ats.failedBasic),
    failures: Array.isArray(ats.failures) ? ats.failures : [],
  };
}

function serializeCv(doc, atsDoc) {
  const o = doc.toObject ? doc.toObject() : doc;
  return {
    id: o._id.toString(),
    originalFileName: o.originalFileName || 'cv',
    fileType: o.fileType || '',
    fileUrl: o.fileUrl || '',
    extractedText: o.extractedText || '',
    uploadedAt: o.uploadedAt,
    documentStage: o.documentStage,
    generatedBy: o.generatedBy,
    report: serializeAts(atsDoc),
  };
}

async function listDocuments(req, res) {
  try {
    const docs = await CVDocument.find({ userId: req.userId })
      .sort({ uploadedAt: -1 })
      .lean();
    const out = [];
    for (const d of docs) {
      const ats = await ATSCheckReport.findOne({ documentId: d._id })
        .sort({ createdAt: -1 })
        .exec();
      const full = await CVDocument.findById(d._id);
      const profile = await CVParsedProfile.findOne({ documentId: d._id })
        .sort({ _id: -1 })
        .exec();
      const row = serializeCv(full, ats);
      if (profile) {
        row.profileId = profile._id.toString();
        row.hasParsedCv = Boolean(parseStoredParsedCv(profile));
      }
      out.push(row);
    }
    return res.json({ documents: out });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function createDocument(req, res) {
  try {
    const {
      originalFileName,
      fileType = 'pdf',
      extractedText = '',
      documentStage = 'uploaded',
      generatedBy = 'user',
    } = req.body;
    if (!originalFileName || String(originalFileName).trim() === '') {
      return res.status(400).json({ error: 'originalFileName required' });
    }
    const doc = await CVDocument.create({
      userId: req.userId,
      originalFileName: String(originalFileName).trim(),
      fileType: String(fileType).trim() || 'pdf',
      extractedText: String(extractedText),
      documentStage: String(documentStage),
      generatedBy: String(generatedBy),
      fileUrl: '',
    });
    await CVVersion.create({
      userId: req.userId,
      documentId: doc._id,
      versionNo: 1,
    });
    const fresh = await CVDocument.findById(doc._id);
    return res.status(201).json({ document: serializeCv(fresh, null) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function getDocument(req, res) {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const doc = await CVDocument.findOne({
      _id: req.params.id,
      userId: req.userId,
    });
    if (!doc) return res.status(404).json({ error: 'Not found' });
    const ats = await ATSCheckReport.findOne({ documentId: doc._id })
      .sort({ createdAt: -1 })
      .exec();
    const profile = await CVParsedProfile.findOne({ documentId: doc._id })
      .sort({ _id: -1 })
      .exec();
    const parsedCv = parseStoredParsedCv(profile);
    return res.json({
      document: serializeCv(doc, ats),
      ...(parsedCv ? { parsedCv, parseEngine: 'llama-lora-cv-parser-v1' } : {}),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function getParsedProfile(req, res) {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const doc = await CVDocument.findOne({
      _id: req.params.id,
      userId: req.userId,
    });
    if (!doc) return res.status(404).json({ error: 'Not found' });

    const profile = await CVParsedProfile.findOne({ documentId: doc._id })
      .sort({ _id: -1 })
      .exec();
    if (!profile) {
      return res.status(404).json({ error: 'No parsed profile for this document' });
    }

    const parsedCv = parseStoredParsedCv(profile);
    if (!parsedCv) {
      return res.status(404).json({
        error: 'Parsed CV JSON not available yet. Upload with CV parser running on port 8001.',
      });
    }

    let parseEngine = 'llama-lora-cv-parser-v1';
    let parsedAt = profile.createdAt;
    try {
      const envelope = JSON.parse(profile.rawJson);
      if (envelope?.engine) parseEngine = String(envelope.engine);
      if (envelope?.parsedAt) parsedAt = envelope.parsedAt;
    } catch (_e) {
      /* legacy raw portfolio JSON */
    }

    return res.json({
      documentId: doc._id.toString(),
      profileId: profile._id.toString(),
      parseEngine,
      parsedAt,
      parsedCv,
      portfolioDefaults: portfolioSnapshotFromParsedCv(parsedCv, {}),
      fullNameExtracted: profile.fullNameExtracted || '',
      emailExtracted: profile.emailExtracted || '',
      specializationDetected: profile.specializationDetected || '',
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function deleteDocument(req, res) {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const doc = await CVDocument.findOne({
      _id: req.params.id,
      userId: req.userId,
    });
    if (!doc) return res.status(404).json({ error: 'Not found' });
    await cascadeDeleteAnalysisForDocument(doc._id);
    await CVVersion.deleteMany({ documentId: doc._id });
    await doc.deleteOne();
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function analyzeDocument(req, res) {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid id' });
    }
    const doc = await CVDocument.findOne({
      _id: req.params.id,
      userId: req.userId,
    });
    if (!doc) return res.status(404).json({ error: 'Not found' });
    if (!doc.extractedText || doc.extractedText.trim().length < 40) {
      return res.status(400).json({
        error: 'Document needs more extracted text (min ~40 chars) for analysis',
      });
    }

    await cascadeDeleteAnalysisForDocument(doc._id);

    const h = analyzeExtractedText(doc.extractedText);
    const ats = await ATSCheckReport.create({
      documentId: doc._id,
      ...atsCreateFields(h),
    });

    const spec = inferSpecialization(doc.extractedText);
    const profile = await CVParsedProfile.create({
      documentId: doc._id,
      fullNameExtracted: '',
      emailExtracted: '',
      specializationDetected: spec,
      rawJson: JSON.stringify({
        engine: 'heuristic-v1',
        score: h.score,
        keywords: h.missingKeywords,
      }),
    });

    const assessment = await SkillAssessment.create({
      profileId: profile._id,
      targetSpecialization: spec,
      strengthScore: h.score,
      breakdownJson: JSON.stringify({
        format: h.formatScore,
        keywords: h.keywordsChecked,
        total: h.keywordsTotal,
      }),
    });

    const recs = [
      {
        assessmentId: assessment._id,
        recType: 'keyword',
        title: 'Keyword coverage',
        description: h.recommendationBullets[0] || 'Improve keyword overlap.',
        priority: 'high',
      },
      {
        assessmentId: assessment._id,
        recType: 'format',
        title: 'Structure',
        description: h.recommendationBullets[1] || 'Clarify section headers.',
        priority: 'medium',
      },
      {
        assessmentId: assessment._id,
        recType: 'metrics',
        title: 'Impact',
        description: h.recommendationBullets[2] || 'Add measurable outcomes.',
        priority: 'medium',
      },
    ];
    await Recommendation.insertMany(recs);

    doc.documentStage = 'analyzed';
    await doc.save();

    return res.json({
      document: serializeCv(doc, ats),
      profileId: profile._id.toString(),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function uploadAndAnalyzeFile(req, res) {
  try {
    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ error: 'file is required (multipart field: file)' });
    }

    const originalFileName = String(req.file.originalname || '').trim();
    if (!originalFileName) {
      return res.status(400).json({ error: 'original file name missing' });
    }
    const ext = originalFileName.toLowerCase().split('.').pop();
    if (!['pdf', 'docx'].includes(ext)) {
      return res.status(400).json({ error: 'Only PDF and DOCX files are supported' });
    }

    // ATS format check + CV parser (Llama/LoRA JSON) run in parallel on the same file buffer.
    const fileBuffer = req.file.buffer;
    const [atsOutcome, parseOutcome] = await Promise.all([
      analyzeUploadedCvFile({ fileBuffer, fileName: originalFileName }),
      (async () => {
        try {
          return await parseCvFileViaParser({ fileBuffer, fileName: originalFileName });
        } catch (parseErr) {
          console.warn('[cv-parser] parse failed:', parseErr.message);
          return null;
        }
      })(),
    ]);

    const {
      ats: fast,
      extractedText: atsExtractedText,
      engine,
      atsAvailable = fast?.engine === 'fastapi-ats-format-v1',
    } = atsOutcome;
    let parsedCv = null;
    let parseEngine = 'unavailable';
    if (parseOutcome?.parsedCv) {
      parsedCv = parseOutcome.parsedCv;
      parseEngine = parseOutcome.engine;
    }

    const parserPreview = parsedCv ? previewTextFromParsedCv(parsedCv) : '';
    const contact = parsedCv ? contactFromParsedCv(parsedCv) : { fullName: '', email: '' };
    const finalExtractedText =
      parserPreview ||
      atsExtractedText ||
      `Uploaded for ATS format check: ${originalFileName}`;

    const doc = await CVDocument.create({
      userId: req.userId,
      originalFileName,
      fileType: ext,
      extractedText: finalExtractedText,
      documentStage: 'analyzed',
      generatedBy: 'user',
      fileUrl: '',
    });
    await CVVersion.create({
      userId: req.userId,
      documentId: doc._id,
      versionNo: 1,
    });

    const ats = await ATSCheckReport.create({
      documentId: doc._id,
      ...atsCreateFields(fast),
    });

    const spec = inferSpecialization(doc.extractedText);
    const profile = await CVParsedProfile.create({
      documentId: doc._id,
      fullNameExtracted: contact.fullName,
      emailExtracted: contact.email,
      specializationDetected: spec,
      rawJson: JSON.stringify(
        parsedCv
          ? envelopeForStorage(parsedCv, parseEngine)
          : {
              engine: engine || fast.templateId,
              score: fast.score,
              issues: fast.missingKeywords,
            },
      ),
    });

    const assessment = await SkillAssessment.create({
      profileId: profile._id,
      targetSpecialization: spec,
      strengthScore: fast.score,
      breakdownJson: JSON.stringify({
        format: fast.formatScore,
        keywords: fast.keywordsChecked,
        total: fast.keywordsTotal,
      }),
    });

    const recs = [
      {
        assessmentId: assessment._id,
        recType: 'keyword',
        title: 'ATS format issues',
        description: fast.recommendationBullets[0] || 'Apply ATS format recommendations.',
        priority: 'high',
      },
      {
        assessmentId: assessment._id,
        recType: 'format',
        title: 'Structure',
        description: fast.recommendationBullets[1] || 'Use clear section headings and simple layout.',
        priority: 'medium',
      },
      {
        assessmentId: assessment._id,
        recType: 'metrics',
        title: 'Readability',
        description: fast.recommendationBullets[2] || 'Keep content plain text and concise.',
        priority: 'medium',
      },
    ];
    await Recommendation.insertMany(recs);

    return res.status(201).json({
      document: serializeCv(doc, ats),
      profileId: profile._id.toString(),
      parsedCv,
      parseEngine,
      atsEngine: fast.engine || engine,
      atsAvailable: Boolean(atsAvailable),
    });
  } catch (err) {
    console.error(err);
    const code = err.statusCode === 503 ? 503 : 500;
    return res.status(code).json({
      error: err.message || 'Upload analysis failed',
    });
  }
}

/**
 * Save analysis results computed by the Flutter app from the user's local
 * ATS engine (port 8000) and CV parser (port 8001).
 *
 * Body shape:
 * {
 *   originalFileName: string,
 *   fileType: 'pdf' | 'docx',
 *   ats: {                         // raw FastAPI JSON (decision, failures, …)
 *     decision: 'PASS' | 'FAIL',
 *     failed_basic: boolean,
 *     failed_rules_count: number,
 *     failures: [{ rule_id, severity, issue, fix }],
 *     recommendation?: { message?: string, improvements?: string[] },
 *   },
 *   parsedCv?: object,             // make_portfolio_json shape (optional)
 *   parseEngine?: string,
 * }
 */
async function saveLocalAnalysis(req, res) {
  try {
    const {
      originalFileName,
      fileType,
      ats: atsRaw,
      parsedCv = null,
      parseEngine = '',
    } = req.body || {};

    const fileName = String(originalFileName || '').trim();
    const ext = String(fileType || '').toLowerCase();
    if (!fileName) {
      return res.status(400).json({ error: 'originalFileName required' });
    }
    if (!['pdf', 'docx'].includes(ext)) {
      return res.status(400).json({ error: 'fileType must be pdf or docx' });
    }
    if (!atsRaw || typeof atsRaw !== 'object') {
      return res.status(400).json({ error: 'ats result object required' });
    }

    const decision = String(atsRaw.decision || 'FAIL').toUpperCase();
    const failedBasic = Boolean(atsRaw.failed_basic);
    const failedRulesCount = Number(atsRaw.failed_rules_count) || 0;
    const failuresRaw = Array.isArray(atsRaw.failures) ? atsRaw.failures : [];
    const failures = failuresRaw
      .map((f) => ({
        ruleId: String(f?.rule_id || f?.ruleId || '').trim(),
        severity: String(f?.severity || '').trim(),
        issue: String(f?.issue || '').trim(),
        fix: String(f?.fix || '').trim(),
      }))
      .filter((f) => f.issue || f.fix);
    const recommendation =
      atsRaw.recommendation && typeof atsRaw.recommendation === 'object'
        ? atsRaw.recommendation
        : {};
    const improvements = Array.isArray(recommendation.improvements)
      ? recommendation.improvements.map((s) => String(s).trim()).filter(Boolean)
      : [];
    const issues = failures.map((f) => f.issue).filter(Boolean);

    const score =
      decision === 'PASS'
        ? 100
        : Math.min(99, Math.max(5, 100 - failedRulesCount * 10 - (failedBasic ? 25 : 0)));

    const PASS_SCORE_THRESHOLD = 70;
    const scoreDecision = score > PASS_SCORE_THRESHOLD ? 'PASS' : 'FAIL';

    const atsFields = {
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
      recommendationBullets: [...new Set(improvements.concat(failures.map((f) => f.fix)))]
        .filter(Boolean)
        .slice(0, 8),
      suitabilityHeadline:
        String(recommendation.message || '').trim() ||
        (scoreDecision === 'PASS'
          ? 'ATS format check passed'
          : failedBasic
            ? 'Critical ATS format issues found'
            : 'ATS format check found issues to fix'),
      issuesSummary: `Local Uvicorn ATS (${fileName}) — ${decision}, ${failedRulesCount} failed rule(s)`,
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

    const previewText = parsedCv ? previewTextFromParsedCv(parsedCv) : '';
    const contact = parsedCv
      ? contactFromParsedCv(parsedCv)
      : { fullName: '', email: '' };

    const doc = await CVDocument.create({
      userId: req.userId,
      originalFileName: fileName,
      fileType: ext,
      extractedText: previewText || `Uploaded CV: ${fileName}`,
      documentStage: 'analyzed',
      generatedBy: 'user',
      fileUrl: '',
    });
    await CVVersion.create({
      userId: req.userId,
      documentId: doc._id,
      versionNo: 1,
    });

    const ats = await ATSCheckReport.create({
      documentId: doc._id,
      ...atsCreateFields(atsFields),
    });

    const spec = inferSpecialization(doc.extractedText);
    const profile = await CVParsedProfile.create({
      documentId: doc._id,
      fullNameExtracted: contact.fullName,
      emailExtracted: contact.email,
      specializationDetected: spec,
      rawJson: JSON.stringify(
        parsedCv
          ? envelopeForStorage(parsedCv, parseEngine || 'llama-lora-cv-parser-v1')
          : { engine: 'fastapi-ats-format-v1', score, issues },
      ),
    });

    await SkillAssessment.create({
      profileId: profile._id,
      targetSpecialization: spec,
      strengthScore: score,
      breakdownJson: JSON.stringify({
        format: score,
        rulesFailed: failedRulesCount,
      }),
    });

    return res.status(201).json({
      document: serializeCv(doc, ats),
      profileId: profile._id.toString(),
      parsedCv,
      parseEngine: parseEngine || (parsedCv ? 'llama-lora-cv-parser-v1' : 'unavailable'),
      atsEngine: 'fastapi-ats-format-v1',
      atsAvailable: true,
    });
  } catch (err) {
    console.error('[cv.saveLocalAnalysis]', err);
    return res.status(500).json({
      error: err.message || 'Save analysis failed',
    });
  }
}

module.exports = {
  listDocuments,
  createDocument,
  getDocument,
  getParsedProfile,
  deleteDocument,
  analyzeDocument,
  uploadAndAnalyzeFile,
  saveLocalAnalysis,
};
