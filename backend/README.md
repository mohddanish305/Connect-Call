# ConnectCall Backend

## Purpose

This backend provides secure, production-grade server-side infrastructure for the ConnectCall Flutter 1-to-1 calling application. It acts as the centralized gateway for security, future Firebase ID token verification, and short-lived Agora RTC token generation.

## Current Features

- **Express.js Server**: Modular architecture with separation of concerns (`routes`, `controllers`, `services`, `middleware`, `config`, `utils`).
- **Environment Configuration**: Centralized, validated environment configuration with fast-fail validation on missing or invalid variables.
- **Security Middleware**: Powered by `helmet` for HTTP security headers.
- **CORS Management**: Centralized CORS middleware with support for configurable origins.
- **Health Check**: Automated health check endpoint returning service status.
- **Centralized Error Handling**: Standardized, safe JSON responses (`{ success: false, message: ... }`) without leaking stack traces or internal paths.
- **404 Route Handling**: Standardized 404 handler for nonexistent routes.
- **Safe Request Logger**: Development logger that strictly excludes sensitive headers, tokens, and credentials.

## Planned Features

- **Firebase Authentication Verification**: Server-side verification of client Firebase Bearer ID tokens.
- **Secure Agora RTC Token Generation**: Server-side minting of short-lived tokens using the Agora App Certificate kept strictly on the backend.
- **Call-related APIs**: Application-level call state and signaling operations.

## Requirements

- **Node.js**: v18.0.0 or later (tested on Node v24)
- **npm**: v9.0.0 or later (tested on npm v11)

## Installation

Navigate to the `backend/` directory and install the required dependencies:

```bash
cd backend
npm install
```

## Environment Setup

Copy the example environment configuration template:

```bash
cp .env.example .env
```

The default development configuration contains:

```env
PORT=3000
NODE_ENV=development
```

> **SECURITY NOTE**: Sensitive credentials (such as Agora App Certificate, Firebase private keys, or API secrets) must **NEVER** be committed to Git. The `.gitignore` file is configured to strictly ignore all `.env` files while keeping `.env.example` trackable.

## Run Development Server

To run with automatic file watch and reload:

```bash
npm run dev
```

## Run Production Server

```bash
npm start
```

## Health Check

To verify the backend server is running and healthy:

```bash
curl http://localhost:3000/health
```

Expected Response (`200 OK`):

```json
{
  "success": true,
  "service": "ConnectCall Backend",
  "status": "healthy"
}
```

## Agora RTC Token Generation

Protected endpoint requiring Firebase Authentication:

- **Method**: `POST`
- **Route**: `/api/agora/token`
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer <FIREBASE_ID_TOKEN>`

### Request Body

```json
{
  "channelName": "call_test123",
  "uid": 123456
}
```

### Successful Response (`200 OK`)

```json
{
  "success": true,
  "data": {
    "token": "007eJxTYGg...<temporary_token>",
    "appId": "your_agora_app_id",
    "channelName": "call_test123",
    "uid": 123456,
    "expiresAt": "2026-09-11T12:00:00.000Z"
  }
}
```

### Curl Test Example

```bash
curl -X POST http://localhost:3000/api/agora/token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer FIREBASE_ID_TOKEN" \
  -d "{\"channelName\":\"call_test123\",\"uid\":123456}"
```

## Running Automated Tests

Run the test suite verifying health checks, authentication rejections, input validation, and secure token generation:

```bash
npm test
```

