const mongoose = require('mongoose');

const cvDocumentSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    originalFileName: { type: String, default: '' },
    extractedText: { type: String, default: '' },
    fileUrl: { type: String, default: '' },
    fileType: { type: String, default: '' },
    uploadedAt: { type: Date, default: Date.now },
    parentDocumentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVDocument',
      default: null,
    },
    generatedBy: { type: String, required: true },
    documentStage: { type: String, required: true },
  },
  { timestamps: false },
);

module.exports = mongoose.model('CVDocument', cvDocumentSchema);
