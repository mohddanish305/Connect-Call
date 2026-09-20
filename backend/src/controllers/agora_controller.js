const agoraTokenService = require('../services/agora_token_service');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * Controller handling Agora RTC token requests.
 * Orchestrates validation, service invocation, and structured HTTP responses.
 */
class AgoraController {
  /**
   * POST /api/agora/token
   * Generates a temporary Agora RTC token for authenticated Firebase users.
   */
  async generateToken(req, res) {
    try {
      const { channelName, uid } = req.body || {};

      // 1. Initial presence checks
      if (!channelName) {
        return errorResponse(res, 'channelName is required.', 400);
      }
      if (uid === undefined || uid === null || uid === '') {
        return errorResponse(res, 'uid is required.', 400);
      }

      // 2. Delegate validation and generation to AgoraTokenService
      console.log('[AGORA TOKEN] request validated');
      let tokenData;
      try {
        console.log('[AGORA TOKEN] token generation START');
        tokenData = agoraTokenService.generateRtcToken(channelName, uid);
        console.log('[AGORA TOKEN] token generation END');
      } catch (serviceError) {
        const errorMsg = serviceError.message || '';

        // Validation errors return HTTP 400
        if (
          errorMsg.includes('channelName') ||
          errorMsg.includes('uid')
        ) {
          return errorResponse(res, errorMsg, 400);
        }

        // Configuration errors return HTTP 500 with generic safe message
        if (errorMsg.includes('Agora credentials')) {
          console.error('[Agora Controller] Token generation error: Agora credentials are not configured.');
          return errorResponse(res, 'Agora credentials are not configured.', 500);
        }

        // Unexpected generation errors return HTTP 500
        console.error('[Agora Controller] Token generation error:', errorMsg);
        return errorResponse(res, 'Unable to generate Agora token.', 500);
      }

      // 3. Return sanitized response (never include App Certificate or log token string)
      console.log(`[AGORA TOKEN]\nchannel=${tokenData.channelName}\nuid=${tokenData.uid}\ntokenGenerated=true\ntokenLength=${tokenData.token.length}\nexpiresAt=${tokenData.expiresAt}`);
      console.log('[AGORA TOKEN] response SENT');
      return successResponse(res, {
        data: {
          token: tokenData.token,
          appId: tokenData.appId,
          channelName: tokenData.channelName,
          uid: tokenData.uid,
          expiresAt: tokenData.expiresAt,
        },
      }, 200);
    } catch (err) {
      console.error('[Agora Controller] Unexpected error:', err.message);
      return errorResponse(res, 'Unable to generate Agora token.', 500);
    }
  }
}

module.exports = new AgoraController();
