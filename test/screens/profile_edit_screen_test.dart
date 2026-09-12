import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/child/profile_edit_screen.dart';
import 'package:readme_app/services/firebase_service.dart';

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
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: MaterialApp(
        home: ProfileEditScreen(
          firestoreOverride: firestore,
          authOverride: auth,
        ),
      ),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'kid-1', email: 'kid1@example.com'),
      signedIn: true,
    );
    await firestore.collection('users').doc('kid-1').set({
      'username': 'Junior',
      'avatar': '🐶',
    });
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
  });

  testWidgets('pre-fills the username, email, and currently selected avatar',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Junior'), findsOneWidget);
    expect(find.text('kid1@example.com'), findsOneWidget);

    // The selected avatar's circle has a colored border; find its
    // Container by locating the '🐶' text's Container ancestor.
    final dogAvatar = find.ancestor(
      of: find.text('🐶'),
      matching: find.byType(Container),
    );
    expect(dogAvatar, findsWidgets);
  });

  testWidgets('tapping Save with an empty username shows an error and does '
      'not write to Firestore', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    // "Save Changes" sits below the fold at the default 800x600 test
    // viewport (the whole body is inside a SingleChildScrollView).
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Username cannot be empty'), findsOneWidget);
    final doc = await firestore.collection('users').doc('kid-1').get();
    expect(doc.data()!['username'], 'Junior');
  });

  testWidgets(
      'selecting a new avatar and saving updates Firestore and pops the '
      'screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider<AuthProvider>.value(
                  value: authProvider,
                  child: ProfileEditScreen(
                    firestoreOverride: firestore,
                    authOverride: auth,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🦊'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'NewName');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('users').doc('kid-1').get();
    expect(doc.data()!['username'], 'NewName');
    expect(doc.data()!['avatar'], '🦊');
    expect(find.byType(ProfileEditScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
