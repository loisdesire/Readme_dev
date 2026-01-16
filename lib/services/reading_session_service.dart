import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';

/// Simple, centralized reading session tracking
class ReadingSessionService {
  static final ReadingSessionService _instance = ReadingSessionService._internal();
  
  factory ReadingSessionService() {
    return _instance;
  }
  
  ReadingSessionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Start a reading session when user opens a book
  Future<String?> startSession({
    required String userId,
    required String bookId,
    required String bookTitle,
  }) async {
    try {
      final sessionRef = await _firestore.collection('reading_sessions').add({
        'userId': userId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'durationMinutes': 0,
      });
      
      appLog('[SESSION] Started reading session for book: $bookTitle', level: 'INFO');
      return sessionRef.id;
    } catch (e) {
      appLog('[SESSION] Error starting session: $e', level: 'ERROR');
      return null;
    }
  }

  /// End a reading session and calculate duration
  Future<int> endSession({
    required String sessionId,
    required String userId,
    required String bookId,
  }) async {
    try {
      final sessionRef = _firestore.collection('reading_sessions').doc(sessionId);
      final sessionDoc = await sessionRef.get();
      
      if (!sessionDoc.exists) {
        appLog('[SESSION] Session not found: $sessionId', level: 'WARN');
        return 0;
      }

      final data = sessionDoc.data() as Map<String, dynamic>;
      final startTime = (data['startTime'] as Timestamp?)?.toDate();
      
      if (startTime == null) {
        appLog('[SESSION] No start time found for session: $sessionId', level: 'WARN');
        return 0;
      }

      final endTime = DateTime.now();
      final durationSeconds = endTime.difference(startTime).inSeconds;
      
      // Convert to minutes, rounding up so even 1 second = 1 minute for UI purposes
      // But clamp to reasonable values (max 6 hours = 360 minutes per session to catch stuck sessions)
      final durationMinutes = durationSeconds > 0 ? ((durationSeconds + 59) ~/ 60) : 0;
      final finalDuration = durationMinutes > 360 ? 360 : durationMinutes;

      await sessionRef.update({
        'endTime': FieldValue.serverTimestamp(),
        'durationMinutes': finalDuration,
      });

      appLog('[SESSION] Ended session with duration: $durationSeconds seconds = $finalDuration minutes', level: 'INFO');
      return finalDuration;
    } catch (e) {
      appLog('[SESSION] Error ending session: $e', level: 'ERROR');
      return 0;
    }
  }

  /// Get total reading minutes for a user
  Future<int> getTotalReadingMinutes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      int totalMinutes = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Convert sessionDurationSeconds to minutes (rounded up)
        final durationSeconds = (data['sessionDurationSeconds'] as int?) ?? 0;
        final durationMinutes = (durationSeconds + 59) ~/ 60; // Round up to nearest minute
        totalMinutes += durationMinutes;
      }

      return totalMinutes;
    } catch (e) {
      appLog('[SESSION] Error getting total reading minutes: $e', level: 'ERROR');
      return 0;
    }
  }

  /// Get today's reading minutes for a user
  Future<int> getTodayReadingMinutes(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startTimestamp = Timestamp.fromDate(startOfDay);

      final snapshot = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: startTimestamp)
          .where('durationMinutes', isGreaterThan: 0)
          .get();

      int totalMinutes = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['durationMinutes'] as int?) ?? 0;
      }

      return totalMinutes;
    } catch (e) {
      appLog('[SESSION] Error getting today reading minutes: $e', level: 'ERROR');
      return 0;
    }
  }

  /// Get session count (for session-based achievements)
  Future<int> getSessionCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('durationMinutes', isGreaterThan: 0)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      appLog('[SESSION] Error getting session count: $e', level: 'ERROR');
      return 0;
    }
  }
}
