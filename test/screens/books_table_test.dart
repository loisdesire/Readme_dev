import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/admin/widgets/books_table.dart';

// BooksTable's own root Column (header + search box + a fixed-height
// SizedBox wrapping its DataTable) is meant to be scrolled by its parent —
// AdminPortalScreen always wraps its tab content in a SingleChildScrollView
// — so it needs the same wrapper here, or its fixed-height table overflows
// the test viewport.
Widget wrap(FakeFirebaseFirestore firestore) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BooksTable(firestoreOverride: firestore),
      ),
    ),
  );
}

Future<void> seedBook(
  FakeFirebaseFirestore firestore,
  String id, {
  String title = 'A Book',
  String author = 'Author',
  bool needsTagging = false,
  String pdfUrl = 'https://example.com/x.pdf',
}) {
  return firestore.collection('books').doc(id).set({
    'title': title,
    'author': author,
    'description': 'desc',
    'ageRating': '6+',
    'needsTagging': needsTagging,
    'pdfUrl': pdfUrl,
    'createdAt': Timestamp.now(),
  });
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  testWidgets('shows an empty state with no books', (tester) async {
    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('No books uploaded yet'), findsOneWidget);
  });

  testWidgets('lists every book with its title, author, and tagging status',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales', needsTagging: true);
    await seedBook(firestore, 'b2', title: 'Space Explorers', needsTagging: false);

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Dragon Tales'), findsOneWidget);
    expect(find.text('Space Explorers'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget); // needs tagging
    expect(find.text('Tagged'), findsOneWidget);
  });

  testWidgets('typing in the search box filters by title or author',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales', author: 'Jane Doe');
    await seedBook(firestore, 'b2', title: 'Space Explorers', author: 'John Roe');

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'dragon');
    await tester.pumpAndSettle();

    expect(find.text('Dragon Tales'), findsOneWidget);
    expect(find.text('Space Explorers'), findsNothing);
  });

  testWidgets('a search matching no books shows "No books found"',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales');

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('No books found'), findsOneWidget);
  });

  testWidgets(
      'confirming the delete dialog removes the book from Firestore',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales');

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete Book'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Book deleted successfully'), findsOneWidget);
    expect(find.text('Dragon Tales'), findsNothing);
    final doc = await firestore.collection('books').doc('b1').get();
    expect(doc.exists, isFalse);
  });

  testWidgets('cancelling the delete dialog keeps the book', (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales');

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Dragon Tales'), findsOneWidget);
    final doc = await firestore.collection('books').doc('b1').get();
    expect(doc.exists, isTrue);
  });

  testWidgets('editing a book through the dialog saves the new values',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales', author: 'Jane Doe');

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.edit));
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Edit Book'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Dragon Tales'), 'Dragon Tales 2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Book updated successfully'), findsOneWidget);
    expect(find.text('Dragon Tales 2'), findsOneWidget);
    final doc = await firestore.collection('books').doc('b1').get();
    expect(doc.data()!['title'], 'Dragon Tales 2');
  });
}
