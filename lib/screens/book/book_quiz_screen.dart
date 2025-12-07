import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/quiz_generator_service.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

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

class _BookQuizScreenState extends State<BookQuizScreen> {
  final QuizGeneratorService _quizService = QuizGeneratorService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _quizData;
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  bool _quizCompleted = false;
  int _score = 0;

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
        _quizData = quizData;
        _questions = quizData['questions'] as List;
        _userAnswers = List.filled(_questions.length, null);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load quiz. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _selectAnswer(int answerIndex) {
    if (_quizCompleted) return;
    
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
    
    FeedbackService.instance.playTap();
  }

  void _nextQuestion() {
    if (_userAnswers[_currentQuestionIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer'),
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
    // Calculate score
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      if (_userAnswers[i] == question['correctAnswer']) {
        score++;
      }
    }

    setState(() {
      _score = score;
      _quizCompleted = true;
    });

    // Save quiz attempt
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId != null) {
      await _quizService.saveQuizAttempt(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        userAnswers: _userAnswers.cast<int>(),
        score: score,
        totalQuestions: _questions.length,
      );
    }

    FeedbackService.instance.playSuccess();
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
          : _quizCompleted
              ? _buildResultsScreen()
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
                              : AppTheme.textGray.withOpacity(0.3),
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
                                    : AppTheme.textGray.withOpacity(0.5),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: AppTheme.body.copyWith(
                                  color: isSelected ? AppTheme.white : AppTheme.textGray,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              options[index],
                              style: AppTheme.body.copyWith(
                                color: isSelected ? AppTheme.primaryPurple : AppTheme.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            boxShadow: [
              BoxShadow(
                color: AppTheme.blackOpaque20.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousQuestion,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryPurple),
                    ),
                    child: Text(
                      'Previous',
                      style: AppTheme.body.copyWith(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _currentQuestionIndex == _questions.length - 1
                        ? 'Submit Quiz'
                        : 'Next',
                    style: AppTheme.buttonText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_score / _questions.length * 100).round();
    final passed = percentage >= 60;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              passed ? '🎉 Great Job!' : '📚 Keep Learning!',
              style: AppTheme.logoSmall,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurpleOpaque10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '$_score / ${_questions.length}',
                    style: AppTheme.logoLarge.copyWith(
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage% Correct',
                    style: AppTheme.heading,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              passed
                  ? 'You have a great understanding of this book!'
                  : 'Try reading the book again to improve your score!',
              style: AppTheme.body,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              ),
              child: Text(
                'Done',
                style: AppTheme.buttonText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
