import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';

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
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCelebration();
  }

  void _initializeAnimations() {
    _confettiController = ConfettiController(
      duration: AppConstants.confettiDuration,
    );

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
  }

  void _startCelebration() {
    _confettiController.play();
    _animationController.forward();
    FeedbackService.instance.playSuccess();
  }

  void _nextAchievement() {
    if (_currentIndex < widget.achievements.length - 1) {
      setState(() {
        _currentIndex++;
        _animationController.reset();
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
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievements[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildMainContent(achievement),
          _buildConfetti(Alignment.topLeft, 0),
          _buildConfetti(Alignment.topRight, 3.14),
        ],
      ),
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
    return FadeTransition(
      opacity: _fadeAnimation,
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Text(
        '🏆',
        style: TextStyle(fontSize: 120),
      ),
    );
  }

  Widget _buildAchievementName(String name) {
    return FadeTransition(
      opacity: _fadeAnimation,
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
    return Container(
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

  Widget _buildConfetti(Alignment alignment, double direction) {
    return Align(
      alignment: alignment,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirection: direction,
        blastDirectionality: BlastDirectionality.directional,
        shouldLoop: false,
        colors: const [
          Colors.yellow,
          Colors.orange,
          Colors.pink,
          Colors.purple,
          Colors.blue,
          Colors.green,
        ],
        numberOfParticles: 15,
        gravity: 0.05,
        emissionFrequency: 0.03,
        minimumSize: const Size(8, 8),
        maximumSize: const Size(15, 15),
      ),
    );
  }
}