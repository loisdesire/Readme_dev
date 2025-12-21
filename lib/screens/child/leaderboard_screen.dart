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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadLeaderboard,
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        '🏆 Leaderboard',
                        style: AppTheme.heading.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Current user rank banner
                    if (_currentUserRank != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                    color:
                                        AppTheme.white.withValues(alpha: 0.7),
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
    // Medal for top 3 with distinct styling
    Widget? rankDisplay;
    Color? cardColor;
    Color? borderColor;
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    if (rank == 1) {
      rankDisplay = Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDAA520), Color(0xFFF0C050)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFFDAA520).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '👑',
            style: TextStyle(fontSize: 32),
          ),
        ),
      );
      cardColor = const Color(0xFFFFF8E7);
      borderColor = const Color(0xFFDAA520);
    } else if (rank == 2) {
      rankDisplay = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC0C0C0), Color(0xFFE8E8E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: silverColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥈',
            style: TextStyle(fontSize: 28),
          ),
        ),
      );
      cardColor = const Color(0xFFF5F5F5);
      borderColor = silverColor;
    } else if (rank == 3) {
      rankDisplay = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFFE89B6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: bronzeColor.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥉',
            style: TextStyle(fontSize: 28),
          ),
        ),
      );
      cardColor = const Color(0xFFFFF5EE);
      borderColor = bronzeColor;
    } else {
      // Regular ranks
      rankDisplay = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCurrentUser
                ? [const Color(0xFF8E44AD), const Color(0xFFA062BA)]
                : [const Color(0xFFF0F0F0), const Color(0xFFE0E0E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$rank',
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isCurrentUser ? Colors.white : AppTheme.textGray,
            ),
          ),
        ),
      );
      cardColor = isCurrentUser ? const Color(0xFFF3E5F5) : Colors.white;
      borderColor =
          isCurrentUser ? AppTheme.primaryPurple : AppTheme.borderGray;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: rank <= 3 ? 2 : (isCurrentUser ? 2 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: rank <= 3 ? 12 : 8,
            offset: Offset(0, rank <= 3 ? 6 : 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank or Medal
            rankDisplay,

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
                            fontSize: rank <= 3 ? 18 : 16,
                            fontWeight:
                                rank <= 3 ? FontWeight.w700 : FontWeight.w600,
                            color: rank <= 3
                                ? Colors.black87
                                : (isCurrentUser
                                    ? AppTheme.primaryPurple
                                    : Colors.black87),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E44AD), Color(0xFFA062BA)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple
                                    .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'YOU',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book,
                                size: 14, color: Color(0xFF1976D2)),
                            const SizedBox(width: 4),
                            Text(
                              '$booksRead',
                              style: AppTheme.bodySmall.copyWith(
                                color: const Color(0xFF1976D2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$streak',
                              style: AppTheme.bodySmall.copyWith(
                                color: const Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Points - emphasized
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: AppTheme.heading.copyWith(
                    fontSize: rank <= 3 ? 28 : 24,
                    fontWeight: FontWeight.w800,
                    color: rank == 1
                        ? goldColor
                        : rank == 2
                            ? const Color(0xFF757575)
                            : rank == 3
                                ? bronzeColor
                                : AppTheme.primaryPurple,
                  ),
                ),
                Text(
                  'points',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                    fontSize: 11,
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
