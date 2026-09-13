import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
// Firebase's own `AuthProvider` (base class for federated sign-in providers
// like GoogleAuthProvider) collides by name with our app's AuthProvider —
// hide it since this file only needs FirebaseAuthException from here.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/services/firebase_service.dart';

/// Builds an AuthProvider wired to fakes instead of real Firebase, so tests
/// run instantly with no network/emulator and no real project.
///
/// AuthProvider's constructor subscribes to `authStateChanges()`, and
/// MockFirebaseAuth delivers its *initial* signed-in/out state as a stream
/// event rather than synchronously. In the real app there's always a gap
/// (splash screen, navigation) between construction and the first
/// sign-in/sign-up call, so that event has long settled by then — but a
/// test that calls signIn/signUp immediately after construction can have
/// that stale initial event arrive *after* signIn/signUp's own state
/// change and clobber it. Awaiting this once after construction avoids
/// that race by settling the initial event first, matching real-world timing.
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
  group('AuthProvider.signUp', () {
    test('creates a Firebase Auth user and a matching Firestore profile', () async {
      final auth = MockFirebaseAuth();
      final firestore = FakeFirebaseFirestore();
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);

      final success = await provider.signUp(
        email: 'parent@example.com',
        password: 'password123',
        username: 'ParentOne',
        accountType: 'parent',
      );

      expect(success, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.userId, isNotNull);

      final doc = await firestore.collection('users').doc(provider.userId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['username'], 'ParentOne');
      expect(doc.data()!['accountType'], 'parent');
      expect(doc.data()!['hasCompletedQuiz'], false);
      // totalAchievementPoints is deliberately left absent (not even 0) at
      // creation — firestore.rules denies a client from setting it at all,
      // on create or update, so every reader already treats "absent" as
      // 0. See SECURITY.md's "Point-award security migration".
      expect(doc.data()!['totalAchievementPoints'], isNull);
    });

    test('a duplicate email surfaces a child-friendly error, not the raw code', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final provider = await buildAuthProvider(auth: auth, firestore: FakeFirebaseFirestore());

      final success = await provider.signUp(
        email: 'taken@example.com',
        password: 'password123',
        username: 'Someone',
      );

      expect(success, isFalse);
      expect(provider.status, AuthStatus.error);
      expect(provider.errorMessage, contains('already registered'));
    });

    test('an unrecognized Firebase error code still gets a friendly fallback message', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'some-new-error-code'));
      final provider = await buildAuthProvider(auth: auth, firestore: FakeFirebaseFirestore());

      final success = await provider.signUp(
        email: 'x@example.com',
        password: 'password123',
        username: 'X',
      );

      expect(success, isFalse);
      expect(provider.errorMessage, "Oops! Something went wrong. Please try again.");
    });
  });

  group('AuthProvider.signIn', () {
    test('loads the existing Firestore profile on successful sign-in', () async {
      final mockUser = MockUser(uid: 'child-1', email: 'child@example.com');
      final auth = MockFirebaseAuth(mockUser: mockUser);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('child-1').set({
        'username': 'Kiddo',
        'accountType': 'child',
        'hasCompletedQuiz': true,
        'personalityTraits': ['curious', 'kind'],
      });
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);

      final success = await provider.signIn(email: 'child@example.com', password: 'whatever');

      expect(success, isTrue);
      expect(provider.userId, 'child-1');
      expect(provider.isChildAccount, isTrue);
      expect(provider.hasCompletedQuiz(), isTrue);
      expect(provider.getPersonalityTraits(), ['curious', 'kind']);
    });

    test('wrong-password maps to a friendly, non-technical message', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      final provider = await buildAuthProvider(auth: auth, firestore: FakeFirebaseFirestore());

      final success = await provider.signIn(email: 'a@b.com', password: 'nope');

      expect(success, isFalse);
      expect(provider.status, AuthStatus.error);
      expect(provider.errorMessage, contains("doesn't match"));
    });

    test('an account removed by a parent is immediately signed back out', () async {
      final mockUser = MockUser(uid: 'removed-child', email: 'removed@example.com');
      final auth = MockFirebaseAuth(mockUser: mockUser);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('removed-child').set({
        'username': 'Gone',
        'accountType': 'child',
        'isRemoved': true,
      });
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);

      await provider.signIn(email: 'removed@example.com', password: 'whatever');

      expect(provider.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull); // signOut() actually ran
    });
  });

  group('AuthProvider.saveQuizResults', () {
    test('persists OCEAN scores and traits, and marks the quiz complete', () async {
      final mockUser = MockUser(uid: 'quiz-taker', email: 'q@example.com');
      final auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('quiz-taker').set({
        'username': 'Quizzer',
        'accountType': 'child',
        'hasCompletedQuiz': false,
      });
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);
      await provider.signIn(email: 'q@example.com', password: 'whatever');

      final success = await provider.saveQuizResults(
        selectedAnswers: [5, 4, 3, 2, 1, 5, 4, 3, 2, 1],
        traitScores: {'O': 10, 'C': 8, 'E': 6, 'A': 4, 'N': 2},
        dominantTraits: ['curious', 'creative', 'imaginative', 'responsible', 'organized'],
      );

      expect(success, isTrue);
      expect(provider.hasCompletedQuiz(), isTrue);
      expect(provider.getPersonalityTraits(),
          ['curious', 'creative', 'imaginative', 'responsible', 'organized']);

      final doc = await firestore.collection('users').doc('quiz-taker').get();
      expect(doc.data()!['oceanScores'], {'O': 10, 'C': 8, 'E': 6, 'A': 4, 'N': 2});
    });
  });

  group('AuthProvider parent/child relationship getters', () {
    test('parentIds reads the new array field when present', () async {
      final mockUser = MockUser(uid: 'child-2', email: 'c2@example.com');
      final auth = MockFirebaseAuth(mockUser: mockUser);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('child-2').set({
        'accountType': 'child',
        'parentIds': ['parent-a', 'parent-b'],
      });
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);
      await provider.signIn(email: 'c2@example.com', password: 'whatever');

      expect(provider.parentIds, ['parent-a', 'parent-b']);
    });

    test('parentIds falls back to the legacy singular parentId field', () async {
      final mockUser = MockUser(uid: 'child-3', email: 'c3@example.com');
      final auth = MockFirebaseAuth(mockUser: mockUser);
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('child-3').set({
        'accountType': 'child',
        'parentId': 'legacy-parent',
      });
      final provider = await buildAuthProvider(auth: auth, firestore: firestore);
      await provider.signIn(email: 'c3@example.com', password: 'whatever');

      expect(provider.parentIds, ['legacy-parent']);
    });
  });
}
