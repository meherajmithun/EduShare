/**
 * routes/contributorRoutes.js — Public contributor profiles + student ratings
 *
 * All routes require JWT (protect).
 * Only 'student' role can submit, edit, or delete ratings.
 * Any authenticated role can view profiles, materials, and ratings.
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
} = require('../controllers/ratingController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// ── Public contributor profile (any authenticated user can view) ───────
router.get('/:id/profile', protect, getContributorProfile);
router.get('/:id/materials', protect, getContributorMaterials);
router.get('/:id/ratings', protect, getContributorRatings);

// ── Rating CRUD (students only) ───────────────────────────────────────
router.post('/:id/ratings', protect, roleGuard('student'), addRating);
router.put('/:id/ratings', protect, roleGuard('student'), updateRating);
router.delete('/:id/ratings', protect, roleGuard('student'), deleteRating);

module.exports = router;
