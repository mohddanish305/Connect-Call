# ConnectCall

> Real-Time 1-to-1 Audio & Video Calling Application

ConnectCall is a production-grade, real-time 1-to-1 audio and video calling mobile application built with Flutter, Riverpod, Cloud Firestore, and the Agora RTC Engine. It is engineered with strict separation of concerns, defensive security architecture, responsive error handling, and cloud-ready backend token authentication.

---

## Assignment Overview

ConnectCall was designed and developed specifically for the **Flutter Development Intern Assignment**. The assignment requires a fully functional, real-time 1-to-1 audio and video calling mobile application (not merely a UI prototype) backed by secure signaling, granular call controls, persistent call history, robust permission handling, and server-side credential isolation.

---

## Features

### Mandatory Requirements
- **Authentication**: Email and password user registration, secure login with Firebase Authentication, persistent session state across app restarts, and clean sign out.
- **User Discovery & Profile**: Real-time searchable user directory, live presence indicators (`Online` / `Last seen`), and profile customization.
- **1-to-1 Audio Calling**: Real-time, ultra-low latency voice communication powered by Agora RTC.
- **1-to-1 Video Calling**: 720p HD video streaming, local camera preview picture-in-picture (PIP), and hardware-accelerated remote canvas rendering.
- **Signaling & Incoming Calls**: Real-time Firestore signaling with incoming call alerts, pulsing visual cues, ringtone feedback, and Accept/Reject actions.
- **Audio Controls**: Live microphone mute/unmute, earpiece/speakerphone audio routing toggle, and hang-up termination.
- **Video Controls**: Live camera feed toggle (on/off), front/rear camera lens switching, microphone muting, and hang-up termination.
- **Call History**: Idempotent persistence of call sessions recording participant identities, call direction (incoming/outgoing), call type (audio/video), timestamp, duration (`mm:ss`), and status badges.
- **Permissions**: Runtime handling for Microphone and Camera via `permission_handler`, with distinct dialogs and settings shortcuts for denied and permanently denied states.
- **Call State Lifecycle**: Strict state machine handling transitions across `Calling`, `Ringing`, `Connected`, `In Call`, `Ended`, `Rejected`, `Missed`, `Busy`, `Failed`, and `Disconnected`.
- **Error Handling & Resilience**: Pre-flight network reachability checks, reconnection handling with countdown timer, token expiration refresh, and graceful fallback when users are offline or decline calls.

### Implemented Bonus Features
- **Push Notifications**: Firebase Cloud Messaging (FCM) incoming call payloads dispatched via backend `/api/notifications/call`.
- **Background Incoming Calls**: High-priority notification channel (`connectcall_incoming_calls`) waking the device for incoming calls.
- **Dark Mode**: 3-option theme switcher (`System Default`, `Light`, `Dark`) with immediate persistence.
- **Block User**: Ability to block/unblock users with dedicated blocked users management screen and isolated Firestore security rules.
- **Recent Contacts**: Frequently and recently contacted user list saved locally with instant redial capability.
- **Group Calling**: Multi-party calling support (`groupCalls` Firestore collection and dynamic multi-participant canvas).
- **Network Quality Indicators**: Live packet loss and bitrate monitoring via Agora RTC engine callbacks displaying network health in the active call UI.

---

## Tech Stack

| Technology / Library | Version | Role in Architecture |
| :--- | :--- | :--- |
| **Flutter SDK** | `3.41.1 (channel stable)` | Cross-platform mobile client framework |
| **Dart SDK** | `3.11.0` | Strongly-typed client programming language |
| **flutter_riverpod** | `^2.6.1` | Reactive, testable state management |
| **agora_rtc_engine** | `^6.6.4` | Hardware-accelerated real-time voice & video engine |
| **firebase_core** | `^4.14.0` | Firebase client initialization and lifecycle |
| **firebase_auth** | `^6.6.1` | User authentication and Firebase ID Token management |
| **cloud_firestore** | `^6.9.0` | Real-time call signaling, presence, and history |
| **firebase_messaging**| `^16.7.0` | Background incoming call push notifications |
| **flutter_local_notifications** | `^18.0.1` | Heads-up foreground notification display |
| **permission_handler**| `^11.4.0` | OS runtime permission management (Camera/Mic) |
| **shared_preferences**| `^2.3.5` | Local persistent cache (theme, onboarding, call logs) |
| **Node.js** | `v24.13.0` | Backend runtime environment |
| **Express** | `^4.21.2` | REST API framework for secure token vending |
| **agora-token** | `^2.0.6` | Official server-side Agora RTC token generator |
| **firebase-admin** | `^14.4.0` | Server-side Firebase ID token verification |
| **helmet** | `^8.0.0` | HTTP security response headers |
| **cors** | `^2.8.5` | Centralized CORS middleware |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Client Application               │
│                                                             │
│   Screens (Auth, Home, Contacts, AudioCall, VideoCall)      │
│                              ▲                              │
│   Riverpod State Notifiers (Auth, CallController, History)   │
│                              ▲                              │
│   Services (CallingService, CallSignaling, Permission)      │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
        Bearer ID Token                 Firestore Listeners
      Agora Token Request             Signaling & Presence
               ▼                               ▼
┌──────────────────────────────┐  ┌───────────────────────────┐
│     Node.js / Express        │  │     Google Cloud /        │
│       Backend Server         │  │     Firebase Backend      │
│                              │  │                           │
│ • Firebase Token Verify      │  │ • Firebase Authentication │
│ • Input & UID Validation     │  │ • Cloud Firestore DB      │
│ • Secure Agora RTC Token     │  │ • Strict Security Rules v2│
│   Builder (Cert in .env)     │  │                           │
└──────────────┬───────────────┘  └───────────────────────────┘
               │
          Channel Token
               ▼
┌──────────────────────────────┐
│       Agora RTC Engine       │
│ • Low-Latency Audio Stream   │
│ • 720p HD Video & Preview    │
│ • Adaptive Bitrate & Quality │
└──────────────────────────────┘
```

### Layer Responsibilities
1. **UI Layer (`lib/screens/`, `lib/widgets/`)**: Declarative Flutter widgets reflecting state reactively. Strictly decoupled from network protocols.
2. **State Management (`lib/providers/`)**: Riverpod Notifiers encapsulating business logic, session models, and reactive streams.
3. **Service Layer (`lib/services/`, `lib/core/services/`)**: Single-responsibility adapters managing Agora RTC engine lifecycle, Firestore signaling, runtime permissions, and HTTP token requests.
4. **Backend Layer (`backend/`)**: Authoritative Node.js service verifying caller identity via Firebase Admin and generating short-lived Agora RTC tokens using the private App Certificate.
5. **Real-Time Media Layer (Agora RTC Engine)**: Native media engine handling echo cancellation, noise suppression, adaptive video encoding, and peer-to-peer/relay data delivery.

---

## Project Structure

```
ConnectCall/
├── android/                         # Native Android host project & Gradle configuration
│   ├── app/
│   │   ├── google-services.json    # Firebase Android client configuration
│   │   ├── build.gradle.kts        # Android app build specification
│   │   └── src/main/AndroidManifest.xml # Permissions & intents
│   └── build.gradle.kts            # Project-level Gradle build file
├── ios/                             # Native iOS configuration (Info.plist, entitlements)
├── assets/                          # App brand logos, illustrations, and images
├── backend/                         # Node.js Express Agora Token & Notification server
│   ├── src/
│   │   ├── config/
│   │   │   └── env.js              # Environment variable validation
│   │   ├── controllers/
│   │   │   ├── agora_controller.js # POST /api/agora/token handler
│   │   │   └── health_controller.js# GET /health handler
│   │   ├── middleware/
│   │   │   ├── auth_middleware.js  # Firebase ID Token verification
│   │   │   ├── cors_middleware.js  # Mobile-appropriate CORS
│   │   │   └── error_handler.js    # Global error response formatting
│   │   ├── routes/                 # Express route definitions
│   │   ├── services/
│   │   │   └── agora_token_service.js # RtcTokenBuilder token generator
│   │   └── server.js               # Application entry point & graceful shutdown
│   ├── tests/
│   │   └── agora_token.test.js     # 11-step automated backend test suite
│   ├── .env.example                # Safe environment variable template
│   └── package.json                # Node dependencies & scripts
├── docs/                            # Architecture & verification checklists
├── lib/
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart     # Decoupled dev/prod backend endpoints
│   │   ├── constants/              # Spacing, colors, radius, and typography
│   │   ├── services/               # Agora engine, token client, and network
│   │   ├── theme/                  # Light and Dark ThemeData definitions
│   │   └── utils/                  # Date and duration formatters
│   ├── models/                      # User, Call, and CallHistory data models
│   ├── providers/                   # Riverpod StateNotifiers and StreamProviders
│   ├── screens/                     # Auth, Call, Contacts, History, Profile
│   ├── services/                    # Signaling, permissions, block, recent contacts
│   ├── widgets/                     # Reusable buttons, avatars, badges
│   ├── firebase_options.dart        # FlutterFire client configuration
│   └── main.dart                    # Client startup & ProviderScope bootstrap
├── test/
│   └── widget_test.dart             # 22-step Flutter unit & widget test suite
├── .gitignore                       # Strict repository credential protections
├── firestore.rules                  # Strict Cloud Firestore Security Rules v2
└── pubspec.yaml                     # Flutter package dependencies
```

---

## Calling Architecture & Lifecycle

```
Caller                               Callee                     Backend Server
  │                                    │                              │
  ├─── 1. Create Call Document ───────►│ (Firestore: 'ringing')       │
  │    (status: 'calling')             │                              │
  │                                    ├─── 2. Display Incoming Screen│
  │                                    │    (Ringtone & Vibration)    │
  │                                    │                              │
  │                                    ├─── 3. Callee Taps Accept ────┤
  │                                    │    (Firestore: 'accepted')   │
  │                                    │                              │
  ├─── 4. Request Agora RTC Token ─────┼─────────────────────────────►│
  │    (Auth: Bearer Firebase-Token)   │                              │ (Verify Token)
  │◄── 5. Return Temporary Token ──────┼──────────────────────────────┤
  │                                    │                              │
  │                                    ├─── 6. Request Agora Token ──►│
  │                                    │◄── 7. Return Agora Token ────┤
  │                                    │                              │
  ├─── 8. Join Agora Channel ──────────┤                              │
  │    (channelName, numeric UID)      ├─── 9. Join Agora Channel ────┤
  │                                    │                              │
  │◄═══════════════════════════════════╪═════════════════════════════►│
  │       10. Real-Time Audio / 720p HD Video Communication (Agora)   │
  │◄═══════════════════════════════════╪═════════════════════════════►│
  │                                    │                              │
  ├─── 11. Caller/Callee Ends Call ───►│ (Firestore: 'ended')         │
  │                                    ├─── 12. Teardown RTC Engine   │
  └─── 13. Idempotent History Saved ───┴─── 14. Return to Dashboard   │
```

---

## Backend Service

The backend is built with Node.js and Express to safeguard the Agora App Certificate and issue cryptographically signed, short-lived Agora RTC tokens.

- **`GET /health`**: Health status endpoint returning service status.
- **`POST /api/agora/token`**: Protected endpoint requiring a Firebase ID Token in `Authorization: Bearer <token>`.
- **`POST /api/notifications/call`**: Optional push notification trigger for waking sleeping callee devices via FCM.

---

## Environment Variables

### Backend Configuration (`backend/.env.example`)
Configure these environment variables in your deployment environment or in `backend/.env` for local testing:

```env
PORT=3000
NODE_ENV=development

# Agora RTC Credentials (App Certificate is strictly server-side)
AGORA_APP_ID=
AGORA_APP_CERTIFICATE=
AGORA_TOKEN_EXPIRY_SECONDS=3600

# Firebase Admin Configuration (For cloud platforms like Render)
FIREBASE_PROJECT_ID=connectcall-01
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

# Local service account file path (optional)
FIREBASE_SERVICE_ACCOUNT_PATH=
```

> [!IMPORTANT]
> Never commit real secret keys (`AGORA_APP_CERTIFICATE`, `FIREBASE_PRIVATE_KEY`) to version control. Production secrets must be configured via the deployment platform's environment variables dashboard.

---

## Local Setup & Running Instructions

### 1. Prerequisites
- **Flutter SDK**: `3.41.1` or compatible stable version
- **Dart SDK**: `^3.11.0`
- **Node.js**: `v20.x` or `v24.x`
- **Android Studio / Android SDK**: Platform 34+, Build Tools, NDK

### 2. Backend Setup
```bash
cd backend
npm install

# Create local environment file from template
cp .env.example .env
# Edit backend/.env with your AGORA_APP_ID and AGORA_APP_CERTIFICATE

# Start local server
npm start
```
Verify the server is running by opening: `http://localhost:3000/health`

### 3. Flutter Client Setup
```bash
# Return to repository root
cd ..

# Fetch Flutter dependencies
flutter pub get

# Run on an Android emulator or connected device
# For local physical devices, pass your host computer's LAN IP:
flutter run --dart-define=BACKEND_BASE_URL=http://<YOUR_LOCAL_IP>:3000
```

---

## Android Permissions

The application requests the following permissions configured in `android/app/src/main/AndroidManifest.xml`:
- `android.permission.RECORD_AUDIO`: Voice capture for audio and video calls.
- `android.permission.CAMERA`: Video capture for video calling.
- `android.permission.INTERNET`: Firebase signaling and Agora RTC media streaming.
- `android.permission.ACCESS_NETWORK_STATE`: Pre-flight connectivity checks.
- `android.permission.POST_NOTIFICATIONS`: Foreground service and incoming call alerts on Android 13+.

---

## Firestore Security & Data Architecture

The application requires the following Firestore collections, protected by `firestore.rules`:
- **`users/{userId}`**: User profile data (name, email, presence, last seen). Read-accessible to authenticated users; write-restricted to the document owner.
- **`users/{userId}/blockedUsers/{blockedUid}`**: Block list entries restricted strictly to the user and target blocked peer.
- **`calls/{callId}`**: Active 1-to-1 call signaling documents. Readable and modifiable solely by the designated `callerId` and `receiverId` with enforced state transitions.
- **`callHistory/{historyId}`**: Permanent call logs accessible and writable solely by call participants.
- **`groupCalls/{groupId}`**: Multi-party group call state accessible only by group participants and host.

---

## Security Architecture

1. **Zero Secret Leakage**: The `AGORA_APP_CERTIFICATE` and Firebase Admin private keys reside exclusively on the server and are never packaged into the Flutter client binary or release APK.
2. **Short-Lived RTC Tokens**: Tokens expire automatically after 3600 seconds (configurable) and grant access strictly to a specific channel and numeric UID.
3. **Identity Verification**: Every token request must present a valid, cryptographically verified Firebase ID Token.
4. **Client Config Distinction**: `google-services.json` and `firebase_options.dart` contain only public client identifiers, completely separate from privileged Firebase Admin service account keys.
5. **No Secret Logging**: The server explicitly filters out all tokens, authorization headers, and certificate values from server logs.

---

## Cloud Deployment (Cloudflare Workers & Edge Network)

The backend is prepared for deployment on **Cloudflare Workers** with global edge replication:
- **Production URL**: `https://<YOUR_WORKER_NAME>.<YOUR_SUBDOMAIN>.workers.dev`
- **Health Check**: `GET /health`
- **Token Endpoint**: `POST /api/agora/token`
- **Configuration**:
  - `wrangler.jsonc` with `nodejs_compat` enabled
  - Serverless architecture with sub-15ms cold starts
  - Secure Cloudflare encrypted secrets for `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE`
  - Zero server maintenance, DDoS mitigation, and global auto-scaling

### Deploying Your Own Worker
```bash
cd backend-worker
npm install

# Configure secrets in Cloudflare encrypted storage
npx wrangler secret put AGORA_APP_ID
npx wrangler secret put AGORA_APP_CERTIFICATE

# Deploy to Cloudflare
npm run deploy
```

---

## Alternative Cloud Deployment (Render Web Service)

For traditional server environments, the Node.js Express backend in `backend/` is also deployment-ready for [Render](https://render.com):
- **Root Directory**: `backend`
- **Environment**: `Node`
- **Build Command**: `npm install`
- **Start Command**: `npm start`
- **Health Check Path**: `/health`
- **Environment Variables**:
  - `PORT`: `10000` (set automatically by Render)
  - `NODE_ENV`: `production`
  - `AGORA_APP_ID`: `<YOUR_AGORA_APP_ID>`
  - `AGORA_APP_CERTIFICATE`: `<YOUR_AGORA_APP_CERTIFICATE>`
  - `FIREBASE_PROJECT_ID`: `connectcall-01`
  - `FIREBASE_CLIENT_EMAIL`: `<YOUR_FIREBASE_SERVICE_ACCOUNT_EMAIL>`
  - `FIREBASE_PRIVATE_KEY`: `<YOUR_FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY>`


---

## Building Release APK

```bash
flutter build apk --release
```
The resulting release binary will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Test Verification Matrix

| Component | Test Suite | Tests Executed | Status |
| :--- | :--- | :--- | :--- |
| **Flutter Static Analysis** | `flutter analyze` | Entire Flutter codebase | **PASS** (0 issues) |
| **Flutter Unit & Widgets** | `flutter test` (`test/widget_test.dart`) | 22 tests | **PASS** (22/22) |
| **Cloudflare Worker Suite** | `npm test` (`backend-worker/tests/worker.test.ts`) | 9 tests | **PASS** (9/9) |
| **Node Backend Integration** | `npm test` (`backend/tests/agora_token.test.js`) | 11 tests | **PASS** (11/11) |
| **Secret Scan** | Automated repository audit | Full repo grep | **PASS** (0 committed secrets) |
| **Git Credential Ignore** | `git check-ignore backend/.env backend-worker/.dev.vars` | Git index check | **PASS** (Ignored) |

---

## Known Limitations

1. **Agora Token Connectivity**: Real-time media exchange requires an active internet connection to the token server and Agora SD-RTN infrastructure.
2. **Background Wake-up**: Background call notifications depend on Google Play Services and OEM battery optimization policies.
3. **Hardware Emulation**: Testing video camera feed and microphone recording is best evaluated on physical hardware rather than headless virtual devices.

---

## AI-Assisted Development Disclosure

In accordance with internship evaluation guidelines, the development of ConnectCall utilized:
- **ChatGPT**: Assisted with preliminary architectural drafting, protocol planning, and test scenario design.
- **Antigravity IDE**: Assisted with codebase navigation, refactoring, test execution, and security audit verification.

All generated code, state machines, Agora RTC integrations, and security rules were manually reviewed, tested, and hardened by the developer.
