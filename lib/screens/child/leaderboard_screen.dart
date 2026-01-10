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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _currentUserId = authProvider.userId;

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

      // Trigger stagger animation after data loads
      _animationController.forward(from: 0.0);

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
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Leaderboard',
                        style: AppTheme.heading.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: _rankedUsers.isEmpty
                          ? const Center(child: Text('No rankings yet'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _rankedUsers.length,
                              itemBuilder: (context, index) {
                                final user = _rankedUsers[index];
                                // Staggered animation: each card cascades in
                                return AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    // Calculate delay for this item (50ms per item)
                                    final itemDelay = index * 0.05;
                                    final animationStart = itemDelay;
                                    final animationEnd = itemDelay + 0.3;
                                    
                                    // Calculate progress for this specific item
                                    final progress = Curves.easeOut.transform(
                                      (((_animationController.value - animationStart) / (animationEnd - animationStart))
                                          .clamp(0.0, 1.0)),
                                    );
                                    
                                    return Opacity(
                                      opacity: progress,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - progress)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildRankCard(
                                    user['rank'],
                                    user['username'],
                                    user['points'],
                                    user['booksRead'],
                                    user['streak'],
                                    user['userId'] == _currentUserId,
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

  Widget _buildRankCard(int rank, String name, int points, int books, int streak, bool isYou) {
    Color? backgroundColor;
    Color? borderColor;
    Widget? rankWidget;

    if (rank == 1) {
      backgroundColor = const Color(0xFFFFF8E1);
      borderColor = const Color(0xFFFFD700);
      rankWidget = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '👑',
            style: TextStyle(fontSize: 24),
          ),
        ),
      );
    } else if (rank == 2) {
      backgroundColor = const Color(0xFFF5F5F5);
      borderColor = const Color(0xFFC0C0C0);
      rankWidget = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFC0C0C0), Color(0xFF999999)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC0C0C0).withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥈',
            style: TextStyle(fontSize: 24),
          ),
        ),
      );
    } else if (rank == 3) {
      backgroundColor = const Color(0xFFFBE9E7);
      borderColor = const Color(0xFFCD7F32);
      rankWidget = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCD7F32).withValues(alpha: 0.3),
              spreadRadius: 2,
              blurRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥉',
            style: TextStyle(fontSize: 24),
          ),
        ),
      );
    } else {
      backgroundColor = isYou ? const Color(0xFFF3E5F5) : Colors.white;
      borderColor = isYou ? AppTheme.primaryPurple : AppTheme.borderGray;
      rankWidget = Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isYou ? AppTheme.primaryPurple : AppTheme.lightGray,
        ),
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isYou ? Colors.white : AppTheme.textGray,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor!, width: rank <= 3 ? 2 : 1),
        boxShadow: rank <= 3 ? AppTheme.elevatedCardShadow : AppTheme.defaultCardShadow,
      ),
      child: Row(
        children: [
          rankWidget,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTheme.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isYou)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'YOU',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book,
                            size: 12,
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$books',
                            style: AppTheme.bodySmall.copyWith(
                              color: const Color(0xFF2196F3),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$streak',
                            style: AppTheme.bodySmall.copyWith(
                              color: const Color(0xFFFF6B6B),
                              fontSize: 11,
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
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$points',
                style: AppTheme.heading.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? borderColor : AppTheme.primaryPurple,
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
    );
  }
}
