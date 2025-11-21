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
  
  // Quiz questions mapped to Big Five traits (child-friendly)
  // Each answer has 3 traits for balanced coverage across all 5 domains
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'When you have a problem, what do you usually do?',
      'options': [
        {'text': 'Think carefully and make a plan', 'traits': ['responsible', 'organized', 'focused']},
        {'text': 'Try different ideas until something works', 'traits': ['persistent', 'inventive', 'brave']},
        {'text': 'Ask someone to help me', 'traits': ['social', 'cooperative', 'friendly']},
        {'text': 'Come up with a new or unusual solution', 'traits': ['creative', 'imaginative', 'confident']},
      ]
    },
    {
      'question': 'Which sounds most fun to you?',
      'options': [
        {'text': 'Figuring out puzzles or riddles', 'traits': ['curious', 'persistent', 'focused']},
        {'text': 'Drawing, writing, or making things', 'traits': ['creative', 'artistic', 'calm']},
        {'text': 'Spending time with friends', 'traits': ['social', 'outgoing', 'friendly']},
        {'text': 'Exploring new places or learning new things', 'traits': ['curious', 'adventurous', 'brave']},
      ]
    },
    {
      'question': 'How do you feel when you try something new?',
      'options': [
        {'text': 'Excited! I want to start right away', 'traits': ['enthusiastic', 'brave', 'confident']},
        {'text': 'Curious! I want to know more about it first', 'traits': ['curious', 'careful', 'responsible']},
        {'text': 'Calm. I like to watch and think before I try', 'traits': ['calm', 'careful', 'organized']},
        {'text': 'More excited if I can do it with others', 'traits': ['social', 'cooperative', 'cheerful']},
      ]
    },
    {
      'question': 'What do you like most about stories?',
      'options': [
        {'text': 'The magical and imaginative parts', 'traits': ['imaginative', 'creative', 'curious']},
        {'text': 'The characters and their friendships', 'traits': ['kind', 'caring', 'friendly']},
        {'text': 'The brave heroes and their challenges', 'traits': ['brave', 'confident', 'enthusiastic']},
        {'text': 'The mystery or puzzle to solve', 'traits': ['curious', 'persistent', 'focused']},
      ]
    },
    {
      'question': 'If you had a free afternoon, what would you choose to do?',
      'options': [
        {'text': 'Read, imagine stories, or relax quietly', 'traits': ['calm', 'relaxed', 'easygoing']},
        {'text': 'Create something or work on a project', 'traits': ['creative', 'persistent', 'hardworking']},
        {'text': 'Hang out and talk with friends', 'traits': ['social', 'outgoing', 'talkative']},
        {'text': 'Try something new or adventurous', 'traits': ['adventurous', 'brave', 'enthusiastic']},
      ]
    },
    {
      'question': 'How do you like to help people?',
      'options': [
        {'text': 'By being kind and taking care of them', 'traits': ['kind', 'caring', 'gentle']},
        {'text': 'By teaching them or sharing what I know', 'traits': ['cooperative', 'helpful', 'responsible']},
        {'text': 'By staying calm and making them feel better', 'traits': ['calm', 'gentle', 'positive']},
        {'text': 'By thinking of new ways to solve their problem', 'traits': ['creative', 'inventive', 'helpful']},
      ]
    },
    {
      'question': 'When you feel sad or upset, what helps you most?',
      'options': [
        {'text': 'Talking to someone I trust', 'traits': ['social', 'cooperative', 'sharing']},
        {'text': 'Drawing, writing, or making something', 'traits': ['creative', 'artistic', 'imaginative']},
        {'text': 'Moving around or doing something active', 'traits': ['energetic', 'positive', 'enthusiastic']},
        {'text': 'Thinking quietly, reading, or resting', 'traits': ['calm', 'resilient', 'relaxed']},
      ]
    },
    {
      'question': 'Which one sounds most like you?',
      'options': [
        {'text': 'I love learning and discovering new things', 'traits': ['curious', 'focused', 'hardworking']},
        {'text': 'I enjoy helping and caring for others', 'traits': ['kind', 'caring', 'helpful']},
        {'text': 'I stay positive even when things are hard', 'traits': ['positive', 'resilient', 'confident']},
        {'text': 'I have fun playing and being with friends', 'traits': ['playful', 'social', 'cheerful']},
      ]
    },
    {
      'question': 'What kind of books or movies do you enjoy?',
      'options': [
        {'text': 'Calm, beautiful, or thoughtful ones', 'traits': ['calm', 'easygoing', 'imaginative']},
        {'text': 'Fast-paced and exciting ones', 'traits': ['enthusiastic', 'energetic', 'adventurous']},
        {'text': 'Ones that teach me something interesting', 'traits': ['curious', 'persistent', 'organized']},
        {'text': 'Ones about friendship and helping others', 'traits': ['kind', 'cooperative', 'gentle']},
      ]
    },
    {
      'question': 'What do you enjoy most when you have fun?',
      'options': [
        {'text': 'Solving challenges or figuring things out', 'traits': ['persistent', 'organized', 'focused']},
        {'text': 'Pretending and using my imagination', 'traits': ['imaginative', 'creative', 'playful']},
        {'text': 'Running, jumping, or being active', 'traits': ['energetic', 'outgoing', 'enthusiastic']},
        {'text': 'Being together with other people', 'traits': ['social', 'friendly', 'sharing']},
      ]
    },
  ];

  void _selectAnswer(int optionIndex) {
    setState(() {
      if (selectedAnswers.length > currentQuestion) {
        selectedAnswers[currentQuestion] = questions[currentQuestion]['options'][optionIndex]['text'];
      } else {
        selectedAnswers.add(questions[currentQuestion]['options'][optionIndex]['text']);
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
                        onPressed: currentQuestion > 0 ? _previousQuestion : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
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
                                style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
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
                        style: AppTheme.bodyMedium.copyWith(color: const Color(0xFF666666)),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
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
                    currentQuestion < questions.length - 1 ? 'Next' : 'Complete Quiz',
                    style: AppTheme.buttonText.copyWith(fontWeight: FontWeight.w600),
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
