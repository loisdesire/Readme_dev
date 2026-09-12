import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';

ContentFilterService buildService({FakeFirebaseFirestore? firestore}) {
  return ContentFilterService.withInstances(
    firebaseService: FirebaseService.withInstances(
      firestore: firestore ?? FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(),
      storage: MockFirebaseStorage(),
    ),
  );
}

Map<String, dynamic> book({
  String id = 'book-1',
  String title = 'A story',
  String description = '',
  String ageRating = '6+',
  String author = 'Some Author',
  List<String> tags = const ['adventure'],
}) {
  return {
    'id': id,
    'title': title,
    'description': description,
    'ageRating': ageRating,
    'author': author,
    'tags': tags,
  };
}

void main() {
  group('ContentFilterService.filterBooks — default (unconfigured) filter', () {
    // Every user gets this default filter (enableSafeMode: true) until a
    // parent explicitly visits the content-filter screen, so a false
    // positive here silently removes a book from every library by default.
    test(
        'wholesome, common phrases are not blocked by whole-word-unsafe '
        'substrings ("skills" containing "kill", "begun" containing "gun", '
        '"warm"/"awarded"/"forward" containing "war")', () async {
      final service = buildService();
      final books = [
        book(id: '1', description: 'Learn problem-solving skills and teamwork'),
        book(id: '2', description: 'Her adventure has begun in a magical forest'),
        book(id: '3', description: 'A story about a warm friendship'),
        book(id: '4', description: 'The knight was awarded a medal for kindness'),
        book(id: '5', description: 'He looked forward to seeing his grandma'),
      ];

      final filtered = await service.filterBooks(books, 'user-1');

      expect(filtered.map((b) => b['id']).toSet(), {'1', '2', '3', '4', '5'});
    });

    test('a real unsafe word is still blocked as a whole word', () async {
      final service = buildService();
      final books = [
        book(id: 'safe', description: 'A gentle bedtime story'),
        book(id: 'unsafe', description: 'The dragon wanted to kill the hero'),
      ];

      final filtered = await service.filterBooks(books, 'user-1');

      expect(filtered.map((b) => b['id']), ['safe']);
    });

    test('a book tagged only with a category outside the old 23-item list '
        'is still allowed (regression: allowedCategories must stay in sync '
        "with functions/lib/ai_helpers.js's ALLOWED_TAGS)", () async {
      final service = buildService();
      final books = [
        book(id: '1', tags: ['organization']),
        book(id: '2', tags: ['enthusiasm']),
        book(id: '3', tags: ['positivity']),
        book(id: '4', tags: ['patience']),
        book(id: '5', tags: ['generosity']),
        book(id: '6', tags: ['helpfulness']),
        book(id: '7', tags: ['playfulness']),
        book(id: '8', tags: ['innovation']),
      ];

      final filtered = await service.filterBooks(books, 'user-1');

      expect(filtered, hasLength(8));
    });

    test('a parent-configured blocked word still matches as a whole word '
        'but not as a substring of an unrelated word', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('content_filters').doc('user-1').set({
        'userId': 'user-1',
        'allowedCategories': <String>[],
        'blockedWords': ['ass'], // classic false-positive-prone word
        'maxAgeRating': '12+',
        'enableSafeMode': false,
        'allowedAuthors': <String>[],
        'blockedAuthors': <String>[],
        'maxReadingTimeMinutes': 60,
        'allowedTimes': ['06:00-22:00'],
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      final service = buildService(firestore: firestore);
      final books = [
        book(id: 'classic', description: 'A tale of a bold, classic hero'),
        book(id: 'assembly', description: 'The friends assemble a treehouse'),
        book(id: 'blocked', description: 'He is an ass sometimes'),
      ];

      final filtered = await service.filterBooks(books, 'user-1');

      expect(filtered.map((b) => b['id']).toSet(), {'classic', 'assembly'});
    });
  });
}
