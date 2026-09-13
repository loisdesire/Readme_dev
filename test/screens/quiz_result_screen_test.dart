import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/quiz/quiz_result_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/personality_scoring.dart' as scoring;
import 'package:readme_app/services/points_engine_client.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

/// A fake standing in for the real awardPersonalityQuizPoints Cloud
/// Function (see SECURITY.md's "Point-award security migration"): applies
/// the same flat 3-point, one-time-only credit directly to the fake
/// Firestore so tests can assert on the outcome without needing the real
/// server-side logic (already covered by
/// functions/lib/__tests__/emulator/points_engine.test.js).
PointsEngineClient fakePersonalityQuizPointsClient(
  FakeFirebaseFirestore firestore,
  String userId,
) {
  return PointsEngineClient.withCaller((name, data) async {
    expect(name, 'awardPersonalityQuizPoints');
    final userRef = firestore.collection('users').doc(userId);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};
    if (userData['quizCompleted'] == true) {
      throw FirebaseFunctionsException(
        message: 'Already awarded.',
        code: 'already-exists',
      );
    }
    final current = (userData['totalAchievementPoints'] as int?) ?? 0;
    final newTotal = current + 3;
    await userRef.set({
      'totalAchievementPoints': newTotal,
      'allTimePoints': ((userData['allTimePoints'] as int?) ?? 0) + 3,
      'quizCompleted': true,
    }, SetOptions(merge: true));
    return {'pointsEarned': 3, 'newTotalPoints': newTotal, 'promotedLeague': null};
  });
}

// A single all-"O" (Openness) question so the OCEAN scoring deterministically
// picks Openness as the top dimension, and its sub-traits (curious, creative,
// imaginative) as the top 3 traits shown on screen.
const _questions = [
  {'dimension': 'O', 'isReversed': false},
];
const _answers = [5];

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
  late UserProvider userProvider;
  late BookProvider bookProvider;
  late AchievementService achievementService;

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
      ],
      child: MaterialApp(
        home: QuizResultScreen(
          answers: _answers,
          questions: _questions,
          achievementServiceOverride: achievementService,
        ),
      ),
    );
  }

  // The animation controller's forward() only fires from a Future.delayed
  // in initState with nothing else scheduled beforehand, so a bare
  // pumpAndSettle() would return immediately without waiting for it,
  // leaving its Timer pending at test teardown.
  Future<void> settleAfterDelay(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'avatar': '🧒',
    });
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    userProvider = UserProvider(
      firebaseService: firebaseService,
      firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
      readingSessionService:
          ReadingSessionService.withInstances(firestore: firestore),
    );
    bookProvider = BookProvider(
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
    achievementService = AchievementService.withInstances(
      auth: auth,
      firestore: firestore,
      notificationService:
          NotificationService.withInstances(auth: auth, firestore: firestore),
      weeklyChallengeService:
          WeeklyChallengeService.withInstances(firestore: firestore),
      pointsEngineClient: fakePersonalityQuizPointsClient(firestore, 'kid-1'),
    );
  });

  testWidgets(
      'shows the congratulations header with the username and top traits',
      (tester) async {
    await tester.pumpWidget(wrap());
    await settleAfterDelay(tester);

    expect(find.text('Congratulations, Junior!'), findsOneWidget);
    expect(find.text('Curious'), findsOneWidget);
    expect(find.text('Creative'), findsOneWidget);
    expect(find.text('Imaginative'), findsOneWidget);
    expect(
      find.textContaining('curious, creative, imaginative'),
      findsOneWidget,
    );
  });

  testWidgets('saves quiz results (OCEAN scores and sub-traits) to Firestore',
      (tester) async {
    final oceanScores = scoring.calculateOceanScores(
      answers: _answers,
      questions: _questions,
    );
    final success = await authProvider.saveQuizResults(
      selectedAnswers: _answers,
      traitScores: oceanScores,
      dominantTraits: scoring.getAllTraits(oceanScores),
    );
    expect(success, isTrue);
    // saveQuizResults reloads the profile afterwards, which schedules a
    // zero-duration notifyListeners() timer — flush it so it isn't still
    // pending at test teardown (no widget was pumped in this test to do
    // so implicitly). Passing an explicit Duration.zero (vs. a bare
    // pump()) is what actually elapses fake time far enough to fire it.
    await tester.pump(Duration.zero);

    final doc = await firestore.collection('users').doc('kid-1').get();
    expect(doc.data()!['hasCompletedQuiz'], isTrue);
    expect(doc.data()!['personalityTraits'],
        ['curious', 'creative', 'imaginative', 'responsible', 'organized']);
  });

  // Not testing "tapping Start Reading navigates to ChildHomeScreen" by
  // actually driving the tap here: doing so unavoidably builds a real
  // ChildHomeScreen (production code constructs a bare
  // `const ChildHomeScreen()`, with no override reachable from this
  // test), whose initState() kicks off a whole cascade of BookProvider
  // loads and Firestore stream listeners — real Timers that don't
  // resolve within this test's pump budget and fail the "Timer is still
  // pending" teardown check regardless of how carefully the pumping is
  // bounded, since the build happens synchronously as part of the same
  // pump() call that lets the async save/award chain reach
  // Navigator.pushAndRemoveUntil. ChildHomeScreen has its own dedicated
  // test coverage in child_home_screen_test.dart; here, the save and
  // award logic the button invokes is verified directly (above and
  // below) instead.

  testWidgets('awards personality quiz points when called directly',
      (tester) async {
    final doc = await achievementService.awardPersonalityQuizCompletion(
      userId: 'kid-1',
    );
    // No league promotion from 0 points, so no new league is returned.
    expect(doc, isNull);

    final userDoc = await firestore.collection('users').doc('kid-1').get();
    expect(userDoc.data()!['totalAchievementPoints'], 3);
    expect(userDoc.data()!['quizCompleted'], isTrue);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await settleAfterDelay(tester);

    expect(tester.takeException(), isNull);
  });
}
