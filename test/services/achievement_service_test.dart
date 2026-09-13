import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/points_engine_client.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

// SECURITY.md's "Point-award security migration": checkAndUnlockAchievements
// no longer writes points/user_achievements to Firestore directly — it
// calls a Cloud Function (functions/lib/points_engine.js's
// unlockAchievement) that re-verifies everything server-side. That
// server-side logic is covered by
// functions/lib/__tests__/emulator/points_engine.test.js; these tests
// instead cover what AchievementService itself is still responsible for:
// using the local (fast, optimistic) shouldUnlockAchievement check to
// decide which achievements to even attempt, calling PointsEngineClient
// correctly, and handling its success/already-exists/failed-precondition
// outcomes without crashing.

/// A fake PointsEngineClient standing in for the real unlockAchievement
/// Cloud Function: looks up the real achievement doc (still on the fake
/// Firestore, exactly like the real function would via Admin SDK) and
/// simulates its idempotency/threshold checks against the given fakes,
/// so tests can assert on the *outcome* without re-deriving the server's
/// internal logic.
PointsEngineClient fakeUnlockClient({
  required FakeFirebaseFirestore firestore,
  required String userId,
  Set<String> alreadyUnlockedIds = const {},
}) {
  return PointsEngineClient.withCaller((name, data) async {
    expect(name, 'unlockAchievement');
    final achievementId = data['achievementId'] as String;

    if (alreadyUnlockedIds.contains(achievementId)) {
      throw FirebaseFunctionsException(
        message: 'Achievement already unlocked.',
        code: 'already-exists',
      );
    }

    final achievementDoc =
        await firestore.collection('achievements').doc(achievementId).get();
    if (!achievementDoc.exists) {
      throw FirebaseFunctionsException(
          message: 'Unknown achievement.', code: 'not-found');
    }
    final achievement = achievementDoc.data()!;
    final points = achievement['points'] as int;

    await firestore.collection('user_achievements').add({
      'userId': userId,
      'achievementId': achievementId,
      'achievementName': achievement['name'],
      'category': achievement['category'],
      'points': points,
      'popupShown': false,
    });

    final userRef = firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    final current = (userSnap.data()?['totalAchievementPoints'] as int?) ?? 0;
    final newTotal = current + points;
    await userRef.set({
      'totalAchievementPoints': newTotal,
      'allTimePoints':
          ((userSnap.data()?['allTimePoints'] as int?) ?? 0) + points,
    }, SetOptions(merge: true));

    return {
      'unlocked': true,
      'achievementId': achievementId,
      'points': points,
      'newTotalPoints': newTotal,
      'promotedLeague': null,
    };
  });
}

AchievementService buildAchievementService({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
  PointsEngineClient? pointsEngineClient,
}) {
  return AchievementService.withInstances(
    auth: auth,
    firestore: firestore,
    notificationService: NotificationService.withInstances(
      auth: auth,
      firestore: firestore,
    ),
    weeklyChallengeService: WeeklyChallengeService.withInstances(
      firestore: firestore,
    ),
    pointsEngineClient: pointsEngineClient,
  );
}

Future<void> seedAchievement(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String type,
  required int requiredValue,
  required int points,
  String category = 'general',
}) async {
  await firestore.collection('achievements').doc(id).set({
    'id': id,
    'name': id,
    'description': 'desc',
    'emoji': '🏅',
    'category': category,
    'type': type,
    'requiredValue': requiredValue,
    'points': points,
  });
}

void main() {
  group('AchievementService.checkAndUnlockAchievements', () {
    test('unlocking an achievement calls the points engine, writes the '
        'unlock, awards points, and sends a notification', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'reader-1', email: 'r@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reader-1').set({
        'username': 'Reader',
        'totalAchievementPoints': 0,
      });
      await seedAchievement(
        firestore,
        id: 'first-book',
        type: 'books_read',
        requiredValue: 1,
        points: 10,
      );
      final service = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient:
            fakeUnlockClient(firestore: firestore, userId: 'reader-1'),
      );

      final unlocked = await service.checkAndUnlockAchievements(booksCompleted: 1);

      expect(unlocked.map((a) => a.id), ['first-book']);

      final unlockDocs = await firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: 'reader-1')
          .get();
      expect(unlockDocs.docs, hasLength(1));
      expect(unlockDocs.docs.first.data()['achievementId'], 'first-book');
      expect(unlockDocs.docs.first.data()['points'], 10);

      final userDoc = await firestore.collection('users').doc('reader-1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 10);
      expect(userDoc.data()!['allTimePoints'], 10);

      final notifications = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: 'reader-1')
          .get();
      expect(notifications.docs, hasLength(1));
      expect(notifications.docs.first.data()['type'], 'achievement');
    });

    test('an already-unlocked achievement (per the local cache) is never '
        'attempted twice', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'reader-2', email: 'r2@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reader-2').set({'totalAchievementPoints': 0});
      await seedAchievement(
        firestore,
        id: 'first-book',
        type: 'books_read',
        requiredValue: 1,
        points: 10,
      );

      final first = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient:
            fakeUnlockClient(firestore: firestore, userId: 'reader-2'),
      );
      final firstUnlocked = await first.checkAndUnlockAchievements(booksCompleted: 1);
      expect(firstUnlocked, hasLength(1));

      // A second, independent service instance (simulating a later app
      // session with a cold cache) asks the points engine again, which
      // this time reports it's already unlocked server-side.
      final second = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient: fakeUnlockClient(
          firestore: firestore,
          userId: 'reader-2',
          alreadyUnlockedIds: {'first-book'},
        ),
      );
      final secondUnlocked = await second.checkAndUnlockAchievements(booksCompleted: 5);
      expect(secondUnlocked, isEmpty);

      final userDoc = await firestore.collection('users').doc('reader-2').get();
      expect(userDoc.data()!['totalAchievementPoints'], 10); // not double-awarded
    });

    test('progress below the threshold (per the local pre-check) never '
        'even calls the points engine', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'reader-3', email: 'r3@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reader-3').set({'totalAchievementPoints': 0});
      await seedAchievement(
        firestore,
        id: 'ten-books',
        type: 'books_read',
        requiredValue: 10,
        points: 50,
      );
      final service = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient: PointsEngineClient.withCaller(
          (name, data) => throw StateError(
              'should not be called: local pre-check should have skipped it'),
        ),
      );

      final unlocked = await service.checkAndUnlockAchievements(booksCompleted: 3);

      expect(unlocked, isEmpty);
      final unlockDocs = await firestore.collection('user_achievements').get();
      expect(unlockDocs.docs, isEmpty);
    });

    test('a failed-precondition from the server (its own re-verification '
        'disagreeing with the local pre-check) is treated as "not unlocked" '
        'rather than a crash', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'reader-3b', email: 'r3b@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reader-3b').set({'totalAchievementPoints': 0});
      await seedAchievement(
        firestore,
        id: 'first-book',
        type: 'books_read',
        requiredValue: 1,
        points: 10,
      );
      final service = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient: PointsEngineClient.withCaller(
          (name, data) => throw FirebaseFunctionsException(
            message: 'Requirements not met.',
            code: 'failed-precondition',
          ),
        ),
      );

      final unlocked = await service.checkAndUnlockAchievements(booksCompleted: 1);

      expect(unlocked, isEmpty);
    });

    test('multiple achievement types are evaluated independently in one call', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'reader-4', email: 'r4@example.com'),
        signedIn: true,
      );
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('reader-4').set({'totalAchievementPoints': 0});
      await seedAchievement(firestore,
          id: 'first-book', type: 'books_read', requiredValue: 1, points: 10);
      await seedAchievement(firestore,
          id: 'three-day-streak', type: 'reading_streak', requiredValue: 3, points: 20);
      await seedAchievement(firestore,
          id: 'ten-books', type: 'books_read', requiredValue: 10, points: 50);
      final service = buildAchievementService(
        auth: auth,
        firestore: firestore,
        pointsEngineClient:
            fakeUnlockClient(firestore: firestore, userId: 'reader-4'),
      );

      final unlocked = await service.checkAndUnlockAchievements(
        booksCompleted: 1,
        readingStreak: 3,
      );

      expect(unlocked.map((a) => a.id).toSet(), {'first-book', 'three-day-streak'});
    });
  });
}
