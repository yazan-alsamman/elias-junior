const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    fullName: { type: String, trim: true, default: '' },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: { type: String, required: true },
  },
  { timestamps: { createdAt: 'createdAt', updatedAt: false } },
);

// Third arg fixes collection name to "users" (Compass: db from MONGODB_URI → collection users).
module.exports = mongoose.model('User', userSchema, 'users');
