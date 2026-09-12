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
    // Both "Total Books" and "Total Users" (and the other two stat cards)
    // start at 0.
    expect(find.text('0'), findsNWidgets(4));
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

    // Total Books=2, Total Users=2, Needs Tagging=1, Missing PDF=1
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));

    // Newer Book (2024-06-01) should render before Older Book
    // (2024-01-01) in the "Recent Books" list.
    final newer = tester.getTopLeft(find.text('Newer Book'));
    final older = tester.getTopLeft(find.text('Older Book'));
    expect(newer.dy, lessThan(older.dy));
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
