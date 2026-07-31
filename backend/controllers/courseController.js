/**
 * controllers/courseController.js — Department-scoped Course CRUD
 *
 * Authorization rules:
 *  - GET  /api/courses            → any authenticated user (students, contributors, admins)
 *                                   Default: only active courses.
 *                                   Pass ?includeAll=true to get all statuses (admin management).
 *  - POST /api/courses            → faculty_admin (auto dept), admin/super_admin (pass deptId)
 *  - PUT  /api/courses/:id        → faculty_admin (own dept only), admin, super_admin
 *  - DELETE /api/courses/:id      → faculty_admin (own dept only), admin, super_admin
 *  - PATCH /api/courses/:id/status → faculty_admin (own dept only), admin, super_admin
 */

const Course = require('../models/Course');
const Department = require('../models/Department');
const { success, createError } = require('../utils/apiResponse');

// ─── Helper: assert faculty_admin / admin owns this course's department ─
const assertDeptOwnership = (user, course) => {
  if (user.role === 'faculty_admin' || user.role === 'admin') {
    const courseDeptId = course.departmentId?.toString();
    const userDeptId = user.departmentId?.toString();
    if (!userDeptId || courseDeptId !== userDeptId) {
      throw createError('You can only manage courses in your own department.', 403);
    }
  }
};

// ─── GET /api/courses?departmentId=&includeAll=true ───────────────────
const getCourses = async (req, res) => {
  const { departmentId, includeAll } = req.query;

  const filter = {};
  if (departmentId) filter.departmentId = departmentId;

  // By default only return active courses; admins can pass includeAll=true
  const isAdmin = ['faculty_admin', 'admin', 'super_admin'].includes(req.user?.role);
  if (!isAdmin || includeAll !== 'true') {
    filter.status = 'active';
  }

  const courses = await Course.find(filter).sort({ code: 1 });
  res.json(success(courses, 'Courses fetched successfully.'));
};

// ─── GET /api/courses/:id ─────────────────────────────────────────────
const getCourseById = async (req, res) => {
  const course = await Course.findById(req.params.id).populate('departmentId', 'name code');
  if (!course) throw createError('Course not found.', 404);
  res.json(success(course));
};

// ─── POST /api/courses ────────────────────────────────────────────────
const createCourse = async (req, res) => {
  const { name, code, semester, credit } = req.body;
  let { departmentId } = req.body;

  if (!name || !code) {
    throw createError('name and code are required.', 400);
  }

  // faculty_admin and admin must use their own department
  if (req.user.role === 'faculty_admin' || req.user.role === 'admin') {
    if (!req.user.departmentId) {
      throw createError('Your account has no department assigned. Contact a Super Admin.', 403);
    }
    departmentId = req.user.departmentId.toString();
  }

  if (!departmentId) {
    throw createError('departmentId is required.', 400);
  }

  const dept = await Department.findById(departmentId);
  if (!dept) throw createError('Department not found.', 404);

  const course = await Course.create({
    name,
    code,
    departmentId,
    semester: semester || '',
    credit: credit !== undefined ? Number(credit) : 3,
    status: 'active',
  });

  res.status(201).json(success(course, 'Course created successfully.'));
};

// ─── PUT /api/courses/:id ─────────────────────────────────────────────
const updateCourse = async (req, res) => {
  const course = await Course.findById(req.params.id);
  if (!course) throw createError('Course not found.', 404);

  assertDeptOwnership(req.user, course);

  const { name, code, semester, credit, status } = req.body;
  if (name !== undefined) course.name = name;
  if (code !== undefined) course.code = code;
  if (semester !== undefined) course.semester = semester;
  if (credit !== undefined) course.credit = Number(credit);
  if (status !== undefined) {
    if (!['active', 'inactive'].includes(status)) {
      throw createError('status must be active or inactive.', 400);
    }
    course.status = status;
  }

  await course.save();
  res.json(success(course, 'Course updated successfully.'));
};

// ─── PATCH /api/courses/:id/status ────────────────────────────────────
const toggleCourseStatus = async (req, res) => {
  const course = await Course.findById(req.params.id);
  if (!course) throw createError('Course not found.', 404);

  assertDeptOwnership(req.user, course);

  course.status = course.status === 'active' ? 'inactive' : 'active';
  await course.save();

  res.json(success(course, `Course ${course.status === 'active' ? 'activated' : 'deactivated'} successfully.`));
};

// ─── DELETE /api/courses/:id ──────────────────────────────────────────
const deleteCourse = async (req, res) => {
  const course = await Course.findById(req.params.id);
  if (!course) throw createError('Course not found.', 404);

  assertDeptOwnership(req.user, course);

  await Course.findByIdAndDelete(req.params.id);
  res.json(success(null, 'Course deleted successfully.'));
};

module.exports = {
  getCourses,
  getCourseById,
  createCourse,
  updateCourse,
  toggleCourseStatus,
  deleteCourse,
};
