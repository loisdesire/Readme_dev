import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pressable_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🏆 Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
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
                          colors: [Color(0xFF8E44AD), Color(0xFFAB47BC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8E44AD).withOpacity(0.3),
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#$_currentUserRank',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8E44AD),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Rank',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_rankedUsers.firstWhere(
                                    (u) => u['userId'] == _currentUserId,
                                    orElse: () => {'points': 0},
                                  )['points']} points',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
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
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No rankings yet!',
                                  style: AppTheme.heading.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Complete books to earn points',
                                  style: AppTheme.body.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _rankedUsers.length,
                            itemBuilder: (context, index) {
                              final user = _rankedUsers[index];
                              final isCurrentUser = user['userId'] == _currentUserId;
                              final rank = user['rank'];

                              return _buildRankingCard(
                                rank: rank,
                                username: user['username'],
                                points: user['points'],
                                booksRead: user['booksRead'],
                                streak: user['streak'],
                                isCurrentUser: isCurrentUser,
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
    if (rank == 1) {
      medal = const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 32);
      medalColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      medal = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 28);
      medalColor = const Color(0xFFC0C0C0);
    } else if (rank == 3) {
      medal = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 28);
      medalColor = const Color(0xFFCD7F32);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFF3E5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? const Color(0xFF8E44AD) : const Color(0xFFE0E0E0),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                          ? const Color(0xFF8E44AD)
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.white : Colors.grey[700],
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
                                ? const Color(0xFF8E44AD)
                                : Colors.black87,
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
                            color: const Color(0xFF8E44AD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
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
                      Icon(Icons.book, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$booksRead books',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.local_fire_department,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: medalColor ?? const Color(0xFF8E44AD),
                  ),
                ),
                Text(
                  'points',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.grey[600],
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
