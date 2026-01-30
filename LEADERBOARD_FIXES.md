# Leaderboard & Reading Time Fixes

## Issues Fixed (January 26, 2026)

### 1. ✅ Extra Users Appearing After Leaderboard Reset

**Problem:** Deleted users were reappearing after leaderboard resets.

**Root Cause:** The `tools/import_users.js` script imports users from the old project (readme-40267) to current project (readmev2). When run after deletions, it restores deleted users.

**Solution:**
- ✅ Added manual "yes" confirmation prompt before import
- ✅ Created audit log (`tools/import_users_log.txt`) tracking all imports with timestamps
- ✅ Created `tools/IMPORT_WARNING.md` documentation
- ✅ Added log file to `.gitignore`
- ✅ Confirmed leaderboard reset functions do NOT trigger imports

**Action Required:**
- **Check** `tools/import_users_log.txt` to see when imports last ran
- **Never run** `import_users.js` unless explicitly restoring from backup
- **Delete unwanted users** again if they were reimported

---

### 2. ✅ Inaccurate Total Reading Time

**Problem:** Reading time displayed in leaderboards/achievements was inaccurate.

**Root Cause:** Two competing sources of truth:
1. `reading_progress` collection with `readingTimeMinutes` field (used by achievements)
2. `reading_sessions` collection with actual session tracking (accurate)

**Solution:**
- ✅ Changed `book_provider.dart` to use `ReadingSessionService` (source of truth)
- ✅ Achievements now calculate from actual reading sessions
- ✅ Added `ReadingSessionService` import to `book_provider.dart`

**Technical Details:**
```dart
// OLD (inaccurate):
final totalReadingTime = _userProgress.fold<int>(
  0,
  (total, progress) => total + progress.readingTimeMinutes,
);

// NEW (accurate):
final sessionService = ReadingSessionService();
final totalReadingTime = await sessionService.getTotalReadingMinutes(userId);
```

---

## How Leaderboard Reset Works

**File:** `functions/index.js`

**Scheduled Function:** `resetWeeklyLeaderboard`
- Runs: Every Monday at 00:00 UTC
- Updates: All users in database
- Resets:
  - `totalAchievementPoints`: 0
  - `weeklyBooksRead`: 0
  - `weeklyPoints`: 0
  - `weeklyReadingMinutes`: 0
  - `lastWeeklyReset`: current timestamp

**Manual Function:** `manualWeeklyReset`
- Callable endpoint for testing
- Same logic as scheduled function

**⚠️ IMPORTANT:** These functions do NOT create or import users. They only update existing users.

---

## Files Changed

1. **lib/providers/book_provider.dart**
   - Import: Added `ReadingSessionService`
   - Method: `_checkAndUnlockAchievements()` now uses sessions for reading time

2. **tools/import_users.js**
   - Added: Manual confirmation prompt
   - Added: Audit logging with timestamps
   - Added: Import summary logging

3. **tools/IMPORT_WARNING.md** (NEW)
   - Documentation about import dangers
   - When to/not to run the script

4. **.gitignore**
   - Added: `tools/import_users_log.txt`

---

## Verification Steps

### Check if import ran recently:
```bash
cat tools/import_users_log.txt
```

### Check last leaderboard reset:
Query Firestore for any user's `lastWeeklyReset` field.

### Verify reading time accuracy:
1. Open child home screen
2. Check badge progress (time-based achievements)
3. Compare with actual reading sessions in Firestore

---

## Future Prevention

### To avoid unwanted user imports:
- ✅ Never run `import_users.js` manually
- ✅ Check audit log before any bulk operations
- ✅ Read `IMPORT_WARNING.md` before running ANY tool scripts

### To maintain reading time accuracy:
- ✅ Always use `ReadingSessionService.getTotalReadingMinutes()`
- ✅ Don't rely on `reading_progress.readingTimeMinutes` for totals
- ✅ Session tracking is the source of truth

---

## Testing Checklist

- [ ] Delete a test user from Firestore
- [ ] Run weekly leaderboard reset (manual function)
- [ ] Verify deleted user does NOT reappear
- [ ] Check `import_users_log.txt` - should be empty or show old imports only
- [ ] Verify reading time matches actual sessions
- [ ] Test badge progress uses accurate session data

---

## Questions?

1. **Users still appearing?** → Check `import_users_log.txt` for recent imports
2. **Reading time wrong?** → Verify using `reading_sessions` collection in Firestore
3. **Import needed?** → Read `tools/IMPORT_WARNING.md` first, then proceed with caution
