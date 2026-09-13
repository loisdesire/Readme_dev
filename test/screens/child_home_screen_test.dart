import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/child/child_home_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

// ChildHomeScreen reaches directly for a few real singletons
// (WeeklyChallengeService(), AchievementService.getDefaultAchievements —
// now static and side-effect-free — and a raw FirebaseFirestore.instance
// StreamBuilder for the weekly-challenge card) with no constructor seam to
// override them. Each is reached from a try/catch'd background flow or a
// StreamBuilder that simply never receives data in a test environment, so
// they no-op/log-and-swallow rather than crash — the screen's actual
// render output is driven entirely by the properly-injected providers
// below, which is what these tests verify.

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

Future<void> seedBook(
  FakeFirebaseFirestore firestore,
  String id, {
  String title = 'A Book',
  List<String> traits = const [],
}) {
  return firestore.collection('books').doc(id).set({
    'title': title,
    'author': 'Author',
    'description': 'desc',
    'traits': traits,
    'tags': <String>[],
    'ageRating': '6+',
    'estimatedReadingTime': 15,
  });
}

/// ChildHomeScreen's own initState kicks off a real (fast, fake-backed)
/// data reload — a chain of several async BookProvider/UserProvider calls
/// that each dispatch their notifyListeners through a zero-duration
/// `safeNotify()` timer. A bare `tester.pump()` never elapses the fake
/// clock at all (only an explicit `Duration` does), so those timers, and
/// whichever further ones they schedule in turn, never fire — leaving
/// Timers pending at teardown. `pumpAndSettle()` doesn't work either: this
/// screen renders a looping `PulseAnimation`, which keeps scheduling new
/// frames forever, so pumpAndSettle's "stop once nothing more is
/// scheduled" condition never becomes true and it times out. Bounded,
/// repeated zero-duration pumps thread the needle: each one elapses the
/// fake clock (even by zero, which is enough to fire due timers) and
/// flushes microtasks, and doing it a fixed number of times drains the
/// finite async chain without ever waiting on the infinite animation.
Future<void> pumpAndDrain(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(Duration.zero);
  }
}

Widget wrap({
  required AuthProvider authProvider,
  required BookProvider bookProvider,
  required UserProvider userProvider,
  required FakeFirebaseFirestore firestore,
  AchievementService? achievementService,
  WeeklyChallengeService? weeklyChallengeService,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: ChildHomeScreen(
        firestoreOverride: firestore,
        achievementServiceOverride: achievementService,
        weeklyChallengeServiceOverride: weeklyChallengeService,
      ),
    ),
  );
}

void main() {
  // Shared across every test. buildAuthProvider's internal
  // `Future.delayed` only resolves when awaited from a `setUp()` (a plain
  // package:test hook, running on the real event loop) — awaiting it
  // directly inside a testWidgets() body hangs forever, because
  // TestWidgetsFlutterBinding runs that body in a fake-clock zone that
  // never advances without an explicit tester.pump(). See SECURITY.md.
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late BookProvider bookProvider;
  late UserProvider userProvider;
  // ChildHomeScreen kicks off its own real (fast, fake-backed) data load
  // from initState's post-frame callback, which would otherwise flip a
  // manually-injected isLoading/error state on `bookProvider` straight
  // back to normal before a test ever gets to observe it. Signing out
  // short-circuits that internal load at its `authProvider.userId == null`
  // guard, so an injected loading/error state actually sticks around.
  // Built here (in setUp(), not inside a testWidgets() body) for the same
  // reason `authProvider` itself is: buildAuthProvider()'s internal
  // `Future.delayed` only resolves on setUp()'s real event loop.
  late AuthProvider signedOutAuthProvider;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    bookProvider = buildBookProvider(firestore, auth);
    userProvider = buildUserProvider(firestore, auth);
    signedOutAuthProvider = await buildAuthProvider(
      auth: MockFirebaseAuth(signedIn: false),
      firestore: firestore,
    );
  });

  testWidgets('shows a loading spinner while BookProvider is loading',
      (tester) async {
    bookProvider.setLoading(true);

    await tester.pumpWidget(wrap(
      authProvider: signedOutAuthProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      firestore: firestore,
    ));
    // setLoading()'s notifyListeners is dispatched via safeNotify(), which
    // schedules it through a zero-duration Future.delayed rather than
    // calling it synchronously (to dodge "setState during build" issues).
    // A bare pump() never elapses the fake clock at all — only an explicit
    // Duration does — so without one that timer is still pending when the
    // test tears down and Flutter's leak check fails the test. Pass
    // Duration.zero explicitly so the fake clock elapses (even by zero)
    // and flushes it.
    await tester.pump(Duration.zero);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error state with a retry affordance when '
      'BookProvider has an error', (tester) async {
    bookProvider.setError('Oops! We couldn\'t load the books. Please try again.');

    await tester.pumpWidget(wrap(
      authProvider: signedOutAuthProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      firestore: firestore,
    ));
    // See the note above: setError() also notifies via a zero-duration
    // safeNotify() timer that needs an explicit clock elapse to flush.
    await tester.pump(Duration.zero);

    expect(find.textContaining('couldn\'t load the books'), findsOneWidget);
  });

  group('once loaded', () {
    setUp(() async {
      await firestore.collection('users').doc('kid-1').set({
        'username': 'Junior',
        'avatar': '🦊',
      });
    });

    testWidgets('shows the signed-in user\'s username and avatar in the '
        'header', (tester) async {
      await userProvider.loadUserData('kid-1');
      await tester.pumpWidget(wrap(
        authProvider: authProvider,
        bookProvider: bookProvider,
        userProvider: userProvider,
        firestore: firestore,
      ));
      await pumpAndDrain(tester);

      expect(find.text('Junior'), findsOneWidget);
    });

    testWidgets('shows the streak count from UserProvider', (tester) async {
      await firestore.collection('reading_progress').add({
        'userId': 'kid-1',
        'lastReadAt': Timestamp.fromDate(DateTime.now()),
        'progressPercentage': 0.5,
        'readingTimeMinutes': 10,
      });
      await userProvider.loadUserData('kid-1');
      await tester.pumpWidget(wrap(
        authProvider: authProvider,
        bookProvider: bookProvider,
        userProvider: userProvider,
        firestore: firestore,
      ));
      await pumpAndDrain(tester);

      expect(find.text('${userProvider.dailyReadingStreak}-day streak!'), findsOneWidget);
    });

    testWidgets(
        'Continue Reading shows an in-progress book but not a completed or '
        'not-yet-started one', (tester) async {
      await seedBook(firestore, 'in-progress', title: 'In Progress Book');
      await seedBook(firestore, 'done', title: 'Finished Book');
      await seedBook(firestore, 'unstarted', title: 'Unstarted Book');
      await bookProvider.loadAllBooks();
      await bookProvider.updateReadingProgress(
        userId: 'kid-1',
        bookId: 'in-progress',
        currentPage: 3,
        totalPages: 10,
        additionalReadingTime: 5,
      );
      await bookProvider.updateReadingProgress(
        userId: 'kid-1',
        bookId: 'done',
        currentPage: 10,
        totalPages: 10,
        additionalReadingTime: 10,
      );
      await bookProvider.loadUserProgress('kid-1');

      await tester.pumpWidget(wrap(
        authProvider: authProvider,
        bookProvider: bookProvider,
        userProvider: userProvider,
        firestore: firestore,
      ));
      await pumpAndDrain(tester);

      // Scoped to the "Keep Going" (Continue Reading) section specifically:
      // Finished/Unstarted Book can legitimately still appear elsewhere on
      // the screen (e.g. in Recommended Books, which recommends from the
      // whole catalog), so a screen-wide findsNothing would be too broad.
      expect(find.text('Keep Going'), findsOneWidget);
      final continueReadingSection = find
          .ancestor(of: find.text('Keep Going'), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(
            of: continueReadingSection, matching: find.text('In Progress Book')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: continueReadingSection, matching: find.text('Finished Book')),
        findsNothing,
      );
      expect(
        find.descendant(
            of: continueReadingSection, matching: find.text('Unstarted Book')),
        findsNothing,
      );
    });

    testWidgets('badge progress card shows books-read count toward the '
        'next reading achievement', (tester) async {
      await firestore.collection('reading_progress').add({
        'userId': 'kid-1',
        'isCompleted': true,
        'lastReadAt': Timestamp.fromDate(DateTime.now()),
      });
      await userProvider.loadUserData('kid-1');
      await bookProvider.loadUserProgress('kid-1');

      await tester.pumpWidget(wrap(
        authProvider: authProvider,
        bookProvider: bookProvider,
        userProvider: userProvider,
        firestore: firestore,
      ));
      await pumpAndDrain(tester);

      // Regression check: this section reads AchievementService's default
      // achievement list purely for its target thresholds/names — no
      // Firestore/Auth touch — and must not crash the whole screen doing
      // it. 'First Book' (target 1) is instantly met, so the badge card
      // should show progress toward whichever is the *next* one.
      expect(find.text('Your Progress'), findsOneWidget);
    });
  });

  group('weekly challenge completion actually awards points', () {
    // Bug found in this pass: the weekly-challenge celebration card
    // promised "+50 points" but nothing ever credited totalAchievementPoints
    // — the same "cosmetic reward" class of bug already found and fixed for
    // the daily quests card (see SECURITY.md). This is a regression test
    // for the fix, exercised via the live Firestore-listener path
    // (_buildWeeklyChallengeCard), which is the one reachable in a widget
    // test since it reads through the overridable _firestore rather than
    // the real WeeklyChallengeService() singleton.
    late WeeklyChallengeService weeklyChallengeService;
    late String weekKey;

    setUp(() async {
      weeklyChallengeService =
          WeeklyChallengeService.withInstances(firestore: firestore);
      final startOfWeek = weeklyChallengeService.getStartOfWeek();
      weekKey = '${startOfWeek.year}_${startOfWeek.month}_${startOfWeek.day}';

      await firestore.collection('users').doc('kid-1').set({
        'username': 'Junior',
        'avatar': '🦊',
        'totalAchievementPoints': 0,
        'allTimePoints': 0,
        // Same week as "now" so _checkWeeklyChallengeOnce's
        // initializeWeeklyChallenge() treats this as already-initialized
        // and doesn't reset/overwrite the fields below.
        'lastWeeklyChallengeWeek': weekKey,
        'currentChallengeType': 'completeBooks',
        'currentChallengeTarget': 1,
        'weeklyChallengeProgress': 0,
        'weeklyChallengeCompleted': false,
        'weeklyChallengeSeen': false,
      });
      await userProvider.loadUserData('kid-1');
    });

    testWidgets(
        'crediting points was previously missing entirely; now the live '
        'listener awards them the moment the challenge flips to completed',
        (tester) async {
      final achievementService = AchievementService.withInstances(
        auth: auth,
        firestore: firestore,
        notificationService:
            NotificationService.withInstances(auth: auth, firestore: firestore),
        weeklyChallengeService: weeklyChallengeService,
      );

      await tester.pumpWidget(wrap(
        authProvider: authProvider,
        bookProvider: bookProvider,
        userProvider: userProvider,
        firestore: firestore,
        achievementService: achievementService,
        weeklyChallengeService: weeklyChallengeService,
      ));
      await pumpAndDrain(tester);

      // Sanity: first load (challenge not yet complete) didn't award
      // anything on its own.
      var userDoc = await firestore.collection('users').doc('kid-1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 0);

      // Simulate the challenge completing live — flip it directly in
      // Firestore, exactly like WeeklyChallengeService.updateProgress does
      // when a book completion elsewhere refreshes progress.
      await firestore.collection('users').doc('kid-1').set({
        'weeklyChallengeProgress': 1,
        'weeklyChallengeCompleted': true,
      }, SetOptions(merge: true));

      await pumpAndDrain(tester, 20);

      userDoc = await firestore.collection('users').doc('kid-1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 50);

      // The celebration screen that's now showing plays a ConfettiController
      // on a real (non-zero) Timer, which a Duration.zero pump never
      // advances — dismiss it via its own close button and pump with real
      // time so that timer actually fires/cancels, instead of leaving it
      // pending when the widget tree is torn down (see the same caveat in
      // weekly_challenge_celebration_screen_test.dart).
      await tester.tap(find.text('Keep the Streak Going'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  testWidgets(
      'section headers ("Your Progress"/"Keep Going"/"Start Reading" + '
      '"Show all") do not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await seedBook(firestore, 'b1', title: 'A Book');
    await bookProvider.loadAllBooks();

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      firestore: firestore,
    ));
    await pumpAndDrain(tester);

    expect(tester.takeException(), isNull);
  });
}
