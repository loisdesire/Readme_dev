// File: lib/providers/user_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userProfile;
  List<String> _personalityTraits = [];
  int _dailyReadingStreak = 0;
  int _totalBooksRead = 0;
  int _totalReadingMinutes = 0;
  Map<String, int> _weeklyProgress = {}; // e.g. {'Mon': 10, 'Tue': 0, ...}

  // For UI: list of booleans representing the last N days (today first).
  // true = read, false = not read. Useful to render filled vs outlined circles.
  List<bool> _currentStreakDays = [];

  // Getters
  Map<String, dynamic>? get userProfile => _userProfile;
  List<String> get personalityTraits => _personalityTraits;
  int get dailyReadingStreak => _dailyReadingStreak;
  int get totalBooksRead => _totalBooksRead;
  int get totalReadingMinutes => _totalReadingMinutes;
  Map<String, int> get weeklyProgress => _weeklyProgress;
  List<bool> get currentStreakDays => _currentStreakDays;

  // Load full user data (profile + stats)
  // Internal helpers for throttling/coalescing loads
  Future<void>? _ongoingLoadFuture;
  DateTime? _lastLoadAt;
  final Duration _minReloadInterval = const Duration(milliseconds: 800);

  /// Load full user data (profile + stats).
  ///
  /// To avoid hammering Firestore when multiple parts of the UI call this
  /// repeatedly (for example, after page changes), this method coalesces
  /// concurrent calls so they await the same in-flight load, and it will
  /// skip a reload if the last load finished within [_minReloadInterval]
  /// unless [force] is true.
  Future<void> loadUserData(String userId, {bool force = false}) async {
    try {
      // If a load is already in progress, return that same future so callers
      // don't fire redundant requests.
      if (!force && _ongoingLoadFuture != null) {
        appLog('Awaiting existing user data load', level: 'DEBUG');
        return await _ongoingLoadFuture!;
      }

      // If we recently loaded, skip unless forced.
      if (!force && _lastLoadAt != null && DateTime.now().difference(_lastLoadAt!) < _minReloadInterval) {
        appLog('Skipping user data reload - last load was recent', level: 'DEBUG');
        return;
      }

      // Start actual load and store the future so concurrent callers can await it.
      _ongoingLoadFuture = _performLoadUserData(userId);
      try {
        await _ongoingLoadFuture;
      } finally {
        _ongoingLoadFuture = null;
        _lastLoadAt = DateTime.now();
      }
    } catch (e) {
      appLog('Error loading user data (coalesced): $e', level: 'ERROR');
    }
  }

  // Actual implementation of loading user data (separated for clarity)
  Future<void> _performLoadUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _userProfile = userDoc.data();
        _personalityTraits = List<String>.from(_userProfile?['personalityTraits'] ?? []);
      }

      await _loadReadingStats(userId);
      await _loadWeeklyProgress(userId);

      // Notify UI
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      appLog('Error performing user data load: $e', level: 'ERROR');
    }
  }

  // Load aggregate reading stats
  Future<void> _loadReadingStats(String userId) async {
    try {
      final progressQuery = await _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .get();

      _totalBooksRead = progressQuery.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;

      _totalReadingMinutes = progressQuery.docs
          .map((doc) => doc.data()['readingTimeMinutes'] as int? ?? 0)
          .fold(0, (total, minutes) => total + minutes);

      await _calculateReadingStreak(userId);
    } catch (e) {
      appLog('Error loading reading stats: $e', level: 'ERROR');
    }
  }

  // Calculate the reading streak and also produce a boolean list for UI.
  // Behavior:
  // - Count consecutive days with reading, ending today if read, otherwise ending yesterday.
  // - _dailyReadingStreak is the integer count of consecutive days.
  // - _currentStreakDays is a list [today, yesterday, day-2, ...] where each value is true iff read.
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

        // Query both reading_progress and reading_sessions for activity on that day
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
            // Mark this day as read
            streakDays.add(true);
            if (i == 0) todayRead = true;
          } else {
            // Day has no reading
            if (i == 0) {
              // If today has no reading, mark false for today (outline in UI)
              // but DON'T break - continue to check previous days
              streakDays.add(false);
            } else {
              // If a past day has no reading, the consecutive streak stops here
              break;
            }
          }
        } catch (qErr) {
          appLog('Error checking day $i for streak: $qErr', level: 'ERROR');
          // If query breaks, stop checking further
          if (i == 0) {
            streakDays.add(false);
          }
          break;
        }
      }

      // Calculate streak: count consecutive days read (excluding today if not read)
      if (todayRead) {
        // Today is read, so streak includes all true values from the start
        streak = streakDays.takeWhile((day) => day == true).length;
      } else {
        // Today is not read, so streak is consecutive days from yesterday backwards
        // streakDays[0] is false (today), check from index 1 onwards
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

  // Load weekly progress (last 7 days) into a friendly map 'Mon'..'Sun'
  Future<void> _loadWeeklyProgress(String userId) async {
    try {
      appLog('Loading weekly progress for user: $userId', level: 'DEBUG');
      final now = DateTime.now();
      _weeklyProgress.clear();

      // Week starts Monday
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final dayKey = _getDayKey(day);
        int dayMinutes = 0;

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

          for (final doc in progressQuery.docs) {
            final readingTime = (doc.data()['readingTimeMinutes'] as int? ?? 0);
            dayMinutes += readingTime;
          }

          for (final doc in sessionsQuery.docs) {
            final sessionData = doc.data();
            final duration = sessionData['sessionDurationSeconds'] as int? ?? 0;
            final minutes = (duration / 60).round();
            dayMinutes += minutes;
          }

          // Fallback: if no minutes but there are records, mark 1 minute
          if (dayMinutes == 0 && (progressQuery.docs.isNotEmpty || sessionsQuery.docs.isNotEmpty)) {
            bool hasActualReading = false;
            for (final doc in progressQuery.docs) {
              final data = doc.data();
              final progressPercent = (data['progressPercentage'] as double? ?? 0.0);
              final currentPage = (data['currentPage'] as int? ?? 0);
              if (progressPercent > 0.01 || currentPage > 1) {
                hasActualReading = true;
                break;
              }
            }
            if (hasActualReading || sessionsQuery.docs.isNotEmpty) {
              dayMinutes = 1;
            }
          }

          _weeklyProgress[dayKey] = dayMinutes;
        } catch (qErr) {
          appLog('Error querying weekly progress for $dayKey: $qErr', level: 'ERROR');
          _weeklyProgress[dayKey] = 0;
        }
      }

      appLog('Weekly progress loaded: $_weeklyProgress', level: 'DEBUG');
    } catch (e) {
      appLog('Error loading weekly progress: $e', level: 'ERROR');
      _weeklyProgress = {};
    }
  }

  // Helper to get day key
  String _getDayKey(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  // Check if user read today
  bool hasReadToday() {
    final today = _getDayKey(DateTime.now());
    return (_weeklyProgress[today] ?? 0) > 0;
  }

  // Get today's reading minutes
  int getTodayReadingMinutes() {
    final today = _getDayKey(DateTime.now());
    return _weeklyProgress[today] ?? 0;
  }

  // Update user's personality traits after quiz
  Future<void> updatePersonalityTraits(String userId, List<String> traits) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'personalityTraits': traits,
        'hasCompletedQuiz': true,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      });

      _personalityTraits = traits;
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      appLog('Error updating personality traits: $e', level: 'ERROR');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);

      if (_userProfile != null) {
        _userProfile!.addAll(updates);
      }

      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      appLog('Error updating user profile: $e', level: 'ERROR');
    }
  }

  // Record reading session (called by BookProvider)
  Future<void> recordReadingSession({
    required String userId,
    required String bookId,
    required int minutesRead,
  }) async {
    try {
      // Optionally save a session record here. For now we just refresh user stats.
      await loadUserData(userId);
    } catch (e) {
      appLog('Error recording reading session: $e', level: 'ERROR');
    }
  }

  double getDailyGoalProgress() {
    final todayMinutes = getTodayReadingMinutes();
    const dailyGoal = 15;
    return (todayMinutes / dailyGoal).clamp(0.0, 1.0);
  }

  List<String> getUnlockedAchievements() {
    List<String> achievements = [];

    if (_totalBooksRead >= 1) achievements.add('First Book');
    if (_totalBooksRead >= 5) achievements.add('Book Lover');
    if (_dailyReadingStreak >= 3) achievements.add('3-Day Streak');
    if (_dailyReadingStreak >= 7) achievements.add('Week Warrior');
    if (_totalReadingMinutes >= 60) achievements.add('Hour Hero');

    return achievements;
  }

  // Clear user data (for logout)
  void clearUserData() {
    _userProfile = null;
    _personalityTraits = [];
    _dailyReadingStreak = 0;
    _totalBooksRead = 0;
    _totalReadingMinutes = 0;
    _weeklyProgress = {};
    _currentStreakDays = [];
    Future.delayed(Duration.zero, () => notifyListeners());
  }
}