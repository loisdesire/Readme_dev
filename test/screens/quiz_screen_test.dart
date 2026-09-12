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
      'the 1-5 Likert rating circles do not overflow on a narrow phone '
      'width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let\'s Go!'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
