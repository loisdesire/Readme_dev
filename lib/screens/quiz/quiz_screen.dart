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
  
  // Sample quiz questions (matches your Figma design)
  final List<Map<String, dynamic>> questions = [
    {
      'question': 'When you have a problem to solve, what do you do first?',
      'options': [
        {'text': 'Think about it and make a plan', 'traits': ['thoughtful', 'strategic']},
        {'text': 'Jump in and try different things', 'traits': ['brave', 'active']},
        {'text': 'Ask someone for advice', 'traits': ['social', 'wise']},
        {'text': 'Look for creative solutions', 'traits': ['innovative', 'resourceful']},
      ]
    },
    {
      'question': 'Which activity sounds most fun to you?',
      'options': [
        {'text': 'Solving puzzles or mysteries', 'traits': ['analytical', 'detective']},
        {'text': 'Making art or crafts', 'traits': ['creative', 'artistic']},
        {'text': 'Playing with friends', 'traits': ['social', 'friendly']},
        {'text': 'Exploring outdoors', 'traits': ['adventurous', 'energetic']},
      ]
    },
    {
      'question': 'How do you feel about trying new things?',
      'options': [
        {'text': 'Excited and ready to go', 'traits': ['adventurous', 'brave']},
        {'text': 'Curious and want to learn more first', 'traits': ['curious', 'studious']},
        {'text': 'Careful and prefer to watch', 'traits': ['thoughtful', 'careful']},
        {'text': 'Happy to join if friends are involved', 'traits': ['social', 'enthusiastic']},
      ]
    },
    {
      'question': 'What do you like most about stories?',
      'options': [
        {'text': 'The magical and imaginative parts', 'traits': ['imaginative', 'whimsical']},
        {'text': 'The characters and friendships', 'traits': ['social', 'empathetic']},
        {'text': 'The action and adventure', 'traits': ['adventurous', 'thrilling']},
        {'text': 'The mystery to solve', 'traits': ['analytical', 'detective']},
      ]
    },
    {
      'question': 'If you could spend a day any way you wanted, what would you do?',
      'options': [
        {'text': 'Read books or daydream', 'traits': ['independent', 'dreamy']},
        {'text': 'Make or build something', 'traits': ['creative', 'practical']},
        {'text': 'Play games with friends', 'traits': ['social', 'strategic']},
        {'text': 'Go on an outdoor adventure', 'traits': ['adventurous', 'energetic']},
      ]
    },
    {
      'question': 'How do you help others?',
      'options': [
        {'text': 'Take care of them', 'traits': ['caring', 'nurturing']},
        {'text': 'Teach or share what you know', 'traits': ['generous', 'wise']},
        {'text': 'Cheer them up and play together', 'traits': ['friendly', 'enthusiastic']},
        {'text': 'Find creative ways to solve their problems', 'traits': ['innovative', 'resourceful']},
      ]
    },
    {
      'question': 'What do you do when you feel upset?',
      'options': [
        {'text': 'Talk to someone about it', 'traits': ['social', 'empathetic']},
        {'text': 'Write, draw, or create', 'traits': ['creative', 'artistic']},
        {'text': 'Go outside or move around', 'traits': ['energetic', 'active']},
        {'text': 'Think quietly or read', 'traits': ['independent', 'peaceful']},
      ]
    },
    {
      'question': 'Which describes you best?',
      'options': [
        {'text': 'I like to learn new things', 'traits': ['curious', 'studious']},
        {'text': 'I like to help and care for others', 'traits': ['caring', 'helpful']},
        {'text': 'I like to invent and create', 'traits': ['creative', 'innovative']},
        {'text': 'I like to play and have fun with friends', 'traits': ['social', 'enthusiastic']},
      ]
    },
    {
      'question': 'How do you prefer to spend your free time?',
      'options': [
        {'text': 'Relaxing and daydreaming', 'traits': ['peaceful', 'dreamy']},
        {'text': 'Doing something active', 'traits': ['energetic', 'active']},
        {'text': 'Learning something new', 'traits': ['curious', 'studious']},
        {'text': 'Helping family or friends', 'traits': ['caring', 'helpful']},
      ]
    },
    {
      'question': 'When you play games, what do you enjoy most?',
      'options': [
        {'text': 'Solving puzzles and challenges', 'traits': ['analytical', 'patient']},
        {'text': 'Pretend and role-play', 'traits': ['imaginative', 'creative']},
        {'text': 'Sports and active games', 'traits': ['energetic', 'competitive']},
        {'text': 'Playing with friends', 'traits': ['social', 'strategic']},
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
