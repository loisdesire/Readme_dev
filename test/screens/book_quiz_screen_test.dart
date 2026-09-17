import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/book/book_quiz_celebration_screen.dart';
import 'package:readme_app/screens/book/book_quiz_screen.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/points_engine_client.dart';
import 'package:readme_app/services/quiz_generator_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

/// A fake standing in for the real awardQuizPoints Cloud Function (see
/// SECURITY.md's "Point-award security migration") — this screen doesn't
/// expose a seam for it directly (only QuizGeneratorService does), so
/// tests below that reach _submitQuiz's point-award call inject this via
/// QuizGeneratorService.withInstances instead of hitting the real
/// singleton. Its actual server-side logic is covered by
/// functions/lib/__tests__/emulator/points_engine.test.js.
PointsEngineClient fakeQuizPointsClient(FakeFirebaseFirestore firestore) {
  return PointsEngineClient.withCaller((name, data) async {
    final attemptRef =
        firestore.collection('quiz_attempts').doc(data['attemptId'] as String);
    await attemptRef.set({'pointsAwarded': true}, SetOptions(merge: true));
    return {'pointsEarned': 0, 'newTotalPoints': 0, 'promotedLeague': null};
  });
}

/// Same reasoning/race as auth_provider_test.dart's buildAuthProvider: let
/// MockFirebaseAuth's initial authStateChanges() event settle before use.
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

Future<void> seedQuiz(FakeFirebaseFirestore firestore, String bookId) {
  return firestore.collection('book_quizzes').doc(bookId).set({
    'questions': [
      {
        'question': 'What color was the dragon?',
        'options': ['Red', 'Blue', 'Green', 'Purple'],
        'correctAnswer': 2, // Green
      },
      {
        'question': 'Where did the story take place?',
        'options': ['A castle', 'A forest', 'A city', 'The sea'],
        'correctAnswer': 1, // A forest
      },
    ],
  });
}

Widget wrap(
  Widget child,
  AuthProvider authProvider, {
  required UserProvider userProvider,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        // BookQuizScreen reads the child's current streak (for the
        // achievement-points multiplier) via UserProvider.
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: child,
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late UserProvider userProvider;
  late QuizGeneratorService quizService;
  late WeeklyChallengeService weeklyChallengeService;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'kid-1', email: 'kid@example.com'),
      signedIn: true,
    );
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    userProvider = buildUserProvider(firestore, auth);
    quizService = QuizGeneratorService.withInstances(
      firestore: firestore,
      pointsEngine: fakeQuizPointsClient(firestore),
    );
    weeklyChallengeService = WeeklyChallengeService.withInstances(firestore: firestore);
  });

  testWidgets('loads the cached quiz and shows the first question',
      (tester) async {
    await seedQuiz(firestore, 'b1');

    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('What color was the dragon?'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testWidgets('tapping Next without selecting an answer shows a warning and '
      'does not advance', (tester) async {
    await seedQuiz(firestore, 'b1');
    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Please select an answer before continuing'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testWidgets(
      'answering both questions correctly and submitting navigates to the '
      'celebration screen with a 100% / max-points result', (tester) async {
    await seedQuiz(firestore, 'b1');
    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    // Q1: select "Green" (correct) and advance.
    await tester.tap(find.text('Green'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Question 2 of 2'), findsOneWidget);

    // Q2: select "A forest" (correct) and submit.
    await tester.tap(find.text('A forest'));
    await tester.pump();
    expect(find.text('Submit Quiz'), findsOneWidget);
    await tester.tap(find.text('Submit Quiz'));
    // BookQuizCelebrationScreen runs a several-second staggered reveal
    // sequence via chained Future.delayed calls (12 randomize steps +
    // settling, per card, x3 cards) that pumpAndSettle can't resolve any
    // faster than real pumps advancing the clock through it — and leaving
    // any of it un-drained trips flutter_test's "timer still pending at
    // test end" check. Pump the fake clock all the way through it.
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    final celebration =
        tester.widget<BookQuizCelebrationScreen>(find.byType(BookQuizCelebrationScreen));
    expect(celebration.score, 2);
    expect(celebration.totalQuestions, 2);
    expect(celebration.percentage, 100);
    expect(celebration.pointsEarned, 5); // 90-100% tier

    // saveQuizAttempt actually wrote to Firestore.
    final attempts = await firestore.collection('quiz_attempts').get();
    expect(attempts.docs, hasLength(1));
    expect(attempts.docs.first.data()['score'], 2);
    expect(attempts.docs.first.data()['percentage'], 100);

    // awardQuizPoints was called with the real saved attempt's ID (see
    // fakeQuizPointsClient), marking it pointsAwarded.
    expect(attempts.docs.first.data()['pointsAwarded'], true);

    final weeklyUserDoc = await firestore.collection('users').doc('kid-1').get();
    expect(weeklyUserDoc.data()?['quizzesCompletedThisWeek'], 1);
    expect(weeklyUserDoc.data()?['bestQuizScoreThisWeek'], 100);
  });

  testWidgets('a wrong answer on one question still submits, with a lower '
      'score and points tier', (tester) async {
    await seedQuiz(firestore, 'b1');
    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    // Q1: wrong answer.
    await tester.tap(find.text('Red'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Q2: correct answer.
    await tester.tap(find.text('A forest'));
    await tester.pump();
    await tester.tap(find.text('Submit Quiz'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    final celebration =
        tester.widget<BookQuizCelebrationScreen>(find.byType(BookQuizCelebrationScreen));
    expect(celebration.score, 1);
    expect(celebration.percentage, 50);
    expect(celebration.pointsEarned, 1); // 50-69% tier
  });

  testWidgets(
      'shows a read-aloud button once the quiz loads, and tapping it '
      'degrades safely with no crash when there\'s no real TTS platform '
      '(early-childhood audit finding #3 — see SECURITY.md)',
      (tester) async {
    await seedQuiz(firestore, 'b1');
    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    final readAloudButton = find.byIcon(Icons.volume_up);
    expect(readAloudButton, findsOneWidget);

    await tester.tap(readAloudButton);
    await tester.pumpAndSettle();

    // No real TTS platform is available in a widget test, so the speak
    // call itself fails — the important thing is that it fails
    // *gracefully* (caught, _isPlaying reset) rather than crashing the
    // screen or leaving the button stuck showing "stop".
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsNothing);
  });

  testWidgets(
      'the "Question X of Y" progress header does not overflow on a '
      'narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await seedQuiz(firestore, 'b1');

    await tester.pumpWidget(wrap(
      BookQuizScreen(
        bookId: 'b1',
        bookTitle: 'The Dragon Tale',
        quizService: quizService,
        weeklyChallengeService: weeklyChallengeService,
      ),
      authProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
