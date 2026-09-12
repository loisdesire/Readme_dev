import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/badges_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

Future<void> seedAchievement(
  FakeFirebaseFirestore firestore,
  String id, {
  required String name,
  required String category,
  int requiredValue = 1,
}) {
  return firestore.collection('achievements').doc(id).set({
    'name': name,
    'description': 'desc for $name',
    'emoji': 'star',
    'category': category,
    'requiredValue': requiredValue,
    'type': 'books_read',
    'points': 10,
  });
}

Widget wrap(AchievementService service) {
  return MaterialApp(home: BadgesScreen(achievementServiceOverride: service));
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AchievementService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    service = AchievementService.withInstances(
      firestore: firestore,
      auth: auth,
      notificationService:
          NotificationService.withInstances(auth: auth, firestore: firestore),
      weeklyChallengeService:
          WeeklyChallengeService.withInstances(firestore: firestore),
    );
  });

  testWidgets('with none unlocked, shows the encouraging empty state '
      'instead of a badge count', (tester) async {
    await seedAchievement(firestore, 'a1', name: 'First Book', category: 'reading');

    await tester.pumpWidget(wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Start Your Badge Collection!'), findsOneWidget);
    expect(find.textContaining('unlocked!'), findsNothing);
  });

  testWidgets('groups achievements by category with a count of unlocked '
      'ones', (tester) async {
    await seedAchievement(firestore, 'a1', name: 'First Book', category: 'reading');
    await seedAchievement(firestore, 'a2', name: 'Quiz Whiz', category: 'quiz');
    await firestore.collection('user_achievements').add({
      'userId': 'kid-1',
      'achievementId': 'a1',
    });

    await tester.pumpWidget(wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('1 badge unlocked!'), findsOneWidget);
    expect(find.text('Books Read'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('First Book'), findsOneWidget);
    expect(find.text('Quiz Whiz'), findsOneWidget);
  });

  testWidgets('plural "badges unlocked" when more than one', (tester) async {
    await seedAchievement(firestore, 'a1', name: 'First Book', category: 'reading');
    await seedAchievement(firestore, 'a2', name: 'Second Book', category: 'reading');
    await firestore.collection('user_achievements').add({'userId': 'kid-1', 'achievementId': 'a1'});
    await firestore.collection('user_achievements').add({'userId': 'kid-1', 'achievementId': 'a2'});

    await tester.pumpWidget(wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('2 badges unlocked!'), findsOneWidget);
  });

  testWidgets('tapping "Read more books!" pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BadgesScreen(achievementServiceOverride: service),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read more books!'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(BadgesScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await seedAchievement(firestore, 'a1',
        name: 'An Extraordinarily Long Achievement Name', category: 'reading');
    await firestore.collection('user_achievements').add({'userId': 'kid-1', 'achievementId': 'a1'});

    await tester.pumpWidget(wrap(service));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
