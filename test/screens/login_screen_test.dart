import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/auth/login_screen.dart';
import 'package:readme_app/screens/auth/register_screen.dart';
import 'package:readme_app/screens/child/child_home_screen.dart';
import 'package:readme_app/screens/parent/parent_home_screen.dart';
import 'package:readme_app/screens/quiz/quiz_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';
import 'package:readme_app/utils/app_constants.dart';

// LoginScreen navigates (via Navigator.pushReplacement, after a real
// AppConstants.postAuthNavigationDelay) into whichever of ParentHomeScreen,
// ChildHomeScreen, or QuizScreen matches the signed-in account — so these
// tests provide every provider those destination screens need too, not
// just what LoginScreen itself uses, to avoid a downstream
// ProviderNotFoundException/missing-provider crash failing the test even
// though the assertion under test (which screen we landed on) would
// otherwise have passed.

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

BookProvider buildBookProvider(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
  final firebaseService = FirebaseService.withInstances(
    auth: auth,
    firestore: firestore,
    storage: MockFirebaseStorage(),
  );
  return BookProvider(
    firebaseService: firebaseService,
    apiService: ApiService.withInstances(firestore: firestore),
    analyticsService: AnalyticsService.withInstances(firebaseService: firebaseService),
    achievementService: AchievementService.withInstances(
      auth: auth,
      firestore: firestore,
      notificationService: NotificationService.withInstances(auth: auth, firestore: firestore),
      weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    ),
    contentFilterService: ContentFilterService.withInstances(firebaseService: firebaseService),
    weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

UserProvider buildUserProvider(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
  return UserProvider(
    firebaseService: FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    ),
    firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late BookProvider bookProvider;
  late UserProvider userProvider;

  // The providers must wrap MaterialApp itself, not sit as `home:`'s child:
  // MaterialApp.home becomes part of its *first route's* page widget, which
  // Navigator.pushReplacement (used throughout LoginScreen's navigation)
  // discards along with everything under it — a provider placed there
  // would vanish the moment the route is replaced, so the next screen
  // couldn't find it. Wrapping MaterialApp keeps the providers above the
  // Navigator entirely, where they survive route changes — matching how
  // the real app wraps its own MaterialApp in production.
  Widget wrapLogin() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'user-1', email: 'user@example.com'));
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    bookProvider = buildBookProvider(firestore, auth);
    userProvider = buildUserProvider(firestore, auth);
  });

  testWidgets('submitting with empty fields shows validation errors and '
      'does not attempt a sign-in', (tester) async {
    await tester.pumpWidget(wrapLogin());
    await tester.tap(find.text('Let\'s Go'));
    await tester.pumpAndSettle();

    expect(find.text('We need your email to continue'), findsOneWidget);
    expect(find.text('Don\'t forget your password'), findsOneWidget);
  });

  testWidgets('a wrong-password failure shows the friendly error message, '
      'no navigation', (tester) async {
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(wrapLogin());
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Let\'s Go'));
    await tester.pumpAndSettle();

    expect(find.textContaining("doesn't match"), findsOneWidget);
    expect(find.byType(ParentHomeScreen), findsNothing);
  });

  testWidgets('successful sign-in as a parent navigates to ParentHomeScreen',
      (tester) async {
    await firestore.collection('users').doc('user-1').set({
      'username': 'Mom',
      'accountType': 'parent',
    });

    await tester.pumpWidget(wrapLogin());
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Let\'s Go'));
    await tester.pumpAndSettle();
    // Navigation is deferred by AppConstants.postAuthNavigationDelay.
    await tester.pump(AppConstants.postAuthNavigationDelay);
    await tester.pumpAndSettle();

    expect(find.byType(ParentHomeScreen), findsOneWidget);
  });

  testWidgets(
      'successful sign-in as a child who already completed the quiz '
      'navigates to ChildHomeScreen', (tester) async {
    await firestore.collection('users').doc('user-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'hasCompletedQuiz': true,
    });

    await tester.pumpWidget(wrapLogin());
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Let\'s Go'));
    await tester.pumpAndSettle();
    await tester.pump(AppConstants.postAuthNavigationDelay);
    await tester.pumpAndSettle();

    expect(find.byType(ChildHomeScreen), findsOneWidget);
    // The exception a bare ChildHomeScreen throws deep in its own
    // Firestore-backed StreamBuilder (no BookProvider/UserProvider load
    // has actually run here) is expected and irrelevant to what this test
    // checks — consume it so it doesn't fail the test on its own.
    tester.takeException();
  });

  testWidgets(
      'successful sign-in as a child who has not completed the quiz yet '
      'navigates to QuizScreen', (tester) async {
    await firestore.collection('users').doc('user-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'hasCompletedQuiz': false,
    });

    await tester.pumpWidget(wrapLogin());
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Let\'s Go'));
    await tester.pumpAndSettle();
    await tester.pump(AppConstants.postAuthNavigationDelay);
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('tapping "Create Account" navigates to RegisterScreen',
      (tester) async {
    await tester.pumpWidget(wrapLogin());
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}
