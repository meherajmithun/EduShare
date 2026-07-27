/**
 * utils/apiResponse.js — Standardised JSON response helpers
 *
 * Every API response follows the same envelope:
 *   { success: true/false, data?: any, message?: string, pagination?: object }
 *
 * Usage:
 *   res.status(200).json(success(data, 'Fetched successfully'));
 *   res.status(400).json(fail('Validation error'));
 */

/**
 * Build a successful response envelope.
 * @param {*} data - The response payload
 * @param {string} [message='Success'] - Human-readable message
 * @param {object} [pagination] - Optional pagination metadata
 */
const success = (data, message = 'Success', pagination) => ({
  success: true,
  message,
  data,
  ...(pagination && { pagination }),
});

/**
 * Build an error response envelope.
 * @param {string} [message='An error occurred'] - Human-readable error
 * @param {object} [errors] - Optional field-level validation errors
 */
const fail = (message = 'An error occurred', errors) => ({
  success: false,
  message,
  ...(errors && { errors }),
});

/**
 * Create an Error with a custom HTTP status code attached.
 * Use inside async route handlers — express-async-errors forwards it
 * to the global error handler automatically.
 *
 * @param {string} message - Error message
 * @param {number} statusCode - HTTP status (e.g. 400, 401, 403, 404)
 */
const createError = (message, statusCode) => {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
};

module.exports = { success, fail, createError };
