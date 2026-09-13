import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';
import 'points_engine_client.dart';

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
        _injectedPointsEngine = null;

  /// Test-only: an independent (non-singleton) instance wrapping fakes.
  /// `functions` has no fake/mock package available for this Firebase
  /// plugin (unlike auth/firestore/storage), so getBookQuiz's actual
  /// httpsCallable-calling retry loop stays untested at the unit level —
  /// see quiz_generator_service_test.dart and SECURITY.md for what IS
  /// covered instead (the pure decision functions above, plus every
  /// Firestore/points-engine-touching method).
  @visibleForTesting
  QuizGeneratorService.withInstances({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
    PointsEngineClient? pointsEngine,
  })  : _firestore = firestore,
        _injectedFunctions = functions,
        _injectedPointsEngine = pointsEngine;

  // Resolved lazily (not in the constructor) so building a
  // QuizGeneratorService.withInstances() for a test that never reaches
  // getBookQuiz's Cloud Function call doesn't require a real Firebase app
  // to exist just to satisfy this field.
  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions get _functions => _injectedFunctions ?? FirebaseFunctions.instance;
  final FirebaseFirestore _firestore;
  final PointsEngineClient? _injectedPointsEngine;
  PointsEngineClient get _pointsEngine =>
      _injectedPointsEngine ?? PointsEngineClient();

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

  /// Save quiz attempt result. Returns the created doc's ID (used by
  /// [awardQuizPoints], which needs a real attemptId to award against —
  /// see that method's doc comment) or null if the write failed.
  Future<String?> saveQuizAttempt({
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
      final doc = await _firestore.collection('quiz_attempts').add({
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
      return doc.id;
    } catch (e) {
      appLog('Error saving quiz attempt: $e', level: 'ERROR');
      return null;
    }
  }

  /// Award points for quiz completion.
  ///
  /// Points are no longer computed here or trusted from the caller — the
  /// Cloud Function behind this re-reads the real `quiz_attempts` doc for
  /// [attemptId] and computes the tier from its actual stored percentage,
  /// closing what used to be a bare, unverified point-injection call. See
  /// SECURITY.md's "Point-award security migration".
  Future<void> awardQuizPoints({required String attemptId}) async {
    try {
      final result =
          await _pointsEngine.awardQuizPoints(attemptId: attemptId);
      appLog(
        'Awarded ${result['pointsEarned']} points for quiz attempt $attemptId',
        level: 'INFO',
      );
    } catch (e) {
      if (isFunctionsErrorCode(e, 'already-exists')) return; // already awarded
      appLog('Error awarding quiz points: $e', level: 'ERROR');
    }
  }
}
