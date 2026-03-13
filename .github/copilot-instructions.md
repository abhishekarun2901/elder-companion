# AI Coding Guidelines for Mitra - Elderly Companion App

## Project Overview
Mitra is a Flutter-based cross-platform app providing AI companionship for elderly users. It features Firebase backend integration, role-based access (Elder/Caregiver), and services like voice interaction, notifications, and health tracking.

## Architecture
- **Frontend**: Flutter with Material Design, role-based navigation (Elder vs Caregiver flows)
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Messaging)
- **Key Components**:
  - `lib/`: Shared UI screens and business logic
  - `functions/`: Node.js Cloud Functions for AI memory storage and processing
  - Services in `lib/services/`: Notification, voice, location, push notifications
- **Data Flow**: Firebase Auth → Role selection → Profile check → Feature screens

## Critical Workflows
- **Authentication**: Phone OTP via Firebase Auth, role stored in SharedPreferences
- **Build & Deploy**:
  - `flutter pub get` for dependencies
  - `flutter run` for local development
  - `firebase deploy` for backend functions
- **Notifications**: Local notifications with TTS, push via Firebase Messaging
- **Voice Integration**: Speech-to-text and TTS using `speech_to_text` and `flutter_tts`

## Code Patterns
- **State Management**: StreamBuilder for auth state, setState for local UI
- **Firebase Usage**: Firestore collections like `users/{uid}/memory_entries` for conversation history
- **Error Handling**: Try-catch with debugPrint, platform-safe Firebase init (web vs mobile)
- **Navigation**: MaterialPageRoute with role-based routing, GlobalKey navigator for notifications
- **Services**: Singleton pattern (e.g., `NotificationService._instance`), async init methods

## Examples
- **Role Routing**: Check `SharedPreferences.getString('user_role')` to route to Elder (`ProfileCheckWrapper`) or Caregiver (`CaregiverDashboard`)
- **Firebase Calls**: Use `cloud_functions` for `storeConversationMemory` to persist chat history
- **Notifications**: Schedule with `flutter_local_notifications` and `timezone`, include TTS via `flutterTts.speak()`
- **Voice Commands**: `VoiceService` listens continuously, integrates with chat and reminders

## Conventions
- **Imports**: Relative paths within lib/, absolute for external packages
- **Naming**: CamelCase for classes, snake_case for files (e.g., `home_screen.dart`)
- **Dependencies**: Pin versions in `pubspec.yaml`, use `flutter_dotenv` for non-web secrets
- **Platform Checks**: `kIsWeb` for web-specific logic, handle permissions with `permission_handler`

## Key Files
- `main.dart`: App entry, Firebase init, role selection
- `auth_wrapper.dart`: Auth state management with role routing
- `home_screen.dart`: Elder feature grid with voice integration
- `functions/index.js`: Cloud functions for memory management
- `firestore.rules`: Security rules for user-scoped data</content>
<parameter name="filePath">/home/abhishekarunkumar/Library/elder-companion/.github/copilot-instructions.md