import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/help_support_screen.dart';

Widget wrap() => const MaterialApp(home: HelpSupportScreen());

void main() {
  testWidgets('shows the header, every FAQ question, and the contact card',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('We\'re Here to Help!'), findsOneWidget);
    expect(find.text('How do I take the personality quiz?'), findsOneWidget);
    expect(find.text('Can I read offline?'), findsOneWidget);
    expect(find.text('Contact Support'), findsOneWidget);
    expect(find.text('Email Support'), findsOneWidget);
  });

  testWidgets('shows every reading tip', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Build a Reading Habit'), findsOneWidget);
    expect(find.text('Explore New Genres'), findsOneWidget);
    expect(find.text('Track Your Achievements'), findsOneWidget);
  });

  testWidgets('tapping back pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(HelpSupportScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
