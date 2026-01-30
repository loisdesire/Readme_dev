// File: lib/services/api_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger.dart';

class ApiService {
  static const String baseUrl = 'https://your-api-endpoint.com/api/v1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<QuerySnapshot<Map<String, dynamic>>> _getRecentReadingSessions({
    required String userId,
    required int limit,
  }) async {
    try {
      final snap = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (snap.docs.isNotEmpty) return snap;
    } catch (e) {
      appLog('[API_SERVICE] Error fetching sessions by createdAt: $e',
          level: 'WARN');
    }

    try {
      return await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();
    } catch (e) {
      appLog('[API_SERVICE] Error fetching sessions by startTime: $e',
          level: 'WARN');
      return await _firestore
          .collection('reading_sessions')
          .where(FieldPath.documentId, isEqualTo: '__never__')
          .limit(1)
          .get();
    }
  }

  // HTTP methods and utilities can be added here when needed

  Future<List<Map<String, dynamic>>> _getBooksByIdsPreservingOrder(
    List<String> bookIds,
  ) async {
    if (bookIds.isEmpty) return const [];

    final resultsById = <String, Map<String, dynamic>>{};

    // Firestore whereIn has a max of 10.
    for (int i = 0; i < bookIds.length; i += 10) {
      final chunk = bookIds.sublist(
        i,
        (i + 10) > bookIds.length ? bookIds.length : (i + 10),
      );

      final snap = await _firestore
          .collection('books')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        resultsById[doc.id] = {
          'id': doc.id,
          ...doc.data(),
        };
      }
    }

    final ordered = <Map<String, dynamic>>[];
    for (final id in bookIds) {
      final book = resultsById[id];
      if (book != null) ordered.add(book);
    }
    return ordered;
  }

  // Book-related API calls
  Future<List<Map<String, dynamic>>> getRecommendedBooks(List<String> traits,
      {String? userId}) async {
    try {
      // First, try to get AI-generated recommendations from user document
      if (userId != null && userId.isNotEmpty) {
        try {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            final aiRecommendations = userData?['aiRecommendations'] as List?;

            // Use AI recommendations if they exist (no time restriction)
            if (aiRecommendations != null && aiRecommendations.isNotEmpty) {
              // Fetch the recommended books by ID
              final bookIds = aiRecommendations.cast<String>();

              appLog(
                  '[API_SERVICE] Fetching ${bookIds.length} AI-recommended books: ${bookIds.join(", ")}',
                  level: 'INFO');

              final books = await _getBooksByIdsPreservingOrder(bookIds);

              if (books.isNotEmpty) {
                appLog(
                    '[API_SERVICE] Returning ${books.length} AI-recommended books',
                    level: 'INFO');
                return books;
              }
            } else {
              appLog(
                  '[API_SERVICE] No AI recommendations found in user document',
                  level: 'WARN');
            }
          } else {
            appLog(
                '[API_SERVICE] User document does not exist for userId: $userId',
                level: 'WARN');
          }
        } catch (e) {
          appLog('[API_SERVICE] Error fetching AI recommendations: $e',
              level: 'ERROR');
          // If AI recommendations fail, fall through to trait-based matching
        }
      }

      // Fallback: use trait-based matching if AI recommendations are not available
      final query = await _firestore
          .collection('books')
          .where('traits', arrayContainsAny: traits)
          .limit(10)
          .get();

      return query.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      throw ApiException('Failed to get recommendations: $e');
    }
  }

  Future<Map<String, dynamic>> getBookContent(String bookId) async {
    try {
      final doc = await _firestore.collection('books').doc(bookId).get();
      if (!doc.exists) {
        throw ApiException('Book not found');
      }
      return {
        'id': doc.id,
        ...doc.data()!,
      };
    } catch (e) {
      throw ApiException('Failed to get book content: $e');
    }
  }

  // Analytics API calls
  Future<void> trackReadingSession({
    required String userId,
    required String bookId,
    required int pageNumber,
    required int sessionDurationMinutes,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    try {
      final sessionDurationSeconds =
          sessionEnd.difference(sessionStart).inSeconds;

      await _firestore.collection('reading_sessions').add({
        'userId': userId,
        'bookId': bookId,
        'pageNumber': pageNumber,
        'sessionDurationMinutes': sessionDurationMinutes,
        'sessionDurationSeconds': sessionDurationSeconds,
        'durationMinutes': sessionDurationMinutes,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'startTime': Timestamp.fromDate(sessionStart),
        'endTime': Timestamp.fromDate(sessionEnd),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ApiException('Failed to track reading session: $e');
    }
  }

  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    try {
      // Get reading sessions
      final sessionsQuery =
          await _getRecentReadingSessions(userId: userId, limit: 100);

      final sessions = sessionsQuery.docs.map((doc) => doc.data()).toList();

      // Calculate analytics
      final totalMinutes = sessions.fold<int>(
        0,
        (total, session) {
          final minutes = session['sessionDurationMinutes'] as int? ??
              session['durationMinutes'] as int?;
          if (minutes != null) return total + minutes;

          final seconds = session['sessionDurationSeconds'] as int?;
          if (seconds != null) return total + (seconds / 60).floor();

          return total;
        },
      );

      final uniqueBooks =
          sessions.map((session) => session['bookId']).toSet().length;

      return {
        'totalReadingMinutes': totalMinutes,
        'uniqueBooksRead': uniqueBooks,
        'totalSessions': sessions.length,
        'averageSessionLength':
            sessions.isNotEmpty ? totalMinutes / sessions.length : 0,
        'recentSessions': sessions.take(10).toList(),
      };
    } catch (e) {
      throw ApiException('Failed to get user analytics: $e');
    }
  }

  // Quiz and personality API calls
  Future<List<Map<String, dynamic>>> getQuizQuestions() async {
    try {
      final query =
          await _firestore.collection('quiz_questions').orderBy('order').get();

      return query.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      throw ApiException('Failed to get quiz questions: $e');
    }
  }

  Future<Map<String, dynamic>> submitQuizResults({
    required String userId,
    required List<Map<String, dynamic>> answers,
    required Map<String, int> traitScores,
  }) async {
    try {
      // Save quiz results
      await _firestore.collection('quiz_results').add({
        'userId': userId,
        'answers': answers,
        'traitScores': traitScores,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Determine dominant traits
      final sortedTraits = traitScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final dominantTraits =
          sortedTraits.take(3).map((entry) => entry.key).toList();

      // Update user profile
      await _firestore.collection('users').doc(userId).update({
        'personalityTraits': dominantTraits,
        'traitScores': traitScores,
        'hasCompletedQuiz': true,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      });

      return {
        'dominantTraits': dominantTraits,
        'allScores': traitScores,
      };
    } catch (e) {
      throw ApiException('Failed to submit quiz results: $e');
    }
  }

  // Parent dashboard API calls
  Future<Map<String, dynamic>> getChildProgress(String childUserId) async {
    try {
      // Get reading progress
      final progressQuery = await _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: childUserId)
          .get();

      final completedBooks = progressQuery.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;

      final totalReadingTime = progressQuery.docs
          .map((doc) => doc.data()['readingTimeMinutes'] as int? ?? 0)
          .fold(0, (total, minutes) => total + minutes);

      // Get recent activity
      final recentSessions =
          await _getRecentReadingSessions(userId: childUserId, limit: 10);

      return {
        'completedBooks': completedBooks,
        'totalReadingTime': totalReadingTime,
        'recentSessions': recentSessions.docs.map((doc) => doc.data()).toList(),
        'lastActivity': recentSessions.docs.isNotEmpty
            ? (recentSessions.docs.first.data()['createdAt'] ??
                recentSessions.docs.first.data()['startTime'] ??
                recentSessions.docs.first.data()['sessionStart'])
            : null,
      };
    } catch (e) {
      throw ApiException('Failed to get child progress: $e');
    }
  }

  // Content filtering API calls
  Future<void> updateContentFilters({
    required String userId,
    required List<String> allowedCategories,
    required List<String> blockedWords,
    required String maxAgeRating,
  }) async {
    try {
      await _firestore.collection('content_filters').doc(userId).set({
        'allowedCategories': allowedCategories,
        'blockedWords': blockedWords,
        'maxAgeRating': maxAgeRating,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ApiException('Failed to update content filters: $e');
    }
  }

  Future<Map<String, dynamic>?> getContentFilters(String userId) async {
    try {
      final doc =
          await _firestore.collection('content_filters').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw ApiException('Failed to get content filters: $e');
    }
  }

  // Notification API calls
  Future<void> scheduleReadingReminder({
    required String userId,
    required String time, // Format: "HH:mm"
    required List<String> days, // ["monday", "tuesday", etc.]
  }) async {
    try {
      await _firestore.collection('reading_reminders').doc(userId).set({
        'time': time,
        'days': days,
        'isEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ApiException('Failed to schedule reading reminder: $e');
    }
  }

  // Achievement API calls
  Future<List<Map<String, dynamic>>> getUserAchievements(String userId) async {
    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: userId)
          .orderBy('unlockedAt', descending: true)
          .get();

      return query.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      throw ApiException('Failed to get user achievements: $e');
    }
  }

  Future<void> unlockAchievement({
    required String userId,
    required String achievementId,
    required String achievementName,
  }) async {
    try {
      await _firestore.collection('user_achievements').add({
        'userId': userId,
        'achievementId': achievementId,
        'achievementName': achievementName,
        'unlockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ApiException('Failed to unlock achievement: $e');
    }
  }
}

// Custom exception class
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
