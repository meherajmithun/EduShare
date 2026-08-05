const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  incrementViewCount,
  saveProgress,
  getCourseProgress,
  getContinueWatching,
  getHistory,
  getBookmarks,
  addBookmark,
  removeBookmark,
  getComments,
  addComment,
} = require('../controllers/videoController');

router.use(protect);

router.post('/progress', saveProgress);
router.get('/progress/:courseId', getCourseProgress);
router.get('/continue-watching', getContinueWatching);
router.get('/history', getHistory);

router.get('/bookmarks', getBookmarks);
router.post('/bookmark/:materialId', addBookmark);
router.delete('/bookmark/:materialId', removeBookmark);

router.get('/:materialId/comments', getComments);
router.post('/:materialId/comments', addComment);

router.post('/:id/view', incrementViewCount);

module.exports = router;
