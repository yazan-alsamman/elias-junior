const mongoose = require('mongoose');

const portfolioSchema = new mongoose.Schema(
  {
    profileId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CVParsedProfile',
      required: true,
      index: true,
    },
    templateId: { type: String, default: 'classic' },
    portfolioUrl: { type: String, default: '' },
    /** GitHub login for public page project links */
    githubUsername: { type: String, default: '', trim: true },
    /** Repo slugs as entered in the app (shown on /p/:slug) */
    projectRepos: { type: [String], default: [] },
    /** Public page: GET {PUBLIC_BASE_URL}/p/{publicSlug} */
    publicSlug: {
      type: String,
      trim: true,
      lowercase: true,
      sparse: true,
      unique: true,
      index: true,
    },
    /** Stored app preview (name, bio, skills, projects…) so /p/:slug matches in-app generation */
    previewSnapshot: { type: mongoose.Schema.Types.Mixed, default: null },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false },
);

module.exports = mongoose.model('Portfolio', portfolioSchema, 'portfolios');
