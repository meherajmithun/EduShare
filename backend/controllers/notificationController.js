/**
 * controllers/notificationController.js — User notification endpoints
 *
 * All endpoints require a valid JWT (req.user is set by protect middleware).
 * Users only ever see their own notifications.
 */

const Notification = require('../models/Notification');
const { success } = require('../utils/apiResponse');

// ─── GET /api/notifications ────────────────────────────────────────────
// Fetch the logged-in user's notifications, newest first. Limit to 50.
const getNotifications = async (req, res) => {
  const notifications = await Notification.find({ recipient: req.user._id })
    .sort({ createdAt: -1 })
    .limit(50);

  res.json(success(notifications, 'Notifications fetched.'));
};

// ─── GET /api/notifications/unread-count ──────────────────────────────
// Returns { count: N } for the badge indicator.
const getUnreadCount = async (req, res) => {
  const count = await Notification.countDocuments({
    recipient: req.user._id,
    isRead: false,
  });

  res.json(success({ count }, 'Unread count fetched.'));
};

// ─── PUT /api/notifications/read/:id ──────────────────────────────────
// Mark a single notification as read.
const markAsRead = async (req, res) => {
  const notification = await Notification.findOneAndUpdate(
    { _id: req.params.id, recipient: req.user._id }, // ownership check
    { isRead: true },
    { new: true }
  );

  if (!notification) {
    return res.status(404).json({ success: false, message: 'Notification not found.' });
  }

  res.json(success(notification.toJSON(), 'Notification marked as read.'));
};

// ─── PUT /api/notifications/read-all ──────────────────────────────────
// Mark ALL of the user's unread notifications as read in one operation.
const markAllAsRead = async (req, res) => {
  await Notification.updateMany(
    { recipient: req.user._id, isRead: false },
    { isRead: true }
  );

  res.json(success(null, 'All notifications marked as read.'));
};

module.exports = { getNotifications, getUnreadCount, markAsRead, markAllAsRead };
