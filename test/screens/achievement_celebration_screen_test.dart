import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/achievement_celebration_screen.dart';
import 'package:readme_app/services/achievement_service.dart';

// The trophy badge is a looping Lottie animation (repeat: true), so
// pumpAndSettle() never terminates here (same class of gotcha as
// ChildHomeScreen's looping PulseAnimation — see SECURITY.md). Bounded,
// repeated pumps are used instead.
Future<void> pumpAndDrain(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Achievement achievement({
  String id = 'a1',
  String name = 'First Book',
  String description = 'Read your first book',
  int points = 10,
}) {
  return Achievement(
    id: id,
    name: name,
    description: description,
    emoji: 'book',
    category: 'reading',
    requiredValue: 1,
    type: 'books_read',
    points: points,
    isUnlocked: true,
  );
}

Widget wrap(List<Achievement> achievements) {
  return MaterialApp(home: AchievementCelebrationScreen(achievements: achievements));
}

void main() {
  testWidgets('shows the achievement name, description, and points',
      (tester) async {
    await tester.pumpWidget(wrap([achievement()]));
    await pumpAndDrain(tester);

    expect(find.text('New Achievement Unlocked!'), findsOneWidget);
    expect(find.text('First Book'), findsOneWidget);
    expect(find.text('Read your first book'), findsOneWidget);
    expect(find.text('+10 points'), findsOneWidget);
  });

  testWidgets('a single achievement shows Share/Close, not a counter or '
      '"Next Achievement"', (tester) async {
    await tester.pumpWidget(wrap([achievement()]));
    await pumpAndDrain(tester);

    expect(find.textContaining('Achievement 1 of'), findsNothing);
    expect(find.text('Share Achievement'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Next Achievement'), findsNothing);
  });

  testWidgets(
      'multiple achievements show a counter and step through with "Next '
      'Achievement"', (tester) async {
    await tester.pumpWidget(wrap([
      achievement(id: 'a1', name: 'First Book'),
      achievement(id: 'a2', name: 'Speed Reader'),
    ]));
    await pumpAndDrain(tester);

    expect(find.text('Achievement 1 of 2'), findsOneWidget);
    expect(find.text('First Book'), findsOneWidget);
    expect(find.text('Next Achievement'), findsOneWidget);

    await tester.tap(find.text('Next Achievement'));
    await pumpAndDrain(tester);

    expect(find.text('Achievement 2 of 2'), findsOneWidget);
    expect(find.text('Speed Reader'), findsOneWidget);
    // Last achievement: no more "Next", back to Share/Close.
    expect(find.text('Next Achievement'), findsNothing);
    expect(find.text('Share Achievement'), findsOneWidget);
  });

  testWidgets('"Skip remaining" on a multi-achievement run pops the screen '
      'immediately', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AchievementCelebrationScreen(achievements: [
                  achievement(id: 'a1', name: 'First Book'),
                  achievement(id: 'a2', name: 'Speed Reader'),
                ]),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpAndDrain(tester);

    await tester.tap(find.text('Skip remaining'));
    await pumpAndDrain(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(AchievementCelebrationScreen), findsNothing);
  });

  testWidgets('an empty description falls back to encouraging copy',
      (tester) async {
    await tester.pumpWidget(wrap([achievement(description: '')]));
    await pumpAndDrain(tester);

    expect(find.text('Keep up the great work!'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow phone width, even with a '
      'long name/description', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap([
      achievement(
        name: 'The Extraordinarily Dedicated Marathon Reader',
        description:
            'Read for an extraordinarily long and impressive amount of time without stopping',
        points: 999,
      ),
    ]));
    await pumpAndDrain(tester);

    expect(tester.takeException(), isNull);
  });
}
