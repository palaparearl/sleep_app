# PahingApp — Sleep Diary

A Flutter-based sleep health management app that helps users track sleep patterns, identify factors affecting sleep quality, and connect with sleep medicine specialists.

## Features

- **Sleep Diary** — Log sleep and wake times on a calendar-based interface
- **Sleep Analytics** — Visualize sleep patterns with charts, statistics, and AI-powered insights
- **Sleep Factor Tracking** — Record coffee, medicine, alcohol intake, and notes that may impact sleep
- **Can't Sleep Mode** — Access relaxation music, sleep stories, meditation content, and AI chat support
- **Doctor Finder** — Browse a directory of sleep medicine specialists via NowServing.ph
- **Voice & Video Calls** — WebRTC-based audio/video calling for consultations

## Tech Stack

- **Flutter** (Dart SDK ^3.10.7)
- **Firebase** (Cloud Firestore)
- **flutter_webrtc** — Video/audio calls
- **fl_chart** — Analytics visualization
- **just_audio** — Audio playback
- **table_calendar** — Calendar UI

## Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd sleep_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Copy the example env file and fill in your Firebase credentials:
   ```bash
   cp .env.example .env
   ```

   Populate `.env` with your Firebase project values (see `.env.example` for required keys).

4. **Android setup**

   Place your `google-services.json` in `android/app/` (this file is gitignored).

5. **Run the app**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

6. **Build a release APK**
   ```bash
   flutter build apk --release --dart-define-from-file=.env
   ```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── app.dart               # MaterialApp config and theming
├── firebase_options.dart  # Firebase config (reads from env)
├── data/                  # Local data layer
├── models/                # Data models (SleepRecord, CoffeeRecord, etc.)
├── screens/               # App screens (Home, Dashboard, Can't Sleep, Doctors, Call)
├── services/              # Business logic (Chat, Call, Firebase services)
├── utils/                 # Utilities and helpers
└── widgets/               # Reusable UI components
```
