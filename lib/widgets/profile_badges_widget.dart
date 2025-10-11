import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';

class ProfileBadgesWidget extends StatelessWidget {
  final List<Achievement> achievements;

  const ProfileBadgesWidget({Key? key, required this.achievements}) : super(key: key);

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
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: achievements.map((achievement) {
        return _buildBadge(context, achievement);
      }).toList(),
    );
  }

  Widget _buildBadge(BuildContext context, Achievement achievement) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: achievement.isUnlocked ? const Color(0xFF8E44AD) : Colors.grey[300],
          child: Text(
            achievement.emoji.isNotEmpty ? achievement.emoji : '🏅',
            style: const TextStyle(fontSize: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          achievement.name,
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
    );
  }
}
