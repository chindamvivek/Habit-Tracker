# 🏃 Habit Tracker

A Flutter app to build, track, and gamify your daily habits — powered by Firebase and Gemini AI.

## ✨ Features

- 📅 Daily habit tracking with calendar view
- 🔥 Streak tracking and gamification (XP, badges, levels)
- 🤖 AI-powered habit plans via Gemini API
- 📊 Analytics and progress charts
- 🔐 Firebase Authentication (login/signup)
- ☁️ Cloud Firestore for real-time data sync
- 🌙 Dark / Light theme support

---

## ⚙️ Setup Instructions (For Contributors / Friends)

### 1. Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.10+)
- [Android Studio](https://developer.android.com/studio) + Android SDK
- [Git](https://git-scm.com/downloads)

### 2. Clone the Repository

```bash
git clone https://github.com/chindamvivek/Habit-Tracker.git
cd Habit-Tracker
```

### 3. Add Firebase Config Files ⚠️

> **These two files are NOT included in the repository for security reasons.**
> You must get them directly from the project owner (via WhatsApp/email).

Place the files at the exact paths below:

| File to Add | Where to Place It |
|---|---|
| `google-services.json` | `android/app/google-services.json` |
| `firebase_options.dart` | `lib/firebase_options.dart` |

**Template files** (with placeholder values) are available for reference:
- `android/app/google-services.json.example`
- `lib/firebase_options.dart.example`

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Set Up Android SDK Path

Create the file `android/local.properties` (if it doesn't exist) with:

```properties
sdk.dir=C:\Users\YOUR_USERNAME\AppData\Local\Android\sdk
flutter.sdk=C:\flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

> Replace `YOUR_USERNAME` with your actual Windows username, and adjust `flutter.sdk` to where Flutter is installed on your machine.

### 6. Run the App

Connect an Android emulator or physical device, then:

```bash
flutter run
```

### 7. Set Up Gemini API Key (In-App)

The Gemini AI key is stored **securely on-device** and is NOT in the codebase.

- Get your own free API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
- Open the app → go to **Profile / Settings** → enter your Gemini API key

---

## 🛠️ Common Fixes

| Problem | Fix |
|---|---|
| `flutter: command not found` | Add Flutter to your system PATH |
| `SDK not found` | Set correct `sdk.dir` in `android/local.properties` |
| Firebase error on launch | Make sure `google-services.json` is in `android/app/` |
| Build fails | Run `flutter clean` then `flutter pub get` |
| Any other issue | Run `flutter doctor` and fix all reported issues |

---

## 📦 Tech Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI framework |
| Firebase Auth | User authentication |
| Cloud Firestore | Real-time database |
| Gemini AI | AI habit plan generation |
| fl_chart | Analytics charts |
| provider | State management |
| flutter_secure_storage | Secure API key storage |
