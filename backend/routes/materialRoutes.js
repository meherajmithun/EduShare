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
} = require('../controllers/materialController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');
const { uploadDoc, uploadVideo } = require('../services/cloudinaryService');

// ─── Smart multer middleware ───────────────────────────────────────────
// We cannot inspect req.body before multer runs on multipart/form-data.
// Strategy: use uploadVideo for the upload route since it accepts both
// video files AND documents (the file filter allows octet-stream which
// covers all cases). The controller then applies the correct Cloudinary
// resource_type based on type + videoSource fields.
//
// For YouTube videos, no file is uploaded at all — multer still runs but
// req.file will be undefined (which is fine).
const uploadMiddleware = uploadVideo.single('file');

// IMPORTANT: /my must come before /:id to avoid route conflict
router.get(
  '/my',
  protect,
  roleGuard('contributor', 'admin', 'faculty_admin', 'super_admin'),
  getMyMaterials
);
router.get('/', protect, getMaterials);          // ?courseId=&type=
router.get('/:id', protect, getMaterialById);

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
