import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../services/achievement_service.dart';
import '../../services/feedback_service.dart';

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

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

  IconData _getIconData(String emoji) {
    switch (emoji) {
      case 'book':
        return Icons.book;
      case 'menu_book':
        return Icons.menu_book;
      case 'favorite':
        return Icons.favorite;
      case 'auto_stories':
        return Icons.auto_stories;
      case 'library_books':
        return Icons.library_books;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'stars':
        return Icons.stars;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'diamond':
        return Icons.diamond;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'bolt':
        return Icons.bolt;
      case 'schedule':
        return Icons.schedule;
      case 'access_time':
        return Icons.access_time;
      case 'timer':
        return Icons.timer;
      case 'psychology':
        return Icons.psychology;
      case 'play_circle':
        return Icons.play_circle;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = widget.achievements[_currentIndex];
    final totalAchievements = widget.achievements.length;

    return Scaffold(
      backgroundColor: const Color(0xFF8E44AD),
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
                    // Badge count indicator (if multiple)
                    if (totalAchievements > 1) ...[
                      Text(
                        'Achievement ${_currentIndex + 1} of $totalAchievements',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Achievement Unlocked!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Badge with animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconData(achievement.emoji),
                          size: 80,
                          color: const Color(0xFF8E44AD),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Achievement name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        achievement.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const Spacer(),

                    // Action buttons
                    if (totalAchievements > 1 && _currentIndex < totalAchievements - 1)
                      // Next button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextAchievement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF8E44AD),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Next Achievement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      // Continue button (last or only achievement)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _close,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF8E44AD),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Skip button
                    if (totalAchievements > 1 && _currentIndex < totalAchievements - 1)
                      TextButton(
                        onPressed: _close,
                        child: const Text(
                          'Skip remaining',
                          style: TextStyle(
                            color: Colors.white70,
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
