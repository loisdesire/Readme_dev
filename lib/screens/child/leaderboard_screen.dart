import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rankedUsers = [];
  List<Map<String, dynamic>> _previousRankedUsers = [];
  bool _isLoading = true;
  int? _currentUserRank;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _currentUserId = authProvider.userId;

      // Fetch all users with achievement points
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalAchievementPoints', descending: true)
          .limit(100)
          .get();

      final rankedUsers = <Map<String, dynamic>>[];
      int rank = 1;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final points = data['totalAchievementPoints'] ?? 0;

        rankedUsers.add({
          'userId': doc.id,
          'username': data['username'] ?? 'Anonymous',
          'points': points,
          'rank': rank,
          'booksRead': data['totalBooksRead'] ?? 0,
          'streak': data['currentStreak'] ?? 0,
        });

        if (doc.id == _currentUserId) {
          _currentUserRank = rank;
        }

        rank++;
      }

      setState(() {
        _previousRankedUsers = List.from(_rankedUsers);
        _rankedUsers = rankedUsers;
        _isLoading = false;
      });

      appLog('[Leaderboard] Loaded ${rankedUsers.length} users', level: 'INFO');
    } catch (e) {
      appLog('[Leaderboard] Error loading: $e', level: 'ERROR');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text('🏆 Leaderboard', style: AppTheme.heading),
        backgroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: Column(
                children: [
                  // Current user rank banner
                  if (_currentUserRank != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurpleOpaque30,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$_currentUserRank',
                                style: AppTheme.heading.copyWith(
                                  color: AppTheme.primaryPurple,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Rank',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rankedUsers
                                          .firstWhere(
                                            (u) =>
                                                u['userId'] == _currentUserId,
                                            orElse: () => {'points': 0},
                                          )['points']
                                          .toString() +
                                      ' points',
                                  style: AppTheme.heading.copyWith(
                                    color: AppTheme.white,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.emoji_events,
                            color: AppTheme.amber,
                            size: 32,
                          ),
                        ],
                      ),
                    ),

                  // Leaderboard list
                  Expanded(
                    child: _rankedUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.leaderboard,
                                  size: 64,
                                  color: AppTheme.borderGray,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No rankings yet!',
                                  style: AppTheme.heading.copyWith(
                                    color: AppTheme.textGray,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Complete books to earn points',
                                  style: AppTheme.body.copyWith(
                                    color: AppTheme.textGray,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : AnimatedList(
                            key: GlobalKey<AnimatedListState>(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            initialItemCount: _rankedUsers.length,
                            itemBuilder: (context, index, animation) {
                              final user = _rankedUsers[index];
                              final isCurrentUser =
                                  user['userId'] == _currentUserId;
                              final rank = user['rank'];

                              return SlideTransition(
                                position: animation.drive(
                                  Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).chain(CurveTween(curve: Curves.easeOut)),
                                ),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: _buildRankingCard(
                                    rank: rank,
                                    username: user['username'],
                                    points: user['points'],
                                    booksRead: user['booksRead'],
                                    streak: user['streak'],
                                    isCurrentUser: isCurrentUser,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const AppBottomNav(currentTab: NavTab.leaderboard),
    );
  }

  Widget _buildRankingCard({
    required int rank,
    required String username,
    required int points,
    required int booksRead,
    required int streak,
    required bool isCurrentUser,
  }) {
    // Medal for top 3
    Widget? medal;
    Color? medalColor;
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFE8E8E8); // Bright silver, not grey
    const bronzeColor = Color(0xFFCD7F32);

    if (rank == 1) {
      medal = const Icon(Icons.workspace_premium, color: goldColor, size: 32);
      medalColor = goldColor;
    } else if (rank == 2) {
      medal = const Icon(Icons.workspace_premium, color: silverColor, size: 28);
      medalColor = silverColor;
    } else if (rank == 3) {
      medal = const Icon(Icons.workspace_premium, color: bronzeColor, size: 28);
      medalColor = bronzeColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFF3E5F5) : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? AppTheme.primaryPurple : AppTheme.borderGray,
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: AppTheme.defaultCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank or Medal
            SizedBox(
              width: 50,
              child: medal ??
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? AppTheme.primaryPurple
                          : AppTheme.borderGray,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: AppTheme.heading.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? AppTheme.white
                              : AppTheme.textGray,
                        ),
                      ),
                    ),
                  ),
            ),

            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: AppTheme.heading.copyWith(
                            color: isCurrentUser
                                ? AppTheme.primaryPurple
                                : AppTheme.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'YOU',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.book, size: 14, color: AppTheme.textGray),
                      const SizedBox(width: 4),
                      Text(
                        '$booksRead books',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textGray,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.local_fire_department,
                          size: 14, color: AppTheme.warningOrange),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: AppTheme.heading.copyWith(
                    fontSize: 24,
                    color: medalColor ?? AppTheme.primaryPurple,
                  ),
                ),
                Text(
                  'points',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
