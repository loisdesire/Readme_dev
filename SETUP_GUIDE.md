# 🚀 ReadMe App - Complete Setup Guide

**Last Updated:** December 2025
**Project:** ReadMe - AI-Powered Children's Reading App
**Firebase Project ID:** readme-40267

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Firebase Configuration](#firebase-configuration)
5. [Environment Variables](#environment-variables)
6. [Cloud Functions Setup](#cloud-functions-setup)
7. [Storage CORS Configuration](#storage-cors-configuration)
8. [Running the App](#running-the-app)
9. [Deployment](#deployment)
10. [Moving to New Location/Repo](#moving-to-new-locationrepo)
11. [Troubleshooting](#troubleshooting)

---

## 🎯 Quick Start

```bash
# Clone repository
git clone <your-repo-url>
cd Readme_dev

# Install Flutter dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Install Cloud Functions dependencies
cd functions
npm install
cd ..

# Run the app
flutter run
```

---

## 📦 Prerequisites

### Required Tools:

- **Flutter SDK** (3.0+)
  ```bash
  flutter --version
  ```

- **Node.js** (16+) & npm
  ```bash
  node --version
  npm --version
  ```

- **Firebase CLI**
  ```bash
  npm install -g firebase-tools
  firebase --version
  ```

- **FlutterFire CLI**
  ```bash
  dart pub global activate flutterfire_cli
  ```

### Required Accounts:

- Firebase account (https://console.firebase.google.com)
- OpenAI API account (https://platform.openai.com)
- Git/GitHub account

---

## 🛠️ Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd Readme_dev
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
flutter doctor
```

Fix any issues reported by `flutter doctor`.

### 3. Install Tools Dependencies

```bash
cd tools
npm install
cd ..
```

---

## 🔥 Firebase Configuration

### Project Details:

- **Project ID:** `readme-40267`
- **Project Name:** ReadMe App
- **Region:** us-central1
- **Storage Bucket:** `readme-40267.firebasestorage.app`
- **Auth Domain:** `readme-40267.firebaseapp.com`

### Configure Firebase for Your Project:

#### Option A: Use Existing Firebase Project

```bash
# Login to Firebase
firebase login

# Configure FlutterFire (select existing project)
flutterfire configure
```

This generates `lib/firebase_options.dart` with your credentials.

#### Option B: Create New Firebase Project

1. Go to https://console.firebase.google.com
2. Create new project
3. Enable these services:
   - **Authentication** (Email/Password)
   - **Cloud Firestore** (Database)
   - **Cloud Storage** (File storage)
   - **Cloud Functions**
4. Run FlutterFire configuration:
   ```bash
   flutterfire configure
   ```

### Firebase Collections Structure:

```
📂 books/                      ← Book catalog
   ├─ title: string
   ├─ author: string
   ├─ pdfUrl: string
   ├─ traits: array
   ├─ tags: array
   ├─ ageRating: string
   └─ needsTagging: boolean

📂 users/                      ← User profiles
   ├─ username: string
   ├─ email: string
   ├─ personalityTraits: array
   └─ aiRecommendations: array

📂 reading_progress/           ← Reading tracking
   ├─ userId: string
   ├─ bookId: string
   ├─ currentPage: number
   ├─ progressPercentage: number
   └─ lastReadAt: timestamp

📂 reading_sessions/           ← Session tracking
   ├─ userId: string
   ├─ bookId: string
   ├─ sessionDurationSeconds: number
   └─ createdAt: timestamp

📂 user_achievements/          ← Gamification
   ├─ userId: string
   ├─ achievementId: string
   ├─ unlockedAt: timestamp
   └─ popupShown: boolean

📂 quiz_analytics/             ← Personality quiz
   ├─ userId: string
   ├─ traitScores: map
   └─ completedAt: timestamp

📂 book_interactions/          ← Favorites/bookmarks
   ├─ userId: string
   ├─ bookId: string
   ├─ type: string (favorite/bookmark)
   └─ timestamp: timestamp
```

### Firebase Security Rules:

**Firestore Rules** (firestore.rules):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Books are readable by all, writable by admins only
    match /books/{bookId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    // Reading progress - user can only access their own
    match /reading_progress/{progressId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Reading sessions - user can only access their own
    match /reading_sessions/{sessionId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // User achievements - user can only access their own
    match /user_achievements/{achievementId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Quiz analytics - user can only access their own
    match /quiz_analytics/{quizId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Book interactions - user can only access their own
    match /book_interactions/{interactionId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

**Storage Rules** (storage.rules):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // PDFs and covers are readable by authenticated users
    match /pdfs/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

    match /covers/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
```

---

## 🔐 Environment Variables

### For Cloud Functions:

Set OpenAI API key in Firebase:

```bash
firebase functions:config:set openai.key="your-openai-api-key-here"
```

View current config:
```bash
firebase functions:config:get
```

### For Local Testing (Optional):

Create `functions/.env` (DO NOT commit):
```env
OPENAI_KEY=your-openai-api-key-here
```

Add to `.gitignore`:
```
functions/.env
functions/serviceAccountKey.json
tools/.env
tools/serviceAccountKey.json
```

---

## ☁️ Cloud Functions Setup

### Functions Overview:

Located in `/functions/index.js`:

1. **flagNewBookForTagging** - Triggers when new book added
2. **checkUpdatedBookForTagging** - Re-flags books when PDF changes
3. **dailyAiTagging** - Runs daily at 2 AM UTC
4. **dailyAiRecommendations** - Runs daily at 3 AM UTC
5. **triggerAiTagging** - Manual HTTP endpoint
6. **triggerAiRecommendations** - Manual HTTP endpoint
7. **generateBookQuiz** - Callable function to generate quiz questions for books
8. **healthCheck** - Status check endpoint

### Deploy Functions:

```bash
cd functions
npm install
cd ..

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:triggerAiTagging
```

### Function URLs:

After deployment, you'll get URLs like:
```
https://triggeraitagging-y2edld2faq-uc.a.run.app
https://triggerairecommendations-y2edld2faq-uc.a.run.app
https://healthcheck-y2edld2faq-uc.a.run.app
```

### Test Functions:

```bash
# Health check
curl https://healthcheck-y2edld2faq-uc.a.run.app

# Trigger AI tagging
curl -X POST https://triggeraitagging-y2edld2faq-uc.a.run.app

# Trigger recommendations
curl -X POST https://triggerairecommendations-y2edld2faq-uc.a.run.app
```

---

## 📦 Storage CORS Configuration

### Why CORS is Needed:

Firebase Storage requires CORS configuration to allow web/Flutter access to PDFs and images.

### Apply CORS Configuration:

1. **Install Google Cloud SDK:**
   ```bash
   # macOS
   brew install google-cloud-sdk

   # Windows/Linux
   # Download from https://cloud.google.com/sdk/docs/install
   ```

2. **Authenticate:**
   ```bash
   gcloud auth login
   gcloud config set project readme-40267
   ```

3. **Apply CORS config:**
   ```bash
   gsutil cors set cors.json gs://readme-40267.firebasestorage.app
   ```

### CORS Configuration File:

`cors.json` (already in project root):
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600,
    "responseHeader": ["Content-Type", "Content-Length", "Content-Range"]
  }
]
```

### Verify CORS:

```bash
gsutil cors get gs://readme-40267.firebasestorage.app
```

---

## 🏃 Running the App

### Development:

```bash
# Run on Chrome (fastest for development)
flutter run -d chrome

# Run on physical device
flutter devices
flutter run -d <device-id>

# Run with hot reload
flutter run
# Press 'r' to hot reload
# Press 'R' to hot restart
```

### Build for Production:

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Desktop
flutter build macos --release  # macOS
flutter build windows --release  # Windows
flutter build linux --release  # Linux
```

---

## 🚀 Deployment

### Web Deployment (Firebase Hosting):

```bash
# Build web app
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Mobile App Deployment:

**Android:**
```bash
flutter build apk --release
# Upload to Google Play Console
```

**iOS:**
```bash
flutter build ios --release
# Open Xcode and archive for App Store
```

---

## 📦 Moving to New Location/Repo

### What Needs Reconfiguring:

#### 🔴 MUST Reconfigure:

1. **Firebase Project Connection**
   ```bash
   flutterfire configure
   ```
   This regenerates `lib/firebase_options.dart` with your Firebase credentials.

2. **Firebase Storage CORS**
   ```bash
   gsutil cors set cors.json gs://your-new-bucket-name
   ```

3. **Firebase Cloud Functions**
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

4. **OpenAI API Key**
   ```bash
   firebase functions:config:set openai.key="your-key"
   ```

#### 🟡 Check These:

5. **Git Configuration**
   ```bash
   git init
   git remote add origin <new-repo-url>
   ```

6. **Flutter Dependencies**
   ```bash
   flutter clean
   flutter pub get
   ```

7. **Platform-Specific Files** (if they exist)
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - Download fresh from Firebase Console → Project Settings

#### 🟢 Should Work As-Is:

- ✅ All Dart code
- ✅ Assets (illustrations, SVGs)
- ✅ `pubspec.yaml` dependencies
- ✅ Firebase rules configuration files
- ✅ Tools scripts
- ✅ CORS configuration file

### Quick Setup Script:

```bash
# After copying to new location:
flutter pub get
flutterfire configure  # Select your Firebase project
cd functions && npm install && cd ..
firebase functions:config:set openai.key="your-key"
firebase deploy --only functions
gsutil cors set cors.json gs://your-bucket
flutter run
```

---

## 🔧 Troubleshooting

### Common Issues:

#### 1. **Firebase Connection Errors**

**Error:** "Firebase auth not initialized"

**Solution:**
```bash
flutter clean
flutterfire configure
flutter pub get
flutter run
```

#### 2. **CORS Errors in Browser**

**Error:** "Access to fetch at '...' from origin '...' has been blocked by CORS policy"

**Solution:**
```bash
gsutil cors set cors.json gs://readme-40267.firebasestorage.app
```

#### 3. **Cloud Functions Not Working**

**Error:** Functions timing out or returning errors

**Solution:**
```bash
# Check logs
firebase functions:log

# Redeploy
firebase deploy --only functions

# Verify environment variables
firebase functions:config:get
```

#### 4. **PDF Not Loading**

**Possible Causes:**
- CORS not configured
- Invalid storage URL
- Authentication issue

**Solution:**
```bash
# Test storage access
curl "<pdf-url>"

# Regenerate URLs if needed
node tools/regenerate_storage_urls.js
```

#### 5. **Build Failures**

**Error:** Build errors after pulling latest code

**Solution:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter run
```

#### 6. **Git Push Blocked by Secrets**

**Error:** "GitHub blocked push containing secrets"

**Solution:**
```bash
# Remove from tracking
git rm --cached tools/serviceAccountKey.json
git rm --cached functions/.env

# Update .gitignore
echo "tools/serviceAccountKey.json" >> .gitignore
echo "functions/.env" >> .gitignore

# Commit and push
git add .gitignore
git commit -m "Remove secrets"
git push
```

---

## 📝 Quick Reference Commands

### Firebase:
```bash
firebase login                    # Login
firebase projects:list            # List projects
firebase use <project-id>         # Switch project
firebase deploy                   # Deploy everything
firebase deploy --only functions  # Deploy functions only
firebase deploy --only hosting    # Deploy web only
```

### Flutter:
```bash
flutter doctor                    # Check setup
flutter devices                   # List devices
flutter run                       # Run app
flutter build web                 # Build web
flutter clean                     # Clean build
flutter pub get                   # Install dependencies
```

### Git:
```bash
git status                        # Check status
git add .                         # Stage all changes
git commit -m "message"           # Commit
git push                          # Push to remote
git pull                          # Pull from remote
```

---

## 🎉 Setup Complete!

You should now have a fully configured ReadMe app ready for development and deployment.

**Next Steps:**
- Read [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) for architecture details
- Run the app: `flutter run`
- Deploy functions: `firebase deploy --only functions`
- Test features and verify everything works

**Need Help?**
- Check [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md) for detailed system architecture
- Review Firebase Console for data and logs
- Check Flutter/Firebase documentation

---

*For detailed technical architecture, data flow, and feature explanations, see [TECHNICAL_DOCUMENTATION.md](./TECHNICAL_DOCUMENTATION.md)*
