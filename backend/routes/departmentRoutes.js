const express = require('express');
const router = express.Router();
const {
  getDepartments,
  getAllDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  activateDepartment,
  deactivateDepartment,
  deleteDepartment,
} = require('../controllers/departmentController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// ─── PUBLIC route — no auth needed (used by register screen) ─────────────
// Returns ONLY active departments.
router.get('/', getDepartments);

// ─── Authenticated routes ─────────────────────────────────────────────────
// Super Admin gets ALL departments (any status) for management
router.get('/all', protect, roleGuard('super_admin'), getAllDepartments);
router.get('/:id', protect, getDepartmentById);

// Super Admin CRUD
router.post('/', protect, roleGuard('super_admin'), createDepartment);
router.put('/:id', protect, roleGuard('super_admin'), updateDepartment);
router.put('/:id/activate', protect, roleGuard('super_admin'), activateDepartment);
router.put('/:id/deactivate', protect, roleGuard('super_admin'), deactivateDepartment);
router.delete('/:id', protect, roleGuard('super_admin'), deleteDepartment);

module.exports = router;
