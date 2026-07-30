/**
 * controllers/superAdminController.js — Super Admin management of Admins
 *
 * All endpoints require role = 'super_admin'.
 *
 * Admin lifecycle (backend role = faculty_admin, shown as "Admin" in the Flutter UI):
 *   register (pending) → approve (active) → disable / delete
 *                      → reject (status = 'rejected', record kept, reason stored)
 */

const User = require('../models/User');
const Material = require('../models/Material');
const { success, createError } = require('../utils/apiResponse');
const {
  notifyAdminOnApproval,
  notifyAdminOnRejection,
} = require('../services/notificationService');

// ─── GET /api/super-admin/faculty-admins/pending ───────────────────────
// List all Admins awaiting approval
const getPendingFacultyAdmins = async (req, res) => {
  const pending = await User.find({ role: { $in: ['faculty_admin', 'admin'] }, status: 'pending' })
    .sort({ createdAt: 1 })
    .select('-password');
  res.json(success(pending, 'Pending Admin registrations fetched.'));
};

// ─── GET /api/super-admin/faculty-admins ──────────────────────────────
// List all Admins (any status). Pass ?status=pending|active|disabled|rejected
const getAllFacultyAdmins = async (req, res) => {
  const { status } = req.query;
  const filter = { role: { $in: ['faculty_admin', 'admin'] } };
  if (status) filter.status = status;

  const admins = await User.find(filter)
    .sort({ createdAt: -1 })
    .select('-password');
  res.json(success(admins, 'Admins fetched.'));
};

// ─── PUT /api/super-admin/faculty-admins/:id/approve ──────────────────
// Approve a pending Admin → status becomes 'active'.
// Sets verifiedBy/verifiedAt. Notifies the Admin.
const approveFacultyAdmin = async (req, res) => {
  const admin = await User.findOne({ _id: req.params.id, role: { $in: ['faculty_admin', 'admin'] } });
  if (!admin) throw createError('Admin not found.', 404);

  if (admin.status === 'active') {
    throw createError('This Admin is already approved.', 400);
  }

  admin.status = 'active';
  admin.verifiedBy = req.user._id;
  admin.verifiedAt = new Date();
  admin.rejectionReason = null;
  await admin.save();

  // ── Notify the Admin (fire-and-forget) ────────────────────────────────
  notifyAdminOnApproval({ admin, superAdmin: req.user });

  res.json(success(admin.toJSON(), 'Admin approved successfully. They can now log in.'));
};

// ─── PUT /api/super-admin/faculty-admins/:id/reject ───────────────────
// Reject a pending Admin.
// Status becomes 'rejected', reason is stored, record is KEPT for audit.
// Notifies the Admin with the rejection reason.
const rejectFacultyAdmin = async (req, res) => {
  const admin = await User.findOne({ _id: req.params.id, role: { $in: ['faculty_admin', 'admin'] } });
  if (!admin) throw createError('Admin not found.', 404);

  if (admin.status !== 'pending') {
    throw createError('Only pending registrations can be rejected.', 400);
  }

  const reason = (req.body.reason && req.body.reason.trim())
    ? req.body.reason.trim()
    : 'No reason provided.';

  admin.status = 'rejected';
  admin.verifiedBy = req.user._id;
  admin.verifiedAt = new Date();
  admin.rejectionReason = reason;
  await admin.save();

  // ── Notify the Admin (fire-and-forget) ────────────────────────────────
  notifyAdminOnRejection({ admin, superAdmin: req.user, reason });

  res.json(success(admin.toJSON(), 'Admin registration rejected.'));
};

// ─── PUT /api/super-admin/faculty-admins/:id/disable ──────────────────
// Disable an active Admin (reversible)
const disableFacultyAdmin = async (req, res) => {
  const admin = await User.findOne({ _id: req.params.id, role: { $in: ['faculty_admin', 'admin'] } });
  if (!admin) throw createError('Admin not found.', 404);

  if (admin.status === 'disabled') {
    throw createError('This Admin is already disabled.', 400);
  }

  admin.status = 'disabled';
  await admin.save();

  res.json(success(admin.toJSON(), 'Admin has been disabled.'));
};

// ─── PUT /api/super-admin/faculty-admins/:id/enable ───────────────────
// Re-enable a disabled Admin
const enableFacultyAdmin = async (req, res) => {
  const admin = await User.findOne({ _id: req.params.id, role: { $in: ['faculty_admin', 'admin'] } });
  if (!admin) throw createError('Admin not found.', 404);

  if (admin.status !== 'disabled') {
    throw createError('Only disabled Admins can be re-enabled.', 400);
  }

  admin.status = 'active';
  await admin.save();

  res.json(success(admin.toJSON(), 'Admin has been re-enabled.'));
};

// ─── DELETE /api/super-admin/faculty-admins/:id ────────────────────────
// Hard delete an Admin account
const deleteFacultyAdmin = async (req, res) => {
  const admin = await User.findOne({ _id: req.params.id, role: { $in: ['faculty_admin', 'admin'] } });
  if (!admin) throw createError('Admin not found.', 404);

  await User.findByIdAndDelete(req.params.id);

  res.json(success(null, 'Admin account permanently deleted.'));
};

// ─── GET /api/super-admin/stats ────────────────────────────────────────
// Global stats for the Super Admin dashboard
const getSuperAdminStats = async (req, res) => {
  const [
    totalStudents,
    totalContributors,
    totalAdmins,
    pendingAdmins,
    disabledAdmins,
    totalMaterials,
    pendingMaterials,
    approvedMaterials,
    rejectedMaterials,
  ] = await Promise.all([
    User.countDocuments({ role: 'student', isActive: true }),
    User.countDocuments({ role: 'contributor', isActive: true }),
    User.countDocuments({ role: 'faculty_admin', status: 'active', isActive: true }),
    User.countDocuments({ role: 'faculty_admin', status: 'pending' }),
    User.countDocuments({ role: 'faculty_admin', status: 'disabled' }),
    Material.countDocuments(),
    Material.countDocuments({ status: 'pending' }),
    Material.countDocuments({ status: 'approved' }),
    Material.countDocuments({ status: 'rejected' }),
  ]);

  res.json(
    success(
      {
        users: {
          totalStudents,
          totalContributors,
          // "Admin" in UI = faculty_admin role
          totalAdmins,
          pendingAdmins,
          disabledAdmins,
          // Legacy aliases kept for backward compat with existing Flutter screens
          totalFacultyAdmins: totalAdmins,
          pendingFacultyAdmins: pendingAdmins,
          disabledFacultyAdmins: disabledAdmins,
          total: totalStudents + totalContributors + totalAdmins,
        },
        materials: {
          total: totalMaterials,
          pending: pendingMaterials,
          approved: approvedMaterials,
          rejected: rejectedMaterials,
        },
      },
      'Super Admin stats fetched.'
    )
  );
};

// ─── GET /api/super-admin/users ────────────────────────────────────────
// All users across all roles (Super Admin global view)
const getAllUsers = async (req, res) => {
  const { role, status } = req.query;
  const filter = {};
  if (role) filter.role = role;
  if (status) filter.status = status;

  const users = await User.find(filter)
    .sort({ createdAt: -1 })
    .select('-password');

  res.json(success(users, 'All users fetched.'));
};

module.exports = {
  getPendingFacultyAdmins,
  getAllFacultyAdmins,
  approveFacultyAdmin,
  rejectFacultyAdmin,
  disableFacultyAdmin,
  enableFacultyAdmin,
  deleteFacultyAdmin,
  getSuperAdminStats,
  getAllUsers,
};
