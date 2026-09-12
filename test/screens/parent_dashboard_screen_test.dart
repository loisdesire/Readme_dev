import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/parent/content_filter_screen.dart';
import 'package:readme_app/screens/parent/parent_dashboard_screen.dart';
import 'package:readme_app/screens/parent/reading_history_screen.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/reading_session_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  Widget wrap({String? childId}) {
    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    return MaterialApp(
      home: ParentDashboardScreen(
        childId: childId,
        firestoreOverride: firestore,
        authOverride: auth,
        analyticsServiceOverride:
            AnalyticsService.withInstances(firebaseService: firebaseService),
        contentFilterServiceOverride:
            ContentFilterService.withInstances(firebaseService: firebaseService),
        userProviderOverride: UserProvider(
          firebaseService: firebaseService,
          firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
          readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
        ),
      ),
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'parent-1'), signedIn: true);
  });

  testWidgets('shows an error state when there is no child to load',
      (tester) async {
    final signedOutAuth = MockFirebaseAuth(signedIn: false);
    await tester.pumpWidget(MaterialApp(
      home: ParentDashboardScreen(
        firestoreOverride: firestore,
        authOverride: signedOutAuth,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No user authenticated'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'loads and shows a specific child\'s name, today/all-time stats, and '
      'content filter categories', (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'username': 'Junior',
      'accountType': 'child',
    });
    await firestore.collection('content_filters').doc('child-1').set({
      'userId': 'child-1',
      'allowedCategories': ['adventure', 'fantasy'],
      'blockedWords': <String>[],
      'maxAgeRating': '12+',
      'enableSafeMode': true,
      'allowedAuthors': <String>[],
      'blockedAuthors': <String>[],
      'maxReadingTimeMinutes': 45,
      'allowedTimes': ['06:00-22:00'],
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await firestore.collection('daily_reading_time').doc('child-1_$dateKey').set({
      'totalMinutes': 20,
    });
    await firestore.collection('reading_progress').add({
      'userId': 'child-1',
      'isCompleted': true,
      'lastReadAt': Timestamp.fromDate(today),
    });
    await firestore.collection('reading_sessions').add({
      'userId': 'child-1',
      'bookId': 'b1',
      'bookTitle': 'Dragon Tales',
      'createdAt': Timestamp.fromDate(today),
      'progressPercentage': 0.4,
      'durationMinutes': 15,
    });

    await tester.pumpWidget(wrap(childId: 'child-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Junior'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('Goal: 45 min'), findsOneWidget);
    expect(find.text('1 books • 15 min'), findsOneWidget);
    expect(find.text('Dragon Tales'), findsOneWidget);
    // _buildContentTag renders the raw category string as-is, with no
    // capitalization applied.
    expect(find.text('adventure'), findsOneWidget);
    expect(find.text('fantasy'), findsOneWidget);
  });

  testWidgets(
      'shows the empty states for reading history and achievements when '
      'there is no activity yet', (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'username': 'Junior',
      'accountType': 'child',
    });

    await tester.pumpWidget(wrap(childId: 'child-1'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No activity yet'),
      findsOneWidget,
    );
    expect(find.textContaining('No wins yet'), findsOneWidget);
  });

  testWidgets('tapping "See all" navigates to ReadingHistoryScreen for the '
      'right child', (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'username': 'Junior',
      'accountType': 'child',
    });

    await tester.pumpWidget(wrap(childId: 'child-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    final history =
        tester.widget<ReadingHistoryScreen>(find.byType(ReadingHistoryScreen));
    expect(history.childId, 'child-1');
  });

  testWidgets('tapping "Review filters" navigates to ContentFilterScreen',
      (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'username': 'Junior',
      'accountType': 'child',
    });

    await tester.pumpWidget(wrap(childId: 'child-1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Review filters'));
    await tester.tap(find.text('Review filters'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentFilterScreen), findsOneWidget);
  });

  testWidgets(
      'falls back to the currently signed-in user when no childId is given',
      (tester) async {
    await firestore.collection('users').doc('parent-1').set({
      'username': 'Mom',
      'accountType': 'parent',
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // No childId means the screen falls back to the current auth user
    // (parent-1 here) rather than erroring.
    expect(find.textContaining('No user authenticated'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
}
