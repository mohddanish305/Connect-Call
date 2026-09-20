const dotenv = require('dotenv');
const path = require('path');

// Load environment variables from backend/.env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

/**
 * Validates and exports centralized environment configuration.
 */
function loadAndValidateEnv() {
  const nodeEnv = process.env.NODE_ENV || 'development';
  const rawPort = process.env.PORT || '3000';
  const port = parseInt(rawPort, 10);

  if (isNaN(port) || port <= 0 || port > 65535) {
    console.error(`[Config Error] Invalid PORT specified: "${rawPort}". Must be a valid port number between 1 and 65535.`);
    process.exit(1);
  }

  const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
    : ['*'];

  const agoraAppId = process.env.AGORA_APP_ID ? process.env.AGORA_APP_ID.trim() : '';
  const agoraAppCertificate = process.env.AGORA_APP_CERTIFICATE ? process.env.AGORA_APP_CERTIFICATE.trim() : '';
  const tokenExpiry = parseInt(process.env.AGORA_TOKEN_EXPIRY_SECONDS || '3600', 10);

  const isAgoraAppIdConfigured = Boolean(
    agoraAppId &&
    !agoraAppId.includes('<') &&
    agoraAppId !== 'your_agora_app_id' &&
    agoraAppId.length === 32
  );

  const isAgoraCertificateConfigured = Boolean(
    agoraAppCertificate &&
    !agoraAppCertificate.includes('<') &&
    agoraAppCertificate !== 'your_agora_app_certificate' &&
    /^[a-fA-F0-9]{32}$/.test(agoraAppCertificate)
  );

  const isAgoraConfigured = isAgoraAppIdConfigured && isAgoraCertificateConfigured;

  return Object.freeze({
    PORT: port,
    NODE_ENV: nodeEnv,
    IS_PRODUCTION: nodeEnv === 'production',
    IS_DEVELOPMENT: nodeEnv === 'development',
    ALLOWED_ORIGINS: allowedOrigins,
    AGORA_APP_ID: agoraAppId,
    AGORA_APP_CERTIFICATE: agoraAppCertificate,
    AGORA_TOKEN_EXPIRY_SECONDS: isNaN(tokenExpiry) ? 3600 : tokenExpiry,
    isAgoraAppIdConfigured,
    isAgoraCertificateConfigured,
    isAgoraConfigured,
    FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || 'connectcall-01',
    FIREBASE_SERVICE_ACCOUNT_PATH: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '',
    FIREBASE_CLIENT_EMAIL: process.env.FIREBASE_CLIENT_EMAIL || '',
    FIREBASE_PRIVATE_KEY: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : '',
  });
}

const env = loadAndValidateEnv();

module.exports = env;
