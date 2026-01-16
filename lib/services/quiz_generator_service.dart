import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger.dart';

class QuizGeneratorService {
  static final QuizGeneratorService _instance = QuizGeneratorService._internal();
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
      print('[QUIZ_SERVICE] Fetching quiz for book: $bookId');

      // Check cache first
      final cachedQuiz = await _getCachedQuiz(bookId);
      if (cachedQuiz != null) {
        appLog('Using cached quiz for book: $bookId', level: 'INFO');
        print('[QUIZ_SERVICE] Using cached quiz');
        return cachedQuiz;
      }

      print('[QUIZ_SERVICE] No cached quiz, calling Cloud Function...');

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
          print('[QUIZ_SERVICE] Attempt ${retries + 1}/$maxRetries: Calling Cloud Function with bookId: $bookId');
          final result = await callable.call({'bookId': bookId});
          
          print('[QUIZ_SERVICE] Cloud Function response received: ${result.data.runtimeType}');
          appLog('Cloud Function response: ${result.data}', level: 'DEBUG');
          
          if (result.data is Map && result.data['success'] == true) {
            final quizData = result.data['quiz'] as Map<String, dynamic>;
            print('[QUIZ_SERVICE] Quiz generated successfully, ${quizData['questions']?.length ?? 0} questions');
            appLog('Quiz generated successfully', level: 'INFO');
            return quizData;
          }

          final errorMsg = result.data is Map 
            ? (result.data['message'] ?? result.data['error'] ?? 'Unknown error')
            : 'Invalid response format: ${result.data}';
          print('[QUIZ_SERVICE] Quiz generation failed: $errorMsg');
          appLog('Quiz generation failed: $errorMsg', level: 'ERROR');
          
          // Don't retry on invalid-argument or not-found errors
          if (result.data is Map && 
              (result.data['code'] == 'invalid-argument' || result.data['code'] == 'not-found')) {
            print('[QUIZ_SERVICE] Non-retryable error, returning null');
            return null;
          }
          
          retries++;
          if (retries < maxRetries) {
            print('[QUIZ_SERVICE] Retrying after 2 second delay...');
            await Future.delayed(const Duration(seconds: 2));
          }
        } on FirebaseFunctionsException catch (e) {
          // Extract detailed error message
          final errorMessage = e.message ?? 'Unknown error';
          final errorCode = e.code;
          final errorDetails = e.details?.toString() ?? 'No details';
          
          print('[QUIZ_SERVICE] FirebaseFunctionsException [$errorCode]: $errorMessage');
          print('[QUIZ_SERVICE] Exception details: $errorDetails');
          appLog('Firebase Function Error [$errorCode]: $errorMessage', level: 'ERROR');
          appLog('Firebase Function Details: $errorDetails', level: 'ERROR');
          
          // Don't retry on permission-denied or auth errors
          if (errorCode == 'permission-denied' || errorCode == 'unauthenticated') {
            print('[QUIZ_SERVICE] Auth error, not retrying');
            return null;
          }
          
          retries++;
          if (retries < maxRetries) {
            print('[QUIZ_SERVICE] Retrying after 2 second delay...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      
      print('[QUIZ_SERVICE] All retries exhausted, returning null');
      return null;

    } catch (e, stackTrace) {
      print('[QUIZ_SERVICE] Unexpected error: $e');
      print('[QUIZ_SERVICE] Stack trace: $stackTrace');
      appLog('Error getting book quiz: $e\n$stackTrace', level: 'ERROR');
      return null;
    }
  }

  /// Get cached quiz from Firestore
  Future<Map<String, dynamic>?> _getCachedQuiz(String bookId) async {
    try {
      print('[QUIZ_CACHE] Checking cache for bookId: $bookId');
      final doc = await _firestore.collection('book_quizzes').doc(bookId).get();
      print('[QUIZ_CACHE] Document exists: ${doc.exists}');
      
      if (doc.exists) {
        print('[QUIZ_CACHE] Document data: ${doc.data()}');
        return doc.data();
      }
      
      print('[QUIZ_CACHE] No cached quiz found');
      return null;
    } catch (e) {
      print('[QUIZ_CACHE] Error: $e');
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

      appLog('Quiz attempt saved for user $userId, book $bookId', level: 'INFO');
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
      await _firestore.collection('users').doc(userId).set({
        'totalAchievementPoints': FieldValue.increment(points),
        'allTimePoints': FieldValue.increment(points),
      }, SetOptions(merge: true));

      appLog(
        'Awarded $points points to $userId for $percentage% on book quiz $bookId',
        level: 'INFO',
      );
    } catch (e) {
      appLog('Error awarding quiz points: $e', level: 'ERROR');
    }
  }
}