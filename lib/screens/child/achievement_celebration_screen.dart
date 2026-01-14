import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';

import '../../services/achievement_service.dart';
import '../../services/feedback_service.dart';
import '../../widgets/app_button.dart';
import '../../utils/app_constants.dart';
import '../../theme/app_theme.dart';

class AchievementCelebrationScreen extends StatefulWidget {
  final List<Achievement> achievements;

  const AchievementCelebrationScreen({
    super.key,
    required this.achievements,
  });

  @override
  State<AchievementCelebrationScreen> createState() =>
      _AchievementCelebrationScreenState();
}

class _AchievementCelebrationScreenState
    extends State<AchievementCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _slideController;
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideUpAnimation;

  int _currentIndex = 0;

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
  }

  void _startCelebration() {
    _animationController.forward();
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bounceController.forward();
    });
    FeedbackService.instance.playSuccess();
  }

  void _nextAchievement() {
    if (_currentIndex < widget.achievements.length - 1) {
      setState(() {
        _currentIndex++;
        _animationController.reset();
        _slideController.reset();
        _bounceController.reset();
      });
      _startCelebration();
    } else {
      _close();
    }
  }

  void _close() {
    FeedbackService.instance.playTap();
    Navigator.pop(context);
  }

  Future<void> _shareAchievement() async {
    final achievement = widget.achievements[_currentIndex];
    FeedbackService.instance.playTap();

    try {
      final message = '''🎉 I just unlocked an achievement on ReadMe!

🏆 ${achievement.name}
${achievement.description}

Join me on ReadMe - the fun reading app for kids! 📚✨
https://readme-40267.web.app/''';

      await Share.share(
        message,
        subject: 'My ReadMe Achievement!',
      );
    } catch (e) {
      // Silently fail if share is cancelled or unavailable
    }
  }

  bool get _isLastAchievement =>
      _currentIndex == widget.achievements.length - 1;

  bool get _hasMultipleAchievements => widget.achievements.length > 1;

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievements[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildMainContent(achievement),
    );
  }

  Widget _buildMainContent(Achievement achievement) {
    return SafeArea(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildAchievementCard(achievement),
                const SizedBox(height: 40),
                _buildActionButtons(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasMultipleAchievements) ...[
            _buildAchievementCounter(),
            const SizedBox(height: 20),
          ],
          _buildTitle(),
          const SizedBox(height: 40),
          _buildBadge(),
          const SizedBox(height: 40),
          _buildAchievementName(achievement.name),
          const SizedBox(height: 16),
          _buildAchievementDescription(achievement.description),
          const SizedBox(height: 20),
          _buildPointsBadge(achievement.points),
        ],
      ),
    );
  }

  Widget _buildAchievementCounter() {
    return Text(
      'Achievement ${_currentIndex + 1} of ${widget.achievements.length}',
      style: AppTheme.body.copyWith(
        fontSize: 16,
        color: const Color(0xFF8E44AD),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTitle() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        'Achievement Unlocked!',
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
    return Stack(
      alignment: Alignment.center,
      children: [
        // Lottie animation in background
        Lottie.asset(
          'assets/animations/trophy_badge_animation.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          repeat: true,
        ),
        // Badge icon on top
        ScaleTransition(
          scale: _scaleAnimation,
          child: const Text(
            '🏆',
            style: TextStyle(fontSize: 120),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementName(String name) {
    return SlideTransition(
      position: _slideUpAnimation,
      child: Text(
        name,
        style: AppTheme.heading.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAchievementDescription(String description) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        description.isNotEmpty ? description : 'Keep up the great work!',
        style: AppTheme.body.copyWith(
          fontSize: 18,
          color: Colors.black54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPointsBadge(int points) {
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
          '+$points points',
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
    if (_hasMultipleAchievements && !_isLastAchievement) {
      return Column(
        children: [
          PrimaryButton(
            text: 'Next Achievement',
            onPressed: _nextAchievement,
          ),
          const SizedBox(height: 12),
          AppTextButton(
            text: 'Skip remaining',
            onPressed: _close,
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildShareButton(),
        const SizedBox(height: 12),
        _buildCloseButton(),
      ],
    );
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _shareAchievement,
        icon: const Icon(Icons.share),
        label: Text(
          'Share Achievement',
          style: AppTheme.buttonText.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          padding: EdgeInsets.symmetric(
            vertical: AppConstants.buttonVerticalPadding,
            horizontal: AppConstants.buttonHorizontalPadding,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _close,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: AppTheme.primaryPurple,
            width: 2,
          ),
          padding: EdgeInsets.symmetric(
            vertical: AppConstants.buttonVerticalPadding,
            horizontal: AppConstants.buttonHorizontalPadding,
          ),
        ),
        child: Text(
          'Close',
          style: AppTheme.body.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8E44AD),
          ),
        ),
      ),
    );
  }
}