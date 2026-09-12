import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/weekly_challenge_celebration_screen.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

// This screen plays a ConfettiController on initState. Under
// flutter_test's fake-clock zone, repeatedly pumping while confetti is
// active does not reliably settle (observed hangs during manual
// screenshot verification — see SECURITY.md), so tests here use only a
// small, fixed number of short pumps rather than pumpAndSettle() or a
// long bounded-pump loop.
Future<void> pumpFew(WidgetTester tester, [int times = 12]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('shows the challenge title, message, and points',
      (tester) async {
    await tester.pumpWidget(wrap(const WeeklyChallengeCelebrationScreen(
      booksCompleted: 3,
      targetBooks: 3,
      pointsEarned: 15,
    )));
    await pumpFew(tester);

    expect(find.text('Weekly Challenge Unlocked!'), findsOneWidget);
    expect(find.text('Challenge Completed!'), findsOneWidget);
    expect(
        find.textContaining('crushed 3 books this week'), findsOneWidget);
    expect(find.text('+15 points'), findsOneWidget);
  });

  testWidgets('singular "book" phrasing when exactly one book completed',
      (tester) async {
    await tester.pumpWidget(wrap(const WeeklyChallengeCelebrationScreen(
      booksCompleted: 1,
      targetBooks: 1,
    )));
    await pumpFew(tester);

    expect(find.textContaining('crushed 1 book this week'), findsOneWidget);
  });

  testWidgets('tapping "Keep the Streak Going" pops the screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WeeklyChallengeCelebrationScreen(
                  booksCompleted: 2,
                  targetBooks: 2,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpFew(tester);

    await tester.tap(find.text('Keep the Streak Going'));
    await pumpFew(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(WeeklyChallengeCelebrationScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const WeeklyChallengeCelebrationScreen(
      booksCompleted: 12,
      targetBooks: 12,
      pointsEarned: 999,
    )));
    await pumpFew(tester);

    expect(tester.takeException(), isNull);
  });
}
