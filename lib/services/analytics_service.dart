// File: lib/services/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../utils/date_utils.dart';
import 'firestore_helpers.dart';
import 'logger.dart';

class AnalyticsService {
  final FirebaseService _firebase = FirebaseService();

  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  DateTime? _extractSessionTimestamp(Map<String, dynamic> data) {
    final sessionStart = (data['sessionStart'] as Timestamp?)?.toDate();
    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return sessionStart ?? startTime ?? createdAt;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getReadingSessionDocsTolerant({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      Query<Map<String, dynamic>> query = _firebase.firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query =
            query.where('createdAt', isLessThan: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('createdAt', descending: true);
      if (limit != null) query = query.limit(limit);

      final snap = await query.get();
      for (final doc in snap.docs) {
        byId[doc.id] = doc;
      }
    } catch (e) {
      appLog('Error querying reading sessions by createdAt: $e', level: 'WARN');
    }

    try {
      Query<Map<String, dynamic>> query = _firebase.firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query =
            query.where('startTime', isLessThan: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('startTime', descending: true);
      if (limit != null) query = query.limit(limit);

      final snap = await query.get();
      for (final doc in snap.docs) {
        byId[doc.id] = doc;
      }
    } catch (e) {
      // startTime is legacy/fallback; ignore if missing/unindexed.
      appLog('Error querying reading sessions by startTime: $e',
          level: 'DEBUG');
    }

    final docs = byId.values.toList();
    docs.sort((a, b) {
      final at = _extractSessionTimestamp(a.data()) ?? DateTime(1970);
      final bt = _extractSessionTimestamp(b.data()) ?? DateTime(1970);
      return bt.compareTo(at);
    });

    if (limit != null && docs.length > limit) {
      return docs.take(limit).toList();
    }

    return docs;
  }

  int _extractSessionDurationSeconds(Map<String, dynamic> session) {
    final seconds = session['sessionDurationSeconds'];
    if (seconds is int && seconds > 0) return seconds;
    if (seconds is num && seconds > 0) return seconds.toInt();

    final minutes =
        session['sessionDurationMinutes'] ?? session['durationMinutes'];
    if (minutes is int && minutes > 0) return minutes * 60;
    if (minutes is num && minutes > 0) return (minutes.toDouble() * 60).round();

    return 0;
  }

  // Track reading session (only sessions 5+ minutes are tracked for achievements)
  Future<void> trackReadingSession({
    required String bookId,
    required String bookTitle,
    required int pageNumber,
    required int totalPages,
    required int sessionDurationSeconds,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    // Only track sessions that are 5 minutes or longer (300 seconds)
    if (sessionDurationSeconds < 300) {
      appLog(
          'Skipping short reading session (${sessionDurationSeconds}s - need 300s minimum)',
          level: 'DEBUG');
      return;
    }

    try {
      final sessionDurationMinutes = (sessionDurationSeconds / 60).floor();

      await _firebase.firestore.collection('reading_sessions').add({
        'userId': user.uid,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'pageNumber': pageNumber,
        'totalPages': totalPages,
        'sessionDurationSeconds': sessionDurationSeconds,
        'sessionDurationMinutes': sessionDurationMinutes,
        'durationMinutes': sessionDurationMinutes,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'startTime': Timestamp.fromDate(sessionStart),
        'endTime': Timestamp.fromDate(sessionEnd),
        'progressPercentage': pageNumber / totalPages,
        'createdAt': FieldValue.serverTimestamp(),
      });
      appLog(
          'Tracked reading session: ${sessionDurationSeconds}s for $bookTitle',
          level: 'INFO');
    } catch (e) {
      appLog('Error tracking reading session: $e', level: 'ERROR');
    }
  }

  // Track quiz completion
  Future<void> trackQuizCompletion({
    required Map<String, int> traitScores,
    required List<String> dominantTraits,
    required int totalQuestions,
    required int timeSpentSeconds,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firebase.firestore.collection('quiz_analytics').add({
        'userId': user.uid,
        'traitScores': traitScores,
        'dominantTraits': dominantTraits,
        'totalQuestions': totalQuestions,
        'timeSpentSeconds': timeSpentSeconds,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('Error tracking quiz completion: $e', level: 'ERROR');
    }
  }

  // Track book interaction
  Future<void> trackBookInteraction({
    required String bookId,
    required String action, // 'view', 'start_reading', 'favorite', 'complete'
    Map<String, dynamic>? metadata,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firebase.firestore.collection('book_interactions').add({
        'userId': user.uid,
        'bookId': bookId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('Error tracking book interaction: $e', level: 'ERROR');
    }
  }

  // Track app usage
  Future<void> trackAppSession({
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String screenName,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      final sessionDuration = sessionEnd.difference(sessionStart).inSeconds;

      await _firebase.firestore.collection('app_sessions').add({
        'userId': user.uid,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'sessionDurationSeconds': sessionDuration,
        'screenName': screenName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('Error tracking app session: $e', level: 'ERROR');
    }
  }

  // Get user reading analytics
  Future<Map<String, dynamic>> getUserReadingAnalytics(String userId) async {
    try {
      // Get reading sessions from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final sessionDocs = await _getReadingSessionDocsTolerant(
        userId: userId,
        startDate: thirtyDaysAgo,
      );
      final sessions = sessionDocs.map((doc) => doc.data()).toList();

      // Calculate metrics
      final totalSessions = sessions.length;
      final totalReadingTime = sessions.fold<int>(
        0,
        (total, session) => total + _extractSessionDurationSeconds(session),
      );

      final uniqueBooks =
          sessions.map((session) => session['bookId']).toSet().length;

      final averageSessionLength =
          totalSessions > 0 ? totalReadingTime / totalSessions : 0;

      // Get daily reading data for the last 7 days
      final weeklyData = await _getWeeklyReadingData(userId);

      // Get reading streak
      final streak = await _calculateReadingStreak(userId);

      return {
        'totalSessions': totalSessions,
        'totalReadingTimeSeconds': totalReadingTime,
        'totalReadingTimeMinutes': (totalReadingTime / 60).round(),
        'uniqueBooksRead': uniqueBooks,
        'averageSessionLengthSeconds': averageSessionLength.round(),
        'weeklyData': weeklyData,
        'currentStreak': streak,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      appLog('Error getting user reading analytics: $e', level: 'ERROR');
      return {};
    }
  }

  // Get weekly reading data (uses AppDateUtils for date handling)
  Future<List<Map<String, dynamic>>> _getWeeklyReadingData(
      String userId) async {
    final weeklyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    final helpers = FirestoreHelpers();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final range = AppDateUtils.getDayRange(date);

      final minutes = await helpers.getDailyReadingMinutes(
        userId: userId,
        date: date,
      );

      final sessionCount = await _getSessionCountForRange(
        userId: userId,
        start: range.start,
        end: range.end,
      );

      weeklyData.add({
        'date': AppDateUtils.formatDateKey(date),
        'readingTimeMinutes': minutes,
        'sessionCount': sessionCount,
      });
    }

    return weeklyData;
  }

  Future<int> _getSessionCountForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final docs = await _getReadingSessionDocsTolerant(
      userId: userId,
      startDate: start,
      endDate: end,
    );
    return docs.length;
  }

  // Calculate reading streak (uses AppDateUtils for date handling)
  Future<int> _calculateReadingStreak(String userId) async {
    try {
      final result = await FirestoreHelpers().calculateReadingStreak(
        userId: userId,
      );
      return result['streak'] as int? ?? 0;
    } catch (e) {
      appLog('Error calculating reading streak: $e', level: 'ERROR');
      return 0;
    }
  }

  // Get book popularity analytics
  Future<List<Map<String, dynamic>>> getBookPopularityAnalytics() async {
    try {
      final interactionsQuery = await _firebase.firestore
          .collection('book_interactions')
          .where('action', isEqualTo: 'start_reading')
          .get();

      final bookCounts = <String, int>{};

      for (final doc in interactionsQuery.docs) {
        final data = doc.data();
        final bookId = data['bookId'] as String;
        bookCounts[bookId] = (bookCounts[bookId] ?? 0) + 1;
      }

      final sortedBooks = bookCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topIds = sortedBooks.take(10).map((e) => e.key).toList();
      final bookTitles = <String, String>{};

      if (topIds.isNotEmpty) {
        try {
          final snap = await _firebase.firestore
              .collection('books')
              .where(FieldPath.documentId, whereIn: topIds)
              .get();

          for (final doc in snap.docs) {
            final data = doc.data();
            bookTitles[doc.id] = data['title'] as String? ?? 'Unknown';
          }
        } catch (e) {
          appLog('Error batching book title lookup: $e', level: 'WARN');
        }
      }

      return sortedBooks
          .take(10)
          .map((entry) => {
                'bookId': entry.key,
                'title': bookTitles[entry.key] ?? 'Unknown',
                'readCount': entry.value,
              })
          .toList();
    } catch (e) {
      appLog('Error getting book popularity analytics: $e', level: 'ERROR');
      return [];
    }
  }

  // Track achievement unlock
  Future<void> trackAchievementUnlock({
    required String achievementId,
    required String achievementName,
    required String category,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firebase.firestore.collection('achievement_unlocks').add({
        'userId': user.uid,
        'achievementId': achievementId,
        'achievementName': achievementName,
        'category': category,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('Error tracking achievement unlock: $e', level: 'ERROR');
    }
  }

  // Get parent analytics for child
  Future<Map<String, dynamic>> getParentAnalytics(String childUserId) async {
    try {
      final analytics = await getUserReadingAnalytics(childUserId);

      // Get additional parent-specific metrics
      final recentBooks = await _getRecentlyReadBooks(childUserId);
      final achievements = await _getRecentAchievements(childUserId);

      return {
        ...analytics,
        'recentBooks': recentBooks,
        'recentAchievements': achievements,
      };
    } catch (e) {
      appLog('Error getting parent analytics: $e', level: 'ERROR');
      return {};
    }
  }

  // Get recently read books
  Future<List<Map<String, dynamic>>> _getRecentlyReadBooks(
      String userId) async {
    try {
      // Grab a bit more than needed so we can dedupe by bookId.
      final sessionDocs = await _getReadingSessionDocsTolerant(
        userId: userId,
        limit: 25,
      );

      final recentBooks = <Map<String, dynamic>>[];
      final seenBooks = <String>{};

      for (final doc in sessionDocs) {
        final data = doc.data();
        final bookId = data['bookId'] as String;

        if (!seenBooks.contains(bookId)) {
          seenBooks.add(bookId);
          recentBooks.add({
            'bookId': bookId,
            'bookTitle': data['bookTitle'] ?? 'Unknown',
            'lastReadAt':
                data['createdAt'] ?? data['startTime'] ?? data['sessionStart'],
            'progressPercentage': data['progressPercentage'] ?? 0.0,
          });

          if (recentBooks.length >= 5) break;
        }
      }

      return recentBooks;
    } catch (e) {
      appLog('Error getting recently read books: $e', level: 'ERROR');
      return [];
    }
  }

  // Get recent achievements
  Future<List<Map<String, dynamic>>> _getRecentAchievements(
      String userId) async {
    try {
      final achievementsQuery = await _firebase.firestore
          .collection('achievement_unlocks')
          .where('userId', isEqualTo: userId)
          .orderBy('unlockedAt', descending: true)
          .limit(5)
          .get();

      return achievementsQuery.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      appLog('Error getting recent achievements: $e', level: 'ERROR');
      return [];
    }
  }
}
