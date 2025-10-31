// File: lib/providers/user_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';
import '../services/firestore_helpers.dart';
import '../utils/date_utils.dart';
import 'base_provider.dart';

class UserProvider extends BaseProvider {
  final FirestoreHelpers _firestoreHelpers = FirestoreHelpers();

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
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _userProfile = userDoc.data();
        _personalityTraits = List<String>.from(_userProfile?['personalityTraits'] ?? []);
      }

      await _loadReadingStats(userId);
      await _loadWeeklyProgress(userId);

      // Notify UI
      safeNotify();
    } catch (e) {
      appLog('Error performing user data load: $e', level: 'ERROR');
    }
  }

  // Load aggregate reading stats
  Future<void> _loadReadingStats(String userId) async {
    try {
      final progressQuery = await _firestoreHelpers.getReadingProgress(
        userId: userId,
      );

      _totalBooksRead = progressQuery.docs
          .where((doc) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              return data['isCompleted'] == true;
            }
            return false;
          })
          .length;

      _totalReadingMinutes = progressQuery.docs
          .map((doc) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              return (data['readingTimeMinutes'] as int?) ?? 0;
            }
            return 0;
          })
          .fold(0, (total, minutes) => total + minutes);

      await _calculateReadingStreak(userId);
    } catch (e) {
      appLog('Error loading reading stats: $e', level: 'ERROR');
    }
  }

  // Calculate the reading streak and also produce a boolean list for UI.
  // Uses FirestoreHelpers utility to eliminate duplicate query logic.
  Future<void> _calculateReadingStreak(String userId, {int lookbackDays = 30}) async {
    try {
      final result = await _firestoreHelpers.calculateReadingStreak(
        userId: userId,
        lookbackDays: lookbackDays,
      );

      _dailyReadingStreak = result['streak'] as int;
      _currentStreakDays = result['days'] as List<bool>;
    } catch (e) {
      appLog('Error calculating reading streak: $e', level: 'ERROR');
      _dailyReadingStreak = 0;
      _currentStreakDays = [];
    }
  }

  // Load weekly progress (last 7 days) into a friendly map 'Mon'..'Sun'
  // Uses FirestoreHelpers utility to eliminate duplicate query logic.
  Future<void> _loadWeeklyProgress(String userId) async {
    try {
      appLog('Loading weekly progress for user: $userId', level: 'DEBUG');

      _weeklyProgress = await _firestoreHelpers.getWeeklyReadingData(
        userId: userId,
      );

      appLog('Weekly progress loaded: $_weeklyProgress', level: 'DEBUG');
    } catch (e) {
      appLog('Error loading weekly progress: $e', level: 'ERROR');
      _weeklyProgress = {};
    }
  }

  // Check if user read today
  bool hasReadToday() {
    final today = AppDateUtils.getDayKey(DateTime.now());
    return (_weeklyProgress[today] ?? 0) > 0;
  }

  // Get today's reading minutes
  int getTodayReadingMinutes() {
    final today = AppDateUtils.getDayKey(DateTime.now());
    return _weeklyProgress[today] ?? 0;
  }

  // Update user's personality traits after quiz
  Future<void> updatePersonalityTraits(String userId, List<String> traits) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'personalityTraits': traits,
        'hasCompletedQuiz': true,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      });

      _personalityTraits = traits;
      safeNotify();
    } catch (e) {
      appLog('Error updating personality traits: $e', level: 'ERROR');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await firestore.collection('users').doc(userId).update(updates);

      if (_userProfile != null) {
        _userProfile!.addAll(updates);
      }

      safeNotify();
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
    safeNotify();
  }
}