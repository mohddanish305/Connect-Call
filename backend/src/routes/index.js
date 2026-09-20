const express = require('express');
const router = express.Router();
const healthRoutes = require('./health_routes');

const agoraRoutes = require('./agora_routes');
const notificationRoutes = require('./notification_routes');

// Health check available at /health and /api/health
router.use('/', healthRoutes);

// Base API route mount (/api)
const apiRouter = express.Router();

// Mount health check on /api/health as well
apiRouter.use('/', healthRoutes);

// Agora RTC token routes (/api/agora/token)
apiRouter.use('/agora', agoraRoutes);

// Notification routes (/api/notifications/call)
apiRouter.use('/notifications', notificationRoutes);

router.use('/api', apiRouter);

module.exports = router;
