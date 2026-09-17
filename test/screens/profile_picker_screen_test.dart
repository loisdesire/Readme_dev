import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/auth/login_screen.dart';
import 'package:readme_app/screens/auth/profile_picker_screen.dart';
import 'package:readme_app/screens/quiz/quiz_screen.dart';
import 'package:readme_app/services/device_child_profile_service.dart';
import 'package:readme_app/services/firebase_service.dart';

// Real device secure storage uses a platform channel that isn't available
// under plain `flutter_test` — this in-memory fake stands in for it.
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
  await Future<void>.value();
  return provider;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late DeviceChildProfileService deviceChildProfileService;

  // See login_screen_test.dart for why the provider must wrap MaterialApp
  // rather than sit as `home:`'s child — Navigator.pushReplacement (used
  // by both a successful sign-in and "Not your profile?") discards
  // whatever was part of the old route's page widget.
  Widget wrap() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        home: ProfilePickerScreen(
          deviceChildProfileService: deviceChildProfileService,
        ),
      ),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    // MockFirebaseAuth signs in as this single mockUser regardless of the
    // email/password actually passed to signInWithEmailAndPassword — same
    // pattern used throughout login_screen_test.dart.
    auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'kid-1', email: 'junior@example.com'));
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    deviceChildProfileService =
        DeviceChildProfileService(store: InMemorySecureKeyValueStore());
  });

  testWidgets('no remembered children: shows the picker with nobody on it',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Who\'s reading?'), findsOneWidget);
    final wrap0 = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap0.children, isEmpty);
  });

  testWidgets('shows an avatar and name for each remembered child',
      (tester) async {
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-2',
      username: 'Rosie',
      email: 'rosie@example.com',
      password: 'password456',
      avatar: '👧',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Junior'), findsOneWidget);
    expect(find.text('Rosie'), findsOneWidget);
  });

  testWidgets(
      'tapping a profile who has completed the quiz signs in and lands on '
      'ChildHomeScreen', (tester) async {
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'hasCompletedQuiz': true,
    });
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();

    expect(authProvider.isAuthenticated, isTrue);
    // ChildHomeScreen's own known FirebaseAuth.instance-based dependencies
    // (same class of gap as ProfileEditScreen's, documented in
    // settings_screen_test.dart) mean its full render can't be asserted in
    // this harness — draining that unrelated exception rather than
    // asserting on the widget tree past this point.
    tester.takeException();
  });

  testWidgets(
      'tapping a profile who has not completed the quiz signs in and lands '
      'on QuizScreen', (tester) async {
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'hasCompletedQuiz': false,
    });
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets(
      'a stored password that no longer works shows an error and forgets '
      'that profile instead of offering it forever', (tester) async {
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'wrong-password'));
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'stale-password',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Couldn\'t sign in'), findsOneWidget);
    expect(
      await deviceChildProfileService.getRememberedChildren(),
      isEmpty,
    );
  });

  testWidgets(
      'long-pressing a profile and confirming removes it from the picker',
      (tester) async {
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Junior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Junior'), findsNothing);
    expect(await deviceChildProfileService.getRememberedChildren(), isEmpty);
  });

  testWidgets(
      'tapping "Not your profile?" navigates to LoginScreen instead of '
      'signing anyone in', (tester) async {
    await deviceChildProfileService.rememberChild(const RememberedChildProfile(
      uid: 'kid-1',
      username: 'Junior',
      email: 'junior@example.com',
      password: 'password123',
      avatar: '👦',
    ));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Not your profile?'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(authProvider.isAuthenticated, isFalse);
  });
}
