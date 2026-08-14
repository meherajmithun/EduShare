const mongoose = require('mongoose');
const Material = require('../models/Material');
const VideoProgress = require('../models/VideoProgress');
const VideoBookmark = require('../models/VideoBookmark');
const VideoComment = require('../models/VideoComment');
const { success, createError } = require('../utils/apiResponse');

// ─── POST /api/videos/:id/view ─────────────────────────────────────────
const incrementViewCount = async (req, res) => {
  const { id } = req.params;
  const material = await Material.findByIdAndUpdate(
    id,
    { $inc: { views: 1 } },
    { new: true }
  );
  if (!material) throw createError('Material not found', 404);
  res.json(success({ views: material.views }, 'View count updated'));
};

// ─── POST /api/videos/progress ─────────────────────────────────────────
const saveProgress = async (req, res) => {
  let { materialId, courseId, lastPosition, duration, completed } = req.body;
  if (!materialId) {
    throw createError('materialId is required', 400);
  }

  if (!courseId || !mongoose.isValidObjectId(courseId)) {
    const mat = await Material.findById(materialId);
    if (mat && mat.courseId) {
      courseId = mat.courseId;
    }
  }

  if (!courseId || !mongoose.isValidObjectId(courseId)) {
    throw createError('Valid courseId or material with course is required', 400);
  }

  const pos = Number(lastPosition) || 0;
  const dur = Number(duration) || 0;
  const isCompleted = completed || (dur > 0 && pos / dur >= 0.85);

  const progress = await VideoProgress.findOneAndUpdate(
    { userId: req.user._id, materialId },
    {
      userId: req.user._id,
      materialId,
      courseId,
      lastPosition: pos,
      duration: dur,
      completed: isCompleted,
      lastWatchedAt: new Date(),
    },
    { upsert: true, new: true }
  );

  res.json(success(progress, 'Progress saved'));
};

// ─── GET /api/videos/progress/:courseId ───────────────────────────────
const getCourseProgress = async (req, res) => {
  const { courseId } = req.params;
  const records = await VideoProgress.find({
    userId: req.user._id,
    courseId,
  });
  res.json(success(records, 'Course progress retrieved'));
};

// ─── GET /api/videos/continue-watching ─────────────────────────────────
const getContinueWatching = async (req, res) => {
  const progressList = await VideoProgress.find({
    userId: req.user._id,
    completed: false,
  })
    .sort({ lastWatchedAt: -1 })
    .limit(10)
    .populate('materialId')
    .populate('courseId', 'name code');

  const items = progressList
    .filter((p) => p.materialId && p.materialId.approvalStatus === 'approved')
    .map((p) => ({
      progress: p,
      material: p.materialId,
      course: p.courseId,
    }));

  res.json(success(items, 'Continue watching items retrieved'));
};

// ─── GET /api/videos/history ───────────────────────────────────────────
const getHistory = async (req, res) => {
  const progressList = await VideoProgress.find({ userId: req.user._id })
    .sort({ lastWatchedAt: -1 })
    .limit(30)
    .populate('materialId')
    .populate('courseId', 'name code');

  const items = progressList
    .filter((p) => p.materialId && p.materialId.approvalStatus === 'approved')
    .map((p) => ({
      progress: p,
      material: p.materialId,
      course: p.courseId,
    }));

  res.json(success(items, 'Watch history retrieved'));
};

// ─── GET /api/videos/bookmarks ─────────────────────────────────────────
const getBookmarks = async (req, res) => {
  const bookmarks = await VideoBookmark.find({ userId: req.user._id })
    .sort({ createdAt: -1 })
    .populate('materialId')
    .populate('courseId', 'name code');

  const items = bookmarks
    .filter((b) => b.materialId)
    .map((b) => ({
      bookmarkId: b._id,
      material: b.materialId,
      course: b.courseId,
      createdAt: b.createdAt,
    }));

  res.json(success(items, 'Bookmarks retrieved'));
};

// ─── POST /api/videos/bookmark/:materialId ────────────────────────────
const addBookmark = async (req, res) => {
  const { materialId } = req.params;
  const { courseId } = req.body;

  const mat = await Material.findById(materialId);
  if (!mat) throw createError('Material not found', 404);

  const bookmark = await VideoBookmark.findOneAndUpdate(
    { userId: req.user._id, materialId },
    {
      userId: req.user._id,
      materialId,
      courseId: courseId || mat.courseId,
    },
    { upsert: true, new: true }
  );

  res.json(success(bookmark, 'Video bookmarked'));
};

// ─── DELETE /api/videos/bookmark/:materialId ─────────────────────────
const removeBookmark = async (req, res) => {
  const { materialId } = req.params;
  await VideoBookmark.findOneAndDelete({
    userId: req.user._id,
    materialId,
  });
  res.json(success(null, 'Bookmark removed'));
};

// ─── GET /api/videos/:materialId/comments ──────────────────────────────
const getComments = async (req, res) => {
  const { materialId } = req.params;
  const comments = await VideoComment.find({ materialId }).sort({ createdAt: -1 });
  res.json(success(comments, 'Comments retrieved'));
};

// ─── POST /api/videos/:materialId/comments ─────────────────────────────
const addComment = async (req, res) => {
  const { materialId } = req.params;
  const { comment } = req.body;

  if (!comment || !comment.trim()) {
    throw createError('Comment text is required', 400);
  }

  const newComment = await VideoComment.create({
    materialId,
    userId: req.user._id,
    userName: req.user.name,
    userPhoto: req.user.profilePhotoUrl || '',
    comment: comment.trim(),
  });

  res.status(201).json(success(newComment, 'Comment added'));
};

module.exports = {
  incrementViewCount,
  saveProgress,
  getCourseProgress,
  getContinueWatching,
  getHistory,
  getBookmarks,
  addBookmark,
  removeBookmark,
  getComments,
  addComment,
};
