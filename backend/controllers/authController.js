/**
 * controllers/authController.js — Register, Login, Profile
 *
 * Supports 5 roles: student, contributor, admin (legacy), faculty_admin, super_admin
 *
 * Faculty Admin registration is a SEPARATE endpoint that:
 *  - Sets status = 'pending'
 *  - Does NOT return a JWT (user must await Super Admin approval)
 *
 * Login blocks accounts with status = 'pending' or 'disabled'.
 */

const User = require('../models/User');
const Department = require('../models/Department');
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

// ─── Valid self-registerable roles (super_admin can only be seeded) ────
const SELF_REGISTER_ROLES = ['student', 'contributor', 'admin'];

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

  // University email enforcement
  if (!isAllowedEmail(email)) {
    throw createError('Only university emails are allowed (e.g. name@bubt.edu.bd).', 400);
  }

  // Role validation — block super_admin self-registration
  if (!SELF_REGISTER_ROLES.includes(role)) {
    throw createError(
      'Invalid role. Use the Faculty Admin registration form for faculty_admin role.',
      400
    );
  }

  // Check for duplicate email
  const existing = await User.findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    throw createError('An account with this email already exists. Please log in instead.', 409);
  }

  // Create user — password is hashed in the pre-save hook
  const user = await User.create({ name, email, password, role, department, status: 'active' });

  const token = signToken(user._id);

  res.status(201).json(
    success({ token, user }, 'Account created successfully.')
  );
};

// ─── POST /api/auth/register-faculty-admin ────────────────────────────
// Submits a Faculty Admin registration request (status = pending).
// Does NOT return a JWT — user must be approved by Super Admin first.
const registerFacultyAdmin = async (req, res) => {
  const { name, facultyId, email, password, departmentId, designation, profilePhotoUrl } = req.body;

  // Required fields
  if (!name || !facultyId || !email || !password || !departmentId || !designation) {
    throw createError(
      'All fields are required: name, facultyId, email, password, departmentId, designation.',
      400
    );
  }

  if (password.length < 6) {
    throw createError('Password must be at least 6 characters.', 400);
  }

  if (!isAllowedEmail(email)) {
    throw createError('Only university emails are allowed (e.g. name@bubt.edu.bd).', 400);
  }

  // Resolve department name from ID
  const dept = await Department.findById(departmentId);
  if (!dept) {
    throw createError('Selected department not found.', 404);
  }

  // Check for duplicate email
  const existing = await User.findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    throw createError('An account with this email already exists.', 409);
  }

  // Create pending Faculty Admin
  const user = await User.create({
    name,
    email,
    password,
    role: 'faculty_admin',
    status: 'pending',
    department: dept.name,
    departmentId: dept._id,
    facultyId,
    designation,
    profilePhotoUrl: profilePhotoUrl || '',
    isActive: true,
  });

  res.status(201).json(
    success(
      { userId: user._id.toString() },
      'Faculty Admin registration submitted successfully. Awaiting Super Admin approval.'
    )
  );
};

// ─── POST /api/auth/login ─────────────────────────────────────────────
const login = async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password || !role) {
    throw createError('Email, password, and role are required.', 400);
  }

  // Validate role string
  const validRoles = ['student', 'contributor', 'admin', 'faculty_admin', 'super_admin'];
  if (!validRoles.includes(role)) {
    throw createError('Invalid role selected.', 400);
  }

  // Fetch user WITH password (select: false by default)
  const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');

  if (!user) {
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  // Verify password
  const passwordMatch = await user.comparePassword(password);
  if (!passwordMatch) {
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  // Role check — must match exactly
  if (user.role !== role) {
    throw createError(
      `Selected role does not match your registered account. You registered as "${user.role}".`,
      401
    );
  }

  // Status check — block pending and disabled accounts
  if (user.status === 'pending') {
    throw createError(
      'Your Faculty Admin registration is pending Super Admin approval. You will be notified once approved.',
      403
    );
  }

  if (user.status === 'disabled') {
    throw createError(
      'Your account has been disabled. Please contact the Super Admin.',
      403
    );
  }

  if (!user.isActive) {
    throw createError('Your account has been deactivated. Contact support.', 401);
  }

  const token = signToken(user._id);

  const userJSON = user.toJSON();

  res.json(success({ token, user: userJSON }, 'Logged in successfully.'));
};

// ─── GET /api/auth/profile ────────────────────────────────────────────
const getProfile = async (req, res) => {
  res.json(success(req.user, 'Profile fetched successfully.'));
};

module.exports = { register, registerFacultyAdmin, login, getProfile };
