/**
 * controllers/userController.js — User management (admin only)
 */

const User = require('../models/User');
const { success, createError } = require('../utils/apiResponse');

// ─── GET /api/users ────────────────────────────────────────────────────
const getUsers = async (req, res) => {
  const { role } = req.query;
  const filter = { isActive: true };
  if (role) filter.role = role;

  const users = await User.find(filter).sort({ createdAt: -1 }).select('-password');
  res.json(success(users, 'Users fetched successfully.'));
};

// ─── GET /api/users/:id ────────────────────────────────────────────────
const getUserById = async (req, res) => {
  const user = await User.findById(req.params.id).select('-password');
  if (!user) throw createError('User not found.', 404);
  res.json(success(user));
};

// ─── PUT /api/users/:id/role ───────────────────────────────────────────
// Change a user's role (admin only)
const updateUserRole = async (req, res) => {
  const { role } = req.body;
  if (!role) throw createError('Role is required.', 400);
  if (!['student', 'contributor', 'admin'].includes(role)) {
    throw createError('Role must be student, contributor, or admin.', 400);
  }

  // Prevent an admin from changing their own role
  if (req.params.id === req.user._id.toString()) {
    throw createError('You cannot change your own role.', 400);
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
