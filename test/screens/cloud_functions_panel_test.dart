import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/admin/widgets/cloud_functions_panel.dart';

// The actual function-trigger HTTP calls go through the top-level
// http.post function directly (no injectable http.Client), so they aren't
// exercised here — see this widget's own doc comment and SECURITY.md for
// the same accepted gap already documented for cloud_functions elsewhere.
// Everything before that network call — loading/saving the enabled-state
// settings doc, and the disabled-function guard that stops a trigger
// before any network call happens — is fully covered.

Widget wrap(FakeFirebaseFirestore firestore) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CloudFunctionsPanel(firestoreOverride: firestore),
      ),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  testWidgets('all three functions default to enabled with no saved settings',
      (tester) async {
    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Enabled'), findsNWidgets(3));
    expect(find.text('Disabled'), findsNothing);
  });

  testWidgets('loads a previously saved disabled state for one function',
      (tester) async {
    await firestore.collection('admin_settings').doc('cloud_functions').set({
      'aiTaggingEnabled': false,
      'aiRecommendationsEnabled': true,
      'healthCheckEnabled': true,
    });

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Enabled'), findsNWidgets(2));
  });

  testWidgets('toggling a function off persists the new state to Firestore',
      (tester) async {
    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final doc =
        await firestore.collection('admin_settings').doc('cloud_functions').get();
    expect(doc.data()!['aiTaggingEnabled'], isFalse);
    expect(doc.data()!['aiRecommendationsEnabled'], isTrue);
    expect(doc.data()!['healthCheckEnabled'], isTrue);
  });

  testWidgets(
      'a disabled function\'s "Trigger" button is inert — tapping it does '
      'nothing, never attempts the network call', (tester) async {
    await firestore.collection('admin_settings').doc('cloud_functions').set({
      'aiTaggingEnabled': false,
      'aiRecommendationsEnabled': true,
      'healthCheckEnabled': true,
    });

    await tester.pumpWidget(wrap(firestore));
    await tester.pumpAndSettle();

    // The button itself is disabled (onPressed: null) whenever !enabled,
    // so a tap on it is a no-op at the framework level — it never reaches
    // _triggerFunction's own "This function is currently disabled" guard,
    // which is consequently unreachable dead code (worth flagging, not
    // fixing: harmless, just never actually shown to a user this way).
    await tester.tap(find.text('Trigger AI Tagging'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('This function is currently disabled'), findsNothing);
    expect(find.text('Running...'), findsNothing);
  });
}
