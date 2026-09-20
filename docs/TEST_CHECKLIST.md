# ConnectCall — QA & Verification Checklist

This document tracks verified testing flows across Flutter client features, Firebase Authentication, Cloud Firestore Signaling, and Agora RTC Engine calling.

---

## 1. Authentication & Onboarding
- [x] **First Launch Onboarding**: Fresh install shows 3-step PageView with dot indicators and "Get Started".
- [x] **Onboarding Skip**: Skipping or completing saves `connectcall_onboarding_completed` locally and routes to Login.
- [x] **Subsequent Launch Routing**: Returning user automatically skips onboarding.
- [x] **User Registration**: Form validation rejects invalid emails or empty passwords with exact error strings.
- [x] **User Sign In**: Authenticates via Firebase Auth; shows loading state and disables CTA to prevent double-submit.
- [x] **Demo User 1-Tap Sign In**: Quick chips populate and authenticate instantly for fast QA testing.
- [x] **Sign Out**: Clears session, resets auth state, and returns to LoginScreen.
- [x] **Restart Auth Preservation**: Authenticated user directly opens HomeScreen on app restart.

---

## 2. User Discovery & Contacts
- [x] **Contacts Loading**: Fetches real-time contact profiles from Cloud Firestore with local cache fallback.
- [x] **Real-time Presence**: Online/offline indicators display accurately based on timestamp or `isOnline` flag.
- [x] **Search Contacts**: Real-time filtering by name, email, or phone number.
- [x] **Empty State**: Friendly illustration and guidance shown when search query yields no results.

---

## 3. 1-to-1 Audio Calling
- [x] **Outgoing Audio Call**: Initializes session, creates Firestore call document (`ringing`), fetches token, and joins Agora channel.
- [x] **Incoming Audio Call**: Real-time Firestore stream triggers incoming call screen for receiver.
- [x] **Accept Audio Call**: Atomic Firestore transaction marks call `accepted` and joins Agora channel.
- [x] **Microphone Mute/Unmute**: Real-time audio track muting via `agoraService.muteLocalAudio`.
- [x] **Speakerphone Toggle**: Routes audio output between device speaker and earpiece.
- [x] **Call Duration**: Dynamic elapsed timer starts upon `connected` and updates once per second.
- [x] **Call Rejection**: Receiver declines call; caller updates state, cleans up media, and exits.
- [x] **Ringing Timeout (Missed)**: 30-second timer transitions unaccepted call to `missed` status safely.
- [x] **End Call**: Either party can end call; cleans up media, updates Firestore to `ended`, and commits history.

---

## 4. 1-to-1 Video Calling
- [x] **Outgoing Video Call**: Initializes camera hardware, sets video encoder configuration (720p), creates call doc, joins channel.
- [x] **Local Video Preview**: Renders local camera view smoothly in corner PIP view.
- [x] **Remote Video Rendering**: Automatically attaches remote video canvas upon `onUserJoined`.
- [x] **Camera Toggle (On/Off)**: Disables local video publishing and shows camera-off placeholder.
- [x] **Camera Switching (Front/Rear)**: Swaps between front and back camera lenses seamlessly.
- [x] **Remote Video Mute Notification**: UI updates when remote peer turns off their camera.
- [x] **End Video Call**: Tears down video tracks, releases Agora engine, and records duration.

---

## 5. Call History & Persistence
- [x] **Idempotent Record Creation**: Exactly one call history entry created per call session.
- [x] **Relative Call Direction**: Correctly evaluates incoming vs outgoing based on viewer's ID.
- [x] **Accurate Status Representation**: Differentiates `Completed`, `Missed`, `Rejected`, and `Failed`.
- [x] **Formatted Timestamps**: Displays relative human-friendly dates (Today at HH:mm, Yesterday, etc.).

---

## 6. Permissions & Device Hardening
- [x] **Microphone Permission**: Checked and requested at runtime before audio or video call starts.
- [x] **Camera Permission**: Checked and requested before video call begins.
- [x] **Permission Denied Handling**: Clean, actionable error message displayed without app crashing.
- [x] **Permanently Denied Handling**: Direct prompt offering to open App Settings.

---

## 7. Network Resilience & Error Recovery
- [x] **Pre-flight Network Check**: Call start blocked with clear message if device is offline.
- [x] **Mid-call Disconnect Detection**: Reconnecting state with 25-second countdown timer.
- [x] **Token Privilege Expiration**: Dynamic token renewal via backend before RTC token expires.
- [x] **Backend Failure Handling**: Graceful error message if token server is unreachable.

---

## 8. Dark Mode & Accessibility
- [x] **Theme Switcher**: 3 options (System Default, Light, Dark) available in Profile and persisted.
- [x] **Color Contrast Audit**: All surfaces, cards, text, and dividers adhere to the design system palette.
- [x] **Semantic Labels**: Explicit screen-reader labels on all call action buttons.
- [x] **Touch Target Sizes**: All interactive elements maintain a minimum 48px target size.
