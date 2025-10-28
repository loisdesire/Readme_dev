# Phase 1 Migration Guide - Using New Utilities

This guide shows how to migrate existing code to use the new Phase 1 utilities.

## 🎯 What's New in Phase 1

1. **FirebaseService** - Centralized Firebase instance management
2. **AppDateUtils** - Comprehensive date manipulation utilities
3. **FirestoreHelpers** - Reusable Firestore query methods
4. **Enhanced BaseProvider** - Better state management capabilities

---

## 1. Using FirebaseService

### ❌ Before (Old Way)
```dart
class MyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    // ...
  }
}
```

### ✅ After (New Way)
```dart
class MyProvider extends BaseProvider {
  // No need to declare Firebase instances!
  // BaseProvider already provides:
  //   - firestore (FirebaseFirestore)
  //   - auth (FirebaseAuth)
  //   - currentUser (User?)
  //   - currentUserId (String?)

  Future<void> loadData() async {
    if (currentUserId == null) return;

    final doc = await firestore.collection('users').doc(currentUserId).get();
    // ...
  }
}
```

### 🎯 Benefits
- No duplicate instance creation
- Consistent across all providers
- Easier testing (single point to mock)
- Less boilerplate code

---

## 2. Using AppDateUtils

### ❌ Before (Old Way)
```dart
// Getting day range for queries
final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
final dayEnd = dayStart.add(const Duration(days: 1));

final query = await firestore
    .collection('reading_sessions')
    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
    .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
    .get();

// Formatting date key
final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

// Getting day name
const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
final dayName = days[date.weekday - 1];
```

### ✅ After (New Way)
```dart
import '../utils/date_utils.dart';

// Getting day range for queries - ONE LINE!
final range = AppDateUtils.getDayRange(checkDate);

final query = await firestore
    .collection('reading_sessions')
    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
    .where('timestamp', isLessThan: Timestamp.fromDate(range.end))
    .get();

// Formatting date key - ONE LINE!
final dateKey = AppDateUtils.formatDateKey(today);

// Getting day name - ONE LINE!
final dayName = AppDateUtils.getDayKey(date);
```

### 🎯 Common Use Cases

```dart
// Check if a date is today
if (AppDateUtils.isToday(someDate)) {
  print('This happened today!');
}

// Get start of week (Monday)
final weekStart = AppDateUtils.startOfWeek(DateTime.now());

// Get weekly range
final range = AppDateUtils.getWeekRange(DateTime.now());
// range.start = This Monday at 00:00:00
// range.end = Next Monday at 00:00:00

// Format dates relative to today
print(AppDateUtils.formatRelative(DateTime.now())); // "Today"
print(AppDateUtils.formatRelative(yesterday)); // "Yesterday"
print(AppDateUtils.formatRelative(oldDate)); // "2025-10-20"

// Count days between dates
final days = AppDateUtils.daysBetween(startDate, endDate);
```

---

## 3. Using FirestoreHelpers

### ❌ Before (Old Way)
```dart
// user_provider.dart - Checking if user read on a day
Future<bool> checkIfReadOnDay(String userId, DateTime date) async {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  // Check reading_progress
  final progressQuery = await _firestore
      .collection('reading_progress')
      .where('userId', isEqualTo: userId)
      .where('lastReadAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .where('lastReadAt', isLessThan: Timestamp.fromDate(dayEnd))
      .get();

  if (progressQuery.docs.isNotEmpty) return true;

  // Check reading_sessions
  final sessionsQuery = await _firestore
      .collection('reading_sessions')
      .where('userId', isEqualTo: userId)
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
      .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
      .limit(1)
      .get();

  return sessionsQuery.docs.isNotEmpty;
}
```

### ✅ After (New Way)
```dart
// Just ONE LINE!
final hasRead = await FirestoreHelpers().hasReadingActivityOnDay(
  userId: userId,
  date: date,
);
```

### 🎯 More Examples

```dart
final helpers = FirestoreHelpers();

// Get reading sessions for today
final range = AppDateUtils.getDayRange(DateTime.now());
final sessions = await helpers.getReadingSessions(
  userId: userId,
  startDate: range.start,
  endDate: range.end,
);

// Get completed books
final completed = await helpers.getReadingProgress(
  userId: userId,
  completedOnly: true,
);

// Get ongoing books
final ongoing = await helpers.getReadingProgress(
  userId: userId,
  ongoingOnly: true,
);

// Get daily reading minutes
final minutes = await helpers.getDailyReadingMinutes(
  userId: userId,
  date: DateTime.now(),
);

// Get weekly reading data
final weeklyData = await helpers.getWeeklyReadingData(userId: userId);
print(weeklyData); // {'Mon': 15, 'Tue': 20, 'Wed': 0, ...}

// Calculate reading streak
final streakResult = await helpers.calculateReadingStreak(userId: userId);
print('Streak: ${streakResult['streak']} days');
print('Read today: ${streakResult['todayRead']}');
print('Recent days: ${streakResult['days']}');
```

---

## 4. Using Enhanced BaseProvider

### ❌ Before (Old Way)
```dart
class MyProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData() async {
    try {
      _isLoading = true;
      Future.delayed(Duration.zero, () => notifyListeners());

      // Load data...
      final data = await fetchData();

      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      _error = 'Failed to load data: $e';
      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }
}
```

### ✅ After (New Way)
```dart
class MyProvider extends BaseProvider {
  // isLoading, error, setLoading, setError already provided by BaseProvider!

  Future<void> loadData() async {
    await executeWithState(
      () async {
        // Just your loading logic!
        final data = await fetchData();
        return data;
      },
      errorMessage: 'Failed to load data',
      onSuccess: () {
        appLog('Data loaded successfully');
      },
    );
  }
}
```

### 🎯 Benefits
- **90% less boilerplate** for loading states
- **Automatic error handling** with custom messages
- **Safe notification** (no build-phase issues)
- **Disposal-safe** execution
- **Success callbacks** for additional actions

---

## 📊 Real-World Migration Example

Let's migrate a complex method from `user_provider.dart`:

### ❌ Before (91 lines)
```dart
Future<void> _calculateReadingStreak(String userId, {int lookbackDays = 30}) async {
  try {
    appLog('Starting streak calculation for user: $userId', level: 'DEBUG');
    final now = DateTime.now();

    int streak = 0;
    bool todayRead = false;
    List<bool> streakDays = [];

    for (int i = 0; i < lookbackDays; i++) {
      final checkDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayStart = checkDate;
      final dayEnd = dayStart.add(const Duration(days: 1));

      try {
        final progressQuery = await _firestore
            .collection('reading_progress')
            .where('userId', isEqualTo: userId)
            .where('lastReadAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('lastReadAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        final sessionsQuery = await _firestore
            .collection('reading_sessions')
            .where('userId', isEqualTo: userId)
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        final hasProgress = progressQuery.docs.isNotEmpty;
        final hasSessions = sessionsQuery.docs.isNotEmpty;

        if (hasProgress || hasSessions) {
          streakDays.add(true);
          if (i == 0) todayRead = true;
        } else {
          if (i == 0) {
            streakDays.add(false);
          } else {
            break;
          }
        }
      } catch (qErr) {
        appLog('Error checking day $i for streak: $qErr', level: 'ERROR');
        if (i == 0) {
          streakDays.add(false);
        }
        break;
      }
    }

    // Calculate streak
    if (todayRead) {
      streak = streakDays.takeWhile((day) => day == true).length;
    } else {
      streak = 0;
      for (int i = 1; i < streakDays.length; i++) {
        if (streakDays[i] == true) {
          streak++;
        } else {
          break;
        }
      }
    }

    _dailyReadingStreak = streak;
    _currentStreakDays = streakDays;

    appLog('Streak calculated: $_dailyReadingStreak, days: $_currentStreakDays', level: 'DEBUG');
  } catch (e) {
    appLog('Error calculating reading streak: $e', level: 'ERROR');
    _dailyReadingStreak = 0;
    _currentStreakDays = [];
  }
}
```

### ✅ After (7 lines!)
```dart
Future<void> _calculateReadingStreak(String userId, {int lookbackDays = 30}) async {
  final result = await FirestoreHelpers().calculateReadingStreak(
    userId: userId,
    lookbackDays: lookbackDays,
  );

  _dailyReadingStreak = result['streak'] as int;
  _currentStreakDays = result['days'] as List<bool>;
}
```

**Reduction: 91 lines → 7 lines (92% reduction!)**

---

## 🚀 Migration Checklist

### Step 1: Update Imports
Add these imports where needed:
```dart
import '../services/firebase_service.dart';
import '../utils/date_utils.dart';
import '../services/firestore_helpers.dart';
```

### Step 2: Extend BaseProvider
If your provider doesn't already extend BaseProvider:
```dart
// Before
class MyProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ...
}

// After
class MyProvider extends BaseProvider {
  // firestore already available!
  // ...
}
```

### Step 3: Replace Date Manipulations
Search for patterns like:
- `DateTime(date.year, date.month, date.day)` → `AppDateUtils.startOfDay(date)`
- `.add(const Duration(days: 1))` → `AppDateUtils.getDayRange(date)`
- Manual date formatting → `AppDateUtils.formatDateKey(date)`

### Step 4: Replace Firestore Queries
Search for patterns like:
- Duplicate reading_sessions queries → `FirestoreHelpers().getReadingSessions()`
- Duplicate reading_progress queries → `FirestoreHelpers().getReadingProgress()`
- Complex streak calculations → `FirestoreHelpers().calculateReadingStreak()`

### Step 5: Simplify State Management
Replace manual loading/error handling with:
```dart
await executeWithState(() async {
  // Your logic
}, errorMessage: 'Custom error message');
```

---

## 📝 Testing Your Changes

After migration, test these scenarios:

1. **Date Utilities**
   - [ ] Streak calculation works correctly
   - [ ] Weekly data shows correct days
   - [ ] Date ranges include correct boundaries

2. **Firestore Helpers**
   - [ ] Reading sessions query returns expected results
   - [ ] Streak calculation matches old behavior
   - [ ] Daily minutes calculation is accurate

3. **BaseProvider**
   - [ ] Loading states update correctly
   - [ ] Error messages display properly
   - [ ] No build-phase notification errors

---

## 💡 Tips

1. **Don't migrate everything at once** - Start with one provider
2. **Test thoroughly** after each migration
3. **Keep old code commented** initially for comparison
4. **Use the examples** in this guide as templates
5. **Check logs** to ensure calculations match previous behavior

---

## 🎉 Expected Results

After Phase 1 migration:
- ✅ **~420+ fewer lines** of duplicate code
- ✅ **More consistent** date handling
- ✅ **Easier to test** isolated utilities
- ✅ **Faster development** with reusable helpers
- ✅ **Better maintainability** with single sources of truth

---

## ❓ Need Help?

If you encounter issues:
1. Check the original recommendation document for context
2. Look at the utility source files for detailed documentation
3. Compare with examples in this guide
4. Test one piece at a time

Happy coding! 🚀
