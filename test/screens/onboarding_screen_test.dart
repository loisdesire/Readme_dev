import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/auth/register_screen.dart';
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

  testWidgets(
      'tapping "Get Started" navigates straight to RegisterScreen, '
      'pre-set to the parent account type — the old "Parent or Child?" '
      'picker screen is gone (see docs/child-account-model-design.md)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final register = tester.widget<RegisterScreen>(find.byType(RegisterScreen));
    expect(register.initialAccountType, 'parent');
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
