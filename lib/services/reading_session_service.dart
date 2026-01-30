import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';

/// Simple, centralized reading session tracking
class ReadingSessionService {
  static final ReadingSessionService _instance =
      ReadingSessionService._internal();

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
        // Analytics-friendly schema (used elsewhere in the app)
        'createdAt': FieldValue.serverTimestamp(),
        'sessionStart': FieldValue.serverTimestamp(),
        'sessionEnd': null,
        'sessionDurationSeconds': 0,
        'sessionDurationMinutes': 0,
        // Legacy/alternate schema
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'durationMinutes': 0,
      });

      appLog('[SESSION] Started reading session for book: $bookTitle',
          level: 'INFO');
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
      final sessionRef =
          _firestore.collection('reading_sessions').doc(sessionId);
      final sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        appLog('[SESSION] Session not found: $sessionId', level: 'WARN');
        return 0;
      }

      final data = sessionDoc.data() as Map<String, dynamic>;
      final startTime = (data['startTime'] as Timestamp?)?.toDate();

      if (startTime == null) {
        appLog('[SESSION] No start time found for session: $sessionId',
            level: 'WARN');
        return 0;
      }

      final endTime = DateTime.now();
      final durationSeconds = endTime.difference(startTime).inSeconds;

      // Convert to minutes, rounding up so even 1 second = 1 minute for UI purposes
      // But clamp to reasonable values (max 6 hours = 360 minutes per session to catch stuck sessions)
      final durationMinutes =
          durationSeconds > 0 ? ((durationSeconds + 59) ~/ 60) : 0;
      final finalDuration = durationMinutes > 360 ? 360 : durationMinutes;
      final finalSeconds = durationSeconds > 0
          ? (durationSeconds > 360 * 60 ? 360 * 60 : durationSeconds)
          : 0;

      await sessionRef.update({
        // Analytics-friendly schema
        'sessionEnd': FieldValue.serverTimestamp(),
        'sessionDurationSeconds': finalSeconds,
        'sessionDurationMinutes': finalDuration,
        // Legacy/alternate schema
        'endTime': FieldValue.serverTimestamp(),
        'durationMinutes': finalDuration,
      });

      appLog(
          '[SESSION] Ended session with duration: $durationSeconds seconds = $finalDuration minutes',
          level: 'INFO');
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
        // Preferred fields written by endSession
        final minutes = (data['durationMinutes'] as int?) ??
            (data['sessionDurationMinutes'] as int?) ??
            0;
        if (minutes > 0) {
          totalMinutes += minutes;
          continue;
        }

        // Back-compat: any legacy sessions that stored seconds
        final durationSeconds = (data['sessionDurationSeconds'] as int?) ?? 0;
        final durationMinutes =
            durationSeconds > 0 ? ((durationSeconds + 59) ~/ 60) : 0;
        totalMinutes += durationMinutes;
      }

      return totalMinutes;
    } catch (e) {
      appLog('[SESSION] Error getting total reading minutes: $e',
          level: 'ERROR');
      return 0;
    }
  }

  /// Get today's reading minutes for a user
  Future<int> getTodayReadingMinutes(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startTimestamp = Timestamp.fromDate(startOfDay);
      final endTimestamp =
          Timestamp.fromDate(startOfDay.add(const Duration(days: 1)));

      final snapshot = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .get();

      int totalMinutes = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final minutes = (data['durationMinutes'] as int?) ??
            (data['sessionDurationMinutes'] as int?) ??
            0;
        if (minutes > 0) {
          totalMinutes += minutes;
          continue;
        }

        final seconds = (data['sessionDurationSeconds'] as int?) ?? 0;
        totalMinutes += seconds > 0 ? ((seconds + 59) ~/ 60) : 0;
      }

      // Fallback for any sessions that only have startTime (no createdAt)
      if (totalMinutes == 0) {
        final fallback = await _firestore
            .collection('reading_sessions')
            .where('userId', isEqualTo: userId)
            .where('startTime', isGreaterThanOrEqualTo: startTimestamp)
            .where('startTime', isLessThan: endTimestamp)
            .get();

        for (final doc in fallback.docs) {
          final data = doc.data();
          totalMinutes += (data['durationMinutes'] as int?) ?? 0;
        }
      }

      return totalMinutes;
    } catch (e) {
      appLog('[SESSION] Error getting today reading minutes: $e',
          level: 'ERROR');
      return 0;
    }
  }

  /// Get session count (for session-based achievements)
  Future<int> getSessionCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reading_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final minutes = (data['durationMinutes'] as int?) ??
            (data['sessionDurationMinutes'] as int?) ??
            0;
        if (minutes > 0) {
          count++;
          continue;
        }

        final seconds = (data['sessionDurationSeconds'] as int?) ?? 0;
        if (seconds > 0) count++;
      }

      return count;
    } catch (e) {
      appLog('[SESSION] Error getting session count: $e', level: 'ERROR');
      return 0;
    }
  }
}
