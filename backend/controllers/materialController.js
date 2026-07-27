/**
 * controllers/materialController.js — Material upload, browsing, deletion
 */

const Material = require('../models/Material');
const { uploadBuffer, deleteFile } = require('../services/cloudinaryService');
const { success, createError } = require('../utils/apiResponse');

// ─── GET /api/materials?courseId=&type= ───────────────────────────────
// Returns approved materials only (public browsing for students)
const getMaterials = async (req, res) => {
  const { courseId, type } = req.query;

  const filter = { status: 'approved' };
  if (courseId) filter.courseId = courseId;
  if (type) filter.type = type;

  const materials = await Material.find(filter).sort({ createdAt: -1 });
  res.json(success(materials, 'Materials fetched successfully.'));
};

// ─── GET /api/materials/my ─────────────────────────────────────────────
// Returns ALL materials uploaded by the authenticated user (any status)
const getMyMaterials = async (req, res) => {
  const materials = await Material.find({ uploadedBy: req.user._id }).sort({ createdAt: -1 });
  res.json(success(materials, 'Your materials fetched successfully.'));
};

// ─── GET /api/materials/:id ────────────────────────────────────────────
const getMaterialById = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);
  res.json(success(material));
};

// ─── POST /api/materials ───────────────────────────────────────────────
// contributor / admin — creates a new material with optional file upload
const createMaterial = async (req, res) => {
  const { title, description, type, videoLink, courseId, departmentId } = req.body;

  if (!title || !description || !type || !courseId || !departmentId) {
    throw createError('title, description, type, courseId, and departmentId are required.', 400);
  }

  if (!['notes', 'assignment', 'video'].includes(type)) {
    throw createError('type must be notes, assignment, or video.', 400);
  }

  // For file-based types, a file upload is required
  if (type !== 'video' && !req.file) {
    throw createError('A file is required for notes and assignment types.', 400);
  }

  // For video type, a link is required
  if (type === 'video' && !videoLink) {
    throw createError('A video link is required for video type.', 400);
  }

  const materialData = {
    title,
    description,
    type,
    courseId,
    departmentId,
    uploadedBy: req.user._id,
    contributorName: req.user.name,
    status: 'pending',
  };

  // Stream the in-memory buffer to Cloudinary
  if (req.file) {
    const { url, publicId } = await uploadBuffer(req.file.buffer, 'edushare/materials');
    materialData.fileUrl = url;
    materialData.filePublicId = publicId;
  }

  if (videoLink) {
    materialData.videoLink = videoLink;
  }

  const material = await Material.create(materialData);

  res.status(201).json(success(material, 'Material submitted for review. Awaiting admin approval.'));
};

// ─── DELETE /api/materials/:id ─────────────────────────────────────────
// contributor (own materials only) or admin (any material)
const deleteMaterial = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  // Contributors can only delete their own materials
  if (req.user.role === 'contributor' && material.uploadedBy.toString() !== req.user._id.toString()) {
    throw createError('You can only delete your own materials.', 403);
  }

  // Clean up the file from Cloudinary if it exists
  if (material.filePublicId) {
    const resourceType = material.type === 'notes' || material.type === 'assignment' ? 'raw' : 'image';
    await deleteFile(material.filePublicId, resourceType);
  }

  await Material.findByIdAndDelete(req.params.id);

  res.json(success(null, 'Material deleted successfully.'));
};

module.exports = { getMaterials, getMyMaterials, getMaterialById, createMaterial, deleteMaterial };
