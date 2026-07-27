/**
 * controllers/departmentController.js — Department CRUD
 */

const Department = require('../models/Department');
const { success, createError } = require('../utils/apiResponse');

// GET /api/departments
const getDepartments = async (req, res) => {
  const departments = await Department.find().sort({ name: 1 });
  res.json(success(departments, 'Departments fetched successfully.'));
};

// GET /api/departments/:id
const getDepartmentById = async (req, res) => {
  const dept = await Department.findById(req.params.id);
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept));
};

// POST /api/departments (admin only)
const createDepartment = async (req, res) => {
  const { name, code, description } = req.body;
  if (!name || !code) throw createError('Name and code are required.', 400);

  const dept = await Department.create({ name, code, description });
  res.status(201).json(success(dept, 'Department created.'));
};

// PUT /api/departments/:id (admin only)
const updateDepartment = async (req, res) => {
  const dept = await Department.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true,
  });
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(dept, 'Department updated.'));
};

// DELETE /api/departments/:id (admin only)
const deleteDepartment = async (req, res) => {
  const dept = await Department.findByIdAndDelete(req.params.id);
  if (!dept) throw createError('Department not found.', 404);
  res.json(success(null, 'Department deleted.'));
};

module.exports = { getDepartments, getDepartmentById, createDepartment, updateDepartment, deleteDepartment };
