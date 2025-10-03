// File: lib/services/api_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  static const String baseUrl = 'https://your-api-endpoint.com/api/v1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // HTTP methods and utilities can be added here when needed

  // Book-related API calls
  Future<List<Map<String, dynamic>>> getRecommendedBooks(List<String> traits) async {
    try {
      // For now, use Firestore. In production, this could be an ML API
      final query = await _firestore
          .collection('books')
          .where('traits', arrayContainsAny: traits)
          .limit(10)
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
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
      await _firestore.collection('reading_sessions').add({
        'userId': userId,
        'bookId': bookId,
        'pageNumber': pageNumber,
        'sessionDurationMinutes': sessionDurationMinutes,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': Timestamp.fromDate(sessionEnd),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ApiException('Failed to track reading session: $e');
    }
  }

  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    try {
      // Get reading sessions
      final sessionsQuery = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final sessions = sessionsQuery.docs.map((doc) => doc.data()).toList();
      
      // Calculate analytics
      final totalMinutes = sessions.fold<int>(
        0, 
        (sum, session) => sum + (session['sessionDurationMinutes'] as int? ?? 0),
      );
      
      final uniqueBooks = sessions
          .map((session) => session['bookId'])
          .toSet()
          .length;

      return {
        'totalReadingMinutes': totalMinutes,
        'uniqueBooksRead': uniqueBooks,
        'totalSessions': sessions.length,
        'averageSessionLength': sessions.isNotEmpty ? totalMinutes / sessions.length : 0,
        'recentSessions': sessions.take(10).toList(),
      };
    } catch (e) {
      throw ApiException('Failed to get user analytics: $e');
    }
  }

  // Quiz and personality API calls
  Future<List<Map<String, dynamic>>> getQuizQuestions() async {
    try {
      final query = await _firestore
          .collection('quiz_questions')
          .orderBy('order')
          .get();
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
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
      
      final dominantTraits = sortedTraits
          .take(3)
          .map((entry) => entry.key)
          .toList();

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
          .fold(0, (sum, minutes) => sum + minutes);

      // Get recent activity
      final recentSessions = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: childUserId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return {
        'completedBooks': completedBooks,
        'totalReadingTime': totalReadingTime,
        'recentSessions': recentSessions.docs.map((doc) => doc.data()).toList(),
        'lastActivity': recentSessions.docs.isNotEmpty 
            ? recentSessions.docs.first.data()['createdAt']
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
      final doc = await _firestore.collection('content_filters').doc(userId).get();
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
      
      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
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
