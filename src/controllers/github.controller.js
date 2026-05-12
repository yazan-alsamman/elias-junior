const { GitHubAccount } = require('../models');

async function getGithub(req, res) {
  try {
    const row = await GitHubAccount.findOne({ userId: req.userId }).lean();
    if (!row) {
      return res.json({ github: null });
    }
    return res.json({
      github: {
        id: row._id.toString(),
        githubUsername: row.githubUsername,
        linkedAt: row.linkedAt,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function linkGithub(req, res) {
  try {
    const { githubUsername } = req.body;
    if (!githubUsername || String(githubUsername).trim() === '') {
      return res.status(400).json({ error: 'githubUsername required' });
    }
    const account = await GitHubAccount.findOneAndUpdate(
      { userId: req.userId },
      {
        userId: req.userId,
        githubUsername: String(githubUsername).trim(),
        linkedAt: new Date(),
      },
      { upsert: true, new: true },
    );
    return res.json({
      github: {
        id: account._id.toString(),
        githubUsername: account.githubUsername,
        linkedAt: account.linkedAt,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { getGithub, linkGithub };
