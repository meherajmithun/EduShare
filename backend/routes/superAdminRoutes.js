/**
 * routes/superAdminRoutes.js — Super Admin exclusive endpoints
 *
 * Mounted at: /api/super-admin
 * Guard: JWT + role = 'super_admin'
 */
const express = require('express');
const router = express.Router();
const {
  getPendingFacultyAdmins,
  getAllFacultyAdmins,
  approveFacultyAdmin,
  rejectFacultyAdmin,
  disableFacultyAdmin,
  enableFacultyAdmin,
  deleteFacultyAdmin,
  getSuperAdminStats,
  getAllUsers,
} = require('../controllers/superAdminController');
const {
  getAllDepartments,
  createDepartment,
  updateDepartment,
  activateDepartment,
  deactivateDepartment,
  deleteDepartment,
} = require('../controllers/departmentController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// All routes require Super Admin JWT
router.use(protect, roleGuard('super_admin'));

// ─── Stats ────────────────────────────────────────────────────────────
router.get('/stats', getSuperAdminStats);

// ─── Users (global view) ──────────────────────────────────────────────
router.get('/users', getAllUsers);

// ─── Faculty Admin management ─────────────────────────────────────────
router.get('/faculty-admins/pending', getPendingFacultyAdmins);
router.get('/faculty-admins', getAllFacultyAdmins);           // ?status=pending|active|disabled
router.put('/faculty-admins/:id/approve', approveFacultyAdmin);
router.put('/faculty-admins/:id/reject', rejectFacultyAdmin);
router.put('/faculty-admins/:id/disable', disableFacultyAdmin);
router.put('/faculty-admins/:id/enable', enableFacultyAdmin);
router.delete('/faculty-admins/:id', deleteFacultyAdmin);

// ─── Department management ────────────────────────────────────────────────
router.get('/departments', getAllDepartments);
router.post('/departments', createDepartment);
router.put('/departments/:id', updateDepartment);
router.put('/departments/:id/activate', activateDepartment);
router.put('/departments/:id/deactivate', deactivateDepartment);
router.delete('/departments/:id', deleteDepartment);

module.exports = router;
