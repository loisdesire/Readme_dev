import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/book/book_completion_celebration_screen.dart';
import 'package:readme_app/screens/book/book_quiz_screen.dart';
import 'package:readme_app/utils/page_transitions.dart';

Widget wrap(Widget child, {List<NavigatorObserver> observers = const []}) =>
    MaterialApp(home: child, navigatorObservers: observers);

/// Captures pushed routes without ever pumping the frame that would build
/// them. Needed for the "Take Quiz" test below: BookQuizScreen's own
/// initState reaches for a real Firestore-backed singleton with no
/// override available from this call site, so actually letting it mount
/// would crash in a test environment with no Firebase app — same gotcha as
/// parent_home_screen_test.dart's push-target inspection. Reading the
/// already-pushed route's `.page` property directly sidesteps that.
class RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  // Navigator.pushReplacement (used by "Take Quiz") notifies observers via
  // didReplace, not didPush.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) pushedRoutes.add(newRoute);
  }
}

// The counting-up point/time values only start animating after an initial
// Future.delayed(800ms) with nothing else scheduled beforehand — no
// AnimationController is ticking yet, so pumpAndSettle() (which only pumps
// while a frame is scheduled) sees "nothing to settle" and returns almost
// immediately, well before that delay elapses. Bounded, repeated pumps
// advance real/fake time regardless of whether anything is scheduled.
Future<void> pumpAndDrain(WidgetTester tester, [int times = 15]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('shows the book title, trophy, and completion message',
      (tester) async {
    await tester.pumpWidget(wrap(const BookCompletionCelebrationScreen(
      bookId: 'b1',
      bookTitle: 'The Great Adventure',
      pointsEarned: 25,
      isFirstCompletion: true,
      totalBooksCompleted: 4,
      readingDuration: Duration(minutes: 22),
      pagesRead: 40,
    )));
    await pumpAndDrain(tester);

    expect(find.text('Book Conquered'), findsOneWidget);
    expect(find.text('The Great Adventure'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(
        find.text('Amazing! That\'s 4 books completed!'), findsOneWidget);
    expect(find.text('22 min'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
  });

  testWidgets('a repeat read (not first completion) shows different copy',
      (tester) async {
    await tester.pumpWidget(wrap(const BookCompletionCelebrationScreen(
      bookId: 'b1',
      bookTitle: 'The Great Adventure',
      pointsEarned: 5,
      isFirstCompletion: false,
      totalBooksCompleted: 4,
    )));
    await pumpAndDrain(tester);

    expect(find.text('Great job reading this again!'), findsOneWidget);
  });

  testWidgets('a single completed book uses singular "book" phrasing',
      (tester) async {
    await tester.pumpWidget(wrap(const BookCompletionCelebrationScreen(
      bookId: 'b1',
      bookTitle: 'The Great Adventure',
      pointsEarned: 5,
      isFirstCompletion: true,
      totalBooksCompleted: 1,
    )));
    await pumpAndDrain(tester);

    expect(find.text('Amazing! That\'s 1 book completed!'), findsOneWidget);
  });

  testWidgets('tapping "Take Quiz" navigates to BookQuizScreen for the '
      'same book', (tester) async {
    final observer = RecordingNavigatorObserver();
    await tester.pumpWidget(wrap(
      const BookCompletionCelebrationScreen(
        bookId: 'b1',
        bookTitle: 'The Great Adventure',
        pointsEarned: 5,
        isFirstCompletion: true,
        totalBooksCompleted: 1,
      ),
      observers: [observer],
    ));
    await pumpAndDrain(tester);

    await tester.tap(find.text('Take Quiz'));
    // No further pumping: BookQuizScreen's own initState reaches for a
    // real singleton with no override from this call site (see
    // RecordingNavigatorObserver's doc comment above).

    final pushedPage =
        (observer.pushedRoutes.last as SlideUpRoute).page as BookQuizScreen;
    expect(pushedPage.bookId, 'b1');
    expect(pushedPage.bookTitle, 'The Great Adventure');
  });

  testWidgets('tapping "Close" pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BookCompletionCelebrationScreen(
                  bookId: 'b1',
                  bookTitle: 'The Great Adventure',
                  pointsEarned: 5,
                  isFirstCompletion: true,
                  totalBooksCompleted: 1,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpAndDrain(tester);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(BookCompletionCelebrationScreen), findsNothing);
  });

  testWidgets(
      'does not overflow on a narrow phone width, even with a long title',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const BookCompletionCelebrationScreen(
      bookId: 'b1',
      bookTitle:
          'The Extraordinarily Long and Winding Tale of a Very Persistent Dragon',
      pointsEarned: 999,
      isFirstCompletion: true,
      totalBooksCompleted: 42,
      readingDuration: Duration(hours: 1, minutes: 5),
    )));
    await pumpAndDrain(tester);

    expect(tester.takeException(), isNull);
  });
}
