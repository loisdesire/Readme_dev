// File: lib/screens/quiz/quiz_result_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../child/child_home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/feedback_service.dart';

class QuizResultScreen extends StatefulWidget {
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

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  bool _isLoading = false;

  Map<String, int> _calculatePersonalityTraits() {
    Map<String, int> traitCounts = {};

    for (int i = 0; i < widget.answers.length && i < widget.questions.length; i++) {
      final questionOptions = widget.questions[i]['options'] as List;
      for (var option in questionOptions) {
        if (option['text'] == widget.answers[i]) {
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

  // Expanded domain-to-traits mapping (traits can belong to multiple domains)
  static const Map<String, List<String>> domainToTraits = {
    'Openness': [
      'curious', 'imaginative', 'creative', 'adventurous', 'artistic', 'inventive',
    ],
    'Conscientiousness': [
      'hardworking', 'careful', 'persistent', 'focused', 'responsible', 'organized',
    ],
    'Extraversion': [
      'outgoing', 'energetic', 'talkative', 'playful', 'cheerful', 'social', 'enthusiastic',
    ],
    'Agreeableness': [
      'kind', 'helpful', 'caring', 'friendly', 'cooperative', 'gentle', 'sharing',
    ],
    'Emotional Stability': [
      'calm', 'relaxed', 'positive', 'brave', 'confident', 'easygoing',
    ],
  };

  // Reverse mapping for scoring (traits can belong to multiple domains)
  static Map<String, List<String>> get traitToDomains {
    final Map<String, List<String>> map = {};
    domainToTraits.forEach((domain, traits) {
      for (final trait in traits) {
        map.putIfAbsent(trait, () => []).add(domain);
      }
    });
    return map;
  }

  Map<String, double> _calculateBigFiveDomainScores() {
    final traitCounts = _calculatePersonalityTraits();
    final totalResponses = widget.answers.length * 2; // 2 traits per answer (update if you change quiz logic)

    Map<String, int> domainCounts = {
      for (final domain in domainToTraits.keys) domain: 0
    };

    traitCounts.forEach((trait, count) {
      final domains = traitToDomains[trait] ?? [];
      for (final domain in domains) {
        domainCounts[domain] = (domainCounts[domain] ?? 0) + count;
      }
    });

    Map<String, double> domainScores = {};
    domainCounts.forEach((domain, count) {
      domainScores[domain] = count / totalResponses;
    });
    return domainScores;
  }

  List<String> _getTopTraits() {
    final domainScores = _calculateBigFiveDomainScores();
    final traitCounts = _calculatePersonalityTraits();

    // Get top 5 domains with score > 0.2 (20%), or all with score > 0 if fewer than 5
    List<MapEntry<String, double>> topDomains = domainScores.entries
        .where((entry) => entry.value > 0.2)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topDomains.length < 5) {
      // Add more domains with score > 0 if needed
      final extraDomains = domainScores.entries
          .where((entry) => entry.value > 0 && !topDomains.contains(entry))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var entry in extraDomains) {
        if (topDomains.length < 5) topDomains.add(entry);
      }
    }

    List<String> selectedTraits = [];

    // Take top 5 domains and select highest scoring trait from each (traits may belong to multiple domains)
    for (var domainEntry in topDomains.take(5)) {
      final domainTraitsList = domainToTraits[domainEntry.key] ?? [];
      // Find highest scoring trait in this domain
      String? topTrait;
      int maxCount = 0;
      for (String trait in domainTraitsList) {
        int count = traitCounts[trait] ?? 0;
        if (count > maxCount && !selectedTraits.contains(trait)) {
          maxCount = count;
          topTrait = trait;
        }
      }
      if (topTrait != null && maxCount > 0 && !selectedTraits.contains(topTrait)) {
        selectedTraits.add(topTrait);
      }
    }

    // If fewer than 5, fill with next highest overall traits
    if (selectedTraits.length < 5) {
      final sortedTraits = traitCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var entry in sortedTraits) {
        if (entry.value > 0 && !selectedTraits.contains(entry.key)) {
          selectedTraits.add(entry.key);
          if (selectedTraits.length == 5) break;
        }
      }
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
    
    // Map traits to diverse book tags (FIXED: no more always Learning/Adventure/Fantasy)
    
    // Openness - creativity and exploration
    if (topTraits.contains('curious')) {
      genres.addAll(['Exploration', 'Discovery', 'Science']);
    }
    if (topTraits.contains('creative') || topTraits.contains('imaginative')) {
      genres.addAll(['Creativity', 'Art', 'Imagination']);
    }
    if (topTraits.contains('artistic')) {
      genres.addAll(['Art', 'Creativity', 'Self-expression']);
    }
    if (topTraits.contains('inventive')) {
      genres.addAll(['Innovation', 'Problem-solving', 'Technology']);
    }
    if (topTraits.contains('adventurous')) {
      genres.addAll(['Adventure', 'Exploration', 'Nature']);
    }
    
    // Conscientiousness - work and organization
    if (topTraits.contains('hardworking') || topTraits.contains('persistent')) {
      genres.addAll(['Perseverance', 'Achievement', 'Goal-setting']);
    }
    if (topTraits.contains('responsible') || topTraits.contains('organized')) {
      genres.addAll(['Responsibility', 'Organization', 'Leadership']);
    }
    if (topTraits.contains('careful') || topTraits.contains('focused')) {
      genres.addAll(['Patience', 'Mindfulness', 'Skill-building']);
    }
    
    // Extraversion - social and energetic
    if (topTraits.contains('outgoing') || topTraits.contains('social')) {
      genres.addAll(['Friendship', 'Social-skills', 'Communication']);
    }
    if (topTraits.contains('energetic') || topTraits.contains('enthusiastic')) {
      genres.addAll(['Sports', 'Physical-activity', 'Adventure']);
    }
    if (topTraits.contains('talkative') || topTraits.contains('cheerful')) {
      genres.addAll(['Humor', 'Storytelling', 'Expression']);
    }
    if (topTraits.contains('playful')) {
      genres.addAll(['Games', 'Humor', 'Fun']);
    }
    
    // Agreeableness - kindness and cooperation
    if (topTraits.contains('kind') || topTraits.contains('caring')) {
      genres.addAll(['Kindness', 'Empathy', 'Helping-others']);
    }
    if (topTraits.contains('helpful') || topTraits.contains('cooperative')) {
      genres.addAll(['Cooperation', 'Teamwork', 'Community']);
    }
    if (topTraits.contains('friendly')) {
      genres.addAll(['Friendship', 'Social-connection', 'Belonging']);
    }
    if (topTraits.contains('gentle') || topTraits.contains('sharing')) {
      genres.addAll(['Generosity', 'Compassion', 'Animals']);
    }
    
    // Emotional Stability - calmness and confidence
    if (topTraits.contains('calm') || topTraits.contains('relaxed')) {
      genres.addAll(['Mindfulness', 'Wellness', 'Peace']);
    }
    if (topTraits.contains('confident') || topTraits.contains('brave')) {
      genres.addAll(['Confidence', 'Bravery', 'Leadership']);
    }
    if (topTraits.contains('positive') || topTraits.contains('easygoing')) {
      genres.addAll(['Positivity', 'Resilience', 'Adaptability']);
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
                child: Column(
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Congratulations!',
                      style: AppTheme.heading.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You\'ve completed your personality quiz!',
                      style: AppTheme.body.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
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
                      color: const Color(0x1A9E9E9E),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Reading Personality:',
                      style: AppTheme.heading.copyWith(
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      description,
                      style: AppTheme.body.copyWith(
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your Top Traits:',
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E44AD),
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
                            color: AppTheme.primaryPurpleOpaque10,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppTheme.primaryPurpleOpaque30,
                            ),
                          ),
                          child: Text(
                            trait.capitalize(),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E44AD),
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
                      color: const Color(0x1A9E9E9E),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_stories,
                          color: Color(0xFF8E44AD),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Books We\'ll Recommend:',
                          style: AppTheme.heading.copyWith(
                            color: const Color(0xFF8E44AD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      recommendedGenres,
                      style: AppTheme.body.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We\'ll find books that match your unique personality!',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
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
                  onPressed: _isLoading ? null : () async {
                    // Add haptic feedback for satisfying button press
                    FeedbackService.instance.playSuccess();

                    setState(() {
                      _isLoading = true;
                    });

                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final bookProvider = Provider.of<BookProvider>(context, listen: false);
                    final userProvider = Provider.of<UserProvider>(context, listen: false);

                    if (authProvider.userId != null) {
                      // Save quiz results to Firebase
                      final traitCounts = _calculatePersonalityTraits();
                      final topTraits = _getTopTraits();

                      final success = await authProvider.saveQuizResults(
                        selectedAnswers: widget.answers,
                        traitScores: traitCounts,
                        dominantTraits: topTraits,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        // Phase 1: Load critical user data only (fast)
                        await userProvider.loadUserData(authProvider.userId!);

                        // Ensure we're still mounted before using context for navigation
                        if (!context.mounted) return;

                        // Navigate immediately - don't wait for book recommendations
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChildHomeScreen(),
                          ),
                          (route) => false, // Remove all previous routes
                        );

                        // Phase 2: Load recommendations in background (after navigation)
                        // Dashboard will show loading indicator for recommendations section only
                        bookProvider.loadRecommendedBooks(topTraits);
                        bookProvider.loadAllBooks();
                      } else {
                        // Show error and still navigate (fallback)
                        if (!context.mounted) return;

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
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Setting up your library...',
                              style: AppTheme.heading.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.menu_book, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Start Reading Journey!',
                              style: AppTheme.heading.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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