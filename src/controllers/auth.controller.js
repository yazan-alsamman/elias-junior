const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { User } = require('../models');

function signToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: '7d' });
}

async function register(req, res) {
  try {
    const { fullName, email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    const nameTrim = fullName != null ? String(fullName).trim() : '';
    if (!nameTrim) {
      return res.status(400).json({ error: 'Full name required' });
    }
    const emailNorm = String(email).toLowerCase().trim();
    const existing = await User.findOne({ email: emailNorm });
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    const passwordHash = await bcrypt.hash(String(password), 10);
    const user = await User.create({
      fullName: nameTrim,
      email: emailNorm,
      passwordHash,
    });
    console.log(
      `[auth] register ok email=${user.email} id=${user._id} db=${mongoose.connection.name}`,
    );
    const token = signToken(user._id.toString());
    return res.status(201).json({
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (err) {
    if (err && err.code === 11000) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    console.error('[auth] register failed:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function login(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required' });
    }
    const user = await User.findOne({ email: String(email).toLowerCase().trim() });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const ok = await bcrypt.compare(String(password), user.passwordHash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const token = signToken(user._id.toString());
    return res.json({
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
      },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function me(req, res) {
  try {
    const user = await User.findById(req.userId).select('-passwordHash');
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json({ user });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { register, login, me };
