import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/auth/account_type_screen.dart';
import 'package:readme_app/screens/onboarding/onboarding_screen.dart';

Widget wrap() => const MaterialApp(home: OnboardingScreen());

void main() {
  testWidgets('shows the tagline, illustration caption, and Get Started '
      'button', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('reading app'), findsOneWidget);
    expect(find.textContaining('Discover and read books'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('tapping "Get Started" navigates to AccountTypeScreen',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountTypeScreen), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
