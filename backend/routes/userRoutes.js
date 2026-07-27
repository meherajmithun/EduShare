const express = require('express');
const router = express.Router();
const { getUsers, getUserById, updateUserRole, deleteUser } = require('../controllers/userController');
const { protect } = require('../middleware/auth');
const roleGuard = require('../middleware/roleGuard');

router.use(protect, roleGuard('admin'));

router.get('/', getUsers);           // ?role=student|contributor|admin
router.get('/:id', getUserById);
router.put('/:id/role', updateUserRole);
router.delete('/:id', deleteUser);

module.exports = router;
