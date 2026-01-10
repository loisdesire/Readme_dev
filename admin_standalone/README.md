# ReadMe Admin Portal (Standalone)

A standalone Flutter web app for managing books, users, and content in the ReadMe platform.

## Prerequisites

- Flutter SDK (>=3.1.0)
- Firebase project configured

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run locally:
   ```bash
   flutter run -d chrome
   ```

3. Build for production:
   ```bash
   flutter build web
   ```

## Features

- Book upload and management
- User management
- Cloud Functions triggers (AI tagging, recommendations)
- Analytics dashboard
- Firestore data viewer

## Firebase Configuration

This app uses the readmev2 Firebase project. The configuration is already set in `lib/firebase_options.dart`.

## Deployment

Deploy to Firebase Hosting:
```bash
firebase deploy --only hosting
```

---

Part of the ReadMe AI-Powered Children's Reading App ecosystem.
