import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/api_service.dart';

ApiService buildService(FakeFirebaseFirestore firestore) {
  return ApiService.withInstances(firestore: firestore);
}

void main() {
  // getRecommendedBooks is the only ApiService method actually called from
  // the app today (via BookProvider) — see SECURITY.md for the rest, which
  // is unreferenced. Tested here in isolation for behavior book_provider_test
  // doesn't specifically stress: order preservation and >10-ID chunking.
  group('ApiService.getRecommendedBooks', () {
    test('prefers AI recommendations from the user doc, in the exact order '
        'listed, over trait-based matching', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('b1').set({'title': 'B1', 'traits': []});
      await firestore.collection('books').doc('b2').set({'title': 'B2', 'traits': []});
      await firestore.collection('users').doc('u1').set({
        'aiRecommendations': ['b2', 'b1'], // deliberately out of natural order
      });
      final service = buildService(firestore);

      final result = await service.getRecommendedBooks(['curious'], userId: 'u1');

      expect(result.map((b) => b['id']).toList(), ['b2', 'b1']);
    });

    test('preserves requested order across a >10-ID whereIn chunk boundary',
        () async {
      final firestore = FakeFirebaseFirestore();
      final ids = List.generate(12, (i) => 'b$i');
      for (final id in ids) {
        await firestore.collection('books').doc(id).set({'title': id});
      }
      // Reversed order, spanning the 10-item whereIn chunk limit.
      final requestedOrder = ids.reversed.toList();
      await firestore.collection('users').doc('u1').set({
        'aiRecommendations': requestedOrder,
      });
      final service = buildService(firestore);

      final result = await service.getRecommendedBooks([], userId: 'u1');

      expect(result.map((b) => b['id']).toList(), requestedOrder);
    });

    test('an AI recommendation ID for a book that no longer exists is '
        'silently dropped, not left as a null/broken entry', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('exists').set({'title': 'Exists'});
      await firestore.collection('users').doc('u1').set({
        'aiRecommendations': ['exists', 'deleted-book'],
      });
      final service = buildService(firestore);

      final result = await service.getRecommendedBooks([], userId: 'u1');

      expect(result.map((b) => b['id']).toList(), ['exists']);
    });

    test('falls back to trait-based matching when the user has no AI '
        'recommendations', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('match').set({'title': 'Match', 'traits': ['curious']});
      await firestore.collection('books').doc('nomatch').set({'title': 'NoMatch', 'traits': ['brave']});
      await firestore.collection('users').doc('u1').set({});
      final service = buildService(firestore);

      final result = await service.getRecommendedBooks(['curious'], userId: 'u1');

      expect(result.map((b) => b['id']).toList(), ['match']);
    });

    test('falls back to trait-based matching when no userId is given at all',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('match').set({'title': 'Match', 'traits': ['curious']});
      final service = buildService(firestore);

      final result = await service.getRecommendedBooks(['curious']);

      expect(result.map((b) => b['id']).toList(), ['match']);
    });
  });

  group('ApiService.getBookContent', () {
    test('returns the book merged with its id', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('books').doc('b1').set({'title': 'B1'});
      final service = buildService(firestore);

      final result = await service.getBookContent('b1');

      expect(result['id'], 'b1');
      expect(result['title'], 'B1');
    });

    test('throws ApiException for a book that does not exist', () async {
      final service = buildService(FakeFirebaseFirestore());
      expect(
        () => service.getBookContent('missing'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
