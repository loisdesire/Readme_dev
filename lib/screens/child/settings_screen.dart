import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/achievement_service.dart';
import '../../widgets/profile_badges_widget.dart';
import '../../providers/book_provider.dart';
import '../parent/parent_dashboard_screen.dart';
import 'badges_screen.dart';
import 'profile_edit_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../services/feedback_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _readAloudEnabled = true;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF8E44AD),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            
            // Settings content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Consumer2<AuthProvider, UserProvider>(
                  builder: (context, authProvider, userProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Section
                        _buildSectionHeader('Profile'),
                        _buildProfileCard(authProvider, userProvider),
                        const SizedBox(height: 16),
                        // Badges Section (title outside card)
                        _buildSectionHeader('Badges'),
                        FutureBuilder<List<Achievement>>(
                          future: AchievementService().getUserAchievements(),
                          builder: (context, snapshot) {
                            final achievements = snapshot.data ?? [];
                            return PressableCard(
                              onTap: () {
                                FeedbackService.instance.playTap();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BadgesScreen(achievements: achievements)),
                                );
                              },
                              child: _buildBadgesCard(achievements, showLabel: false),
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        
                        // Reading Preferences
                        _buildSectionHeader('Reading Preferences'),
                        _buildSettingsCard([
                          _buildSwitchTile(
                            'Read Aloud',
                            'Enable text-to-speech while reading',
                            Icons.record_voice_over,
                            _readAloudEnabled,
                            (value) {
                              setState(() {
                                _readAloudEnabled = value;
                              });
                            },
                          ),
                        ]),
                        
                        const SizedBox(height: 30),
                        
                        // App Settings
                        _buildSectionHeader('App Settings'),
                        _buildSettingsCard([
                          // Feedback toggle (sounds & animations)
                          _buildSwitchTile(
                            'Play sounds & animations',
                            'Enable confetti, chimes and haptics',
                            Icons.volume_up,
                            FeedbackService.instance.enabled,
                            (value) {
                              setState(() {
                                FeedbackService.instance.setEnabled(value);
                              });
                            },
                          ),
                        ]),
                        
                        const SizedBox(height: 30),
                        
                        // Account Actions
                        _buildSectionHeader('Account'),
                        _buildSettingsCard([
                          _buildListTile(
                            'Parent Access',
                            'Access parent dashboard and controls',
                            Icons.supervisor_account,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ParentDashboardScreen(),
                                ),
                              );
                            },
                          ),
                          _buildListTile(
                            'Privacy Policy',
                            'Read our privacy policy',
                            Icons.privacy_tip,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Privacy policy coming soon! 📋'),
                                  backgroundColor: Color(0xFF8E44AD),
                                ),
                              );
                            },
                          ),
                          _buildListTile(
                            'Help & Support',
                            'Get help and contact support',
                            Icons.help,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Help center coming soon! 💬'),
                                  backgroundColor: Color(0xFF8E44AD),
                                ),
                              );
                            },
                          ),
                          _buildListTile(
                            'Sign Out',
                            'Sign out of your account',
                            Icons.logout,
                            () {
                              _showSignOutDialog(authProvider);
                            },
                            isDestructive: true,
                          ),
                        ]),

                        SizedBox(height: 100 + bottomPadding), // Space for bottom navigation
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: const AppBottomNav(
        currentTab: NavTab.settings,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8E44AD),
        ),
      ),
    );
  }

  Widget _buildProfileCard(AuthProvider authProvider, UserProvider userProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A9E9E9E),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x1A8E44AD),
                  border: Border.all(
                    color: const Color(0xFF8E44AD),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    authProvider.userProfile?['avatar'] ?? '👦',
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.userProfile?['username'] ?? 'Reader',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${userProvider.totalBooksRead} books read • ${userProvider.dailyReadingStreak} day streak',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                onPressed: () {
                  FeedbackService.instance.playTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFF8E44AD),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Separate badges card
  Widget _buildBadgesCard(List<Achievement> achievements, {bool showLabel = true}) {
    // Count unlocked vs total
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A9E9E9E),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Badges',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BadgesScreen(achievements: achievements)),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8E44AD),
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Show up to 4 badges (one row)
          ProfileBadgesWidget(achievements: achievements, maxCount: 4, showAll: false),
          const SizedBox(height: 12),
          // Badge count and "See all" indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$unlockedCount of $totalCount unlocked',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              if (totalCount > 4)
                Row(
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF8E44AD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: const Color(0xFF8E44AD),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
            BoxShadow(
              color: const Color(0x1A9E9E9E),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x1A8E44AD),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8E44AD),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF8E44AD),
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0x1Aff0000) : const Color(0x1A8E44AD),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF8E44AD),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                appLog('Signing out user...', level: 'INFO');
                await authProvider.signOut();
                // Clear local user state so UI doesn't show stale data after sign-out
                try {
                  if (context.mounted) {
                    context.read<UserProvider>().clearUserData();
                    // CRITICAL: Clear ALL book provider user data to prevent data bleeding between users
                    // This includes: recommendations, progress, favorites, filtered books, traits, achievements
                    context.read<BookProvider>().clearUserData();
                  }
                } catch (e) {
                  appLog('Error clearing user data on sign out: $e', level: 'WARN');
                }
                appLog('Sign out complete', level: 'INFO');

                if (!context.mounted) return;

                // Close dialog then navigate to splash which handles routing
                Navigator.pop(context);
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }


}
