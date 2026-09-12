import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../theme/app_theme.dart';
import '../../utils/league_helper.dart';
import '../../widgets/common/user_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/daily_quest_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Sample local data for rendering; keep for league demo until real leaderboard is available.
  final List<Map<String, dynamic>> _users = List.generate(12, (i) {
    final pts = [2, 8, 22, 40][i % 4] + (i * 3);
    return {
      'id': 'u$i',
      'username': 'Reader ${i + 1}',
      'avatar': i % 3 == 0 ? '🧒' : '',
      'points': pts,
      'streak': (i % 7),
      'books': (i % 5) + 1,
    };
  });

  // The "Today's Goals" card below used to compute its three quests purely
  // from live UserProvider stats — nothing was ever persisted, and the
  // "+N stars" it displayed were never actually credited anywhere, even
  // though a complete, tested backend for exactly this (DailyQuestService)
  // already existed elsewhere in the codebase, just never called. Wired up
  // here: on load, upsert today's quest doc from the child's real stats,
  // and use its persisted completion/reward state instead. See
  // SECURITY.md's cleanup-pass entry.
  Map<String, dynamic>? _questDoc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDailyQuests());
  }

  Future<void> _loadDailyQuests() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = authProvider.userId;
    if (userId == null) return;

    final todayMinutes = userProvider.getTodayReadingMinutes();
    const dailyGoal = 15; // kept in sync with UserProvider.getDailyGoalProgress

    try {
      final questService = DailyQuestService(firestore: authProvider.firestore);
      final result = await questService.upsertTodayFromStats(
        userId: userId,
        minutesReadToday: todayMinutes,
        dailyGoalMinutes: dailyGoal,
        hasReadToday: todayMinutes > 0,
      );
      if (!mounted) return;
      setState(() => _questDoc = result.doc);

      if (result.awardedStars > 0) {
        // Refresh cached profile stats now that totalAchievementPoints /
        // allTimePoints were just incremented server-side.
        await authProvider.reloadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "All of today's quests complete! +${result.awardedStars} ⭐"),
              backgroundColor: AppTheme.primaryPurple,
            ),
          );
        }
      }
    } catch (_) {
      // Non-fatal: the card falls back to live-computed (unpersisted)
      // progress below if the quest doc never loads.
    }
  }

  Map<String, dynamic>? _quest(String key) {
    final raw = (_questDoc?['quests'] as Map?)?[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTop3ByLeagueSection(),
            const SizedBox(height: 16),
            _buildDailyGoalsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTop3ByLeagueSection() {
    // Group users by league
    final Map<League, List<Map<String, dynamic>>> byLeague = {};
    for (final u in _users) {
      final pts = (u['points'] as num?)?.toInt() ?? 0;
      final league = LeagueHelper.getLeague(pts);
      byLeague.putIfAbsent(league, () => []).add(u);
    }

    final checkpoints = [
      League.bronze,
      League.silver,
      League.gold,
      League.platinum,
      League.diamond,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: checkpoints.map((league) {
        final list = byLeague[league] ?? [];
        list.sort((a, b) => ((b['points'] as num?)?.toInt() ?? 0).compareTo((a['points'] as num?)?.toInt() ?? 0));
        final top = list.take(3).toList(growable: false);
        final color = Color(LeagueHelper.getLeagueColor(league));
        final title = LeagueHelper.getLeagueName(league);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18)),
              boxShadow: AppTheme.subtleCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('$title — Top 3', style: AppTheme.heading.copyWith(fontSize: 16)),
                    const Spacer(),
                    Text('${list.length} players', style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray)),
                  ],
                ),
                const SizedBox(height: 10),
                if (top.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Text('No players in $title yet', style: AppTheme.bodySmall)),
                  )
                else
                  AnimationLimiter(
                    child: Column(
                      children: List.generate(top.length, (index) {
                        final u = top[index];
                        final pts = (u['points'] as num?)?.toInt() ?? 0;
                        final name = (u['username'] as String?) ?? 'Reader';
                        final avatar = (u['avatar'] as String?)?.isNotEmpty == true ? u['avatar'] as String : '🧒';

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 420),
                          child: SlideAnimation(
                            verticalOffset: 24,
                            child: FadeInAnimation(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderGray.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  children: [
                                    _RankCircle(rank: index + 1, color: color),
                                    const SizedBox(width: 10),
                                    UserAvatar(avatar: avatar, size: 40, fontSize: 18),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(name, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600))),
                                    _StarsChip(points: pts),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildDailyGoalsCard() {
    // Use UserProvider for actual daily progress as the immediately-available
    // fallback; _questDoc (once loaded) carries the actually-persisted
    // completion/reward state from DailyQuestService, which wins when present.
    final userProv = Provider.of<UserProvider?>(context, listen: false);
    final todayMinutes = userProv?.getTodayReadingMinutes() ?? 0;
    final progress = userProv?.getDailyGoalProgress() ?? 0.0;
    const dailyGoal = 15; // kept in sync with UserProvider's internal goal

    final readGoalQuest = _quest(DailyQuestService.questReadGoal);
    final streakQuest = _quest(DailyQuestService.questKeepStreak);
    final miniReadQuest = _quest(DailyQuestService.questMiniRead);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.12)),
        boxShadow: AppTheme.subtleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flag, color: AppTheme.primaryPurple, size: 18),
            const SizedBox(width: 8),
            Text('Today\'s Goals', style: AppTheme.heading.copyWith(fontSize: 16)),
            const Spacer(),
            Text('${(progress * 100).round()}%', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _AnimatedProgressBar(progress: progress, color: AppTheme.primaryPurple, height: 12),
          const SizedBox(height: 12),
          _QuestRow(
            icon: Icons.menu_book,
            title: 'Read $dailyGoal minutes',
            completed: readGoalQuest?['completed'] == true || todayMinutes >= dailyGoal,
            stars: (readGoalQuest?['rewardStars'] as num?)?.toInt() ?? 5,
            progressFraction: progress,
            progressLabel: '$todayMinutes / $dailyGoal min',
          ),
          const SizedBox(height: 10),
          _QuestRow(
            icon: Icons.local_fire_department,
            title: 'Keep your streak',
            completed: streakQuest?['completed'] == true || todayMinutes > 0,
            stars: (streakQuest?['rewardStars'] as num?)?.toInt() ?? 3,
            progressFraction: todayMinutes > 0 ? 1.0 : 0.0,
            progressLabel: 'Read today',
          ),
          const SizedBox(height: 10),
          _QuestRow(
            icon: Icons.bolt,
            title: 'Do a mini read',
            completed: miniReadQuest?['completed'] == true || todayMinutes >= 2,
            stars: (miniReadQuest?['rewardStars'] as num?)?.toInt() ?? 2,
            progressFraction: (todayMinutes / 2).clamp(0.0, 1.0),
            progressLabel: todayMinutes >= 2 ? 'Done!' : 'Even 2 minutes counts',
          ),
        ],
      ),
    );
  }

}

class _RankCircle extends StatelessWidget {
  const _RankCircle({required this.rank, required this.color});
  final int rank;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12), border: Border.all(color: color)),
        child: Center(child: Text('#$rank', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700))),
      );

}

class _StarsChip extends StatelessWidget {
  const _StarsChip({required this.points});
  final int points;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text('$points ⭐', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppTheme.textGray)),
      );

}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.progress, required this.color, this.height = 10});
  final double progress;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.icon, required this.title, required this.completed, required this.stars, this.progressFraction, this.progressLabel});
  final IconData icon;
  final String title;
  final bool completed;
  final int stars;
  final double? progressFraction;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final accent = completed ? AppTheme.successGreen : AppTheme.primaryPurple;
    return Row(children: [
      Icon(icon, color: accent),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)), if (progressLabel != null) Text(progressLabel!, style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray))])),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Text('+$stars ⭐', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700)))
    ]);
  }
}
