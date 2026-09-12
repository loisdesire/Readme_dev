import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/child/parent_link_qr_screen.dart';
import 'package:readme_app/services/firebase_service.dart';

// Regression coverage for a real vulnerability: the parent-access PIN
// shown here is a bearer credential (anyone holding it can link themselves
// as a parent to this child account — see AddChildScreen/QRScannerWidget)
// that used to be generated from `DateTime.now().millisecondsSinceEpoch`,
// making it predictable rather than a genuine 1-in-900,000 secret. See
// SECURITY.md.

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

Widget wrap(
  AuthProvider authProvider, {
  String childUid = 'child-1',
  String? parentAccessPin,
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      home: ParentLinkQRScreen(
        childUid: childUid,
        childName: 'Junior',
        parentAccessPin: parentAccessPin,
      ),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  // Built here (setUp(), not inside a testWidgets() body): buildAuthProvider's
  // internal Future.delayed only resolves on setUp()'s real event loop —
  // see child_home_screen_test.dart / SECURITY.md for the same gotcha.
  late AuthProvider authProvider2;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'child-1'), signedIn: true);
    await firestore.collection('users').doc('child-1').set({'username': 'Junior'});
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    final auth2 = MockFirebaseAuth(mockUser: MockUser(uid: 'child-2'), signedIn: true);
    await firestore.collection('users').doc('child-2').set({'username': 'Sibling'});
    authProvider2 = await buildAuthProvider(auth: auth2, firestore: firestore);
  });

  testWidgets('reuses an already-issued PIN without generating a new one',
      (tester) async {
    await tester.pumpWidget(wrap(authProvider, parentAccessPin: '654321'));
    await tester.pumpAndSettle();

    expect(find.text('654321'), findsOneWidget);
    final doc = await firestore.collection('users').doc('child-1').get();
    expect(doc.data()!.containsKey('parentAccessPin'), isFalse);
  });

  testWidgets(
      'generates and persists a 6-digit PIN when the child has none yet',
      (tester) async {
    await tester.pumpWidget(wrap(authProvider));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('users').doc('child-1').get();
    final savedPin = doc.data()!['parentAccessPin'] as String;
    expect(savedPin, matches(RegExp(r'^\d{6}$')));
    expect(find.text(savedPin), findsOneWidget);
  });

  testWidgets(
      'two PINs generated back-to-back are not identical — regression for '
      'the clock-derived generator that would produce the same PIN for '
      'calls landing in the same millisecond', (tester) async {
    await tester.pumpWidget(wrap(authProvider));
    await tester.pumpAndSettle();
    final pin1 =
        (await firestore.collection('users').doc('child-1').get()).data()!['parentAccessPin'];

    await tester.pumpWidget(wrap(authProvider2, childUid: 'child-2'));
    await tester.pumpAndSettle();
    final pin2 =
        (await firestore.collection('users').doc('child-2').get()).data()!['parentAccessPin'];

    expect(pin1, isNot(equals(pin2)));
  });
}
