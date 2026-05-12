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
      out.push(serializeCv(full, ats));
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
    return res.json({ document: serializeCv(doc, ats) });
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
      score: h.score,
      status: h.status,
      extractedTextLength: h.extractedTextLength,
      keywordsChecked: h.keywordsChecked,
      keywordsTotal: h.keywordsTotal,
      formatScore: h.formatScore,
      sectionMatch: h.sectionMatch,
      estimatedSecondsLeft: h.estimatedSecondsLeft,
      missingKeywords: h.missingKeywords,
      recommendationBullets: h.recommendationBullets,
      suitabilityHeadline: h.suitabilityHeadline,
      issuesSummary: h.issuesSummary,
      severity: h.severity,
      canAutoFix: h.canAutoFix,
      autoFixApplied: h.autoFixApplied,
      failureReason: h.failureReason,
      templateId: h.templateId,
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

module.exports = {
  listDocuments,
  createDocument,
  getDocument,
  deleteDocument,
  analyzeDocument,
};
