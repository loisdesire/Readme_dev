import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

/// Builds a BookProvider wired end-to-end to fakes — every Firebase-touching
/// collaborator BookProvider constructs (ApiService, AnalyticsService,
/// AchievementService + its own collaborators, ContentFilterService,
/// WeeklyChallengeService) gets a fake-backed instance, so simply
/// *constructing* a BookProvider doesn't reach for real Firebase.
BookProvider buildBookProvider(FakeFirebaseFirestore firestore, {MockFirebaseAuth? auth}) {
  final resolvedAuth = auth ?? MockFirebaseAuth();
  final firebaseService = FirebaseService.withInstances(
    auth: resolvedAuth,
    firestore: firestore,
    storage: MockFirebaseStorage(),
  );
  return BookProvider(
    firebaseService: firebaseService,
    apiService: ApiService.withInstances(firestore: firestore),
    analyticsService: AnalyticsService.withInstances(firebaseService: firebaseService),
    achievementService: AchievementService.withInstances(
      auth: resolvedAuth,
      firestore: firestore,
      notificationService:
          NotificationService.withInstances(auth: resolvedAuth, firestore: firestore),
      weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    ),
    contentFilterService: ContentFilterService.withInstances(firebaseService: firebaseService),
    weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

Future<void> seedBook(
  FakeFirebaseFirestore firestore,
  String id, {
  required List<String> traits,
  int estimatedReadingTime = 15,
  List<String> tags = const [],
}) async {
  await firestore.collection('books').doc(id).set({
    'title': id,
    'author': 'Author',
    'description': 'desc',
    'traits': traits,
    'tags': tags,
    'ageRating': '6+',
    'estimatedReadingTime': estimatedReadingTime,
  });
}

void main() {
  group('BookProvider.loadAllBooks', () {
    test('loads every book from Firestore into allBooks (no userId => no '
        'content filtering)', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: ['curious']);
      await seedBook(firestore, 'b2', traits: ['kind']);
      final provider = buildBookProvider(firestore);

      await provider.loadAllBooks();

      expect(provider.allBooks, hasLength(2));
      expect(provider.allBooks.map((b) => b.id).toSet(), {'b1', 'b2'});
    });
  });

  group('BookProvider.loadRecommendedBooks (rule-based tier)', () {
    test('scores and ranks books by trait overlap, highest first', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'perfect-match', traits: ['curious', 'kind']);
      await seedBook(firestore, 'partial-match', traits: ['curious']);
      await seedBook(firestore, 'no-match', traits: ['calm']);
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.loadRecommendedBooks(['curious', 'kind']);

      final ids = provider.recommendedBooks.map((b) => b.id).toList();
      expect(ids.indexOf('perfect-match'), lessThan(ids.indexOf('partial-match')));
      expect(ids.contains('no-match'), isFalse); // score 0 is excluded
    });

    test('with no trait overlap at all, falls back to shortest-reading-time '
        'default books rather than an empty list', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'long', traits: ['calm'], estimatedReadingTime: 30);
      await seedBook(firestore, 'short', traits: ['calm'], estimatedReadingTime: 5);
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.loadRecommendedBooks(['curious']); // no book has 'curious'

      expect(provider.recommendedBooks, isNotEmpty);
      expect(provider.recommendedBooks.first.id, 'short');
    });

    test('gracefully ignores a missing/absent AI recommendation field and '
        'keeps the rule-based results', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: ['curious']);
      await firestore.collection('users').doc('u1').set({'username': 'Kid'});
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.loadRecommendedBooks(['curious'], userId: 'u1');

      expect(provider.recommendedBooks.map((b) => b.id), contains('b1'));
    });
  });

  group('BookProvider.combinedRecommendedBooks', () {
    test('AI recs (via aiRecommendations on the user doc) come first, then '
        'rule-based recs not already included', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'ai-pick', traits: []); // no traits, wouldn't score
      await seedBook(firestore, 'rule-pick', traits: ['curious', 'kind', 'calm']);
      await firestore.collection('users').doc('u1').set({
        'aiRecommendations': ['ai-pick'],
      });
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.loadRecommendedBooks(['curious', 'kind', 'calm'], userId: 'u1');

      final combined = provider.combinedRecommendedBooks;
      expect(combined.first.id, 'ai-pick');
      expect(combined.map((b) => b.id), contains('rule-pick'));
    });

    // The "3+ matching traits" comment on combinedRecommendedBooks actually
    // checks the trait *score* (10 points/match) against a threshold of 3 —
    // so in practice any single matching trait (score 10) clears it, and
    // only a zero-match book (score 0) is excluded. Verified here rather
    // than assumed, since the comment reads like it means "3 traits".
    test('a rule-based book with zero matching traits is excluded; even one '
        'match is enough to appear alongside AI picks', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'ai-pick', traits: []);
      await seedBook(firestore, 'one-match', traits: ['curious']);
      await seedBook(firestore, 'zero-match', traits: ['calm']);
      await firestore.collection('users').doc('u1').set({
        'aiRecommendations': ['ai-pick'],
      });
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();
      await provider.loadRecommendedBooks(['curious'], userId: 'u1');

      final combinedIds = provider.combinedRecommendedBooks.map((b) => b.id);

      expect(combinedIds, contains('one-match'));
      expect(combinedIds, isNot(contains('zero-match')));
    });
  });

  group('BookProvider progress + favorites', () {
    test('updateReadingProgress writes to Firestore and is reflected by '
        'getProgressForBook', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: ['curious']);
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.updateReadingProgress(
        userId: 'u1',
        bookId: 'b1',
        currentPage: 5,
        totalPages: 20,
        additionalReadingTime: 3,
      );

      final saved = await firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: 'u1')
          .where('bookId', isEqualTo: 'b1')
          .get();
      expect(saved.docs, hasLength(1));
      expect(saved.docs.first.data()['currentPage'], 5);

      await provider.loadUserProgress('u1');
      final progress = provider.getProgressForBook('b1');
      expect(progress, isNotNull);
      expect(progress!.currentPage, 5);
      expect(progress.isCompleted, isFalse);
    });

    test('once a book is completed, a later non-final-page update does not '
        'revert it to incomplete', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: ['curious']);
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      // Finish the book.
      await provider.updateReadingProgress(
        userId: 'u1',
        bookId: 'b1',
        currentPage: 20,
        totalPages: 20,
        additionalReadingTime: 10,
      );

      // A later write reports an earlier page (e.g. the reader re-opened the
      // book to re-read a section) without explicitly un-completing it.
      await provider.updateReadingProgress(
        userId: 'u1',
        bookId: 'b1',
        currentPage: 5,
        totalPages: 20,
        additionalReadingTime: 1,
      );

      await provider.loadUserProgress('u1');
      final progress = provider.getProgressForBook('b1');
      expect(progress!.isCompleted, isTrue);
      expect(progress.currentPage, 20); // normalized back to 100%
    });

    test('completedAt is set once on first completion and does not move on '
        'a later reopen/reread — regression for the weekly-challenge bug '
        'where reopening an old finished book bumped lastReadAt and was '
        'wrongly counted as a fresh completion', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: ['curious']);
      final provider = buildBookProvider(firestore);
      await provider.loadAllBooks();

      await provider.updateReadingProgress(
        userId: 'u1',
        bookId: 'b1',
        currentPage: 20,
        totalPages: 20,
        additionalReadingTime: 10,
      );
      await provider.loadUserProgress('u1');
      final firstCompletedAt = provider.getProgressForBook('b1')!.completedAt;
      expect(firstCompletedAt, isNotNull);

      // Reopen and read again later — isCompleted stays true (existing
      // behavior), and completedAt must NOT be bumped to now.
      await provider.updateReadingProgress(
        userId: 'u1',
        bookId: 'b1',
        currentPage: 5,
        totalPages: 20,
        additionalReadingTime: 1,
      );
      await provider.loadUserProgress('u1');
      final progress = provider.getProgressForBook('b1')!;

      expect(progress.isCompleted, isTrue);
      expect(progress.completedAt, firstCompletedAt);
    });

    test('favorites: toggling adds then removes from Firestore and the '
        'in-memory set', () async {
      final firestore = FakeFirebaseFirestore();
      await seedBook(firestore, 'b1', traits: []);
      final provider = buildBookProvider(firestore);
      await provider.loadFavorites('u1');
      expect(provider.isFavorite('b1'), isFalse);

      await provider.toggleFavorite('u1', 'b1');
      expect(provider.isFavorite('b1'), isTrue);
      final afterAdd = await firestore
          .collection('user_favorites')
          .doc('u1')
          .collection('favorites')
          .doc('b1')
          .get();
      expect(afterAdd.exists, isTrue);

      await provider.toggleFavorite('u1', 'b1');
      expect(provider.isFavorite('b1'), isFalse);
      final afterRemove = await firestore
          .collection('user_favorites')
          .doc('u1')
          .collection('favorites')
          .doc('b1')
          .get();
      expect(afterRemove.exists, isFalse);
    });
  });
}
