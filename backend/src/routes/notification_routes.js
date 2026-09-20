const express = require('express');
const router = express.Router();
const fs = require('fs');
const env = require('../config/env');
const { successResponse, errorResponse } = require('../utils/response');

/**
 * POST /api/notifications/call
 * Dispatches an incoming call push notification via Firebase Cloud Messaging.
 * Notification payload includes only non-secret call metadata.
 */
router.post('/call', async (req, res) => {
  const { callId, callerId, callerName, receiverId, callType, channelName } = req.body;

  if (!callId || !receiverId) {
    return errorResponse(res, 'Missing required fields: callId and receiverId are required.', 400);
  }

  // Gracefully skip if Firebase service account credentials are not configured on server
  if (!env.FIREBASE_SERVICE_ACCOUNT_PATH || !fs.existsSync(env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
    return successResponse(res, {
      dispatched: false,
      reason: 'Firebase service account not configured on server; signaling handled via Firestore.'
    });
  }

  try {
    const { getFirestore } = require('firebase-admin/firestore');
    const { getMessaging } = require('firebase-admin/messaging');
    const firestore = getFirestore();
    const userDoc = await firestore.collection('users').doc(receiverId).get();

    if (!userDoc.exists) {
      return successResponse(res, { dispatched: false, reason: 'Receiver profile not found.' });
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
      console.log(`[FCM] Receiver ${receiverId} has no registered FCM token. Skipping push.`);
      return successResponse(res, { dispatched: false, reason: 'Receiver has no FCM token registered.' });
    }

    const isVideo = callType === 'video';
    const title = isVideo ? 'Incoming Video Call' : 'Incoming Audio Call';
    const body = `${callerName || 'Someone'} is calling you`;

    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        callId: String(callId),
        callerId: String(callerId || ''),
        callerName: String(callerName || ''),
        receiverId: String(receiverId),
        callType: String(callType || 'video'),
        channelName: String(channelName || ''),
        type: 'incoming_call',
      },
      android: {
        priority: 'high',
        ttl: 30000, // 30 seconds ringing TTL
        notification: {
          channelId: 'connectcall_incoming_calls',
          priority: 'max',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
    };

    const response = await getMessaging().send(message);
    console.log(`[FCM] Successfully dispatched incoming call push notification (messageId: ${response}) to receiver ${receiverId}`);

    return successResponse(res, {
      dispatched: true,
      messageId: response,
    });
  } catch (error) {
    console.warn(`[FCM Error] Failed to send push notification to receiver ${receiverId}:`, error.message);
    // Return 200 with error info so caller flow is never halted
    return successResponse(res, {
      dispatched: false,
      error: error.message,
    });
  }
});

module.exports = router;
