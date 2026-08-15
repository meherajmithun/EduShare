/**
 * controllers/userController.js — User management
 *
 * Super Admin: can manage all users across all roles.
 * Faculty Admin: can view only users in their own department.
 * Legacy Admin: global access (backward compatibility).
 *
 * DELETE performs a HARD delete for student/contributor accounts.
 * Admin-class accounts (admin, faculty_admin, super_admin) are protected.
 */

const User = require('../models/User');
const Material = require('../models/Material');
const Notification = require('../models/Notification');
const MaterialRating = require('../models/MaterialRating');
const VideoProgress = require('../models/VideoProgress');
const VideoBookmark = require('../models/VideoBookmark');
const VideoComment = require('../models/VideoComment');
const { deleteFile } = require('../services/cloudinaryService');
const { success, createError } = require('../utils/apiResponse');

const VALID_ROLES = ['student', 'contributor', 'admin', 'faculty_admin', 'super_admin'];
const PROTECTED_ROLES = ['admin', 'faculty_admin', 'super_admin'];

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

  // Hide super_admin accounts from non-super_admin users
  if (req.user.role !== 'super_admin') {
    filter.role = filter.role && filter.role !== 'super_admin'
      ? filter.role
      : { $ne: 'super_admin' };
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
// Hard-deletes a student or contributor from the database.
// Admin-class roles are fully protected and cannot be deleted here.
const deleteUser = async (req, res) => {
  if (req.params.id === req.user._id.toString()) {
    throw createError('You cannot delete your own account.', 400);
  }

  const user = await User.findById(req.params.id);
  if (!user) throw createError('User not found.', 404);

  // Block deletion of any admin-class account via this endpoint
  if (PROTECTED_ROLES.includes(user.role)) {
    throw createError(
      'Admin accounts must be managed via the Admin management endpoint.',
      403
    );
  }

  // Faculty Admin can only delete users from their own department
  if (req.user.role === 'faculty_admin' && user.department !== req.user.department) {
    throw createError('Access denied. User is not in your department.', 403);
  }

  const userId = req.params.id;

  // Delete Cloudinary profile photo if exists
  if (user.profilePhotoPublicId) {
    try { await deleteFile(user.profilePhotoPublicId); } catch (_) {}
  }

  // Hard delete: remove user and ALL associated data in parallel
  await Promise.all([
    User.findByIdAndDelete(userId),
    Material.deleteMany({ uploadedBy: userId }),
    Notification.deleteMany({ $or: [{ recipient: userId }, { sender: userId }] }),
    MaterialRating.deleteMany({ ratedBy: userId }),
    VideoProgress.deleteMany({ userId }),
    VideoBookmark.deleteMany({ userId }),
    VideoComment.deleteMany({ userId }),
  ]);

  res.json(success(null, `${user.name}'s account has been permanently deleted.`));
};

// ─── GET /api/users/me/stats ──────────────────────────────────────────
// Returns learning statistics for the currently logged-in user.
// All roles can call this; stats are computed from VideoProgress, Material, & VideoBookmark.
const getMyStats = async (req, res) => {
  const userId = req.user._id;

  const { getStudentCourseProgressData } = require('./courseController');
  const courseProgressData = await getStudentCourseProgressData(userId);

  const [progressRecords] = await Promise.all([
    VideoProgress.find({ userId }),
  ]);

  const completed = courseProgressData.completedCount;
  const downloads = courseProgressData.downloads;
  const savedNotes = courseProgressData.savedNotes;

  // ── Weekly activity (last 7 days) ──────────────────────────────────
  // Derive approximate study hours from video watch time stored in lastPosition.
  const today = new Date();
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Build a map: dayLabel -> total seconds watched that day
  const daySeconds = {};
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    daySeconds[DAYS[d.getDay()]] = 0;
  }

  // Aggregate seconds per day-of-week from updatedAt timestamps
  for (const p of progressRecords) {
    const updatedAt = p.updatedAt || p.lastWatchedAt;
    if (!updatedAt) continue;
    const diffDays = Math.floor((today - updatedAt) / (1000 * 60 * 60 * 24));
    if (diffDays >= 0 && diffDays <= 6) {
      const label = DAYS[updatedAt.getDay()];
      if (label in daySeconds) {
        daySeconds[label] += p.lastPosition || 0;
      }
    }
  }

  // Convert seconds → hours (rounded to 1 decimal)
  const weeklyActivity = Object.entries(daySeconds).map(([day, seconds]) => ({
    day,
    hours: Math.round((seconds / 3600) * 10) / 10,
  }));

  const totalHours = weeklyActivity.reduce((acc, d) => acc + d.hours, 0);

  res.json(
    success(
      {
        downloads,
        savedNotes,
        completed,
        weeklyActivity,
        totalWeeklyHours: Math.round(totalHours * 10) / 10,
      },
      'Stats fetched successfully.'
    )
  );
};

module.exports = { getUsers, getUserById, updateUserRole, deleteUser, getMyStats };
