import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/feedback_service.dart';
import '../../widgets/app_button.dart';
import '../../utils/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/celebration_confetti.dart';
import 'package:confetti/confetti.dart';

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
  late final AnimationController _animationController;
  late final AnimationController _slideController;
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideUpAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCelebration();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bounceController = AnimationController(
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

    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _confettiController =
        ConfettiController(duration: AppConstants.confettiDuration);
  }

  void _startCelebration() {
    _confettiController.play();
    _animationController.forward();
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bounceController.forward();
    });
    FeedbackService.instance.playSuccess();
  }

  void _close() {
    FeedbackService.instance.playTap();
    Navigator.pop(context);
  }

  Future<void> _shareChallenge() async {
    FeedbackService.instance.playTap();

    try {
      final message = '''🎉 I just completed the weekly reading challenge on ReadMe!

📚 I read ${widget.booksCompleted} ${widget.booksCompleted == 1 ? 'book' : 'books'} this week!

Join me on ReadMe - the fun reading app for kids! 📚✨
https://readme-40267.web.app/''';

      await Share.share(
        message,
        subject: 'ReadMe Weekly Challenge Completed!',
      );
    } catch (e) {
      // Silently fail if share is cancelled or unavailable
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMainContent(),
          CelebrationConfetti(controller: _confettiController),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: _buildChallengeCard(),
              ),
            ),
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitle(),
        const SizedBox(height: 12),
        _buildBadge(),
        const SizedBox(height: 12),
        _buildChallengeMessage(),
        const SizedBox(height: 6),
        _buildMotivationalText(),
        const SizedBox(height: 16),
        _buildPointsBadge(),
      ],
    );
  }

  Widget _buildTitle() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        'Weekly Challenge Unlocked!',
        style: AppTheme.heading.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8E44AD),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBadge() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Text(
        '⭐',
        style: TextStyle(fontSize: 120),
      ),
    );
  }

  Widget _buildChallengeMessage() {
    return SlideTransition(
      position: _slideUpAnimation,
      child: Text(
        'You read ${widget.booksCompleted} ${widget.booksCompleted == 1 ? 'book' : 'books'} this week!',
        style: AppTheme.heading.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMotivationalText() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        'You absolutely crushed it this week. You\'re a reading superstar',
        style: AppTheme.body.copyWith(
          fontSize: 18,
          color: Colors.black54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPointsBadge() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _bounceController,
        curve: Curves.bounceOut,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
          border: Border.all(
            color: const Color(0xFF8E44AD),
            width: 2,
          ),
        ),
        child: Text(
          '+${widget.pointsEarned} points',
          style: AppTheme.body.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8E44AD),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildShareButton(),
        const SizedBox(height: 12),
        _buildCloseButton(),
      ],
    );
  }

  Widget _buildShareButton() {
    return PrimaryButton(
      text: 'Share Challenge',
      onPressed: _shareChallenge,
    );
  }

  Widget _buildCloseButton() {
    return SecondaryButton(
      text: 'Keep the Streak Going',
      onPressed: _close,
    );
  }
}