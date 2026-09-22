# ConnectCall

A 1-to-1 audio and video calling application built with Flutter, Firebase, and Agora.

ConnectCall delivers real-time, low-latency audio and HD video calls with robust call signaling, granular controls, call history, and server-side credential isolation.

---

## Features

- **Firebase Authentication**: Email and password user registration, secure login, persistent session state, and clean sign out.
- **User Profiles & Discovery**: Real-time user directory, presence indicators (`Online` / `Last seen`), and profile customization.
- **Search**: Fast, real-time search across registered contacts.
- **1-to-1 Audio Calling**: Real-time, ultra-low latency voice communication powered by Agora RTC.
- **1-to-1 Video Calling**: 720p HD video streaming, local picture-in-picture (PIP) camera preview, and hardware-accelerated remote canvas rendering.
- **Incoming Call Handling**: Real-time Firestore signaling with incoming call alerts, vibration, ringtone feedback, and Accept/Reject actions.
- **Audio Controls**: Live microphone mute/unmute and speakerphone toggle.
- **Video Controls**: Live camera on/off toggle, front/rear camera lens switching, and microphone muting.
- **Call History**: Persistent call log recording participants, call direction (incoming/outgoing), call type (audio/video), timestamp, duration, and status badges.
- **Block/Unblock Users**: Easily block and unblock users with a dedicated blocked users list and enforced Firestore security rules.
- **Network Quality**: Real-time network health, packet loss, and bitrate monitoring indicators during active calls.
- **Dark Mode**: 3-option theme support (`System Default`, `Light`, `Dark`) with instant persistence.
- **Group Calling**: Multi-party calling support with dynamic multi-participant grid canvas.

---

## Download

### Android APK
Download the latest release for your device architecture from [**GitHub Releases**](https://github.com/mohddanish305/Connect-Call/releases):

| Build Variant | Architecture | Target Devices | Direct Download |
| :--- | :--- | :--- | :--- |
| **arm64-v8a (Recommended)** | 64-bit ARM | Modern Android smartphones (most devices) | [Download APK](https://github.com/mohddanish305/Connect-Call/releases/download/v1.0.0/ConnectCall-v1.0.0-arm64-v8a.apk) |
| **armeabi-v7a** | 32-bit ARM | Older 32-bit Android phones | [Download APK](https://github.com/mohddanish305/Connect-Call/releases/download/v1.0.0/ConnectCall-v1.0.0-armeabi-v7a.apk) |
| **x86_64** | 64-bit x86 | Android emulators & ChromeOS | [Download APK](https://github.com/mohddanish305/Connect-Call/releases/download/v1.0.0/ConnectCall-v1.0.0-x86_64.apk) |

> [!TIP]
> If you are unsure which architecture your phone uses, choose **`arm64-v8a`**, which works on virtually all modern Android devices.

---

## Installation

1. **Download the APK** from the [GitHub Releases](https://github.com/mohddanish305/Connect-Call/releases) page.
2. **Open the downloaded APK** on your Android device.
3. If prompted by Android, tap **Settings** and allow **Install unknown apps** from your browser or file manager.
4. Tap **Install** to install ConnectCall.
5. **Open ConnectCall**.
6. **Register** a new account or **login** with existing credentials.
7. **Grant microphone and camera permissions** when prompted so you can make and receive audio and video calls.

---

## Requirements

- **Device**: Android smartphone or tablet.
- **Minimum Android Version**: Android 5.0 (API Level 21 / Lollipop) or higher (as configured in `android/app/build.gradle.kts`).
- **Target Android Version**: Android 14+ (API Level 34+).
- **Network**: Active internet connection (Wi-Fi or cellular data).
- **Hardware**: Functional microphone and camera.

---

## Architecture

```
Flutter Client
      ↓
Firebase Authentication (User Sign-In & ID Token)
      ↓
Cloud Firestore (Real-time Signaling & Call State)
      ↓
Vercel Node.js Serverless API (Token Authorization & Issuance)
      ↓
Agora RTC Engine (Encrypted Real-Time Audio & Video Streaming)
```

### Security by Design:
- **Server-Side Credentials**: The sensitive `AGORA_APP_CERTIFICATE` is stored **strictly on the backend** as an environment variable and is **never** embedded in the client application, mobile binary, or version control.
- **Cryptographic Verification**: Every token request to the backend must include a valid `Authorization: Bearer <Firebase ID token>` header. The backend validates the user identity with the Firebase Admin SDK before issuing short-lived, channel-scoped Agora RTC tokens.

---

## Backend

- **Platform**: Vercel Serverless Functions (Node.js Express)
- **Production Base URL**:
  ```
  https://connect-call-3zfappl6z-mohd-danishs-projects-8fb6a537.vercel.app
  ```
- **Endpoints**:
  - `GET /health` — Health check returning service status (`HTTP 200`).
  - `POST /api/agora/token` — Authenticated token generation endpoint (`Authorization: Bearer <Firebase ID token>`).

---

## Development

To set up and run ConnectCall locally for development:

### 1. Prerequisites
- **Flutter SDK**: `^3.41.1` (channel stable)
- **Node.js**: `v20.x` or `v22.x`
- **Android SDK**: Platform 34+, NDK

### 2. Backend Local Setup
```bash
cd backend
npm install

# Copy example environment file
cp .env.example .env

# Configure backend/.env with your development credentials:
# AGORA_APP_ID=your_agora_app_id
# AGORA_APP_CERTIFICATE=your_agora_app_certificate
# FIREBASE_PROJECT_ID=connectcall-01

# Run tests
npm test

# Start local backend server
npm start
```

### 3. Flutter Client Setup
```bash
# Return to root
cd ..

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run on an emulator or connected device
flutter run
```

---

## Security

- **Never commit `.env` files** to Git.
- **Never expose or commit `AGORA_APP_CERTIFICATE`**.
- **Never expose or commit Firebase Admin private keys** or service-account JSON files.
- **Never commit Android Keystore / signing key files**.
- All backend secrets must reside exclusively in secure environment variables on the backend hosting platform (Vercel).
- Client configuration files (`lib/firebase_options.dart` and `android/app/google-services.json`) contain standard public client identifiers required by Firebase client SDKs.

---

## AI Disclosure

In accordance with internship requirements, AI-assisted development tools were utilized during the development and hardening of ConnectCall:
- **ChatGPT**: Used for initial architectural design, state machine planning, and scenario modeling.
- **Google Antigravity**: Used for pair-programming, codebase refactoring, security auditing, and automated testing.

All architecture, business logic, Agora RTC streaming integrations, and security rules were verified, tested, and validated.
