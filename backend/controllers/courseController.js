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
const Material = require('../models/Material');
const VideoProgress = require('../models/VideoProgress');
const VideoBookmark = require('../models/VideoBookmark');
const { success, createError } = require('../utils/apiResponse');

// ─── Helper: calculate student course progress and completions ─────────
const getStudentCourseProgressData = async (userId) => {
  const [progressRecords, bookmarks] = await Promise.all([
    VideoProgress.find({ userId }).populate('materialId').populate('courseId'),
    VideoBookmark.find({ userId }),
  ]);

  // Group progress records by courseId
  const courseMap = {};
  for (const prog of progressRecords) {
    if (!prog.courseId || !prog.courseId._id) continue;
    const cid = prog.courseId._id.toString();
    if (!courseMap[cid]) {
      courseMap[cid] = {
        course: prog.courseId,
        records: [],
      };
    }
    courseMap[cid].records.push(prog);
  }

  const continueLearning = [];
  const completedCourses = [];

  for (const [cid, entry] of Object.entries(courseMap)) {
    const course = entry.course;
    // Find all approved materials/videos for this course
    const allMaterials = await Material.find({ courseId: course._id, approvalStatus: 'approved' });
    const totalMaterials = allMaterials.length;
    if (totalMaterials === 0) continue;

    // Calculate progress
    let totalRatio = 0;
    let completedCount = 0;
    let lastWatchedAt = new Date(0);
    let mostRecentRecord = null;

    for (const mat of allMaterials) {
      const rec = entry.records.find((r) => r.materialId && r.materialId._id.toString() === mat._id.toString());
      if (rec) {
        if (rec.lastWatchedAt && new Date(rec.lastWatchedAt) > lastWatchedAt) {
          lastWatchedAt = new Date(rec.lastWatchedAt);
          mostRecentRecord = rec;
        }
        if (rec.completed) {
          completedCount++;
          totalRatio += 1.0;
        } else if (rec.duration > 0 && rec.lastPosition > 0) {
          totalRatio += Math.min(0.95, rec.lastPosition / rec.duration);
        }
      }
    }

    const progressPercentage = Math.min(100, Math.round((totalRatio / totalMaterials) * 100));
    const isCompleted = (completedCount === totalMaterials && totalMaterials > 0) || progressPercentage === 100;

    // Find instructor/contributor name from materials
    const instructor = allMaterials.find((m) => m.contributorName)?.contributorName || 'Faculty Instructor';

    const courseData = {
      id: course._id.toString(),
      name: course.name,
      code: course.code,
      departmentId: course.departmentId?.toString() ?? '',
      instructor,
      progressPercentage: isCompleted ? 100 : Math.max(progressPercentage, 1),
      completedVideos: completedCount,
      totalVideos: totalMaterials,
      lastPosition: mostRecentRecord?.lastPosition || 0,
      duration: mostRecentRecord?.duration || 0,
      lastWatchedVideoId: mostRecentRecord?.materialId?._id?.toString() || null,
      lastWatchedVideoTitle: mostRecentRecord?.materialId?.title || null,
      lastWatchedAt,
    };

    if (isCompleted) {
      completedCourses.push(courseData);
    } else if (progressPercentage > 0) {
      continueLearning.push(courseData);
    }
  }

  // Sort continueLearning by most recently watched
  continueLearning.sort((a, b) => new Date(b.lastWatchedAt) - new Date(a.lastWatchedAt));
  completedCourses.sort((a, b) => new Date(b.lastWatchedAt) - new Date(a.lastWatchedAt));

  return {
    continueLearning,
    completedCourses,
    completedCount: completedCourses.length,
    downloads: progressRecords.length,
    savedNotes: bookmarks.length,
  };
};

// ─── GET /api/courses/learning-progress ────────────────────────────────
const getStudentLearningProgress = async (req, res) => {
  const data = await getStudentCourseProgressData(req.user._id);
  res.json(success(data, 'Student learning progress fetched.'));
};

// ─── Helper: assert faculty_admin / admin owns this course's department ─
const assertDeptOwnership = (user, course) => {
  if (user.role === 'super_admin') {
    throw createError('Super Admins do not manage courses. Department Admins manage courses for their respective departments.', 403);
  }
  if (user.role === 'faculty_admin' || user.role === 'admin') {
    const courseDeptId = course.departmentId?.toString();
    const userDeptId = user.departmentId?.toString();
    if (userDeptId && courseDeptId) {
      if (courseDeptId !== userDeptId) {
        throw createError('You can only manage courses in your own department.', 403);
      }
    } else if (!userDeptId) {
      throw createError('Your account has no department assigned. Contact a Super Admin.', 403);
    }
  } else {
    throw createError('Unauthorized to manage courses.', 403);
  }
};

// ─── GET /api/courses?departmentId=&includeAll=true ───────────────────
const getCourses = async (req, res) => {
  const { departmentId, includeAll } = req.query;

  const filter = {};
  if (['student', 'contributor'].includes(req.user?.role)) {
    // Students and contributors ONLY see courses from their own department
    let deptId = req.user.departmentId;
    if (!deptId && req.user.department) {
      const dept = await Department.findOne({
        $or: [
          { name: new RegExp('^' + req.user.department.trim() + '$', 'i') },
          { code: new RegExp('^' + req.user.department.trim() + '$', 'i') },
        ],
      });
      if (dept) deptId = dept._id;
    }
    filter.departmentId = deptId || '000000000000000000000000';
  } else if (['faculty_admin', 'admin'].includes(req.user?.role) && req.user?.departmentId) {
    filter.departmentId = req.user.departmentId;
  } else if (departmentId) {
    filter.departmentId = departmentId;
  }

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

  if (req.user?.role === 'student') {
    let studentDeptId = req.user.departmentId?.toString();
    if (!studentDeptId && req.user.department) {
      const dept = await Department.findOne({
        $or: [
          { name: new RegExp('^' + req.user.department.trim() + '$', 'i') },
          { code: new RegExp('^' + req.user.department.trim() + '$', 'i') },
        ],
      });
      if (dept) studentDeptId = dept._id.toString();
    }
    const courseDeptId = (course.departmentId?._id || course.departmentId)?.toString();
    if (studentDeptId && courseDeptId && courseDeptId !== studentDeptId) {
      throw createError('Access denied. You can only view courses from your own department.', 403);
    }
  }

  res.json(success(course));
};

// ─── POST /api/courses ────────────────────────────────────────────────
const createCourse = async (req, res) => {
  if (req.user.role === 'super_admin') {
    throw createError('Super Admins do not manage courses. Department Admins manage courses for their respective departments.', 403);
  }

  const { name, code, semester, credit } = req.body;
  let { departmentId } = req.body;

  if (!name || !code) {
    throw createError('name and code are required.', 400);
  }

  // faculty_admin and admin must use their own department
  if (req.user.role === 'faculty_admin' || req.user.role === 'admin') {
    if (!req.user.departmentId && req.user.department) {
      const escaped = req.user.department.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      let dept = await Department.findOne({ name: new RegExp('^' + escaped + '$', 'i') });
      if (!dept) {
        dept = await Department.create({
          name: req.user.department,
          code: req.user.department.substring(0, 4).toUpperCase().replace(/[^A-Z]/gi, '') || 'DEPT',
        });
      }
      req.user.departmentId = dept._id;
      await req.user.save();
    }

    if (!req.user.departmentId) {
      throw createError('Your account has no department assigned. Contact a Super Admin.', 403);
    }
    departmentId = req.user.departmentId.toString();
  } else {
    throw createError('Unauthorized to create courses.', 403);
  }

  if (!departmentId) {
    throw createError('departmentId is required.', 400);
  }

  const dept = await Department.findById(departmentId);
  if (!dept) throw createError('Department not found.', 404);

  const course = await Course.create({
    name: name.trim(),
    code: code.trim().toUpperCase(),
    departmentId,
    semester: semester ? semester.trim() : '',
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
  getStudentLearningProgress,
  getStudentCourseProgressData,
};
