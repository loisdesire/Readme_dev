import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/privacy_policy_screen.dart';

Widget wrap() => const MaterialApp(home: PrivacyPolicyScreen());

void main() {
  testWidgets('shows the header and every section title', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Your Privacy Matters'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Information We Collect'), findsOneWidget);
    expect(find.text('Children\'s Privacy (COPPA Compliance)'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.text('COPPA Compliant'), findsOneWidget);
  });

  testWidgets('tapping back pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
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
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
