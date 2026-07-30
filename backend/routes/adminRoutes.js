/**
 * routes/adminRoutes.js — Material approval + stats + contributor management
 *
 * Allowed roles:
 *   admin         — legacy, global access
 *   faculty_admin — sees only materials/contributors in their department
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
  getPendingContributors,
  approveContributor,
  rejectContributor,
} = require('../controllers/adminController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// All admin routes require JWT + admin-class role
router.use(protect, roleGuard('admin', 'faculty_admin', 'super_admin'));

// ── Material management ───────────────────────────────────────────────
router.get('/pending', getPendingMaterials);
router.get('/stats', getStats);
router.get('/materials', getAllMaterials);       // ?status=pending|approved|rejected
router.put('/approve/:id', approveMaterial);
router.put('/reject/:id', rejectMaterial);       // body: { reason: '...' }

// ── Contributor account management ───────────────────────────────────
router.get('/pending-contributors', getPendingContributors);
router.put('/contributors/:id/approve', approveContributor);
router.put('/contributors/:id/reject', rejectContributor);  // body: { reason: '...' }

module.exports = router;
