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
  const allowed = new Set(roles);
  if (allowed.has('admin') || allowed.has('faculty_admin')) {
    allowed.add('admin');
    allowed.add('faculty_admin');
  }

  return (req, res, next) => {
    if (!req.user) {
      throw createError('Not authenticated.', 401);
    }

    if (!allowed.has(req.user.role)) {
      throw createError(
        `Access denied. This action requires one of the following roles: ${Array.from(allowed).join(', ')}.`,
        403
      );
    }

    next();
  };
};

/**
 * Ensures a Faculty Admin / Admin can only access resources matching their own department.
 * For super_admin, this middleware is a pass-through.
 *
 * Must be used AFTER protect + roleGuard.
 * Injects `req.departmentFilter` for controllers to use in DB queries.
 */
const departmentGuard = (req, res, next) => {
  if (req.user.role === 'faculty_admin' || req.user.role === 'admin') {
    if (!req.user.department && !req.user.departmentId) {
      throw createError('Your account has no department assigned. Contact a Super Admin.', 403);
    }
    req.departmentFilter = req.user.departmentId
      ? { departmentId: req.user.departmentId }
      : { department: req.user.department };
  } else {
    req.departmentFilter = {}; // Super Admin sees all
  }
  next();
};

module.exports = roleGuard;
module.exports.departmentGuard = departmentGuard;
