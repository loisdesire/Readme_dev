import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/parent/qr_scanner_widget.dart';
import 'package:readme_app/services/firebase_service.dart';

// QRScannerWidget's actual linking logic lives in a private method reached
// only through MobileScanner's onDetect callback — there's no way to call
// it directly, but MobileScanner exposes onDetect as a public field, so a
// test can grab the mounted MobileScanner and invoke it with a synthetic
// BarcodeCapture, exactly as the camera plugin would on a real scan.

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

Future<void> detect(WidgetTester tester, String code) async {
  final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
  scanner.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
  await tester.pumpAndSettle();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;

  // A successful link calls Navigator.pop(context, true) right after
  // queuing its SnackBar — see add_child_screen_test.dart's wrap() for why
  // that needs a real route underneath to be observable rather than a
  // silent no-op.
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
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: QRScannerWidget()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScanner(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
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

  testWidgets('a code with the wrong prefix is rejected as not a ReadMe code',
      (tester) async {
    await openScanner(tester);

    await detect(tester, 'SOMEOTHERAPP:CHILD:child-1:123456');

    expect(
      find.text('Invalid QR code - not a ReadMe child account'),
      findsOneWidget,
    );
    // This path schedules a 2-second Future.delayed to allow rescanning —
    // flush it explicitly so it isn't still pending at test teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a code with the wrong number of parts is rejected',
      (tester) async {
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:child-1');

    expect(find.text('Invalid QR code format'), findsOneWidget);
  });

  testWidgets('a code naming a nonexistent child is rejected', (tester) async {
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:ghost-child:123456');

    expect(find.text('Child account not found'), findsOneWidget);
  });

  testWidgets('a code naming a non-child account is rejected', (tester) async {
    await firestore.collection('users').doc('target-1').set({
      'accountType': 'parent',
      'parentAccessPin': '123456',
    });
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:target-1:123456');

    expect(find.text('This is not a child account'), findsOneWidget);
  });

  testWidgets('a wrong PIN is rejected', (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'accountType': 'child',
      'parentAccessPin': '123456',
    });
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:child-1:000000');

    expect(find.text('Invalid PIN - QR code may be outdated'), findsOneWidget);
  });

  testWidgets('a removed child account is rejected', (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'accountType': 'child',
      'parentAccessPin': '123456',
      'isRemoved': true,
    });
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:child-1:123456');

    expect(
      find.text('This child account has been removed'),
      findsOneWidget,
    );
  });

  testWidgets('a child already linked to this parent is rejected',
      (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'accountType': 'child',
      'parentAccessPin': '123456',
      'parentIds': ['parent-1'],
    });
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:child-1:123456');

    expect(
      find.text('This child is already linked to your account'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a valid code links the child, updating both sides, and shows success',
      (tester) async {
    await firestore.collection('users').doc('child-1').set({
      'username': 'Junior',
      'accountType': 'child',
      'parentAccessPin': '123456',
      'parentIds': <String>[],
    });
    await openScanner(tester);

    await detect(tester, 'READMEAPP:CHILD:child-1:123456');

    expect(find.text('Junior linked successfully!'), findsOneWidget);
    final parentDoc = await firestore.collection('users').doc('parent-1').get();
    expect(parentDoc.data()!['children'], contains('child-1'));
    final childDoc = await firestore.collection('users').doc('child-1').get();
    expect(childDoc.data()!['parentIds'], contains('parent-1'));
  });
}
