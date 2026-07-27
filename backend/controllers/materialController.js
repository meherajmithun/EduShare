/**
 * controllers/materialController.js — Material upload, browsing, deletion
 *
 * Department-based approval workflow:
 *   On upload → find the active Faculty Admin for the material's department.
 *               Set assignedAdmin automatically. Send notification to Faculty Admin.
 */

const Material = require('../models/Material');
const User = require('../models/User');
const Department = require('../models/Department');
const { uploadBuffer, deleteFile } = require('../services/cloudinaryService');
const { notifyFacultyAdminOnUpload } = require('../services/notificationService');
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

// ─── GET /api/materials?courseId=&type= ────────────────────────────────
// Returns approved materials only (public browsing for students)
const getMaterials = async (req, res) => {
  const { courseId, type } = req.query;

  const filter = { approvalStatus: 'approved' };
  if (courseId) filter.courseId = courseId;
  if (type) filter.type = type;

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
const createMaterial = async (req, res) => {
  const { title, description, type, videoLink, courseId, departmentId } = req.body;

  if (!title || !description || !type || !courseId || !departmentId) {
    throw createError('title, description, type, courseId, and departmentId are required.', 400);
  }

  if (!['notes', 'assignment', 'video'].includes(type)) {
    throw createError('type must be notes, assignment, or video.', 400);
  }

  if (type !== 'video' && !req.file) {
    throw createError('A file is required for notes and assignment types.', 400);
  }

  if (type === 'video' && !videoLink) {
    throw createError('A video link is required for video type.', 400);
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

  if (req.file) {
    const { url, publicId } = await uploadBuffer(req.file.buffer, 'edushare/materials');
    materialData.fileUrl = url;
    materialData.filePublicId = publicId;
  }

  if (videoLink) materialData.videoLink = videoLink;

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
    const resourceType =
      material.type === 'notes' || material.type === 'assignment' ? 'raw' : 'image';
    await deleteFile(material.filePublicId, resourceType);
  }

  await Material.findByIdAndDelete(req.params.id);

  res.json(success(null, 'Material deleted successfully.'));
};

module.exports = {
  getMaterials,
  getMyMaterials,
  getMaterialById,
  createMaterial,
  deleteMaterial,
};
