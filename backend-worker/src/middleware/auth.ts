import { createMiddleware } from 'hono/factory';
import { verifyFirebaseIdToken } from '../services/firebase';
import type { Env, Variables } from '../types';

/**
 * Authentication middleware for Cloudflare Worker.
 * Enforces valid Firebase ID token in `Authorization: Bearer <token>`.
 */
export const authMiddleware = createMiddleware<{ Bindings: Env; Variables: Variables }>(
  async (c, next) => {
    const authHeader = c.req.header('authorization') || c.req.header('Authorization');

    if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
      return c.json({ success: false, message: 'Authentication required.' }, 401);
    }

    const idToken = authHeader.substring(7).trim();
    if (!idToken) {
      return c.json({ success: false, message: 'Authentication required.' }, 401);
    }

    const projectId = c.env.FIREBASE_PROJECT_ID || 'connectcall-01';
    const isTestEnv = c.env.ENVIRONMENT === 'test' || (typeof process !== 'undefined' && process.env.NODE_ENV === 'test');

    try {
      const user = await verifyFirebaseIdToken(idToken, projectId, isTestEnv);
      c.set('user', user);
      await next();
    } catch (err: unknown) {
      const error = err as { message?: string };
      return c.json(
        {
          success: false,
          message: error.message || 'Authentication required.',
        },
        401
      );
    }
  }
);
