import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger.dart';
import '../../services/quiz_generator_service.dart';
import '../../services/weekly_challenge_service.dart';
import '../../services/feedback_service.dart';
import '../../widgets/app_button.dart';
import '../../theme/app_theme.dart';
import 'book_quiz_celebration_screen.dart';

class BookQuizScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  /// Test-only overrides — QuizGeneratorService/WeeklyChallengeService are
  /// singletons with no other seam, so a widget test needs a way to pass
  /// fake-backed instances in. Both default to the real singleton, so
  /// production behavior (and every other caller of this screen) is
  /// unchanged.
  @visibleForTesting
  final QuizGeneratorService? quizService;
  @visibleForTesting
  final WeeklyChallengeService? weeklyChallengeService;

  const BookQuizScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.quizService,
    this.weeklyChallengeService,
  });

  @override
  State<BookQuizScreen> createState() => _BookQuizScreenState();
}

class _BookQuizScreenState extends State<BookQuizScreen>
    with SingleTickerProviderStateMixin {
  late final QuizGeneratorService _quizService;

  bool _isLoading = true;
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  DateTime? _quizStartTime;
  Duration _quizDuration = Duration.zero;

  // Read-aloud (early-childhood audit finding #3, SECURITY.md): a
  // pre-reader or emerging reader couldn't take this quiz independently
  // at all before — the reading screen has had TTS since day one, this
  // screen had none. Manual button only, not autoplay, to match the
  // reading screen's existing convention rather than introduce a new one.
  late FlutterTts _flutterTts;
  bool _isTtsInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _quizService = widget.quizService ?? QuizGeneratorService();
    _initializeTts();
    _loadQuiz();
  }

  @override
  void dispose() {
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    super.dispose();
  }

  // Mirrors PdfReadingScreenSyncfusion's _initializeTts — same
  // error-tolerant shape (every failure path still ends with
  // _isTtsInitialized = true so the button doesn't stay permanently
  // disabled over a recoverable settings failure).
  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();

      _flutterTts.setErrorHandler((msg) {
        appLog('[QUIZ_TTS] Error: $msg', level: 'ERROR');
        if (mounted) setState(() => _isPlaying = false);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlaying = false);
      });

      try {
        await _flutterTts.setLanguage('en-US');
      } catch (e) {
        appLog('[QUIZ_TTS] Language setting failed, trying default: $e',
            level: 'WARN');
      }
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      if (mounted) setState(() => _isTtsInitialized = true);
    } catch (e) {
      appLog('[QUIZ_TTS] Initialization error: $e', level: 'ERROR');
      if (mounted) setState(() => _isTtsInitialized = true);
    }
  }

  Future<void> _toggleReadAloud() async {
    if (!_isTtsInitialized) return;
    if (_isPlaying) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List;
    final buffer = StringBuffer('Question: ${question['question']}. ');
    for (var i = 0; i < options.length; i++) {
      buffer.write('Option ${String.fromCharCode(65 + i)}: ${options[i]}. ');
    }

    try {
      await _flutterTts.stop();
      if (!mounted) return;
      setState(() => _isPlaying = true);
      final result = await _flutterTts.speak(buffer.toString());
      if (result == 0 && mounted) {
        setState(() => _isPlaying = false);
      }
    } catch (e) {
      appLog('[QUIZ_TTS] Speak error: $e', level: 'ERROR');
      if (mounted) setState(() => _isPlaying = false);
    }
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
        appLog(
          '[QUIZ] Quiz data is null or missing questions for bookId=${widget.bookId}. quizData=$quizData',
          level: 'WARN',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quiz not available for this book yet. Please try again in a moment.',
            ),
            backgroundColor: AppTheme.warningOrange,
            duration: Duration(seconds: 4),
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
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    _stopReadAloud();
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      FeedbackService.instance.playTap();
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _stopReadAloud();
      setState(() => _currentQuestionIndex--);
      FeedbackService.instance.playTap();
    }
  }

  void _stopReadAloud() {
    if (_isPlaying) {
      _flutterTts.stop();
      setState(() => _isPlaying = false);
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
      pointsEarned = 5; // 90-100%: 5 points
    } else if (percentage >= 70) {
      pointsEarned = 3; // 70-89%: 3 points
    } else if (percentage >= 50) {
      pointsEarned = 1; // 50-69%: 1 point
    }
    // Below 50%: 0 points

    // Save quiz attempt and award points. Read now, before any awaits,
    // since `context` shouldn't be touched again once this method has
    // yielded (the widget may be unmounted by then).
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId != null) {
      final attemptId = await _quizService.saveQuizAttempt(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        userAnswers: _userAnswers.cast<int>(),
        score: score,
        totalQuestions: _questions.length,
      );

      // Weekly challenge: count book quizzes (and refresh progress if current
      // weekly challenge is quiz-based).
      await (widget.weeklyChallengeService ?? WeeklyChallengeService())
          .trackQuizCompletion(
        userId: authProvider.userId!,
        score: percentage.round().clamp(0, 100),
      );

      // Award points if user scored 50% or higher. pointsEarned above is
      // only what's *displayed* on the celebration screen next — the
      // actual credited amount is computed server-side from the real
      // quiz_attempts doc just saved, not trusted from this client. See
      // SECURITY.md's "Point-award security migration".
      if (pointsEarned > 0 && attemptId != null) {
        await _quizService.awardQuizPoints(attemptId: attemptId);
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
        actions: [
          if (!_isLoading && _questions.isNotEmpty)
            IconButton(
              icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up,
                  color: AppTheme.white),
              onPressed: _toggleReadAloud,
              tooltip: 'Read question aloud',
            ),
        ],
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
              // Flexible + ellipsis: a real, always-reproducible overflow
              // at narrow phone widths (found while scanning for UI
              // issues) — neither Text here had any flex handling.
              Flexible(
                child: Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
