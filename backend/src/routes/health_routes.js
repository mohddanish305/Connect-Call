const express = require('express');
const router = express.Router();
const healthController = require('../controllers/health_controller');

// GET /health
router.get('/health', healthController.getHealth);

module.exports = router;
