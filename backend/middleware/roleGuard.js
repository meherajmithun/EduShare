/**
 * middleware/roleGuard.js — Role-based access control middleware
 *
 * Usage:
 *   router.post('/', protect, roleGuard('contributor', 'admin'), handler)
 *
 * Must be used AFTER the `protect` middleware (requires req.user to be set).
 */

const { createError } = require('../utils/apiResponse');

/**
 * Returns a middleware that allows only the specified roles.
 * @param  {...string} roles - Allowed roles (e.g. 'admin', 'contributor')
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

module.exports = roleGuard;
