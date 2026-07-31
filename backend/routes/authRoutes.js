const express = require('express');
const router = express.Router();
const {
  register,
  registerFacultyAdmin,
  login,
  getProfile,
  updateProfile,
  uploadProfilePhoto,
} = require('../controllers/authController');
const { protect } = require('../middleware/auth');
const { upload } = require('../services/cloudinaryService');

router.post('/register', register);
router.post('/register-faculty-admin', registerFacultyAdmin);
router.post('/login', login);
router.get('/profile', protect, getProfile);
router.put('/profile', protect, updateProfile);
router.post('/profile/photo', protect, upload.single('photo'), uploadProfilePhoto);

module.exports = router;
