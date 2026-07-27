/**
 * middleware/auth.js — JWT verification middleware
 *
 * Attaches the decoded user payload to req.user on success.
 * Throws 401 on missing, expired, or invalid token.
 */

const jwt = require('jsonwebtoken');
const { createError } = require('../utils/apiResponse');
const User = require('../models/User');

const protect = async (req, res, next) => {
  let token;

  // Extract Bearer token from Authorization header
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    throw createError('No authentication token provided. Please log in.', 401);
  }

  try {
    // Verify and decode the token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Fetch the user fresh from DB to catch role changes or account deletions
    const user = await User.findById(decoded.id).select('-password');

    if (!user) {
      throw createError('User no longer exists. Please log in again.', 401);
    }

    if (!user.isActive) {
      throw createError('Your account has been deactivated. Contact support.', 401);
    }

    req.user = user; // Available to all subsequent handlers
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError') {
      throw createError('Invalid token. Please log in again.', 401);
    }
    if (err.name === 'TokenExpiredError') {
      throw createError('Token expired. Please log in again.', 401);
    }
    throw err; // Re-throw our own createError instances
  }
};

/**
 * Sign a new JWT for the given user _id.
 * @param {string} id - MongoDB ObjectId as string
 */
const signToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
};

module.exports = { protect, signToken };
