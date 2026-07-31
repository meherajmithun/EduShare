/**
 * controllers/ratingController.js — Contributor rating CRUD + profile
 *
 * Endpoints:
 *   GET    /api/contributors/:id/profile   — Public profile (any authenticated user)
 *   GET    /api/contributors/:id/materials — Approved materials by this contributor
 *   GET    /api/contributors/:id/ratings   — All ratings + caller's own rating
 *   POST   /api/contributors/:id/ratings   — Submit rating (students only)
 *   PUT    /api/contributors/:id/ratings   — Edit own rating (students only)
 *   DELETE /api/contributors/:id/ratings   — Delete own rating (students only)
 */

const User = require('../models/User');
const Material = require('../models/Material');
const Rating = require('../models/Rating');
const { success, createError } = require('../utils/apiResponse');

// ─── Helper: recalculate and persist avgRating + totalRatings ─────────
const recalcContributorRating = async (contributorId) => {
  const [result] = await Rating.aggregate([
    { $match: { contributor: contributorId } },
    {
      $group: {
        _id: null,
        avg: { $avg: '$stars' },
        count: { $sum: 1 },
      },
    },
  ]);

  const avg = result ? parseFloat(result.avg.toFixed(1)) : 0;
  const count = result ? result.count : 0;

  await User.findByIdAndUpdate(contributorId, {
    avgRating: avg,
    totalRatings: count,
  });

  return { avg, count };
};

// ─── GET /api/contributors/:id/profile ────────────────────────────────
// Returns contributor's public profile including avgRating, totalRatings,
// total uploads, and approved upload count.
const getContributorProfile = async (req, res) => {
  const contributor = await User.findById(req.params.id).select(
    'name email department departmentId bio profilePhotoUrl avgRating totalRatings role createdAt'
  );

  if (!contributor || contributor.role !== 'contributor') {
    throw createError('Contributor not found.', 404);
  }

  // Count total materials and approved materials
  const [totalUploads, approvedUploads] = await Promise.all([
    Material.countDocuments({ uploadedBy: req.params.id }),
    Material.countDocuments({ uploadedBy: req.params.id, approvalStatus: 'approved' }),
  ]);

  res.json(
    success(
      {
        id: contributor._id.toString(),
        name: contributor.name,
        email: contributor.email,
        department: contributor.department,
        departmentId: contributor.departmentId?.toString() ?? null,
        bio: contributor.bio || '',
        profilePhotoUrl: contributor.profilePhotoUrl || '',
        avgRating: contributor.avgRating || 0,
        totalRatings: contributor.totalRatings || 0,
        totalUploads,
        approvedUploads,
        createdAt: contributor.createdAt,
      },
      'Contributor profile fetched.'
    )
  );
};

// ─── GET /api/contributors/:id/materials ──────────────────────────────
// Returns approved materials uploaded by this contributor.
const getContributorMaterials = async (req, res) => {
  const contributor = await User.findById(req.params.id).select('role');
  if (!contributor || contributor.role !== 'contributor') {
    throw createError('Contributor not found.', 404);
  }

  const materials = await Material.find({
    uploadedBy: req.params.id,
    approvalStatus: 'approved',
  }).sort({ createdAt: -1 });

  res.json(success(materials, 'Contributor materials fetched.'));
};

// ─── GET /api/contributors/:id/ratings ───────────────────────────────
// Returns all ratings for this contributor.
// Includes `myRating` — the current user's own rating (null if none).
const getContributorRatings = async (req, res) => {
  const ratings = await Rating.find({ contributor: req.params.id })
    .sort({ createdAt: -1 });

  // Find the caller's own rating (if any)
  const myRating = ratings.find(
    (r) => r.ratedBy.toString() === req.user._id.toString()
  ) ?? null;

  res.json(
    success(
      {
        ratings,
        myRating,
      },
      'Ratings fetched.'
    )
  );
};

// ─── POST /api/contributors/:id/ratings ──────────────────────────────
// Submit a new rating. Only students allowed. One per contributor.
const addRating = async (req, res) => {
  const { stars, review } = req.body;

  if (!stars) {
    throw createError('stars (1–5) is required.', 400);
  }

  const starsInt = parseInt(stars, 10);
  if (isNaN(starsInt) || starsInt < 1 || starsInt > 5) {
    throw createError('stars must be an integer between 1 and 5.', 400);
  }

  // Verify the target is actually a contributor
  const contributor = await User.findById(req.params.id).select('role');
  if (!contributor || contributor.role !== 'contributor') {
    throw createError('Contributor not found.', 404);
  }

  // Prevent self-rating (shouldn't happen — students can't be contributors — but defensive)
  if (req.params.id === req.user._id.toString()) {
    throw createError('You cannot rate yourself.', 400);
  }

  // Check for existing rating (enforced by unique index but give a friendlier error)
  const existing = await Rating.findOne({
    contributor: req.params.id,
    ratedBy: req.user._id,
  });
  if (existing) {
    throw createError('You have already rated this contributor. Use PUT to update.', 409);
  }

  const rating = await Rating.create({
    contributor: req.params.id,
    ratedBy: req.user._id,
    ratedByName: req.user.name,
    stars: starsInt,
    review: review?.trim() ?? '',
  });

  // Recalculate contributor's aggregate stats
  await recalcContributorRating(contributor._id);

  res.status(201).json(success(rating, 'Rating submitted successfully.'));
};

// ─── PUT /api/contributors/:id/ratings ───────────────────────────────
// Update the caller's existing rating.
const updateRating = async (req, res) => {
  const { stars, review } = req.body;

  const rating = await Rating.findOne({
    contributor: req.params.id,
    ratedBy: req.user._id,
  });

  if (!rating) {
    throw createError('No rating found. Use POST to submit a new rating.', 404);
  }

  if (stars !== undefined) {
    const starsInt = parseInt(stars, 10);
    if (isNaN(starsInt) || starsInt < 1 || starsInt > 5) {
      throw createError('stars must be an integer between 1 and 5.', 400);
    }
    rating.stars = starsInt;
  }

  if (review !== undefined) {
    rating.review = review.trim();
  }

  await rating.save();

  // Recalculate contributor's aggregate stats
  await recalcContributorRating(req.params.id);

  res.json(success(rating, 'Rating updated successfully.'));
};

// ─── DELETE /api/contributors/:id/ratings ─────────────────────────────
// Delete the caller's own rating.
const deleteRating = async (req, res) => {
  const rating = await Rating.findOneAndDelete({
    contributor: req.params.id,
    ratedBy: req.user._id,
  });

  if (!rating) {
    throw createError('No rating found to delete.', 404);
  }

  // Recalculate contributor's aggregate stats
  await recalcContributorRating(req.params.id);

  res.json(success(null, 'Rating deleted successfully.'));
};

module.exports = {
  getContributorProfile,
  getContributorMaterials,
  getContributorRatings,
  addRating,
  updateRating,
  deleteRating,
};
