# Cosmic — Android Chat, Photo Sharing, Voice & Video Calling App

> **"Connect beyond distance."**
> Package Name: `com.cosmic.chat`

Cosmic is a production-ready, high-performance Android communication application built with Flutter, Dart, Firebase, and WebRTC. It delivers a modern, minimal, mobile-first experience featuring real-time private messaging, photo & video sharing, interactive voice messages, and direct 1-to-1 WebRTC voice and video calling.

---

## 🌟 Key Features

### 1. Direct Voice & Video Calling (WebRTC)
* **Zero User-Facing Room IDs:** Users never see, generate, copy, or enter Room IDs.
* **Direct Experience:** Tap 📞 or 🎥 directly inside any conversation or contact card. Cosmic automatically creates and manages internal session tokens and handles WebRTC signaling via Cloud Firestore.
* **Full-Screen Incoming Call UI:** Displays caller avatar, caller name, call type with pulsing visual indicators, and Accept / Decline controls.
* **Active Call Interface:**
  * **Voice Calls:** Contact avatar with speaking pulse, call duration timer, mute/unmute microphone, speakerphone toggle, and red end-call button.
  * **Video Calls:** Fullscreen remote video stream (`RTCVideoView`), draggable picture-in-picture floating local preview (`RTCVideoView`), front/back camera switch, camera on/off, microphone mute, and speakerphone.
* **Reliability:** Timeout handling, auto-disconnect on call termination, error recovery, and status tracking (`calling`, `ringing`, `accepted`, `connected`, `ended`, `rejected`, `missed`).

### 2. Real-time One-to-One Chat
* **Real-time Firestore stream** with ordered message delivery.
* **Rich message types:**
  * Text messages with emoji support
  * Photo sharing (gallery or camera capture, upload progress, pinch-to-zoom fullscreen viewer, and save)
  * Video sharing (gallery or recording, inline video preview with play button, fullscreen playback with timeline)
  * Voice notes (press-and-hold to record with live timer, slide to cancel, inline audio player with play/pause and progress scrubbing)
* **Message Receipts:** Sent, Delivered, and Seen double-check ticks.
* **Replies:** Swipe/tap to reply with quote banner above composer and inside bubbles.
* **Message Deletion:** Delete own messages with confirmation.
* **Typing Indicator:** Real-time debounced "Rahul is typing..." indicator.
* **Presence:** Online status and formatted "Last seen at..." timestamps.

### 3. Authentication & Profiles
* Email and Password login and registration.
* Phone number + 6-digit SMS OTP authentication.
* Forgot password email reset.
* Duplicate username prevention during registration.
* Profile customization: Profile photo upload, display name, bio, and phone number.

### 4. Contacts & Discovery
* Global user discovery by `@username` or display name.
* Add/Remove contacts.
* Block/Unblock users with dedicated privacy settings.
* One-tap actions: Message, Direct Voice Call, Direct Video Call.

### 5. Call History
* Detailed call logs (Incoming, Outgoing, Missed).
* Call type indicator (📞 Voice or 🎥 Video).
* Call duration and formatted timestamps.
* One-tap callback functionality.

---

## 🏗️ Architecture & Project Structure

The project follows a clean, modular architecture separating UI, State Management, Repositories, Services, and Models:

```text
lib/
├── main.dart                          # Application entry point, system styling, and service init
├── app/
│   ├── app.dart                       # MultiProvider setup & MaterialApp configuration
│   ├── routes.dart                    # Centralized route definitions
│   └── theme.dart                     # Cosmic dark space theme & light mode definitions
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Cosmic color palette, nebula gradients
│   │   └── app_constants.dart         # Firestore collections, WebRTC STUN servers, timeouts
│   ├── errors/
│   │   └── app_exception.dart         # Typed exceptions (Auth, Network, Call, Storage)
│   └── utils/
│       ├── date_formatter.dart        # Chat list time, message time, call duration formatter
│       └── validators.dart            # Form input validation (username, email, password, phone)
├── models/
│   ├── user_model.dart                # User profile (uid, username, displayName, bio, isOnline)
│   ├── message_model.dart             # Message payload (text, image, video, audio, replies)
│   ├── chat_model.dart                # Conversation tracking (participants, lastMessage, unreads)
│   ├── call_model.dart                # Internal call document (callId, SDP offer/answer, status)
│   └── contact_model.dart             # Contact and blocked user models
├── services/
│   ├── webrtc_service.dart            # WebRTC RTCPeerConnection, MediaStreams, renderers, ICE
│   ├── presence_service.dart          # App lifecycle online/lastSeen & typing indicators
│   └── notification_service.dart      # FCM & flutter_local_notifications background handlers
├── repositories/
│   ├── auth_repository.dart           # Firebase Auth (email, phone OTP, session state)
│   ├── chat_repository.dart           # Firestore messages stream, batch send, seen updates
│   ├── call_repository.dart           # Direct call initiation, incoming listener, call history
│   ├── user_repository.dart           # User search, contacts, profile updates, blocking
│   └── storage_repository.dart        # Firebase Storage uploads (profiles, photos, videos, audio)
├── widgets/
│   ├── avatar_widget.dart             # Avatar with cached network image & online badge
│   ├── cosmic_button.dart             # Gradient Cosmic action button with loading states
│   ├── cosmic_text_field.dart         # Stylized dark text field with obscure toggle
│   ├── audio_bubble_player.dart       # Voice message player with seek slider
│   └── video_bubble_player.dart       # Video preview bubble with thumbnail & play overlay
├── features/
│   ├── splash/                        # Animated Cosmic glowing logo & auth routing
│   ├── auth/                          # Login, Register, Forgot Password, Phone Auth
│   ├── home/                          # Bottom navigation bar (Chats, Calls, Contacts, Profile)
│   ├── chats/                         # Conversation list, Chat screen, Fullscreen media viewer
│   ├── calls/                         # Calls tab, Incoming call screen, Active voice/video screens
│   ├── contacts/                      # Contacts list and User search
│   └── profile/                       # User profile, Edit profile, Blocked users, Settings
└── test/
    ├── models_and_validation_test.dart# Tests for models, validators, and serialization
```

---

## 🔒 Security Rules

### Cloud Firestore Rules (`firestore.rules`)
* **Users:** Any authenticated user can read public profiles; users can only update their own profile and private contacts/blocked subcollections.
* **Chats:** Only participants in `participants` array can read or write messages in that conversation.
* **Calls:** Only the `callerId` and `receiverId` have access to the signaling documents and ICE candidates.
* **Call Logs:** Strictly owned by the respective user (`call_logs/{userId}/logs/{logId}`).

### Firebase Storage Rules (`storage.rules`)
* **Profile Photos:** Only the user can upload to `/users/{userId}/profile/` (max 10MB, image MIME type only).
* **Chat Attachments:** Authenticated users upload to `/chats/{chatId}/` with a 50MB limit per file.

---

## 🚀 Getting Started

### 1. Prerequisites
* Flutter SDK (3.2.0 or higher)
* Android SDK (API 24 or higher)
* Firebase Project with Authentication, Firestore, and Storage enabled.

### 2. Firebase Setup
1. Add your Android app with package name `com.cosmic.chat` in the Firebase Console.
2. Download `google-services.json` and place it in `android/app/`.
3. Enable Email/Password and Phone Authentication in Firebase Authentication.
4. Deploy Firestore rules and Storage rules:
   ```bash
   firebase deploy --only firestore:rules,storage:rules
   ```

### 3. Build & Run
To run the app on an Android device or emulator:
```bash
flutter pub get
flutter run
```

To build a release APK:
```bash
flutter build apk --release
```

To build an Android App Bundle (AAB):
```bash
flutter build appbundle --release
```

---

## 🧪 Testing

Run automated tests:
```bash
flutter test
```
