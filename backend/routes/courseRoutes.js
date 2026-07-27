const express = require('express');
const router = express.Router();
const {
  getCourses,
  getCourseById,
  createCourse,
  updateCourse,
  deleteCourse,
} = require('../controllers/courseController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

router.get('/', protect, getCourses);           // ?departmentId=<id>
router.get('/:id', protect, getCourseById);
router.post('/', protect, roleGuard('admin'), createCourse);
router.put('/:id', protect, roleGuard('admin'), updateCourse);
router.delete('/:id', protect, roleGuard('admin'), deleteCourse);

module.exports = router;
