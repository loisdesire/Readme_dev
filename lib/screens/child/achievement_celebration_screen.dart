import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/achievement_service.dart';
import '../../services/feedback_service.dart';
import '../../utils/app_constants.dart';
import '../../theme/app_theme.dart';

class AchievementCelebrationScreen extends StatefulWidget {
  final List<Achievement> achievements;

  const AchievementCelebrationScreen({
    super.key,
    required this.achievements,
  });

  @override
  State<AchievementCelebrationScreen> createState() => _AchievementCelebrationScreenState();
}

class _AchievementCelebrationScreenState extends State<AchievementCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: AppConstants.confettiDuration);
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

    // Start celebration
    _startCelebration();
  }

  void _startCelebration() {
    _confettiController.play();
    _animationController.forward();
    FeedbackService.instance.playSuccess();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
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
    try {
      FeedbackService.instance.playTap();
      
      // Capture screenshot of just the achievement card (excluding buttons)
      final image = await _screenshotController.capture();
      
      if (image == null) {
        // Fallback to text sharing if screenshot fails
        await _shareText();
        return;
      }
      
      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/achievement_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);
      
      // Share the image with a nice caption and link
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: '''🎉 Achievement Unlocked on ReadMe! 🏆

I just earned the "${achievement.name}" achievement!
${achievement.description}

Join me on ReadMe - the fun reading app for kids that makes learning exciting! 📚✨

Download now: https://play.google.com/store/apps/details?id=com.readme.app''',
      );
      
      // Clean up temporary file after sharing completes
      Future.delayed(const Duration(seconds: 30), () {
        if (imageFile.existsSync()) {
          imageFile.deleteSync();
        }
      });
      
    } catch (e) {
      // Fallback to text sharing if image sharing fails
      await _shareText();
    }
  }

  Future<void> _shareText() async {
    final achievement = widget.achievements[_currentIndex];
    try {
      final message = '''🎉 Achievement Unlocked!

🏆 ${achievement.name}
${achievement.description}

+${achievement.points} points earned!

📚 ReadMe - Making reading fun for kids!''';

      await Share.share(
        message,
        subject: 'My ReadMe Achievement!',
      );
      
      FeedbackService.instance.playTap();
    } catch (e) {
      // Silently fail if share is cancelled or unavailable
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievements[_currentIndex];
    final totalAchievements = widget.achievements.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.yellow,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.blue,
                Colors.green,
              ],
              numberOfParticles: 30,
              gravity: 0.3,
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Screenshot wrapper - only captures the card, not the buttons
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge count indicator (if multiple)
                            if (totalAchievements > 1) ...[
                              Text(
                                'Achievement ${_currentIndex + 1} of $totalAchievements',
                                style: AppTheme.body.copyWith(
                                  fontSize: 16,
                                  color: const Color(0xFF8E44AD),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Title
                            FadeTransition(
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
                            ),

                            const SizedBox(height: 40),

                            // Badge with animation
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: const Text(
                                '🏆',
                                style: TextStyle(
                                  fontSize: 120,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Achievement name
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                achievement.name,
                                style: AppTheme.heading.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Achievement description
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                achievement.description.isNotEmpty
                                    ? achievement.description
                                    : 'Keep up the great work!',
                                style: AppTheme.body.copyWith(
                                  fontSize: 18,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Points earned
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                                border: Border.all(
                                  color: const Color(0xFF8E44AD),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '+${achievement.points} points',
                                style: AppTheme.body.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8E44AD),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Action buttons (NOT included in screenshot)
                    if (totalAchievements > 1 && _currentIndex < totalAchievements - 1)
                      // Next button for multiple achievements
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextAchievement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E44AD),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppConstants.buttonVerticalPadding,
                              horizontal: AppConstants.buttonHorizontalPadding,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                            ),
                          ),
                          child: Text(
                            'Next Achievement',
                            style: AppTheme.buttonText.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Last or only achievement - show three buttons
                      SizedBox(
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
                            backgroundColor: const Color(0xFF8E44AD),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: AppConstants.buttonVerticalPadding,
                              horizontal: AppConstants.buttonHorizontalPadding,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _close,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8E44AD),
                            side: const BorderSide(
                              color: Color(0xFF8E44AD),
                              width: 2,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: AppConstants.buttonVerticalPadding,
                              horizontal: AppConstants.buttonHorizontalPadding,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
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
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Skip button for multiple achievements
                    if (totalAchievements > 1 && _currentIndex < totalAchievements - 1)
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          'Skip remaining',
                          style: AppTheme.body.copyWith(
                            color: const Color(0xFF8E44AD),
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
