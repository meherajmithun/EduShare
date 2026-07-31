/**
 * controllers/authController.js — Register, Login, Profile
 *
 * Roles visible in UI: student, contributor, Admin (= faculty_admin backend role)
 * Roles hidden from UI: super_admin (seeded only), admin (legacy)
 *
 * Admin ("faculty_admin") registration:
 *  - Sets status = 'pending'
 *  - Does NOT return a JWT (must await Super Admin approval)
 *  - Sends a notification to the Super Admin
 *
 * Login blocks accounts with status = 'pending', 'rejected', or 'disabled'.
 */

const User = require('../models/User');
const Department = require('../models/Department');
const { signToken } = require('../middleware/auth');
const { success, fail, createError } = require('../utils/apiResponse');
const {
  notifySuperAdminOnNewAdmin,
  notifyFacultyAdminOnContributorRegistration,
} = require('../services/notificationService');

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

// ─── Valid self-registerable roles ──
const SELF_REGISTER_ROLES = ['student', 'contributor', 'admin', 'faculty_admin'];

// ─── POST /api/auth/register ──────────────────────────────────────────
//
// Contributor workflow:
//   status = 'pending' → no JWT issued → Faculty Admin notified.
//   Admin workflow:
//   status = 'pending' → no JWT issued → Super Admin notified.
//   Student workflow: status = 'active' → JWT issued immediately.
const register = async (req, res) => {
  const { name, email, password, role, department, facultyId, designation } = req.body;

  if (!name || !email || !password || !role || !department) {
    throw createError('All fields are required: name, email, password, role, department.', 400);
  }

  if (password.length < 6) {
    throw createError('Password must be at least 6 characters.', 400);
  }

  if (!isAllowedEmail(email)) {
    throw createError('Only university emails are allowed (e.g. name@bubt.edu.bd).', 400);
  }

  // Block super_admin self-registration via this endpoint
  if (!SELF_REGISTER_ROLES.includes(role)) {
    throw createError(
      'Invalid role selected.',
      400
    );
  }

  const existing = await User.findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    throw createError('An account with this email already exists. Please log in instead.', 409);
  }

  // ── Contributor → pending approval ──────────────────────────────────────
  if (role === 'contributor') {
    const contributor = await User.create({
      name,
      email,
      password,
      role: 'contributor',
      department,
      status: 'pending', // Blocked until Faculty Admin approves
    });

    // Find the active Faculty Admin for this department (by name match)
    const facultyAdmin = await User.findOne({
      role: { $in: ['faculty_admin', 'admin'] },
      status: 'active',
      department,
    });

    // Notify Faculty Admin (fire-and-forget)
    notifyFacultyAdminOnContributorRegistration({ contributor, facultyAdmin });

    return res.status(201).json(
      success(
        { pending: true, userId: contributor._id.toString() },
        'Registration submitted. Your account is pending Faculty Admin approval. You will be notified once approved.'
      )
    );
  }

  // ── Admin / Faculty Admin → pending approval ──────────────────────────────
  if (role === 'admin' || role === 'faculty_admin') {
    let deptId = null;
    if (department) {
      const escaped = department.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      let dept = await Department.findOne({ name: new RegExp('^' + escaped + '$', 'i') });
      if (!dept) {
        dept = await Department.create({
          name: department.trim(),
          code: department.trim().substring(0, 4).toUpperCase().replace(/[^A-Z]/gi, '') || 'DEPT',
        });
      }
      deptId = dept._id;
    }

    const adminUser = await User.create({
      name,
      email,
      password,
      role: 'faculty_admin',
      department: department.trim(),
      departmentId: deptId,
      facultyId: facultyId || '',
      designation: designation || '',
      status: 'pending', // Blocked until Super Admin approves
    });

    // Notify Super Admin (fire-and-forget)
    notifySuperAdminOnNewAdmin({ newAdmin: adminUser });

    return res.status(201).json(
      success(
        { pending: true, userId: adminUser._id.toString() },
        'Your Admin application is waiting for Super Admin approval.'
      )
    );
  }

  // ── Student → active immediately ───────────────────────────────────────
  let studentDeptId = null;
  if (department) {
    const escaped = department.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    let dept = await Department.findOne({ name: new RegExp('^' + escaped + '$', 'i') });
    if (dept) studentDeptId = dept._id;
  }

  const user = await User.create({
    name,
    email,
    password,
    role,
    department: department.trim(),
    departmentId: studentDeptId,
    status: 'active',
  });
  const token = signToken(user._id);

  res.status(201).json(
    success({ token, user }, 'Account created successfully.')
  );
};

// ─── POST /api/auth/register-faculty-admin ────────────────────────────
// Submits an Admin registration request (status = pending).
// Does NOT return a JWT — must be approved by Super Admin first.
// Notifies the Super Admin automatically.
const registerFacultyAdmin = async (req, res) => {
  const { name, facultyId, email, password, departmentId, designation, profilePhotoUrl } = req.body;

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

  const dept = await Department.findById(departmentId);
  if (!dept) {
    throw createError('Selected department not found.', 404);
  }

  const existing = await User.findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    throw createError('An account with this email already exists.', 409);
  }

  // Create pending Admin (backend role = faculty_admin, shown as "Admin" in UI)
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

  // ── Notify the Super Admin (fire-and-forget) ────────────────────────
  notifySuperAdminOnNewAdmin({ newAdmin: user });

  res.status(201).json(
    success(
      { userId: user._id.toString() },
      'Your Admin application is waiting for Super Admin approval.'
    )
  );
};

// ─── GET /api/auth/account-status?email= ──────────────────────────────
const getAccountStatus = async (req, res) => {
  const { email } = req.query;
  if (!email || !email.trim()) {
    throw createError('Email parameter is required.', 400);
  }

  const user = await User.findOne({ email: email.toLowerCase().trim() });
  if (!user) {
    throw createError('No account found with this email address.', 404);
  }

  let message = 'Account is active.';
  if (user.status === 'pending') {
    message = (user.role === 'admin' || user.role === 'faculty_admin')
      ? 'Your Admin application is still under review.'
      : 'Your contributor account is still under review.';
  } else if (user.status === 'rejected') {
    const reason = user.rejectionReason || 'No reason provided.';
    message = (user.role === 'admin' || user.role === 'faculty_admin')
      ? `Your Admin application was rejected. Reason: ${reason}`
      : `Your contributor registration was rejected. Reason: ${reason}`;
  } else if (user.status === 'disabled') {
    message = 'Your account has been disabled. Please contact support.';
  }

  res.json(
    success(
      {
        status: user.status,
        role: user.role,
        message,
        rejectionReason: user.rejectionReason || null,
      },
      'Account status fetched.'
    )
  );
};

// ─── POST /api/auth/login ─────────────────────────────────────────────
const login = async (req, res) => {
  const { email, password, role } = req.body;

  if (!email || !password || !role) {
    throw createError('Email, password, and role are required.', 400);
  }

  const validRoles = ['student', 'contributor', 'admin', 'faculty_admin', 'super_admin'];
  if (!validRoles.includes(role)) {
    throw createError('Invalid role selected.', 400);
  }

  const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');

  if (!user) {
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  const passwordMatch = await user.comparePassword(password);
  if (!passwordMatch) {
    throw createError('Invalid credentials. Please check your email and password.', 401);
  }

  // Role check — allow super_admin to log in via the 'faculty_admin' / Admin UI chip
  if (user.role !== role) {
    if (user.role === 'super_admin' && (role === 'faculty_admin' || role === 'admin')) {
      // Allowed: Super Admin logs in via the "Admin" chip since Super Admin is hidden from UI
    } else {
      throw createError(
        `Selected role does not match your registered account. You registered as "${user.role}".`,
        401
      );
    }
  }

  // Status check — block pending, rejected, and disabled accounts
  if (user.status === 'pending') {
    if (user.role === 'contributor') {
      throw createError(
        'Your contributor account is pending Faculty Admin approval. You will be notified once approved.',
        403
      );
    }
    throw createError(
      'Your Admin application is still under review.',
      403
    );
  }

  if (user.status === 'rejected') {
    const reason = user.rejectionReason || 'No reason provided.';
    if (user.role === 'contributor') {
      throw createError(
        `Your contributor registration was rejected. Reason: ${reason}`,
        403
      );
    }
    throw createError(
      `Your Admin application was rejected. Reason: ${reason}`,
      403
    );
  }

  if (user.status === 'disabled') {
    throw createError(
      'Your account has been disabled. Please contact support.',
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

const { uploadBuffer } = require('../services/cloudinaryService');

// ─── GET /api/auth/profile ────────────────────────────────────────────
const getProfile = async (req, res) => {
  res.json(success(req.user, 'Profile fetched successfully.'));
};

// ─── PUT /api/auth/profile ────────────────────────────────────────────
const updateProfile = async (req, res) => {
  const { name, bio, designation, profilePhotoUrl } = req.body;
  const user = await User.findById(req.user._id);
  if (!user) throw createError('User not found.', 404);

  if (name !== undefined && name.trim().length > 0) user.name = name.trim();
  if (bio !== undefined) user.bio = bio.trim();
  if (designation !== undefined) user.designation = designation.trim();
  if (profilePhotoUrl !== undefined) user.profilePhotoUrl = profilePhotoUrl.trim();

  await user.save();
  const updatedUser = await User.findById(user._id).select('-password');
  res.json(success(updatedUser, 'Profile updated successfully.'));
};

// ─── POST /api/auth/profile/photo ─────────────────────────────────────
const uploadProfilePhoto = async (req, res) => {
  if (!req.file || !req.file.buffer) {
    throw createError('No photo file provided.', 400);
  }

  const result = await uploadBuffer(req.file.buffer, 'edushare/profiles');
  const photoUrl = result.url;

  if (req.user) {
    await User.findByIdAndUpdate(req.user._id, { profilePhotoUrl: photoUrl });
  }

  res.json(success({ profilePhotoUrl: photoUrl }, 'Profile photo uploaded successfully.'));
};

module.exports = {
  register,
  registerFacultyAdmin,
  getAccountStatus,
  login,
  getProfile,
  updateProfile,
  uploadProfilePhoto,
};
