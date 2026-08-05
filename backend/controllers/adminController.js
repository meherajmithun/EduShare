/**
 * controllers/adminController.js — Material approval + stats
 *
 * Department-based approval workflow with notifications:
 *
 * Faculty Admin:
 *   GET /api/admin/pending  → only materials where assignedAdmin = req.user._id
 *   PUT /api/admin/approve/:id → must be assignedAdmin; notifies contributor
 *   PUT /api/admin/reject/:id  → must be assignedAdmin; notifies contributor with reason
 *
 * Super Admin / Legacy Admin:
 *   GET /api/admin/pending  → all pending materials
 *   PUT /api/admin/approve/:id → any material; notifies contributor
 *   PUT /api/admin/reject/:id  → any material; notifies contributor with reason
 */

const Material = require('../models/Material');
const User = require('../models/User');
const {
  notifyContributorOnApproval,
  notifyContributorOnRejection,
  notifyContributorOnAccountApproval,
  notifyContributorOnAccountRejection,
  notifyStudentsOnMaterialApproval,
} = require('../services/notificationService');
const { success, createError } = require('../utils/apiResponse');

// ─── GET /api/admin/pending ────────────────────────────────────────────
const getPendingMaterials = async (req, res) => {
  const filter = { approvalStatus: 'pending' };

  if (req.user.role === 'faculty_admin') {
    filter.assignedAdmin = req.user._id;
  }

  const pending = await Material.find(filter).sort({ createdAt: 1 });
  res.json(success(pending, 'Pending materials fetched.'));
};

// ─── PUT /api/admin/approve/:id ────────────────────────────────────────
const approveMaterial = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (
    req.user.role === 'faculty_admin' &&
    material.assignedAdmin?.toString() !== req.user._id.toString()
  ) {
    throw createError('Access denied. This material is not assigned to you.', 403);
  }

  if (material.approvalStatus === 'approved') {
    throw createError('This material is already approved.', 400);
  }

  const reviewComment = (req.body.reviewComment && req.body.reviewComment.trim())
    ? req.body.reviewComment.trim()
    : null;

  material.approvalStatus = 'approved';
  material.status = 'approved';
  material.approvedBy = req.user._id;
  material.approvedByName = req.user.name;
  material.approvedAt = new Date();
  material.rejectionReason = null;
  material.reviewComment = reviewComment;

  await material.save();

  // ── Notify contributor (fire-and-forget) ──────────────────────────────
  notifyContributorOnApproval({ material, admin: req.user });

  // ── Notify all students in this department (fire-and-forget) ──────────
  notifyStudentsOnMaterialApproval({ material });

  res.json(success(material.toJSON(), 'Material approved successfully.'));
};

// ─── PUT /api/admin/reject/:id ─────────────────────────────────────────
const rejectMaterial = async (req, res) => {
  const { reason, reviewComment } = req.body;

  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (
    req.user.role === 'faculty_admin' &&
    material.assignedAdmin?.toString() !== req.user._id.toString()
  ) {
    throw createError('Access denied. This material is not assigned to you.', 403);
  }

  if (material.approvalStatus === 'rejected') {
    throw createError('This material is already rejected.', 400);
  }

  const rejectionReason = reason && reason.trim() ? reason.trim() : 'No reason provided.';
  const adminReviewComment = (reviewComment && reviewComment.trim())
    ? reviewComment.trim()
    : null;

  material.approvalStatus = 'rejected';
  material.status = 'rejected';
  material.approvedBy = req.user._id;
  material.approvedByName = req.user.name;
  material.approvedAt = new Date();
  material.rejectionReason = rejectionReason;
  material.reviewComment = adminReviewComment;

  await material.save();

  // ── Notify the contributor with the rejection reason (fire-and-forget) ──
  notifyContributorOnRejection({ material, admin: req.user, reason: rejectionReason });

  res.json(success(material.toJSON(), 'Material rejected.'));
};

// ─── GET /api/admin/stats ──────────────────────────────────────────────
const getStats = async (req, res) => {
  let matFilter = {};
  let userFilter = {};

  if (req.user.role === 'faculty_admin' || req.user.role === 'admin') {
    matFilter.assignedAdmin = req.user._id;
    userFilter.department = req.user.department;
  }

  const [totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount, pendingContributors] =
    await Promise.all([
      User.countDocuments({ ...userFilter, isActive: true, status: 'active' }),
      Material.countDocuments(matFilter),
      Material.countDocuments({ ...matFilter, approvalStatus: 'pending' }),
      Material.countDocuments({ ...matFilter, approvalStatus: 'approved' }),
      Material.countDocuments({ ...matFilter, approvalStatus: 'rejected' }),
      User.countDocuments({ ...userFilter, role: 'contributor', status: 'pending' }),
    ]);

  res.json(
    success(
      { totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount, pendingContributors },
      'Stats fetched.'
    )
  );
};

// ─── GET /api/admin/materials ──────────────────────────────────────────
const getAllMaterials = async (req, res) => {
  const { status } = req.query;
  const filter = {};

  if (req.user.role === 'faculty_admin') {
    filter.assignedAdmin = req.user._id;
  }

  if (status) filter.approvalStatus = status;

  const materials = await Material.find(filter).sort({ createdAt: -1 });
  res.json(success(materials, 'All materials fetched.'));
};

// ─── GET /api/admin/pending-contributors ────────────────────────────────
const getPendingContributors = async (req, res) => {
  const filter = { role: 'contributor', status: 'pending' };

  // Faculty Admin sees only their department; super/legacy admin sees all
  if (req.user.role === 'faculty_admin') {
    filter.department = req.user.department;
  }

  const contributors = await User.find(filter)
    .sort({ createdAt: 1 })
    .select('-password');
  res.json(success(contributors, 'Pending contributors fetched.'));
};

// ─── PUT /api/admin/contributors/:id/approve ──────────────────────────
const approveContributor = async (req, res) => {
  const contributor = await User.findOne({ _id: req.params.id, role: 'contributor' });
  if (!contributor) throw createError('Contributor not found.', 404);

  // Faculty Admin can only approve contributors from their own department
  if (
    req.user.role === 'faculty_admin' &&
    contributor.department !== req.user.department
  ) {
    throw createError('Access denied. This contributor is not in your department.', 403);
  }

  if (contributor.status === 'active') {
    throw createError('This contributor is already approved.', 400);
  }

  contributor.status = 'active';
  contributor.verifiedBy = req.user._id;
  contributor.verifiedAt = new Date();
  contributor.rejectionReason = null;
  await contributor.save();

  // Notify contributor (fire-and-forget)
  notifyContributorOnAccountApproval({ contributor, admin: req.user });

  res.json(success(contributor.toJSON(), 'Contributor approved. They can now log in and upload materials.'));
};

// ─── PUT /api/admin/contributors/:id/reject ───────────────────────────
const rejectContributor = async (req, res) => {
  const { reason } = req.body;

  const contributor = await User.findOne({ _id: req.params.id, role: 'contributor' });
  if (!contributor) throw createError('Contributor not found.', 404);

  // Faculty Admin can only reject contributors from their own department
  if (
    req.user.role === 'faculty_admin' &&
    contributor.department !== req.user.department
  ) {
    throw createError('Access denied. This contributor is not in your department.', 403);
  }

  if (contributor.status === 'rejected') {
    throw createError('This contributor registration is already rejected.', 400);
  }

  const rejectionReason = reason && reason.trim() ? reason.trim() : 'No reason provided.';

  contributor.status = 'rejected';
  contributor.verifiedBy = req.user._id;
  contributor.verifiedAt = new Date();
  contributor.rejectionReason = rejectionReason;
  await contributor.save();

  // Notify contributor (fire-and-forget)
  notifyContributorOnAccountRejection({ contributor, admin: req.user, reason: rejectionReason });

  res.json(success(contributor.toJSON(), 'Contributor registration rejected.'));
};

module.exports = {
  getPendingMaterials,
  approveMaterial,
  rejectMaterial,
  getStats,
  getAllMaterials,
  getPendingContributors,
  approveContributor,
  rejectContributor,
};
