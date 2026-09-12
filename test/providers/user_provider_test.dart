import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/reading_session_service.dart';

UserProvider buildUserProvider(FakeFirebaseFirestore firestore) {
  final firebaseService = FirebaseService.withInstances(
    auth: MockFirebaseAuth(),
    firestore: firestore,
    storage: MockFirebaseStorage(),
  );
  return UserProvider(
    firebaseService: firebaseService,
    firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

void main() {
  group('UserProvider.loadUserData', () {
    test('loads the profile, personality traits, and completed-book count',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'username': 'Kid',
        'personalityTraits': ['curious', 'kind'],
      });
      await firestore.collection('reading_progress').doc('p1').set({
        'userId': 'u1',
        'bookId': 'b1',
        'isCompleted': true,
        'lastReadAt': DateTime.now(),
      });
      await firestore.collection('reading_progress').doc('p2').set({
        'userId': 'u1',
        'bookId': 'b2',
        'isCompleted': false,
        'lastReadAt': DateTime.now(),
      });
      final provider = buildUserProvider(firestore);

      await provider.loadUserData('u1', force: true);

      expect(provider.userProfile?['username'], 'Kid');
      expect(provider.personalityTraits, ['curious', 'kind']);
      expect(provider.totalBooksRead, 1); // only the completed one counts
    });

    test('syncs totalBooksRead and currentStreak back onto the user doc '
        '(for the leaderboard)', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      await firestore.collection('reading_progress').doc('p1').set({
        'userId': 'u1',
        'bookId': 'b1',
        'isCompleted': true,
        'lastReadAt': DateTime.now(),
      });
      final provider = buildUserProvider(firestore);

      await provider.loadUserData('u1', force: true);

      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['totalBooksRead'], 1);
      expect(doc.data()!.containsKey('currentStreak'), isTrue);
    });

    test('a missing user document does not crash — stats still load', () async {
      final firestore = FakeFirebaseFirestore();
      final provider = buildUserProvider(firestore);

      await provider.loadUserData('ghost-user', force: true);

      expect(provider.userProfile, isNull);
      expect(provider.totalBooksRead, 0);
    });

    test('a reload within the coalescing window is skipped unless forced',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);

      // Change the underlying data, then reload without force immediately after.
      await firestore.collection('users').doc('u1').update({'username': 'Renamed'});
      await provider.loadUserData('u1'); // not forced — should be skipped

      expect(provider.userProfile?['username'], 'Kid'); // stale, as expected

      await provider.loadUserData('u1', force: true);
      expect(provider.userProfile?['username'], 'Renamed');
    });
  });

  group('UserProvider profile/trait updates', () {
    test('updatePersonalityTraits writes to Firestore and updates local state',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildUserProvider(firestore);

      await provider.updatePersonalityTraits('u1', ['kind', 'calm']);

      expect(provider.personalityTraits, ['kind', 'calm']);
      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['personalityTraits'], ['kind', 'calm']);
      expect(doc.data()!['hasCompletedQuiz'], true);
    });

    test('updateUserProfile merges updates into both Firestore and the '
        'in-memory profile', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'username': 'Kid',
        'avatar': '👦',
      });
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);

      await provider.updateUserProfile('u1', {'avatar': '🦄'});

      expect(provider.userProfile?['avatar'], '🦄');
      expect(provider.userProfile?['username'], 'Kid'); // untouched field survives
      final doc = await firestore.collection('users').doc('u1').get();
      expect(doc.data()!['avatar'], '🦄');
    });
  });

  group('UserProvider daily/weekly derived stats', () {
    test('hasReadToday and getTodayReadingMinutes reflect today\'s logged '
        'reading session minutes exactly', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      await firestore.collection('reading_sessions').doc('s1').set({
        'userId': 'u1',
        'createdAt': DateTime.now(),
        'sessionDurationSeconds': 12 * 60,
      });
      final provider = buildUserProvider(firestore);

      await provider.loadUserData('u1', force: true);

      expect(provider.hasReadToday(), isTrue);
      expect(provider.getTodayReadingMinutes(), 12);
    });

    test('with no reading_sessions at all, hasReadToday is false', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildUserProvider(firestore);

      await provider.loadUserData('u1', force: true);

      expect(provider.hasReadToday(), isFalse);
      expect(provider.getTodayReadingMinutes(), 0);
    });

    test('getDailyGoalProgress is 0 with no reading and clamps at 1.0 once '
        'the daily goal (15 min) is met or exceeded', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);
      expect(provider.getDailyGoalProgress(), 0.0);

      // Minutes for the weekly/daily view come from reading_sessions (not
      // reading_progress.readingTimeMinutes, which only marks day-level
      // activity) — verified by first getting this wrong and seeing the
      // fallback "1 minute for any activity" value instead of 999.
      await firestore.collection('reading_sessions').doc('s1').set({
        'userId': 'u1',
        'createdAt': DateTime.now(),
        'sessionDurationSeconds': 999 * 60, // way past the 15-minute goal
      });
      await provider.loadUserData('u1', force: true);
      expect(provider.getDailyGoalProgress(), 1.0);
    });
  });

  group('UserProvider.getUnlockedAchievements', () {
    // Note: this is a separate, simpler local badge scheme (string labels
    // like 'First Book') distinct from the Firestore-backed AchievementService
    // system tested in achievement_service_test.dart — both exist in the app
    // today; this just verifies UserProvider's own thresholds.
    test('returns only the badges whose thresholds are actually met', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      for (var i = 0; i < 5; i++) {
        await firestore.collection('reading_progress').doc('p$i').set({
          'userId': 'u1',
          'bookId': 'b$i',
          'isCompleted': true,
          'lastReadAt': DateTime.now(),
        });
      }
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);

      expect(provider.totalBooksRead, 5);
      final achievements = provider.getUnlockedAchievements();
      expect(achievements, contains('First Book'));
      expect(achievements, contains('Book Lover')); // 5+ books threshold
    });

    test('no books read unlocks nothing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);

      expect(provider.getUnlockedAchievements(), isEmpty);
    });
  });

  group('UserProvider.clearUserData', () {
    test('resets every stat back to its default', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'username': 'Kid',
        'personalityTraits': ['curious'],
      });
      final provider = buildUserProvider(firestore);
      await provider.loadUserData('u1', force: true);
      expect(provider.userProfile, isNotNull);

      provider.clearUserData();

      expect(provider.userProfile, isNull);
      expect(provider.personalityTraits, isEmpty);
      expect(provider.totalBooksRead, 0);
      expect(provider.totalReadingMinutes, 0);
      expect(provider.weeklyProgress, isEmpty);
      expect(provider.dailyReadingStreak, 0);
    });
  });
}
