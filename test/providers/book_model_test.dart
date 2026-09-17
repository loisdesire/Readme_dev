import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/book_provider.dart';

void main() {
  group('normalizeTraitsForMatching', () {
    test('lowercases, trims, and keeps only canonical traits', () {
      expect(
        normalizeTraitsForMatching(['  Curious ', 'KIND', 'not-a-trait']),
        ['curious', 'kind'],
      );
    });

    test('maps drifted/legacy trait words to their canonical equivalent', () {
      expect(normalizeTraitsForMatching(['brave']), ['resilient']);
      expect(normalizeTraitsForMatching(['adventurous']), ['curious']);
      expect(normalizeTraitsForMatching(['friendly']), ['kind']);
      expect(normalizeTraitsForMatching(['hardworking']), ['persistent']);
    });

    test('drops empty strings and de-duplicates', () {
      expect(
        normalizeTraitsForMatching(['curious', '', ' ', 'curious', 'CURIOUS']),
        ['curious'],
      );
    });
  });

  group('normalizeAgeRating', () {
    test('null becomes the 4+ default', () {
      // Lowered from '6+' to '4+' to match the app's early-childhood
      // (4-7) target — see SECURITY.md.
      expect(normalizeAgeRating(null), '4+');
    });

    test('a bare number gets a plus appended', () {
      expect(normalizeAgeRating(8), '8+');
    });

    test('a numeric string gets a plus appended', () {
      expect(normalizeAgeRating('10'), '10+');
    });

    test('a string that already has formatting is passed through', () {
      expect(normalizeAgeRating('12+'), '12+');
    });

    test('an empty string falls back to the default', () {
      expect(normalizeAgeRating(''), '4+');
    });
  });

  group('calculateBookRelevanceScore', () {
    Book book(List<String> traits) => Book(
          id: 'b1',
          title: 'Test',
          author: 'Author',
          description: 'desc',
          traits: traits,
          ageRating: '6+',
          estimatedReadingTime: 10,
          createdAt: DateTime(2024),
        );

    test('10 points per matching trait', () {
      final score = calculateBookRelevanceScore(
        book(['curious', 'kind', 'calm']),
        ['curious', 'kind'],
      );
      expect(score, 20);
    });

    test('no overlap scores 0', () {
      final score = calculateBookRelevanceScore(book(['calm']), ['curious']);
      expect(score, 0);
    });

    test('null or empty user traits always score 0, regardless of the book',
        () {
      expect(calculateBookRelevanceScore(book(['curious']), null), 0);
      expect(calculateBookRelevanceScore(book(['curious']), []), 0);
    });

    test('matches through trait synonyms on both sides', () {
      // Book tagged with a legacy word, user traits already canonical.
      final score =
          calculateBookRelevanceScore(book(['brave']), ['resilient']);
      expect(score, 10);
    });
  });

  group('Book.fromFirestore / toMap', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test('round-trips a well-formed document', () async {
      await firestore.collection('books').doc('b1').set({
        'title': 'The Enchanted Monkey',
        'author': 'Maya Adventure',
        'description': 'An adventure.',
        'coverImageUrl': 'https://example.com/cover.png',
        'coverEmoji': '🐒',
        'traits': ['curious', 'adventurous'],
        'tags': ['adventure'],
        'ageRating': 8,
        'estimatedReadingTime': 15,
        'pdfUrl': 'https://example.com/book.pdf',
      });

      final doc = await firestore.collection('books').doc('b1').get();
      final book = Book.fromFirestore(doc);

      expect(book.id, 'b1');
      expect(book.title, 'The Enchanted Monkey');
      expect(book.hasRealCover, isTrue);
      expect(book.hasPdf, isTrue);
      expect(book.ageRating, '8+'); // normalized from the raw number
      expect(book.traits, ['curious', 'adventurous']);
    });

    test('rejects a non-http coverImageUrl/pdfUrl instead of crashing',
        () async {
      await firestore.collection('books').doc('b2').set({
        'title': 'Bad URLs',
        'author': 'X',
        'description': 'd',
        'coverImageUrl': 'not-a-url',
        'pdfUrl': '/local/storage/path.pdf',
        'traits': [],
        'ageRating': '6+',
        'estimatedReadingTime': 10,
      });

      final doc = await firestore.collection('books').doc('b2').get();
      final book = Book.fromFirestore(doc);

      expect(book.coverImageUrl, isNull);
      expect(book.hasRealCover, isFalse);
      expect(book.hasPdf, isFalse);
      expect(book.displayCover, '📚'); // falls back to the default emoji
    });

    test('missing optional fields fall back to sane defaults', () async {
      await firestore.collection('books').doc('b3').set({
        'title': 'Minimal',
        'author': 'Y',
      });

      final doc = await firestore.collection('books').doc('b3').get();
      final book = Book.fromFirestore(doc);

      expect(book.description, '');
      expect(book.traits, isEmpty);
      expect(book.ageRating, '4+'); // normalizeAgeRating's default — see SECURITY.md.
      expect(book.estimatedReadingTime, 15);
    });

    test('toMap output can be written back and read again unchanged', () async {
      final original = Book(
        id: 'ignored', // toMap doesn't include id — Firestore doc id owns it
        title: 'Round Trip',
        author: 'Z',
        description: 'd',
        traits: ['kind'],
        tags: ['friendship'],
        ageRating: '7+',
        estimatedReadingTime: 20,
        createdAt: DateTime(2024, 1, 1),
      );

      await firestore.collection('books').doc('rt').set(original.toMap());
      final doc = await firestore.collection('books').doc('rt').get();
      final reloaded = Book.fromFirestore(doc);

      expect(reloaded.title, original.title);
      expect(reloaded.traits, original.traits);
      expect(reloaded.ageRating, original.ageRating);
      expect(reloaded.createdAt, original.createdAt);
    });
  });

  group('ReadingProgress.fromFirestore', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test('a progressPercentage already stored as 0-1 is left alone', () async {
      await firestore.collection('reading_progress').doc('p1').set({
        'userId': 'u1',
        'bookId': 'b1',
        'currentPage': 5,
        'totalPages': 20,
        'progressPercentage': 0.25,
        'isCompleted': false,
      });

      final doc = await firestore.collection('reading_progress').doc('p1').get();
      final progress = ReadingProgress.fromFirestore(doc);

      expect(progress.progressPercentage, 0.25);
      expect(progress.isCompleted, isFalse);
    });

    test('a legacy 0-100 progressPercentage is normalized to 0-1', () async {
      await firestore.collection('reading_progress').doc('p2').set({
        'userId': 'u1',
        'bookId': 'b1',
        'currentPage': 5,
        'totalPages': 20,
        'progressPercentage': 25.0, // old format
        'isCompleted': false,
      });

      final doc = await firestore.collection('reading_progress').doc('p2').get();
      final progress = ReadingProgress.fromFirestore(doc);

      expect(progress.progressPercentage, 0.25);
    });

    test('currentPage reaching totalPages is treated as completed even if '
        'isCompleted was never set', () async {
      await firestore.collection('reading_progress').doc('p3').set({
        'userId': 'u1',
        'bookId': 'b1',
        'currentPage': 20,
        'totalPages': 20,
        'progressPercentage': 1.0,
      });

      final doc = await firestore.collection('reading_progress').doc('p3').get();
      final progress = ReadingProgress.fromFirestore(doc);

      expect(progress.isCompleted, isTrue);
    });

    test('98%+ progress is treated as completed (mobile page-count fuzziness)',
        () async {
      await firestore.collection('reading_progress').doc('p4').set({
        'userId': 'u1',
        'bookId': 'b1',
        'currentPage': 19,
        'totalPages': 20,
        'progressPercentage': 0.99,
      });

      final doc = await firestore.collection('reading_progress').doc('p4').get();
      final progress = ReadingProgress.fromFirestore(doc);

      expect(progress.isCompleted, isTrue);
    });
  });
}
