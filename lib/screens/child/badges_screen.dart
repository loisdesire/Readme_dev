import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../widgets/profile_badges_widget.dart';
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class BadgesScreen extends StatelessWidget {
  final List<Achievement> achievements;
  const BadgesScreen({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Group achievements by category
    final quiz = achievements.where((a) => a.category == 'quiz').toList();
    final streak = achievements.where((a) => a.category == 'streak').toList();
    final time = achievements.where((a) => a.category == 'time').toList();
    final reading = achievements.where((a) => a.category == 'reading').toList();
    final sessions = achievements.where((a) => a.category == 'sessions').toList();

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final hasUnlocked = unlockedCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('All Badges', style: AppTheme.heading),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF8E44AD),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          // Show encouraging message if no badges unlocked yet
          if (!hasUnlocked) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 80,
                      color: const Color(0x4D8E44AD),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Start Your Badge Collection!',
                      style: AppTheme.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Read books, build streaks, and complete\nreading sessions to unlock awesome badges!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Show progress summary
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: const Color(0xFF8E44AD), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$unlockedCount ${unlockedCount == 1 ? 'badge' : 'badges'} unlocked!',
                      style: AppTheme.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (quiz.isNotEmpty) ...[
            Text('Quiz', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: Color(0xFF8E44AD))),
            const SizedBox(height: 10),
            ProfileBadgesWidget(achievements: quiz, showAll: true),
            const SizedBox(height: 24),
          ],
          if (streak.isNotEmpty) ...[
            Text('Streak', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: Color(0xFF8E44AD))),
            const SizedBox(height: 10),
            ProfileBadgesWidget(achievements: streak, showAll: true),
            const SizedBox(height: 24),
          ],
          if (time.isNotEmpty) ...[
            Text('Time', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: Color(0xFF8E44AD))),
            const SizedBox(height: 10),
            ProfileBadgesWidget(achievements: time, showAll: true),
            const SizedBox(height: 24),
          ],
          if (reading.isNotEmpty) ...[
            Text('Books Read', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: Color(0xFF8E44AD))),
            const SizedBox(height: 10),
            ProfileBadgesWidget(achievements: reading, showAll: true),
            const SizedBox(height: 24),
          ],
          if (sessions.isNotEmpty) ...[
            Text('Sessions', style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: Color(0xFF8E44AD))),
            const SizedBox(height: 10),
            ProfileBadgesWidget(achievements: sessions, showAll: true),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 30),
          // Full-width button to library
          PrimaryButton(
            text: 'Read more books!',
            onPressed: () {
              FeedbackService.instance.playTap();
              Navigator.pop(context); // Go back to previous screen
            },
          ),
          SizedBox(height: 20 + bottomPadding),
        ],
      ),
      ),
    );
  }
}
