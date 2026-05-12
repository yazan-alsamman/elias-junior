const mongoose = require('mongoose');

const skillAssessmentSchema = new mongoose.Schema(
  {
    profileId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVParsedProfile',
      required: true,
      index: true,
    },
    targetSpecialization: { type: String, default: '' },
    strengthScore: { type: Number, default: 0 },
    breakdownJson: { type: String, default: '{}' },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('SkillAssessment', skillAssessmentSchema);
