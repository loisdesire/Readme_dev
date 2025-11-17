// File: lib/services/firestore_helpers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../utils/date_utils.dart';
import 'logger.dart';

/// Helper class for common Firestore query patterns.
///
/// This class provides reusable query methods to eliminate duplicate
/// query code across providers and services.
///
/// Usage:
/// ```dart
/// final helpers = FirestoreHelpers();
///
/// // Get reading sessions for today
/// final range = AppDateUtils.getDayRange(DateTime.now());
/// final sessions = await helpers.getReadingSessions(
///   userId: userId,
///   startDate: range.start,
///   endDate: range.end,
/// );
/// ```
class FirestoreHelpers {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  // Singleton pattern
  static final FirestoreHelpers _instance = FirestoreHelpers._internal();
  factory FirestoreHelpers() => _instance;
  FirestoreHelpers._internal();

  /// Query reading sessions for a user within a date range
  ///
  /// [userId] - The user ID to query sessions for
  /// [startDate] - Optional start date for filtering (inclusive)
  /// [endDate] - Optional end date for filtering (exclusive)
  /// [limit] - Optional limit on number of results
  /// [orderDescending] - Whether to order by timestamp descending (default: true)
  ///
  /// Returns a QuerySnapshot containing matching reading sessions.
  ///
  /// Example:
  /// ```dart
  /// // Get last 5 reading sessions
  /// final sessions = await helpers.getReadingSessions(
  ///   userId: 'user123',
  ///   limit: 5,
  /// );
  ///
  /// // Get sessions from last 7 days
  /// final weekAgo = DateTime.now().subtract(Duration(days: 7));
  /// final recentSessions = await helpers.getReadingSessions(
  ///   userId: 'user123',
  ///   startDate: weekAgo,
  /// );
  /// ```
  Future<QuerySnapshot> getReadingSessions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    bool orderDescending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt',
            isLessThan: Timestamp.fromDate(endDate));
      }

      // Order by createdAt (for ordering to work with where clause)
      query = query.orderBy('createdAt', descending: orderDescending);

      if (limit != null) {
        query = query.limit(limit);
      }

      return await query.get();
    } catch (e) {
      appLog('Error getting reading sessions: $e', level: 'ERROR');
      rethrow;
    }
  }

  /// Query reading progress for a user within a date range
  ///
  /// [userId] - The user ID to query progress for
  /// [startDate] - Optional start date for filtering (inclusive)
  /// [endDate] - Optional end date for filtering (exclusive)
  /// [completedOnly] - If true, only return completed books
  /// [ongoingOnly] - If true, only return books in progress
  /// [bookId] - Optional filter for a specific book
  ///
  /// Returns a QuerySnapshot containing matching reading progress records.
  ///
  /// Example:
  /// ```dart
  /// // Get all completed books
  /// final completed = await helpers.getReadingProgress(
  ///   userId: 'user123',
  ///   completedOnly: true,
  /// );
  ///
  /// // Get progress for a specific book
  /// final bookProgress = await helpers.getReadingProgress(
  ///   userId: 'user123',
  ///   bookId: 'book456',
  /// );
  /// ```
  Future<QuerySnapshot> getReadingProgress({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    bool? completedOnly,
    bool? ongoingOnly,
    String? bookId,
  }) async {
    try {
      Query query = _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId);

      if (bookId != null) {
        query = query.where('bookId', isEqualTo: bookId);
      }

      if (startDate != null) {
        query = query.where('lastReadAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('lastReadAt',
            isLessThan: Timestamp.fromDate(endDate));
      }

      if (completedOnly == true) {
        query = query.where('isCompleted', isEqualTo: true);
      } else if (ongoingOnly == true) {
        query = query.where('isCompleted', isEqualTo: false);
      }

      return await query.get();
    } catch (e) {
      appLog('Error getting reading progress: $e', level: 'ERROR');
      rethrow;
    }
  }

  /// Check if user has any reading activity on a specific day
  ///
  /// This checks both reading_progress and reading_sessions collections
  /// to determine if the user had any ACTUAL reading activity (not just opening a book).
  ///
  /// For reading_progress: Only counts if progress > 1% or currentPage > 1
  /// For reading_sessions: Any session with duration > 0 counts
  ///
  /// [userId] - The user ID to check
  /// [date] - The date to check for activity
  ///
  /// Returns true if there was any reading activity, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final hasReadToday = await helpers.hasReadingActivityOnDay(
  ///   userId: 'user123',
  ///   date: DateTime.now(),
  /// );
  /// ```
  Future<bool> hasReadingActivityOnDay({
    required String userId,
    required DateTime date,
  }) async {
    try {
      final range = AppDateUtils.getDayRange(date);

      // Check reading progress - validate actual progress was made
      final progressQuery = await getReadingProgress(
        userId: userId,
        startDate: range.start,
        endDate: range.end,
      );

      if (progressQuery.docs.isNotEmpty) {
        // Validate that ACTUAL reading occurred (not just opened book)
        for (final doc in progressQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final progressPercent = (data['progressPercentage'] as num?)?.toDouble() ?? 0.0;
          final readingTimeMinutes = (data['readingTimeMinutes'] as int?) ?? 0;

          // For PDF reading: Count if they made progress OR spent time reading
          // Page numbers don't matter for PDFs
          if (progressPercent > 0.0 || readingTimeMinutes > 0) {
            return true;
          }
        }
      }

      // Check reading sessions - any session counts
      final sessionsQuery = await getReadingSessions(
        userId: userId,
        startDate: range.start,
        endDate: range.end,
        limit: 1,
      );

      return sessionsQuery.docs.isNotEmpty;
    } catch (e) {
      appLog('Error checking reading activity: $e', level: 'ERROR');
      return false;
    }
  }

  /// Get total reading minutes for a user on a specific day
  ///
  /// Aggregates reading time from both reading_progress and reading_sessions.
  ///
  /// [userId] - The user ID
  /// [date] - The date to calculate minutes for
  ///
  /// Returns the total reading minutes for that day.
  ///
  /// Example:
  /// ```dart
  /// final minutesToday = await helpers.getDailyReadingMinutes(
  ///   userId: 'user123',
  ///   date: DateTime.now(),
  /// );
  /// ```
  Future<int> getDailyReadingMinutes({
    required String userId,
    required DateTime date,
  }) async {
    try {
      final range = AppDateUtils.getDayRange(date);
      int totalMinutes = 0;

      // Get minutes from reading_progress
      final progressQuery = await getReadingProgress(
        userId: userId,
        startDate: range.start,
        endDate: range.end,
      );

      for (final doc in progressQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalMinutes += (data['readingTimeMinutes'] as int? ?? 0);
      }

      // Get minutes from reading_sessions
      final sessionsQuery = await getReadingSessions(
        userId: userId,
        startDate: range.start,
        endDate: range.end,
      );

      for (final doc in sessionsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final seconds = data['sessionDurationSeconds'] as int? ?? 0;
        totalMinutes += (seconds / 60).round();
      }

      // If there are records but no minutes, ensure at least 1 minute is counted
      final hasRecords = progressQuery.docs.isNotEmpty || sessionsQuery.docs.isNotEmpty;
      if (totalMinutes == 0 && hasRecords) {
        // Check if there's actual progress (not just opened)
        bool hasActualProgress = false;
        for (final doc in progressQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final progressPercent = (data['progressPercentage'] as double? ?? 0.0);
          // For PDF reading: any progress > 0% means they read
          // Page numbers don't matter for PDFs
          if (progressPercent > 0.0) {
            hasActualProgress = true;
            break;
          }
        }
        if (hasActualProgress || sessionsQuery.docs.isNotEmpty) {
          totalMinutes = 1;
        }
      }

      return totalMinutes;
    } catch (e) {
      appLog('Error getting daily reading minutes: $e', level: 'ERROR');
      return 0;
    }
  }

  /// Get weekly reading data for a user
  ///
  /// Returns a map of day keys (Mon, Tue, etc.) to reading minutes.
  ///
  /// [userId] - The user ID
  /// [weekStart] - Optional start of week (defaults to current week's Monday)
  ///
  /// Returns a map like: {'Mon': 15, 'Tue': 0, 'Wed': 20, ...}
  ///
  /// Example:
  /// ```dart
  /// final weeklyData = await helpers.getWeeklyReadingData(userId: 'user123');
  /// print(weeklyData['Mon']); // Minutes read on Monday
  /// ```
  Future<Map<String, int>> getWeeklyReadingData({
    required String userId,
    DateTime? weekStart,
  }) async {
    try {
      final start = weekStart ?? AppDateUtils.startOfWeek(DateTime.now());
      final weeklyProgress = <String, int>{};

      for (int i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        final dayKey = AppDateUtils.getDayKey(day);

        final minutes = await getDailyReadingMinutes(
          userId: userId,
          date: day,
        );

        weeklyProgress[dayKey] = minutes;
      }

      return weeklyProgress;
    } catch (e) {
      appLog('Error getting weekly reading data: $e', level: 'ERROR');
      return {};
    }
  }

  /// Calculate consecutive reading streak for a user
  ///
  /// Counts consecutive days with reading activity, ending today if
  /// user read today, otherwise ending yesterday.
  ///
  /// OPTIMIZED: Fetches all data in 2 batch queries instead of N*2 queries.
  ///
  /// [userId] - The user ID
  /// [lookbackDays] - Maximum days to look back (default: 365)
  ///
  /// Returns the streak count and a list of booleans for recent days
  /// [today, yesterday, day-2, ...] where true = read that day.
  ///
  /// Example:
  /// ```dart
  /// final result = await helpers.calculateReadingStreak(userId: 'user123');
  /// print('Streak: ${result['streak']} days');
  /// print('Read today: ${result['days'][0]}');
  /// ```
  Future<Map<String, dynamic>> calculateReadingStreak({
    required String userId,
    int lookbackDays = 365,
  }) async {
    try {
      appLog('Calculating reading streak for user: $userId', level: 'DEBUG');
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: lookbackDays));

      // OPTIMIZATION: Fetch all data at once instead of per-day queries
      final progressQuery = await getReadingProgress(
        userId: userId,
        startDate: startDate,
      );

      final sessionsQuery = await getReadingSessions(
        userId: userId,
        startDate: startDate,
      );

      // Build a map of date -> hasActivity for quick lookup
      final activityByDate = <String, bool>{};

      // Process progress records
      for (final doc in progressQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lastReadAt = (data['lastReadAt'] as Timestamp?)?.toDate();
        if (lastReadAt != null) {
          final dateKey = AppDateUtils.formatDateKey(lastReadAt);
          final progressPercent = (data['progressPercentage'] as num?)?.toDouble() ?? 0.0;

          final readingTimeMinutes = (data['readingTimeMinutes'] as int?) ?? 0;

          // For PDF reading: Count as "read" if they made actual progress OR spent time reading
          // - progressPercent > 0% = they read and progress was saved
          // - readingTimeMinutes > 0 = they spent time reading
          // - Page numbers don't matter for PDFs (can start anywhere)
          if (progressPercent > 0.0 || readingTimeMinutes > 0) {
            activityByDate[dateKey] = true;
          }
        }
      }

      // Process session records
      for (final doc in sessionsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey = AppDateUtils.formatDateKey(createdAt);
          activityByDate[dateKey] = true;
        }
      }

      // Now check each day going backwards from today
      int streak = 0;
      bool todayRead = false;
      List<bool> streakDays = [];

      for (int i = 0; i < lookbackDays; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateKey = AppDateUtils.formatDateKey(checkDate);
        final hasActivity = activityByDate[dateKey] ?? false;

        if (hasActivity) {
          streakDays.add(true);
          if (i == 0) todayRead = true;
        } else {
          if (i == 0) {
            // Today has no reading, add false but continue checking
            streakDays.add(false);
          } else {
            // Past day with no reading breaks the streak
            break;
          }
        }
      }

      // Calculate streak: count consecutive days read (excluding today if not read)
      if (todayRead) {
        streak = streakDays.takeWhile((day) => day == true).length;
      } else {
        // Today not read, count from yesterday backwards
        for (int i = 1; i < streakDays.length; i++) {
          if (streakDays[i] == true) {
            streak++;
          } else {
            break;
          }
        }
      }

      return {
        'streak': streak,
        'days': streakDays,
        'todayRead': todayRead,
      };
    } catch (e) {
      appLog('Error calculating reading streak: $e', level: 'ERROR');
      return {
        'streak': 0,
        'days': <bool>[],
        'todayRead': false,
      };
    }
  }
}
