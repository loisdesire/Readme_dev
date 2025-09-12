import 'package:flutter/material.dart';
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
      'question': 'What do you think is the most fun?',
      'options': [
        {'text': 'Solving puzzles', 'traits': ['analytical', 'curious']},
        {'text': 'Playing with animals', 'traits': ['caring', 'gentle']},
        {'text': 'Making up stories', 'traits': ['creative', 'imaginative']},
        {'text': 'Doing exciting things', 'traits': ['adventurous', 'brave']},
      ]
    },
    {
      'question': 'When you read a book, you like stories about:',
      'options': [
        {'text': 'Magic and wizards', 'traits': ['imaginative', 'dreamy']},
        {'text': 'Real animals and nature', 'traits': ['curious', 'caring']},
        {'text': 'Space and robots', 'traits': ['analytical', 'innovative']},
        {'text': 'Adventures and treasure', 'traits': ['adventurous', 'brave']},
      ]
    },
    {
      'question': 'Your favorite place to spend time is:',
      'options': [
        {'text': 'In your room reading', 'traits': ['independent', 'thoughtful']},
        {'text': 'Outside exploring', 'traits': ['adventurous', 'energetic']},
        {'text': 'With friends playing', 'traits': ['social', 'friendly']},
        {'text': 'Building or creating things', 'traits': ['creative', 'practical']},
      ]
    },
    {
      'question': 'When you learn something new, you like to:',
      'options': [
        {'text': 'Try it right away', 'traits': ['brave', 'active']},
        {'text': 'Think about it first', 'traits': ['thoughtful', 'careful']},
        {'text': 'Ask lots of questions', 'traits': ['curious', 'inquisitive']},
        {'text': 'Share it with others', 'traits': ['social', 'generous']},
      ]
    },
    {
      'question': 'Your ideal weekend would be:',
      'options': [
        {'text': 'Going on a family adventure', 'traits': ['social', 'adventurous']},
        {'text': 'Reading your favorite books', 'traits': ['independent', 'peaceful']},
        {'text': 'Making art or crafts', 'traits': ['creative', 'artistic']},
        {'text': 'Playing games and puzzles', 'traits': ['analytical', 'strategic']},
      ]
    },
    // Add 5 more questions to reach 10 total
    {
      'question': 'When you see a new animal, you want to:',
      'options': [
        {'text': 'Learn everything about it', 'traits': ['curious', 'studious']},
        {'text': 'Take care of it', 'traits': ['caring', 'nurturing']},
        {'text': 'Draw or photograph it', 'traits': ['creative', 'observant']},
        {'text': 'Tell your friends about it', 'traits': ['social', 'enthusiastic']},
      ]
    },
    {
      'question': 'Your favorite type of games are:',
      'options': [
        {'text': 'Puzzles and brain teasers', 'traits': ['analytical', 'patient']},
        {'text': 'Sports and active games', 'traits': ['energetic', 'competitive']},
        {'text': 'Pretend and role-play', 'traits': ['imaginative', 'creative']},
        {'text': 'Board games with friends', 'traits': ['social', 'strategic']},
      ]
    },
    {
      'question': 'When you have free time, you prefer to:',
      'options': [
        {'text': 'Relax and daydream', 'traits': ['peaceful', 'dreamy']},
        {'text': 'Do something active', 'traits': ['energetic', 'active']},
        {'text': 'Learn something new', 'traits': ['curious', 'studious']},
        {'text': 'Help family or friends', 'traits': ['caring', 'helpful']},
      ]
    },
    {
      'question': 'The best part of a story is:',
      'options': [
        {'text': 'The exciting action', 'traits': ['adventurous', 'thrilling']},
        {'text': 'The interesting characters', 'traits': ['social', 'empathetic']},
        {'text': 'The mystery to solve', 'traits': ['analytical', 'detective']},
        {'text': 'The magical elements', 'traits': ['imaginative', 'whimsical']},
      ]
    },
    {
      'question': 'When facing a challenge, you:',
      'options': [
        {'text': 'Jump right in and try', 'traits': ['brave', 'confident']},
        {'text': 'Make a plan first', 'traits': ['strategic', 'organized']},
        {'text': 'Ask for help', 'traits': ['wise', 'collaborative']},
        {'text': 'Find a creative solution', 'traits': ['innovative', 'resourceful']},
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
                    // Cute illustration
                    Container(
                      height: 150,
                      width: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6BCE1).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.quiz,
                              size: 50,
                              color: Color(0xFF8E44AD),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '🤔💭✨🧩',
                              style: TextStyle(fontSize: 20),
                            ),
                          ],
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
