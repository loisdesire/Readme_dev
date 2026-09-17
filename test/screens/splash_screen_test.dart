import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/auth/profile_picker_screen.dart';
import 'package:readme_app/screens/onboarding/onboarding_screen.dart';
import 'package:readme_app/screens/splash_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/app_readiness_tracker.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/device_child_profile_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

// Real device secure storage uses a platform channel that isn't available
// under plain `flutter_test` — same class of gap as this codebase's
// Firebase services (see FirebaseService.withInstances). This in-memory
// fake stands in for it everywhere a SplashScreen is built below.
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

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
  // A plain microtask yield, not Future.delayed: this helper runs inside
  // the testWidgets body itself (not a setUp() callback), which executes
  // in flutter_test's FakeAsync zone — a real Timer-based delay would
  // never fire there without a tester.pump() to advance the fake clock,
  // hanging the test. AuthProvider's authStateChanges() listener sets
  // _status/_user synchronously as soon as it starts running (before its
  // own internal awaits), so yielding once is enough to let it start.
  await Future<void>.value();
  return provider;
}

void main() {
  late FakeFirebaseFirestore firestore;

  Widget wrap({
    required AuthProvider authProvider,
    required UserProvider userProvider,
    required BookProvider bookProvider,
    DeviceChildProfileService? deviceChildProfileService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
      ],
      child: MaterialApp(
        routes: {
          '/parent_home': (context) => const Scaffold(
                body: Center(child: Text('Parent Home')),
              ),
        },
        home: SplashScreen(
          deviceChildProfileService: deviceChildProfileService ??
              DeviceChildProfileService(store: InMemorySecureKeyValueStore()),
        ),
      ),
    );
  }

  BookProvider buildBookProvider(MockFirebaseAuth auth) {
    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    return BookProvider(
      firebaseService: firebaseService,
      apiService: ApiService.withInstances(firestore: firestore),
      analyticsService:
          AnalyticsService.withInstances(firebaseService: firebaseService),
      achievementService: AchievementService.withInstances(
        auth: auth,
        firestore: firestore,
        notificationService:
            NotificationService.withInstances(auth: auth, firestore: firestore),
        weeklyChallengeService:
            WeeklyChallengeService.withInstances(firestore: firestore),
      ),
      contentFilterService:
          ContentFilterService.withInstances(firebaseService: firebaseService),
      weeklyChallengeService:
          WeeklyChallengeService.withInstances(firestore: firestore),
      readingSessionService:
          ReadingSessionService.withInstances(firestore: firestore),
    );
  }

  UserProvider buildUserProvider(MockFirebaseAuth auth) {
    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    return UserProvider(
      firebaseService: firebaseService,
      firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
      readingSessionService:
          ReadingSessionService.withInstances(firestore: firestore),
    );
  }

  // The 3-second navigation delay is a genuine Future.delayed with the
  // preceding bookProvider.loadAllBooks() await already resolved by the
  // time pumpWidget's own initial pump finishes (fake_cloud_firestore
  // resolves via microtasks, no real time), so a single pump covering
  // the full delay is enough to fire it and let the rest of the async
  // chain (and any route transition) settle.
  Future<void> settleAfterDelay(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    // AppReadinessTracker is process-global state; splash's dispose()
    // flips it permanently for the rest of this file's tests otherwise.
    AppReadinessTracker.resetForTesting();
  });

  testWidgets('shows the logo while loading', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));

    expect(find.byType(SplashScreen), findsOneWidget);
    // AppReadinessTracker gates achievement-celebration popups off the
    // splash screen (see SECURITY.md) — it must still read "active"
    // while splash is actually showing.
    expect(AppReadinessTracker.isSplashActive, isTrue);

    // Flush the pending 3-second navigation timer scheduled in initState
    // so it isn't still pending at test teardown.
    await settleAfterDelay(tester);
  });

  testWidgets(
      'AppReadinessTracker flips once splash hands off to a real screen '
      '— what unblocks a deferred achievement celebration', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));
    expect(AppReadinessTracker.isSplashActive, isTrue);

    await settleAfterDelay(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(AppReadinessTracker.isSplashActive, isFalse);
  });

  testWidgets(
      'an unauthenticated user on a device with no remembered children is '
      'sent to onboarding', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));
    await settleAfterDelay(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets(
      'an unauthenticated user on a device with a remembered child is sent '
      'to the profile picker instead of onboarding (Option B — see '
      'docs/child-account-model-design.md)', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    final store = InMemorySecureKeyValueStore();
    final deviceChildProfileService =
        DeviceChildProfileService(store: store);
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
      deviceChildProfileService: deviceChildProfileService,
    ));
    await settleAfterDelay(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(ProfilePickerScreen), findsOneWidget);
  });

  testWidgets(
      'an authenticated child who has not completed the quiz is sent to '
      'onboarding', (tester) async {
    final auth =
        MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'hasCompletedQuiz': false,
    });
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));
    await settleAfterDelay(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('an authenticated parent account is sent to /parent_home',
      (tester) async {
    final auth =
        MockFirebaseAuth(mockUser: MockUser(uid: 'parent-1'), signedIn: true);
    await firestore.collection('users').doc('parent-1').set({
      'username': 'Mom',
      'accountType': 'parent',
    });
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));
    await settleAfterDelay(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Parent Home'), findsOneWidget);
  });

  // Not testing the "authenticated child who HAS completed the quiz" path
  // by letting it fully navigate here: that path's destination is a bare
  // `const ChildHomeScreen()` with no override reachable from this test,
  // and its initState() kicks off a cascade of real Firestore stream
  // listeners/timers that can't resolve within a test's pump budget
  // regardless of pumping strategy (fails the "Timer still pending"
  // teardown check) — see the same reasoning in
  // quiz_result_screen_test.dart. ChildHomeScreen has its own dedicated
  // test suite; the other three branches of this screen's routing logic
  // are covered above.

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = MockFirebaseAuth(signedIn: false);
    final authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      userProvider: buildUserProvider(auth),
      bookProvider: buildBookProvider(auth),
    ));

    expect(tester.takeException(), isNull);

    // Flush the pending 3-second navigation timer scheduled in initState
    // so it isn't still pending at test teardown.
    await settleAfterDelay(tester);
  });
}
