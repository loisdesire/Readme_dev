// File: lib/services/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Track reading session
  Future<void> trackReadingSession({
    required String bookId,
    required String bookTitle,
    required int pageNumber,
    required int totalPages,
    required int sessionDurationSeconds,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('reading_sessions').add({
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
    } catch (e) {
      print('Error tracking reading session: $e');
    }
  }

  // Track quiz completion
  Future<void> trackQuizCompletion({
    required Map<String, int> traitScores,
    required List<String> dominantTraits,
    required int totalQuestions,
    required int timeSpentSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('quiz_analytics').add({
        'userId': user.uid,
        'traitScores': traitScores,
        'dominantTraits': dominantTraits,
        'totalQuestions': totalQuestions,
        'timeSpentSeconds': timeSpentSeconds,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking quiz completion: $e');
    }
  }

  // Track book interaction
  Future<void> trackBookInteraction({
    required String bookId,
    required String action, // 'view', 'start_reading', 'favorite', 'complete'
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('book_interactions').add({
        'userId': user.uid,
        'bookId': bookId,
        'action': action,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking book interaction: $e');
    }
  }

  // Track app usage
  Future<void> trackAppSession({
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String screenName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final sessionDuration = sessionEnd.difference(sessionStart).inSeconds;
      
      await _firestore.collection('app_sessions').add({
        'userId': user.uid,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'sessionDurationSeconds': sessionDuration,
        'screenName': screenName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking app session: $e');
    }
  }

  // Get user reading analytics
  Future<Map<String, dynamic>> getUserReadingAnalytics(String userId) async {
    try {
      // Get reading sessions from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final sessionsQuery = await _firestore
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
        (sum, session) => sum + (session['sessionDurationSeconds'] as int? ?? 0),
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
      print('Error getting user reading analytics: $e');
      return {};
    }
  }

  // Get weekly reading data
  Future<List<Map<String, dynamic>>> _getWeeklyReadingData(String userId) async {
    final weeklyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final daySessionsQuery = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      final dayTotalTime = daySessionsQuery.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc.data()['sessionDurationSeconds'] as int? ?? 0),
      );

      weeklyData.add({
        'date': dayStart.toIso8601String().split('T')[0],
        'readingTimeMinutes': (dayTotalTime / 60).round(),
        'sessionCount': daySessionsQuery.docs.length,
      });
    }

    return weeklyData;
  }

  // Calculate reading streak
  Future<int> _calculateReadingStreak(String userId) async {
    try {
      final now = DateTime.now();
      int streak = 0;

      for (int i = 0; i < 365; i++) { // Check up to a year
        final checkDate = now.subtract(Duration(days: i));
        final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final daySessionsQuery = await _firestore
            .collection('reading_sessions')
            .where('userId', isEqualTo: userId)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
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
      print('Error calculating reading streak: $e');
      return 0;
    }
  }

  // Get book popularity analytics
  Future<List<Map<String, dynamic>>> getBookPopularityAnalytics() async {
    try {
      final interactionsQuery = await _firestore
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
            final bookDoc = await _firestore.collection('books').doc(bookId).get();
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
      print('Error getting book popularity analytics: $e');
      return [];
    }
  }

  // Track achievement unlock
  Future<void> trackAchievementUnlock({
    required String achievementId,
    required String achievementName,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('achievement_unlocks').add({
        'userId': user.uid,
        'achievementId': achievementId,
        'achievementName': achievementName,
        'category': category,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking achievement unlock: $e');
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
      print('Error getting parent analytics: $e');
      return {};
    }
  }

  // Get recently read books
  Future<List<Map<String, dynamic>>> _getRecentlyReadBooks(String userId) async {
    try {
      final sessionsQuery = await _firestore
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
      print('Error getting recently read books: $e');
      return [];
    }
  }

  // Get recent achievements
  Future<List<Map<String, dynamic>>> _getRecentAchievements(String userId) async {
    try {
      final achievementsQuery = await _firestore
          .collection('achievement_unlocks')
          .where('userId', isEqualTo: userId)
          .orderBy('unlockedAt', descending: true)
          .limit(5)
          .get();

      return achievementsQuery.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting recent achievements: $e');
      return [];
    }
  }
}
