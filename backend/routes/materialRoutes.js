const express = require('express');
const router = express.Router();
const {
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
} = require('../controllers/materialController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');
const { uploadMaterialFile } = require('../services/cloudinaryService');

// ─── Universal upload middleware ─────────────────────────────────────────
// Accepts documents, PDFs, images, and videos.
const uploadMiddleware = uploadMaterialFile.single('file');

// IMPORTANT: /my must come before /:id to avoid route conflict
router.get(
  '/my',
  protect,
  roleGuard('contributor', 'admin', 'faculty_admin', 'super_admin'),
  getMyMaterials
);
router.get('/', protect, getMaterials);          // ?courseId=&type=
router.get('/:id', protect, getMaterialById);
router.get('/:id/file', protect, streamMaterialFile);

// ─── Reading & Material Progress ────────────────────────────────────────
router.post('/:id/progress', protect, saveMaterialProgress);
router.get('/:id/progress', protect, getMaterialProgress);

// ─── View & Download counters ────────────────────────────────────────────
router.post('/:id/view', protect, incrementMaterialView);
router.post('/:id/download', protect, incrementMaterialDownload);

// uploadMiddleware streams file to memory; controller decides Cloudinary resource_type
router.post(
  '/',
  protect,
  roleGuard('contributor', 'admin', 'faculty_admin', 'super_admin'),
  uploadMiddleware,
  createMaterial
);

router.delete(
  '/:id',
  protect,
  roleGuard('contributor', 'admin', 'faculty_admin', 'super_admin'),
  deleteMaterial
);

// Material ratings (students submit; all authenticated users can read)
router.get('/:id/ratings', protect, getMaterialRatings);
router.post('/:id/ratings', protect, roleGuard('student'), addMaterialRating);
router.put('/:id/ratings', protect, roleGuard('student'), updateMaterialRating);
router.delete('/:id/ratings', protect, roleGuard('student'), deleteMaterialRating);

module.exports = router;
