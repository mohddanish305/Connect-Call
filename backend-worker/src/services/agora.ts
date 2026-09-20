import pkg from 'agora-token';
const { RtcTokenBuilder, RtcRole } = pkg;

export interface GeneratedTokenData {
  token: string;
  appId: string;
  channelName: string;
  uid: number;
  expiresAt: string;
}

/**
 * Validates channelName according to Agora constraints and ConnectCall convention (call_ or group_)
 */
export function validateChannelName(channelName: unknown): string {
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

  const safePattern = /^(call|group)_[a-zA-Z0-9_-]+$/;
  if (!safePattern.test(trimmed)) {
    throw new Error('channelName contains invalid characters. Expected format: call_<unique_id> or group_<unique_id>.');
  }

  return trimmed;
}

/**
 * Validates numeric Agora UID (positive 32-bit unsigned integer)
 */
export function validateUid(uid: unknown): number {
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
 * Generates short-lived Agora RTC token for 1-to-1 or group calling
 */
export function generateAgoraToken(
  rawChannelName: unknown,
  rawUid: unknown,
  appId: string | undefined,
  appCertificate: string | undefined,
  expireSeconds: number = 3600
): GeneratedTokenData {
  const channelName = validateChannelName(rawChannelName);
  const uid = validateUid(rawUid);

  if (!appId || appId.trim().length === 0) {
    throw new Error('AGORA_APP_ID is not configured.');
  }

  if (!appCertificate || appCertificate.trim().length === 0) {
    throw new Error('AGORA_APP_CERTIFICATE is not configured.');
  }

  const trimmedAppId = appId.trim();
  const trimmedCert = appCertificate.trim();

  const isHex32 = /^[a-fA-F0-9]{32}$/.test(trimmedCert);
  if (!isHex32) {
    throw new Error('AGORA_APP_CERTIFICATE must be a 32-character hexadecimal string.');
  }

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + (expireSeconds > 0 ? expireSeconds : 3600);

  // Role: PUBLISHER (allows both bidirectional sending & receiving for 1-to-1 calling)
  const role = RtcRole.PUBLISHER;

  const token = RtcTokenBuilder.buildTokenWithUid(
    trimmedAppId,
    trimmedCert,
    channelName,
    uid,
    role,
    privilegeExpiredTs,
    privilegeExpiredTs
  );

  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    throw new Error('Failed to generate Agora token.');
  }

  return {
    token,
    appId: trimmedAppId,
    channelName,
    uid,
    expiresAt: new Date(privilegeExpiredTs * 1000).toISOString(),
  };
}
