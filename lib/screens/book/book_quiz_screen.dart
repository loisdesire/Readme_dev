import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/quiz_generator_service.dart';
import '../../services/feedback_service.dart';
import '../../widgets/app_button.dart';
import '../../theme/app_theme.dart';
import 'book_quiz_celebration_screen.dart';

class BookQuizScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const BookQuizScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<BookQuizScreen> createState() => _BookQuizScreenState();
}

class _BookQuizScreenState extends State<BookQuizScreen>
    with SingleTickerProviderStateMixin {
  final QuizGeneratorService _quizService = QuizGeneratorService();

  bool _isLoading = true;
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  DateTime? _quizStartTime;
  Duration _quizDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);

    final quizData = await _quizService.getBookQuiz(widget.bookId);

    if (quizData != null && quizData['questions'] != null) {
      setState(() {
        _questions = quizData['questions'] as List;
        _userAnswers = List.filled(_questions.length, null);
        _isLoading = false;
        _quizStartTime = DateTime.now(); // Start timer when quiz loads
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load quiz. This might be due to network issues or the quiz generation service being unavailable. Please try again later.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });

    FeedbackService.instance.playTap();
  }

  void _nextQuestion() {
    if (_userAnswers[_currentQuestionIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer before continuing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      FeedbackService.instance.playTap();
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
      FeedbackService.instance.playTap();
    }
  }

  Future<void> _submitQuiz() async {
    // Calculate elapsed time
    if (_quizStartTime != null) {
      _quizDuration = DateTime.now().difference(_quizStartTime!);
    }

    // Calculate score
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      if (_userAnswers[i] == question['correctAnswer']) {
        score++;
      }
    }

    // Calculate percentage and points earned based on score
    final percentage = (score / _questions.length * 100).round();
    int pointsEarned = 0;

    // Award points based on performance
    if (percentage >= 90) {
      pointsEarned = 10; // 90-100%: 10 points
    } else if (percentage >= 70) {
      pointsEarned = 5; // 70-89%: 5 points
    } else if (percentage >= 50) {
      pointsEarned = 2; // 50-69%: 2 points
    }
    // Below 50%: 0 points

    // Save quiz attempt and award points
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId != null) {
      await _quizService.saveQuizAttempt(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        userAnswers: _userAnswers.cast<int>(),
        score: score,
        totalQuestions: _questions.length,
      );

      // Award points if user scored 50% or higher
      if (pointsEarned > 0) {
        await _quizService.awardQuizPoints(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          points: pointsEarned,
          percentage: percentage,
        );
      }
    }

    // Navigate to celebration screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookQuizCelebrationScreen(
            score: score,
            totalQuestions: _questions.length,
            percentage: percentage,
            pointsEarned: pointsEarned,
            quizDuration: _quizDuration,
            bookTitle: widget.bookTitle,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        title: Text(
          'Quiz: ${widget.bookTitle}',
          style: AppTheme.heading.copyWith(color: AppTheme.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildQuizScreen(),
    );
  }

  Widget _buildQuizScreen() {
    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List;
    final selectedAnswer = _userAnswers[_currentQuestionIndex];

    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryPurpleOpaque10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: AppTheme.body.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${((_currentQuestionIndex / _questions.length) * 100).round()}% Complete',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question
                Text(
                  question['question'],
                  style: AppTheme.heading,
                ),

                const SizedBox(height: 32),

                // Options
                ...List.generate(options.length, (index) {
                  final isSelected = selectedAnswer == index;

                  return GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryPurpleOpaque10
                            : AppTheme.lightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : AppTheme.textGray.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryPurple
                                  : AppTheme.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : AppTheme.textGray.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: AppTheme.body.copyWith(
                                  color: isSelected
                                      ? AppTheme.white
                                      : AppTheme.textGray,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              options[index],
                              style: AppTheme.body.copyWith(
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : AppTheme.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: SecondaryButton(
                    text: 'Previous',
                    onPressed: _previousQuestion,
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  text: _currentQuestionIndex == _questions.length - 1
                      ? 'Submit Quiz'
                      : 'Next',
                  onPressed: _nextQuestion,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
