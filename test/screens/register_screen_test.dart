import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/auth/login_screen.dart';
import 'package:readme_app/screens/auth/register_screen.dart';
import 'package:readme_app/screens/parent/parent_home_screen.dart';
import 'package:readme_app/screens/quiz/quiz_screen.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/utils/app_constants.dart';

// See login_screen_test.dart for why the provider must wrap MaterialApp
// rather than sit as `home:`'s child: Navigator.pushReplacement (used by
// both _handleSignUp and _switchToLogin) discards whatever was part of the
// old route's page widget, AuthProvider included if it were placed there.

Future<AuthProvider> buildAuthProvider({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
}) async {
  final provider = AuthProvider(
    firebaseService: FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    ),
  );
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;

  Widget wrap({String? initialAccountType}) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        home: RegisterScreen(initialAccountType: initialAccountType),
      ),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
  });

  testWidgets(
      'submitting with everything empty shows every field\'s validation error',
      (tester) async {
    await tester.pumpWidget(wrap());
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a username'), findsOneWidget);
    expect(find.text('We\'ll need your email to get started'), findsOneWidget);
    expect(find.text('Create a password to protect your account'), findsOneWidget);
    expect(find.text('Type your password again to confirm'), findsOneWidget);
  });

  testWidgets('an email with no @ is rejected', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();

    expect(find.text('Check that email address again'), findsOneWidget);
  });

  testWidgets('a password under 6 characters is rejected', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(2), 'ab1');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();

    expect(
      find.text('Make your password at least 6 characters long'),
      findsOneWidget,
    );
  });

  testWidgets('a confirm-password that doesn\'t match the password is rejected',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password124');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();

    expect(find.text('These passwords don\'t match—try again'), findsOneWidget);
  });

  testWidgets('a duplicate email shows the friendly error, no navigation',
      (tester) async {
    whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(0), 'Junior');
    await tester.enterText(find.byType(TextFormField).at(1), 'taken@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already registered'), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets(
      'a successful child sign-up (the default account type) navigates to '
      'QuizScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(0), 'Junior');
    await tester.enterText(find.byType(TextFormField).at(1), 'junior@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();
    await tester.pump(AppConstants.postAuthNavigationDelay);
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);

    final doc = await firestore.collection('users').doc(authProvider.userId).get();
    expect(doc.data()!['accountType'], 'child');
  });

  testWidgets(
      'a successful parent sign-up (initialAccountType: parent) navigates '
      'straight to ParentHomeScreen, skipping the quiz', (tester) async {
    await tester.pumpWidget(wrap(initialAccountType: 'parent'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Mom');
    await tester.enterText(find.byType(TextFormField).at(1), 'mom@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    // The form scrolls, and this button sits below the fold at the
    // default test viewport size — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Start Reading'));
    await tester.tap(find.text('Start Reading'));
    await tester.pumpAndSettle();
    await tester.pump(AppConstants.postAuthNavigationDelay);
    await tester.pumpAndSettle();

    expect(find.byType(ParentHomeScreen), findsOneWidget);

    final doc = await firestore.collection('users').doc(authProvider.userId).get();
    expect(doc.data()!['accountType'], 'parent');
  });

  testWidgets('tapping the "Sign In" tab navigates to LoginScreen',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
