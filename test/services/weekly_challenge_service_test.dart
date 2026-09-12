import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

WeeklyChallengeService buildService(FakeFirebaseFirestore firestore) {
  return WeeklyChallengeService.withInstances(firestore: firestore);
}

void main() {
  group('parseChallengeType', () {
    test('accepts the bare enum-value name', () {
      final service = buildService(FakeFirebaseFirestore());
      expect(service.parseChallengeType('completeQuizzes'), ChallengeType.completeQuizzes);
    });

    test('accepts the "ChallengeType.x" qualified form', () {
      final service = buildService(FakeFirebaseFirestore());
      expect(service.parseChallengeType('ChallengeType.readGenres'), ChallengeType.readGenres);
    });

    test('is case-insensitive', () {
      final service = buildService(FakeFirebaseFirestore());
      expect(service.parseChallengeType('READDAYS'), ChallengeType.readDays);
    });

    test('unrecognized/null/empty all fall back to completeBooks', () {
      final service = buildService(FakeFirebaseFirestore());
      expect(service.parseChallengeType(null), ChallengeType.completeBooks);
      expect(service.parseChallengeType(''), ChallengeType.completeBooks);
      expect(service.parseChallengeType('not-a-real-type'), ChallengeType.completeBooks);
    });
  });

  group('getStartOfWeek', () {
    test('always resolves to the Monday of that week, at midnight', () {
      final service = buildService(FakeFirebaseFirestore());
      // Thursday 2026-01-08 -> Monday 2026-01-05
      final result = service.getStartOfWeek(DateTime(2026, 1, 8, 15, 30));
      expect(result, DateTime(2026, 1, 5));
    });

    test('a Monday maps to itself, at midnight', () {
      final service = buildService(FakeFirebaseFirestore());
      final result = service.getStartOfWeek(DateTime(2026, 1, 5, 23, 59));
      expect(result, DateTime(2026, 1, 5));
    });
  });

  group('calculateProgress — completeBooks', () {
    final startOfWeek = DateTime(2026, 1, 5);

    test(
        'regression: reopening a book completed in a previous week does NOT '
        'count toward this week\'s challenge (was: any lastReadAt bump '
        'counted as a fresh completion)', () async {
      final service = buildService(FakeFirebaseFirestore());
      final userProgress = [
        {
          'isCompleted': true,
          // Completed well before this week...
          'completedAt': Timestamp.fromDate(DateTime(2025, 12, 1)),
          // ...but reopened/reread THIS week, bumping lastReadAt.
          'lastReadAt': Timestamp.fromDate(DateTime(2026, 1, 6)),
        },
      ];

      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.completeBooks,
        startOfWeek: startOfWeek,
        userData: {},
        userProgress: userProgress,
      );

      expect(progress, 0);
    });

    test('a book actually completed this week counts', () async {
      final service = buildService(FakeFirebaseFirestore());
      final userProgress = [
        {
          'isCompleted': true,
          'completedAt': Timestamp.fromDate(DateTime(2026, 1, 6)),
          'lastReadAt': Timestamp.fromDate(DateTime(2026, 1, 6)),
        },
      ];

      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.completeBooks,
        startOfWeek: startOfWeek,
        userData: {},
        userProgress: userProgress,
      );

      expect(progress, 1);
    });

    test('legacy doc with no completedAt falls back to lastReadAt', () async {
      final service = buildService(FakeFirebaseFirestore());
      final userProgress = [
        {
          'isCompleted': true,
          'lastReadAt': Timestamp.fromDate(DateTime(2026, 1, 6)),
        },
      ];

      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.completeBooks,
        startOfWeek: startOfWeek,
        userData: {},
        userProgress: userProgress,
      );

      expect(progress, 1);
    });

    test('an incomplete book never counts, regardless of timestamps',
        () async {
      final service = buildService(FakeFirebaseFirestore());
      final userProgress = [
        {
          'isCompleted': false,
          'completedAt': Timestamp.fromDate(DateTime(2026, 1, 6)),
        },
      ];

      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.completeBooks,
        startOfWeek: startOfWeek,
        userData: {},
        userProgress: userProgress,
      );

      expect(progress, 0);
    });
  });

  group('calculateProgress — day/time-based types', () {
    final startOfWeek = DateTime(2026, 1, 5);
    final weeklyReadingProgress = {
      'Mon': 15,
      'Tue': 0,
      'Wed': 12,
      'Thu': 10,
      'Fri': 10,
      'Sat': 0,
      'Sun': 5,
    };

    test('readDays counts days with any minutes at all', () async {
      final service = buildService(FakeFirebaseFirestore());
      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.readDays,
        startOfWeek: startOfWeek,
        userData: {},
        weeklyReadingProgress: weeklyReadingProgress,
      );
      expect(progress, 5); // Mon, Wed, Thu, Fri, Sun
    });

    test('readingTime sums every day\'s minutes', () async {
      final service = buildService(FakeFirebaseFirestore());
      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.readingTime,
        startOfWeek: startOfWeek,
        userData: {},
        weeklyReadingProgress: weeklyReadingProgress,
      );
      expect(progress, 15 + 12 + 10 + 10 + 5);
    });

    test('dailyMinutes counts only days with >= 10 minutes', () async {
      final service = buildService(FakeFirebaseFirestore());
      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.dailyMinutes,
        startOfWeek: startOfWeek,
        userData: {},
        weeklyReadingProgress: weeklyReadingProgress,
      );
      expect(progress, 4); // Mon(15), Wed(12), Thu(10), Fri(10)
    });

    test('consecutiveDays finds the longest streak, not the total active days',
        () async {
      final service = buildService(FakeFirebaseFirestore());
      // Mon(15) Tue(0) Wed(12) Thu(10) Fri(10) Sat(0) Sun(5)
      // Streaks: [Mon]=1, [Wed,Thu,Fri]=3, [Sun]=1 -> best = 3
      final progress = await service.calculateProgress(
        userId: 'u1',
        challengeType: ChallengeType.consecutiveDays,
        startOfWeek: startOfWeek,
        userData: {},
        weeklyReadingProgress: weeklyReadingProgress,
      );
      expect(progress, 3);
    });
  });

  group('calculateProgress — user-doc-counter types', () {
    final startOfWeek = DateTime(2026, 1, 5);

    test('completeQuizzes / quizScore / unlockAchievement / readGenres / '
        'readPages all read their respective userData counters, defaulting '
        'to 0/empty', () async {
      final service = buildService(FakeFirebaseFirestore());

      expect(
        await service.calculateProgress(
          userId: 'u1',
          challengeType: ChallengeType.completeQuizzes,
          startOfWeek: startOfWeek,
          userData: {'quizzesCompletedThisWeek': 4},
        ),
        4,
      );
      expect(
        await service.calculateProgress(
          userId: 'u1',
          challengeType: ChallengeType.quizScore,
          startOfWeek: startOfWeek,
          userData: {},
        ),
        0,
      );
      expect(
        await service.calculateProgress(
          userId: 'u1',
          challengeType: ChallengeType.readGenres,
          startOfWeek: startOfWeek,
          userData: {
            'genresReadThisWeek': ['fantasy', 'adventure']
          },
        ),
        2,
      );
    });
  });

  group('updateProgress', () {
    test('marks completed once progress reaches target, leaving '
        'weeklyChallengeSeen false so the celebration is shown', () async {
      final firestore = FakeFirebaseFirestore();
      // Default state for a week in progress, per initializeWeeklyChallenge.
      await firestore.collection('users').doc('u1').set({'weeklyChallengeSeen': false});
      final service = buildService(firestore);

      await service.updateProgress(userId: 'u1', progress: 3, target: 3);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['weeklyChallengeCompleted'], true);
      expect(doc.data()!['weeklyChallengeProgress'], 3);
      expect(doc.data()!['weeklyChallengeSeen'], false);
    });

    test('does not re-trigger the celebration flag once already seen for '
        'this completion', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'weeklyChallengeSeen': false});
      final service = buildService(firestore);

      await service.updateProgress(userId: 'u1', progress: 3, target: 3);
      // Simulate the app marking the celebration seen.
      await service.markCelebrationSeen('u1');
      // A later recompute with the same (already-completed) progress.
      await service.updateProgress(userId: 'u1', progress: 3, target: 3);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['weeklyChallengeSeen'], true);
    });

    test('below target, not marked completed', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);
      await service.updateProgress(userId: 'u1', progress: 1, target: 3);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['weeklyChallengeCompleted'], false);
    });
  });

  group('trackQuizCompletion', () {
    test('increments the weekly quiz count and keeps the best score seen',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore);

      await service.trackQuizCompletion(userId: 'u1', score: 60);
      await service.trackQuizCompletion(userId: 'u1', score: 90);
      await service.trackQuizCompletion(userId: 'u1', score: 70);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['quizzesCompletedThisWeek'], 3);
      expect(doc.data()!['bestQuizScoreThisWeek'], 90);
    });
  });

  group('resetWeeklyTracking', () {
    test('zeroes every weekly counter', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'quizzesCompletedThisWeek': 5,
        'bestQuizScoreThisWeek': 100,
        'genresReadThisWeek': ['a', 'b'],
      });
      final service = buildService(firestore);

      await service.resetWeeklyTracking('u1');

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['quizzesCompletedThisWeek'], 0);
      expect(doc.data()!['bestQuizScoreThisWeek'], 0);
      expect(doc.data()!['genresReadThisWeek'], isEmpty);
    });
  });
}
