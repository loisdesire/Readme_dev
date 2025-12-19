import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../providers/auth_provider.dart';
import '../../services/quiz_generator_service.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';

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

class _BookQuizScreenState extends State<BookQuizScreen> with SingleTickerProviderStateMixin {
  final QuizGeneratorService _quizService = QuizGeneratorService();
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;
  bool _quizCompleted = false;
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _pointsEarned = 0;
  List<int?> _userAnswers = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: AppConstants.confettiDuration);
    _animationController = AnimationController(
      duration: AppConstants.standardAnimationDuration,
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    _loadQuiz();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);

    final quizData = await _quizService.getBookQuiz(widget.bookId);
    
    if (quizData != null && quizData['questions'] != null) {
      setState(() {
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
    // Calculate score
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      if (_userAnswers[i] == question['correctAnswer']) {
        score++;
      }
    }

    // Calculate points earned (10 points per correct answer)
    final pointsEarned = score * 10;
    final percentage = (score / _questions.length * 100).round();

    setState(() {
      _score = score;
      _pointsEarned = pointsEarned;
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

    // Play celebration if passed
    if (percentage >= 60) {
      _confettiController.play();
      _animationController.forward();
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playTap();
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
                color: AppTheme.blackOpaque20.withValues(alpha: 0.5),
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
    final emoji = percentage >= 80 
        ? '🏆' 
        : percentage >= 60 
            ? '⭐' 
            : '📚';

    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      passed ? 'Quiz Complete!' : 'Quiz Complete',
                      style: AppTheme.heading.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Emoji with animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 120),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Score card
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryPurple.withValues(alpha: 0.1),
                            AppTheme.primaryPurple.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_score / ${_questions.length}',
                            style: AppTheme.logoLarge.copyWith(
                              color: AppTheme.primaryPurple,
                              fontSize: 56,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$percentage% Correct',
                            style: AppTheme.heading.copyWith(
                              color: AppTheme.black,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Points earned (if passed)
                  if (_pointsEarned > 0)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryPurple,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '+$_pointsEarned points earned!',
                          style: AppTheme.body.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Feedback message
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      passed
                          ? 'Excellent work! You really understood this book!'
                          : 'Keep practicing! Try reading the book again.',
                      style: AppTheme.body.copyWith(
                        fontSize: 18,
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppConstants.buttonHorizontalPadding,
                          vertical: AppConstants.buttonVerticalPadding,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.standardBorderRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: AppTheme.buttonText.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),

        // Confetti for passed quizzes
        if (passed)
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3.14 / 2,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.yellow,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.blue,
                Colors.green,
              ],
              numberOfParticles: 50,
              gravity: 0.2,
              emissionFrequency: 0.05,
              minimumSize: const Size(10, 10),
              maximumSize: const Size(20, 20),
            ),
          ),
      ],
    );
  }
}

