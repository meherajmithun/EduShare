/**
 * controllers/departmentController.js — Department CRUD
 *
 * GET  /api/departments        — PUBLIC. Returns only active departments.
 *                                Used by register screen (unauthenticated).
 * GET  /api/departments/all    — Super Admin: returns ALL departments (any status).
 * GET  /api/departments/:id    — authenticated.
 * POST /api/departments        — Super Admin only.
 * PUT  /api/departments/:id    — Super Admin only.
 * PUT  /api/departments/:id/activate   — Super Admin only.
 * PUT  /api/departments/:id/deactivate — Super Admin only.
 * DELETE /api/departments/:id  — Super Admin only.
 */

const Department = require('../models/Department');
const { success, createError } = require('../utils/apiResponse');

// ─── GET /api/departments — PUBLIC (no auth required) ─────────────────────
// Returns only ACTIVE departments. Used by register screen before login.
const getDepartments = async (req, res) => {
  const departments = await Department.find({ isActive: true }).sort({ name: 1 });
  res.json(success(departments, 'Departments fetched successfully.'));
};

// ─── GET /api/departments/all — Super Admin only ───────────────────────────
// Returns ALL departments regardless of isActive status.
const getAllDepartments = async (req, res) => {
  const departments = await Department.find().sort({ name: 1 });
  res.json(success(departments, 'All departments fetched successfully.'));
};

// ─── GET /api/departments/:id ──────────────────────────────────────────────
const getDepartmentById = async (req, res) => {
  const dept = await Department.findById(req.params.id);
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept));
};

// ─── POST /api/departments — Super Admin only ─────────────────────────────
const createDepartment = async (req, res) => {
  const { name, code, description } = req.body;
  if (!name || !code) throw createError('Name and code are required.', 400);

  const dept = await Department.create({ name, code, description, isActive: true });
  res.status(201).json(success(dept, 'Department created.'));
};

// ─── PUT /api/departments/:id — Super Admin only ──────────────────────────
const updateDepartment = async (req, res) => {
  // Disallow changing isActive via this route (use activate/deactivate)
  const { isActive, ...rest } = req.body;
  const dept = await Department.findByIdAndUpdate(req.params.id, rest, {
    new: true,
    runValidators: true,
  });
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept, 'Department updated.'));
};

// ─── PUT /api/departments/:id/activate — Super Admin only ─────────────────
const activateDepartment = async (req, res) => {
  const dept = await Department.findByIdAndUpdate(
    req.params.id,
    { isActive: true },
    { new: true }
  );
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept, 'Department activated.'));
};

// ─── PUT /api/departments/:id/deactivate — Super Admin only ───────────────
const deactivateDepartment = async (req, res) => {
  const dept = await Department.findByIdAndUpdate(
    req.params.id,
    { isActive: false },
    { new: true }
  );
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept, 'Department deactivated. It will no longer appear in signup and upload forms.'));
};

// ─── DELETE /api/departments/:id — Super Admin only ───────────────────────
const deleteDepartment = async (req, res) => {
  const dept = await Department.findByIdAndDelete(req.params.id);
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(null, 'Department deleted.'));
};

module.exports = {
  getDepartments,
  getAllDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  activateDepartment,
  deactivateDepartment,
  deleteDepartment,
};
