const { CVDocument, ATSCheckReport } = require('../models');

async function summary(req, res) {
  try {
    const latestDoc = await CVDocument.findOne({ userId: req.userId })
      .sort({ uploadedAt: -1 })
      .exec();
    if (!latestDoc) {
      return res.json({
        latestReport: null,
        progressPercent: 0,
        activeStepIndex: 0,
      });
    }
    const ats = await ATSCheckReport.findOne({ documentId: latestDoc._id })
      .sort({ createdAt: -1 })
      .exec();
    if (!ats) {
      return res.json({
        latestReport: null,
        progressPercent: 25,
        activeStepIndex: 1,
      });
    }
    const o = ats.toObject();
    const progressPercent = Math.min(95, 35 + Math.round((o.score || 0) / 2.2));
    const report = {
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
    return res.json({
      latestReport: report,
      progressPercent,
      activeStepIndex: 2,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { summary };
