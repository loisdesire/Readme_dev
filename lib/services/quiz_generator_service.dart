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
  Future<Map<String, dynamic>?> getBookQuiz(String bookId) async {
    try {
      appLog('Fetching quiz for book: $bookId', level: 'INFO');

      // Check cache first
      final cachedQuiz = await _getCachedQuiz(bookId);
      if (cachedQuiz != null) {
        appLog('Using cached quiz for book: $bookId', level: 'INFO');
        return cachedQuiz;
      }

      // Generate new quiz via Cloud Function
      appLog('Generating new quiz for book: $bookId', level: 'INFO');
      final callable = _functions.httpsCallable(
        'generateBookQuiz',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      final result = await callable.call({'bookId': bookId});
      
      if (result.data['success'] == true) {
        final quizData = result.data['quiz'] as Map<String, dynamic>;
        appLog('Quiz generated successfully', level: 'INFO');
        return quizData;
      }

      appLog('Quiz generation failed', level: 'ERROR');
      return null;

    } catch (e, stackTrace) {
      appLog('Error getting book quiz: $e\n$stackTrace', level: 'ERROR');
      return null;
    }
  }

  /// Get cached quiz from Firestore
  Future<Map<String, dynamic>?> _getCachedQuiz(String bookId) async {
    try {
      final doc = await _firestore.collection('book_quizzes').doc(bookId).get();
      
      if (doc.exists) {
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