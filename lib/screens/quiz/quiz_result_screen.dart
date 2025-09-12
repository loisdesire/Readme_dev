// File: lib/screens/quiz/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../child/child_home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';

class QuizResultScreen extends StatelessWidget {
  final List<String> answers;
  final List<Map<String, dynamic>> questions;
  final String? bookId;
  final String? bookTitle;

  const QuizResultScreen({
    super.key,
    required this.answers,
    required this.questions,
    this.bookId,
    this.bookTitle,
  });

  Map<String, int> _calculatePersonalityTraits() {
    Map<String, int> traitCounts = {};
    
    for (int i = 0; i < answers.length && i < questions.length; i++) {
      final questionOptions = questions[i]['options'] as List;
      for (var option in questionOptions) {
        if (option['text'] == answers[i]) {
          final traits = option['traits'] as List<String>;
          for (String trait in traits) {
            traitCounts[trait] = (traitCounts[trait] ?? 0) + 1;
          }
          break;
        }
      }
    }
    
    return traitCounts;
  }

  List<String> _getTopTraits() {
    final traitCounts = _calculatePersonalityTraits();
    final sortedTraits = traitCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTraits.take(3).map((e) => e.key).toList();
  }

  String _getPersonalityDescription(List<String> topTraits) {
    if (topTraits.contains('curious') && topTraits.contains('analytical')) {
      return 'The Young Explorer! You love to discover new things and figure out how they work. Perfect for mystery and science books!';
    } else if (topTraits.contains('creative') && topTraits.contains('imaginative')) {
      return 'The Dreamer! You have a wonderful imagination and love stories filled with magic and adventure.';
    } else if (topTraits.contains('adventurous') && topTraits.contains('brave')) {
      return 'The Bold Adventurer! You love excitement and stories about heroes going on amazing journeys.';
    } else if (topTraits.contains('caring') && topTraits.contains('social')) {
      return 'The Kind Friend! You care about others and enjoy stories about friendship and helping people.';
    } else if (topTraits.contains('independent') && topTraits.contains('thoughtful')) {
      return 'The Wise Thinker! You like to think deeply about things and enjoy meaningful stories.';
    } else {
      return 'You\'re unique! Your personality shows you enjoy a wonderful mix of different types of stories.';
    }
  }

  String _getRecommendedGenres(List<String> topTraits) {
    Set<String> genres = {};
    
    if (topTraits.contains('curious') || topTraits.contains('analytical')) {
      genres.addAll(['Mystery', 'Science', 'Educational']);
    }
    if (topTraits.contains('creative') || topTraits.contains('imaginative')) {
      genres.addAll(['Fantasy', 'Fairy Tales', 'Art & Creativity']);
    }
    if (topTraits.contains('adventurous') || topTraits.contains('brave')) {
      genres.addAll(['Adventure', 'Action', 'Exploration']);
    }
    if (topTraits.contains('caring') || topTraits.contains('social')) {
      genres.addAll(['Friendship', 'Family', 'Animals']);
    }
    
    return genres.isEmpty ? 'Various genres' : genres.take(3).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final topTraits = _getTopTraits();
    final description = _getPersonalityDescription(topTraits);
    final recommendedGenres = _getRecommendedGenres(topTraits);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Congratulations header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8E44AD),
                      Color(0xFFA062BA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You\'ve completed your personality quiz!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '🎉✨🌟📚',
                      style: TextStyle(fontSize: 30),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Personality result card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Reading Personality:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your Top Traits:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topTraits.map((trait) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E44AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(0xFF8E44AD).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            trait.capitalize(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E44AD),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              
              // Recommended genres card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_stories,
                          color: Color(0xFF8E44AD),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Books We\'ll Recommend:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8E44AD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      recommendedGenres,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We\'ll find books that match your unique personality!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Start reading button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final bookProvider = Provider.of<BookProvider>(context, listen: false);
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    
                    if (authProvider.userId != null) {
                      // Save quiz results to Firebase
                      final traitCounts = _calculatePersonalityTraits();
                      final topTraits = _getTopTraits();
                      
                      final success = await authProvider.saveQuizResults(
                        selectedAnswers: answers,
                        traitScores: traitCounts,
                        dominantTraits: topTraits,
                      );
                      
                      if (success) {
                        // Load user data and book recommendations
                        await userProvider.loadUserData(authProvider.userId!);
                        await bookProvider.loadRecommendedBooks(topTraits);
                        await bookProvider.loadAllBooks();
                        
                        // Navigate to child dashboard
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChildHomeScreen(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      } else {
                        // Show error and still navigate (fallback)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quiz completed! Some data may not be saved.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChildHomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Start Reading Journey!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension to capitalize strings
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}