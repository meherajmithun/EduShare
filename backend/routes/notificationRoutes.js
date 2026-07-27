/**
 * routes/notificationRoutes.js — Notification endpoints
 * Mounted at: /api/notifications
 * All routes require a valid JWT.
 */

const express = require('express');
const router = express.Router();
const {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
} = require('../controllers/notificationController');
const { protect } = require('../middleware/auth');

router.use(protect); // All routes are authenticated

router.get('/', getNotifications);
router.get('/unread-count', getUnreadCount);
router.put('/read-all', markAllAsRead);
router.put('/read/:id', markAsRead);

module.exports = router;
