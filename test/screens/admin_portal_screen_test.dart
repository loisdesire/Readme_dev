import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:readme_app/screens/admin/admin_portal_screen.dart';
import 'package:readme_app/screens/admin/widgets/admin_dashboard.dart';
import 'package:readme_app/screens/admin/widgets/book_upload_form.dart';
import 'package:readme_app/screens/admin/widgets/books_table.dart';
import 'package:readme_app/screens/admin/widgets/cloud_functions_panel.dart';

Widget wrap(MockFirebaseAuth auth, FakeFirebaseFirestore firestore) {
  return MaterialApp(
    home: AdminPortalScreen(authOverride: auth, firestoreOverride: firestore),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;

  // This admin console is desktop-browser-only tooling (a fixed 260px
  // sidebar plus a 3-column function-card layout, DataTables, etc.) —
  // unlike the rest of this app, it was never designed to fit a
  // phone-narrow viewport. flutter_test's default 800x600 surface is
  // narrower than any real window this screen is used in, and overflows
  // it in several places that aren't reachable in real usage; a realistic
  // desktop size avoids chasing those rather than genuine bugs.
  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<void> useDesktopSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows the sign-in form when signed out', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
  });

  testWidgets(
      'a signed-in user with role: admin on their own users doc sees the '
      'dashboard', (tester) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'admin-1'), signedIn: true);
    await firestore.collection('users').doc('admin-1').set({'role': 'admin'});

    await useDesktopSurface(tester);
    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    expect(find.text('ReadMe Admin'), findsOneWidget);
    expect(find.byType(AdminDashboard), findsOneWidget);
  });

  testWidgets(
      'a signed-in user found in the admins collection fallback also sees '
      'the dashboard', (tester) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'admin-1'), signedIn: true);
    // No 'role: admin' on their own users doc...
    await firestore.collection('users').doc('admin-1').set({'role': 'parent'});
    // ...but present in the admins fallback collection.
    await firestore.collection('admins').doc('admin-1').set({'role': 'admin'});

    await useDesktopSurface(tester);
    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    expect(find.text('ReadMe Admin'), findsOneWidget);
  });

  testWidgets(
      'a signed-in non-admin is shown the sign-in form again and signed out',
      (tester) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'user-1'), signedIn: true);
    await firestore.collection('users').doc('user-1').set({'role': 'parent'});

    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('a wrong-password sign-in attempt shows the raw Firebase error',
      (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));

    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'nope');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.textContaining('wrong-password'), findsOneWidget);
  });

  testWidgets('a successful sign-in then passing the admin check shows the '
      'dashboard', (tester) async {
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'admin-1', email: 'admin@example.com'),
      signedIn: false,
    );
    await firestore.collection('users').doc('admin-1').set({'role': 'admin'});

    await useDesktopSurface(tester);
    await tester.pumpWidget(wrap(auth, firestore));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'admin@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('ReadMe Admin'), findsOneWidget);
  });

  group('once signed in as admin', () {
    late MockFirebaseAuth auth;

    setUp(() async {
      auth = MockFirebaseAuth(mockUser: MockUser(uid: 'admin-1'), signedIn: true);
      await firestore.collection('users').doc('admin-1').set({'role': 'admin'});
    });

    testWidgets('the sidebar switches between all four tabs', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(wrap(auth, firestore));
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboard), findsOneWidget);

      await tester.tap(find.text('Upload Book'));
      await tester.pumpAndSettle();
      expect(find.byType(BookUploadForm), findsOneWidget);

      await tester.tap(find.text('Manage Books'));
      await tester.pumpAndSettle();
      expect(find.byType(BooksTable), findsOneWidget);

      await tester.tap(find.text('Cloud Functions'));
      await tester.pumpAndSettle();
      expect(find.byType(CloudFunctionsPanel), findsOneWidget);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboard), findsOneWidget);
    });

    testWidgets('signing out returns to the sign-in form', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(wrap(auth, firestore));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Sign In'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });
  });
}
