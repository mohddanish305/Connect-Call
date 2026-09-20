const express = require('express');
const router = express.Router();
const agoraController = require('../controllers/agora_controller');
const { authenticateFirebaseUser } = require('../middleware/auth_middleware');

/**
 * @route   POST /api/agora/token
 * @desc    Generate a temporary Agora RTC token for 1-to-1 calling
 * @access  Protected (Requires Firebase ID Token in Authorization Bearer header)
 */
router.post('/token', authenticateFirebaseUser, (req, res) => agoraController.generateToken(req, res));

module.exports = router;
