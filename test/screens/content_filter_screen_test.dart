import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/screens/parent/content_filter_screen.dart';
import 'package:readme_app/services/content_filter_service.dart';
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

Widget wrap(Widget child, AuthProvider authProvider) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: child,
    ),
  );
}

/// ContentFilterScreen's ListView.builder only builds items in/near the
/// viewport, so a category has to be scrolled to individually rather than
/// searched for all at once. Drags the list directly (rather than
/// tester.scrollUntilVisible, whose internal scrollable-resolution proved
/// fragile against this specific screen's widget tree) forward in small
/// steps until the target text resolves to exactly one widget.
Future<Finder> scrollToCategory(WidgetTester tester, String displayName) async {
  final target = find.text(displayName);
  for (var i = 0; i < 40; i++) {
    if (target.evaluate().isNotEmpty) return target;
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  fail('Could not find category "$displayName" by scrolling');
}

Future<String> statusOf(WidgetTester tester, String displayName) async {
  final target = await scrollToCategory(tester, displayName);
  final rowFinder = find.ancestor(of: target, matching: find.byType(Row)).first;
  final allowed = find.descendant(of: rowFinder, matching: find.text('Allowed'));
  return tester.any(allowed) ? 'Allowed' : 'Blocked';
}

void main() {
  late FakeFirebaseFirestore firestore;
  late AuthProvider authProvider;
  late ContentFilterService contentFilterService;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'parent-1', email: 'parent@example.com'),
      signedIn: true,
    );
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    contentFilterService = ContentFilterService.withInstances(firebaseService: firebaseService);
  });

  testWidgets(
      'regression: every category in kAllContentFilterCategories — '
      'including the 7 added when the default filter\'s tag-list-drift '
      'bug was fixed — appears as a toggle, defaulting to allowed for a '
      'user with no saved filter yet', (tester) async {
    await tester.pumpWidget(wrap(
      ContentFilterScreen(contentFilterService: contentFilterService),
      authProvider,
    ));
    await tester.pumpAndSettle();

    for (final category in kAllContentFilterCategories) {
      final displayName = category[0].toUpperCase() + category.substring(1);
      expect(await statusOf(tester, displayName), 'Allowed',
          reason: '"$displayName" should default to allowed');
    }
  });

  testWidgets(
      'regression: saving without touching anything preserves every '
      'category, including the ones an earlier bug would have silently '
      'dropped', (tester) async {
    await tester.pumpWidget(wrap(
      ContentFilterScreen(contentFilterService: contentFilterService),
      authProvider,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = await contentFilterService.getContentFilter('parent-1');
    expect(
      saved!.allowedCategories.toSet(),
      kAllContentFilterCategories.toSet(),
    );
  });

  testWidgets('toggling a category off and saving removes only that one '
      'category', (tester) async {
    await tester.pumpWidget(wrap(
      ContentFilterScreen(contentFilterService: contentFilterService),
      authProvider,
    ));
    await tester.pumpAndSettle();

    // Turn off "Innovation" — one of the categories that used to be
    // missing from this screen entirely.
    final target = await scrollToCategory(tester, 'Innovation');
    final rowFinder = find.ancestor(of: target, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: rowFinder, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(find.descendant(of: rowFinder, matching: find.text('Blocked')), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final saved = await contentFilterService.getContentFilter('parent-1');
    expect(saved!.allowedCategories.contains('innovation'), isFalse);
    expect(saved.allowedCategories.contains('adventure'), isTrue);
    expect(saved.allowedCategories.length, kAllContentFilterCategories.length - 1);
  });

  testWidgets('loads and reflects a previously saved, already-narrowed '
      'filter (not just the all-enabled default)', (tester) async {
    await firestore.collection('content_filters').doc('parent-1').set({
      'userId': 'parent-1',
      'allowedCategories': ['adventure', 'fantasy'],
      'blockedWords': <String>[],
      'maxAgeRating': '12+',
      'enableSafeMode': true,
      'allowedAuthors': <String>[],
      'blockedAuthors': <String>[],
      'maxReadingTimeMinutes': 60,
      'allowedTimes': ['06:00-22:00'],
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });

    await tester.pumpWidget(wrap(
      ContentFilterScreen(contentFilterService: contentFilterService),
      authProvider,
    ));
    await tester.pumpAndSettle();

    // Checked in the same order they appear in the list — the scroll
    // helper only scrolls forward.
    expect(await statusOf(tester, 'Adventure'), 'Allowed');
    expect(await statusOf(tester, 'Fantasy'), 'Allowed');
    expect(await statusOf(tester, 'Kindness'), 'Blocked');
    // A category not in the saved filter's allowedCategories — including
    // one of the 7 that used to be missing from this screen — is Blocked.
    expect(await statusOf(tester, 'Innovation'), 'Blocked');
  });
}
