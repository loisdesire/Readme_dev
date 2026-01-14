// File: lib/screens/quiz/quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_button.dart';
import '../../widgets/feedback_overlay.dart';
import '../../theme/app_theme.dart';
import '../child/child_home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';

class QuizResultScreen extends StatefulWidget {
  final List<String> answers;
  final List<Map<String, dynamic>> questions;
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  Map<String, int> _calculatePersonalityTraits() {
    Map<String, int> traitCounts = {};

    // Count how many times each trait appears in user's answers
    for (int i = 0;
        i < widget.answers.length && i < widget.questions.length;
        i++) {
      final questionOptions = widget.questions[i]['options'] as List;
      for (var option in questionOptions) {
        if (option['text'] == widget.answers[i]) {
          final traits = (option['traits'] as List).cast<String>();
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

    // Sort traits by frequency
    final sortedTraits = traitCounts.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return top 3 traits for display (but save all for matching)
    return sortedTraits.take(3).map((entry) => entry.key).toList();
  }

  List<String> _getAllTraits() {
    final traitCounts = _calculatePersonalityTraits();

    // Return ALL traits for saving to database (used for book matching)
    final sortedTraits = traitCounts.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTraits.map((entry) => entry.key).toList();
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
                            // Save quiz results to Firebase
                            final traitCounts = _calculatePersonalityTraits();
                            // Top 3 for display
                            final allTraits =
                                _getAllTraits(); // All traits for matching

                            final success = await authProvider.saveQuizResults(
                              selectedAnswers: widget.answers,
                              traitScores: traitCounts,
                              dominantTraits:
                                  allTraits, // Save all traits for book matching
                            );

                            if (!context.mounted) return;

                            if (success) {
                              // Award 10 points for completing personality quiz (one-time)
                              await _firestore.collection('users').doc(authProvider.userId).set({
                                'totalAchievementPoints': FieldValue.increment(10),
                                'allTimePoints': FieldValue.increment(10),
                                'quizCompleted': true,
                                'quizCompletedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

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

