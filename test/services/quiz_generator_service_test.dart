import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/points_engine_client.dart';
import 'package:readme_app/services/quiz_generator_service.dart';

// getBookQuiz's actual httpsCallable-calling retry loop has no fake/mock
// package available for cloud_functions (unlike auth/firestore/storage), so
// it isn't exercised here — see SECURITY.md. Everything else — the pure
// decision logic that loop relies on, and every Firestore/points-engine
// -touching method — is covered.

/// A fake standing in for the real awardQuizPoints Cloud Function (see
/// SECURITY.md's "Point-award security migration"): computes the same
/// tiered points from the real quiz_attempts doc's stored percentage,
/// exactly like the server does, so this test can assert on the outcome
/// without re-deriving the server's own logic (already covered by
/// functions/lib/__tests__/emulator/points_engine.test.js).
PointsEngineClient fakeQuizPointsClient(FakeFirebaseFirestore firestore) {
  return PointsEngineClient.withCaller((name, data) async {
    expect(name, 'awardQuizPoints');
    final attemptRef =
        firestore.collection('quiz_attempts').doc(data['attemptId'] as String);
    final attemptSnap = await attemptRef.get();
    final percentage = (attemptSnap.data()?['percentage'] as int?) ?? 0;
    final points = percentage >= 90
        ? 5
        : percentage >= 70
            ? 3
            : percentage >= 50
                ? 1
                : 0;

    final userRef = firestore.collection('users').doc(attemptSnap.data()!['userId'] as String);
    final userSnap = await userRef.get();
    final newTotal = ((userSnap.data()?['totalAchievementPoints'] as int?) ?? 0) + points;
    if (points > 0) {
      await userRef.set({'totalAchievementPoints': newTotal}, SetOptions(merge: true));
    }
    await attemptRef.set({'pointsAwarded': true}, SetOptions(merge: true));
    return {'pointsEarned': points, 'newTotalPoints': newTotal, 'promotedLeague': null};
  });
}

void main() {
  group('isNonRetryableErrorResult', () {
    test('invalid-argument and not-found are not retryable', () {
      expect(isNonRetryableErrorResult({'code': 'invalid-argument'}), isTrue);
      expect(isNonRetryableErrorResult({'code': 'not-found'}), isTrue);
    });

    test('a transient-looking code (e.g. internal, unavailable) IS retryable',
        () {
      expect(isNonRetryableErrorResult({'code': 'internal'}), isFalse);
      expect(isNonRetryableErrorResult({'code': 'unavailable'}), isFalse);
      expect(isNonRetryableErrorResult({}), isFalse);
    });
  });

  group('isNonRetryableExceptionCode', () {
    test('permission-denied and unauthenticated are not retryable', () {
      expect(isNonRetryableExceptionCode('permission-denied'), isTrue);
      expect(isNonRetryableExceptionCode('unauthenticated'), isTrue);
    });

    test('other codes and null are retryable', () {
      expect(isNonRetryableExceptionCode('deadline-exceeded'), isFalse);
      expect(isNonRetryableExceptionCode(null), isFalse);
    });
  });

  group('extractErrorMessage', () {
    test('prefers "message", falls back to "error", then a default', () {
      expect(extractErrorMessage({'message': 'bad request'}), 'bad request');
      expect(extractErrorMessage({'error': 'oops'}), 'oops');
      expect(extractErrorMessage({}), 'Unknown error');
    });

    test('a non-Map response describes itself instead of crashing', () {
      expect(extractErrorMessage('plain string'), contains('plain string'));
      expect(extractErrorMessage(null), contains('null'));
    });
  });

  group('QuizGeneratorService.saveQuizAttempt', () {
    test('writes the attempt with a correctly rounded percentage', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuizGeneratorService.withInstances(firestore: firestore);

      final attemptId = await service.saveQuizAttempt(
        userId: 'u1',
        bookId: 'b1',
        userAnswers: [0, 1, 2],
        score: 2,
        totalQuestions: 3,
      );

      final docs = (await firestore.collection('quiz_attempts').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.first.data()['percentage'], 67); // round(2/3*100)
      expect(docs.first.data()['score'], 2);
      // The returned ID is what awardQuizPoints needs to award against —
      // see SECURITY.md's "Point-award security migration".
      expect(attemptId, docs.first.id);
    });

    test(
        'regression: a totalQuestions of 0 (malformed/fallback quiz) writes '
        'a 0% attempt instead of throwing on NaN.round() and silently '
        'dropping the write entirely', () async {
      final firestore = FakeFirebaseFirestore();
      final service = QuizGeneratorService.withInstances(firestore: firestore);

      await service.saveQuizAttempt(
        userId: 'u1',
        bookId: 'b1',
        userAnswers: [],
        score: 0,
        totalQuestions: 0,
      );

      final docs = (await firestore.collection('quiz_attempts').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.first.data()['percentage'], 0);
    });
  });

  group('QuizGeneratorService._getCachedQuiz (via getBookQuiz)', () {
    test('getBookQuiz returns a cached quiz without needing a Cloud '
        'Function call', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('book_quizzes').doc('b1').set({
        'questions': [
          {'question': 'Q1', 'correctAnswer': 0}
        ],
      });
      final service = QuizGeneratorService.withInstances(firestore: firestore);

      final quiz = await service.getBookQuiz('b1');

      expect(quiz, isNotNull);
      expect(quiz!['questions'], hasLength(1));
    });
  });

  group('QuizGeneratorService.awardQuizPoints', () {
    test('uses the injected PointsEngineClient, not the real singleton — '
        'regression for the same DI-escape class of bug fixed in '
        'AnalyticsService earlier this session', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final attempt = await firestore.collection('quiz_attempts').add({
        'userId': 'u1', 'bookId': 'b1', 'percentage': 80,
      });
      final service = QuizGeneratorService.withInstances(
        firestore: firestore,
        pointsEngine: fakeQuizPointsClient(firestore),
      );

      await service.awardQuizPoints(attemptId: attempt.id);

      final userDoc = await firestore.collection('users').doc('u1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 3); // 70-89% tier
    });
  });
}
