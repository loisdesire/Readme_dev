import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/achievement_service.dart';
import '../services/feedback_service.dart';
import '../services/logger.dart';
import '../theme/app_theme.dart';

class AchievementPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onClose;

  const AchievementPopup({
    super.key,
    required this.achievement,
    this.onClose,
  });

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Play celebration sound
    FeedbackService.instance.playSuccess();

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _close() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose?.call();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _shareAchievement() async {
    try {
      final message = '''🎉 I just unlocked an achievement on ReadMe!

🏆 ${widget.achievement.name}
${widget.achievement.description}

Join me on ReadMe - the fun reading app for kids! 📚✨
https://readme-40267.web.app/''';

      await Share.share(
        message,
        subject: 'My ReadMe Achievement!',
      );
      
      appLog('[Achievement] Shared: ${widget.achievement.name}', level: 'INFO');
      
      // Play feedback
      FeedbackService.instance.playTap();
    } catch (e) {
      appLog('[Achievement] Share failed: $e', level: 'ERROR');
    }
  }

  Widget _getAchievementIcon() {
    if (widget.achievement.emoji.isEmpty) {
      return const Icon(Icons.star, size: 40, color: Colors.white);
    }

    // Map of icon names to IconData
    final iconMap = <String, IconData>{
      'book': Icons.book,
      'menu_book': Icons.menu_book,
      'favorite': Icons.favorite,
      'auto_stories': Icons.auto_stories,
      'library_books': Icons.library_books,
      'emoji_events': Icons.emoji_events,
      'star': Icons.star,
      'stars': Icons.stars,
      'workspace_premium': Icons.workspace_premium,
      'military_tech': Icons.military_tech,
      'diamond': Icons.diamond,
      'crown': Icons.star,  // Crown doesn't exist, use star
      'local_fire_department': Icons.local_fire_department,
      'whatshot': Icons.whatshot,
      'bolt': Icons.bolt,
      'schedule': Icons.schedule,
      'access_time': Icons.access_time,
      'timer': Icons.timer,
      'psychology': Icons.psychology,
      'play_circle': Icons.play_circle,
      'verified': Icons.verified,
    };

    // Check if emoji field contains an icon name
    final iconData = iconMap[widget.achievement.emoji];
    if (iconData != null) {
      return Icon(iconData, size: 40, color: Colors.white);
    }

    // Otherwise treat as emoji text
    return Text(
      widget.achievement.emoji,
      style: const TextStyle(fontSize: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E44AD), // Solid purple matching app theme
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          spreadRadius: 5,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trophy icon or emoji
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: _getAchievementIcon(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // "Achievement Unlocked!" text
                        Text(
                          'Achievement Unlocked! 🎉',
                          style: AppTheme.body.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Achievement name
                        Text(
                          widget.achievement.name,
                          style: AppTheme.heading.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Achievement description
                        Text(
                          widget.achievement.description,
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Points earned
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            '+${widget.achievement.points} points',
                            style: AppTheme.body.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Share button
                            TextButton.icon(
                              onPressed: () async {
                                await _shareAchievement();
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Icons.share, color: Colors.white, size: 18),
                              label: Text(
                                'Share',
                                style: AppTheme.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Close button
                            TextButton(
                              onPressed: _close,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(
                                'Awesome!',
                                style: AppTheme.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }


}