const express = require('express');
const router = express.Router();
const {
  getPendingMaterials,
  approveMaterial,
  rejectMaterial,
  getStats,
  getAllMaterials,
} = require('../controllers/adminController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

// All admin routes require JWT + admin role
router.use(protect, roleGuard('admin'));

router.get('/pending', getPendingMaterials);
router.get('/stats', getStats);
router.get('/materials', getAllMaterials);           // ?status=pending|approved|rejected
router.put('/approve/:id', approveMaterial);
router.put('/reject/:id', rejectMaterial);

module.exports = router;
