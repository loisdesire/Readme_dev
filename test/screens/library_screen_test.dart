import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/providers/user_provider.dart';
import 'package:readme_app/screens/child/library_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/firestore_helpers.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';

// LibraryScreen (unlike ChildHomeScreen) routes every Firestore/Auth touch
// through its injected providers — no raw FirebaseFirestore.instance/
// FirebaseAuth.instance calls of its own — so it needs no test-only DI seam
// of its own. Its per-item animations (flutter_staggered_animations) are
// finite, unlike ChildHomeScreen's looping PulseAnimation, so pumpAndSettle()
// is safe to use here.

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
  // See child_home_screen_test.dart: this only resolves when awaited from
  // setUp(), never directly inside a testWidgets() body.
  await Future<void>.delayed(Duration.zero);
  return provider;
}

BookProvider buildBookProvider(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
  final firebaseService = FirebaseService.withInstances(
    auth: auth,
    firestore: firestore,
    storage: MockFirebaseStorage(),
  );
  return BookProvider(
    firebaseService: firebaseService,
    apiService: ApiService.withInstances(firestore: firestore),
    analyticsService: AnalyticsService.withInstances(firebaseService: firebaseService),
    achievementService: AchievementService.withInstances(
      auth: auth,
      firestore: firestore,
      notificationService: NotificationService.withInstances(auth: auth, firestore: firestore),
      weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    ),
    contentFilterService: ContentFilterService.withInstances(firebaseService: firebaseService),
    weeklyChallengeService: WeeklyChallengeService.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

UserProvider buildUserProvider(FakeFirebaseFirestore firestore, MockFirebaseAuth auth) {
  return UserProvider(
    firebaseService: FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    ),
    firestoreHelpers: FirestoreHelpers.withInstances(firestore: firestore),
    readingSessionService: ReadingSessionService.withInstances(firestore: firestore),
  );
}

Future<void> seedBook(
  FakeFirebaseFirestore firestore,
  String id, {
  String title = 'A Book',
  String author = 'Author',
  String description = 'desc',
  List<String> traits = const [],
  // ContentFilterService's default filter (applied whenever a userId is
  // passed to loadAllBooks, as LibraryScreen's own initState always does)
  // requires a book to have at least one tag in the allowed-categories
  // list, or it's excluded from `filteredBooks` entirely — a book with no
  // tags at all would vanish from every _filteredBooks-driven tab (All
  // Books, For You) while still appearing in the tabs that read _allBooks
  // directly (Reading Now, Finished, Favorites). Real books always carry
  // at least one real category tag, so default to one here too.
  List<String> tags = const ['adventure'],
  String ageRating = '6+',
}) {
  return firestore.collection('books').doc(id).set({
    'title': title,
    'author': author,
    'description': description,
    'traits': traits,
    'tags': tags,
    'ageRating': ageRating,
    'estimatedReadingTime': 15,
  });
}

Widget wrap({
  required AuthProvider authProvider,
  required BookProvider bookProvider,
  required UserProvider userProvider,
  int initialTab = 0,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: LibraryScreen(initialTab: initialTab),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late BookProvider bookProvider;
  late UserProvider userProvider;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);
    bookProvider = buildBookProvider(firestore, auth);
    userProvider = buildUserProvider(firestore, auth);
  });

  testWidgets('All Books tab lists every loaded book', (tester) async {
    await seedBook(firestore, 'b1', title: 'Adventure One');
    await seedBook(firestore, 'b2', title: 'Adventure Two');

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Adventure One'), findsOneWidget);
    expect(find.text('Adventure Two'), findsOneWidget);
  });

  testWidgets('typing in the search box filters the All Books tab by title',
      (tester) async {
    await seedBook(firestore, 'b1', title: 'Dragon Tales');
    await seedBook(firestore, 'b2', title: 'Space Explorers');

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
    ));
    await tester.pumpAndSettle();

    // The search field is inline and collapsed until the search icon is
    // tapped (or it already has text/focus) — open it first.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'dragon');
    await tester.pumpAndSettle();

    expect(find.text('Dragon Tales'), findsOneWidget);
    expect(find.text('Space Explorers'), findsNothing);
  });

  testWidgets(
      'regression: an empty-state tab does not overflow when the search '
      'field is expanded, shrinking the space available for it',
      (tester) async {
    // No books seeded at all: the Ongoing tab's empty state is reached
    // immediately, with no async load in between.
    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      initialTab: 2, // Reading Now
    ));
    await tester.pumpAndSettle();

    // Opening the inline search field shrinks the tab body's available
    // height by the field's own height — this is what used to overflow
    // _buildEmptyState's fixed-size Column by 16px.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('No ongoing books'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Reading Now tab shows only a book with in-progress reading progress',
      (tester) async {
    await seedBook(firestore, 'in-progress', title: 'In Progress Book');
    await seedBook(firestore, 'done', title: 'Finished Book');
    await seedBook(firestore, 'unstarted', title: 'Unstarted Book');
    await bookProvider.loadAllBooks();
    await bookProvider.updateReadingProgress(
      userId: 'kid-1',
      bookId: 'in-progress',
      currentPage: 3,
      totalPages: 10,
      additionalReadingTime: 5,
    );
    await bookProvider.updateReadingProgress(
      userId: 'kid-1',
      bookId: 'done',
      currentPage: 10,
      totalPages: 10,
      additionalReadingTime: 10,
    );
    await bookProvider.loadUserProgress('kid-1');

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      initialTab: 2, // Reading Now
    ));
    await tester.pumpAndSettle();

    expect(find.text('In Progress Book'), findsOneWidget);
    expect(find.text('Finished Book'), findsNothing);
    expect(find.text('Unstarted Book'), findsNothing);
  });

  testWidgets('Finished tab shows only a completed book', (tester) async {
    await seedBook(firestore, 'in-progress', title: 'In Progress Book');
    await seedBook(firestore, 'done', title: 'Finished Book');
    await bookProvider.loadAllBooks();
    await bookProvider.updateReadingProgress(
      userId: 'kid-1',
      bookId: 'in-progress',
      currentPage: 3,
      totalPages: 10,
      additionalReadingTime: 5,
    );
    await bookProvider.updateReadingProgress(
      userId: 'kid-1',
      bookId: 'done',
      currentPage: 10,
      totalPages: 10,
      additionalReadingTime: 10,
    );
    await bookProvider.loadUserProgress('kid-1');

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      initialTab: 3, // Finished
    ));
    await tester.pumpAndSettle();

    expect(find.text('Finished Book'), findsOneWidget);
    expect(find.text('In Progress Book'), findsNothing);
  });

  testWidgets('My Favorites tab shows an empty state with no favorites, '
      'then the favorited book once one is added', (tester) async {
    await seedBook(firestore, 'b1', title: 'Loved Book');
    await seedBook(firestore, 'b2', title: 'Ignored Book');
    await bookProvider.loadAllBooks();
    await bookProvider.loadFavorites('kid-1');

    await tester.pumpWidget(wrap(
      authProvider: authProvider,
      bookProvider: bookProvider,
      userProvider: userProvider,
      initialTab: 4, // My Favorites
    ));
    await tester.pumpAndSettle();

    expect(find.text('No favorites yet'), findsOneWidget);

    await bookProvider.toggleFavorite('kid-1', 'b1');
    await tester.pumpAndSettle();

    expect(find.text('Loved Book'), findsOneWidget);
    expect(find.text('Ignored Book'), findsNothing);
  });
}
