import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/admin/widgets/admin_dashboard.dart';

Widget wrap(FakeFirebaseFirestore firestore) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AdminDashboard(firestoreOverride: firestore),
      ),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  testWidgets('shows zero counts with no books or users', (tester) async {
    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Total Books'), findsOneWidget);
    // All 5 stat cards (Total Books, Total Users, Needs Tagging, Missing
    // PDF, Needs Review) start at 0.
    expect(find.text('0'), findsNWidgets(5));
    expect(find.text('No books yet'), findsOneWidget);
    expect(find.text('No books uploaded yet'), findsOneWidget);
  });

  testWidgets(
      'counts books needing tagging and missing a PDF, and lists recent '
      'books newest-first', (tester) async {
    await firestore.collection('users').doc('u1').set({'accountType': 'child'});
    await firestore.collection('users').doc('u2').set({'accountType': 'parent'});
    await firestore.collection('books').doc('b1').set({
      'title': 'Older Book',
      'author': 'Author A',
      'ageRating': '6+',
      'needsTagging': false,
      'pdfUrl': 'https://example.com/a.pdf',
      'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
    });
    await firestore.collection('books').doc('b2').set({
      'title': 'Newer Book',
      'author': 'Author B',
      'ageRating': '8+',
      'needsTagging': true,
      'pdfUrl': '',
      'createdAt': Timestamp.fromDate(DateTime(2024, 6, 1)),
    });

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    // Total Books=2, Total Users=2, Needs Tagging=1, Missing PDF=1,
    // Needs Review=0.
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('0'), findsOneWidget);

    // Newer Book (2024-06-01) should render before Older Book
    // (2024-01-01) in the "Recent Books" list.
    final newer = tester.getTopLeft(find.text('Newer Book'));
    final older = tester.getTopLeft(find.text('Older Book'));
    expect(newer.dy, lessThan(older.dy));
  });

  testWidgets('counts books flagged needsReview by the AI content-safety '
      'check separately from Needs Tagging', (tester) async {
    await firestore.collection('books').doc('b1').set({
      'title': 'Flagged Book',
      'author': 'Author A',
      'ageRating': '8+',
      'needsTagging': false,
      'needsReview': true,
      'isVisible': false,
      'pdfUrl': 'https://example.com/a.pdf',
      'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
    });
    await firestore.collection('books').doc('b2').set({
      'title': 'Clean Book',
      'author': 'Author B',
      'ageRating': '6+',
      'needsTagging': false,
      'pdfUrl': 'https://example.com/b.pdf',
      'createdAt': Timestamp.fromDate(DateTime(2024, 1, 2)),
    });

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Needs Review'), findsOneWidget);
    // Total Books=2, Needs Tagging=0, Missing PDF=0, Needs Review=1 — four
    // cards showing "0"/"1" would be ambiguous to count directly since
    // Total Users is also 0, so just confirm the specific card's value by
    // finding it via the Needs Review label's sibling.
    final card = find.ancestor(
      of: find.text('Needs Review'),
      matching: find.byType(Column),
    );
    expect(find.descendant(of: card.first, matching: find.text('1')),
        findsOneWidget);
  });

  testWidgets('a book missing createdAt is excluded from Recent Books '
      'without crashing', (tester) async {
    await firestore.collection('books').doc('b1').set({
      'title': 'No Date Book',
      'author': 'Author A',
      'ageRating': '6+',
      // No createdAt field at all.
    });

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Total Books'), findsOneWidget);
    expect(find.text('No Date Book'), findsNothing);
    expect(find.text('No books uploaded yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
