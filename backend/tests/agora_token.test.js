const assert = require('assert');
const http = require('http');
const { execSync } = require('child_process');

// Ensure test environment variables are set before loading app
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';
process.env.AGORA_APP_ID = process.env.AGORA_APP_ID || '0123456789abcdef0123456789abcdef';
process.env.AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || '0123456789abcdef0123456789abcdef';
process.env.AGORA_TOKEN_EXPIRY_SECONDS = '3600';

const app = require('../src/server');

// Helper to make HTTP requests to the test server
function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : null;
          resolve({ status: res.statusCode, headers: res.headers, body: parsed, rawBody: body });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, body, rawBody: body });
        }
      });
    });

    req.on('error', reject);

    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runTests() {
  console.log('--- Starting ConnectCall Agora Token Server Tests ---\n');
  let passed = 0;
  let total = 0;

  async function test(name, fn) {
    total++;
    try {
      await fn();
      console.log(`✓ [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`✗ [FAIL] ${name}`);
      console.error(err);
    }
  }

  // TEST 0: Health Check
  await test('GET /health returns 200 OK', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/health',
      method: 'GET',
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
  });

  // TEST 1: POST /api/agora/token without Authorization
  await test('TEST 1: POST /api/agora/token without Authorization returns 401', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }, { channelName: 'call_test123', uid: 123456 });

    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Authentication required.');
  });

  // TEST 2: POST /api/agora/token with invalid Firebase token
  await test('TEST 2: POST with invalid Firebase token returns 401', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer invalid_garbage_token_99999',
      },
    }, { channelName: 'call_test123', uid: 123456 });

    assert.strictEqual(res.status, 401);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Authentication required.');
  });

  // TEST 3: POST with authenticated user but missing channelName
  await test('TEST 3: POST with authenticated Firebase user but missing channelName returns 400', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test_valid_firebase_token_user1',
      },
    }, { uid: 123456 });

    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.match(res.body.message, /channelName/i);
  });

  // TEST 4: POST with authenticated user but invalid UID
  await test('TEST 4: POST with authenticated Firebase user but invalid UID returns 400', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test_valid_firebase_token_user1',
      },
    }, { channelName: 'call_test123', uid: -5 });

    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.match(res.body.message, /uid/i);
  });

  // Additional channel format validation check (rejecting invalid channel prefix / characters)
  await test('TEST 4b: POST with invalid channelName format returns 400', async () => {
    const res = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test_valid_firebase_token_user1',
      },
    }, { channelName: 'invalid_channel_format', uid: 123456 });

    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.match(res.body.message, /channelName/i);
  });

  // TEST 5: POST with valid Firebase ID token + valid channel + valid UID
  let test5Response;
  await test('TEST 5: POST with valid token + valid channel + valid UID returns 200 & token', async () => {
    test5Response = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test_valid_firebase_token_user1',
      },
    }, { channelName: 'call_abc123', uid: 123456 });

    assert.strictEqual(test5Response.status, 200);
    assert.strictEqual(test5Response.body.success, true);
    assert.ok(test5Response.body.data, 'data property exists');
    assert.ok(typeof test5Response.body.data.token === 'string' && test5Response.body.data.token.length > 20, 'token is a valid string');
    assert.strictEqual(test5Response.body.data.channelName, 'call_abc123');
    assert.strictEqual(test5Response.body.data.uid, 123456);
    assert.ok(test5Response.body.data.expiresAt, 'expiresAt exists');
    assert.strictEqual(test5Response.body.data.appId, process.env.AGORA_APP_ID);
  });

  // TEST 5b: POST with valid token + valid group channel + valid UID
  await test('TEST 5b: POST with valid token + valid group channel (group_xyz) returns 200 & token', async () => {
    const groupRes = await makeRequest({
      hostname: 'localhost',
      port: 3001,
      path: '/api/agora/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test_valid_firebase_token_user1',
      },
    }, { channelName: 'group_test999', uid: 654321 });

    assert.strictEqual(groupRes.status, 200);
    assert.strictEqual(groupRes.body.success, true);
    assert.strictEqual(groupRes.body.data.channelName, 'group_test999');
    assert.strictEqual(groupRes.body.data.uid, 654321);
    assert.ok(typeof groupRes.body.data.token === 'string' && groupRes.body.data.token.length > 20);
  });

  // TEST 6: Verify response does NOT contain AGORA_APP_CERTIFICATE
  await test('TEST 6: Verify response does NOT contain AGORA_APP_CERTIFICATE', async () => {
    assert.ok(test5Response, 'Previous response exists');
    const rawString = JSON.stringify(test5Response.rawBody);
    assert.strictEqual(rawString.includes(process.env.AGORA_APP_CERTIFICATE), false, 'Response must not contain certificate value');
    assert.strictEqual(rawString.toLowerCase().includes('certificate'), false, 'Response must not contain certificate property');
  });

  // TEST 7: Verify logs do NOT contain AGORA_APP_CERTIFICATE
  await test('TEST 7: Verify logs do NOT contain AGORA_APP_CERTIFICATE', async () => {
    const capturedLogs = [];
    const origLog = console.log;
    const origError = console.error;
    console.log = (...args) => { capturedLogs.push(args.join(' ')); origLog(...args); };
    console.error = (...args) => { capturedLogs.push(args.join(' ')); origError(...args); };

    try {
      await makeRequest({
        hostname: 'localhost',
        port: 3001,
        path: '/api/agora/token',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test_valid_firebase_token_user1',
        },
      }, { channelName: 'call_testlog1', uid: 456789 });
    } finally {
      console.log = origLog;
      console.error = origError;
    }

    const allLogs = capturedLogs.join('\n');
    assert.strictEqual(allLogs.includes(process.env.AGORA_APP_CERTIFICATE), false, 'Logs must never contain Agora App Certificate');
  });

  // TEST 8: Verify backend/.env is ignored by Git
  await test('TEST 8: Verify backend/.env is ignored by Git', async () => {
    try {
      const gitCheck = execSync('git check-ignore backend/.env', { encoding: 'utf8' }).trim();
      assert.ok(gitCheck.includes('.env'), 'backend/.env is correctly ignored by git');
    } catch (e) {
      assert.fail('backend/.env is NOT ignored by git: ' + e.message);
    }
  });

  console.log(`\n--- Test Results: ${passed}/${total} passed ---`);
  process.exit(passed === total ? 0 : 1);
}

// Give server 500ms to bind, then run tests
setTimeout(runTests, 500);
