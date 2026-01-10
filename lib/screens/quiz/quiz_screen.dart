import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'quiz_result_screen.dart';
import '../../widgets/pressable_card.dart';
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
  List<String> selectedAnswers = [];
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

  // Personality Quiz - Balanced questions for kids (no right/wrong answers)
  // Designed to reveal genuine preferences without leading questions
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'What do you like doing on the weekend?',
      'options': [
        {'text': 'Reading or drawing quietly', 'traits': ['calm', 'creative', 'imaginative']},
        {'text': 'Playing sports or running around', 'traits': ['energetic', 'active', 'enthusiastic']},
        {'text': 'Hanging out with lots of friends', 'traits': ['social', 'outgoing', 'friendly']},
        {'text': 'Building or making something', 'traits': ['focused', 'creative', 'hardworking']},
        {'text': 'Helping family with chores or projects', 'traits': ['helpful', 'responsible', 'kind']},
      ]
    },
    {
      'question': 'When you get a new book, what do you do?',
      'options': [
        {'text': 'Start reading it right away', 'traits': ['curious', 'enthusiastic', 'adventurous']},
        {'text': 'Look at the pictures first', 'traits': ['creative', 'imaginative', 'artistic']},
        {'text': 'Read it with a friend or family member', 'traits': ['social', 'sharing', 'cooperative']},
        {'text': 'Save it for a quiet time', 'traits': ['calm', 'organized', 'patient']},
        {'text': 'Check if it teaches something new', 'traits': ['curious', 'focused', 'inventive']},
      ]
    },
    {
      'question': 'If you could pick any activity, which sounds best?',
      'options': [
        {'text': 'Making up stories or pretend games', 'traits': ['imaginative', 'creative', 'playful']},
        {'text': 'Learning a new skill or hobby', 'traits': ['persistent', 'hardworking', 'focused']},
        {'text': 'Playing games with other kids', 'traits': ['social', 'cooperative', 'friendly']},
        {'text': 'Exploring nature or new places', 'traits': ['curious', 'adventurous', 'brave']},
        {'text': 'Relaxing and taking it easy', 'traits': ['calm', 'easygoing', 'relaxed']},
      ]
    },
    {
      'question': 'What kind of stories do you enjoy most?',
      'options': [
        {'text': 'Magical and fantasy adventures', 'traits': ['imaginative', 'curious', 'creative']},
        {'text': 'Mysteries that need solving', 'traits': ['focused', 'inventive', 'persistent']},
        {'text': 'Stories about friendship', 'traits': ['kind', 'caring', 'cooperative']},
        {'text': 'Action and exciting quests', 'traits': ['brave', 'enthusiastic', 'adventurous']},
        {'text': 'Funny and silly tales', 'traits': ['playful', 'positive', 'easygoing']},
      ]
    },
    {
      'question': 'How do you feel about trying new things?',
      'options': [
        {'text': 'I get excited to try new stuff!', 'traits': ['adventurous', 'curious', 'brave']},
        {'text': 'I like to watch others try it first', 'traits': ['careful', 'observant', 'thoughtful']},
        {'text': 'I prefer things I already know', 'traits': ['calm', 'content', 'reliable']},
        {'text': "It's more fun with friends", 'traits': ['social', 'cooperative', 'friendly']},
        {'text': 'I think about it a lot before deciding', 'traits': ['organized', 'careful', 'responsible']},
      ]
    },
    {
      'question': 'What do you do when you finish your homework?',
      'options': [
        {'text': 'Check it over to make sure it\'s right', 'traits': ['careful', 'organized', 'responsible']},
        {'text': 'Put it away and go play', 'traits': ['energetic', 'playful', 'spontaneous']},
        {'text': 'Show it to someone', 'traits': ['sharing', 'social', 'proud']},
        {'text': 'Read or do something creative', 'traits': ['creative', 'imaginative', 'focused']},
        {'text': 'Help a classmate with theirs', 'traits': ['helpful', 'kind', 'cooperative']},
      ]
    },
    {
      'question': 'When playing with others, what role do you usually take?',
      'options': [
        {'text': 'I come up with the game ideas', 'traits': ['creative', 'imaginative', 'inventive']},
        {'text': 'I help make sure everyone follows the rules', 'traits': ['organized', 'responsible', 'fair']},
        {'text': 'I make sure everyone is having fun', 'traits': ['kind', 'caring', 'thoughtful']},
        {'text': 'I like being in the action', 'traits': ['enthusiastic', 'energetic', 'brave']},
        {'text': 'I go along with what others want', 'traits': ['cooperative', 'easygoing', 'flexible']},
      ]
    },
    {
      'question': 'What makes you feel proud?',
      'options': [
        {'text': 'When I make something cool', 'traits': ['creative', 'artistic', 'inventive']},
        {'text': 'When I finish a hard task', 'traits': ['persistent', 'hardworking', 'focused']},
        {'text': 'When I help someone', 'traits': ['kind', 'caring', 'helpful']},
        {'text': 'When I try something brave', 'traits': ['brave', 'confident', 'adventurous']},
        {'text': 'When I make people laugh', 'traits': ['playful', 'positive', 'social']},
      ]
    },
    {
      'question': 'Pick your favorite type of place to be:',
      'options': [
        {'text': 'A quiet library or cozy room', 'traits': ['calm', 'focused', 'content']},
        {'text': 'A playground or sports field', 'traits': ['active', 'energetic', 'playful']},
        {'text': 'A party or group event', 'traits': ['social', 'outgoing', 'enthusiastic']},
        {'text': 'An art room or maker space', 'traits': ['creative', 'imaginative', 'artistic']},
        {'text': 'Somewhere in nature', 'traits': ['curious', 'adventurous', 'calm']},
      ]
    },
    {
      'question': 'What describes you best?',
      'options': [
        {'text': 'I love learning new things', 'traits': ['curious', 'inventive', 'focused']},
        {'text': 'I care about how others feel', 'traits': ['kind', 'gentle', 'caring']},
        {'text': 'I stay positive even when things are hard', 'traits': ['resilient', 'confident', 'brave']},
        {'text': 'I like making plans and organizing', 'traits': ['organized', 'responsible', 'careful']},
        {'text': 'I enjoy being with lots of people', 'traits': ['social', 'friendly', 'outgoing']},
      ]
    },
  ];

  void _selectAnswer(int optionIndex) {
    setState(() {
      if (selectedAnswers.length > currentQuestion) {
        selectedAnswers[currentQuestion] =
            questions[currentQuestion]['options'][optionIndex]['text'];
      } else {
        selectedAnswers
            .add(questions[currentQuestion]['options'][optionIndex]['text']);
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
      FadeRoute(page: QuizResultScreen(
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
    final progress = (currentQuestion + 1) / questions.length;
    final currentQ = questions[currentQuestion];
    final hasSelectedAnswer = selectedAnswers.length > currentQuestion;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Back button and title
                  Row(
                    children: [
                      IconButton(
                        onPressed: currentQuestion > 0
                            ? _previousQuestion
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF8E44AD)),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'My Reading Quiz',
                              style: AppTheme.heading,
                              textAlign: TextAlign.center,
                            ),
                            if (widget.bookTitle != null)
                              Text(
                                widget.bookTitle!,
                                style: AppTheme.bodyMedium
                                    .copyWith(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${currentQuestion + 1} of ${questions.length}',
                        style: AppTheme.bodyMedium
                            .copyWith(color: const Color(0xFF666666)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E44AD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Illustration (SVG) - no background box, just like onboarding
                    SvgPicture.asset(
                      'assets/illustrations/question page_wormies.svg',
                      height: 150,
                      width: 150,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => const SizedBox(
                        height: 150,
                        width: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Question text
                    Text(
                      currentQ['question'],
                      style: AppTheme.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Answer options
                    ...List.generate(
                      currentQ['options'].length,
                      (index) {
                        final option = currentQ['options'][index];
                        final isSelected = hasSelectedAnswer &&
                            selectedAnswers[currentQuestion] == option['text'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: PressableCard(
                            onTap: () => _selectAnswer(index),
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryPurpleOpaque10
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8E44AD)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF8E44AD)
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFF8E44AD)
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      option['text'],
                                      style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF8E44AD)
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: PrimaryButton(
                text: currentQuestion < questions.length - 1
                    ? 'Next'
                    : 'Complete Quiz',
                onPressed: hasSelectedAnswer ? _nextQuestion : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

