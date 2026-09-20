const { successResponse } = require('../utils/response');

/**
 * Health check controller
 */
function getHealth(req, res) {
  return successResponse(
    res,
    {
      service: 'ConnectCall Backend',
      status: 'healthy',
    },
    200
  );
}

module.exports = {
  getHealth,
};
