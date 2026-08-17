const express = require('express');
const router = express.Router();
const {
  getFolders,
  createFolder,
  renameFolder,
  deleteFolder,
  getFolderMaterials,
  saveMaterialToFolder,
  removeMaterialFromFolder,
} = require('../controllers/folderController');
const { protect } = require('../middleware/auth');

// All folder routes require student/user authentication
router.use(protect);

router.get('/', getFolders);
router.post('/', createFolder);
router.put('/:id', renameFolder);
router.delete('/:id', deleteFolder);

router.get('/:id/materials', getFolderMaterials);
router.post('/:id/materials/:materialId', saveMaterialToFolder);
router.delete('/:id/materials/:materialId', removeMaterialFromFolder);

module.exports = router;
