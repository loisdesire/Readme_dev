import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/achievement_service.dart';
import '../../utils/icon_mapper.dart';
import '../../providers/book_provider.dart';
import 'badges_screen.dart';
import 'profile_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'help_support_screen.dart';
import 'parent_link_qr_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/parental_gate.dart';
import '../../widgets/common/user_avatar.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';
import '../../utils/page_transitions.dart';

class SettingsScreen extends StatefulWidget {
  /// Test-only: an independent AchievementService instance (usually
  /// wrapping fakes), instead of the real singleton. Production code
  /// always uses the default.
  @visibleForTesting
  final AchievementService? achievementServiceOverride;

  const SettingsScreen({super.key, this.achievementServiceOverride});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _readAloudEnabled = true;

  AchievementService get _achievementService =>
      widget.achievementServiceOverride ?? AchievementService();

  List<BoxShadow> get _softCardShadow => AppTheme.subtleCardShadow;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Settings',
                style: AppTheme.heading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
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
                          future: _achievementService.getUserAchievements(),
                          builder: (context, snapshot) {
                            final achievements = snapshot.data ?? [];
                            return PressableCard(
                              onTap: () {
                                FeedbackService.instance.playTap();
                                Navigator.push(
                                  context,
                                  SlideRightRoute(page: const BadgesScreen()),
                                );
                              },
                              child: _buildBadgesCard(achievements,
                                  showLabel: false),
                            );
                          },
                        ),
                        const SizedBox(height: 30),

                        // Reading Preferences
                        _buildSectionHeader('Reading Preferences'),
                        _buildSettingsCard([
                          _buildSwitchTile(
                            'Read Aloud',
                            'Enable text-to-speech',
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
                            'Enable confetti and sound effects',
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
                            'Share this PIN with your parent',
                            Icons.supervisor_account,
                            () async {
                              // Gated too: the revealed PIN is a bearer
                              // credential (see parent_link_qr_screen.dart)
                              // that grants read access to this child's
                              // account and the ability to remove it —
                              // worth the same "ask a grown-up" pause as
                              // sign-out/profile-edit.
                              if (!await showParentalGate(context)) return;
                              if (!context.mounted) return;
                              _showParentAccessDialog(authProvider);
                            },
                          ),
                          _buildListTile(
                            'Privacy Policy',
                            'Read our privacy policy',
                            Icons.privacy_tip,
                            () {
                              Navigator.push(
                                context,
                                SlideRightRoute(page:
                                      const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                          ),
                          _buildListTile(
                            'Help & Support',
                            'Get help and contact support',
                            Icons.help,
                            () {
                              Navigator.push(
                                context,
                                SlideRightRoute(page:
                                      const HelpSupportScreen(),
                                ),
                              );
                            },
                          ),
                          _buildListTile(
                            'Sign Out',
                            'Sign out of your account',
                            Icons.logout,
                            () async {
                              if (!await showParentalGate(context)) return;
                              if (!context.mounted) return;
                              _showSignOutDialog(authProvider);
                            },
                            isDestructive: true,
                          ),
                        ]),

                        SizedBox(
                            height: 100 +
                                bottomPadding), // Space for bottom navigation
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
        style: AppTheme.heading.copyWith(
          color: Color(0xFF8E44AD),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      AuthProvider authProvider, UserProvider userProvider) {
    final profile = userProvider.userProfile ?? authProvider.userProfile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: _softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              UserAvatar(
                avatar: (profile?['avatar'] as String?) ?? '🧒',
                size: 60,
                fontSize: 30,
              ),
              const SizedBox(width: 15),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (profile?['username'] as String?) ?? 'Reader',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${userProvider.totalBooksRead} books read • ${userProvider.dailyReadingStreak} day streak',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                onPressed: () async {
                  FeedbackService.instance.playTap();
                  // Parental gate (SECURITY.md, early-childhood audit
                  // finding #5) — editing the profile is an
                  // account-level action, not something a bare tap
                  // should reach unsupervised.
                  if (!await showParentalGate(context)) return;
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    SlideRightRoute(
                      page: const ProfileEditScreen(),
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

  Widget _buildBadgesCard(List<Achievement> achievements,
      {bool showLabel = true}) {
    final unlocked = achievements.where((a) => a.isUnlocked).take(4).toList();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: _softCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Badges',
                  style: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                AppTextButton(
                  text: 'See All',
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideRightRoute(
                          page: const BadgesScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Badges row (compact)
          if (unlocked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No badges yet. Start reading!',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                ),
              ),
            )
          else
            // Horizontally scrollable: up to 4 fixed-70px-wide badges
            // (plus margins) can need over 300px, more than fits in this
            // card's available width on a narrow phone — a real,
            // always-reproducible overflow, not just a test-viewport
            // artifact, since the card's own padding already eats into a
            // narrow screen's width.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: unlocked.map((achievement) {
                return Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF8E44AD),
                        child: Icon(
                          IconMapper.getAchievementIcon(achievement.emoji),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        achievement.name,
                        style: AppTheme.bodySmall.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // Badge count and "See all" indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible + ellipsis: defensive, matching the same
              // unconstrained-Row-with-spaceBetween shape found to
              // overflow at narrow widths elsewhere in this scan.
              Flexible(
                child: Text(
                  '$unlockedCount of $totalCount unlocked',
                  style: AppTheme.bodySmall.copyWith(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (totalCount > 4)
                Row(
                  children: [
                    Text(
                      'See all',
                      style: AppTheme.bodySmall.copyWith(fontSize: 13, color: const Color(0xFF8E44AD), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Color(0xFF8E44AD),
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
        boxShadow: _softCardShadow,
      ),
      // The ListTiles below paint their background/ink splashes on the
      // nearest Material ancestor. Without this, that ancestor is the
      // Scaffold's Material far up the tree, behind this Container's own
      // white background — so taps show no ripple. Clipped so the
      // ripple/highlight respects the card's rounded corners.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      title: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          title,
          style: AppTheme.body.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodyMedium.copyWith(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isDestructive ? const Color(0x1Aff0000) : const Color(0x1A8E44AD),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF8E44AD),
          size: 20,
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          title,
          style: AppTheme.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : Colors.black,
          ),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodyMedium.copyWith(
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
      builder: (ctx) => AppDialog(
        icon: Icons.logout,
        iconColor: AppTheme.errorRed,
        title: 'Sign Out',
        message: 'Are you sure you want to sign out?',
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
        primaryLabel: 'Sign Out',
        primaryColor: AppTheme.errorRed,
        onPrimary: () async {
          appLog('Signing out user...', level: 'INFO');
          await authProvider.signOut();
          try {
            if (ctx.mounted) {
              ctx.read<UserProvider>().clearUserData();
              ctx.read<BookProvider>().clearUserData();
            }
          } catch (e) {
            appLog('Error clearing user data on sign out: $e', level: 'WARN');
          }
          appLog('Sign out complete', level: 'INFO');
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          Navigator.of(ctx).pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
    );
  }

  void _showParentAccessDialog(AuthProvider authProvider) async {
    // Navigate to QR code screen - PIN will be generated there
    Navigator.push(
      context,
      SlideRightRoute(page: ParentLinkQRScreen(
          childUid: authProvider.userId!,
          childName: authProvider.userProfile?['username'] ?? 'Child',
          parentAccessPin: authProvider.userProfile?['parentAccessPin'],
        ),
      ),
    );
  }
}


