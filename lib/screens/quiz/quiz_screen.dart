import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'quiz_result_screen.dart';
import '../../utils/page_transitions.dart';

class QuizScreen extends StatefulWidget {
  final String? bookId;
  final String? bookTitle;

  const QuizScreen({
    super.key,
    this.bookId,
    this.bookTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int currentQuestion = 0;
  List<int> selectedAnswers = []; // Store Likert scores (1-5)
  bool _hasShownIntro = false;
  DateTime? _quizStartTime;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Show intro dialog after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownIntro) {
        _showQuizIntro();
      }
    });
  }

  void _showQuizIntro() {
    setState(() {
      _hasShownIntro = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.all(30),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quiz icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.quiz,
                  size: 50,
                  color: Color(0xFF8E44AD),
                ),
              ),
              const SizedBox(height: 25),

              // Title
              Text(
                widget.bookTitle != null ? 'Book Quiz!' : 'Personality Quiz!',
                style: AppTheme.heading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8E44AD),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              // Description
              Text(
                widget.bookTitle != null
                    ? 'Let\'s see how well you know "${widget.bookTitle}"!'
                    : 'Help us understand what you like so we can recommend the perfect books for you!',
                style: AppTheme.body.copyWith(
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Info items
              _buildInfoItem(Icons.timer_outlined, '10 questions'),
              const SizedBox(height: 10),
              _buildInfoItem(Icons.psychology_outlined, 'About 2-3 minutes'),
              const SizedBox(height: 10),
              _buildInfoItem(
                  Icons.sentiment_very_satisfied, 'No wrong answers!'),
              const SizedBox(height: 30),

              // Let's go button
              PrimaryButton(
                text: 'Let\'s Go!',
                onPressed: () {
                  setState(() {
                    _quizStartTime = DateTime.now();
                  });
                  Navigator.of(context).pop();
                },
                icon: Icons.arrow_forward,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8E44AD)),
        const SizedBox(width: 10),
        // Flexible + ellipsis: overflowed inside the intro dialog's
        // IntrinsicWidth column on a narrow phone (found while scanning
        // for UI issues).
        Flexible(
          child: Text(
            text,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // BFI-C (Big Five Inventory for Children) - 10 Questions with Likert Scale
  // 2 questions per OCEAN dimension for scientifically valid personality assessment
  //
  // Rewritten for the 4-7 early-childhood target audience (see
  // docs/early-childhood-audit.md finding #1, and SECURITY.md): the
  // original wording wasn't just hard to read, it was abstract in a way
  // a 4-7-year-old can't self-assess ("I keep my things neat and tidy"
  // requires a stable self-concept about tidiness). Every question below
  // is instead a concrete, everyday thing this age group actually does
  // or has done, kept deliberately generic (no single specific toy/
  // object named) so it's answerable by any child regardless of what
  // they happen to own or play, AND answerable by a parent who knows
  // their child but wasn't necessarily watching in that exact moment.
  // dimension/isReversed are unchanged — personality_scoring.dart scores
  // off those, never the question text itself.
  final List<Map<String, dynamic>> questions = [
    // OPENNESS #1
    {
      'question': 'I like trying games I\'ve never played before',
      'dimension': 'O', // Openness
      'isReversed': false,
    },
    // CONSCIENTIOUSNESS #1
    {
      'question': 'When I start a puzzle or drawing, I finish it',
      'dimension': 'C', // Conscientiousness
      'isReversed': false,
    },
    // EXTRAVERSION #1
    {
      'question': 'I have fun playing with lots of friends at once',
      'dimension': 'E', // Extraversion
      'isReversed': false,
    },
    // AGREEABLENESS #1
    {
      'question': 'I help pick things up when someone drops them',
      'dimension': 'A', // Agreeableness
      'isReversed': false,
    },
    // NEUROTICISM #1 (reversed for Emotional Stability)
    {
      'question': 'When something doesn\'t go the way I want, I stay calm and try again',
      'dimension': 'N', // Neuroticism (Emotional Stability)
      'isReversed': false, // Direct scoring for stability
    },
    // OPENNESS #2
    {
      'question': 'I like to pretend and make up stories',
      'dimension': 'O',
      'isReversed': false,
    },
    // CONSCIENTIOUSNESS #2
    {
      'question': 'I like to pick up my toys when I\'m done playing',
      'dimension': 'C',
      'isReversed': false,
    },
    // EXTRAVERSION #2
    {
      'question': 'I like showing everyone what I made or did',
      'dimension': 'E',
      'isReversed': false,
    },
    // AGREEABLENESS #2
    {
      'question': 'I share my toys with my friends',
      'dimension': 'A',
      'isReversed': false,
    },
    // NEUROTICISM #2 (reversed for Emotional Stability)
    {
      'question': 'I smile and laugh a lot during the day',
      'dimension': 'N',
      'isReversed': false, // Direct scoring for stability
    },
  ];

  Widget _buildScaleOption({
    required String emoji,
    required String label,
    required int score,
  }) {
    final hasSelectedAnswer = selectedAnswers.length > currentQuestion;
    final isSelected =
        hasSelectedAnswer && selectedAnswers[currentQuestion] == score;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectAnswer(score),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryPurpleOpaque10
                : AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryPurple
                  : AppTheme.textGray.withValues(alpha: 0.3),
              width: isSelected ? 3 : 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.primaryPurple
                      : AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAnswer(int likertScore) {
    setState(() {
      if (selectedAnswers.length > currentQuestion) {
        selectedAnswers[currentQuestion] = likertScore;
      } else {
        selectedAnswers.add(likertScore);
      }
    });
  }

  void _nextQuestion() {
    if (selectedAnswers.length > currentQuestion) {
      if (currentQuestion < questions.length - 1) {
        setState(() {
          currentQuestion++;
        });
      } else {
        // Quiz completed - navigate to results
        _completeQuiz();
      }
    }
  }

  void _previousQuestion() {
    if (currentQuestion > 0) {
      setState(() {
        currentQuestion--;
      });
    }
  }

  void _completeQuiz() {
    // Calculate personality traits and elapsed time
    if (_quizStartTime != null) {
      _elapsedTime = DateTime.now().difference(_quizStartTime!);
    }

    Navigator.pushReplacement(
      context,
      FadeRoute(
        page: QuizResultScreen(
          answers: selectedAnswers,
          questions: questions,
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          quizDuration: _elapsedTime,
          totalQuestions: questions.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = questions[currentQuestion];

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        title: Text(
          'Find Your Perfect Books',
          style: AppTheme.heading.copyWith(color: AppTheme.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryPurpleOpaque10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible + ellipsis: same real overflow found and fixed
                // in book_quiz_screen.dart's identical progress header.
                Flexible(
                  child: Text(
                    'Question ${currentQuestion + 1} of ${questions.length}',
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${((currentQuestion / questions.length) * 100).round()}% Complete',
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
                  // Question with illustration beside it
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/illustrations/question page_wormies.svg',
                        height: 60,
                        width: 60,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          currentQ['question'],
                          style: AppTheme.heading,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Simple 3-point scale (No / Sometimes / Yes!, each with
                  // a face) instead of the old 5-point scale (5 small
                  // circles labeled 1-5, above separate text labels like
                  // "A little like me" / "Mostly like me") — too many
                  // fine-grained, abstractly-worded options for a
                  // 4-7-year-old to meaningfully tell apart. Mapped onto
                  // the same 1-5 score range personality_scoring.dart
                  // already expects (1, 3, 5 — skipping 2 and 4), so no
                  // scoring-logic change was needed. See SECURITY.md.
                  Row(
                    children: [
                      _buildScaleOption(
                          emoji: '🙁', label: 'No', score: 1),
                      const SizedBox(width: 12),
                      _buildScaleOption(
                          emoji: '😐', label: 'Sometimes', score: 3),
                      const SizedBox(width: 12),
                      _buildScaleOption(
                          emoji: '😄', label: 'Yes!', score: 5),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(
              children: [
                if (currentQuestion > 0)
                  Expanded(
                    child: SecondaryButton(
                      text: 'Previous',
                      onPressed: _previousQuestion,
                    ),
                  ),
                if (currentQuestion > 0) const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    text: currentQuestion == questions.length - 1
                        ? 'Complete Quiz'
                        : 'Next',
                    onPressed: _nextQuestion,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
