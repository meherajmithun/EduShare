const express = require('express');
const router = express.Router();
const { getUsers, getUserById, updateUserRole, deleteUser, getMyStats } = require('../controllers/userController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// ─── Self stats — any authenticated user (must be before role guard) ───
router.get('/me/stats', protect, getMyStats);

// Admin, Faculty Admin (dept-scoped in controller), and Super Admin may manage users
router.use(protect, roleGuard('admin', 'faculty_admin', 'super_admin'));

router.get('/', getUsers);              // ?role=... &status=...
router.get('/:id', getUserById);
router.put('/:id/role', updateUserRole);
router.delete('/:id', deleteUser);

module.exports = router;
