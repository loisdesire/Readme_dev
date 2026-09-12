import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/providers/auth_provider.dart';
import 'package:readme_app/providers/book_provider.dart';
import 'package:readme_app/screens/book/book_details_screen.dart';
import 'package:readme_app/screens/book/book_quiz_screen.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/services/analytics_service.dart';
import 'package:readme_app/services/api_service.dart';
import 'package:readme_app/services/content_filter_service.dart';
import 'package:readme_app/services/firebase_service.dart';
import 'package:readme_app/services/notification_service.dart';
import 'package:readme_app/services/reading_session_service.dart';
import 'package:readme_app/services/weekly_challenge_service.dart';
import 'package:readme_app/utils/page_transitions.dart';
import 'package:readme_app/widgets/app_button.dart';

/// Captures pushed routes without ever pumping the frame that would build
/// them. Needed for the "unlocked Quiz button" test below: BookQuizScreen's
/// own initState reaches for a real Firestore-backed singleton with no
/// override available from this call site, so actually letting it mount
/// would crash in a test environment with no Firebase app (same gotcha
/// documented in book_completion_celebration_screen_test.dart). The Quiz
/// button's onPressed is synchronous (no await before Navigator.push), so a
/// bare tap() without any further pump is enough to capture the push.
class RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
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
  await Future<void>.delayed(Duration.zero);
  return provider;
}

Future<void> seedBook(
  FakeFirebaseFirestore firestore,
  String id, {
  String? pdfUrl,
}) {
  return firestore.collection('books').doc(id).set({
    'title': 'The Great Adventure',
    'author': 'Test Author',
    'description': 'A test description.',
    'coverEmoji': '📖',
    'traits': <String>['adventurous'],
    'ageRating': '6+',
    'estimatedReadingTime': 20,
    if (pdfUrl != null) 'pdfUrl': pdfUrl,
    'createdAt': Timestamp.now(),
  });
}

Future<void> seedProgress(
  FakeFirebaseFirestore firestore, {
  required String userId,
  required String bookId,
  required int currentPage,
  required int totalPages,
}) {
  return firestore.collection('reading_progress').add({
    'userId': userId,
    'bookId': bookId,
    'currentPage': currentPage,
    'totalPages': totalPages,
    'progressPercentage': currentPage / totalPages,
    'readingTimeMinutes': 10,
    'lastReadAt': Timestamp.now(),
    'isCompleted': currentPage >= totalPages,
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late AuthProvider authProvider;
  late BookProvider bookProvider;

  Widget wrap({List<NavigatorObserver> observers = const []}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
      ],
      child: MaterialApp(
        navigatorObservers: observers,
        home: BookDetailsScreen(
          bookId: 'b1',
          firestoreOverride: firestore,
        ),
      ),
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'kid-1'), signedIn: true);
    authProvider = await buildAuthProvider(auth: auth, firestore: firestore);

    final firebaseService = FirebaseService.withInstances(
      auth: auth,
      firestore: firestore,
      storage: MockFirebaseStorage(),
    );
    bookProvider = BookProvider(
      firebaseService: firebaseService,
      apiService: ApiService.withInstances(firestore: firestore),
      analyticsService:
          AnalyticsService.withInstances(firebaseService: firebaseService),
      achievementService: AchievementService.withInstances(
        auth: auth,
        firestore: firestore,
        notificationService:
            NotificationService.withInstances(auth: auth, firestore: firestore),
        weeklyChallengeService:
            WeeklyChallengeService.withInstances(firestore: firestore),
      ),
      contentFilterService:
          ContentFilterService.withInstances(firebaseService: firebaseService),
      weeklyChallengeService:
          WeeklyChallengeService.withInstances(firestore: firestore),
      readingSessionService:
          ReadingSessionService.withInstances(firestore: firestore),
    );
  });

  testWidgets(
      'shows the title, author, description, reading time, age rating, '
      'and Explore when there is no progress', (tester) async {
    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('The Great Adventure'), findsOneWidget);
    expect(find.text('by Test Author'), findsOneWidget);
    expect(find.text('A test description.'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(find.text('6+'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('shows progress and "Keep Going" when progress exists',
      (tester) async {
    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();
    await seedProgress(firestore,
        userId: 'kid-1', bookId: 'b1', currentPage: 5, totalPages: 10);
    await bookProvider.loadUserProgress('kid-1');

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Progress: 50%'), findsOneWidget);
    expect(find.text('Keep Going'), findsOneWidget);
  });

  testWidgets(
      'tapping the heart icon adds the book to favorites and shows a '
      'confirmation', (tester) async {
    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.text('Added to favorites'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    final favDoc = await firestore
        .collection('user_favorites')
        .doc('kid-1')
        .collection('favorites')
        .doc('b1')
        .get();
    expect(favDoc.exists, isTrue);
  });

  testWidgets(
      'the Quiz button is locked below 100% progress and does nothing '
      'when tapped', (tester) async {
    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();
    await seedProgress(firestore,
        userId: 'kid-1', bookId: 'b1', currentPage: 3, totalPages: 10);
    await bookProvider.loadUserProgress('kid-1');

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock), findsOneWidget);
    final quizButton = tester.widget<SecondaryButton>(
      find.byType(SecondaryButton),
    );
    expect(quizButton.isDisabled, isTrue);

    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();

    expect(find.byType(BookDetailsScreen), findsOneWidget);
  });

  testWidgets(
      'the Quiz button unlocks at 100% progress and navigates to '
      'BookQuizScreen', (tester) async {
    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();
    await seedProgress(firestore,
        userId: 'kid-1', bookId: 'b1', currentPage: 10, totalPages: 10);
    await bookProvider.loadUserProgress('kid-1');

    final observer = RecordingNavigatorObserver();
    await tester.pumpWidget(wrap(observers: [observer]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.quiz), findsOneWidget);

    // No further pumping after the tap: BookQuizScreen's own initState
    // reaches for a real singleton with no override from this call site
    // (see RecordingNavigatorObserver's doc comment above). The Quiz
    // button's onPressed is synchronous, so the push already happened by
    // the time tap() returns.
    await tester.tap(find.text('Quiz'));

    final pushedPage =
        (observer.pushedRoutes.last as SlideUpRoute).page as BookQuizScreen;
    expect(pushedPage.bookId, 'b1');
    expect(pushedPage.bookTitle, 'The Great Adventure');
  });

  testWidgets(
      'tapping Explore on a book with no PDF shows an unavailable message',
      (tester) async {
    await seedBook(firestore, 'b1'); // no pdfUrl
    await bookProvider.loadAllBooks();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'This book is not available for reading yet. Please try another book.'),
      findsOneWidget,
    );
  });

  // Not testing "tapping Explore on a book WITH a PDF navigates to the PDF
  // reader" here: that handler awaits trackBookInteraction() before
  // navigating, so — unlike the Quiz button above — capturing the push
  // requires pumping, which would also build PdfReadingScreenSyncfusion.
  // That screen is large/complex and its own feasibility as a widget-test
  // target is assessed separately (see its dedicated test file).

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await seedBook(firestore, 'b1');
    await bookProvider.loadAllBooks();
    await seedProgress(firestore,
        userId: 'kid-1', bookId: 'b1', currentPage: 5, totalPages: 10);
    await bookProvider.loadUserProgress('kid-1');

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
