const mongoose = require('mongoose');

const recommendationSchema = new mongoose.Schema(
  {
    assessmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'SkillAssessment',
      required: true,
      index: true,
    },
    recType: { type: String, default: '' },
    title: { type: String, default: '' },
    description: { type: String, default: '' },
    url: { type: String, default: '' },
    priority: { type: String, default: '' },
  },
  { timestamps: false },
);

module.exports = mongoose.model('Recommendation', recommendationSchema);
