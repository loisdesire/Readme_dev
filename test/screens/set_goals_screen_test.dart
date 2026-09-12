import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/parent/set_goals_screen.dart';

// NOTE: SetGoalsScreen is currently dead code — grep confirms nothing in
// lib/ navigates to it (no route, no button, no reference anywhere outside
// this file). Tested anyway for completeness/documentation, per SECURITY.md.
// Also worth recording: even if it were wired up, "Save Goal" doesn't
// persist the chosen goal anywhere (no Firestore write, no provider call,
// no childId to know whose goal it even is) — it only shows a SnackBar and
// pops, so the goal would vanish the instant the screen closes. The actual
// "reading goal" read elsewhere in the app (ParentDashboardScreen's
// readingGoal) comes from ContentFilterService.maxReadingTimeMinutes,
// which this screen never touches.

Widget wrap() {
  return const MaterialApp(home: SetGoalsScreen());
}

void main() {
  testWidgets('starts at the default 15-minute goal', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('15 minutes per day'), findsOneWidget);
  });

  testWidgets('tapping a preset button updates the daily goal display',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.ensureVisible(find.text('Advanced\n30 min'));
    await tester.tap(find.text('Advanced\n30 min'));
    await tester.pump();

    expect(find.text('30 minutes per day'), findsOneWidget);
  });

  testWidgets('dragging the slider to its minimum shows 5 minutes',
      (tester) async {
    await tester.pumpWidget(wrap());

    final sliderRect = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(sliderRect.left + 1, sliderRect.center.dy));
    await tester.pump();

    expect(find.text('5 minutes per day'), findsOneWidget);
  });

  testWidgets(
      'turning off "Daily reminders" hides the reminder-time picker row',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Reminder time'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.text('Reminder time'), findsNothing);
  });

  testWidgets(
      'tapping "Save Goal" shows a confirmation snackbar naming the chosen '
      'minutes and pops the screen — but persists nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetGoalsScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Beginner\n5 min'));
    await tester.tap(find.text('Beginner\n5 min'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Goal'));
    await tester.tap(find.text('Save Goal'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('Goal set to 5 minutes per day!'), findsOneWidget);
  });
}
