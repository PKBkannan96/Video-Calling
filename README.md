# Real-time Video Calling Flutter Application

This is a Flutter application demonstrating a 1:1 real-time video calling experience using the Amazon Chime SDK and a meeting coordinator backend API.

---

## Architecture Overview

The project is structured with a clean separation of concerns:

```
lib/
├── api/
│   └── chime_api.dart        # API integration layer (REST clients)
├── chime/
│   └── chime_service.dart    # Chime SDK bridge (native wrapper commands & event parsing)
├── logic/
│   └── meeting_provider.dart # Business logic & state management (Provider)
├── ui/
│   ├── home_screen.dart      # Landing view (meeting hosting/joining & permissions)
│   ├── meeting_screen.dart   # Call view (video panels, mute controls, collapsible log)
│   └── theme.dart            # Sleek dark-mode design tokens
└── main.dart                 # Application entry point & dependency injection
```

1. **API Layer (`chime_api.dart`)**: Interacts with the backend server via HTTP requests to allocate meeting resources and retrieve join tokens.
2. **Chime Layer (`chime_service.dart`)**: Integrates with the native Amazon Chime SDK wrapper (`eggnstone_amazon_chime`). It listens to the platform's EventChannel to catch state updates (tile additions, participants joining, etc.) and routes methods like start/stop video, mute, and tile binding.
3. **Business Logic Layer (`meeting_provider.dart`)**: Manages call states (idle, joining, connected, disconnected), stores active tile IDs, handles microphone/camera toggle logic, and populates the scrollable event activity log.
4. **UI Layer (`ui/*`)**: High-fidelity dark mode views displaying statuses, local and remote video frames, and real-time meeting events.

---

## State Management

This application uses the **Provider** package for state management. It provides a simple, clean, and highly reactive way to update the user interface based on changes in the meeting lifecycle:
- The UI listens to `MeetingProvider` for properties such as `status`, `localTileId`, `remoteTileId`, `isMicMuted`, `isCameraEnabled`, and `eventLogs`.
- Call controls in the UI trigger async actions in the provider, which interact with the Chime service and API client, automatically notifying listeners on state changes.

---

## Setup & Running Instructions

### Prerequisites
* Flutter SDK (version `^3.5.0` is configured).
* Android Studio and Android SDK installed.
* An **ARM64 Android Emulator** (default on Apple Silicon macOS) or a physical Android device connected via ADB. *(x86 Android emulators are not supported by the Chime SDK).*

### Step 1: Install Dependencies
Run the following command at the root of the project to fetch all required packages:
```bash
flutter pub get
```

### Step 2: Running the App
Start the app in debug mode on your connected emulator or device:
```bash
flutter run
```

---

## Assumptions
* **API Authentication**: The API key (`qxsm2peuW5ZiMz5Nq7DS`) provided in the Postman collection is valid and authorized to create and join meeting rooms.
* **1:1 Call Flow**: User A (Agent) hosts the meeting, copies the generated Meeting ID, and shares it with User B (Client/Agent) who enters the ID to join the same call.

---

## Known Limitations
* **iOS Support**: In the community-maintained `eggnstone_amazon_chime` package, iOS precompiled binaries (`AmazonChimeSDK.framework` and `AmazonChimeSDKMedia.framework`) are omitted from the pub.dev upload due to pub's 100MB file size limitation. Therefore, **iOS compilation will fail to link** unless the precompiled native binaries are manually linked in Xcode. The project is fully configured and optimized for **Android**.
* **Emulator Constraints**: The Chime SDK fails on older x86-based Android Emulators because the underlying native libraries are only built for ARM architectures. Please test using physical devices or ARM64 emulators.
* **1:1 Layout**: The UI viewport and state variables are tailored for 1:1 calling. If more than 2 participants join the meeting, only the latest remote participant's video tile will be displayed in the viewport.
