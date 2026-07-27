const express = require('express');
const router = express.Router();
const {
  getMaterials,
  getMyMaterials,
  getMaterialById,
  createMaterial,
  deleteMaterial,
} = require('../controllers/materialController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');
const { upload } = require('../services/cloudinaryService');

// IMPORTANT: /my must come before /:id to avoid route conflict
router.get('/my', protect, roleGuard('contributor', 'admin'), getMyMaterials);
router.get('/', protect, getMaterials);          // ?courseId=&type=
router.get('/:id', protect, getMaterialById);

// upload.single('file') runs multer → streams file to Cloudinary before controller
router.post(
  '/',
  protect,
  roleGuard('contributor', 'admin'),
  upload.single('file'),
  createMaterial
);

router.delete('/:id', protect, roleGuard('contributor', 'admin'), deleteMaterial);

module.exports = router;
