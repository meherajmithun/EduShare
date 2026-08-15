const express = require('express');
const router = express.Router();
const {
  getCourses,
  getCourseById,
  createCourse,
  updateCourse,
  toggleCourseStatus,
  deleteCourse,
  getStudentLearningProgress,
} = require('../controllers/courseController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// Student learning progress — MUST be before /:id route
router.get('/learning-progress', protect, getStudentLearningProgress);

// Any authenticated user can browse courses (students, contributors, admins)
router.get('/', protect, getCourses);
router.get('/:id', protect, getCourseById);

// Course management — faculty_admin (own dept) and admin only. Super admin does not manage courses.
const deptAdminRoles = roleGuard('faculty_admin', 'admin');
router.post('/', protect, deptAdminRoles, createCourse);
router.put('/:id', protect, deptAdminRoles, updateCourse);
router.patch('/:id/status', protect, deptAdminRoles, toggleCourseStatus);
router.delete('/:id', protect, deptAdminRoles, deleteCourse);

module.exports = router;
