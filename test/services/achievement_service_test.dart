import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

/// Builds an AchievementService wired end-to-end to fakes: a signed-in
/// MockFirebaseAuth user, a FakeFirebaseFirestore, and matching
/// NotificationService/WeeklyChallengeService instances (both singletons
/// in production — separate `.withInstances` here keeps each test isolated
/// instead of sharing app-wide state between tests).
AchievementService buildAchievementService({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
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
    test('unlocking an achievement writes the unlock, awards points, and '
        'sends a notification — end to end against a fake Firestore', () async {
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
      final service = buildAchievementService(auth: auth, firestore: firestore);

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

    test('an already-unlocked achievement is never awarded twice', () async {
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

      // First call unlocks it.
      final first = buildAchievementService(auth: auth, firestore: firestore);
      final firstUnlocked = await first.checkAndUnlockAchievements(booksCompleted: 1);
      expect(firstUnlocked, hasLength(1));

      // A second, independent service instance (simulating a later app
      // session with a cold cache) must see it as already unlocked.
      final second = buildAchievementService(auth: auth, firestore: firestore);
      final secondUnlocked = await second.checkAndUnlockAchievements(booksCompleted: 5);
      expect(secondUnlocked, isEmpty);

      final userDoc = await firestore.collection('users').doc('reader-2').get();
      expect(userDoc.data()!['totalAchievementPoints'], 10); // not double-awarded
    });

    test('progress below the threshold unlocks nothing', () async {
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
      final service = buildAchievementService(auth: auth, firestore: firestore);

      final unlocked = await service.checkAndUnlockAchievements(booksCompleted: 3);

      expect(unlocked, isEmpty);
      final unlockDocs = await firestore.collection('user_achievements').get();
      expect(unlockDocs.docs, isEmpty);
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
      final service = buildAchievementService(auth: auth, firestore: firestore);

      final unlocked = await service.checkAndUnlockAchievements(
        booksCompleted: 1,
        readingStreak: 3,
      );

      expect(unlocked.map((a) => a.id).toSet(), {'first-book', 'three-day-streak'});
    });
  });
}
