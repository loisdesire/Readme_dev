# 🔥 New Firebase Project Setup Guide

**Purpose:** Connect this ReadMe app to a NEW Firebase project for experimentation
**Date:** January 1, 2026

---

## 📋 Overview

This guide will help you:
1. ✅ Create a new Firebase project
2. ✅ Configure Flutter app with new Firebase credentials
3. ✅ Set up Firestore Database
4. ✅ Configure Firebase Storage with CORS
5. ✅ Set up Cloud Functions with OpenAI API
6. ✅ Test the complete setup

---

## Step 1: Create New Firebase Project

### A. In Firebase Console (https://console.firebase.google.com/):

1. Click **"Add project"** or **"Create a project"**
2. Enter project name: `readme-experiment` (or your choice)
3. Click **Continue**
4. **Google Analytics**: Enable (recommended) or disable
5. Click **Create project**
6. **IMPORTANT:** Copy your **Project ID** (looks like `readme-experiment-a1b2c`)

### B. Enable Required Services:

1. **Authentication:**
   - Go to Build → Authentication
   - Click "Get started"
   - Enable **Email/Password** sign-in method

2. **Firestore Database:**
   - Go to Build → Firestore Database
   - Click "Create database"
   - Start in **Test mode** (we'll add security rules later)
   - Choose location: `us-central1` (or closest to you)

3. **Storage:**
   - Go to Build → Storage
   - Click "Get started"
   - Start in **Test mode**
   - Choose same location as Firestore

4. **Cloud Functions:**
   - Go to Build → Functions
   - Click "Get started"
   - Choose region: `us-central1`

---

## Step 2: Configure Flutter App with New Firebase

### A. Run FlutterFire Configure:

```powershell
# Make sure you're in the project root
cd "C:\Users\loisf\Documents\Mee\Lois docs\Readme"

# Install/Update FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure with your NEW project 
flutterfire configure --project=YOUR_PROJECT_ID
```

**What this does:**
- Generates new `firebase_options.dart` with your new project credentials
- Updates `.firebaserc` with new project ID
- Configures all platforms (Android, iOS, Web, Windows, macOS)

### B. Verify Configuration:

Check that `lib/firebase_options.dart` now has your NEW project ID and credentials.

---

## Step 3: Set Up Firestore Security Rules

### A. In Firebase Console → Firestore Database → Rules:

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // User documents - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow parents to read their children's data
      allow read: if request.auth != null && 
                     resource.data.parentIds != null &&
                     request.auth.uid in resource.data.parentIds;
      
      // Allow children to read their parent's basic info
      allow read: if request.auth != null &&
                     resource.data.accountType == 'parent' &&
                     resource.data.children != null &&
                     request.auth.uid in resource.data.children;
    }
    
    // Books collection - read-only for authenticated users
    match /books/{bookId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.accountType == 'admin';
    }
    
    // Reading progress - users can manage their own progress
    match /users/{userId}/reading_progress/{progressId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow parents to read their children's progress
      allow read: if request.auth != null &&
                     get(/databases/$(database)/documents/users/$(userId)).data.parentIds != null &&
                     request.auth.uid in get(/databases/$(database)/documents/users/$(userId)).data.parentIds;
    }
    
    // Achievements - users can manage their own achievements
    match /users/{userId}/achievements/{achievementId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow parents to read their children's achievements
      allow read: if request.auth != null &&
                     get(/databases/$(database)/documents/users/$(userId)).data.parentIds != null &&
                     request.auth.uid in get(/databases/$(database)/documents/users/$(userId)).data.parentIds;
    }
  }
}
```

Click **Publish**

---

## Step 4: Set Up Firebase Storage CORS

### A. Create CORS configuration (already exists in `cors.json`):

The file `cors.json` in your project root should contain:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "maxAgeSeconds": 3600,
    "responseHeader": ["Content-Type", "Access-Control-Allow-Origin"]
  }
]
```

### B. Apply CORS to your new Storage bucket:

```powershell
# Install Google Cloud SDK if not already installed
# Download from: https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set your new project
gcloud config set project YOUR_PROJECT_ID

# Apply CORS configuration
gsutil cors set cors.json gs://YOUR_PROJECT_ID.appspot.com
```

**Alternative (if gsutil not available):**
You can configure CORS later when you deploy Cloud Functions - the functions will handle CORS headers.

---

## Step 5: Set Up Cloud Functions with OpenAI

### A. Get OpenAI API Key:

1. Go to https://platform.openai.com/api-keys
2. Create a new API key (or use existing one)
3. Copy the key (starts with `sk-...`)

### B. Set Environment Variables:

```powershell
# Navigate to functions directory
cd functions

# Set the OpenAI API key as a Firebase secret
firebase functions:secrets:set OPENAI_API_KEY

# When prompted, paste your OpenAI API key
```

### C. Install Dependencies:

```powershell
# Still in functions directory
npm install
```

### D. Deploy Cloud Functions:

```powershell
# Go back to project root
cd ..

# Deploy functions
firebase deploy --only functions

# Or deploy everything (functions + hosting + firestore rules + storage rules)
firebase deploy
```

**Note:** First deployment might take 5-10 minutes.

---

## Step 6: Update Application Constants (Optional)

If you need to update any app constants, check:

- `lib/utils/app_constants.dart` - App-wide constants
- `lib/services/api_service.dart` - API endpoints

Most settings are dynamic and don't need changes.

---

## Step 7: Test the Setup

### A. Run Flutter App:

```powershell
# Install Flutter dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Or run on Android emulator
flutter run -d emulator-name

# Or run on connected device
flutter run
```

### B. Test Key Features:

1. **Authentication:**
   - Create a new parent account
   - Verify email/password signup works

2. **Firestore:**
   - Create a child profile
   - Check if data saves in Firebase Console

3. **Storage:**
   - Upload a book PDF (from admin panel)
   - Verify it appears in Storage

4. **Cloud Functions:**
   - Upload a book with PDF
   - Check if AI tagging triggers (check Functions logs)

---

## Step 8: Create Admin User

### A. In Firebase Console → Authentication:

1. Add a new user manually:
   - Email: your-admin@email.com
   - Password: (set a strong password)
   - Copy the **User UID**

### B. In Firestore Database:

1. Go to `users` collection
2. Click "Add document"
3. Document ID: (paste the User UID from above)
4. Add fields:
   ```
   accountType: "admin"
   email: "your-admin@email.com"
   displayName: "Admin"
   createdAt: [current timestamp]
   ```

Now you can log in as admin and access the admin portal at `/admin` route.

---

## Step 9: Upload Initial Books (Optional)

### A. Using Admin Portal:

1. Log in as admin
2. Navigate to Admin Portal
3. Use the bulk upload feature with the scripts in `tools/` directory

### B. Using Upload Scripts:

```powershell
# Navigate to tools directory
cd tools

# Install dependencies
npm install

# Update serviceAccountKey.json with your new project's service account:
# Go to Firebase Console → Project Settings → Service Accounts
# Click "Generate new private key"
# Save as tools/serviceAccountKey.json

# Run upload script
node upload_books.js
# or
node upload_gutenberg_books.js
```

---

## 🎉 You're All Set!

Your ReadMe app is now connected to your new Firebase project and ready for experimentation!

### Quick Reference Commands:

```powershell
# Run the app
flutter run -d chrome

# Deploy functions
firebase deploy --only functions

# View function logs
firebase functions:log

# Check Firestore data
firebase firestore:list

# Run in debug mode
flutter run --debug
```

---

## 🆘 Troubleshooting

### Issue: "Firebase project not found"
**Solution:** Run `flutterfire configure` again and select correct project

### Issue: "Cloud Functions not deploying"
**Solution:** 
```powershell
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Issue: "CORS errors when loading PDFs"
**Solution:** Apply CORS configuration to Storage bucket (Step 4)

### Issue: "OpenAI API not working"
**Solution:** 
```powershell
firebase functions:secrets:set OPENAI_API_KEY
# Re-deploy functions after setting
firebase deploy --only functions
```

### Issue: "Can't access admin portal"
**Solution:** Create admin user in Firestore (Step 8)

---

## 📚 Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- Original Setup Guide: `SETUP_GUIDE.md`
- Technical Documentation: `TECHNICAL_DOCUMENTATION.md`

---

**Questions?** Check the original `SETUP_GUIDE.md` for more detailed troubleshooting.
