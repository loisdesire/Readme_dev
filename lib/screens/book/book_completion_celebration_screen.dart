import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../utils/app_constants.dart';
import 'book_quiz_screen.dart';
import '../../utils/page_transitions.dart';

class BookCompletionCelebrationScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int pointsEarned;
  final bool isFirstCompletion;
  final int totalBooksCompleted;
  final Duration readingDuration;
  final int pagesRead;

  const BookCompletionCelebrationScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.pointsEarned,
    required this.isFirstCompletion,
    required this.totalBooksCompleted,
    this.readingDuration = const Duration(minutes: 0),
    this.pagesRead = 0,
  });

  @override
  State<BookCompletionCelebrationScreen> createState() =>
      _BookCompletionCelebrationScreenState();
}

class _BookCompletionCelebrationScreenState
    extends State<BookCompletionCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _bounceAnimation;
  
  int _displayMinutes = 0;
  int _displayPoints = 0;
  int _displayLevel = 0;
  
  // Sequential card animation state
  bool _showCard1 = false;
  bool _showCard2 = false;
  bool _showCard3 = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.standardAnimationDuration,
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _bounceAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.bounceOut,
    ));

    // Start animations - bounce in first, then cards
    _bounceController.forward();
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      _startSequentialAnimation();
    });
  }
  
  void _startSequentialAnimation() async {
    // Card 1: Time
    setState(() => _showCard1 = true);
    final minutesTarget = widget.readingDuration.inMinutes;
    await _animateCardInt(
      targetValue: minutesTarget,
      onUpdate: (val) => setState(() => _displayMinutes = val),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Card 2: Points
    setState(() => _showCard2 = true);
    await _animateCardInt(
      targetValue: widget.pointsEarned,
      onUpdate: (val) => setState(() => _displayPoints = val),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Card 3: Level/Rank
    setState(() => _showCard3 = true);
    int levelTarget = (widget.totalBooksCompleted / 5).floor() + 1;
    await _animateCardInt(
      targetValue: levelTarget,
      onUpdate: (val) => setState(() => _displayLevel = val),
    );
  }
  
  Future<void> _animateCardInt({
    required int targetValue,
    required Function(int) onUpdate,
  }) async {
    final random = math.Random();
    const randomizeDuration = 600;
    const settlingDuration = 400;
    const randomizeSteps = 12;
    
    // Randomizing phase
    for (int i = 0; i < randomizeSteps; i++) {
      await Future.delayed(Duration(milliseconds: randomizeDuration ~/ randomizeSteps));
      if (mounted) {
        onUpdate(random.nextInt(math.max(targetValue * 2, 100)));
      }
    }
    
    // Settling phase
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
    _bounceController.dispose();
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
                padding: const EdgeInsets.all(24),
                child: SlideTransition(
                  position: _bounceAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Title without emojis
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Book Conquered',
                          style: AppTheme.heading.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 16),

                      // Book title underneath
                      SlideTransition(
                        position: _bounceAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            widget.bookTitle,
                            style: AppTheme.heading.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Trophy emoji
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: const Text(
                        '🏆',
                        style: TextStyle(fontSize: 120),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Stats cards with sequential animation
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        children: [
                          Expanded(
                            child: _showCard1
                                ? _buildStatCard(
                                    icon: Icons.schedule_rounded,
                                    label: 'Time Spent',
                                    value: _displayMinutes > 0
                                        ? '$_displayMinutes min'
                                        : '${widget.readingDuration.inSeconds} sec',
                                    color: AppTheme.primaryPurple,
                                  )
                                : const SizedBox(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _showCard2
                                ? _buildStatCard(
                                    icon: Icons.stars_rounded,
                                    label: 'Points',
                                    value: '+$_displayPoints',
                                    color: AppTheme.accentGold,
                                  )
                                : const SizedBox(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _showCard3
                                ? _buildStatCard(
                                    icon: Icons.emoji_events_rounded,
                                    label: 'Reader Level',
                                    value: '$_displayLevel',
                                    color: AppTheme.successGreen,
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Completion message
                    SlideTransition(
                      position: _bounceAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          widget.isFirstCompletion
                              ? 'Amazing! That\'s ${widget.totalBooksCompleted} ${widget.totalBooksCompleted == 1 ? 'book' : 'books'} completed!'
                              : 'Great job reading this again!',
                          style: AppTheme.body.copyWith(
                            fontSize: 16,
                            color: AppTheme.textGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Vertically stacked action buttons
                    Column(
                      children: [
                        PrimaryButton(
                          text: 'Take Quiz',
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              SlideUpRoute(
                                page: BookQuizScreen(
                                  bookId: widget.bookId,
                                  bookTitle: widget.bookTitle,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SecondaryButton(
                          text: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
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
