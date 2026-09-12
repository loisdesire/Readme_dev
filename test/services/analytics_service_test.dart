import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/firebase_service.dart';

AnalyticsService buildService({
  required FakeFirebaseFirestore firestore,
  MockFirebaseAuth? auth,
}) {
  final firebaseService = FirebaseService.withInstances(
    firestore: firestore,
    auth: auth ?? MockFirebaseAuth(),
    storage: MockFirebaseStorage(),
  );
  return AnalyticsService.withInstances(firebaseService: firebaseService);
}

MockFirebaseAuth signedInAs(String uid) => MockFirebaseAuth(
      mockUser: MockUser(uid: uid, email: '$uid@example.com'),
      signedIn: true,
    );

void main() {
  group('AnalyticsService.trackReadingSession', () {
    test('writes nothing without a signed-in user', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore: firestore, auth: MockFirebaseAuth());

      await service.trackReadingSession(
        bookId: 'b1',
        bookTitle: 'Book',
        pageNumber: 5,
        totalPages: 10,
        sessionDurationSeconds: 200,
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
      );

      expect((await firestore.collection('reading_sessions').get()).docs, isEmpty);
    });

    test('sessions under 2 minutes (120s) are dropped, not tracked', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore: firestore, auth: signedInAs('u1'));

      await service.trackReadingSession(
        bookId: 'b1',
        bookTitle: 'Book',
        pageNumber: 1,
        totalPages: 10,
        sessionDurationSeconds: 119,
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
      );

      expect((await firestore.collection('reading_sessions').get()).docs, isEmpty);
    });

    test('a session of exactly 120s or longer is tracked', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore: firestore, auth: signedInAs('u1'));

      await service.trackReadingSession(
        bookId: 'b1',
        bookTitle: 'Book',
        pageNumber: 5,
        totalPages: 10,
        sessionDurationSeconds: 125,
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
      );

      final docs = (await firestore.collection('reading_sessions').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.first.data()['sessionDurationMinutes'], 2); // floor(125/60)
    });
  });

  group('AnalyticsService write-then-read paths', () {
    test('trackQuizCompletion / trackBookInteraction / trackAchievementUnlock '
        'all write scoped to the signed-in user', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(firestore: firestore, auth: signedInAs('u1'));

      await service.trackQuizCompletion(
        traitScores: {'O': 5},
        dominantTraits: ['curious'],
        totalQuestions: 10,
        timeSpentSeconds: 60,
      );
      await service.trackBookInteraction(bookId: 'b1', action: 'favorite');
      await service.trackAchievementUnlock(
        achievementId: 'a1',
        achievementName: 'First Book',
        category: 'reading',
      );

      expect((await firestore.collection('quiz_analytics').get()).docs.first.data()['userId'], 'u1');
      expect((await firestore.collection('book_interactions').get()).docs.first.data()['userId'], 'u1');
      expect((await firestore.collection('achievement_unlocks').get()).docs.first.data()['userId'], 'u1');
    });
  });

  group('AnalyticsService.getUserReadingAnalytics / getParentAnalytics', () {
    test(
        'regression: streak and weekly-data use the SAME injected fake '
        'Firestore as everything else in this service, not the real '
        'FirestoreHelpers() singleton — previously these two fields always '
        'hit the real Firebase.instance regardless of what was injected, '
        'which is exactly what surfaced as a stray "[core/no-app]" error '
        'in unrelated tests', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reading_progress').add({
        'userId': 'u1',
        'lastReadAt': Timestamp.fromDate(DateTime.now()),
        'progressPercentage': 0.5,
        'readingTimeMinutes': 10,
      });
      final service = buildService(firestore: firestore, auth: signedInAs('u1'));

      final analytics = await service.getUserReadingAnalytics('u1');

      // If this fell through to the real singleton, currentStreak would
      // come back 0 (nothing in the real, uninitialized Firestore) instead
      // of reflecting the activity actually seeded into the fake.
      expect(analytics['currentStreak'], 1);
      expect(analytics['weeklyData'], isNotEmpty);
    });

    test('getParentAnalytics also uses the injected fake for streak/weekly '
        'data', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reading_progress').add({
        'userId': 'child1',
        'lastReadAt': Timestamp.fromDate(DateTime.now()),
        'progressPercentage': 0.5,
        'readingTimeMinutes': 10,
      });
      final service = buildService(firestore: firestore);

      final analytics = await service.getParentAnalytics('child1');

      expect(analytics['currentStreak'], 1);
      expect(analytics['weeklyData'], isNotEmpty);
    });
  });

  group('AnalyticsService.getBookPopularityAnalytics', () {
    test('ranks books by start_reading interaction count, most popular first',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('popular').set({'title': 'Popular Book'});
      await firestore.collection('books').doc('niche').set({'title': 'Niche Book'});
      for (var i = 0; i < 3; i++) {
        await firestore
            .collection('book_interactions')
            .add({'bookId': 'popular', 'action': 'start_reading'});
      }
      await firestore.collection('book_interactions').add({'bookId': 'niche', 'action': 'start_reading'});
      await firestore.collection('book_interactions').add({'bookId': 'popular', 'action': 'favorite'});
      final service = buildService(firestore: firestore);

      final result = await service.getBookPopularityAnalytics();

      expect(result.first['bookId'], 'popular');
      expect(result.first['readCount'], 3);
      expect(result.first['title'], 'Popular Book');
    });
  });
}
