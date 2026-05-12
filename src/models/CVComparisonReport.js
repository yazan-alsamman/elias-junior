const mongoose = require('mongoose');

const cvComparisonReportSchema = new mongoose.Schema(
  {
    oldVersionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVVersion',
      required: true,
      index: true,
    },
    newVersionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVVersion',
      required: true,
      index: true,
    },
    improvementScore: { type: Number, default: 0 },
    breakdownJson: { type: String, default: '{}' },
    changeSummaryJson: { type: String, default: '{}' },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('CVComparisonReport', cvComparisonReportSchema);
