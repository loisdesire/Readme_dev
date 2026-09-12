import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/parent/add_child_screen.dart';
import 'package:readme_app/services/firebase_service.dart';

// AddChildScreen's "Create New" tab's actual submission calls
// FirebaseFunctions.instance directly, with no fake/mock package available
// for cloud_functions (unlike auth/firestore/storage) — see
// quiz_generator_service_test.dart and SECURITY.md for the same accepted
// gap elsewhere in this suite. Its client-side validation (exercised
// below) runs entirely before that call, so it's fully testable on its own.

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

  // Real usage always pushes AddChildScreen onto an existing route
  // (ParentHomeScreen); the successful-link path calls Navigator.pop(true)
  // right after queuing its SnackBar, and with no route underneath to pop
  // back to, that pop is a no-op that leaves the SnackBar's exact fate
  // untested. A host screen underneath makes the pop (and the SnackBar it
  // shouldn't discard — SnackBars are queued on the single app-level
  // ScaffoldMessenger, so they survive a pop and reappear over whatever
  // route is now on top) both real and observable.
  Widget wrap() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddChildScreen()),
                ),
                child: const Text('open AddChildScreen'),
              ),
            ),
          ),
        ),
      ),
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

  Future<void> openAddChildScreen(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open AddChildScreen'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows all three tabs: Scan QR, Enter PIN, Create New',
      (tester) async {
    await openAddChildScreen(tester);

    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(find.text('Create New'), findsOneWidget);
  });

  group('Enter PIN tab', () {
    Future<void> openPinTab(WidgetTester tester) async {
      await openAddChildScreen(tester);
      await tester.tap(find.text('Enter PIN'));
      await tester.pumpAndSettle();
    }

    testWidgets('submitting an empty PIN shows a warning, no query attempted',
        (tester) async {
      await openPinTab(tester);

      await tester.ensureVisible(find.text('Link Child'));
      await tester.tap(find.text('Link Child'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a PIN'), findsOneWidget);
    });

    testWidgets('a PIN matching no child shows an error', (tester) async {
      await openPinTab(tester);

      await tester.enterText(find.byType(TextFormField), '999999');
      await tester.ensureVisible(find.text('Link Child'));
      await tester.tap(find.text('Link Child'));
      await tester.pumpAndSettle();

      expect(find.text('No child found with this PIN'), findsOneWidget);
    });

    testWidgets(
        'a valid PIN links the child, updates both sides, and pops with true',
        (tester) async {
      await firestore.collection('users').doc('child-1').set({
        'uid': 'child-1',
        'username': 'Junior',
        'accountType': 'child',
        'parentAccessPin': '123456',
        'parentIds': <String>[],
      });
      await openPinTab(tester);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Link Child'));
      await tester.tap(find.text('Link Child'));
      await tester.pumpAndSettle();

      // Confirms Navigator.pop(context, true) actually ran: back on the
      // host screen, with the success SnackBar (queued on the app-level
      // ScaffoldMessenger, so it survives the pop) now showing over it.
      expect(find.text('open AddChildScreen'), findsOneWidget);
      expect(find.text('Junior linked successfully!'), findsOneWidget);

      final parentDoc = await firestore.collection('users').doc('parent-1').get();
      expect(parentDoc.data()!['children'], contains('child-1'));
      final childDoc = await firestore.collection('users').doc('child-1').get();
      expect(childDoc.data()!['parentIds'], contains('parent-1'));
    });

    testWidgets('a child already linked to this parent shows a warning',
        (tester) async {
      await firestore.collection('users').doc('child-1').set({
        'uid': 'child-1',
        'username': 'Junior',
        'accountType': 'child',
        'parentAccessPin': '123456',
        'parentIds': ['parent-1'],
      });
      await openPinTab(tester);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Link Child'));
      await tester.tap(find.text('Link Child'));
      await tester.pumpAndSettle();

      expect(
        find.text('This child is already linked to your account'),
        findsOneWidget,
      );
    });

    testWidgets('a removed child account shows a warning instead of linking',
        (tester) async {
      await firestore.collection('users').doc('child-1').set({
        'uid': 'child-1',
        'username': 'Junior',
        'accountType': 'child',
        'parentAccessPin': '123456',
        'parentIds': <String>[],
        'isRemoved': true,
      });
      await openPinTab(tester);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Link Child'));
      await tester.tap(find.text('Link Child'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('has been removed'),
        findsOneWidget,
      );
    });
  });

  group('Create New tab', () {
    Future<void> openCreateTab(WidgetTester tester) async {
      await openAddChildScreen(tester);
      await tester.tap(find.text('Create New'));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Create Child Account'));
      await tester.tap(find.text('Create Child Account'));
      await tester.pumpAndSettle();
    }

    testWidgets('submitting everything empty shows every validation error',
        (tester) async {
      await openCreateTab(tester);
      await submit(tester);

      expect(find.text('Please enter a username'), findsOneWidget);
      expect(find.text('Please enter an email address'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('an email with no @ is rejected', (tester) async {
      await openCreateTab(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
      await submit(tester);

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('a password under 6 characters is rejected', (tester) async {
      await openCreateTab(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'ab1');
      await submit(tester);

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('a confirm-password mismatch is rejected', (tester) async {
      await openCreateTab(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'password124');
      await submit(tester);

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
