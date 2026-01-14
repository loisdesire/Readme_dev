import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/celebration_confetti.dart';
import '../../utils/app_constants.dart';
import '../../utils/league_helper.dart';

class LeaguePromotionScreen extends StatefulWidget {
  final League newLeague;
  final int totalPoints;

  const LeaguePromotionScreen({
    super.key,
    required this.newLeague,
    required this.totalPoints,
  });

  @override
  State<LeaguePromotionScreen> createState() => _LeaguePromotionScreenState();
}

class _LeaguePromotionScreenState extends State<LeaguePromotionScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: AppConstants.confettiDuration);
    _animationController = AnimationController(
      duration: AppConstants.standardAnimationDuration,
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start animations
    _confettiController.play();
    _animationController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leagueName = LeagueHelper.getLeagueName(widget.newLeague);
    final leagueEmoji = LeagueHelper.getLeagueEmoji(widget.newLeague);
    final leagueColor = Color(LeagueHelper.getLeagueColor(widget.newLeague));

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        '🎉 League Promotion! 🎉',
                        style: AppTheme.heading.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Trophy animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: SizedBox(
                        height: 200,
                        child: Lottie.asset(
                          'assets/animations/trophy.json',
                          repeat: false,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // League badge
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              leagueColor.withValues(alpha: 0.2),
                              leagueColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: leagueColor.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              leagueEmoji,
                              style: const TextStyle(fontSize: 80),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$leagueName League',
                              style: AppTheme.heading.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.totalPoints} points',
                              style: AppTheme.body.copyWith(
                                color: AppTheme.textGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Congratulations message
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'You\'ve been promoted to $leagueName League!',
                        style: AppTheme.body.copyWith(
                          fontSize: 18,
                          color: AppTheme.textGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Action button
                    PrimaryButton(
                      text: 'Continue',
                      onPressed: () => Navigator.pop(context),
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
