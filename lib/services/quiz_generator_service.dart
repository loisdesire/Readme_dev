import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger.dart';
import 'achievement_service.dart';

class QuizGeneratorService {
  static final QuizGeneratorService _instance =
      QuizGeneratorService._internal();
  factory QuizGeneratorService() => _instance;
  QuizGeneratorService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

          final errorMsg = result.data is Map
              ? (result.data['message'] ??
                  result.data['error'] ??
                  'Unknown error')
              : 'Invalid response format: ${result.data}';
          appLog('Quiz generation failed: $errorMsg', level: 'ERROR');

          // Don't retry on invalid-argument or not-found errors
          if (result.data is Map &&
              (result.data['code'] == 'invalid-argument' ||
                  result.data['code'] == 'not-found')) {
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
          if (errorCode == 'permission-denied' ||
              errorCode == 'unauthenticated') {
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
      await _firestore.collection('quiz_attempts').add({
        'userId': userId,
        'bookId': bookId,
        'userAnswers': userAnswers,
        'score': score,
        'totalQuestions': totalQuestions,
        'percentage': (score / totalQuestions * 100).round(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      appLog('Quiz attempt saved for user $userId, book $bookId',
          level: 'INFO');
    } catch (e) {
      appLog('Error saving quiz attempt: $e', level: 'ERROR');
    }
  }

  /// Award points for quiz completion
  Future<void> awardQuizPoints({
    required String userId,
    required String bookId,
    required int points,
    required int percentage,
  }) async {
    try {
      await AchievementService().awardPoints(
        userId: userId,
        basePoints: points,
        reason: 'Book quiz ($percentage%) for $bookId',
        currentStreak: 0,
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
