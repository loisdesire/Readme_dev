// File: lib/screens/quiz/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/feedback_overlay.dart';
import '../../theme/app_theme.dart';
import '../child/child_home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/achievement_service.dart';
import '../../services/weekly_challenge_service.dart';
import '../../utils/page_transitions.dart';

class QuizResultScreen extends StatefulWidget {
  final List<int> answers; // Likert scores (1-5)
  final List<Map<String, dynamic>> questions; // BFI-C questions
  final String? bookId;
  final String? bookTitle;
  final Duration? quizDuration;
  final int? totalQuestions;

  const QuizResultScreen({
    super.key,
    required this.answers,
    required this.questions,
    this.bookId,
    this.bookTitle,
    this.quizDuration,
    this.totalQuestions,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
      FeedbackService.instance.playSuccess();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, int> _calculateOceanScores() {
    // Calculate OCEAN scores from Likert responses
    Map<String, int> oceanScores = {
      'O': 0, // Openness
      'C': 0, // Conscientiousness
      'E': 0, // Extraversion
      'A': 0, // Agreeableness
      'N': 0, // Neuroticism (Emotional Stability)
    };

    for (int i = 0; i < widget.answers.length && i < widget.questions.length; i++) {
      final dimension = widget.questions[i]['dimension'] as String;
      final score = widget.answers[i]; // 1-5 Likert score
      final isReversed = widget.questions[i]['isReversed'] as bool? ?? false;

      // Add score to appropriate dimension (reverse if needed)
      final adjustedScore = isReversed ? (6 - score) : score;
      oceanScores[dimension] = (oceanScores[dimension] ?? 0) + adjustedScore;
    }

    return oceanScores;
  }

  List<String> _mapOceanToSubTraits() {
    final oceanScores = _calculateOceanScores();
    
    // Map OCEAN dimensions to sub-traits (each dimension has 3 facets)
    const Map<String, List<String>> oceanToSubTraits = {
      'O': ['curious', 'creative', 'imaginative'],
      'C': ['responsible', 'organized', 'persistent'],
      'E': ['social', 'enthusiastic', 'outgoing'],
      'A': ['kind', 'cooperative', 'caring'],
      'N': ['resilient', 'calm', 'positive'],
    };

    // Sort dimensions by score (highest first)
    final sortedDimensions = oceanScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Check if all scores are identical (user selected same answer for everything)
    final allScoresIdentical = sortedDimensions.every(
      (entry) => entry.value == sortedDimensions[0].value
    );

    List<String> assignedTraits = [];
    
    if (allScoresIdentical) {
      // User gave same responses to everything - distribute traits evenly across ALL dimensions
      // This ensures variety even when scores are flat
      for (var i = 0; i < 5 && i < sortedDimensions.length; i++) {
        final dimension = sortedDimensions[i % sortedDimensions.length];
        final traits = oceanToSubTraits[dimension.key] ?? [];
        if (traits.isNotEmpty) {
          assignedTraits.add(traits[i ~/ sortedDimensions.length]);
        }
      }
    } else {
      // Normal case: Take traits from top 2 dimensions
      final topDimension = sortedDimensions[0];
      final secondDimension = sortedDimensions.length > 1 ? sortedDimensions[1] : null;
      
      // Take 3 traits from top dimension
      assignedTraits.addAll(oceanToSubTraits[topDimension.key] ?? []);
      
      // Take 2 traits from second dimension (if exists)
      if (secondDimension != null) {
        assignedTraits.addAll((oceanToSubTraits[secondDimension.key] ?? []).take(2));
      }
    }

    // Return exactly 5 traits
    return assignedTraits.take(5).toList();
  }

  List<String> _getTopTraits() {
    final allTraits = _mapOceanToSubTraits();
    // Return top 3 for display to user
    return allTraits.take(3).toList();
  }

  List<String> _getAllTraits() {
    // Return all 5 assigned sub-traits for database storage and matching
    return _mapOceanToSubTraits();
  }

  @override
  Widget build(BuildContext context) {
    final topTraits = _getTopTraits();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.userProfile?['username'] ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          SafeArea(
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
                      'Congratulations, $username!',
                      style: AppTheme.heading.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
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
                      'Your Top Traits:',
                      style: AppTheme.heading.copyWith(
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
                      'Based on your personality, we\'ll recommend books about ${topTraits.take(3).map((t) => t.toLowerCase()).join(", ")} and more!',
                      style: AppTheme.body.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Get ready to discover stories made just for you! 📚',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Start reading button
              PrimaryButton(
                text: 'Start Reading',
                isLoading: _isLoading,
                onPressed: () async {
                          // Add haptic feedback for satisfying button press
                          FeedbackService.instance.playSuccess();

                          setState(() {
                            _isLoading = true;
                          });

                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          final bookProvider =
                              Provider.of<BookProvider>(context, listen: false);
                          final userProvider =
                              Provider.of<UserProvider>(context, listen: false);

                          if (authProvider.userId != null) {
                            // Calculate OCEAN scores and map to sub-traits
                            final oceanScores = _calculateOceanScores();
                            final allTraits = _getAllTraits(); // All sub-traits for matching

                            final success = await authProvider.saveQuizResults(
                              selectedAnswers: widget.answers,
                              traitScores: oceanScores, // Store OCEAN scores
                              dominantTraits: allTraits, // Save all sub-traits for book matching
                            );

                            if (!context.mounted) return;

                            if (success) {
                              // Award 10 points for completing personality quiz (one-time)
                              await AchievementService()
                                  .awardPersonalityQuizCompletion(
                                userId: authProvider.userId!,
                                points: 10,
                              );

                              // Track quiz completion for weekly challenge
                              final challengeService = WeeklyChallengeService();
                              final score = (widget.answers.isNotEmpty) 
                                  ? (widget.answers.reduce((a, b) => a + b) / widget.answers.length / 5.0 * 100).round()
                                  : 0;
                              await challengeService.trackQuizCompletion(
                                userId: authProvider.userId!,
                                score: score,
                              );

                              // If the current weekly challenge is quiz-based, refresh its progress now.
                              await challengeService
                                  .refreshQuizChallengeProgress(authProvider.userId!);

                              // Phase 1: Load critical user data only (fast)
                              await userProvider
                                  .loadUserData(authProvider.userId!);

                              // Ensure we're still mounted before using context for navigation
                              if (!context.mounted) return;

                              // Navigate immediately - don't wait for book recommendations
                              Navigator.pushAndRemoveUntil(
                                context,
                                FadeRoute(page: const ChildHomeScreen(),
                                ),
                                (route) => false, // Remove all previous routes
                              );

                              // Phase 2: Load recommendations in background (after navigation)
                              // Dashboard will show loading indicator for recommendations section only
                              bookProvider.loadRecommendedBooks(
                                  allTraits); // Use all traits for matching
                              bookProvider.loadAllBooks();
                            } else {
                              // Show error and still navigate (fallback)
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Quiz completed! Some data may not be saved.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );

                              Navigator.pushAndRemoveUntil(
                                context,
                                FadeRoute(page: const ChildHomeScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          }
                        },
              ),

              const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          // Confetti overlay - uses existing FeedbackOverlay
          const FeedbackOverlay(),
        ],
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

