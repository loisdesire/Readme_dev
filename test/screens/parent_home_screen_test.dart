import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/auth/login_screen.dart';
import 'package:readme_app/screens/parent/add_child_screen.dart';
import 'package:readme_app/screens/parent/parent_dashboard_screen.dart';
import 'package:readme_app/screens/parent/parent_home_screen.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/utils/page_transitions.dart';

// ParentHomeScreen routes everything through its injected AuthProvider — no
// raw-singleton calls of its own. Its "Add Child"/child-card taps navigate
// to AddChildScreen/ParentDashboardScreen, both of which reach for real
// Firebase singletons of their own with no way to inject test doubles from
// here — see parent_dashboard_screen_test.dart for that screen's own DI
// seam. From this screen's side, that downstream crash is an expected,
// irrelevant side effect of testing navigation *to* it (matching the same
// pattern established in login_screen_test.dart), consumed via
// tester.takeException() rather than threaded through here.

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

  Widget wrap() {
    // Providers wrap MaterialApp itself (see login_screen_test.dart) so
    // they survive this screen's own Navigator.pushAndRemoveUntil on
    // sign-out.
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const MaterialApp(home: ParentHomeScreen()),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'parent-1'), signedIn: true);
    await firestore.collection('users').doc('parent-1').set({
      'username': 'Mom',
      'accountType': 'parent',
      'children': <String>[],
    });
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    await authProvider.reloadUserProfile();
  });

  testWidgets('shows the empty state when the parent has no children yet',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('No children added yet'), findsOneWidget);
    expect(find.text('0 children registered'), findsOneWidget);
  });

  testWidgets(
      'shows a child card with the right stats once a child is registered',
      (tester) async {
    await firestore.collection('users').doc('parent-1').update({
      'children': ['child-1'],
    });
    await firestore.collection('users').doc('child-1').set({
      'uid': 'child-1',
      'username': 'Junior',
      'avatar': '🦊',
      'totalBooksRead': 4,
      'currentStreak': 3,
    });
    await authProvider.reloadUserProfile();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('1 child registered'), findsOneWidget);
    expect(find.text('Junior'), findsOneWidget);
    expect(find.text('4 books'), findsOneWidget);
    expect(find.text('3 day streak'), findsOneWidget);
  });

  testWidgets('a removed child is excluded from the list', (tester) async {
    await firestore.collection('users').doc('parent-1').update({
      'children': ['child-1'],
    });
    await firestore.collection('users').doc('child-1').set({
      'uid': 'child-1',
      'username': 'Junior',
      'isRemoved': true,
    });
    await authProvider.reloadUserProfile();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Junior'), findsNothing);
    expect(find.text('No children added yet'), findsOneWidget);
  });

  testWidgets('tapping "Add Child" navigates to AddChildScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Child'));
    await tester.pumpAndSettle();

    expect(find.byType(AddChildScreen), findsOneWidget);
  });

  testWidgets('tapping a child card navigates to ParentDashboardScreen for '
      'that child', (tester) async {
    await firestore.collection('users').doc('parent-1').update({
      'children': ['child-1'],
    });
    await firestore.collection('users').doc('child-1').set({
      'uid': 'child-1',
      'username': 'Junior',
    });
    await authProvider.reloadUserProfile();

    // ParentDashboardScreen's bare, un-injected FirebaseFirestore.instance
    // call throws during its own initState — before the widget ever
    // finishes mounting, so it never actually appears in the tree for
    // find.byType to see (an exception during a StatefulWidget's own
    // initState aborts that element's mount entirely, unlike one from a
    // build() deeper in its descendants). A NavigatorObserver captures the
    // pushed route — and the ParentDashboardScreen instance inside it —
    // synchronously on push, before any of that build/mount happens.
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const ParentHomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Deliberately not followed by a pump(): building the pushed page is
    // exactly what would run ParentDashboardScreen's crashing initState
    // (see the comment above) — inspecting the captured route is enough
    // for this test, and the crash never has to happen at all.
    await tester.tap(find.text('Junior'));

    final pushed = observer.pushedRoutes.whereType<FadeRoute>().last;
    final dashboard = pushed.page as ParentDashboardScreen;
    expect(dashboard.childId, 'child-1');
  });

  testWidgets(
      'the delete confirmation dialog removes the child and refreshes the '
      'list', (tester) async {
    await firestore.collection('users').doc('parent-1').update({
      'children': ['child-1'],
    });
    await firestore.collection('users').doc('child-1').set({
      'uid': 'child-1',
      'username': 'Junior',
      'parentIds': ['parent-1'],
    });
    await authProvider.reloadUserProfile();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Remove Child?'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Child removed successfully'), findsOneWidget);
    expect(find.text('Junior'), findsNothing);
    expect(find.text('No children added yet'), findsOneWidget);
  });

  testWidgets('tapping cancel on the delete dialog keeps the child',
      (tester) async {
    await firestore.collection('users').doc('parent-1').update({
      'children': ['child-1'],
    });
    await firestore.collection('users').doc('child-1').set({
      'uid': 'child-1',
      'username': 'Junior',
    });
    await authProvider.reloadUserProfile();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Junior'), findsOneWidget);
  });

  testWidgets('signing out navigates to LoginScreen', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(authProvider.isAuthenticated, isFalse);
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}
