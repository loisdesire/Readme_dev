import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../services/feedback_service.dart';

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
    
    // Auto-close after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _close();
      }
    });
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
        color: Colors.black.withOpacity(0.5),
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
                          color: Colors.black.withOpacity(0.3),
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
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: _getAchievementIcon(),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // "Achievement Unlocked!" text
                        const Text(
                          'Achievement Unlocked! 🎉',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Achievement name
                        Text(
                          widget.achievement.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Achievement description
                        Text(
                          widget.achievement.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Points earned
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            '+${widget.achievement.points} points',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 25),
                        
                        // Close button
                        TextButton(
                          onPressed: _close,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Awesome!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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