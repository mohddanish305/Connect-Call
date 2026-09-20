import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';
import { generateAgoraToken } from '../services/agora';
import type { Env, Variables } from '../types';

export const agoraRoutes = new Hono<{ Bindings: Env; Variables: Variables }>();

/**
 * POST /api/agora/token
 * Protected endpoint generating short-lived Agora RTC tokens.
 */
agoraRoutes.post('/token', authMiddleware, async (c) => {
  let body: Record<string, unknown> = {};
  try {
    body = await c.req.json();
  } catch {
    return c.json({ success: false, message: 'Invalid JSON body.' }, 400);
  }

  const { channelName, uid } = body;

  if (!channelName) {
    return c.json({ success: false, message: 'channelName is required.' }, 400);
  }

  if (uid === undefined || uid === null || uid === '') {
    return c.json({ success: false, message: 'uid is required.' }, 400);
  }

  const appId = c.env.AGORA_APP_ID;
  const appCertificate = c.env.AGORA_APP_CERTIFICATE;
  const expirySeconds = parseInt(c.env.AGORA_TOKEN_EXPIRY_SECONDS || '3600', 10);

  try {
    const tokenData = generateAgoraToken(channelName, uid, appId, appCertificate, expirySeconds);

    // Provide both root and data properties for 100% compatibility with AgoraTokenResponse.fromJson
    return c.json({
      success: true,
      appId: tokenData.appId,
      channelName: tokenData.channelName,
      uid: tokenData.uid,
      token: tokenData.token,
      expiresAt: tokenData.expiresAt,
      data: {
        token: tokenData.token,
        appId: tokenData.appId,
        channelName: tokenData.channelName,
        uid: tokenData.uid,
        expiresAt: tokenData.expiresAt,
      },
    });
  } catch (err: unknown) {
    const error = err as { message?: string };
    const errorMsg = error.message || '';

    // Parameter validation errors return 400
    if (errorMsg.includes('channelName') || errorMsg.includes('uid')) {
      return c.json({ success: false, message: errorMsg }, 400);
    }

    // Configuration errors return 500 without leaking secrets
    if (errorMsg.includes('AGORA_APP_ID') || errorMsg.includes('AGORA_APP_CERTIFICATE')) {
      console.error('[Agora Worker Error] Configuration missing:', errorMsg);
      return c.json({ success: false, message: 'Agora credentials are not configured.' }, 500);
    }

    console.error('[Agora Worker Error] Token generation failed:', errorMsg);
    return c.json({ success: false, message: 'Unable to generate Agora token.' }, 500);
  }
});
