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
    IconData iconData;
    
    // Map emoji strings to Material icons
    switch (achievement.emoji) {
      case 'book':
        iconData = Icons.book;
        break;
      case 'menu_book':
        iconData = Icons.menu_book;
        break;
      case 'favorite':
        iconData = Icons.favorite;
        break;
      case 'auto_stories':
        iconData = Icons.auto_stories;
        break;
      case 'library_books':
        iconData = Icons.library_books;
        break;
      case 'emoji_events':
        iconData = Icons.emoji_events;
        break;
      case 'star':
        iconData = Icons.star;
        break;
      case 'stars':
        iconData = Icons.stars;
        break;
      case 'workspace_premium':
        iconData = Icons.workspace_premium;
        break;
      case 'military_tech':
        iconData = Icons.military_tech;
        break;
      case 'diamond':
        iconData = Icons.diamond;
        break;
      case 'crown':
        iconData = Icons.workspace_premium; // Crown not available, use premium
        break;
      case 'local_fire_department':
        iconData = Icons.local_fire_department;
        break;
      case 'whatshot':
        iconData = Icons.whatshot;
        break;
      case 'bolt':
        iconData = Icons.bolt;
        break;
      case 'schedule':
        iconData = Icons.schedule;
        break;
      case 'access_time':
        iconData = Icons.access_time;
        break;
      case 'timer':
        iconData = Icons.timer;
        break;
      case 'psychology':
        iconData = Icons.psychology;
        break;
      case 'play_circle':
        iconData = Icons.play_circle;
        break;
      case 'verified':
        iconData = Icons.verified;
        break;
      default:
        iconData = Icons.emoji_events; // Default badge icon
    }

    return Icon(
      iconData,
      color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
      size: 28,
    );
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
            // Simple dialog presentation (no analytics)
            showDialog(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: Row(
                    children: [
                      _getAchievementIcon(achievement),
                      const SizedBox(width: 12),
                      Expanded(child: Text(achievement.name)),
                    ],
                  ),
                  content: Text(achievement.description.isNotEmpty ? achievement.description : 'Achievement unlocked!'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E44AD)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Navigate to Library to 'read more books'
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
                      },
                      child: const Text('Read more books'),
                    ),
                  ],
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
