const mongoose = require('mongoose');

const gitHubAccountSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    githubUsername: { type: String, trim: true, default: '' },
    linkedAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('GitHubAccount', gitHubAccountSchema);
