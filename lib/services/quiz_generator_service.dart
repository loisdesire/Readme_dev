import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';
import 'achievement_service.dart';

/// True if a `{success: false, code: ...}` response from `generateBookQuiz`
/// should NOT be retried — the request itself was invalid (bad bookId,
/// book not found), so retrying would just fail the same way again.
bool isNonRetryableErrorResult(Map<String, dynamic> data) {
  final code = data['code'];
  return code == 'invalid-argument' || code == 'not-found';
}

/// True if a thrown FirebaseFunctionsException's error code should NOT be
/// retried — an auth problem won't resolve itself by trying again.
bool isNonRetryableExceptionCode(String? code) {
  return code == 'permission-denied' || code == 'unauthenticated';
}

/// Extracts a human-readable error message from a failed (non-exception)
/// Cloud Function response, matching whatever shape the function used.
String extractErrorMessage(dynamic responseData) {
  if (responseData is Map) {
    final message = responseData['message'] ?? responseData['error'];
    if (message != null) return message.toString();
    return 'Unknown error';
  }
  return 'Invalid response format: $responseData';
}

class QuizGeneratorService {
  static final QuizGeneratorService _instance =
      QuizGeneratorService._internal();
  factory QuizGeneratorService() => _instance;
  QuizGeneratorService._internal()
      : _injectedFunctions = null,
        _firestore = FirebaseFirestore.instance,
        _injectedAchievementService = null;

  /// Test-only: an independent (non-singleton) instance wrapping fakes.
  /// `functions` has no fake/mock package available for this Firebase
  /// plugin (unlike auth/firestore/storage), so getBookQuiz's actual
  /// httpsCallable-calling retry loop stays untested at the unit level —
  /// see quiz_generator_service_test.dart and SECURITY.md for what IS
  /// covered instead (the pure decision functions above, plus every
  /// Firestore/AchievementService-touching method).
  @visibleForTesting
  QuizGeneratorService.withInstances({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
    AchievementService? achievementService,
  })  : _firestore = firestore,
        _injectedFunctions = functions,
        _injectedAchievementService = achievementService;

  // Both resolved lazily (not in the constructor) so building a
  // QuizGeneratorService.withInstances() for a test that never reaches
  // getBookQuiz's Cloud Function call, or never calls awardQuizPoints,
  // doesn't require a real Firebase app to exist just to satisfy these
  // fields — AchievementService()'s own singleton constructor is just as
  // eager about FirebaseFirestore.instance/FirebaseAuth.instance.
  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions get _functions => _injectedFunctions ?? FirebaseFunctions.instance;
  final FirebaseFirestore _firestore;
  final AchievementService? _injectedAchievementService;
  AchievementService get _achievementService =>
      _injectedAchievementService ?? AchievementService();

  /// Generate or retrieve quiz for a book
  /// Returns cached quiz if exists, generates new one if not
  /// Falls back to default quiz if generation fails
  Future<Map<String, dynamic>?> getBookQuiz(String bookId) async {
    try {
      appLog('Fetching quiz for book: $bookId', level: 'INFO');

      // Check cache first
      final cachedQuiz = await _getCachedQuiz(bookId);
      if (cachedQuiz != null) {
        appLog('Using cached quiz for book: $bookId', level: 'INFO');
        return cachedQuiz;
      }

      // Generate new quiz via Cloud Function with retry logic
      appLog('Generating new quiz for book: $bookId', level: 'INFO');
      final callable = _functions.httpsCallable(
        'generateBookQuiz',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      int retries = 0;
      const maxRetries = 2;

      while (retries < maxRetries) {
        try {
          appLog(
            '[QUIZ_SERVICE] Attempt ${retries + 1}/$maxRetries: calling Cloud Function for $bookId',
            level: 'DEBUG',
          );
          final result = await callable.call({'bookId': bookId});

          appLog('Cloud Function response: ${result.data}', level: 'DEBUG');

          if (result.data is Map && result.data['success'] == true) {
            final quizData =
                Map<String, dynamic>.from(result.data['quiz'] as Map);
            appLog(
              '[QUIZ_SERVICE] Quiz generated successfully (${quizData['questions']?.length ?? 0} questions)',
              level: 'INFO',
            );
            return quizData;
          }

          final errorMsg = extractErrorMessage(result.data);
          appLog('Quiz generation failed: $errorMsg', level: 'ERROR');

          // Don't retry on invalid-argument or not-found errors
          if (result.data is Map &&
              isNonRetryableErrorResult(result.data as Map<String, dynamic>)) {
            return null;
          }

          retries++;
          if (retries < maxRetries) {
            appLog('[QUIZ_SERVICE] Retrying after 2 seconds...',
                level: 'DEBUG');
            await Future.delayed(const Duration(seconds: 2));
          }
        } on FirebaseFunctionsException catch (e) {
          // Extract detailed error message
          final errorMessage = e.message ?? 'Unknown error';
          final errorCode = e.code;
          final errorDetails = e.details?.toString() ?? 'No details';

          appLog('Firebase Function Error [$errorCode]: $errorMessage',
              level: 'ERROR');
          appLog('Firebase Function Details: $errorDetails', level: 'ERROR');

          // Don't retry on permission-denied or auth errors
          if (isNonRetryableExceptionCode(errorCode)) {
            return null;
          }

          retries++;
          if (retries < maxRetries) {
            appLog('[QUIZ_SERVICE] Retrying after 2 seconds...',
                level: 'DEBUG');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      appLog('[QUIZ_SERVICE] All retries exhausted, returning null',
          level: 'WARN');
      return null;
    } catch (e, stackTrace) {
      appLog('Error getting book quiz: $e\n$stackTrace', level: 'ERROR');
      return null;
    }
  }

  /// Get cached quiz from Firestore
  Future<Map<String, dynamic>?> _getCachedQuiz(String bookId) async {
    try {
      appLog('[QUIZ_CACHE] Checking cache for bookId: $bookId', level: 'DEBUG');
      final doc = await _firestore.collection('book_quizzes').doc(bookId).get();
      appLog('[QUIZ_CACHE] Document exists: ${doc.exists}', level: 'DEBUG');

      if (doc.exists) {
        appLog('[QUIZ_CACHE] Returning cached quiz data', level: 'DEBUG');
        return doc.data();
      }

      return null;
    } catch (e) {
      appLog('Error fetching cached quiz: $e', level: 'ERROR');
      return null;
    }
  }

  /// Save quiz attempt result
  Future<void> saveQuizAttempt({
    required String userId,
    required String bookId,
    required List<int> userAnswers,
    required int score,
    required int totalQuestions,
  }) async {
    try {
      // (score / 0).round() throws (NaN has no int representation), which
      // would silently drop the whole write via the catch below instead of
      // recording anything. totalQuestions should never really be 0, but a
      // malformed/fallback quiz makes it a real possibility worth guarding.
      final percentage =
          totalQuestions > 0 ? (score / totalQuestions * 100).round() : 0;
      await _firestore.collection('quiz_attempts').add({
        'userId': userId,
        'bookId': bookId,
        'userAnswers': userAnswers,
        'score': score,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
        'completedAt': FieldValue.serverTimestamp(),
      });

      appLog('Quiz attempt saved for user $userId, book $bookId',
          level: 'INFO');
    } catch (e) {
      appLog('Error saving quiz attempt: $e', level: 'ERROR');
    }
  }

  /// Award points for quiz completion.
  ///
  /// [currentStreak] feeds AchievementService's streak multiplier (1.0x /
  /// 1.1x / 1.25x / 1.5x). Defaults to 0 (no bonus) for callers that don't
  /// have a streak on hand — previously every real call site hardcoded 0,
  /// which meant the multiplier could never actually apply to quiz points
  /// despite being fully implemented; book_quiz_screen.dart now passes the
  /// child's real streak instead.
  Future<void> awardQuizPoints({
    required String userId,
    required String bookId,
    required int points,
    required int percentage,
    int currentStreak = 0,
  }) async {
    try {
      await _achievementService.awardPoints(
        userId: userId,
        basePoints: points,
        reason: 'Book quiz ($percentage%) for $bookId',
        currentStreak: currentStreak,
      );

      appLog(
        'Awarded $points points to $userId for $percentage% on book quiz $bookId',
        level: 'INFO',
      );
    } catch (e) {
      appLog('Error awarding quiz points: $e', level: 'ERROR');
    }
  }
}
