import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'quiz_result_screen.dart';

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
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'When you have a problem to solve, what do you do first?',
      'options': [
        {'text': 'Think about it and make a plan', 'traits': ['responsible', 'organized']},
        {'text': 'Jump in and try different things', 'traits': ['curious', 'enthusiastic']},
        {'text': 'Ask someone for advice', 'traits': ['social', 'cooperative']},
        {'text': 'Look for creative solutions', 'traits': ['creative', 'imaginative']},
      ]
    },
    {
      'question': 'Which activity sounds most fun to you?',
      'options': [
        {'text': 'Solving puzzles or mysteries', 'traits': ['curious', 'persistent']},
        {'text': 'Making art or crafts', 'traits': ['creative', 'imaginative']},
        {'text': 'Playing with friends', 'traits': ['social', 'outgoing']},
        {'text': 'Exploring outdoors', 'traits': ['curious', 'enthusiastic']},
      ]
    },
    {
      'question': 'How do you feel about trying new things?',
      'options': [
        {'text': 'Excited and ready to go', 'traits': ['enthusiastic', 'outgoing']},
        {'text': 'Curious and want to learn more first', 'traits': ['curious', 'responsible']},
        {'text': 'Careful and prefer to watch', 'traits': ['calm', 'organized']},
        {'text': 'Happy to join if friends are involved', 'traits': ['social', 'cooperative']},
      ]
    },
    {
      'question': 'What do you like most about stories?',
      'options': [
        {'text': 'The magical and imaginative parts', 'traits': ['imaginative', 'creative']},
        {'text': 'The characters and friendships', 'traits': ['kind', 'caring']},
        {'text': 'The action and adventure', 'traits': ['enthusiastic', 'curious']},
        {'text': 'The mystery to solve', 'traits': ['curious', 'persistent']},
      ]
    },
    {
      'question': 'If you could spend a day any way you wanted, what would you do?',
      'options': [
        {'text': 'Read books or daydream', 'traits': ['calm', 'imaginative']},
        {'text': 'Make or build something', 'traits': ['creative', 'persistent']},
        {'text': 'Play games with friends', 'traits': ['social', 'outgoing']},
        {'text': 'Go on an outdoor adventure', 'traits': ['curious', 'enthusiastic']},
      ]
    },
    {
      'question': 'How do you help others?',
      'options': [
        {'text': 'Take care of them', 'traits': ['kind', 'caring']},
        {'text': 'Teach or share what you know', 'traits': ['cooperative', 'responsible']},
        {'text': 'Cheer them up and play together', 'traits': ['social', 'enthusiastic']},
        {'text': 'Find creative ways to solve their problems', 'traits': ['creative', 'cooperative']},
      ]
    },
    {
      'question': 'What do you do when you feel upset?',
      'options': [
        {'text': 'Talk to someone about it', 'traits': ['social', 'cooperative']},
        {'text': 'Write, draw, or create', 'traits': ['creative', 'calm']},
        {'text': 'Go outside or move around', 'traits': ['enthusiastic', 'positive']},
        {'text': 'Think quietly or read', 'traits': ['calm', 'resilient']},
      ]
    },
    {
      'question': 'Which describes you best?',
      'options': [
        {'text': 'I like to learn new things', 'traits': ['curious', 'persistent']},
        {'text': 'I like to help and care for others', 'traits': ['kind', 'caring']},
        {'text': 'I like to invent and create', 'traits': ['creative', 'imaginative']},
        {'text': 'I like to play and have fun with friends', 'traits': ['social', 'enthusiastic']},
      ]
    },
    {
      'question': 'How do you prefer to spend your free time?',
      'options': [
        {'text': 'Relaxing and daydreaming', 'traits': ['calm', 'imaginative']},
        {'text': 'Doing something active', 'traits': ['enthusiastic', 'outgoing']},
        {'text': 'Learning something new', 'traits': ['curious', 'persistent']},
        {'text': 'Helping family or friends', 'traits': ['kind', 'cooperative']},
      ]
    },
    {
      'question': 'When you play games, what do you enjoy most?',
      'options': [
        {'text': 'Solving puzzles and challenges', 'traits': ['persistent', 'organized']},
        {'text': 'Pretend and role-play', 'traits': ['imaginative', 'creative']},
        {'text': 'Sports and active games', 'traits': ['enthusiastic', 'outgoing']},
        {'text': 'Playing with friends', 'traits': ['social', 'cooperative']},
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
                            const Text(
                              'Book Quiz',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (widget.bookTitle != null)
                              Text(
                                widget.bookTitle!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
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
                    // Illustration (SVG)
                    Container(
                      height: 150,
                      width: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6BCE1).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/illustrations/question page_wormies.svg',
                          height: 100,
                          width: 100,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Question text
                    Text(
                      currentQ['question'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
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
                          child: GestureDetector(
                            onTap: () => _selectAnswer(index),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? const Color(0xFF8E44AD).withOpacity(0.1)
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
                                      '${String.fromCharCode(65 + index)}    ${option['text']}',
                                      style: TextStyle(
                                        fontSize: 16,
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
