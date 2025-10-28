import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../screens/child/library_screen.dart';

class ProfileBadgesWidget extends StatelessWidget {
  final List<Achievement> achievements;
  final bool showAll;
  final int maxCount;

  const ProfileBadgesWidget({
    super.key,
    required this.achievements,
    this.showAll = false,
    this.maxCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const Center(
        child: Text(
          'No badges yet. Start reading to earn achievements!',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    // Prioritize unlocked badges, then locked
    final sorted = [...achievements];
    sorted.sort((a, b) {
      if (a.isUnlocked == b.isUnlocked) return 0;
      return a.isUnlocked ? -1 : 1;
    });
    final display = showAll ? sorted : sorted.take(maxCount).toList();
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: display.map((achievement) {
        return _buildBadge(context, achievement);
      }).toList(),
    );
  }

  Widget _getAchievementIcon(Achievement achievement) {
    return Icon(
      _getIconData(achievement.emoji),
      color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
      size: 28,
    );
  }

  IconData _getIconData(String emoji) {
    // Map emoji strings to Material icons
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
      case 'crown':
        return Icons.workspace_premium; // Crown not available, use premium
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
        return Icons.emoji_events; // Default badge icon
    }
  }

  Widget _buildBadge(BuildContext context, Achievement achievement) {
    // Badge widget with tooltip (web/desktop) and dialog on tap (mobile)
    Widget badgeContent = SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: achievement.isUnlocked ? const Color(0xFF8E44AD) : Colors.grey[300],
            child: _getAchievementIcon(achievement),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: achievement.isUnlocked ? const Color(0xFF8E44AD) : Colors.grey,
            ),
          ),
          if (!achievement.isUnlocked)
            Text(
              'Locked',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: achievement.name,
        preferBelow: false,
        child: InkWell(
          onTap: () {
            // Polished dialog with app's purple theme
            showDialog(
              context: context,
              builder: (ctx) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge icon
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: achievement.isUnlocked 
                              ? const Color(0xFF8E44AD) 
                              : Colors.grey[300],
                          child: Icon(
                            _getIconData(achievement.emoji),
                            color: achievement.isUnlocked 
                                ? Colors.white 
                                : Colors.grey[600],
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Badge name
                        Text(
                          achievement.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8E44AD),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Badge description
                        Text(
                          achievement.description.isNotEmpty 
                              ? achievement.description 
                              : achievement.isUnlocked 
                                  ? 'Achievement unlocked!' 
                                  : 'Keep reading to unlock this badge!',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!achievement.isUnlocked) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E44AD),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LibraryScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Read Books',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: badgeContent,
        ),
      ),
    );
  }
}
