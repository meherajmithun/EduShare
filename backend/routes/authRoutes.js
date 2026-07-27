const express = require('express');
const router = express.Router();
const { register, registerFacultyAdmin, login, getProfile } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

router.post('/register', register);
router.post('/register-faculty-admin', registerFacultyAdmin);
router.post('/login', login);
router.get('/profile', protect, getProfile);

module.exports = router;
