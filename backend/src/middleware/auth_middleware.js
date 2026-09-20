const { getApps, initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const fs = require('fs');
const path = require('path');
const env = require('../config/env');
const { errorResponse } = require('../utils/response');

let isFirebaseInitialized = false;

// Safe Firebase Admin initialization
try {
  const existingApps = getApps();
  if (existingApps.length === 0) {
    if (env.FIREBASE_SERVICE_ACCOUNT_PATH && fs.existsSync(env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
      const resolvedPath = path.resolve(env.FIREBASE_SERVICE_ACCOUNT_PATH);
      const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
      initializeApp({
        credential: cert(serviceAccount),
        projectId: env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
      });
      isFirebaseInitialized = true;
      console.log('[Auth] Firebase Admin SDK initialized with service account.');
    } else if (env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY) {
      initializeApp({
        credential: cert({
          projectId: env.FIREBASE_PROJECT_ID,
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey: env.FIREBASE_PRIVATE_KEY,
        }),
        projectId: env.FIREBASE_PROJECT_ID,
      });
      isFirebaseInitialized = true;
      console.log(`[Auth] Firebase Admin SDK initialized via environment credentials for: ${env.FIREBASE_PROJECT_ID}`);
    } else if (env.FIREBASE_PROJECT_ID) {
      initializeApp({
        projectId: env.FIREBASE_PROJECT_ID,
      });
      isFirebaseInitialized = true;
      console.log(`[Auth] Firebase Admin SDK initialized for project: ${env.FIREBASE_PROJECT_ID}`);
    }
  } else {
    isFirebaseInitialized = true;
  }
} catch (error) {
  console.warn('[Auth Warning] Firebase Admin initialization notice:', error.message);
}

/**
 * Firebase Authentication Middleware
 * Rejects requests with missing, malformed, or invalid Firebase ID tokens.
 */
async function authenticateFirebaseUser(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
    return errorResponse(res, 'Authentication required.', 401);
  }

  const idToken = authHeader.substring(7).trim();
  if (!idToken) {
    return errorResponse(res, 'Authentication required.', 401);
  }

  // Allow explicit test tokens strictly in automated test environment (NODE_ENV === 'test')
  if (env.NODE_ENV === 'test' && idToken.startsWith('test_valid_firebase_token')) {
    req.user = {
      uid: 'test_firebase_user_123',
      email: 'test@connectcall.io',
      isTestToken: true,
    };
    return next();
  }

  if (isFirebaseInitialized) {
    try {
      console.log('[AGORA TOKEN] authentication START');
      const decodedToken = await getAuth().verifyIdToken(idToken);
      console.log(`[AGORA TOKEN] authentication END uid=${decodedToken.uid}`);
      req.user = decodedToken;
      console.log(`[Identity E] Agora token request authenticated Firebase UID: ${decodedToken.uid}`);
      return next();
    } catch (err) {
      console.warn(`[AGORA TOKEN] authentication FAILED: ${err.code || err.message}`);
      console.warn(`[Auth Warning] Firebase token verification failed: ${err.code || err.message}`);
      const clientMessage = err.code === 'auth/id-token-expired'
        ? 'Your session has expired. Please sign in again.'
        : 'Authentication required.';
      return errorResponse(res, clientMessage, 401);
    }
  }

  return errorResponse(res, 'Authentication service uninitialized.', 500);
}

module.exports = {
  authenticateFirebaseUser,
};
