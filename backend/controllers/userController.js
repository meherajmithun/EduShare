/**
 * controllers/userController.js — User management
 *
 * Super Admin: can manage all users across all roles.
 * Faculty Admin: can view only users in their own department.
 * Legacy Admin: global access (backward compatibility).
 */

const User = require('../models/User');
const { success, createError } = require('../utils/apiResponse');

const VALID_ROLES = ['student', 'contributor', 'admin', 'faculty_admin', 'super_admin'];

// ─── GET /api/users ────────────────────────────────────────────────────
const getUsers = async (req, res) => {
  const { role, status } = req.query;
  const filter = {};
  if (role) filter.role = role;
  if (status) filter.status = status;

  // Faculty Admin scoping — only see their own department
  if (req.user.role === 'faculty_admin' && req.user.department) {
    filter.department = req.user.department;
  }

  const users = await User.find(filter).sort({ createdAt: -1 }).select('-password');
  res.json(success(users, 'Users fetched successfully.'));
};

// ─── GET /api/users/:id ────────────────────────────────────────────────
const getUserById = async (req, res) => {
  const user = await User.findById(req.params.id).select('-password');
  if (!user) throw createError('User not found.', 404);

  // Faculty Admin scope check
  if (req.user.role === 'faculty_admin' && user.department !== req.user.department) {
    throw createError('Access denied. User is not in your department.', 403);
  }

  res.json(success(user));
};

// ─── PUT /api/users/:id/role ───────────────────────────────────────────
const updateUserRole = async (req, res) => {
  const { role } = req.body;
  if (!role) throw createError('Role is required.', 400);
  if (!VALID_ROLES.includes(role)) {
    throw createError(`Role must be one of: ${VALID_ROLES.join(', ')}.`, 400);
  }

  // Prevent self-role-change
  if (req.params.id === req.user._id.toString()) {
    throw createError('You cannot change your own role.', 400);
  }

  // Only Super Admin can assign super_admin or faculty_admin roles
  if (['super_admin', 'faculty_admin'].includes(role) && req.user.role !== 'super_admin') {
    throw createError('Only Super Admin can assign super_admin or faculty_admin roles.', 403);
  }

  const user = await User.findByIdAndUpdate(
    req.params.id,
    { role },
    { new: true, runValidators: true }
  ).select('-password');

  if (!user) throw createError('User not found.', 404);

  res.json(success(user, `User role updated to ${role}.`));
};

// ─── DELETE /api/users/:id ─────────────────────────────────────────────
// Soft-delete (deactivate) a user account
const deleteUser = async (req, res) => {
  if (req.params.id === req.user._id.toString()) {
    throw createError('You cannot delete your own account.', 400);
  }

  const user = await User.findByIdAndUpdate(req.params.id, { isActive: false }, { new: true });
  if (!user) throw createError('User not found.', 404);

  res.json(success(null, 'User account deactivated.'));
};

module.exports = { getUsers, getUserById, updateUserRole, deleteUser };
