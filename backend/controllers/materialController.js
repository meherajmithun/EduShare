/**
 * controllers/materialController.js — Material upload, browsing, deletion + material ratings
 *
 * Department-based approval workflow:
 *   On upload → find the active Faculty Admin for the material's department.
 *               Set assignedAdmin automatically. Send notification to Faculty Admin.
 *
 * Student access: getMaterials is scoped to the student's departmentId.
 * Contributor access: createMaterial validates departmentId matches own department.
 *
 * Video source logic:
 *   type === 'video' && videoSource === 'youtube'    → store videoLink, no file upload
 *   type === 'video' && videoSource === 'cloudinary' → upload req.file as video to Cloudinary
 *   type === 'pdf' | 'notes' | 'assignment'          → upload req.file as raw to Cloudinary
 *
 * Material Rating endpoints (students only):
 *   GET    /api/materials/:id/ratings   — all ratings + caller's own rating
 *   POST   /api/materials/:id/ratings   — submit rating (students only)
 *   PUT    /api/materials/:id/ratings   — update own rating
 *   DELETE /api/materials/:id/ratings   — delete own rating
 */

const path = require('path');
const https = require('https');
const http = require('http');
const Material = require('../models/Material');
const MaterialRating = require('../models/MaterialRating');
const PdfProgress = require('../models/PdfProgress');
const User = require('../models/User');
const Department = require('../models/Department');
const Course = require('../models/Course');
const { uploadBuffer, uploadVideoBuffer, deleteFile, cloudinary } = require('../services/cloudinaryService');
const { notifyFacultyAdminOnUpload, notifyContributorOnRatingSubmitted, notifyContributorOnRatingUpdated } = require('../services/notificationService');
const { success, createError } = require('../utils/apiResponse');

// ─── Helper: resolve department name from departmentId ─────────────────
const resolveDeptName = async (departmentId) => {
  try {
    const dept = await Department.findById(departmentId);
    return dept ? dept.name : '';
  } catch (_) {
    return '';
  }
};

// ─── Helper: find active Faculty Admin for a given departmentId ────────
const findFacultyAdminForDept = async (departmentId) => {
  return User.findOne({
    role: 'faculty_admin',
    status: 'active',
    departmentId,
  });
};

// ─── Helper: recalculate material avgRating + totalRatings, then
//             update the contributor's overall avgRating from all their
//             materials' ratings (aggregated). ──────────────────────────
const recalcMaterialRating = async (materialId, contributorId) => {
  // 1. Recalc this material's avg
  const [matResult] = await MaterialRating.aggregate([
    { $match: { materialId: materialId } },
    { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
  ]);
  const matAvg = matResult ? parseFloat(matResult.avg.toFixed(1)) : 0;
  const matCount = matResult ? matResult.count : 0;
  await Material.findByIdAndUpdate(materialId, { avgRating: matAvg, totalRatings: matCount });

  // 2. Recalc contributor's overall avg across ALL their material ratings
  const [contResult] = await MaterialRating.aggregate([
    { $match: { contributorId: contributorId } },
    { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
  ]);
  const contAvg = contResult ? parseFloat(contResult.avg.toFixed(1)) : 0;
  const contCount = contResult ? contResult.count : 0;
  await User.findByIdAndUpdate(contributorId, { avgRating: contAvg, totalRatings: contCount });

  return { matAvg, matCount };
};

// ─── GET /api/materials?courseId=&type= ────────────────────────────────
// Returns approved materials only.
// Students: scoped to their own departmentId automatically.
const getMaterials = async (req, res) => {
  const { courseId, type } = req.query;

  const filter = { approvalStatus: 'approved' };
  if (courseId) filter.courseId = courseId;
  if (type) filter.type = type;

  // Department-based access: students ONLY see materials from their own dept
  if (req.user && req.user.role === 'student') {
    let studentDeptId = req.user.departmentId;
    if (!studentDeptId && req.user.department) {
      const dept = await Department.findOne({
        $or: [
          { name: new RegExp('^' + req.user.department.trim() + '$', 'i') },
          { code: new RegExp('^' + req.user.department.trim() + '$', 'i') },
        ],
      });
      if (dept) studentDeptId = dept._id;
    }
    filter.departmentId = studentDeptId ? studentDeptId.toString() : '000000000000000000000000';
  } else if (req.user && req.user.role === 'contributor' && req.user.departmentId) {
    filter.departmentId = req.user.departmentId.toString();
  }

  const materials = await Material.find(filter).sort({ createdAt: -1 });
  res.json(success(materials, 'Materials fetched successfully.'));
};

// ─── GET /api/materials/my ─────────────────────────────────────────────
// Returns ALL materials uploaded by the authenticated user (any status)
const getMyMaterials = async (req, res) => {
  const materials = await Material.find({ uploadedBy: req.user._id })
    .sort({ createdAt: -1 });
  res.json(success(materials, 'Your materials fetched successfully.'));
};

// ─── GET /api/materials/:id ────────────────────────────────────────────
const getMaterialById = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (req.user && req.user.role === 'student') {
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
    if (studentDeptId && material.departmentId && material.departmentId.toString() !== studentDeptId) {
      throw createError('Access denied. You can only view materials from your own department.', 403);
    }
  }

  res.json(success(material));
};

// ─── POST /api/materials ───────────────────────────────────────────────
// Contributor uploads material. Automatically assigns the Faculty Admin
// for the material's department and sends them a notification.
//
// Request body fields (multipart/form-data or JSON):
//   title, description, type, courseId, departmentId
//   videoSource  — 'youtube' | 'cloudinary'  (only for type === 'video')
//   videoLink    — YouTube URL               (only for videoSource === 'youtube')
//   file         — the uploaded file          (for all non-youtube types)
const createMaterial = async (req, res) => {
  const { title, description, type, videoLink, videoSource, courseId, departmentId } = req.body;

  if (!title || !description || !type || !courseId || !departmentId) {
    throw createError('title, description, type, courseId, and departmentId are required.', 400);
  }

  if (!['notes', 'assignment', 'video', 'pdf'].includes(type)) {
    throw createError('type must be notes, assignment, video, or pdf.', 400);
  }

  let effectiveVideoSource = videoSource;

  // Validate based on type / videoSource combination
  if (type === 'video') {
    if (videoLink && typeof videoLink === 'string' && videoLink.trim().length > 0) {
      const trimmedUrl = videoLink.trim();
      try {
        const parsed = new URL(trimmedUrl);
        if (!['http:', 'https:'].includes(parsed.protocol)) {
          throw new Error('Invalid protocol');
        }
      } catch (_) {
        throw createError('Please enter a valid video URL (e.g. https://www.youtube.com/watch?v=... or https://youtu.be/...).', 400);
      }
      effectiveVideoSource = 'youtube';
    } else if (req.file) {
      effectiveVideoSource = 'cloudinary';
    } else {
      throw createError('A valid video URL or video file is required for video materials.', 400);
    }
  } else {
    // notes, assignment, pdf — all require a file
    if (!req.file) {
      throw createError('A file is required for notes, assignment, and pdf types.', 400);
    }
  }

  // Department access guard: contributors can only upload to their own department
  if (req.user.role === 'contributor' && req.user.departmentId) {
    if (req.user.departmentId.toString() !== departmentId.toString()) {
      throw createError('You can only upload materials for your own department.', 403);
    }
  }

  // Course validation: verify course exists, belongs to department, and is active
  const course = await Course.findById(courseId);
  if (!course) {
    throw createError('Selected course not found.', 404);
  }
  if (course.departmentId && course.departmentId.toString() !== departmentId.toString()) {
    throw createError('Selected course does not belong to the chosen department.', 400);
  }
  if (course.status !== 'active') {
    throw createError('Cannot upload materials to an inactive course.', 400);
  }

  // Resolve department name
  const departmentName = await resolveDeptName(departmentId);

  // Auto-assign Faculty Admin for this department
  const facultyAdmin = await findFacultyAdminForDept(departmentId);

  const materialData = {
    title: title.trim(),
    description: description.trim(),
    type,
    courseId,
    departmentId,
    department: departmentName,
    uploadedBy: req.user._id,
    contributorName: req.user.name,
    approvalStatus: 'pending',
    status: 'pending',
    assignedAdmin: facultyAdmin ? facultyAdmin._id : null,
    assignedAdminName: facultyAdmin ? facultyAdmin.name : null,
  };

  // ── Handle file upload to Cloudinary ─────────────────────────────────
  if (req.file) {
    if (type === 'video' && effectiveVideoSource === 'cloudinary') {
      // Upload as video resource type
      const { url, publicId } = await uploadVideoBuffer(req.file.buffer, 'edushare/videos', req.file.originalname);
      materialData.fileUrl = url;
      materialData.filePublicId = publicId;
      materialData.videoSource = 'cloudinary';
    } else {
      // Upload as image or raw document (PDF, DOC, images)
      const { url, publicId } = await uploadBuffer(req.file.buffer, 'edushare/materials', req.file.originalname);
      materialData.fileUrl = url;
      materialData.filePublicId = publicId;
    }

    // Store original filename and size for display
    materialData.fileName = req.file.originalname || null;
    materialData.fileSize = req.file.size || null;
  }

  // ── Handle YouTube / Video URL ────────────────────────────────────────
  if (type === 'video' && effectiveVideoSource === 'youtube') {
    const trimmedUrl = videoLink.trim();
    materialData.videoLink = trimmedUrl;
    materialData.fileUrl = trimmedUrl; // Set fileUrl for backward-compatible fallback
    materialData.videoSource = 'youtube';
  }

  const material = await Material.create(materialData);

  // ── Send notification to Faculty Admin (fire-and-forget) ──────────────
  notifyFacultyAdminOnUpload({ material, uploader: req.user });

  const msg = facultyAdmin
    ? `Material submitted for review. Assigned to ${facultyAdmin.name}.`
    : 'Material submitted. No Faculty Admin is currently assigned — a Super Admin will review it.';

  res.status(201).json(success(material, msg));
};

// ─── DELETE /api/materials/:id ─────────────────────────────────────────
const deleteMaterial = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (
    req.user.role === 'contributor' &&
    material.uploadedBy.toString() !== req.user._id.toString()
  ) {
    throw createError('You can only delete your own materials.', 403);
  }

  if (material.filePublicId) {
    // Determine the correct resource_type for Cloudinary deletion
    let resType = 'raw';
    if (material.type === 'video') resType = 'video';
    else if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].some(ext => (material.fileUrl || '').toLowerCase().endsWith(ext))) {
      resType = 'image';
    }
    await deleteFile(material.filePublicId, resType);
  }

  await material.deleteOne();
  res.json(success(null, 'Material deleted successfully.'));
};

// ─── GET /api/materials/:id/ratings ───────────────────────────────────
const getMaterialRatings = async (req, res) => {
  const { id } = req.params;
  const ratings = await MaterialRating.find({ materialId: id }).sort({ createdAt: -1 });

  let myRating = null;
  if (req.user) {
    myRating = ratings.find(r => r.userId.toString() === req.user._id.toString()) || null;
  }

  res.json(success({ ratings, myRating }, 'Ratings fetched successfully.'));
};

// ─── POST /api/materials/:id/ratings ──────────────────────────────────
const addMaterialRating = async (req, res) => {
  const { id } = req.params;
  const { stars, review } = req.body;

  if (!stars || stars < 1 || stars > 5) {
    throw createError('stars must be an integer between 1 and 5.', 400);
  }

  const material = await Material.findById(id);
  if (!material) throw createError('Material not found.', 404);
  if (material.approvalStatus !== 'approved' && material.status !== 'approved') {
    throw createError('You can only rate approved materials.', 400);
  }

  const existing = await MaterialRating.findOne({ materialId: id, userId: req.user._id });
  if (existing) {
    throw createError('You have already rated this material. Use PUT to update your review.', 409);
  }

  const rating = await MaterialRating.create({
    materialId: id,
    userId: req.user._id,
    ratedByName: req.user.name,
    contributorId: material.uploadedBy,
    stars: Math.round(stars),
    review: (review || '').trim(),
  });

  const { matAvg, matCount } = await recalcMaterialRating(id, material.uploadedBy);
  notifyContributorOnRatingSubmitted({ rating, material, reviewer: req.user });

  res.status(201).json(success({ rating, avgRating: matAvg, totalRatings: matCount }, 'Rating submitted successfully.'));
};

// ─── PUT /api/materials/:id/ratings ───────────────────────────────────
const updateMaterialRating = async (req, res) => {
  const { id } = req.params;
  const { stars, review } = req.body;

  if (!stars || stars < 1 || stars > 5) {
    throw createError('stars must be an integer between 1 and 5.', 400);
  }

  const rating = await MaterialRating.findOne({ materialId: id, userId: req.user._id });
  if (!rating) throw createError('Rating not found. Submit a review first.', 404);

  rating.stars = Math.round(stars);
  if (review !== undefined) rating.review = review.trim();
  await rating.save();

  const material = await Material.findById(id);
  const { matAvg, matCount } = await recalcMaterialRating(id, material ? material.uploadedBy : null);
  if (material) {
    notifyContributorOnRatingUpdated({ rating, material, reviewer: req.user });
  }

  res.json(success({ rating, avgRating: matAvg, totalRatings: matCount }, 'Rating updated successfully.'));
};

// ─── DELETE /api/materials/:id/ratings ────────────────────────────────
const deleteMaterialRating = async (req, res) => {
  const { id } = req.params;
  const rating = await MaterialRating.findOneAndDelete({ materialId: id, userId: req.user._id });
  if (!rating) throw createError('Rating not found.', 404);

  const material = await Material.findById(id);
  const { matAvg, matCount } = await recalcMaterialRating(id, material ? material.uploadedBy : null);

  res.json(success({ avgRating: matAvg, totalRatings: matCount }, 'Rating deleted successfully.'));
};

// ─── POST /api/materials/:id/view ─────────────────────────────────────
const incrementMaterialView = async (req, res) => {
  const { id } = req.params;
  const material = await Material.findByIdAndUpdate(
    id,
    { $inc: { views: 1 } },
    { new: true }
  );
  if (!material) throw createError('Material not found', 404);
  res.json(success({ views: material.views }, 'Material view recorded.'));
};

// ─── POST /api/materials/:id/download ─────────────────────────────────
const incrementMaterialDownload = async (req, res) => {
  const { id } = req.params;
  const material = await Material.findByIdAndUpdate(
    id,
    { $inc: { downloads: 1 } },
    { new: true }
  );
  if (!material) throw createError('Material not found', 404);
  res.json(success({ downloads: material.downloads }, 'Material download recorded.'));
};

// ─── POST /api/materials/:id/progress ──────────────────────────────────
// Save student's PDF reading progress
const saveMaterialProgress = async (req, res) => {
  const materialId = req.params.id;
  const userId = req.user._id;
  const { currentPage, totalPages, progressPercentage, courseId } = req.body;

  const curPage = Math.max(1, parseInt(currentPage) || 1);
  const totPages = Math.max(1, parseInt(totalPages) || 1);
  const progPct = progressPercentage !== undefined
    ? parseFloat(progressPercentage)
    : Math.min(100, parseFloat(((curPage / totPages) * 100).toFixed(1)));

  const progress = await PdfProgress.findOneAndUpdate(
    { userId, materialId },
    {
      userId,
      materialId,
      courseId: courseId || undefined,
      currentPage: curPage,
      totalPages: totPages,
      progressPercentage: progPct,
      lastReadAt: new Date(),
    },
    { upsert: true, new: true }
  );

  res.json(success(progress, 'Reading progress saved.'));
};

// ─── GET /api/materials/:id/progress ───────────────────────────────────
// Get student's saved PDF reading progress
const getMaterialProgress = async (req, res) => {
  const materialId = req.params.id;
  const userId = req.user._id;

  const progress = await PdfProgress.findOne({ userId, materialId });
  res.json(success(progress || { currentPage: 1, totalPages: 1, progressPercentage: 0 }));
};

// ─── GET /api/materials/:id/file ───────────────────────────────────────
// Secure in-app delivery endpoint for material documents, images, and videos.
// Fetches from Cloudinary using server-side credentials and pipes binary data directly to the client.
const streamMaterialFile = async (req, res) => {
  const material = await Material.findById(req.params.id);
  if (!material) throw createError('Material not found.', 404);

  if (req.user && req.user.role === 'student') {
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
    if (studentDeptId && material.departmentId && material.departmentId.toString() !== studentDeptId) {
      throw createError('Access denied. You can only view materials from your own department.', 403);
    }
  }

  const targetUrl = material.fileUrl || material.videoLink;
  if (!targetUrl) {
    throw createError('No file attached to this material.', 404);
  }

  // Increment view counter asynchronously
  Material.findByIdAndUpdate(material._id, { $inc: { views: 1 } }).catch(() => {});

  // Determine Content-Type & extension
  const ext = (material.fileName ? path.extname(material.fileName) : path.extname(targetUrl)).toLowerCase();
  let contentType = 'application/octet-stream';
  if (ext === '.pdf' || material.type === 'pdf' || material.type === 'notes') {
    contentType = 'application/pdf';
  } else if (ext === '.png') {
    contentType = 'image/png';
  } else if (['.jpg', '.jpeg'].includes(ext)) {
    contentType = 'image/jpeg';
  } else if (ext === '.webp') {
    contentType = 'image/webp';
  } else if (ext === '.mp4') {
    contentType = 'video/mp4';
  }

  const safeFilename = encodeURIComponent(material.fileName || material.title || 'material');

  // Candidate URLs to try
  const candidateUrls = [];

  // 1. If publicId exists, generate signed URLs via Cloudinary SDK
  if (material.filePublicId) {
    const isImage = material.type === 'image' || ['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext);
    const isPdf = ext === '.pdf' || material.type === 'pdf' || material.type === 'notes';

    if (isPdf) {
      // Try raw signed URL
      try {
        candidateUrls.push(cloudinary.url(material.filePublicId, {
          resource_type: 'raw',
          sign_url: true,
          secure: true,
          type: 'upload',
        }));
      } catch (_) {}
      // Try image signed URL
      try {
        candidateUrls.push(cloudinary.url(material.filePublicId, {
          resource_type: 'image',
          sign_url: true,
          secure: true,
          type: 'upload',
        }));
      } catch (_) {}
    } else if (isImage) {
      try {
        candidateUrls.push(cloudinary.url(material.filePublicId, {
          resource_type: 'image',
          sign_url: true,
          secure: true,
          type: 'upload',
        }));
      } catch (_) {}
    }
  }

  // 2. Add original targetUrl and URL variations
  candidateUrls.push(targetUrl);
  if (targetUrl.includes('/image/upload/') && targetUrl.includes('.pdf')) {
    candidateUrls.push(targetUrl.replace('/image/upload/', '/raw/upload/'));
  } else if (targetUrl.includes('/raw/upload/') && targetUrl.includes('.pdf')) {
    candidateUrls.push(targetUrl.replace('/raw/upload/', '/image/upload/'));
  }

  const uniqueUrls = [...new Set(candidateUrls.filter(Boolean))];

  // Helper to stream a URL with redirect and basic auth fallback
  const fetchAndPipe = (urlToFetch) => {
    return new Promise((resolve, reject) => {
      const parsed = new URL(urlToFetch);
      const client = parsed.protocol === 'https:' ? https : http;

      // Add auth header if hitting Cloudinary
      const headers = {};
      if (parsed.hostname.includes('cloudinary.com') && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET) {
        const auth = Buffer.from(`${process.env.CLOUDINARY_API_KEY}:${process.env.CLOUDINARY_API_SECRET}`).toString('base64');
        headers['Authorization'] = `Basic ${auth}`;
      }

      const reqStream = client.get(urlToFetch, { headers }, (remoteRes) => {
        // Follow redirects
        if ([301, 302, 307, 308].includes(remoteRes.statusCode) && remoteRes.headers.location) {
          return fetchAndPipe(remoteRes.headers.location).then(resolve).catch(reject);
        }

        if (remoteRes.statusCode === 200) {
          res.setHeader('Content-Type', remoteRes.headers['content-type'] || contentType);
          if (remoteRes.headers['content-length']) {
            res.setHeader('Content-Length', remoteRes.headers['content-length']);
          }
          res.setHeader('Content-Disposition', `inline; filename="${safeFilename}"`);
          res.setHeader('Cache-Control', 'public, max-age=86400');
          remoteRes.pipe(res);
          return resolve(true);
        }

        remoteRes.resume();
        reject(new Error(`Status ${remoteRes.statusCode}`));
      });

      reqStream.on('error', reject);
      reqStream.setTimeout(25000, () => {
        reqStream.destroy();
        reject(new Error('Fetch timeout'));
      });
    });
  };

  for (const url of uniqueUrls) {
    try {
      const ok = await fetchAndPipe(url);
      if (ok) return;
    } catch (_) {}
  }

  // Fallback redirect if streaming failed
  return res.redirect(targetUrl);
};

module.exports = {
  getMaterials,
  getMyMaterials,
  getMaterialById,
  createMaterial,
  deleteMaterial,
  getMaterialRatings,
  addMaterialRating,
  updateMaterialRating,
  deleteMaterialRating,
  incrementMaterialView,
  incrementMaterialDownload,
  saveMaterialProgress,
  getMaterialProgress,
  streamMaterialFile,
};
