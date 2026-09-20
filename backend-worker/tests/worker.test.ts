import { describe, it, expect, beforeEach } from 'vitest';
import app from '../src/index';
import type { Env } from '../src/types';

describe('ConnectCall Cloudflare Worker Backend Tests', () => {
  const mockEnv: Env = {
    SERVICE_NAME: 'ConnectCall Backend',
    FIREBASE_PROJECT_ID: 'connectcall-01',
    AGORA_APP_ID: 'f8accb6b3dc04d2c85f43cc502bb7b23',
    AGORA_APP_CERTIFICATE: '9884447ab7a243cbb5feeb5bb000deac',
    AGORA_TOKEN_EXPIRY_SECONDS: '3600',
    ENVIRONMENT: 'test',
  };

  it('TEST 0: GET /health returns 200 and healthy status', async () => {
    const res = await app.request('/health', {}, mockEnv);
    expect(res.status).toBe(200);

    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(true);
    expect(body.service).toBe('ConnectCall Backend');
    expect(body.status).toBe('healthy');
  });

  it('TEST 1: POST /api/agora/token without Authorization header returns 401', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ channelName: 'call_test123', uid: 123456 }),
      },
      mockEnv
    );

    expect(res.status).toBe(401);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(body.message).toBe('Authentication required.');
  });

  it('TEST 2: POST /api/agora/token with invalid Bearer token returns 401', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer invalid_garbage_token_99999',
        },
        body: JSON.stringify({ channelName: 'call_test123', uid: 123456 }),
      },
      mockEnv
    );

    expect(res.status).toBe(401);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(body.message).toBe('Authentication required.');
  });

  it('TEST 3: POST /api/agora/token with missing channelName returns 400', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ uid: 123456 }),
      },
      mockEnv
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(String(body.message)).toMatch(/channelName/i);
  });

  it('TEST 4: POST /api/agora/token with invalid UID returns 400', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ channelName: 'call_test123', uid: -5 }),
      },
      mockEnv
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(String(body.message)).toMatch(/uid/i);
  });

  it('TEST 4b: POST /api/agora/token with invalid channelName format returns 400', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ channelName: 'invalid_format', uid: 123456 }),
      },
      mockEnv
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(false);
    expect(String(body.message)).toMatch(/channelName/i);
  });

  it('TEST 5: POST /api/agora/token with valid request generates token (200 OK)', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ channelName: 'call_test_ok', uid: 123456 }),
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(true);
    expect(typeof body.token).toBe('string');
    expect(String(body.token).length).toBeGreaterThan(20);
    expect(body.channelName).toBe('call_test_ok');
    expect(body.uid).toBe(123456);
    expect(body.appId).toBe(mockEnv.AGORA_APP_ID);
    expect(body.expiresAt).toBeDefined();

    // Verify compatibility with Flutter AgoraTokenResponse.fromJson (data object)
    const data = body.data as Record<string, unknown>;
    expect(data).toBeDefined();
    expect(data.token).toBe(body.token);
  });

  it('TEST 5b: POST /api/agora/token supports group calling channelName (group_*)', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ channelName: 'group_conference123', uid: 987654 }),
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.success).toBe(true);
    expect(body.channelName).toBe('group_conference123');
    expect(body.uid).toBe(987654);
    expect(typeof body.token).toBe('string');
  });

  it('TEST 6: Response NEVER exposes AGORA_APP_CERTIFICATE', async () => {
    const res = await app.request(
      '/api/agora/token',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer test_valid_firebase_token_user1',
        },
        body: JSON.stringify({ channelName: 'call_secretcheck', uid: 112233 }),
      },
      mockEnv
    );

    const text = await res.text();
    expect(text.includes(mockEnv.AGORA_APP_CERTIFICATE!)).toBe(false);
    expect(text.toLowerCase().includes('certificate')).toBe(false);
  });
});
