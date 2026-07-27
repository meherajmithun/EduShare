/**
 * controllers/authController.js — Register, Login, Profile
 */

const User = require('../models/User');
const { signToken } = require('../middleware/auth');
const { success, fail, createError } = require('../utils/apiResponse');

// ─── Allowed university email domains ─────────────────────────────────
const ALLOWED_DOMAINS = ['bubt.edu.bd'];
const BLOCKED_DOMAINS = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'mail.com', 'protonmail.com'];

const isAllowedEmail = (email) => {
  const lower = email.toLowerCase().trim();
  for (const blocked of BLOCKED_DOMAINS) {
    if (lower.endsWith(`@${blocked}`)) return false;
  }
  for (const allowed of ALLOWED_DOMAINS) {
    if (lower.endsWith(`@${allowed}`)) return true;
  }
  return false;
};

// ─── POST /api/auth/register ──────────────────────────────────────────
const register = async (req, res) => {
  const { name, email, password, role, department } = req.body;

  // Field validation
  if (!name || !email || !password || !role || !department) {
    throw createError('All fields are required: name, email, password, role, department.', 400);
  }

  if (password.length < 6) {
    throw createError('Password must be at least 6 characters.', 400);
  }

  // University email enforcement (server-side mirror of Flutter validation)
  if (!isAllowedEmail(email)) {
    throw createError('Only university emails are allowed (e.g. name@bubt.edu.bd).', 400);
  }

  // Role validation
  if (!['student', 'contributor', 'admin'].includes(role)) {
    throw createError('Role must be student, contributor, or admin.', 400);
  }

  // Check for duplicate email
  const existing = await User.findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    throw createError('An account with this email already exists. Please log in instead.', 409);
  }

  // Create user — password is hashed in the pre-save hook
  const user = await User.create({ name, email, password, role, department });

  const token = signToken(user._id);

  res.status(201).json(
    success({ token, user }, 'Account created successfully.')
  );
};

// ─── POST /api/auth/login ─────────────────────────────────────────────
const login = async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password || !role) {
    throw createError('Email, password, and role are required.', 400);
  }

  // Fetch user WITH password (select: false by default)
  const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');

  if (!user) {
    // Generic message — don't reveal whether the email exists
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  // Verify password
  const passwordMatch = await user.comparePassword(password);
  if (!passwordMatch) {
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  // Role check — matches the Flutter behaviour exactly
  if (user.role !== role) {
    throw createError(
      `Selected role does not match your registered account. You registered as "${user.role}".`,
      401
    );
  }

  if (!user.isActive) {
    throw createError('Your account has been deactivated. Contact support.', 401);
  }

  const token = signToken(user._id);

  // Strip password from response (toJSON transform handles _id/__v)
  const userJSON = user.toJSON();

  res.json(success({ token, user: userJSON }, 'Logged in successfully.'));
};

// ─── GET /api/auth/profile ────────────────────────────────────────────
const getProfile = async (req, res) => {
  // req.user is set by the protect middleware
  res.json(success(req.user, 'Profile fetched successfully.'));
};

module.exports = { register, login, getProfile };
