# Firebase Setup Guide for ReadMe App

This guide will help you configure Firebase to resolve the permission and index errors.

## 1. Firebase Security Rules (Development Only)

**⚠️ WARNING: These rules are for development only. Do NOT use in production!**

Go to your Firebase Console → Firestore Database → Rules and update with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access for development
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

## 2. Required Composite Indexes

The app requires several composite indexes for Firestore queries. Create these indexes in Firebase Console → Firestore Database → Indexes:

### Index 1: Reading Progress by User and Date
- Collection: `reading_progress`
- Fields:
  - `userId` (Ascending)
  - `lastReadAt` (Ascending)
  - `__name__` (Ascending)

### Index 2: Reading Progress for Streak Calculation
- Collection: `reading_progress` 
- Fields:
  - `userId` (Ascending)
  - `lastReadAt` (Ascending)
  - `__name__` (Ascending)

### Index 3: Books by Creation Date
- Collection: `books`
- Fields:
  - `createdAt` (Ascending)
  - `__name__` (Ascending)

## 3. Quick Index Creation

When you see an error like:
```
The query requires an index. You can create it here: https://console.firebase.google.com/...
```

Simply click the provided URL and Firebase will create the index automatically.

## 4. Production Security Rules (Future)

For production, implement proper security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Reading progress - users can only access their own
    match /reading_progress/{progressId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Books are readable by all authenticated users
    match /books/{bookId} {
      allow read: if request.auth != null;
      allow write: if false; // Only admins should write books
    }
    
    // Content filters - users can only access their own
    match /content_filters/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 5. Firebase Authentication Setup

Ensure Firebase Authentication is enabled with these providers:
- Email/Password
- Google Sign-In (optional)

## 6. Firestore Collections Structure

The app expects these collections:
- `users` - User profiles and settings
- `books` - Book content and metadata
- `reading_progress` - User reading progress tracking
- `content_filters` - Parental control settings
- `daily_reading_time` - Daily reading time tracking
- `content_reports` - Inappropriate content reports
- `parental_controls` - Parent dashboard settings

## 7. Testing the Setup

After applying these changes:
1. Restart your Flutter app
2. Check that books load without permission errors
3. Verify that reading progress tracking works
4. Confirm that user data loads properly

## 8. Monitoring

Monitor your Firebase usage in the console:
- Firestore usage and costs
- Authentication activity
- Security rule violations (in production)

Remember to update security rules before going to production!
