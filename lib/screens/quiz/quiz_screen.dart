import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'quiz_result_screen.dart';
import '../../widgets/pressable_card.dart';

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

  // Quiz questions mapped to Big Five traits (child-friendly)
  // Each answer has 3 traits for balanced coverage across all 5 domains
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'When something is tricky or hard, what do you do?',
      'options': [
        {
          'text': 'I think about it and make a plan',
          'traits': ['organized', 'responsible', 'focused']
        },
        {
          'text': 'I come up with a cool new idea',
          'traits': ['creative', 'imaginative', 'inventive']
        },
        {
          'text': 'I ask my friends or family for help',
          'traits': ['social', 'cooperative', 'friendly']
        },
        {
          'text': 'I stay calm and keep trying',
          'traits': ['calm', 'confident', 'resilient']
        },
        {
          'text': 'I try to help other kids too',
          'traits': ['kind', 'caring', 'helpful']
        },
      ]
    },
    {
      'question': 'What sounds like the most fun?',
      'options': [
        {
          'text': 'Going to new places or trying new stuff',
          'traits': ['curious', 'adventurous', 'imaginative']
        },
        {
          'text': 'Making a cool project or plan',
          'traits': ['organized', 'focused', 'hardworking']
        },
        {
          'text': 'Playing and laughing with my friends',
          'traits': ['social', 'outgoing', 'playful']
        },
        {
          'text': 'Chilling with a good book or show',
          'traits': ['calm', 'relaxed', 'easygoing']
        },
        {
          'text': 'Helping someone or making them smile',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'When you try something new, how do you feel?',
      'options': [
        {
          'text': 'Excited! I love trying new things',
          'traits': ['adventurous', 'curious', 'brave']
        },
        {
          'text': 'I like to think about it first',
          'traits': ['careful', 'organized', 'responsible']
        },
        {
          'text': 'More fun if my friends try it with me',
          'traits': ['social', 'friendly', 'cooperative']
        },
        {
          'text': 'I stay calm and do my best',
          'traits': ['calm', 'confident', 'positive']
        },
        {
          'text': 'I like to show others how to do it',
          'traits': ['helpful', 'sharing', 'kind']
        },
      ]
    },
    {
      'question': 'What do you love most about stories?',
      'options': [
        {
          'text': 'When there\'s magic and cool make-believe stuff',
          'traits': ['imaginative', 'creative', 'curious']
        },
        {
          'text': 'When characters solve hard problems',
          'traits': ['focused', 'persistent', 'organized']
        },
        {
          'text': 'When friends go on adventures together',
          'traits': ['friendly', 'social', 'cooperative']
        },
        {
          'text': 'When heroes are brave and don\'t give up',
          'traits': ['brave', 'confident', 'resilient']
        },
        {
          'text': 'When characters are nice and care about others',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'If you had free time after school, what would you do?',
      'options': [
        {
          'text': 'Make or draw something cool',
          'traits': ['creative', 'imaginative', 'artistic']
        },
        {
          'text': 'Work on a project or learn new stuff',
          'traits': ['hardworking', 'focused', 'persistent']
        },
        {
          'text': 'Hang out and play with my friends',
          'traits': ['social', 'outgoing', 'talkative']
        },
        {
          'text': 'Relax with a book or just chill',
          'traits': ['calm', 'relaxed', 'easygoing']
        },
        {
          'text': 'Help someone or take care of people',
          'traits': ['helpful', 'kind', 'caring']
        },
      ]
    },
    {
      'question': 'When you help someone, what do you usually do?',
      'options': [
        {
          'text': 'I think of cool new ways to fix things',
          'traits': ['creative', 'inventive', 'curious']
        },
        {
          'text': 'I teach them or show them how to do it',
          'traits': ['responsible', 'organized', 'focused']
        },
        {
          'text': 'I cheer them up and make them laugh',
          'traits': ['enthusiastic', 'playful', 'energetic']
        },
        {
          'text': 'I stay calm and help them feel better',
          'traits': ['calm', 'positive', 'confident']
        },
        {
          'text': 'I\'m nice to them and take good care of them',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'When you feel sad, what makes you feel better?',
      'options': [
        {
          'text': 'Drawing, writing, or pretending',
          'traits': ['creative', 'artistic', 'imaginative']
        },
        {
          'text': 'Thinking about it and making a plan',
          'traits': ['focused', 'organized', 'careful']
        },
        {
          'text': 'Talking to someone I trust',
          'traits': ['social', 'cooperative', 'sharing']
        },
        {
          'text': 'Taking deep breaths and staying calm',
          'traits': ['calm', 'resilient', 'positive']
        },
        {
          'text': 'Helping other kids who feel sad too',
          'traits': ['caring', 'kind', 'helpful']
        },
      ]
    },
    {
      'question': 'Which one sounds the most like you?',
      'options': [
        {
          'text': 'I love learning and finding out new stuff',
          'traits': ['curious', 'adventurous', 'imaginative']
        },
        {
          'text': 'I work hard and always finish things',
          'traits': ['hardworking', 'persistent', 'focused']
        },
        {
          'text': 'I love playing and hanging with my friends',
          'traits': ['playful', 'social', 'outgoing']
        },
        {
          'text': 'I stay happy even when stuff is hard',
          'traits': ['positive', 'resilient', 'confident']
        },
        {
          'text': 'I like helping and taking care of people',
          'traits': ['kind', 'caring', 'helpful']
        },
      ]
    },
    {
      'question': 'What kind of books or shows do you like best?',
      'options': [
        {
          'text': 'Ones with magic and make-believe',
          'traits': ['imaginative', 'creative', 'curious']
        },
        {
          'text': 'Ones that teach me cool new things',
          'traits': ['focused', 'persistent', 'organized']
        },
        {
          'text': 'Fast and exciting adventures',
          'traits': ['enthusiastic', 'energetic', 'adventurous']
        },
        {
          'text': 'Calm, pretty, or peaceful ones',
          'traits': ['calm', 'easygoing', 'relaxed']
        },
        {
          'text': 'Ones about friends helping each other',
          'traits': ['kind', 'cooperative', 'gentle']
        },
      ]
    },
    {
      'question': 'When you\'re having fun, what do you enjoy most?',
      'options': [
        {
          'text': 'Pretending and making up stories',
          'traits': ['imaginative', 'creative', 'inventive']
        },
        {
          'text': 'Solving puzzles or figuring things out',
          'traits': ['persistent', 'organized', 'focused']
        },
        {
          'text': 'Running, jumping, or being active',
          'traits': ['energetic', 'outgoing', 'enthusiastic']
        },
        {
          'text': 'Relaxing and just enjoying myself',
          'traits': ['calm', 'easygoing', 'positive']
        },
        {
          'text': 'Hanging out and sharing with friends',
          'traits': ['social', 'friendly', 'sharing']
        },
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
    // Calculate personality traits
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          answers: selectedAnswers,
          questions: questions,
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
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
