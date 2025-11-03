import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../screens/child/library_screen.dart';
import '../utils/icon_mapper.dart';

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

    // Use GridView to show exactly 4 badges per row
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: display.length,
      itemBuilder: (context, index) {
        return _buildBadge(context, display[index]);
      },
    );
  }

  Widget _getAchievementIcon(Achievement achievement) {
    return Icon(
      IconMapper.getAchievementIcon(achievement.emoji),
      color: achievement.isUnlocked ? Colors.white : Colors.grey[600],
      size: 28,
    );
  }

  Widget _buildBadge(BuildContext context, Achievement achievement) {
    // Badge widget with tooltip (web/desktop) and dialog on tap (mobile)
    Widget badgeContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: achievement.isUnlocked ? const Color(0xFF8E44AD) : Colors.grey,
            height: 1.2,
          ),
        ),
      ],
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
                            IconMapper.getAchievementIcon(achievement.emoji),
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
                        // Action buttons - centered and spaced
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8E44AD),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
