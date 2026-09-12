import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/widgets/book_card.dart';
import 'package:readme_app/widgets/book_cover.dart';
import 'package:readme_app/widgets/common/progress_button.dart';

// BookCard is the consolidated design shared by ChildHomeScreen's
// "Recommended for you" list and every LibraryScreen tab — previously each
// of those 6 call sites had its own copy-pasted Container/Row/Column plus
// its own duplicate cover-rendering method. See SECURITY.md's cleanup-pass
// entry for the history.

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
  testWidgets(
      'no progress yet: shows title/author/time/age and a "Start" button, '
      'no progress bar', (tester) async {
    await tester.pumpWidget(wrap(BookCard(book: book())));

    expect(find.text('A Great Book'), findsOneWidget);
    expect(find.text('Some Author'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('6+'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
      'a book in progress shows "Resume", the percentage, and a progress bar',
      (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      progress: progress(progressPercentage: 0.5),
    )));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('a completed book shows "Re-read" and 100%', (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      progress: progress(progressPercentage: 1.0, isCompleted: true),
    )));

    expect(find.text('Re-read'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets(
      'buttonTextOverride/buttonTypeOverride win over the derived state — '
      'regression for the Ongoing/Completed tabs which know their own '
      'bucket regardless of what the progress doc says', (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      // No progress at all — derived state would be "Start" — but the tab
      // overrides it because this book is known to already be ongoing.
      buttonTextOverride: 'Resume',
      buttonTypeOverride: ProgressButtonType.inProgress,
    )));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets(
      'alwaysShowProgress renders a 100% bar even with no progress doc — '
      'used by the Completed tab', (tester) async {
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      alwaysShowProgress: true,
    )));

    expect(find.text('100%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('enableHero: false renders the cover without a Hero wrapper — '
      'regression for duplicate-hero-tag collisions across LibraryScreen '
      'tabs sharing the same book', (tester) async {
    await tester.pumpWidget(wrap(BookCard(book: book(), enableHero: false)));

    final cover = tester.widget<BookCover>(find.byType(BookCover));
    expect(cover.enableHero, isFalse);
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('tapping the action button invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(BookCard(
      book: book(),
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(ProgressButton));
    expect(tapped, isTrue);
  });

  testWidgets(
      'the time/age-rating row does not overflow on a narrow phone width — '
      'regression for a real RenderFlex overflow found while screenshotting '
      'the library screen at 400px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(BookCard(book: book())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
