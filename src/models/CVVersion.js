const mongoose = require('mongoose');

const cvVersionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    documentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVDocument',
      required: true,
      index: true,
    },
    versionNo: { type: Number, default: 1 },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('CVVersion', cvVersionSchema);
