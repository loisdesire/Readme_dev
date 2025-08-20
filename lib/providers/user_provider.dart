// File: lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _userProfile;
  List<String> _personalityTraits = [];
  int _dailyReadingStreak = 0;
  int _totalBooksRead = 0;
  int _totalReadingMinutes = 0;
  Map<String, int> _weeklyProgress = {}; // day -> minutes read
  
  // Getters
  Map<String, dynamic>? get userProfile => _userProfile;
  List<String> get personalityTraits => _personalityTraits;
  int get dailyReadingStreak => _dailyReadingStreak;
  int get totalBooksRead => _totalBooksRead;
  int get totalReadingMinutes => _totalReadingMinutes;
  Map<String, int> get weeklyProgress => _weeklyProgress;

  // Load user profile and stats
  Future<void> loadUserData(String userId) async {
    try {
      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _userProfile = userDoc.data();
        _personalityTraits = List<String>.from(_userProfile?['personalityTraits'] ?? []);
      }

      // Load reading stats
      await _loadReadingStats(userId);
      await _loadWeeklyProgress(userId);
      
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Load reading statistics
  Future<void> _loadReadingStats(String userId) async {
    try {
      // Get all reading progress for this user
      final progressQuery = await _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .get();

      _totalBooksRead = progressQuery.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;

      _totalReadingMinutes = progressQuery.docs
          .map((doc) => doc.data()['readingTimeMinutes'] as int? ?? 0)
          .fold(0, (sum, minutes) => sum + minutes);

      // Calculate reading streak
      await _calculateReadingStreak(userId);
    } catch (e) {
      print('Error loading reading stats: $e');
    }
  }

  // Calculate daily reading streak
  Future<void> _calculateReadingStreak(String userId) async {
    try {
      final now = DateTime.now();
      int streak = 0;
      
      // Check each day backwards from today
      for (int i = 0; i < 30; i++) { // Check last 30 days max
        final checkDate = now.subtract(Duration(days: i));
        final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        try {
          final dayProgressQuery = await _firestore
              .collection('reading_progress')
              .where('userId', isEqualTo: userId)
              .where('lastReadAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
              .where('lastReadAt', isLessThan: Timestamp.fromDate(dayEnd))
              .get();

          if (dayProgressQuery.docs.isNotEmpty) {
            // User read something this day
            if (i == 0 || streak == i) {
              streak++;
            } else {
              break; // Streak broken
            }
          } else if (i == 0) {
            // No reading today, streak is 0
            break;
          } else {
            // Streak broken on a previous day
            break;
          }
        } catch (queryError) {
          print('Error querying reading progress for streak calculation: $queryError');
          // If query fails due to index issues, break the loop
          break;
        }
      }

      _dailyReadingStreak = streak;
    } catch (e) {
      print('Error calculating reading streak: $e');
      _dailyReadingStreak = 0;
    }
  }

  // Load weekly reading progress
  Future<void> _loadWeeklyProgress(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
      _weeklyProgress.clear();

      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        try {
          final dayProgressQuery = await _firestore
              .collection('reading_progress')
              .where('userId', isEqualTo: userId)
              .where('lastReadAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
              .where('lastReadAt', isLessThan: Timestamp.fromDate(dayEnd))
              .get();

          int dayMinutes = 0;
          for (final doc in dayProgressQuery.docs) {
            dayMinutes += (doc.data()['readingTimeMinutes'] as int? ?? 0);
          }

          final dayKey = _getDayKey(day);
          _weeklyProgress[dayKey] = dayMinutes;
        } catch (queryError) {
          print('Error querying weekly progress for day $i: $queryError');
          // Set default value for this day if query fails
          final dayKey = _getDayKey(day);
          _weeklyProgress[dayKey] = 0;
        }
      }
    } catch (e) {
      print('Error loading weekly progress: $e');
      // Initialize with empty progress if loading fails
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
      print('Error updating personality traits: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);
      
      // Update local profile
      if (_userProfile != null) {
        _userProfile!.addAll(updates);
      }
      
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('Error updating user profile: $e');
    }
  }

  // Record reading session
  Future<void> recordReadingSession({
    required String userId,
    required String bookId,
    required int minutesRead,
  }) async {
    try {
      // This will be called by BookProvider when updating progress
      // Refresh user stats after recording
      await loadUserData(userId);
    } catch (e) {
      print('Error recording reading session: $e');
    }
  }

  // Get reading goal progress (placeholder for future implementation)
  double getDailyGoalProgress() {
    final todayMinutes = getTodayReadingMinutes();
    const dailyGoal = 15; // 15 minutes default goal
    return (todayMinutes / dailyGoal).clamp(0.0, 1.0);
  }

  // Get achievement status (placeholder for future implementation)
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
    Future.delayed(Duration.zero, () => notifyListeners());
  }
}