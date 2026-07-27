/**
 * routes/adminRoutes.js — Material approval + stats for admins
 *
 * Allowed roles:
 *   admin         — legacy, global access
 *   faculty_admin — sees only materials assignedAdmin = their ID
 *   super_admin   — global access
 */
const express = require('express');
const router = express.Router();
const {
  getPendingMaterials,
  approveMaterial,
  rejectMaterial,
  getStats,
  getAllMaterials,
} = require('../controllers/adminController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// All admin routes require JWT + admin-class role
router.use(protect, roleGuard('admin', 'faculty_admin', 'super_admin'));

router.get('/pending', getPendingMaterials);
router.get('/stats', getStats);
router.get('/materials', getAllMaterials);       // ?status=pending|approved|rejected
router.put('/approve/:id', approveMaterial);
router.put('/reject/:id', rejectMaterial);       // body: { reason: '...' }

module.exports = router;
