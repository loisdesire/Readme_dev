import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';
import '../../widgets/profile_badges_widget.dart';
import 'library_screen.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Badges'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF8E44AD),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FeedbackService.instance.playTap();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LibraryScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Read more books!',
                style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 20 + bottomPadding),
        ],
      ),
    );
  }
}
