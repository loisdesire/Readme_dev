import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Let\'s Go!',
                        style: AppTheme.buttonText
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
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
      'question': 'When you have a problem, what do you usually do?',
      'options': [
        {
          'text': 'Think carefully and make a plan',
          'traits': ['organized', 'responsible', 'focused']
        },
        {
          'text': 'Come up with a creative solution',
          'traits': ['creative', 'imaginative', 'inventive']
        },
        {
          'text': 'Ask friends or family to help me',
          'traits': ['social', 'cooperative', 'friendly']
        },
        {
          'text': 'Stay calm and work through it patiently',
          'traits': ['calm', 'confident', 'resilient']
        },
        {
          'text': 'Try to help others with their problems too',
          'traits': ['kind', 'caring', 'helpful']
        },
      ]
    },
    {
      'question': 'Which sounds most fun to you?',
      'options': [
        {
          'text': 'Exploring new places or trying new things',
          'traits': ['curious', 'adventurous', 'imaginative']
        },
        {
          'text': 'Organizing a project or making a plan',
          'traits': ['organized', 'focused', 'hardworking']
        },
        {
          'text': 'Playing and laughing with friends',
          'traits': ['social', 'outgoing', 'playful']
        },
        {
          'text': 'Relaxing with a good book or story',
          'traits': ['calm', 'relaxed', 'easygoing']
        },
        {
          'text': 'Helping someone or making them happy',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'How do you feel when you try something new?',
      'options': [
        {
          'text': 'Excited and ready to explore!',
          'traits': ['curious', 'adventurous', 'creative']
        },
        {
          'text': 'I want to plan it out first',
          'traits': ['careful', 'organized', 'responsible']
        },
        {
          'text': 'More excited if friends come with me',
          'traits': ['social', 'enthusiastic', 'outgoing']
        },
        {
          'text': 'Calm and patient, I\'ll try my best',
          'traits': ['calm', 'confident', 'brave']
        },
        {
          'text': 'I wonder if I can help others learn too',
          'traits': ['helpful', 'cooperative', 'sharing']
        },
      ]
    },
    {
      'question': 'What do you like most about stories?',
      'options': [
        {
          'text': 'The magical and imaginative parts',
          'traits': ['imaginative', 'creative', 'curious']
        },
        {
          'text': 'How the characters solve problems',
          'traits': ['focused', 'persistent', 'organized']
        },
        {
          'text': 'The friendships and adventures together',
          'traits': ['friendly', 'social', 'cooperative']
        },
        {
          'text': 'The brave heroes who stay strong',
          'traits': ['brave', 'confident', 'resilient']
        },
        {
          'text': 'When characters are kind and caring',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'If you had a free afternoon, what would you choose?',
      'options': [
        {
          'text': 'Make something creative or imaginative',
          'traits': ['creative', 'imaginative', 'artistic']
        },
        {
          'text': 'Work on a project or learn something new',
          'traits': ['hardworking', 'focused', 'persistent']
        },
        {
          'text': 'Hang out and play with friends',
          'traits': ['social', 'outgoing', 'talkative']
        },
        {
          'text': 'Relax quietly with a book or rest',
          'traits': ['calm', 'relaxed', 'easygoing']
        },
        {
          'text': 'Help someone or spend time caring for others',
          'traits': ['helpful', 'kind', 'caring']
        },
      ]
    },
    {
      'question': 'How do you like to help people?',
      'options': [
        {
          'text': 'By thinking of creative ways to solve problems',
          'traits': ['creative', 'inventive', 'curious']
        },
        {
          'text': 'By teaching them or showing them how',
          'traits': ['responsible', 'organized', 'focused']
        },
        {
          'text': 'By cheering them up and making them smile',
          'traits': ['enthusiastic', 'playful', 'energetic']
        },
        {
          'text': 'By staying calm and making them feel better',
          'traits': ['calm', 'positive', 'confident']
        },
        {
          'text': 'By being kind and taking care of them',
          'traits': ['kind', 'caring', 'gentle']
        },
      ]
    },
    {
      'question': 'When you feel sad or upset, what helps you most?',
      'options': [
        {
          'text': 'Drawing, writing, or using my imagination',
          'traits': ['creative', 'artistic', 'imaginative']
        },
        {
          'text': 'Thinking it through and making a plan',
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
          'text': 'Helping others who might feel sad too',
          'traits': ['caring', 'kind', 'helpful']
        },
      ]
    },
    {
      'question': 'Which one sounds most like you?',
      'options': [
        {
          'text': 'I love learning and discovering new things',
          'traits': ['curious', 'adventurous', 'imaginative']
        },
        {
          'text': 'I work hard and finish what I start',
          'traits': ['hardworking', 'persistent', 'focused']
        },
        {
          'text': 'I have fun playing and being with friends',
          'traits': ['playful', 'social', 'outgoing']
        },
        {
          'text': 'I stay positive even when things are hard',
          'traits': ['positive', 'resilient', 'confident']
        },
        {
          'text': 'I enjoy helping and caring for others',
          'traits': ['kind', 'caring', 'helpful']
        },
      ]
    },
    {
      'question': 'What kind of books or movies do you enjoy?',
      'options': [
        {
          'text': 'Creative, magical, or imaginative ones',
          'traits': ['imaginative', 'creative', 'curious']
        },
        {
          'text': 'Ones that teach me something interesting',
          'traits': ['focused', 'persistent', 'organized']
        },
        {
          'text': 'Fast-paced and exciting adventures',
          'traits': ['enthusiastic', 'energetic', 'adventurous']
        },
        {
          'text': 'Calm, beautiful, or peaceful ones',
          'traits': ['calm', 'easygoing', 'relaxed']
        },
        {
          'text': 'Ones about friendship and helping others',
          'traits': ['kind', 'cooperative', 'gentle']
        },
      ]
    },
    {
      'question': 'What do you enjoy most when you have fun?',
      'options': [
        {
          'text': 'Pretending and using my imagination',
          'traits': ['imaginative', 'creative', 'inventive']
        },
        {
          'text': 'Solving challenges or figuring things out',
          'traits': ['persistent', 'organized', 'focused']
        },
        {
          'text': 'Running, jumping, or being active with others',
          'traits': ['energetic', 'outgoing', 'enthusiastic']
        },
        {
          'text': 'Relaxing and enjoying the moment',
          'traits': ['calm', 'easygoing', 'positive']
        },
        {
          'text': 'Being together and sharing with people',
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSelectedAnswer
                        ? const Color(0xFF8E44AD)
                        : const Color(0xFFD6BCE1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: hasSelectedAnswer ? _nextQuestion : null,
                  child: Text(
                    currentQuestion < questions.length - 1
                        ? 'Next'
                        : 'Complete Quiz',
                    style: AppTheme.buttonText
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
