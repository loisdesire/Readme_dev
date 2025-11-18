# 📴 Offline Functionality Implementation Guide

## Overview
This document outlines how to implement offline functionality for the ReadMe app, including complexity estimates and implementation strategies.

---

## Current State (November 2025)

### ✅ Already Implemented
1. **PDF Caching** - PDFs are cached to device storage after first download
2. **Image Caching** - Book covers cached via `cached_network_image` package
3. **Local State Management** - Provider pattern maintains UI state in memory

### ❌ Not Implemented
1. **Offline Database** - No local database for book metadata
2. **Offline Authentication** - Requires active Firebase connection
3. **Sync Mechanism** - No queue for offline actions (reading progress, bookmarks)
4. **Offline Indicator** - No UI feedback when device is offline

---

## Implementation Complexity Assessment

### 🟢 Easy (1-2 days)
**1. Add Offline Detection**
- Use `connectivity_plus` package to detect network status
- Show banner when offline
- Disable network-dependent features gracefully

**Implementation:**
```dart
// Add to pubspec.yaml
dependencies:
  connectivity_plus: ^5.0.0

// Create OfflineService
class OfflineService {
  static final instance = OfflineService._();
  OfflineService._();
  
  bool _isOffline = false;
  bool get isOffline => _isOffline;
  
  void init() {
    Connectivity().onConnectivityChanged.listen((result) {
      _isOffline = result == ConnectivityResult.none;
      // Notify listeners
    });
  }
}

// Show offline banner in main scaffold
if (offlineService.isOffline)
  MaterialBanner(
    content: Text('You are offline. Some features are unavailable.'),
    actions: [TextButton(onPressed: () {}, child: Text('OK'))],
  )
```

---

### 🟡 Medium (3-5 days)
**2. Implement Local Book Database**
- Use `sqflite` (SQLite) or `hive` (NoSQL) for local storage
- Cache book metadata, reading progress, bookmarks
- Implement sync when connection restored

**Implementation:**
```dart
// Add to pubspec.yaml
dependencies:
  sqflite: ^2.3.0  # or hive: ^2.2.3

// Database schema
CREATE TABLE books (
  id TEXT PRIMARY KEY,
  title TEXT,
  author TEXT,
  coverUrl TEXT,
  pdfUrl TEXT,
  description TEXT,
  traits TEXT,  -- JSON array
  tags TEXT,    -- JSON array
  cached_at INTEGER
);

CREATE TABLE reading_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  book_id TEXT,
  current_page INTEGER,
  total_pages INTEGER,
  progress_percent REAL,
  last_read INTEGER,
  is_completed INTEGER,
  synced INTEGER DEFAULT 0  -- 0 = pending sync, 1 = synced
);

// Service implementation
class LocalDatabaseService {
  static Database? _db;
  
  Future<void> cacheBook(Map<String, dynamic> bookData) async {
    await _db.insert('books', bookData, 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getCachedBooks() async {
    return await _db.query('books');
  }
  
  Future<void> saveProgressOffline(Map<String, dynamic> progress) async {
    await _db.insert('reading_progress', {...progress, 'synced': 0});
  }
  
  Future<void> syncPendingProgress() async {
    final pending = await _db.query('reading_progress', 
      where: 'synced = ?', whereArgs: [0]);
    
    for (var record in pending) {
      try {
        await FirebaseFirestore.instance
          .collection('reading_progress')
          .add(record);
        
        await _db.update('reading_progress', 
          {'synced': 1}, 
          where: 'id = ?', 
          whereArgs: [record['id']]);
      } catch (e) {
        // Will retry next sync
      }
    }
  }
}
```

**Sync Strategy:**
1. **Read Operation**: Check local DB first, fallback to Firebase if not found
2. **Write Operation**: Save to local DB immediately, queue for Firebase sync
3. **Background Sync**: When connection restored, push all pending changes
4. **Conflict Resolution**: Last-write-wins (or implement more sophisticated merging)

---

### 🔴 Hard (1-2 weeks)
**3. Full Offline Mode with Conflict Resolution**
- Complete offline authentication (cached credentials)
- Bidirectional sync (handle conflicts when same data modified offline by multiple devices)
- Download books for offline reading
- Smart prefetching based on user preferences

**Implementation Challenges:**
```dart
// Conflict resolution example
class SyncService {
  Future<void> resolveConflicts() async {
    final localProgress = await localDB.getReadingProgress(bookId);
    final remoteProgress = await firestore.getReadingProgress(bookId);
    
    // Conflict detection
    if (localProgress['last_modified'] > remoteProgress['last_modified']) {
      // Local is newer - push to remote
      await firestore.updateReadingProgress(localProgress);
    } else if (remoteProgress['last_modified'] > localProgress['last_modified']) {
      // Remote is newer - pull from remote
      await localDB.updateReadingProgress(remoteProgress);
    } else {
      // Same timestamp - use max progress (user benefit)
      final maxProgress = max(
        localProgress['progress_percent'],
        remoteProgress['progress_percent']
      );
      final merged = {...localProgress, 'progress_percent': maxProgress};
      await firestore.updateReadingProgress(merged);
      await localDB.updateReadingProgress(merged);
    }
  }
}
```

**Additional Requirements:**
- Operation queue system (FIFO or priority-based)
- Retry logic with exponential backoff
- Proper error handling and user notifications
- Data migration from existing Firestore structure
- Testing across multiple offline/online scenarios

---

## Recommended Approach

### Phase 1: Basic Offline Detection (Start Here) 🟢
**Effort**: 1-2 days  
**Impact**: High (user awareness)  
**Risk**: Low

**Steps:**
1. Add `connectivity_plus` package
2. Create `OfflineService` with connectivity monitoring
3. Show offline banner in UI
4. Disable network features when offline
5. Allow reading of already-cached PDFs offline

**Files to Modify:**
- `pubspec.yaml`
- Create `lib/services/offline_service.dart`
- `lib/main.dart` (initialize service)
- `lib/screens/child/child_home_screen.dart` (show banner)
- `lib/providers/book_provider.dart` (check connectivity before network calls)

---

### Phase 2: Local Caching (If Phase 1 Successful) 🟡
**Effort**: 3-5 days  
**Impact**: High (core offline functionality)  
**Risk**: Medium (data consistency)

**Steps:**
1. Add `sqflite` or `hive` package
2. Create database schema
3. Implement `LocalDatabaseService`
4. Modify providers to check local DB first
5. Implement basic sync on reconnection
6. Add "Download for Offline" button on book details

**Files to Modify:**
- `pubspec.yaml`
- Create `lib/services/local_database_service.dart`
- `lib/providers/book_provider.dart` (add local caching layer)
- `lib/providers/user_provider.dart` (cache user data)
- `lib/screens/book/book_details_screen.dart` (download button)

---

### Phase 3: Advanced Sync (Future Enhancement) 🔴
**Effort**: 1-2 weeks  
**Impact**: Medium (edge case handling)  
**Risk**: High (complex sync logic)

**Only implement if:**
- You have multiple active users on multiple devices
- Users frequently switch between online/offline
- Conflict scenarios are common

---

## Testing Checklist

### Offline Detection Testing
- [ ] Turn off WiFi - app shows offline banner
- [ ] Turn off mobile data - app shows offline banner
- [ ] Restore connection - banner disappears
- [ ] Network calls fail gracefully with user-friendly messages

### Caching Testing
- [ ] Open book online - PDF caches
- [ ] Go offline - same book still opens
- [ ] Reading progress saves locally
- [ ] Reconnect - progress syncs to Firebase
- [ ] Multiple offline edits sync correctly

### Edge Cases
- [ ] App starts offline (no crash)
- [ ] Connection drops mid-read (graceful handling)
- [ ] Large book download (progress indicator)
- [ ] Storage full (error handling)
- [ ] Corrupted cache (fallback to re-download)

---

## Estimated Total Effort

| Phase | Complexity | Time | Priority |
|-------|-----------|------|----------|
| Phase 1: Detection | 🟢 Easy | 1-2 days | **High** |
| Phase 2: Caching | 🟡 Medium | 3-5 days | Medium |
| Phase 3: Advanced | 🔴 Hard | 1-2 weeks | Low |

**Recommended Start:** Phase 1 (Offline Detection)  
**Total for Basic Offline:** 4-7 days (Phase 1 + Phase 2)  
**Total for Full Offline:** 2-3 weeks (All phases)

---

## Alternative: Hybrid Approach

Instead of full offline mode, consider a **"Download Mode"**:

```dart
// Allow users to explicitly download books for offline
class BookDownloadService {
  Future<void> downloadBookForOffline(Book book) async {
    // 1. Download PDF to permanent storage
    final file = await downloadPdf(book.pdfUrl);
    
    // 2. Cache metadata locally
    await localDB.cacheBook(book.toJson());
    
    // 3. Update UI (show checkmark "Downloaded")
    notifyListeners();
  }
  
  Future<List<Book>> getDownloadedBooks() async {
    return await localDB.getDownloadedBooks();
  }
}

// UI: Add "Downloaded" section in library
LibraryScreen(
  tabs: [
    'Continue Reading',
    'Downloaded',  // NEW - only shows offline-available books
    'All Books',
  ]
)
```

**Benefits:**
- ✅ Simpler implementation (no sync conflicts)
- ✅ User controls what's available offline
- ✅ Clearer storage management
- ✅ No unexpected behavior (user knows what works offline)

---

## Conclusion

**Answer to "How hard would it be?"**

- **Basic offline detection + caching**: **Medium difficulty** (4-7 days for a Flutter developer)
- **Full offline mode with sync**: **Hard** (2-3 weeks with testing)

**Recommendation:**
Start with **Phase 1** (offline detection) - it's low-risk and provides immediate value. If users request more offline features, proceed to **Phase 2** (local caching). Phase 3 is only needed for advanced multi-device scenarios.

The existing PDF and image caching already provides some offline capability (users can read previously opened books without internet), so you're not starting from zero.
