const mongoose = require('mongoose');

const cvParsedProfileSchema = new mongoose.Schema(
  {
    documentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVDocument',
      required: true,
      index: true,
    },
    fullNameExtracted: { type: String, default: '' },
    emailExtracted: { type: String, default: '' },
    specializationDetected: { type: String, default: '' },
    rawJson: { type: String, default: '{}' },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('CVParsedProfile', cvParsedProfileSchema);
