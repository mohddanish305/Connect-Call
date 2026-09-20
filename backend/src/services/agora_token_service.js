const { RtcTokenBuilder, RtcRole } = require('agora-token');
const env = require('../config/env');

class AgoraTokenService {
  /**
   * Validate channel name according to Agora constraints and ConnectCall conventions
   * Expected format: call_<unique_id>
   * @param {string} channelName
   * @returns {string} trimmed valid channel name
   */
  validateChannelName(channelName) {
    if (!channelName || typeof channelName !== 'string') {
      throw new Error('channelName is required and must be a string.');
    }

    const trimmed = channelName.trim();
    if (trimmed.length < 5 || trimmed.length > 64) {
      throw new Error('channelName length must be between 5 and 64 characters.');
    }

    if ((!trimmed.startsWith('call_') && !trimmed.startsWith('group_')) || trimmed.length <= 5) {
      throw new Error('channelName must follow the format call_<unique_id> or group_<unique_id>.');
    }

    // Safe alphanumeric characters and underscores only
    const safeChannelPattern = /^(call|group)_[a-zA-Z0-9_-]+$/;
    if (!safeChannelPattern.test(trimmed)) {
      throw new Error('channelName contains invalid characters. Expected format: call_<unique_id> or group_<unique_id>.');
    }

    return trimmed;
  }

  /**
   * Validate Agora numeric UID (positive 32-bit unsigned integer)
   * @param {number|string} uid
   * @returns {number} valid integer UID
   */
  validateUid(uid) {
    if (uid === undefined || uid === null || uid === '') {
      throw new Error('uid is required.');
    }

    const num = Number(uid);
    if (!Number.isInteger(num) || num <= 0 || num > 4294967295) {
      throw new Error('uid must be a positive integer between 1 and 4294967295.');
    }

    return num;
  }

  /**
   * Generate short-lived Agora RTC Token
   * @param {string} rawChannelName
   * @param {number|string} rawUid
   * @param {number} [customExpireSeconds]
   * @returns {{ token: string, appId: string, channelName: string, uid: number, expiresAt: string }}
   */
  generateRtcToken(rawChannelName, rawUid, customExpireSeconds) {
    const channelName = this.validateChannelName(rawChannelName);
    const uid = this.validateUid(rawUid);

    const appId = env.AGORA_APP_ID;
    const appCertificate = env.AGORA_APP_CERTIFICATE;

    if (!appId || !appCertificate || appCertificate.includes('<')) {
      throw new Error('AGORA_APP_CERTIFICATE is not configured or is a placeholder. Please set your 32-character Primary Certificate from the Agora Console in backend/.env.');
    }

    const isHex32 = /^[a-fA-F0-9]{32}$/.test(appCertificate);
    if (!isHex32) {
      throw new Error('AGORA_APP_CERTIFICATE must be a 32-character hexadecimal string from the Agora Console.');
    }

    const expireSeconds = customExpireSeconds && customExpireSeconds > 0
      ? customExpireSeconds
      : env.AGORA_TOKEN_EXPIRY_SECONDS;

    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expireSeconds;

    // Role: PUBLISHER allows both audio/video sending and receiving (1-to-1 calling)
    const role = RtcRole.PUBLISHER;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      role,
      privilegeExpiredTs,
      privilegeExpiredTs
    );

    if (!token || typeof token !== 'string' || token.trim().length === 0) {
      throw new Error('Agora token generation returned empty. Please verify AGORA_APP_ID and AGORA_APP_CERTIFICATE in backend/.env.');
    }

    return {
      token,
      appId,
      channelName,
      uid,
      expiresAt: new Date(privilegeExpiredTs * 1000).toISOString(),
    };
  }
}

module.exports = new AgoraTokenService();
