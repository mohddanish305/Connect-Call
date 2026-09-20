const { errorResponse } = require('../utils/response');

/**
 * Centralized Global Error Handler Middleware
 */
function errorHandler(err, req, res, next) {
  // Log internal error safely on server console during development
  console.error('[Unhandled Error]', err.name || 'Error', ':', err.message || err);

  const statusCode = err.statusCode || (err.status && typeof err.status === 'number' ? err.status : 500);
  const userMessage = statusCode === 400 || statusCode === 401 || statusCode === 403 || statusCode === 404
    ? err.message
    : 'Something went wrong.';

  return errorResponse(res, userMessage, statusCode);
}

module.exports = errorHandler;
