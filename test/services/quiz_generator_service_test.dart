import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/quiz_generator_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

// getBookQuiz's actual httpsCallable-calling retry loop has no fake/mock
// package available for cloud_functions (unlike auth/firestore/storage), so
// it isn't exercised here — see SECURITY.md. Everything else — the pure
// decision logic that loop relies on, and every Firestore/AchievementService
// -touching method — is covered.

AchievementService buildAchievementService({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
}) {
  return AchievementService.withInstances(
    auth: auth,
    firestore: firestore,
    notificationService: NotificationService.withInstances(auth: auth, firestore: firestore),
    weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
  );
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

      await service.saveQuizAttempt(
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
    test('uses the injected AchievementService, not the real singleton — '
        'regression for the same DI-escape class of bug fixed in '
        'AnalyticsService earlier this session', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final achievementService = buildAchievementService(auth: auth, firestore: firestore);
      final service = QuizGeneratorService.withInstances(
        firestore: firestore,
        achievementService: achievementService,
      );

      await service.awardQuizPoints(
        userId: 'u1',
        bookId: 'b1',
        points: 3,
        percentage: 80,
      );

      final userDoc = await firestore.collection('users').doc('u1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 3);
    });
  });
}
