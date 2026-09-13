import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/reading_metrics.dart';
import 'package:readme_app/services/reading_session_engine_client.dart';
import 'package:readme_app/services/reading_session_service.dart';

ReadingSessionService buildService(
  FakeFirebaseFirestore firestore, {
  ReadingSessionEngineClient? engine,
}) {
  return ReadingSessionService.withInstances(firestore: firestore, engine: engine);
}

void main() {
  group('extractSessionMinutes', () {
    test('prefers durationMinutes when present and positive', () {
      expect(extractSessionMinutes({'durationMinutes': 7, 'sessionDurationMinutes': 99}), 7);
    });

    test('falls back to sessionDurationMinutes', () {
      expect(extractSessionMinutes({'durationMinutes': 0, 'sessionDurationMinutes': 4}), 4);
    });

    test('falls back to rounding sessionDurationSeconds up to the minute', () {
      expect(extractSessionMinutes({'sessionDurationSeconds': 61}), 2);
      expect(extractSessionMinutes({'sessionDurationSeconds': 60}), 1);
      expect(extractSessionMinutes({'sessionDurationSeconds': 0}), 0);
    });

    test('missing everything is 0', () {
      expect(extractSessionMinutes({}), 0);
    });
  });

  group('extractSessionTimeForBucketing', () {
    test('prefers clientStartTime over every other field', () {
      final client = DateTime(2026, 1, 1, 8);
      final server = DateTime(2026, 1, 1, 9);
      final result = extractSessionTimeForBucketing({
        'clientStartTime': Timestamp.fromDate(client),
        'sessionStart': Timestamp.fromDate(server),
      });
      expect(result, client);
    });

    test('returns null when nothing is set', () {
      expect(extractSessionTimeForBucketing({}), isNull);
    });
  });

  group('ReadingSessionService.startSession / endSession', () {
    test('endSession computes minutes rounded up from the elapsed time',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      final sessionId = await service.startSession(
        userId: 'u1',
        bookId: 'b1',
        bookTitle: 'Book',
      );
      expect(sessionId, isNotNull);

      // Backdate the session's start so endSession sees real elapsed time —
      // FakeFirebaseFirestore resolves serverTimestamp() to "now" immediately,
      // so we can't wait out real elapsed time in a test.
      final startedAt = DateTime.now().subtract(const Duration(minutes: 5));
      await firestore.collection('reading_sessions').doc(sessionId).update({
        'clientStartTime': Timestamp.fromDate(startedAt),
      });

      final minutes = await service.endSession(
        sessionId: sessionId!,
        userId: 'u1',
        bookId: 'b1',
      );

      expect(minutes, greaterThanOrEqualTo(5));
      final doc = await firestore.collection('reading_sessions').doc(sessionId).get();
      expect(doc.data()!['durationMinutes'], minutes);
      expect(doc.data()!['sessionDurationMinutes'], minutes);
    });

    test('endSession on a missing session returns 0, not an error', () async {
      final service = buildService(FakeFirebaseFirestore());
      final minutes = await service.endSession(
        sessionId: 'does-not-exist',
        userId: 'u1',
        bookId: 'b1',
      );
      expect(minutes, 0);
    });

    test('endSession clamps to 360 minutes for a stuck/very long session',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      final sessionId = await service.startSession(
        userId: 'u1',
        bookId: 'b1',
        bookTitle: 'Book',
      );
      await firestore.collection('reading_sessions').doc(sessionId).update({
        'clientStartTime':
            Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 10))),
      });

      final minutes = await service.endSession(
        sessionId: sessionId!,
        userId: 'u1',
        bookId: 'b1',
      );

      expect(minutes, 360);
    });
  });

  group('ReadingSessionService.startSession / endSession — via the '
      'server-timestamped Cloud Functions (Option B, see '
      'docs/reading-session-integrity-design.md)', () {
    test('startSession uses the Cloud Function\'s sessionId when it '
        'succeeds, instead of writing directly', () async {
      final firestore = FakeFirebaseFirestore();
      var startCalled = false;
      final engine = ReadingSessionEngineClient.withCaller((name, data) async {
        if (name == 'startReadingSession') {
          startCalled = true;
          // Simulate the server creating its own doc, as the real Cloud
          // Function would via the Admin SDK.
          final ref = await firestore.collection('reading_sessions').add({
            'userId': 'u1', 'bookId': data['bookId'], 'bookTitle': data['bookTitle'],
            'startedViaCloudFunction': true, 'sessionEnd': null, 'endTime': null,
          });
          return {'sessionId': ref.id};
        }
        throw StateError('unexpected call: $name');
      });
      final service = buildService(firestore, engine: engine);

      final sessionId = await service.startSession(
        userId: 'u1', bookId: 'b1', bookTitle: 'Book',
      );

      expect(startCalled, isTrue);
      expect(sessionId, isNotNull);
      final doc = await firestore.collection('reading_sessions').doc(sessionId).get();
      expect(doc.data()!['startedViaCloudFunction'], isTrue);
    });

    test('endSession uses the Cloud Function\'s server-computed duration '
        'when it succeeds, instead of computing one client-side', () async {
      final firestore = FakeFirebaseFirestore();
      final engine = ReadingSessionEngineClient.withCaller((name, data) async {
        if (name == 'endReadingSession') {
          return {'sessionId': data['sessionId'], 'durationMinutes': 42};
        }
        throw StateError('unexpected call: $name');
      });
      final service = buildService(firestore, engine: engine);

      final minutes = await service.endSession(
        sessionId: 'whatever-the-server-owns', userId: 'u1', bookId: 'b1',
      );

      // The server's number is trusted outright — this service never
      // re-derives it from a local Firestore doc when the Cloud Function
      // call itself succeeds.
      expect(minutes, 42);
    });

    test('a Cloud Function failure falls back to the original direct-write '
        'behavior instead of losing the session — offline reading keeps '
        'working, just unverified for that session', () async {
      final firestore = FakeFirebaseFirestore();
      final engine = ReadingSessionEngineClient.withCaller((name, data) async {
        throw Exception('simulated: no connectivity');
      });
      final service = buildService(firestore, engine: engine);

      final sessionId = await service.startSession(
        userId: 'u1', bookId: 'b1', bookTitle: 'Book',
      );
      expect(sessionId, isNotNull);
      final doc = await firestore.collection('reading_sessions').doc(sessionId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['startedViaCloudFunction'], isNull); // fallback path, not server-verified
    });
  });

  group(
      'ReadingSessionService.sendHeartbeat — "still actively reading" '
      'check-ins (Option A, see docs/reading-session-integrity-design.md)',
      () {
    test('relays the check-in to the engine for the given session', () async {
      String? calledWith;
      final engine = ReadingSessionEngineClient.withCaller((name, data) async {
        if (name == 'recordReadingHeartbeat') {
          calledWith = data['sessionId'] as String?;
          return {'sessionId': data['sessionId'], 'accountedSeconds': 60};
        }
        throw StateError('unexpected call: $name');
      });
      final service = buildService(FakeFirebaseFirestore(), engine: engine);

      await service.sendHeartbeat(sessionId: 's1');

      expect(calledWith, 's1');
    });

    test('swallows a failure instead of throwing — a missed check-in must '
        'never crash the reading screen', () async {
      final engine = ReadingSessionEngineClient.withCaller((name, data) async {
        throw Exception('simulated: no connectivity');
      });
      final service = buildService(FakeFirebaseFirestore(), engine: engine);

      // Should complete without throwing.
      await service.sendHeartbeat(sessionId: 's1');
    });
  });

  group('ReadingSessionService.getTotalReadingMinutes', () {
    test('sums durationMinutes across every session for the user only',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      await firestore.collection('reading_sessions').add({'userId': 'u1', 'durationMinutes': 10});
      await firestore.collection('reading_sessions').add({'userId': 'u1', 'durationMinutes': 5});
      await firestore.collection('reading_sessions').add({'userId': 'u2', 'durationMinutes': 999});

      expect(await service.getTotalReadingMinutes('u1'), 15);
    });
  });

  group('ReadingSessionService.getTodayReadingMinutes', () {
    test('sums sessions created today via the primary createdAt query',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      await firestore.collection('reading_sessions').add({
        'userId': 'u1',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'durationMinutes': 12,
      });

      expect(await service.getTodayReadingMinutes('u1'), 12);
    });

    test(
        'regression: a session matching both fallback queries is not '
        'double-counted when the primary createdAt query misses it',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      final today = DateTime.now();
      await firestore.collection('reading_sessions').add({
        'userId': 'u1',
        // Excluded from the primary query on purpose (yesterday), so the
        // fallback path runs — createdAtClient and startTime are both set
        // to today, exactly as startSession really writes them together.
        'createdAt': Timestamp.fromDate(today.subtract(const Duration(days: 1))),
        'createdAtClient': Timestamp.fromDate(today),
        'startTime': Timestamp.fromDate(today),
        'durationMinutes': 30,
      });

      expect(await service.getTodayReadingMinutes('u1'), 30);
    });

    test('a user with no sessions today gets 0, not an error', () async {
      final service = buildService(FakeFirebaseFirestore());
      expect(await service.getTodayReadingMinutes('nobody'), 0);
    });
  });

  group('ReadingSessionService.getSessionCount', () {
    test('counts only sessions with positive extracted minutes', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      await firestore.collection('reading_sessions').add({'userId': 'u1', 'durationMinutes': 5});
      await firestore.collection('reading_sessions').add({'userId': 'u1', 'durationMinutes': 0});
      await firestore.collection('reading_sessions').add({'userId': 'u2', 'durationMinutes': 5});

      expect(await service.getSessionCount('u1'), 1);
    });
  });
}
