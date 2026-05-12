# ReadMe: A Persuasive Mobile App for Encouraging Reading Among Children

#### Fajuyigbe Lois: ADS2300108Y and Osabutey Precious: ADS2300174Y
#### Date: 10 April 2026

## Setup documentation

Choose ONE:
- Option 1 (fastest): install the APK and use the app.
- Option 2: do a full setup in your own Firebase project (you will not be added to the original Firebase project).

#### Option 1: Install the Android APK and use the app (fastest)

APK path (relative to the project root, after building):
- build/app/outputs/flutter-apk/app-release.apk

Steps:
1. Build the APK (skip this if the APK already exists): flutter build apk --release
2. Use the generated APK at: build/app/outputs/flutter-apk/app-release.apk
3. Copy it to an Android device and install it (you may need to allow “install unknown apps”).
4. Open the app and sign in or create an account.

#### Option 2: Full setup (new Firebase project)

Continue with the sections below to create your own Firebase project, connect the app, deploy Cloud Functions, and run the app.

## Table of contents
1. Requirements
2. Full setup (new Firebase project)
3. Backend (Cloud Functions) setup
4. Storage CORS setup (required for Web)
5. Running the application (development)
6. Building and deployment
7. Troubleshooting

## 1. Requirements

Software prerequisites:
- Flutter SDK 3.x
  - Verify: flutter --version
  - Check setup: flutter doctor

- Node.js 20+ (Cloud Functions requirement for this repository)
  - Verify: node --version

- Firebase CLI
  - Install: npm install -g firebase-tools
  - Verify: firebase --version

- FlutterFire CLI
  - Install: dart pub global activate flutterfire_cli
  - Verify: flutterfire --version

Optional (recommended for web and CORS):
- Google Cloud SDK (gcloud and gsutil)

Accounts:
- Firebase account (required only for Option 2)
- OpenAI account and API key (required only for Option 2)


## 2. Full setup (new Firebase project)

A) Create a Firebase project (Firebase Console)
Enable:
- Authentication (Email/Password)
- Firestore Database
- Storage
- Cloud Functions
- Hosting (optional)

B) Connect Flutter app to Firebase
1) firebase login
2) flutterfire configure
3) Select your new Firebase project and platforms

C) Verify configuration
- Confirm projectId and storageBucket in lib/firebase_options.dart


## 3. Backend (Cloud Functions) setup

1) Install dependencies
- cd functions
- npm install
- cd ..

2) Configure OpenAI API key (Functions Secrets)
- firebase functions:secrets:set OPENAI_KEY
- firebase functions:secrets:list

3) Deploy
- firebase deploy --only functions

4) Verify
- Check Firebase Console: Build -> Functions
- Use the health check endpoint shown in the Functions console


## 4. Storage CORS setup (required for Web)

This step is required for the web app to load PDFs/images from Firebase Storage without browser CORS errors.

1) Confirm cors.json exists in project root.
2) Install Google Cloud SDK.
3) gcloud auth login
4) gcloud config set project YOUR_PROJECT_ID
5) Apply CORS:
   - gsutil cors set cors.json gs://YOUR_STORAGE_BUCKET_NAME
6) Verify:
   - gsutil cors get gs://YOUR_STORAGE_BUCKET_NAME


## 5. Running the application (development)

Web:
- flutter run -d chrome

Android/iOS:
- flutter devices
- flutter run -d <device-id>

Windows:
- flutter run -d windows


## 6. Building and deployment

Build:
- Android APK: flutter build apk --release
- Web: flutter build web --release
- Windows: flutter build windows --release

Deploy Web Hosting (optional):
1) flutter build web --release
2) firebase deploy --only hosting


## 7. Troubleshooting

Firebase initialization errors:
- flutter clean
- flutter pub get
- flutterfire configure

Cloud Functions issues:
- firebase use
- firebase functions:secrets:list
- firebase deploy --only functions

Web CORS errors:
- gsutil cors set cors.json gs://YOUR_STORAGE_BUCKET_NAME

PDF does not load:
- Confirm pdfUrl exists in the Firestore book document
- Confirm Storage object exists and is readable
- For web, confirm CORS has been applied
