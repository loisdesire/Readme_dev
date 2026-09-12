import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/parent/reading_history_screen.dart';

Widget wrap(FakeFirebaseFirestore firestore, String childId) {
  return MaterialApp(
    home: ReadingHistoryScreen(childId: childId, firestoreOverride: firestore),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  testWidgets('shows the empty state when the child has no reading progress',
      (tester) async {
    await tester.pumpWidget(wrap(firestore, 'child-1'));
    await tester.pumpAndSettle();

    expect(find.text('No reading history yet'), findsOneWidget);
  });

  testWidgets(
      'shows an ongoing and a completed book with their title, author, and '
      'progress', (tester) async {
    await firestore.collection('books').doc('b1').set({
      'title': 'Dragon Tales',
      'author': 'Jane Doe',
    });
    await firestore.collection('books').doc('b2').set({
      'title': 'Space Explorers',
      'author': 'John Roe',
    });
    await firestore.collection('reading_progress').add({
      'userId': 'child-1',
      'bookId': 'b1',
      'progressPercentage': 0.5,
      'isCompleted': false,
      'lastReadAt': Timestamp.fromDate(DateTime.now()),
      'readingTimeMinutes': 20,
      'currentPage': 5,
      'totalPages': 10,
    });
    await firestore.collection('reading_progress').add({
      'userId': 'child-1',
      'bookId': 'b2',
      'progressPercentage': 1.0,
      'isCompleted': true,
      'lastReadAt': Timestamp.fromDate(DateTime.now()),
      'readingTimeMinutes': 40,
      'currentPage': 10,
      'totalPages': 10,
    });

    await tester.pumpWidget(wrap(firestore, 'child-1'));
    await tester.pumpAndSettle();

    expect(find.text('Dragon Tales'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Progress: 50%'), findsOneWidget);
    expect(find.text('Page 5/10'), findsOneWidget);
    expect(find.text('20 min read'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);

    expect(find.text('Space Explorers'), findsOneWidget);
    expect(find.text('Progress: 100%'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('a reading_progress doc pointing at a since-deleted book is '
      'silently skipped', (tester) async {
    // No matching 'books' doc for this bookId.
    await firestore.collection('reading_progress').add({
      'userId': 'child-1',
      'bookId': 'deleted-book',
      'progressPercentage': 0.2,
      'isCompleted': false,
      'lastReadAt': Timestamp.fromDate(DateTime.now()),
    });

    await tester.pumpWidget(wrap(firestore, 'child-1'));
    await tester.pumpAndSettle();

    expect(find.text('No reading history yet'), findsOneWidget);
  });

  testWidgets('only shows history for the requested child, not others',
      (tester) async {
    await firestore.collection('books').doc('b1').set({
      'title': 'Dragon Tales',
      'author': 'Jane Doe',
    });
    await firestore.collection('reading_progress').add({
      'userId': 'other-child',
      'bookId': 'b1',
      'progressPercentage': 0.5,
      'isCompleted': false,
      'lastReadAt': Timestamp.fromDate(DateTime.now()),
    });

    await tester.pumpWidget(wrap(firestore, 'child-1'));
    await tester.pumpAndSettle();

    expect(find.text('No reading history yet'), findsOneWidget);
    expect(find.text('Dragon Tales'), findsNothing);
  });

  testWidgets('tapping back pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReadingHistoryScreen(
                  childId: 'child-1',
                  firestoreOverride: firestore,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(ReadingHistoryScreen), findsNothing);
  });

  testWidgets(
      'the progress/page row does not overflow on a narrow phone width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await firestore.collection('books').doc('b1').set({
      'title': 'Dragon Tales',
      'author': 'Jane Doe',
    });
    await firestore.collection('reading_progress').add({
      'userId': 'child-1',
      'bookId': 'b1',
      'progressPercentage': 0.5,
      'isCompleted': false,
      'lastReadAt': Timestamp.fromDate(DateTime.now()),
      'readingTimeMinutes': 20,
      'currentPage': 5,
      'totalPages': 10,
    });

    await tester.pumpWidget(wrap(firestore, 'child-1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
