import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/widgets/book_card.dart';

// NOTE: BookCard isn't imported/used anywhere in lib/ today (confirmed via
// grep) — this is dead code from an earlier iteration of the library UI.
// Still worth getting right and covering: dead code has a way of getting
// revived (see ApiService's getChildProgress in SECURITY.md), and the bug
// below was real regardless of whether anything currently renders it.

Book book({
  String id = 'b1',
  String title = 'A Great Book',
  String author = 'Some Author',
  List<String> traits = const ['curious', 'kind'],
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    description: 'desc',
    traits: traits,
    ageRating: '6+',
    estimatedReadingTime: 15,
    createdAt: DateTime.now(),
  );
}

ReadingProgress progress({
  required double progressPercentage,
  bool isCompleted = false,
}) {
  return ReadingProgress(
    id: 'p1',
    userId: 'u1',
    bookId: 'b1',
    currentPage: 1,
    totalPages: 10,
    progressPercentage: progressPercentage,
    readingTimeMinutes: 5,
    lastReadAt: DateTime.now(),
    isCompleted: isCompleted,
  );
}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('no progress yet: shows a "Not started" badge, no progress bar',
      (tester) async {
    await tester.pumpWidget(wrap(BookCard(book: book())));

    expect(find.text('Not started'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
      'regression: a book 50% read shows "50%" and a half-full bar — not '
      '"0%"/empty. ReadingProgress.progressPercentage is a 0.0-1.0 fraction '
      'but ProgressBar expects 0-100; BookCard previously passed the raw '
      'fraction straight through', (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      progress: progress(progressPercentage: 0.5),
    )));

    expect(find.text('50%'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('a completed book\'s progress bar is green', (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      progress: progress(progressPercentage: 1.0, isCompleted: true),
    )));

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.valueColor!.value, Colors.green);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('showAgeRating: false hides the age rating badge',
      (tester) async {
    await tester.pumpWidget(wrap(BookCard(book: book(), showAgeRating: false)));
    expect(find.text('6+'), findsNothing);

    await tester.pumpWidget(wrap(BookCard(book: book(), showAgeRating: true)));
    expect(find.text('6+'), findsOneWidget);
  });

  testWidgets('shows at most 2 trait chips even when the book has more',
      (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(traits: ['curious', 'kind', 'brave', 'creative']),
    )));

    expect(find.text('curious'), findsOneWidget);
    expect(find.text('kind'), findsOneWidget);
    expect(find.text('brave'), findsNothing);
    expect(find.text('creative'), findsNothing);
  });

  testWidgets('tapping the card invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(BookCard));
    expect(tapped, isTrue);
  });
}
