/**
 * controllers/ratingController.js — Contributor rating CRUD + profile + follow + stats
 *
 * Endpoints:
 *   GET    /api/contributors/:id/profile   — Public profile (any authenticated user)
 *   GET    /api/contributors/:id/materials — Approved materials by this contributor
 *   GET    /api/contributors/:id/ratings   — All ratings + caller's own rating
 *   POST   /api/contributors/:id/ratings   — Submit rating (students only)
 *   PUT    /api/contributors/:id/ratings   — Edit own rating (students only)
 *   DELETE /api/contributors/:id/ratings   — Delete own rating (students only)
 *   POST   /api/contributors/:id/follow    — Follow a contributor
 *   DELETE /api/contributors/:id/follow    — Unfollow a contributor
 *   GET    /api/contributors/me/stats      — Contributor's own performance stats
 */

const User = require('../models/User');
const Material = require('../models/Material');
const Rating = require('../models/Rating');
const Follow = require('../models/Follow');
const {
  notifyContributorOnNewFollower,
} = require('../services/notificationService');
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

// ─── GET /api/contributors/me/stats ───────────────────────────────────
// Returns current contributor's dashboard stats.
// Includes totalUploads, approvedUploads, pendingUploads, rejectedUploads,
// totalDownloads (via views), avgRating, totalRatings, followerCount,
// and 6-month monthly download breakdown.
const getMyContributorStats = async (req, res) => {
  const userId = req.user._id;

  // Aggregate material stats
  const [
    totalUploads,
    approvedUploads,
    pendingUploads,
    rejectedUploads,
    followerCount,
  ] = await Promise.all([
    Material.countDocuments({ uploadedBy: userId }),
    Material.countDocuments({ uploadedBy: userId, approvalStatus: 'approved' }),
    Material.countDocuments({ uploadedBy: userId, approvalStatus: 'pending' }),
    Material.countDocuments({ uploadedBy: userId, approvalStatus: 'rejected' }),
    Follow.countDocuments({ following: userId }),
  ]);

  // Total downloads = sum of views across all approved materials
  const downloadAgg = await Material.aggregate([
    { $match: { uploadedBy: userId, approvalStatus: 'approved' } },
    { $group: { _id: null, totalViews: { $sum: '$views' } } },
  ]);
  const totalDownloads = downloadAgg[0]?.totalViews ?? 0;

  // Monthly breakdown for the last 6 months (views per month)
  const now = new Date();
  const sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 5, 1);

  const monthlyAgg = await Material.aggregate([
    {
      $match: {
        uploadedBy: userId,
        approvalStatus: 'approved',
        createdAt: { $gte: sixMonthsAgo },
      },
    },
    {
      $group: {
        _id: {
          year: { $year: '$createdAt' },
          month: { $month: '$createdAt' },
        },
        downloads: { $sum: '$views' },
      },
    },
    { $sort: { '_id.year': 1, '_id.month': 1 } },
  ]);

  // Build full 6-month labels + values array
  const monthLabels = [];
  const monthDownloads = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const year = d.getFullYear();
    const month = d.getMonth() + 1;
    const label = d.toLocaleString('en', { month: 'short' });
    const match = monthlyAgg.find(
      (m) => m._id.year === year && m._id.month === month
    );
    monthLabels.push(label);
    monthDownloads.push(match?.downloads ?? 0);
  }

  const user = (await User.findById(userId)) || req.user;

  res.json(
    success(
      {
        totalUploads,
        approvedUploads,
        pendingUploads,
        rejectedUploads,
        totalDownloads,
        totalViews: totalDownloads,
        avgRating: user.avgRating || 0,
        totalRatings: user.totalRatings || 0,
        followerCount,
        monthlyLabels: monthLabels,
        monthlyDownloads: monthDownloads,
        monthlyViews: monthDownloads,
      },
      'Contributor stats fetched.'
    )
  );
};

// ─── GET /api/contributors/:id/profile ────────────────────────────────
// Returns contributor's public profile including avgRating, totalRatings,
// total uploads, approved upload count, follower/following counts, and
// whether the current user is following this contributor.
const getContributorProfile = async (req, res) => {
  const contributor = await User.findById(req.params.id).select(
    'name email department departmentId bio profilePhotoUrl avgRating totalRatings role designation status createdAt'
  );

  if (!contributor || contributor.role !== 'contributor') {
    throw createError('Contributor not found.', 404);
  }

  // Count total materials, approved materials, and follow stats
  const [
    totalUploads,
    approvedUploads,
    followerCount,
    followingCount,
    totalDownloads,
    isFollowingDoc,
  ] = await Promise.all([
    Material.countDocuments({ uploadedBy: req.params.id }),
    Material.countDocuments({ uploadedBy: req.params.id, approvalStatus: 'approved' }),
    Follow.countDocuments({ following: req.params.id }),
    Follow.countDocuments({ follower: req.params.id }),
    Material.aggregate([
      { $match: { uploadedBy: contributor._id, approvalStatus: 'approved' } },
      { $group: { _id: null, total: { $sum: '$views' } } },
    ]),
    Follow.findOne({ follower: req.user._id, following: req.params.id }),
  ]);

  res.json(
    success(
      {
        id: contributor._id.toString(),
        name: contributor.name,
        email: contributor.email,
        department: contributor.department,
        departmentId: contributor.departmentId?.toString() ?? null,
        designation: contributor.designation || '',
        bio: contributor.bio || '',
        profilePhotoUrl: contributor.profilePhotoUrl || '',
        avgRating: contributor.avgRating || 0,
        totalRatings: contributor.totalRatings || 0,
        totalUploads,
        approvedUploads,
        totalDownloads: totalDownloads[0]?.total ?? 0,
        followerCount,
        followingCount,
        isFollowing: !!isFollowingDoc,
        // Treat active contributors with good ratings as "verified"
        isVerified: contributor.status === 'active' && (contributor.avgRating || 0) >= 4.0,
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

// ─── POST /api/contributors/:id/follow ───────────────────────────────
// Follow a contributor. Fires a notification to the contributor.
const followContributor = async (req, res) => {
  const contributorId = req.params.id;
  const followerId = req.user._id;

  if (contributorId === followerId.toString()) {
    throw createError('You cannot follow yourself.', 400);
  }

  const contributor = await User.findById(contributorId).select('role name');
  if (!contributor || contributor.role !== 'contributor') {
    throw createError('Contributor not found.', 404);
  }

  // Check if already following
  const existing = await Follow.findOne({ follower: followerId, following: contributorId });
  if (existing) {
    throw createError('You are already following this contributor.', 409);
  }

  await Follow.create({ follower: followerId, following: contributorId });

  // Notify the contributor (fire-and-forget)
  notifyContributorOnNewFollower({
    contributor,
    follower: req.user,
  });

  const followerCount = await Follow.countDocuments({ following: contributorId });

  res.status(201).json(success({ isFollowing: true, followerCount }, 'Now following contributor.'));
};

// ─── DELETE /api/contributors/:id/follow ──────────────────────────────
// Unfollow a contributor.
const unfollowContributor = async (req, res) => {
  const contributorId = req.params.id;

  const result = await Follow.findOneAndDelete({
    follower: req.user._id,
    following: contributorId,
  });

  if (!result) {
    throw createError('You are not following this contributor.', 404);
  }

  const followerCount = await Follow.countDocuments({ following: contributorId });

  res.json(success({ isFollowing: false, followerCount }, 'Unfollowed contributor.'));
};

module.exports = {
  getContributorProfile,
  getContributorMaterials,
  getContributorRatings,
  addRating,
  updateRating,
  deleteRating,
  followContributor,
  unfollowContributor,
  getMyContributorStats,
};
