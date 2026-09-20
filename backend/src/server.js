const express = require('express');
const helmet = require('helmet');
const env = require('./config/env');
const corsMiddleware = require('./middleware/cors_middleware');
const requestLogger = require('./middleware/logger_middleware');
const notFoundHandler = require('./middleware/not_found_handler');
const errorHandler = require('./middleware/error_handler');
const routes = require('./routes');

const app = express();

// 1. Security headers
app.use(helmet());

// 2. Centralized CORS
app.use(corsMiddleware);

// 3. Request body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 4. Request logging (safe, no secrets logged)
if (env.IS_DEVELOPMENT) {
  app.use(requestLogger);
}

// 5. Mount application routes
app.use('/', routes);

// 6. 404 Route Not Found Handler
app.use(notFoundHandler);

// 7. Global Centralized Error Handler
app.use(errorHandler);

// Start server
const server = app.listen(env.PORT, '0.0.0.0', () => {
  console.log(`=========================================`);
  console.log(` ConnectCall Backend Foundation Running`);
  console.log(` Environment:                ${env.NODE_ENV}`);
  console.log(` Port:                       ${env.PORT}`);
  console.log(` Health:                     http://localhost:${env.PORT}/health`);
  console.log(` AGORA_APP_ID configured:          ${env.isAgoraAppIdConfigured}`);
  console.log(` AGORA_APP_CERTIFICATE configured: ${env.isAgoraCertificateConfigured}`);
  console.log(` AGORA_TOKEN_EXPIRY_SECONDS:       ${env.AGORA_TOKEN_EXPIRY_SECONDS}`);
  console.log(`=========================================`);

  if (!env.isAgoraAppIdConfigured || !env.isAgoraCertificateConfigured) {
    console.error('\n[FATAL STARTUP ERROR] Agora credentials validation failed:');
    if (!env.isAgoraAppIdConfigured) {
      console.error(' - AGORA_APP_ID is missing or invalid. Must be a 32-character hexadecimal App ID.');
    }
    if (!env.isAgoraCertificateConfigured) {
      console.error(' - AGORA_APP_CERTIFICATE is missing or invalid. Please configure your 32-character Primary Certificate directly in backend/.env.');
    }
    console.error('Backend startup aborted to prevent runtime call failures.\n');
    if (process.env.NODE_ENV !== 'test') {
      process.exit(1);
    }
  }
});

// Graceful shutdown handling
function handleShutdown(signal) {
  console.log(`\n[Server] Received ${signal}. Shutting down gracefully...`);
  server.close(() => {
    console.log('[Server] HTTP server closed.');
    process.exit(0);
  });
}

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
  console.warn('[Server Warning] Unhandled Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('[Server Error] Uncaught Exception:', error);
});

module.exports = app;
