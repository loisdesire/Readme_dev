import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../screens/child/library_screen.dart';
import '../utils/icon_mapper.dart';
import '../theme/app_theme.dart';

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
      return Center(
        child: Text(
          'No badges yet. Start reading to earn achievements!',
          style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
        ),
      );
    }
    // Smart sorting:
    // 1. Unlocked badges first (most recent first)
    // 2. Then locked badges sorted by requiredValue (most achievable first)
    final sorted = [...achievements];
    sorted.sort((a, b) {
      // If one is unlocked and other is locked, unlocked comes first
      if (a.isUnlocked && !b.isUnlocked) return -1;
      if (!a.isUnlocked && b.isUnlocked) return 1;

      // If both are unlocked, keep their order (or could sort by unlockedAt)
      if (a.isUnlocked && b.isUnlocked) return 0;

      // If both are locked, sort by requiredValue (smaller = more achievable = comes first)
      return a.requiredValue.compareTo(b.requiredValue);
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
          style: AppTheme.bodySmall.copyWith(
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
                          style: AppTheme.heading.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8E44AD),
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
                          style: AppTheme.bodyMedium.copyWith(
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
                              style: AppTheme.bodySmall.copyWith(
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
                                child: Text(
                                  'Close',
                                  style: AppTheme.bodyMedium.copyWith(
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
                                child: Text(
                                  'Read Books',
                                  style: AppTheme.bodyMedium.copyWith(
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
