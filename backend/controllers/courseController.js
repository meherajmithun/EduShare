/**
 * controllers/courseController.js — Course CRUD
 */

const Course = require('../models/Course');
const Department = require('../models/Department');
const { success, createError } = require('../utils/apiResponse');

// GET /api/courses?departmentId=<id>
const getCourses = async (req, res) => {
  const { departmentId } = req.query;
  const filter = departmentId ? { departmentId } : {};
  const courses = await Course.find(filter).sort({ code: 1 });
  res.json(success(courses, 'Courses fetched successfully.'));
};

// GET /api/courses/:id
const getCourseById = async (req, res) => {
  const course = await Course.findById(req.params.id).populate('departmentId', 'name code');
  if (!course) throw createError('Course not found.', 404);
  res.json(success(course));
};

// POST /api/courses (admin only)
const createCourse = async (req, res) => {
  const { name, code, departmentId } = req.body;
  if (!name || !code || !departmentId) throw createError('name, code, and departmentId are required.', 400);

  const dept = await Department.findById(departmentId);
  if (!dept) throw createError('Department not found.', 404);

  const course = await Course.create({ name, code, departmentId });
  res.status(201).json(success(course, 'Course created.'));
};

// PUT /api/courses/:id (admin only)
const updateCourse = async (req, res) => {
  const course = await Course.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true,
  });
  if (!course) throw createError('Course not found.', 404);
  res.json(success(course, 'Course updated.'));
};

// DELETE /api/courses/:id (admin only)
const deleteCourse = async (req, res) => {
  const course = await Course.findByIdAndDelete(req.params.id);
  if (!course) throw createError('Course not found.', 404);
  res.json(success(null, 'Course deleted.'));
};

module.exports = { getCourses, getCourseById, createCourse, updateCourse, deleteCourse };
