// File: lib/services/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../utils/date_utils.dart';
import 'logger.dart';

class AnalyticsService {
  final FirebaseService _firebase = FirebaseService();

  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

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
      appLog('Skipping short reading session (${sessionDurationSeconds}s - need 300s minimum)', level: 'DEBUG');
      return;
    }

    try {
      await _firebase.firestore.collection('reading_sessions').add({
        'userId': user.uid,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'pageNumber': pageNumber,
        'totalPages': totalPages,
        'sessionDurationSeconds': sessionDurationSeconds,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'progressPercentage': pageNumber / totalPages,
        'createdAt': FieldValue.serverTimestamp(),
      });
      appLog('Tracked reading session: ${sessionDurationSeconds}s for $bookTitle', level: 'INFO');
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
      
      final sessionsQuery = await _firebase.firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('createdAt', descending: true)
          .get();

      final sessions = sessionsQuery.docs.map((doc) => doc.data()).toList();

      // Calculate metrics
      final totalSessions = sessions.length;
      final totalReadingTime = sessions.fold<int>(
        0,
        (total, session) => total + (session['sessionDurationSeconds'] as int? ?? 0),
      );
      
      final uniqueBooks = sessions
          .map((session) => session['bookId'])
          .toSet()
          .length;

      final averageSessionLength = totalSessions > 0 
          ? totalReadingTime / totalSessions 
          : 0;

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
  Future<List<Map<String, dynamic>>> _getWeeklyReadingData(String userId) async {
    final weeklyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final range = AppDateUtils.getDayRange(date);

      final daySessionsQuery = await _firebase.firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
          .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
          .get();

      final dayTotalTime = daySessionsQuery.docs.fold<int>(
        0,
        (total, doc) => total + (doc.data()['sessionDurationSeconds'] as int? ?? 0),
      );

      weeklyData.add({
        'date': AppDateUtils.formatDateKey(date),
        'readingTimeMinutes': (dayTotalTime / 60).round(),
        'sessionCount': daySessionsQuery.docs.length,
      });
    }

    return weeklyData;
  }

  // Calculate reading streak (uses AppDateUtils for date handling)
  Future<int> _calculateReadingStreak(String userId) async {
    try {
      final now = DateTime.now();
      int streak = 0;

      for (int i = 0; i < 365; i++) { // Check up to a year
        final checkDate = now.subtract(Duration(days: i));
        final range = AppDateUtils.getDayRange(checkDate);

        final daySessionsQuery = await _firebase.firestore
            .collection('reading_sessions')
            .where('userId', isEqualTo: userId)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
            .where('createdAt', isLessThan: Timestamp.fromDate(range.end))
            .limit(1)
            .get();

        if (daySessionsQuery.docs.isNotEmpty) {
          if (i == 0 || streak == i) {
            streak++;
          } else {
            break;
          }
        } else if (i == 0) {
          break; // No reading today
        } else {
          break; // Streak broken
        }
      }

      return streak;
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
      final bookTitles = <String, String>{};

      for (final doc in interactionsQuery.docs) {
        final data = doc.data();
        final bookId = data['bookId'] as String;
        bookCounts[bookId] = (bookCounts[bookId] ?? 0) + 1;
        
        // Get book title if we don't have it
        if (!bookTitles.containsKey(bookId)) {
          try {
            final bookDoc = await _firebase.firestore.collection('books').doc(bookId).get();
            if (bookDoc.exists) {
              bookTitles[bookId] = bookDoc.data()?['title'] ?? 'Unknown';
            }
          } catch (e) {
            bookTitles[bookId] = 'Unknown';
          }
        }
      }

      final sortedBooks = bookCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedBooks.take(10).map((entry) => {
        'bookId': entry.key,
        'title': bookTitles[entry.key] ?? 'Unknown',
        'readCount': entry.value,
      }).toList();
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
  Future<List<Map<String, dynamic>>> _getRecentlyReadBooks(String userId) async {
    try {
      final sessionsQuery = await _firebase.firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final recentBooks = <Map<String, dynamic>>[];
      final seenBooks = <String>{};

      for (final doc in sessionsQuery.docs) {
        final data = doc.data();
        final bookId = data['bookId'] as String;
        
        if (!seenBooks.contains(bookId)) {
          seenBooks.add(bookId);
          recentBooks.add({
            'bookId': bookId,
            'bookTitle': data['bookTitle'] ?? 'Unknown',
            'lastReadAt': data['createdAt'],
            'progressPercentage': data['progressPercentage'] ?? 0.0,
          });
        }
      }

      return recentBooks;
    } catch (e) {
      appLog('Error getting recently read books: $e', level: 'ERROR');
      return [];
    }
  }

  // Get recent achievements
  Future<List<Map<String, dynamic>>> _getRecentAchievements(String userId) async {
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
