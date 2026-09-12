import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/auth/account_type_screen.dart';
import 'package:readme_app/screens/auth/login_screen.dart';
import 'package:readme_app/screens/auth/register_screen.dart';

// AccountTypeScreen is a plain StatelessWidget with no provider needs of
// its own. Its "Sign In" link uses a *named* route (pushReplacementNamed
// '/login'), matching the real app's MaterialApp.routes table in
// lib/main.dart — replicate the same table here so the tap has somewhere
// to navigate to.
Widget wrap() {
  return MaterialApp(
    routes: {
      '/login': (context) => const LoginScreen(),
    },
    home: const AccountTypeScreen(),
  );
}

void main() {
  testWidgets('tapping "I\'m a Child" opens RegisterScreen pre-set to the '
      'child account type', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('I\'m a Child'));
    await tester.pumpAndSettle();

    final register = tester.widget<RegisterScreen>(find.byType(RegisterScreen));
    expect(register.initialAccountType, 'child');
  });

  testWidgets('tapping "I\'m a Parent" opens RegisterScreen pre-set to the '
      'parent account type', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('I\'m a Parent'));
    await tester.pumpAndSettle();

    final register = tester.widget<RegisterScreen>(find.byType(RegisterScreen));
    expect(register.initialAccountType, 'parent');
  });

  testWidgets('tapping "Sign In" navigates to the named /login route',
      (tester) async {
    await tester.pumpWidget(wrap());
    // This screen scrolls, and "Sign In" sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AccountTypeScreen), findsNothing);
  });
}
