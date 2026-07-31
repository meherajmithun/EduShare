const express = require('express');
const router = express.Router();
const {
  getCourses,
  getCourseById,
  createCourse,
  updateCourse,
  toggleCourseStatus,
  deleteCourse,
} = require('../controllers/courseController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// Any authenticated user can browse courses (students, contributors, admins)
router.get('/', protect, getCourses);
router.get('/:id', protect, getCourseById);

// Course management — faculty_admin (own dept), admin, super_admin
const adminRoles = roleGuard('faculty_admin', 'admin', 'super_admin');
router.post('/', protect, adminRoles, createCourse);
router.put('/:id', protect, adminRoles, updateCourse);
router.patch('/:id/status', protect, adminRoles, toggleCourseStatus);
router.delete('/:id', protect, adminRoles, deleteCourse);

module.exports = router;
