const mongoose = require('mongoose');

const atsCheckReportSchema = new mongoose.Schema(
  {
    documentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVDocument',
      required: true,
      index: true,
    },
    score: { type: Number, default: 0 },
    status: { type: String, required: true },
    extractedTextLength: { type: Number, default: 0 },
    keywordsChecked: { type: Number, default: 0 },
    keywordsTotal: { type: Number, default: 0 },
    formatScore: { type: Number, default: 0 },
    sectionMatch: { type: String, default: '' },
    estimatedSecondsLeft: { type: Number, default: 0 },
    missingKeywords: [{ type: String }],
    recommendationBullets: [{ type: String }],
    suitabilityHeadline: { type: String, default: '' },
    issuesSummary: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now },
    severity: { type: String, default: '' },
    canAutoFix: { type: Boolean, required: true, default: false },
    autoFixApplied: { type: Boolean, required: true, default: false },
    fixedDocumentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVDocument',
      default: null,
    },
    failureReason: { type: String, default: '' },
    templateId: { type: String, default: '' },
  },
  { timestamps: false },
);

module.exports = mongoose.model('ATSCheckReport', atsCheckReportSchema);
