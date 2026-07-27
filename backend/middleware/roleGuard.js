/**
 * middleware/roleGuard.js — Role-based access control middleware
 *
 * Usage:
 *   router.post('/', protect, roleGuard('contributor', 'admin'), handler)
 *   router.get('/dept', protect, roleGuard('faculty_admin'), departmentGuard, handler)
 *
 * Must be used AFTER the `protect` middleware (requires req.user to be set).
 */

const { createError } = require('../utils/apiResponse');

/**
 * Returns a middleware that allows only the specified roles.
 * @param  {...string} roles - Allowed roles
 */
const roleGuard = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      throw createError('Not authenticated.', 401);
    }

    if (!roles.includes(req.user.role)) {
      throw createError(
        `Access denied. This action requires one of the following roles: ${roles.join(', ')}.`,
        403
      );
    }

    next();
  };
};

/**
 * Ensures a Faculty Admin can only access resources matching their own department.
 * For other roles (admin, super_admin), this middleware is a no-op pass-through.
 *
 * Must be used AFTER protect + roleGuard.
 * Injects `req.departmentFilter` for controllers to use in DB queries.
 */
const departmentGuard = (req, res, next) => {
  if (req.user.role === 'faculty_admin') {
    if (!req.user.department) {
      throw createError('Faculty Admin has no department assigned.', 403);
    }
    req.departmentFilter = { department: req.user.department };
  } else {
    req.departmentFilter = {}; // Super Admin / admin sees all
  }
  next();
};

module.exports = roleGuard;
module.exports.departmentGuard = departmentGuard;
