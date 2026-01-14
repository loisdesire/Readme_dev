import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/celebration_confetti.dart';
import '../../utils/app_constants.dart';

class WeeklyChallengeCelebrationScreen extends StatefulWidget {
  final int booksCompleted;
  final int targetBooks;
  final int pointsEarned;

  const WeeklyChallengeCelebrationScreen({
    super.key,
    required this.booksCompleted,
    required this.targetBooks,
    this.pointsEarned = 0,
  });

  @override
  State<WeeklyChallengeCelebrationScreen> createState() =>
      _WeeklyChallengeCelebrationScreenState();
}

class _WeeklyChallengeCelebrationScreenState
    extends State<WeeklyChallengeCelebrationScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideDownAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: AppConstants.confettiDuration);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideDownAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _confettiController.play();
    _animationController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    SlideTransition(
                      position: _slideDownAnimation,
                      child: Text(
                        'Challenge Conquered',
                        style: AppTheme.heading.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Trophy emoji
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: const Text(
                        '⭐',
                        style: TextStyle(fontSize: 120),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Stats card
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.accentGold.withValues(alpha: 0.1),
                              AppTheme.accentGold.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.accentGold.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'You read ${widget.booksCompleted} ${widget.booksCompleted == 1 ? 'book' : 'books'} this week!',
                              style: AppTheme.heading.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${widget.targetBooks} books',
                              style: AppTheme.body.copyWith(
                                color: AppTheme.textGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.pointsEarned > 0) ...[
                      const SizedBox(height: 24),

                      // Points earned
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryYellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.secondaryYellow.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars,
                                color: AppTheme.secondaryYellow,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '+${widget.pointsEarned} Points',
                                style: AppTheme.heading.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Message
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'You absolutely crushed it this week. You\'re a reading superstar',
                        style: AppTheme.body.copyWith(
                          fontSize: 16,
                          color: AppTheme.textGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Action button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: PrimaryButton(
                        text: 'Keep the Streak Going',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Confetti
          CelebrationConfetti(controller: _confettiController),
        ],
      ),
    );
  }
}
