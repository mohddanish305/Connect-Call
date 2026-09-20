# ConnectCall Cloudflare Worker Backend

Production-grade serverless backend for ConnectCall running on the Cloudflare Workers edge network. Provides low-latency Agora RTC token generation, Firebase ID token verification, and security controls.

---

## Features

- **Edge Architecture**: Runs on Cloudflare's global edge network for sub-10ms response times.
- **Workers-Compatible Firebase Auth**: Validates Firebase ID tokens using `jose` and Google's public JWKS.
- **Agora RTC Token Builder**: Creates cryptographically signed, short-lived tokens using `RtcTokenBuilder` with `nodejs_compat`.
- **Zero Credential Leakage**: `AGORA_APP_CERTIFICATE` is stored in Cloudflare encrypted secrets and never exposed.
- **Safe Mobile CORS**: Pre-configured headers for mobile and web apps without credential sharing hazards.

---

## Endpoints

- **`GET /health`**: Health status endpoint returning `{ "success": true, "service": "ConnectCall Backend", "status": "healthy" }`
- **`POST /api/agora/token`**: Generates a temporary RTC token. Requires header `Authorization: Bearer <firebase_id_token>`.

---

## Local Development

```bash
cd backend-worker
npm install

# Create local development variables file (ignored by Git)
cp .dev.vars.example .dev.vars
# Add your AGORA_APP_ID and AGORA_APP_CERTIFICATE to .dev.vars

# Run local development server (http://localhost:8787)
npm run dev

# Run type check and automated tests
npm run typecheck
npm test
```

---

## Cloudflare Deployment

```bash
# Set production secrets in Cloudflare encrypted storage
npx wrangler secret put AGORA_APP_ID
npx wrangler secret put AGORA_APP_CERTIFICATE

# Deploy to Cloudflare Workers
npm run deploy
```
