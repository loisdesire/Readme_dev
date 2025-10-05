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

  Map<String, double> _calculateBigFiveDomainScores() {
    final traitCounts = _calculatePersonalityTraits();
    final totalResponses = answers.length * 2; // 2 traits per answer
    
    // Map traits to Big Five domains
    final domainTraits = {
      'Openness': ['curious', 'creative', 'imaginative'],
      'Conscientiousness': ['responsible', 'organized', 'persistent'],
      'Extraversion': ['social', 'enthusiastic', 'outgoing'],
      'Agreeableness': ['kind', 'cooperative', 'caring'],
      'Emotional Stability': ['resilient', 'calm', 'positive'],
    };
    
    Map<String, double> domainScores = {};
    
    domainTraits.forEach((domain, traits) {
      int domainCount = 0;
      for (String trait in traits) {
        domainCount += traitCounts[trait] ?? 0;
      }
      domainScores[domain] = domainCount / totalResponses;
    });
    
    return domainScores;
  }

  List<String> _getTopTraits() {
    final domainScores = _calculateBigFiveDomainScores();
    final traitCounts = _calculatePersonalityTraits();
    
    // Get top 2-3 domains with score > 0.2 (20%)
    final topDomains = domainScores.entries
        .where((entry) => entry.value > 0.2)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<String> selectedTraits = [];
    
    // Define domain to traits mapping
    final domainToTraits = {
      'Openness': ['curious', 'creative', 'imaginative'],
      'Conscientiousness': ['responsible', 'organized', 'persistent'],
      'Extraversion': ['social', 'enthusiastic', 'outgoing'],
      'Agreeableness': ['kind', 'cooperative', 'caring'],
      'Emotional Stability': ['resilient', 'calm', 'positive'],
    };
    
    // Take top 2-3 domains and select highest scoring trait from each
    for (var domainEntry in topDomains.take(3)) {
      final domainTraitsList = domainToTraits[domainEntry.key] ?? [];
      
      // Find highest scoring trait in this domain
      String? topTrait;
      int maxCount = 0;
      for (String trait in domainTraitsList) {
        int count = traitCounts[trait] ?? 0;
        if (count > maxCount) {
          maxCount = count;
          topTrait = trait;
        }
      }
      
      if (topTrait != null && maxCount > 0) {
        selectedTraits.add(topTrait);
      }
    }
    
    // Ensure we have at least 2 traits, fallback to old method if needed
    if (selectedTraits.length < 2) {
      final sortedTraits = traitCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      selectedTraits = sortedTraits.take(3).map((e) => e.key).toList();
    }
    
    return selectedTraits;
  }

  String _getPersonalityDescription(List<String> topTraits) {
    if (topTraits.contains('curious') && (topTraits.contains('creative') || topTraits.contains('imaginative'))) {
      return 'The Young Explorer! You love to discover new things and use your imagination. Perfect for mystery and adventure books!';
    } else if (topTraits.contains('creative') && topTraits.contains('imaginative')) {
      return 'The Creative Dreamer! You have a wonderful imagination and love stories filled with magic and creativity.';
    } else if (topTraits.contains('social') && (topTraits.contains('enthusiastic') || topTraits.contains('outgoing'))) {
      return 'The Friendly Leader! You love being with others and enjoy stories about friendship and teamwork.';
    } else if (topTraits.contains('kind') && (topTraits.contains('caring') || topTraits.contains('cooperative'))) {
      return 'The Kind Helper! You care about others and enjoy stories about helping people and making friends.';
    } else if (topTraits.contains('responsible') && (topTraits.contains('organized') || topTraits.contains('persistent'))) {
      return 'The Reliable Achiever! You like to finish what you start and enjoy stories about overcoming challenges.';
    } else if (topTraits.contains('calm') && (topTraits.contains('resilient') || topTraits.contains('positive'))) {
      return 'The Peaceful Thinker! You stay calm and positive, and enjoy stories that are thoughtful and inspiring.';
    } else {
      return 'You\'re wonderfully unique! Your personality shows you enjoy many different types of amazing stories.';
    }
  }

  String _getRecommendedGenres(List<String> topTraits) {
    Set<String> genres = {};
    
    // Map traits to actual book tags/categories in your database
    // Openness traits - curiosity and creativity
    if (topTraits.contains('curious') || topTraits.contains('persistent')) {
      genres.addAll(['Learning', 'Adventure', 'Fantasy']);
    }
    if (topTraits.contains('creative') || topTraits.contains('imaginative')) {
      genres.addAll(['Creativity', 'Imagination', 'Fantasy']);
    }
    
    // Extraversion traits - social and energetic
    if (topTraits.contains('social') || topTraits.contains('enthusiastic') || topTraits.contains('outgoing')) {
      genres.addAll(['Adventure', 'Friendship', 'Cooperation']);
    }
    
    // Agreeableness traits - kindness and cooperation
    if (topTraits.contains('kind') || topTraits.contains('caring') || topTraits.contains('cooperative')) {
      genres.addAll(['Friendship', 'Family', 'Animals', 'Kindness']);
    }
    
    // Conscientiousness traits - responsibility and organization
    if (topTraits.contains('responsible') || topTraits.contains('organized')) {
      genres.addAll(['Responsibility', 'Organization', 'Learning']);
    }
    
    // Emotional Stability traits - calmness and resilience
    if (topTraits.contains('calm') || topTraits.contains('resilient') || topTraits.contains('positive')) {
      genres.addAll(['Resilience', 'Positivity', 'Family']);
    }
    
    return genres.isEmpty ? 'Various book types' : genres.take(3).join(', ');
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
                child: const Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 60,
                      color: Colors.white,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Congratulations!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'You\'ve completed your personality quiz!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Icon(
                      Icons.celebration,
                      size: 50,
                      color: Colors.amber,
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