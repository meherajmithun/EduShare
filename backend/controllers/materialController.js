/**
 * controllers/materialController.js — Material upload, browsing, deletion + material ratings
 *
 * Department-based approval workflow:
 *   On upload → find the active Faculty Admin for the material's department.
 *               Set assignedAdmin automatically. Send notification to Faculty Admin.
 *
 * Student access: getMaterials is scoped to the student's departmentId.
 * Contributor access: createMaterial validates departmentId matches own department.
 *
 * Video source logic:
 *   type === 'video' && videoSource === 'youtube'    → store videoLink, no file upload
 *   type === 'video' && videoSource === 'cloudinary' → upload req.file as video to Cloudinary
 *   type === 'pdf' | 'notes' | 'assignment'          → upload req.file as raw to Cloudinary
 *
 * Material Rating endpoints (students only):
 *   GET    /api/materials/:id/ratings   — all ratings + caller's own rating
 *   POST   /api/materials/:id/ratings   — submit rating (students only)
 *   PUT    /api/materials/:id/ratings   — update own rating
 *   DELETE /api/materials/:id/ratings   — delete own rating
 */

const Material = require('../models/Material');
const MaterialRating = require('../models/MaterialRating');
const User = require('../models/User');
const Department = require('../models/Department');
const { uploadBuffer, uploadVideoBuffer, deleteFile } = require('../services/cloudinaryService');
const { notifyFacultyAdminOnUpload, notifyContributorOnRatingSubmitted, notifyContributorOnRatingUpdated } = require('../services/notificationService');
const { success, createError } = require('../utils/apiResponse');

// ─── Helper: resolve department name from departmentId ─────────────────
const resolveDeptName = async (departmentId) => {
  try {
    const dept = await Department.findById(departmentId);
    return dept ? dept.name : '';
  } catch (_) {
    return '';
  }
};

// ─── Helper: find active Faculty Admin for a given departmentId ────────
const findFacultyAdminForDept = async (departmentId) => {
  return User.findOne({
    role: 'faculty_admin',
    status: 'active',
    departmentId,
  });
};

// ─── Helper: recalculate material avgRating + totalRatings, then
//             update the contributor's overall avgRating from all their
//             materials' ratings (aggregated). ──────────────────────────
const recalcMaterialRating = async (materialId, contributorId) => {
  // 1. Recalc this material's avg
  const [matResult] = await MaterialRating.aggregate([
    { $match: { materialId: materialId } },
    { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
  ]);
  const matAvg = matResult ? parseFloat(matResult.avg.toFixed(1)) : 0;
  const matCount = matResult ? matResult.count : 0;
  await Material.findByIdAndUpdate(materialId, { avgRating: matAvg, totalRatings: matCount });

  // 2. Recalc contributor's overall avg across ALL their material ratings
  const [contResult] = await MaterialRating.aggregate([
    { $match: { contributorId: contributorId } },
    { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
  ]);
  const contAvg = contResult ? parseFloat(contResult.avg.toFixed(1)) : 0;
  const contCount = contResult ? contResult.count : 0;
  await User.findByIdAndUpdate(contributorId, { avgRating: contAvg, totalRatings: contCount });

  return { matAvg, matCount };
};

// ─── GET /api/materials?courseId=&type= ────────────────────────────────
// Returns approved materials only.
// Students: scoped to their own departmentId automatically.
const getMaterials = async (req, res) => {
  const { courseId, type } = req.query;

  const filter = { approvalStatus: 'approved' };
  if (courseId) filter.courseId = courseId;
  if (type) filter.type = type;

  // Department-based access: students and contributors only see materials from their dept
  if (req.user && (req.user.role === 'student' || req.user.role === 'contributor') && req.user.departmentId) {
    filter.departmentId = req.user.departmentId.toString();
  }

  const materials = await Material.find(filter).sort({ createdAt: -1 });
  res.json(success(materials, 'Materials fetched successfully.'));
};

// ─── GET /api/materials/my ─────────────────────────────────────────────
// Returns ALL materials uploaded by the authenticated user (any status)
const getMyMaterials = async (req, res) => {
  const materials = await Material.find({ uploadedBy: req.user._id })
    .sort({ createdAt: -1 });
  res.json(success(materials, 'Your materials fetched successfully.'));
};

// ─── GET /api/materials/:id ────────────────────────────────────────────
const getMaterialById = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);
  res.json(success(material));
};

// ─── POST /api/materials ───────────────────────────────────────────────
// Contributor uploads material. Automatically assigns the Faculty Admin
// for the material's department and sends them a notification.
//
// Request body fields (multipart/form-data or JSON):
//   title, description, type, courseId, departmentId
//   videoSource  — 'youtube' | 'cloudinary'  (only for type === 'video')
//   videoLink    — YouTube URL               (only for videoSource === 'youtube')
//   file         — the uploaded file          (for all non-youtube types)
const createMaterial = async (req, res) => {
  const { title, description, type, videoLink, videoSource, courseId, departmentId } = req.body;

  if (!title || !description || !type || !courseId || !departmentId) {
    throw createError('title, description, type, courseId, and departmentId are required.', 400);
  }

  if (!['notes', 'assignment', 'video', 'pdf'].includes(type)) {
    throw createError('type must be notes, assignment, video, or pdf.', 400);
  }

  // Validate based on type / videoSource combination
  if (type === 'video') {
    if (!videoSource || !['youtube', 'cloudinary'].includes(videoSource)) {
      throw createError('videoSource must be "youtube" or "cloudinary" for video type.', 400);
    }
    if (videoSource === 'youtube' && !videoLink) {
      throw createError('A YouTube URL is required when videoSource is "youtube".', 400);
    }
    if (videoSource === 'cloudinary' && !req.file) {
      throw createError('A video file is required when videoSource is "cloudinary".', 400);
    }
  } else {
    // notes, assignment, pdf — all require a file
    if (!req.file) {
      throw createError('A file is required for notes, assignment, and pdf types.', 400);
    }
  }

  // Department access guard: contributors can only upload to their own department
  if (req.user.role === 'contributor' && req.user.departmentId) {
    if (req.user.departmentId.toString() !== departmentId.toString()) {
      throw createError('You can only upload materials for your own department.', 403);
    }
  }

  // Resolve department name
  const departmentName = await resolveDeptName(departmentId);

  // Auto-assign Faculty Admin for this department
  const facultyAdmin = await findFacultyAdminForDept(departmentId);

  const materialData = {
    title,
    description,
    type,
    courseId,
    departmentId,
    department: departmentName,
    uploadedBy: req.user._id,
    contributorName: req.user.name,
    approvalStatus: 'pending',
    status: 'pending',
    assignedAdmin: facultyAdmin ? facultyAdmin._id : null,
    assignedAdminName: facultyAdmin ? facultyAdmin.name : null,
  };

  // ── Handle file upload to Cloudinary ─────────────────────────────────
  if (req.file) {
    if (type === 'video' && videoSource === 'cloudinary') {
      // Upload as video resource type
      const { url, publicId } = await uploadVideoBuffer(req.file.buffer, 'edushare/videos');
      materialData.fileUrl = url;
      materialData.filePublicId = publicId;
      materialData.videoSource = 'cloudinary';
    } else {
      // Upload as raw resource type (PDF, DOC, images)
      const { url, publicId } = await uploadBuffer(req.file.buffer, 'edushare/materials');
      materialData.fileUrl = url;
      materialData.filePublicId = publicId;
    }

    // Store original filename and size for display
    materialData.fileName = req.file.originalname || null;
    materialData.fileSize = req.file.size || null;
  }

  // ── Handle YouTube link ───────────────────────────────────────────────
  if (type === 'video' && videoSource === 'youtube') {
    materialData.videoLink = videoLink.trim();
    materialData.videoSource = 'youtube';
  }

  const material = await Material.create(materialData);

  // ── Send notification to Faculty Admin (fire-and-forget) ──────────────
  notifyFacultyAdminOnUpload({ material, uploader: req.user });

  const msg = facultyAdmin
    ? `Material submitted for review. Assigned to ${facultyAdmin.name}.`
    : 'Material submitted. No Faculty Admin is currently assigned — a Super Admin will review it.';

  res.status(201).json(success(material, msg));
};

// ─── DELETE /api/materials/:id ─────────────────────────────────────────
const deleteMaterial = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (
    req.user.role === 'contributor' &&
    material.uploadedBy.toString() !== req.user._id.toString()
  ) {
    throw createError('You can only delete your own materials.', 403);
  }

  if (material.filePublicId) {
    // Determine the correct resource_type for Cloudinary deletion
    let resourceType = 'raw'; // default for PDF/doc
    if (material.type === 'video' && material.videoSource === 'cloudinary') {
      resourceType = 'video';
    } else if (['notes', 'assignment', 'pdf'].includes(material.type)) {
      resourceType = 'raw';
    }
    await deleteFile(material.filePublicId, resourceType);
  }

  // Also remove all ratings for this material
  await MaterialRating.deleteMany({ materialId: req.params.id });
  await Material.findByIdAndDelete(req.params.id);

  res.json(success(null, 'Material deleted successfully.'));
};

// ─── GET /api/materials/:id/ratings ───────────────────────────────────
// Returns all ratings for a material + the caller's own rating.
const getMaterialRatings = async (req, res) => {
  const material = await Material.findById(req.params.id).select('_id title uploadedBy');
  if (!material) throw createError('Material not found.', 404);

  const ratings = await MaterialRating.find({ materialId: req.params.id })
    .sort({ createdAt: -1 });

  const myRating = ratings.find(
    (r) => r.ratedBy.toString() === req.user._id.toString()
  ) ?? null;

  res.json(success({ ratings, myRating, avgRating: material.avgRating, totalRatings: material.totalRatings }, 'Ratings fetched.'));
};

// ─── POST /api/materials/:id/ratings ──────────────────────────────────
// Submit a new material rating. Only students allowed. One per material.
const addMaterialRating = async (req, res) => {
  if (req.user.role !== 'student') {
    throw createError('Only students can rate materials.', 403);
  }

  const { stars, review } = req.body;
  if (!stars) throw createError('stars (1–5) is required.', 400);
  const starsInt = parseInt(stars, 10);
  if (isNaN(starsInt) || starsInt < 1 || starsInt > 5) {
    throw createError('stars must be an integer between 1 and 5.', 400);
  }

  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);
  if (material.approvalStatus !== 'approved') {
    throw createError('You can only rate approved materials.', 400);
  }

  // Prevent duplicate rating
  const existing = await MaterialRating.findOne({
    materialId: req.params.id,
    ratedBy: req.user._id,
  });
  if (existing) {
    throw createError('You have already rated this material. Use PUT to update.', 409);
  }

  const rating = await MaterialRating.create({
    materialId: material._id,
    contributorId: material.uploadedBy,
    ratedBy: req.user._id,
    ratedByName: req.user.name,
    stars: starsInt,
    review: review?.trim() ?? '',
  });

  await recalcMaterialRating(material._id, material.uploadedBy);

  // Notify contributor (fire-and-forget)
  notifyContributorOnRatingSubmitted({ material, student: req.user });

  res.status(201).json(success(rating, 'Rating submitted successfully.'));
};

// ─── PUT /api/materials/:id/ratings ───────────────────────────────────
// Update the caller's existing rating.
const updateMaterialRating = async (req, res) => {
  if (req.user.role !== 'student') {
    throw createError('Only students can rate materials.', 403);
  }

  const { stars, review } = req.body;
  const rating = await MaterialRating.findOne({
    materialId: req.params.id,
    ratedBy: req.user._id,
  });
  if (!rating) throw createError('No rating found. Use POST to submit a new rating.', 404);

  if (stars !== undefined) {
    const starsInt = parseInt(stars, 10);
    if (isNaN(starsInt) || starsInt < 1 || starsInt > 5) {
      throw createError('stars must be an integer between 1 and 5.', 400);
    }
    rating.stars = starsInt;
  }
  if (review !== undefined) rating.review = review.trim();

  await rating.save();
  await recalcMaterialRating(rating.materialId, rating.contributorId);

  const material = await Material.findById(req.params.id).select('title uploadedBy');
  if (material) notifyContributorOnRatingUpdated({ material, student: req.user });

  res.json(success(rating, 'Rating updated successfully.'));
};

// ─── DELETE /api/materials/:id/ratings ────────────────────────────────
// Delete the caller's own rating.
const deleteMaterialRating = async (req, res) => {
  if (req.user.role !== 'student') {
    throw createError('Only students can delete their material ratings.', 403);
  }

  const rating = await MaterialRating.findOneAndDelete({
    materialId: req.params.id,
    ratedBy: req.user._id,
  });
  if (!rating) throw createError('No rating found to delete.', 404);

  await recalcMaterialRating(rating.materialId, rating.contributorId);

  res.json(success(null, 'Rating deleted successfully.'));
};

module.exports = {
  getMaterials,
  getMyMaterials,
  getMaterialById,
  createMaterial,
  deleteMaterial,
  getMaterialRatings,
  addMaterialRating,
  updateMaterialRating,
  deleteMaterialRating,
};
