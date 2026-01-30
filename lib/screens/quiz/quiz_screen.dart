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
        Text(
          text,
          style: AppTheme.bodyMedium.copyWith(
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // BFI-C (Big Five Inventory for Children) - 10 Questions with Likert Scale
  // 2 questions per OCEAN dimension for scientifically valid personality assessment
  // Likert Scale: 1 = Not like me at all, 2 = A little like me, 3 = Sometimes like me, 
  //               4 = Mostly like me, 5 = Very much like me
  final List<Map<String, dynamic>> questions = [
    // OPENNESS #1
    {
      'question': 'I like to learn about new things',
      'dimension': 'O', // Openness
      'isReversed': false,
    },
    // CONSCIENTIOUSNESS #1
    {
      'question': 'I finish tasks that I start',
      'dimension': 'C', // Conscientiousness
      'isReversed': false,
    },
    // EXTRAVERSION #1
    {
      'question': 'I enjoy playing with lots of friends',
      'dimension': 'E', // Extraversion
      'isReversed': false,
    },
    // AGREEABLENESS #1
    {
      'question': 'I try to help others when they need it',
      'dimension': 'A', // Agreeableness
      'isReversed': false,
    },
    // NEUROTICISM #1 (reversed for Emotional Stability)
    {
      'question': 'I stay calm when things don\'t go my way',
      'dimension': 'N', // Neuroticism (Emotional Stability)
      'isReversed': false, // Direct scoring for stability
    },
    // OPENNESS #2
    {
      'question': 'I use my imagination a lot',
      'dimension': 'O',
      'isReversed': false,
    },
    // CONSCIENTIOUSNESS #2
    {
      'question': 'I keep my things neat and tidy',
      'dimension': 'C',
      'isReversed': false,
    },
    // EXTRAVERSION #2
    {
      'question': 'I like being the center of attention',
      'dimension': 'E',
      'isReversed': false,
    },
    // AGREEABLENESS #2
    {
      'question': 'I share my toys and books with friends',
      'dimension': 'A',
      'isReversed': false,
    },
    // NEUROTICISM #2 (reversed for Emotional Stability)
    {
      'question': 'I feel happy most of the time',
      'dimension': 'N',
      'isReversed': false, // Direct scoring for stability
    },
  ];

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
    final hasSelectedAnswer = selectedAnswers.length > currentQuestion;

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
                Text(
                  'Question ${currentQuestion + 1} of ${questions.length}',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.bold),
                ),
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

                  // Likert Scale Options (1-5)
                  Column(
                    children: [
                      // Scale labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Not like\nme at all',
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'A little\nlike me',
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Sometimes\nlike me',
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Mostly\nlike me',
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Very much\nlike me',
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Likert buttons (1-5)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final score = index + 1; // 1 to 5
                          final isSelected = hasSelectedAnswer &&
                              selectedAnswers[currentQuestion] == score;

                          return GestureDetector(
                            onTap: () => _selectAnswer(score),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : AppTheme.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryPurple
                                      : AppTheme.textGray.withValues(alpha: 0.3),
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryPurple
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: AppTheme.heading.copyWith(
                                    fontSize: 24,
                                    color: isSelected
                                        ? AppTheme.white
                                        : AppTheme.textGray,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
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
