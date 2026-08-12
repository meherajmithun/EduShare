/**
 * routes/contributorRoutes.js — Public contributor profiles + ratings + follow
 *
 * All routes require JWT (protect).
 * Only 'student' role can submit, edit, or delete ratings and follow/unfollow.
 * Any authenticated role can view profiles, materials, and ratings.
 *
 * IMPORTANT: /me/stats must come BEFORE /:id/* routes to avoid param conflict.
 */

const express = require('express');
const router = express.Router();
const {
  getContributorProfile,
  getContributorMaterials,
  getContributorRatings,
  addRating,
  updateRating,
  deleteRating,
  followContributor,
  unfollowContributor,
  getMyContributorStats,
} = require('../controllers/ratingController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// ── Self stats (contributor only) — MUST be before /:id routes ───────
router.get(
  '/me/stats',
  protect,
  roleGuard('contributor', 'admin', 'faculty_admin', 'super_admin'),
  getMyContributorStats
);

// ── Public contributor profile (any authenticated user can view) ───────
router.get('/:id/profile', protect, getContributorProfile);
router.get('/:id/materials', protect, getContributorMaterials);
router.get('/:id/ratings', protect, getContributorRatings);

// ── Rating CRUD (students only) ───────────────────────────────────────
router.post('/:id/ratings', protect, roleGuard('student'), addRating);
router.put('/:id/ratings', protect, roleGuard('student'), updateRating);
router.delete('/:id/ratings', protect, roleGuard('student'), deleteRating);

// ── Follow / Unfollow (students only) ────────────────────────────────
router.post('/:id/follow', protect, roleGuard('student'), followContributor);
router.delete('/:id/follow', protect, roleGuard('student'), unfollowContributor);

module.exports = router;
