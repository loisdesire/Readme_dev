import 'dart:math' show Random, cos, max, min, pi, sin;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/app_scope.dart';
import '../../services/daily_quest_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/league_helper.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/common/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const int _communityGoalStep = 500;
  static const int _maxReadersShown = 10;

  final DailyQuestService _dailyQuestService = DailyQuestService();

  bool _isLoading = true;
  String? _currentUserId;
  List<Map<String, dynamic>> _rankedUsers = [];
  Map<String, dynamic>? _dailyQuestDoc;
  String? _lastCelebratedDateKey;

  int _clubStarsLast7Days = 0;
  int _yourContributionStarsLast7Days = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var clubStarsLast7Days = _clubStarsLast7Days;
    var yourContributionStarsLast7Days = _yourContributionStarsLast7Days;

    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      _currentUserId = authProvider.userId;
      final uid = _currentUserId;

      if (uid != null) {
        await userProvider.loadUserData(uid);

        final profile = userProvider.userProfile ?? authProvider.userProfile;
        final todayMinutes = userProvider.getTodayReadingMinutes();
        final dailyGoal =
            ((profile?['dailyReadingGoal'] as num?)?.toInt() ?? 15)
                .clamp(5, 60);
        final hasReadToday = userProvider.hasReadToday();

        final result = await _dailyQuestService.upsertTodayFromStats(
          userId: uid,
          minutesReadToday: todayMinutes,
          dailyGoalMinutes: dailyGoal,
          hasReadToday: hasReadToday,
        );

        _dailyQuestDoc = result.doc;

        if (result.awardedStars > 0 && mounted) {
          final dateKey = DailyQuestService.todayDateKey();
          if (_lastCelebratedDateKey != dateKey) {
            _lastCelebratedDateKey = dateKey;
            await _showDailyQuestCelebration(result.awardedStars);
          }
        }
      }

      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        final scoped = await FirebaseFirestore.instance
            .collection('users')
            .where('accountType', isEqualTo: 'child')
            .where(AppScope.userNamespaceField, isEqualTo: AppScope.namespace)
            .orderBy('totalAchievementPoints', descending: true)
            .limit(100)
            .get();
        docs = scoped.docs;
      } catch (_) {
        final fallback = await FirebaseFirestore.instance
            .collection('users')
            .where('accountType', isEqualTo: 'child')
            .orderBy('totalAchievementPoints', descending: true)
            .limit(100)
            .get();
        docs = fallback.docs;
      }

      _rankedUsers = docs.map((d) {
        final data = d.data();
        final points = ((data['totalAchievementPoints'] as num?)?.toInt() ?? 0);
        final allTimePoints =
            ((data['allTimePoints'] as num?)?.toInt() ?? points);
        return {
          'id': d.id,
          'username': (data['username'] ?? data['displayName'] ?? 'Reader'),
          'avatar': (data['avatar'] ?? '').toString(),
          'points': points,
          'allTimePoints': allTimePoints,
          'streak': ((data['dailyReadingStreak'] as num?)?.toInt() ??
              (data['streak'] as num?)?.toInt() ??
              0),
          'books': ((data['booksRead'] as num?)?.toInt() ??
              (data['totalBooksRead'] as num?)?.toInt() ??
              0),
        };
      }).toList();

      if (uid != null && _rankedUsers.isNotEmpty) {
        final weekly = await _computeLast7DaysClubStats(
          userIds: _rankedUsers
              .map((u) => u['id'])
              .whereType<String>()
              .toList(growable: false),
          currentUserId: uid,
        );
        clubStarsLast7Days = weekly.clubStars;
        yourContributionStarsLast7Days = weekly.yourStars;
      }
    } catch (_) {
      // Keep prior state if load fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _clubStarsLast7Days = clubStarsLast7Days;
          _yourContributionStarsLast7Days = yourContributionStarsLast7Days;
        });
      }
    }
  }

  Future<({int clubStars, int yourStars})> _computeLast7DaysClubStats({
    required List<String> userIds,
    required String currentUserId,
  }) async {
    // Rolling window: today + previous 6 days.
    final now = DateTime.now();
    final start =
        AppDateUtils.startOfDay(now.subtract(const Duration(days: 6)));
    final endExclusive =
        AppDateUtils.startOfDay(now.add(const Duration(days: 1)));
    final startKey = AppDateUtils.formatDateKey(start);
    final endKeyExclusive = AppDateUtils.formatDateKey(endExclusive);

    var clubStars = 0;
    var yourStars = 0;

    // Sequential to avoid spamming Firestore with 100 concurrent queries.
    for (final userId in userIds) {
      final stars = await _fetchRollingQuestRewardStars(
        userId: userId,
        startKey: startKey,
        endKeyExclusive: endKeyExclusive,
      );
      clubStars += stars;
      if (userId == currentUserId) {
        yourStars = stars;
      }
    }

    return (clubStars: clubStars, yourStars: yourStars);
  }

  Future<int> _fetchRollingQuestRewardStars({
    required String userId,
    required String startKey,
    required String endKeyExclusive,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(DailyQuestService.collectionName)
          .orderBy(FieldPath.documentId)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
          .where(FieldPath.documentId, isLessThan: endKeyExclusive)
          .get();

      var sum = 0;
      for (final d in snap.docs) {
        final data = d.data();
        if (data['rewarded'] == true) {
          sum += ((data['rewardedStars'] as num?)?.toInt() ?? 0);
        }
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();

    final uid = _currentUserId ?? authProvider.userId;
    final profile = userProvider.userProfile ?? authProvider.userProfile;
    final username = _pickUsername(profile) ?? 'Reader';

    final todayMinutes = userProvider.getTodayReadingMinutes();
    final dailyGoal =
        ((profile?['dailyReadingGoal'] as num?)?.toInt() ?? 15).clamp(5, 60);
    final hasReadToday = userProvider.hasReadToday();
    final dailyProgress =
        dailyGoal == 0 ? 0.0 : (todayMinutes / dailyGoal).clamp(0.0, 1.0);

    final you = _findUser(uid);
    final leaderboardPoints =
        ((profile?['totalAchievementPoints'] as num?)?.toInt()) ??
            ((you?['points'] as num?)?.toInt() ?? 0);
    final leaguePoints = ((profile?['allTimePoints'] as num?)?.toInt()) ??
        ((you?['allTimePoints'] as num?)?.toInt() ?? leaderboardPoints);

    final yourAvatarRaw = (profile?['avatar'] as String?)?.trim();
    final yourAvatar = (yourAvatarRaw != null && yourAvatarRaw.isNotEmpty)
        ? yourAvatarRaw
        : (you?['avatar'] as String? ?? '🧒');

    // Club progress is rolling last 7 days, not daily.
    final communityPoints = _clubStarsLast7Days;
    final communityGoal = _nextCommunityGoal(communityPoints);
    final communityProgress = communityGoal == 0
        ? 0.0
        : (communityPoints / communityGoal).clamp(0.0, 1.0);

    final sorted = _sortedByPoints(_rankedUsers);
    final yourRank = _rankInSorted(sorted, uid);
    final topPoints =
        sorted.isEmpty ? 0 : ((sorted.first['points'] as num?)?.toInt() ?? 0);
    final gapToFirst = max(0, topPoints - leaderboardPoints);

    bool completed(String key) {
      final questsRaw = _dailyQuestDoc?['quests'];
      final quests = questsRaw is Map ? questsRaw : null;
      final q = quests?[key];
      return (q is Map) && q['completed'] == true;
    }

    int rewardStars(String key) {
      const fallback = {
        DailyQuestService.questReadGoal: 5,
        DailyQuestService.questKeepStreak: 3,
        DailyQuestService.questMiniRead: 2,
      };
      final questsRaw = _dailyQuestDoc?['quests'];
      final quests = questsRaw is Map ? questsRaw : null;
      final q = quests?[key];
      final raw = (q is Map) ? q['rewardStars'] : null;
      return (raw as num?)?.toInt() ?? fallback[key] ?? 0;
    }

    final readGoalCompleted = completed(DailyQuestService.questReadGoal);
    final streakCompleted = completed(DailyQuestService.questKeepStreak);
    final miniReadCompleted = completed(DailyQuestService.questMiniRead);
    final readGoalRewardStars = rewardStars(DailyQuestService.questReadGoal);
    final streakRewardStars = rewardStars(DailyQuestService.questKeepStreak);
    final miniReadRewardStars = rewardStars(DailyQuestService.questMiniRead);

    final questStarsTotal =
        readGoalRewardStars + streakRewardStars + miniReadRewardStars;
    final questStarsEarned = (readGoalCompleted ? readGoalRewardStars : 0) +
        (streakCompleted ? streakRewardStars : 0) +
        (miniReadCompleted ? miniReadRewardStars : 0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                  children: [
                    _buildHeroRankCard(
                      username: username,
                      yourAvatar: yourAvatar,
                      yourRank: yourRank,
                      gapToFirst: gapToFirst,
                      totalPoints: leaguePoints,
                      todayMinutes: todayMinutes,
                      questStarsEarned: questStarsEarned,
                      questStarsTotal: questStarsTotal,
                    ),
                    const SizedBox(height: 14),
                    _buildLeagueJourneyCard(totalPoints: leaguePoints),
                    const SizedBox(height: 14),
                    _buildBoostCard(
                      todayMinutes: todayMinutes,
                      dailyGoalMinutes: dailyGoal,
                      dailyProgress: dailyProgress,
                      hasReadToday: hasReadToday,
                      streakDays: (you?['streak'] as num?)?.toInt() ??
                          userProvider.dailyReadingStreak,
                      readGoalCompleted: readGoalCompleted,
                      streakCompleted: streakCompleted,
                      miniReadCompleted: miniReadCompleted,
                      readGoalRewardStars: readGoalRewardStars,
                      streakRewardStars: streakRewardStars,
                      miniReadRewardStars: miniReadRewardStars,
                      rewardedToday: _dailyQuestDoc?['rewarded'] == true,
                    ),
                    const SizedBox(height: 14),
                    _buildClubAndRankingsCard(
                      communityPoints: communityPoints,
                      communityGoal: communityGoal,
                      communityProgress: communityProgress,
                      totalReaders: _rankedUsers.length,
                      yourContributionStarsLast7Days:
                          _yourContributionStarsLast7Days,
                      currentUserId: uid,
                      yourAvatar: yourAvatar,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: NavTab.leaderboard),
    );
  }

  String? _pickUsername(Map<String, dynamic>? profile) {
    final raw = (profile?['username'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final raw2 = (profile?['displayName'] as String?)?.trim();
    if (raw2 != null && raw2.isNotEmpty) return raw2;
    return null;
  }

  Map<String, dynamic>? _findUser(String? uid) {
    if (uid == null) return null;
    for (final u in _rankedUsers) {
      if (u['id'] == uid) return u;
    }
    return null;
  }

  int _nextCommunityGoal(int points) {
    if (points <= 0) return _communityGoalStep;
    return ((points ~/ _communityGoalStep) + 1) * _communityGoalStep;
  }

  List<Map<String, dynamic>> _sortedByPoints(List<Map<String, dynamic>> users) {
    final list = List<Map<String, dynamic>>.from(users);
    list.sort((a, b) {
      final ap = ((a['points'] as num?)?.toInt() ?? 0);
      final bp = ((b['points'] as num?)?.toInt() ?? 0);
      return bp.compareTo(ap);
    });
    return list;
  }

  int _rankInSorted(List<Map<String, dynamic>> sorted, String? uid) {
    if (uid == null) return 0;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i]['id'] == uid) return i + 1;
    }
    return 0;
  }

  League? _nextLeague(League league) {
    switch (league) {
      case League.bronze:
        return League.silver;
      case League.silver:
        return League.gold;
      case League.gold:
        return League.platinum;
      case League.platinum:
        return League.diamond;
      case League.diamond:
        return null;
    }
  }

  Widget _buildHeroRankCard({
    required String username,
    required String yourAvatar,
    required int yourRank,
    required int gapToFirst,
    required int totalPoints,
    required int todayMinutes,
    required int questStarsEarned,
    required int questStarsTotal,
  }) {
    final league = LeagueHelper.getLeague(totalPoints);
    final leagueName = LeagueHelper.getLeagueName(league);
    final leagueEmoji = LeagueHelper.getLeagueEmoji(league);
    final leagueColor = Color(LeagueHelper.getLeagueColor(league));

    final title = yourRank > 0
        ? 'You’re #$yourRank in your club!'
        : 'You’re growing as a reader!';
    final sub = yourRank <= 1
        ? 'You’re leading — keep it up, $username.'
        : gapToFirst == 0
            ? 'You’re right near the top.'
            : 'Only $gapToFirst ⭐ behind #1.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          UserAvatar(
            avatar: yourAvatar,
            size: 78,
            fontSize: 34,
            backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.14),
            borderColor: AppTheme.primaryPurple,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTheme.heading.copyWith(
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.emoji_events,
                label: '$leagueEmoji $leagueName',
                color: leagueColor,
              ),
              _InfoPill(
                icon: Icons.timer,
                label: 'Today: $todayMinutes min',
                color: AppTheme.primaryPurple,
              ),
              _InfoPill(
                icon: Icons.stars,
                label: 'Today ⭐: $questStarsEarned/$questStarsTotal',
                color: AppTheme.accentGold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueJourneyCard({required int totalPoints}) {
    final league = LeagueHelper.getLeague(totalPoints);
    final leagueColor = Color(LeagueHelper.getLeagueColor(league));
    final next = _nextLeague(league);
    final nextName = next == null ? 'Max' : LeagueHelper.getLeagueName(next);
    final nextEmoji = next == null ? '🏆' : LeagueHelper.getLeagueEmoji(next);

    final isMax = league == League.diamond;
    final progress = LeagueHelper.getCurrentLeagueProgress(totalPoints);
    final frac = isMax
        ? 1.0
        : progress.total == 0
            ? 0.0
            : (progress.current / progress.total).clamp(0.0, 1.0);
    final progressText =
        isMax ? 'MAX' : '${progress.current}/${progress.total} ⭐';

    const checkpoints = [
      League.bronze,
      League.silver,
      League.gold,
      League.platinum,
      League.diamond,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: leagueColor.withValues(alpha: 0.22)),
        boxShadow: AppTheme.subtleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: leagueColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'League journey',
                  style: AppTheme.heading.copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: checkpoints.map((l) {
              final isCurrent = l == league;
              final reached =
                  checkpoints.indexOf(l) <= checkpoints.indexOf(league);
              final c = Color(LeagueHelper.getLeagueColor(l));
              final e = LeagueHelper.getLeagueEmoji(l);
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? c.withValues(alpha: 0.14)
                            : AppTheme.borderGray.withValues(alpha: 0.30),
                        border: Border.all(
                          color: isCurrent ? c : c.withValues(alpha: 0.35),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 18,
                            color:
                                reached ? AppTheme.black87 : AppTheme.textGray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LeagueHelper.getLeagueName(l),
                      style: AppTheme.bodySmall.copyWith(
                        color: reached ? AppTheme.black87 : AppTheme.textGray,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnimatedProgressBar(
                  progress: frac,
                  color: leagueColor,
                  height: 12,
                  backgroundColor: leagueColor.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                progressText,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isMax ? 'Max league unlocked' : 'Next: $nextEmoji $nextName',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubAndRankingsCard({
    required int communityPoints,
    required int communityGoal,
    required double communityProgress,
    required int totalReaders,
    required int yourContributionStarsLast7Days,
    required String? currentUserId,
    required String yourAvatar,
  }) {
    final sorted = _sortedByPoints(_rankedUsers);

    final display = <Map<String, dynamic>>[];
    for (final u in sorted) {
      if (display.length >= _maxReadersShown) break;
      final isYou = currentUserId != null && u['id'] == currentUserId;
      display.add({...u, 'isYou': isYou});
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: AppTheme.subtleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: AppTheme.primaryPurple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your Reading Club',
                  style: AppTheme.heading.copyWith(
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.borderGray.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalReaders readers',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.borderGray.withValues(alpha: 0.85),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your club contribution (last 7 days)',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textGray,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stars you earned for the club (rolling)',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  yourContributionStarsLast7Days <= 0
                      ? '0 ⭐'
                      : '+$yourContributionStarsLast7Days ⭐',
                  style: AppTheme.heading.copyWith(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 16,
                color: AppTheme.textGray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Club Progress',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$communityPoints/$communityGoal ⭐',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AnimatedProgressBar(
            progress: communityProgress,
            color: AppTheme.primaryPurple,
            height: 12,
            backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: AppTheme.borderGray.withValues(alpha: 0.80),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryPurple,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Top Readers',
                  style: AppTheme.heading.copyWith(
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Top ${min(_maxReadersShown, sorted.length)}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (display.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No readers yet')),
            )
          else
            AnimationLimiter(
              child: Column(
                children: List.generate(display.length, (index) {
                  final u = display[index];
                  final isYou = u['isYou'] == true;
                  final points = ((u['points'] as num?)?.toInt() ?? 0);
                  final streak = ((u['streak'] as num?)?.toInt() ?? 0);
                  final books = ((u['books'] as num?)?.toInt() ?? 0);
                  final safeStreak = max(0, streak);
                  final safeBooks = max(0, books);
                  final nameRaw = (u['username'] ?? 'Reader').toString().trim();
                  final name = nameRaw.isEmpty ? 'Reader' : nameRaw;
                  final avatarRaw = (u['avatar'] ?? '').toString();
                  final avatar = isYou
                      ? yourAvatar
                      : (avatarRaw.trim().isEmpty ? '🧒' : avatarRaw);

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 420),
                    child: SlideAnimation(
                      verticalOffset: 18,
                      child: FadeInAnimation(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isYou
                                ? AppTheme.primaryPurple.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isYou
                                  ? AppTheme.primaryPurple
                                      .withValues(alpha: 0.20)
                                  : AppTheme.borderGray,
                            ),
                          ),
                          child: Row(
                            children: [
                              _RankBadge(rank: index + 1, isYou: isYou),
                              const SizedBox(width: 10),
                              UserAvatar(
                                avatar: avatar,
                                size: 42,
                                fontSize: 22,
                                backgroundColor: isYou
                                    ? AppTheme.primaryPurple
                                        .withValues(alpha: 0.14)
                                    : AppTheme.primaryPurple
                                        .withValues(alpha: 0.08),
                                borderColor: isYou
                                    ? AppTheme.primaryPurple
                                    : AppTheme.primaryPurple
                                        .withValues(alpha: 0.50),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isYou
                                          ? '$name (you)'
                                          : (index == 0 ? '👑 $name' : name),
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.menu_book_rounded,
                                          size: 14,
                                          color: AppTheme.primaryPurple,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$safeBooks',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.primaryPurple,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          Icons.local_fire_department_rounded,
                                          size: 14,
                                          color: AppTheme.warningOrange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$safeStreak',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.warningOrange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StarsChip(points: points, isYou: isYou),
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
    );
  }

  Widget _buildBoostCard({
    required int todayMinutes,
    required int dailyGoalMinutes,
    required double dailyProgress,
    required bool hasReadToday,
    required int streakDays,
    required bool readGoalCompleted,
    required bool streakCompleted,
    required bool miniReadCompleted,
    required int readGoalRewardStars,
    required int streakRewardStars,
    required int miniReadRewardStars,
    required bool rewardedToday,
  }) {
    final allDone = readGoalCompleted && streakCompleted && miniReadCompleted;
    final completedCount = (readGoalCompleted ? 1 : 0) +
        (streakCompleted ? 1 : 0) +
        (miniReadCompleted ? 1 : 0);

    final readGoalFrac = dailyGoalMinutes <= 0
        ? 0.0
        : (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0);

    final miniTargetMinutes = 2;
    final miniCurrent = min(todayMinutes, miniTargetMinutes);
    final miniFrac = miniTargetMinutes <= 0
        ? 0.0
        : (todayMinutes / miniTargetMinutes).clamp(0.0, 1.0);

    final readGoalRow = _QuestRow(
      icon: Icons.menu_book,
      title: 'Read $dailyGoalMinutes minutes',
      subtitle: '',
      completed: readGoalCompleted,
      stars: readGoalRewardStars,
      baseAccent: AppTheme.primaryPurple,
      progressFraction: readGoalFrac,
      progressLabel: '$todayMinutes / $dailyGoalMinutes min',
    );

    final streakRow = _QuestRow(
      icon: Icons.local_fire_department,
      title: 'Keep your streak',
      subtitle: '',
      completed: streakCompleted,
      stars: streakRewardStars,
      baseAccent: AppTheme.warningOrange,
      progressFraction: hasReadToday ? 1.0 : 0.0,
      progressLabel:
          hasReadToday ? 'Done today • $streakDays day streak' : 'Read today',
    );

    final miniReadRow = _QuestRow(
      icon: Icons.timer,
      title: 'Mini read ($miniTargetMinutes min)',
      subtitle: '',
      completed: miniReadCompleted,
      stars: miniReadRewardStars,
      baseAccent: AppTheme.accentGold,
      progressFraction: miniFrac,
      progressLabel: '$miniCurrent / $miniTargetMinutes min',
    );

    final visibleRows = <Widget>[
      readGoalRow,
      const SizedBox(height: 12),
      streakRow,
      const SizedBox(height: 12),
      miniReadRow,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.16),
        ),
        boxShadow: AppTheme.subtleCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.flag, color: AppTheme.primaryPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Today’s Boost',
                    style: AppTheme.heading.copyWith(
                      fontSize: 18,
                    ),
                  ),
                ),
                _QuestStatusPill(
                  allDone: allDone,
                  rewardedToday: rewardedToday,
                  progressText: '$completedCount/3',
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.primaryPurple.withValues(alpha: 0.14),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visibleRows,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyQuestCelebration(int stars) async {
    if (!mounted) return;

    await HapticFeedback.mediumImpact();

    if (!mounted) return;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Quest Party',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, __) {
        return _QuestPartyOverlay(
          stars: stars,
          onClose: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestStatusPill extends StatelessWidget {
  const _QuestStatusPill({
    required this.allDone,
    required this.rewardedToday,
    this.progressText,
  });

  final bool allDone;
  final bool rewardedToday;
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    final text = rewardedToday
        ? 'Rewarded'
        : (progressText?.trim().isNotEmpty ?? false)
            ? progressText!.trim()
            : allDone
                ? 'Complete!'
                : 'In progress';
    final color = rewardedToday
        ? AppTheme.accentGold
        : allDone
            ? Colors.green
            : AppTheme.primaryPurple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rewardedToday
                ? Icons.workspace_premium
                : allDone
                    ? Icons.check_circle
                    : Icons.timelapse,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.stars,
    required this.baseAccent,
    this.progressFraction,
    this.progressLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool completed;
  final int stars;
  final Color baseAccent;
  final double? progressFraction;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final accent = completed ? AppTheme.successGreen : baseAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (subtitle.trim().isNotEmpty)
                  Text(subtitle, style: AppTheme.bodySmall),
                if (progressFraction != null) ...[
                  const SizedBox(height: 8),
                  _AnimatedProgressBar(
                    progress: (progressFraction ?? 0.0).clamp(0.0, 1.0),
                    color: accent,
                    height: 6,
                    backgroundColor: Colors.white,
                  ),
                  if (progressLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      progressLabel!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppTheme.borderGray),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  completed ? Icons.check_circle : Icons.stars,
                  size: 14,
                  color: completed ? Colors.green : AppTheme.accentGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '$stars ⭐',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.isYou});

  final int rank;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    final numberStyle = AppTheme.bodySmall
        .copyWith(fontWeight: FontWeight.w600, color: AppTheme.black87);
    late final Widget child;

    if (rank == 1) {
      bg = AppTheme.accentGold.withValues(alpha: 0.20);
      border = AppTheme.accentGold.withValues(alpha: 0.55);
      child = Text('1', style: numberStyle);
    } else if (rank == 2) {
      bg = AppTheme.borderGray.withValues(alpha: 0.30);
      border = AppTheme.borderGray;
      child = Text('2', style: numberStyle);
    } else if (rank == 3) {
      bg = AppTheme.warningOrange.withValues(alpha: 0.18);
      border = AppTheme.warningOrange.withValues(alpha: 0.45);
      child = Text('3', style: numberStyle);
    } else {
      bg = isYou
          ? AppTheme.primaryPurple.withValues(alpha: 0.16)
          : AppTheme.borderGray.withValues(alpha: 0.30);
      border = isYou
          ? AppTheme.primaryPurple.withValues(alpha: 0.30)
          : AppTheme.borderGray;
      child = Text(
        '$rank',
        style: numberStyle,
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Center(child: child),
    );
  }
}

class _StarsChip extends StatelessWidget {
  const _StarsChip({required this.points, required this.isYou});

  final int points;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final bg =
        isYou ? AppTheme.accentGold.withValues(alpha: 0.16) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isYou
              ? AppTheme.accentGold.withValues(alpha: 0.35)
              : AppTheme.borderGray,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars, size: 16, color: AppTheme.accentGold),
          const SizedBox(width: 6),
          Text(
            '$points',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({
    required this.progress,
    required this.color,
    required this.height,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final double height;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Container(height: height, color: backgroundColor),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  final fillW = (w * value).clamp(0.0, w);
                  return Container(height: height, width: fillW, color: color);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestPartyOverlay extends StatefulWidget {
  const _QuestPartyOverlay({required this.stars, required this.onClose});

  final int stars;
  final VoidCallback onClose;

  @override
  State<_QuestPartyOverlay> createState() => _QuestPartyOverlayState();
}

class _QuestPartyOverlayState extends State<_QuestPartyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pieces = _ConfettiPiece.generate(70);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.primaryPurple;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter:
                      _ConfettiPainter(t: _controller.value, pieces: _pieces),
                );
              },
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.borderGray),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: cardColor.withValues(alpha: 0.30),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.celebration,
                            color: Colors.white, size: 34),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Daily Quests Complete!',
                      style: AppTheme.heading.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You finished all your quests today.',
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.textGray),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.accentGold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars,
                              color: AppTheme.accentGold, size: 22),
                          const SizedBox(width: 10),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: widget.stars),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutBack,
                            builder: (context, value, _) {
                              return Text(
                                '+$value ⭐',
                                style: AppTheme.heading.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.black87,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await HapticFeedback.selectionClick();
                          widget.onClose();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'YAY!',
                          style: AppTheme.buttonTextOnColor.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap YAY! to continue',
                      style:
                          AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.color,
    required this.shape,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  final Color color;
  final int shape;

  static List<_ConfettiPiece> generate(int count) {
    final rnd = Random();
    final colors = <Color>[
      AppTheme.primaryPurple,
      AppTheme.primaryLight,
      AppTheme.primaryMediumLight,
      AppTheme.accentGold,
      AppTheme.secondaryYellow,
      AppTheme.successGreen,
      AppTheme.warningOrange,
    ];
    return List.generate(count, (_) {
      return _ConfettiPiece(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        size: 4 + rnd.nextDouble() * 6,
        speed: 0.6 + rnd.nextDouble() * 1.4,
        phase: rnd.nextDouble() * pi * 2,
        color: colors[rnd.nextInt(colors.length)],
        shape: rnd.nextInt(3),
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.pieces});

  final double t;
  final List<_ConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final dx = (p.x * size.width) + (cos(p.phase + t * 2 * pi) * 18);
      final dy = ((p.y + t * p.speed) % 1.0) * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: 0.90);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset(dx, dy), p.size * 0.55, paint);
          break;
        case 1:
          final r = Rect.fromCenter(
            center: Offset(dx, dy),
            width: p.size,
            height: p.size,
          );
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(sin(p.phase + t * 2 * pi) * 0.8);
          canvas.translate(-dx, -dy);
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(p.size * 0.25)),
            paint,
          );
          canvas.restore();
          break;
        default:
          final path = Path();
          final spikes = 5;
          final outer = p.size * 0.7;
          final inner = p.size * 0.32;
          for (var i = 0; i < spikes * 2; i++) {
            final a = (i / (spikes * 2)) * pi * 2;
            final radius = i.isEven ? outer : inner;
            final sx = dx + cos(a + p.phase) * radius;
            final sy = dy + sin(a + p.phase) * radius;
            if (i == 0) {
              path.moveTo(sx, sy);
            } else {
              path.lineTo(sx, sy);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
