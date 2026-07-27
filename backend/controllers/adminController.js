/**
 * controllers/adminController.js — Admin approval workflow + stats
 */

const Material = require('../models/Material');
const User = require('../models/User');
const { success, createError } = require('../utils/apiResponse');

// ─── GET /api/admin/pending ────────────────────────────────────────────
const getPendingMaterials = async (req, res) => {
  const pending = await Material.find({ status: 'pending' }).sort({ createdAt: 1 });
  res.json(success(pending, 'Pending materials fetched.'));
};

// ─── PUT /api/admin/approve/:id ────────────────────────────────────────
const approveMaterial = async (req, res) => {
  const material = await Material.findByIdAndUpdate(
    req.params.id,
    { status: 'approved' },
    { new: true }
  );
  if (!material) throw createError('Material not found.', 404);
  res.json(success(material, 'Material approved successfully.'));
};

// ─── PUT /api/admin/reject/:id ─────────────────────────────────────────
const rejectMaterial = async (req, res) => {
  const material = await Material.findByIdAndUpdate(
    req.params.id,
    { status: 'rejected' },
    { new: true }
  );
  if (!material) throw createError('Material not found.', 404);
  res.json(success(material, 'Material rejected.'));
};

// ─── GET /api/admin/stats ──────────────────────────────────────────────
// Dashboard summary counts
const getStats = async (req, res) => {
  const [totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount] = await Promise.all([
    User.countDocuments({ isActive: true }),
    Material.countDocuments(),
    Material.countDocuments({ status: 'pending' }),
    Material.countDocuments({ status: 'approved' }),
    Material.countDocuments({ status: 'rejected' }),
  ]);

  res.json(
    success(
      { totalUsers, totalMaterials, pendingCount, approvedCount, rejectedCount },
      'Stats fetched.'
    )
  );
};

// ─── GET /api/admin/materials ──────────────────────────────────────────
// All materials regardless of status (admin overview)
const getAllMaterials = async (req, res) => {
  const { status } = req.query;
  const filter = status ? { status } : {};
  const materials = await Material.find(filter).sort({ createdAt: -1 });
  res.json(success(materials, 'All materials fetched.'));
};

module.exports = { getPendingMaterials, approveMaterial, rejectMaterial, getStats, getAllMaterials };
