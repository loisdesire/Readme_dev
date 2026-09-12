import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/child/leaderboard_screen_impl.dart';
import 'package:readme_app/services/daily_quest_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/reading_session_service.dart';

// Regression coverage for wiring DailyQuestService into the "Today's Goals"
// card: it used to compute its three quests purely from live UserProvider
// stats and never persisted anything, so the "+N stars" it displayed were
// never actually credited — even though a complete, tested backend for
// exactly this already existed and just wasn't called. See SECURITY.md.

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

Widget wrap(AuthProvider authProvider, UserProvider userProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ],
    child: const MaterialApp(home: LeaderboardScreen()),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late AuthProvider authProvider;
  late UserProvider userProvider;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'totalAchievementPoints': 0,
      'allTimePoints': 0,
    });
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    userProvider = UserProvider(
      firebaseService: FirebaseService.withInstances(
        auth: auth,
        firestore: firestore,
        storage: MockFirebaseStorage(),
      ),
      firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
      readingSessionService:
          ReadingSessionService.withInstances(firestore: firestore),
    );
  });

  testWidgets(
      'on load, persists a real daily-quest doc instead of just computing '
      'quest state in memory', (tester) async {
    await tester.pumpWidget(wrap(authProvider, userProvider));
    await tester.pumpAndSettle();

    final doc = await DailyQuestService(firestore: firestore)
        .getTodayDoc('kid-1');
    expect(doc, isNotNull);
    expect(doc!['quests'], isNotNull);
  });

  testWidgets(
      'with no reading yet today, all three quests show as not completed',
      (tester) async {
    await tester.pumpWidget(wrap(authProvider, userProvider));
    await tester.pumpAndSettle();

    final doc =
        await DailyQuestService(firestore: firestore).getTodayDoc('kid-1');
    final quests = doc!['quests'] as Map;
    expect((quests[DailyQuestService.questReadGoal] as Map)['completed'], false);
    expect((quests[DailyQuestService.questKeepStreak] as Map)['completed'], false);
    expect((quests[DailyQuestService.questMiniRead] as Map)['completed'], false);

    // "Do a mini read" is the one row this card didn't show at all before
    // this wiring — regression for the missing third quest.
    expect(find.text('Do a mini read'), findsOneWidget);
    expect(find.text('Even 2 minutes counts'), findsOneWidget);
  });

  testWidgets(
      'no reading yet today: nothing is awarded, no celebratory snackbar, '
      'and the user\'s point totals are untouched', (tester) async {
    await tester.pumpWidget(wrap(authProvider, userProvider));
    await tester.pumpAndSettle();

    expect(find.textContaining('quests complete'), findsNothing);
    final userDoc = await firestore.collection('users').doc('kid-1').get();
    expect(userDoc.data()!['totalAchievementPoints'], 0);
  });

  testWidgets(
      'the "Top 3 by league" header does not overflow on a narrow phone '
      'width — regression for a real RenderFlex overflow (the league name '
      'plus player count didn\'t fit on one line at ~375px) found while '
      'screenshotting the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(authProvider, userProvider));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
