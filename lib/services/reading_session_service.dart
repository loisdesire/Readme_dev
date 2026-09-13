import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';
import 'reading_metrics.dart';
import 'reading_session_engine_client.dart';

/// Simple, centralized reading session tracking
class ReadingSessionService {
  static final ReadingSessionService _instance =
      ReadingSessionService._internal();

  factory ReadingSessionService() {
    return _instance;
  }

  ReadingSessionService._internal()
      : _firestore = FirebaseFirestore.instance,
        _injectedEngine = null;

  /// Test-only: an independent (non-singleton) instance wrapping a fake.
  @visibleForTesting
  ReadingSessionService.withInstances({
    required FirebaseFirestore firestore,
    ReadingSessionEngineClient? engine,
  })  : _firestore = firestore,
        _injectedEngine = engine;

  final FirebaseFirestore _firestore;
  final ReadingSessionEngineClient? _injectedEngine;
  ReadingSessionEngineClient get _engine =>
      _injectedEngine ?? ReadingSessionEngineClient();

  /// Start a reading session when user opens a book.
  ///
  /// Tries the server-timestamped `startReadingSession` Cloud Function
  /// first (see docs/reading-session-integrity-design.md, "Option B") —
  /// the server, not the client, stamps the start time, closing the most
  /// blatant version of fabricating a session that never happened. Falls
  /// back to the original direct Firestore write on any failure (no
  /// connectivity, cold start, etc.) so reading itself never breaks; a
  /// fallback-created session is simply unverified, exactly like every
  /// session was before this change.
  Future<String?> startSession({
    required String userId,
    required String bookId,
    required String bookTitle,
  }) async {
    try {
      final result = await _engine.startReadingSession(
        bookId: bookId,
        bookTitle: bookTitle,
      );
      final sessionId = result['sessionId'] as String?;
      if (sessionId != null) {
        appLog(
            '[SESSION] Started server-verified reading session for book: $bookTitle',
            level: 'INFO');
        return sessionId;
      }
    } catch (e) {
      appLog(
          '[SESSION] startReadingSession Cloud Function failed ($e) — '
          'falling back to a direct, unverified write so reading still works.',
          level: 'WARN');
    }
    return _startSessionDirect(
      userId: userId,
      bookId: bookId,
      bookTitle: bookTitle,
    );
  }

  Future<String?> _startSessionDirect({
    required String userId,
    required String bookId,
    required String bookTitle,
  }) async {
    try {
      final now = DateTime.now();
      final sessionRef = await _firestore.collection('reading_sessions').add({
        'userId': userId,
        'bookId': bookId,
        'bookTitle': bookTitle,
        // Analytics-friendly schema (used elsewhere in the app)
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtClient': Timestamp.fromDate(now),
        'sessionStart': FieldValue.serverTimestamp(),
        'sessionEnd': null,
        'sessionDurationSeconds': 0,
        'sessionDurationMinutes': 0,
        // Legacy/alternate schema
        'startTime': FieldValue.serverTimestamp(),
        'clientStartTime': Timestamp.fromDate(now),
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

  /// End a reading session and calculate duration.
  ///
  /// Tries the server-timestamped `endReadingSession` Cloud Function
  /// first — duration is computed from the server's own clock, never a
  /// client-supplied number. Falls back to the original client-computed
  /// behavior on any failure, same reasoning as [startSession].
  Future<int> endSession({
    required String sessionId,
    required String userId,
    required String bookId,
  }) async {
    try {
      final result = await _engine.endReadingSession(sessionId: sessionId);
      final minutes = (result['durationMinutes'] as num?)?.toInt();
      if (minutes != null) return minutes;
    } catch (e) {
      appLog(
          '[SESSION] endReadingSession Cloud Function failed ($e) — '
          'falling back to a direct, unverified update.',
          level: 'WARN');
    }
    return _endSessionDirect(
      sessionId: sessionId,
      userId: userId,
      bookId: bookId,
    );
  }

  /// "Still actively reading" check-in for an open session (Option A —
  /// see docs/reading-session-integrity-design.md). The caller (the
  /// reading screen) is expected to call this roughly every 10 minutes
  /// while the book is open and the app is foregrounded, and to stop
  /// calling it when backgrounded or disposed — that's what actually
  /// bounds how much idle/abandoned time can be credited; this method
  /// itself just relays one check-in.
  ///
  /// Unlike [startSession]/[endSession], there is no fallback: a
  /// heartbeat is a bonus credit for time already spent reading, not
  /// something reading depends on to keep working. A failure here
  /// (offline, cold start) is swallowed and logged — the next heartbeat
  /// or the final endSession call will simply credit less for that gap,
  /// never crash the reading screen.
  Future<void> sendHeartbeat({required String sessionId}) async {
    try {
      await _engine.recordReadingHeartbeat(sessionId: sessionId);
    } catch (e) {
      appLog(
          '[SESSION] recordReadingHeartbeat failed ($e) — this check-in is '
          'simply lost, reading continues unaffected.',
          level: 'WARN');
    }
  }

  Future<int> _endSessionDirect({
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
      final startTime = extractSessionTimeForBucketing(data);

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
        'clientEndTime': Timestamp.fromDate(endTime),
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
        totalMinutes += extractSessionMinutes(data);
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
      // Track which docs have already contributed to the total: startTime
      // and createdAtClient are written together, moments apart, by every
      // session (see startSession), so a doc that qualifies for one
      // fallback query below almost always qualifies for the other too —
      // without this, it would be summed twice.
      final countedDocIds = <String>{};
      for (final doc in snapshot.docs) {
        totalMinutes += extractSessionMinutes(doc.data());
        countedDocIds.add(doc.id);
      }

      // Fallback for any sessions that only have startTime (no createdAt)
      if (totalMinutes == 0) {
        // Best-effort fallback for sessions that were written with client timestamps.
        try {
          final byClient = await _firestore
              .collection('reading_sessions')
              .where('userId', isEqualTo: userId)
              .where('createdAtClient', isGreaterThanOrEqualTo: startTimestamp)
              .where('createdAtClient', isLessThan: endTimestamp)
              .get();

          for (final doc in byClient.docs) {
            if (!countedDocIds.add(doc.id)) continue;
            totalMinutes += extractSessionMinutes(doc.data());
          }
        } catch (e) {
          appLog('[SESSION] Error querying today minutes by createdAtClient: $e',
              level: 'DEBUG');
        }

        final fallback = await _firestore
            .collection('reading_sessions')
            .where('userId', isEqualTo: userId)
            .where('startTime', isGreaterThanOrEqualTo: startTimestamp)
            .where('startTime', isLessThan: endTimestamp)
            .get();

        for (final doc in fallback.docs) {
          if (!countedDocIds.add(doc.id)) continue;
          totalMinutes += extractSessionMinutes(doc.data());
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
        if (extractSessionMinutes(data) > 0) count++;
      }

      return count;
    } catch (e) {
      appLog('[SESSION] Error getting session count: $e', level: 'ERROR');
      return 0;
    }
  }
}
