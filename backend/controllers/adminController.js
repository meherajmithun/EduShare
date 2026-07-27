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

  material.approvalStatus = 'approved';
  material.status = 'approved';
  material.approvedBy = req.user._id;
  material.approvedByName = req.user.name;
  material.approvedAt = new Date();
  material.rejectionReason = null;

  await material.save();

  // ── Notify the contributor (fire-and-forget) ───────────────────────────
  notifyContributorOnApproval({ material, admin: req.user });

  res.json(success(material.toJSON(), 'Material approved successfully.'));
};

// ─── PUT /api/admin/reject/:id ─────────────────────────────────────────
const rejectMaterial = async (req, res) => {
  const { reason } = req.body;

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

  material.approvalStatus = 'rejected';
  material.status = 'rejected';
  material.approvedBy = req.user._id;
  material.approvedByName = req.user.name;
  material.approvedAt = new Date();
  material.rejectionReason = rejectionReason;

  await material.save();

  // ── Notify the contributor with the rejection reason (fire-and-forget) ──
  notifyContributorOnRejection({ material, admin: req.user, reason: rejectionReason });

  res.json(success(material.toJSON(), 'Material rejected.'));
};

// ─── GET /api/admin/stats ──────────────────────────────────────────────
const getStats = async (req, res) => {
  let matFilter = {};
  let userFilter = {};

  if (req.user.role === 'faculty_admin') {
    matFilter.assignedAdmin = req.user._id;
    userFilter.department = req.user.department;
  }

  const [totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount] =
    await Promise.all([
      User.countDocuments({ ...userFilter, isActive: true, status: 'active' }),
      Material.countDocuments(matFilter),
      Material.countDocuments({ ...matFilter, approvalStatus: 'pending' }),
      Material.countDocuments({ ...matFilter, approvalStatus: 'approved' }),
      Material.countDocuments({ ...matFilter, approvalStatus: 'rejected' }),
    ]);

  res.json(
    success(
      { totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount },
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

module.exports = {
  getPendingMaterials,
  approveMaterial,
  rejectMaterial,
  getStats,
  getAllMaterials,
};
