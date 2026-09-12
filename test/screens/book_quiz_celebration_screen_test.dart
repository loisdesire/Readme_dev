import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/book/book_quiz_celebration_screen.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

// Same gotcha as book_completion_celebration_screen_test.dart: the
// counting-up stat values only start animating after an initial
// Future.delayed(300ms) with nothing yet scheduled, so pumpAndSettle()
// returns before that delay elapses. Bounded, repeated pumps instead.
Future<void> pumpAndDrain(WidgetTester tester, [int times = 15]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('a passing score (>= 60%) shows "Quiz Mastered" and a green '
      'celebration icon', (tester) async {
    await tester.pumpWidget(wrap(const BookQuizCelebrationScreen(
      score: 4,
      totalQuestions: 5,
      percentage: 80,
      pointsEarned: 8,
      quizDuration: Duration(minutes: 3),
      bookTitle: 'The Great Adventure',
    )));
    await pumpAndDrain(tester);

    expect(find.text('Quiz Mastered'), findsOneWidget);
    expect(find.text('The Great Adventure'), findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets(
      'a failing score (< 60%) shows "Keep Practicing" and a purple book '
      'icon, not a red/failure color', (tester) async {
    await tester.pumpWidget(wrap(const BookQuizCelebrationScreen(
      score: 1,
      totalQuestions: 5,
      percentage: 20,
      pointsEarned: 1,
      quizDuration: Duration(minutes: 3),
      bookTitle: 'The Great Adventure',
    )));
    await pumpAndDrain(tester);

    expect(find.text('Keep Practicing'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsNothing);
  });

  testWidgets('message copy varies by score tier', (tester) async {
    await tester.pumpWidget(wrap(const BookQuizCelebrationScreen(
      score: 5,
      totalQuestions: 5,
      percentage: 100,
      pointsEarned: 10,
      quizDuration: Duration(minutes: 2),
      bookTitle: 'Book',
    )));
    await pumpAndDrain(tester);
    expect(find.text('You totally crushed that quiz'), findsOneWidget);
  });

  testWidgets('tapping "Done" pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BookQuizCelebrationScreen(
                  score: 5,
                  totalQuestions: 5,
                  percentage: 100,
                  pointsEarned: 10,
                  quizDuration: Duration(minutes: 2),
                  bookTitle: 'Book',
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

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(BookQuizCelebrationScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const BookQuizCelebrationScreen(
      score: 5,
      totalQuestions: 5,
      percentage: 100,
      pointsEarned: 999,
      quizDuration: Duration(minutes: 2),
      bookTitle:
          'The Extraordinarily Long and Winding Tale of a Very Persistent Dragon',
    )));
    await pumpAndDrain(tester);

    expect(tester.takeException(), isNull);
  });
}
