import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class BookQuizCelebrationScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int percentage;
  final int pointsEarned;
  final Duration quizDuration;
  final String bookTitle;

  const BookQuizCelebrationScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.pointsEarned,
    required this.quizDuration,
    required this.bookTitle,
  });

  @override
  State<BookQuizCelebrationScreen> createState() =>
      _BookQuizCelebrationScreenState();
}

class _BookQuizCelebrationScreenState
    extends State<BookQuizCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _displayScore = 0;
  int _displayAccuracy = 0;
  int _displayPoints = 0;
  
  // Sequential card animation state
  bool _showCard1 = false;
  bool _showCard2 = false;
  bool _showCard3 = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start celebration
    Future.delayed(const Duration(milliseconds: 300), () {
      _animationController.forward();
      _slideController.forward();
      FeedbackService.instance.playSuccess();
      _startSequentialAnimation();
    });
  }
  
  void _startSequentialAnimation() async {
    // Card 1: Score
    setState(() => _showCard1 = true);
    await _animateCard(
      targetValue: widget.score,
      onUpdate: (val) => setState(() => _displayScore = val),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Card 2: Accuracy
    setState(() => _showCard2 = true);
    await _animateCard(
      targetValue: widget.percentage,
      onUpdate: (val) => setState(() => _displayAccuracy = val),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Card 3: Points
    setState(() => _showCard3 = true);
    await _animateCard(
      targetValue: widget.pointsEarned,
      onUpdate: (val) => setState(() => _displayPoints = val),
    );
  }
  
  Future<void> _animateCard({
    required int targetValue,
    required Function(int) onUpdate,
  }) async {
    final random = math.Random();
    const randomizeDuration = 600; // ms
    const settlingDuration = 400; // ms
    const randomizeSteps = 12;
    
    // Randomizing phase
    for (int i = 0; i < randomizeSteps; i++) {
      await Future.delayed(Duration(milliseconds: randomizeDuration ~/ randomizeSteps));
      if (mounted) {
        onUpdate(random.nextInt(math.max(targetValue * 2, 100)));
      }
    }
    
    // Settling phase - count to target
    const settleSteps = 15;
    final increment = (targetValue / settleSteps).ceil();
    for (int i = 0; i <= settleSteps; i++) {
      await Future.delayed(Duration(milliseconds: settlingDuration ~/ settleSteps));
      if (mounted) {
        onUpdate(i == settleSteps ? targetValue : (increment * i).clamp(0, targetValue));
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool passed = widget.percentage >= 60;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      passed ? 'Quiz Mastered' : 'Keep Practicing',
                      style: AppTheme.heading.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        widget.bookTitle,
                        style: AppTheme.body.copyWith(
                          fontSize: 18,
                          color: AppTheme.textGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Emoji
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Text(
                      passed ? '🎉' : '📚',
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Stats Cards with sequential animation
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        if (_showCard1)
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.checklist_rounded,
                              label: 'Questions Right',
                              value: '$_displayScore/${widget.totalQuestions}',
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        if (_showCard1 && _showCard2) const SizedBox(width: 12),
                        if (_showCard2)
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.track_changes_rounded,
                              label: 'Accuracy Score',
                              value: '$_displayAccuracy%',
                              color: widget.percentage >= 60 ? AppTheme.successGreen : AppTheme.errorRed,
                            ),
                          ),
                        if (_showCard2 && _showCard3) const SizedBox(width: 12),
                        if (_showCard3)
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.stars_rounded,
                              label: 'Points Earned',
                              value: '+$_displayPoints',
                              color: AppTheme.accentGold,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Message
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      passed
                          ? widget.percentage >= 90
                              ? 'You totally crushed that quiz'
                              : 'Awesome work, you really understood that story'
                          : widget.percentage >= 40
                              ? 'Good effort—try reading it again to score higher'
                              : 'Keep trying! You\'ll get better with practice',
                      style: AppTheme.body.copyWith(
                        fontSize: 16,
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Spacer(),

                  // Done button
                  PrimaryButton(
                    text: 'Done',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A9E9E9E),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.heading.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textGray,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
