# ConnectCall — Architecture & System Design

This document provides a concise, interview-ready technical overview of ConnectCall's end-to-end architecture, state machines, calling lifecycle, and security controls.

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Client Application               │
│                                                             │
│   Screens (Splash, Onboarding, Auth, Home, Contacts, Call)   │
│                               ▲                             │
│   Riverpod State Notifiers (Auth, CallController, History)   │
│                               ▲                             │
│   Service Layer (Calling, Signaling, History, Permissions)  │
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
│ • Input Validation           │  │ • Cloud Firestore DB      │
│ • Secure Agora RTC Token     │  │ • Security Rules v2       │
│   Builder (Cert in .env)     │  │                           │
└──────────────┬───────────────┘  └───────────────────────────┘
               │
          Channel Token
               ▼
┌──────────────────────────────┐
│       Agora RTC Engine       │
│ • Low-Latency Audio Stream   │
│ • 720p HD Video & Preview    │
│ • Dynamic Quality & Bitrate  │
└──────────────────────────────┘
```

---

## 2. Directory & Component Breakdown

- **`lib/core/`**
  - `config/`: Application configuration and backend URLs (`app_config.dart`).
  - `constants/`: Design tokens, 8px spacing, light/dark color tokens (`app_colors.dart`, `app_text_styles.dart`).
  - `services/`: Low-level services for Agora RTC engine (`agora_service.dart`), token HTTP client (`agora_token_client.dart`), network status (`network_service.dart`), and OS runtime permissions (`permission_service.dart`).
- **`lib/models/`**
  - `user_model.dart`: User profile, presence status, and contact serialization.
  - `call_model.dart`: 1-to-1 call document schema with status enums and timestamps.
  - `call_session.dart`: In-memory immutable UI call state (audio/video, mute, speaker, camera, duration).
- **`lib/providers/`**
  - `auth_provider.dart`: Authentication state notifier, user persistence, error mapping.
  - `call_provider.dart`: Core call controller, active stream listeners, incoming call watchers.
  - `call_history_provider.dart`: Call log state notifier with local-first and Firestore sync.
  - `user_provider.dart`: Contacts and presence streams.
- **`lib/screens/`**
  - `splash/`: Custom wave animations, brand icon glow, startup routing.
  - `onboarding/`: 3-screen PageView with dot indicators and local completion flag.
  - `auth/`: Login and Register screens with validation and loading states.
  - `home/`: Dashboard, quick action chips, active call banners, bottom navigation tabs.
  - `contacts/`: Real-time contact list, search query filtering, direct call buttons.
  - `call/`: Dedicated screens for incoming calls, 1-to-1 audio calling, and HD video calling.
  - `history/`: Call history list with direction indicators, duration, and status tags.
  - `profile/`: User details, 3-option theme switcher dialog, sign-out action.

---

## 3. Calling Lifecycle & State Machine

```
              ┌─────────┐
              │  Idle   │
              └────┬────┘
                   │ startCall()
                   ▼
              ┌─────────┐
              │ Calling │
              └────┬────┘
                   │ doc created (status: ringing)
                   ▼
              ┌─────────┐
        ┌─────┤ Ringing ├─────┐
        │     └────┬────┘     │
  reject│          │accept    │ timeout (30s)
        ▼          ▼          ▼
   ┌────────┐ ┌──────────┐ ┌────────┐
   │Rejected│ │Accepted /│ │ Missed │
   └────────┘ │Connecting│ └────────┘
                   │
                   │ onUserJoined (Agora)
                   ▼
              ┌─────────┐
              │ In Call │
              └────┬────┘
                   │ endCall()
                   ▼
              ┌─────────┐
              │  Ended  │
              └─────────┘
```

### State Consistency Rules
1. **Invalid Transition Prevention**:
   - `Ended` cannot transition to `Connected`.
   - `Rejected` cannot transition to `In Call`.
   - `Calling` cannot create duplicate calls.
2. **Terminal Lock**: Once a call reaches `ended`, `rejected`, `missed`, or `failed`, subsequent updates to non-terminal states are rejected.

---

## 4. Security Architecture

### Agora Token Generation
- **Client Security**: The Flutter application **NEVER** has access to the `AGORA_APP_CERTIFICATE`.
- **Backend Role**: All tokens are generated on the Node.js backend using `RtcTokenBuilder.buildTokenWithUid` with a 24-hour expiration window.
- **Authorization**: The `/api/agora/token` endpoint requires a valid Firebase ID token in the `Authorization: Bearer <token>` header, verified with Firebase Admin SDK.

### Firestore Security Rules
- **Users**: Authenticated users can read contact profiles; users can only update their own profile document. Deletes are prohibited.
- **Calls**: Read/update access is restricted strictly to call participants (`callerId == auth.uid || receiverId == auth.uid`). Status transitions must follow allowed state progression.
- **History**: Only call participants can read or create history entries for their sessions.

---

## 5. Call History & Idempotency

- **Rule**: Exactly **ONE** history record is generated per call.
- **Deduplication**: `CallingService` tracks active call IDs in a local Set `_recordedCallIds`. Even if both caller and receiver trigger termination events simultaneously, the record is committed idempotently via Firestore and locally cached via `SharedPreferences`.
