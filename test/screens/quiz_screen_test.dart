import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/quiz/quiz_screen.dart';

Widget wrap() => const MaterialApp(home: QuizScreen());

void main() {
  testWidgets(
      'the "Question X of Y" progress header does not overflow on a '
      'narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Dismiss the intro dialog shown on first frame.
    await tester.tap(find.text('Let\'s Go!'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the intro dialog\'s info rows do not overflow on a narrow phone '
      'width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No wrong answers!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the No / Sometimes / Yes! scale does not overflow on a narrow '
      'phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let\'s Go!'));
    await tester.pumpAndSettle();

    // Early-childhood audit finding #1 (see SECURITY.md): replaced the
    // old 5-point scale (5 numbered circles, labels like "A little like
    // me" / "Mostly like me") with this simpler 3-point one.
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Sometimes'), findsOneWidget);
    expect(find.text('Yes!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every question is worded as a concrete, everyday thing — '
      'not the old abstract self-report statements', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let\'s Go!'));
    await tester.pumpAndSettle();

    // Spot-check the first question and the one directly quoted when
    // this rewrite was requested — regression against silently
    // reverting to the old wording ("I like to learn about new things",
    // "I keep my things neat and tidy").
    expect(
        find.text('I like trying games I\'ve never played before'),
        findsOneWidget);
  });

  testWidgets('tapping "Yes!" selects the highest score and lets the quiz '
      'advance to the next question', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let\'s Go!'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 10'), findsOneWidget);

    await tester.tap(find.text('Yes!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 10'), findsOneWidget);
  });
}
