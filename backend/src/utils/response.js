/**
 * Formatted JSON response helpers to ensure consistent API response shapes.
 */

function successResponse(res, data = {}, status = 200) {
  return res.status(status).json({
    success: true,
    ...data,
  });
}

function errorResponse(res, message = 'Something went wrong.', status = 500, errors = null) {
  const payload = {
    success: false,
    message,
  };
  if (errors) {
    payload.errors = errors;
  }
  return res.status(status).json(payload);
}

module.exports = {
  successResponse,
  errorResponse,
};
