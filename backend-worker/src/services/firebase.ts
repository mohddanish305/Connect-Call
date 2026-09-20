import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { VerifiedUser } from '../types';

let jwksCache: ReturnType<typeof createRemoteJWKSet> | null = null;

function getGoogleJWKS() {
  if (!jwksCache) {
    jwksCache = createRemoteJWKSet(
      new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
      { cacheMaxAge: 3600000 }
    );
  }
  return jwksCache;
}

/**
 * Verifies Firebase ID Token using Google's public JWKS.
 * 100% Web Crypto standard compliant; runs natively in Cloudflare Workers V8 isolates.
 */
export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
  allowTestTokens: boolean = false
): Promise<VerifiedUser> {
  if (!token || typeof token !== 'string') {
    throw new Error('Authentication required.');
  }

  const trimmedToken = token.trim();

  // Allow explicit test tokens strictly when test mode is enabled
  if (allowTestTokens && trimmedToken.startsWith('test_valid_firebase_token')) {
    return {
      uid: 'test_firebase_user_123',
      email: 'test@connectcall.io',
      name: 'Test User',
      isTestToken: true,
    };
  }

  try {
    const JWKS = getGoogleJWKS();
    const { payload } = await jwtVerify(trimmedToken, JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
      algorithms: ['RS256'],
    });

    const uid = (payload.user_id || payload.sub) as string;
    if (!uid) {
      throw new Error('Invalid token payload: missing user identifier.');
    }

    return {
      uid,
      email: payload.email as string | undefined,
      name: payload.name as string | undefined,
      ...payload,
    };
  } catch (err: unknown) {
    const error = err as { code?: string; message?: string };
    if (error.code === 'ERR_JWT_EXPIRED') {
      throw new Error('Your session has expired. Please sign in again.');
    }
    throw new Error('Authentication required.');
  }
}
