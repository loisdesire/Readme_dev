import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/logger.dart';
import '../../services/achievement_service.dart';
import '../../services/weekly_challenge_service.dart';
import '../../utils/icon_mapper.dart';
import '../book/book_details_screen.dart';
import '../book/pdf_reading_screen_syncfusion.dart';
import '../quiz/quiz_screen.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'library_screen.dart';
import 'profile_edit_screen.dart';
import 'badges_screen.dart';
import 'weekly_challenge_celebration_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common/progress_button.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/pulse_animation.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen>
    with WidgetsBindingObserver {
  bool _hasCheckedWeeklyChallenge = false;
  bool _isShowingWeeklyCelebration = false;
  String? _weeklyCelebrationShownWeekKey;
  DateTime? _lastChallengeUpdate; // Only keep event debounce, remove timer
  DateTime? _lastResumeProfileRefresh;
  String _cachedUsername = 'Reader';
  String _cachedAvatar = '🧒';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setStatusBarStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetStatusBarStyle();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh challenge when app returns to foreground (e.g., after quiz)
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshWeeklyChallengeProgress(force: true);
      _refreshProfileOnResume();
    }
  }

  Future<void> _refreshProfileOnResume() async {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastResumeProfileRefresh != null &&
        now.difference(_lastResumeProfileRefresh!) <
            const Duration(seconds: 2)) {
      return;
    }
    _lastResumeProfileRefresh = now;

    try {
      final authProvider =
          Provider.of<auth_provider.AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final uid = authProvider.userId;
      if (uid == null) return;

      // Reload both providers so UI has the freshest profile data.
      await Future.wait([
        authProvider.reloadUserProfile(),
        userProvider.loadUserData(uid),
      ]);

      // Refresh local cache so the header doesn't flicker to a default avatar.
      final profile = userProvider.userProfile ?? authProvider.userProfile;
      final username = profile?['username'] as String?;
      final avatar = profile?['avatar'] as String?;

      if (mounted) {
        if (username != null &&
            username.trim().isNotEmpty &&
            username != _cachedUsername) {
          _cachedUsername = username;
        }
        if (avatar != null &&
            avatar.trim().isNotEmpty &&
            avatar != _cachedAvatar) {
          _cachedAvatar = avatar;
        }
        setState(() {});
      }
    } catch (e) {
      appLog('[HOME] Resume profile refresh failed: $e', level: 'WARN');
    }
  }

  void _setStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // Dark icons for light background
    ));
  }

  void _resetStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  Future<void> _initializeScreen() async {
    await _loadData();
    if (!_hasCheckedWeeklyChallenge) {
      await _checkWeeklyChallengeOnce();
      _hasCheckedWeeklyChallenge = true;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      final authProvider =
          Provider.of<auth_provider.AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.userId == null) return;

      await Future.wait([
        if (bookProvider.allBooks.isEmpty)
          bookProvider.loadAllBooks(userId: authProvider.userId),
        bookProvider.loadRecommendedBooks(
          authProvider.getPersonalityTraits(),
          userId: authProvider.userId,
        ),
        bookProvider.loadUserProgress(authProvider.userId!),
        userProvider.loadUserData(authProvider.userId!),
        bookProvider.loadFavorites(authProvider.userId!),
      ]);

      // Cache username/avatar from the most reliable source (UserProvider first).
      // This prevents the header from briefly falling back to the default avatar.
      if (mounted) {
        final profile = userProvider.userProfile ?? authProvider.userProfile;
        final username = profile?['username'] as String?;
        final avatar = profile?['avatar'] as String?;
        var changed = false;
        if (username != null &&
            username.isNotEmpty &&
            username != _cachedUsername) {
          _cachedUsername = username;
          changed = true;
        }
        if (avatar != null && avatar.isNotEmpty && avatar != _cachedAvatar) {
          _cachedAvatar = avatar;
          changed = true;
        }
        if (changed) setState(() {});
      }
    } catch (e) {
      appLog('Error loading data: $e', level: 'ERROR');
    }
  }

  Future<void> _checkWeeklyChallengeOnce() async {
    if (!mounted) return;

    try {
      final authProvider =
          Provider.of<auth_provider.AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) return;

      final challengeService = WeeklyChallengeService();

      // Initialize or update weekly challenge (handles week transitions)
      final isNewWeek = await challengeService
          .initializeWeeklyChallenge(authProvider.userId!);

      if (isNewWeek) {
        await challengeService.resetWeeklyTracking(authProvider.userId!);
        appLog('New week started - weekly tracking reset', level: 'INFO');
      }

      // Get current challenge data
      // Update progress immediately on first load
      await _refreshWeeklyChallengeProgress(force: true);

      // Check for celebration after progress update
      if (mounted) {
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authProvider.userId!)
            .get();

        final updatedData = updatedDoc.data();
        final isCompleted =
            updatedData?['weeklyChallengeCompleted'] as bool? ?? false;
        final hasSeenCelebration =
            updatedData?['weeklyChallengeSeen'] as bool? ?? false;
        final progress = updatedData?['weeklyChallengeProgress'] as int? ?? 0;
        final target = updatedData?['currentChallengeTarget'] as int? ?? 1;

        if (isCompleted && !hasSeenCelebration && mounted) {
          await _showWeeklyCelebration(progress, target);
          await challengeService.markCelebrationSeen(authProvider.userId!);
        }
      }
    } catch (e) {
      appLog('Error checking weekly challenge: $e', level: 'ERROR');
    }
  }

  Future<void> _showWeeklyCelebration(
      int booksCompleted, int targetBooks) async {
    if (!mounted) return;

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeeklyChallengeCelebrationScreen(
            booksCompleted: booksCompleted,
            targetBooks: targetBooks,
            pointsEarned: 50,
          ),
        ),
      );

      if (!mounted) return;

      // Refresh data after celebration shown
      await _loadData();
    } catch (e) {
      if (mounted) {
        appLog('Error showing weekly celebration: $e', level: 'ERROR');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child:
            Consumer3<auth_provider.AuthProvider, BookProvider, UserProvider>(
          builder: (context, authProvider, bookProvider, userProvider, child) {
            if (bookProvider.error != null) {
              return _buildErrorState(
                  bookProvider.error!, bookProvider.clearError);
            }

            if (bookProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPurple),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await _loadData();
              },
              color: const Color(0xFF8E44AD),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(authProvider, userProvider),
                    const SizedBox(height: 20),
                    _buildStreakCard(userProvider),
                    const SizedBox(height: 30),
                    _buildBadgeProgress(bookProvider, userProvider),
                    _buildWeeklyChallengeCard(userId: authProvider.userId),
                    const SizedBox(height: 30),
                    _buildContinueReading(bookProvider),
                    _buildRecommendedBooks(authProvider, bookProvider),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentTab: NavTab.home),
    );
  }

  Widget _buildHeader(
      auth_provider.AuthProvider authProvider, UserProvider userProvider) {
    final profile = userProvider.userProfile ?? authProvider.userProfile;
    final username = (profile?['username'] as String?) ?? _cachedUsername;
    final rawAvatar = profile?['avatar'] as String?;
    final avatar = (rawAvatar != null && rawAvatar.trim().isNotEmpty)
        ? rawAvatar
        : _cachedAvatar;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey there,',
                style: AppTheme.body.copyWith(color: AppTheme.textGray),
              ),
              Text(
                username,
                style: AppTheme.heading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            FeedbackService.instance.playTap();
            Navigator.push(
              context,
              SlideRightRoute(page: const ProfileEditScreen()),
            );
          },
          child: UserAvatar(
            avatar: avatar,
            size: 50,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(UserProvider userProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF8E44AD),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44AD).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${userProvider.dailyReadingStreak}-day streak!',
                  style: AppTheme.buttonText.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Keep it going',
                  style: AppTheme.buttonText.copyWith(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildVerticalDayBars(userProvider.currentStreakDays),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeProgress(
      BookProvider bookProvider, UserProvider userProvider) {
    final booksRead = userProvider.totalBooksRead;
    final totalReadingMinutes = bookProvider.userProgress.fold<int>(
      0,
      (total, progress) => total + progress.readingTimeMinutes,
    );

    final badgeDefinitions = _getBadgeDefinitions();
    final nextBookBadge = _getNextBadge(badgeDefinitions['books']!, booksRead);
    final nextTimeBadge =
        _getNextBadge(badgeDefinitions['time']!, totalReadingMinutes);

    if (nextBookBadge == null && nextTimeBadge == null) {
      return const SizedBox.shrink();
    }

    return Consumer2<BookProvider, UserProvider>(
      builder: (context, bookProviderUpdate, userProviderUpdate, _) {
        final updatedBooksRead = userProviderUpdate.totalBooksRead;
        final updatedReadingMinutes = bookProviderUpdate.userProgress.fold<int>(
          0,
          (total, progress) => total + progress.readingTimeMinutes,
        );

        final updatedNextBookBadge =
            _getNextBadge(badgeDefinitions['books']!, updatedBooksRead);
        final updatedNextTimeBadge =
            _getNextBadge(badgeDefinitions['time']!, updatedReadingMinutes);

        if (updatedNextBookBadge == null && updatedNextTimeBadge == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Progress', style: AppTheme.heading),
                TextButton(
                  onPressed: () async {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      SlideRightRoute(
                        page: const BadgesScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Show all',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (updatedNextBookBadge != null)
                  Expanded(
                    child: PulseAnimation(
                      duration: const Duration(milliseconds: 2000),
                      minOpacity: 0.85,
                      child: _buildCircularBadgeCard(
                        updatedNextBookBadge['name'] as String,
                        updatedNextBookBadge['icon'] as IconData,
                        updatedBooksRead,
                        updatedNextBookBadge['target'] as int,
                        updatedBooksRead == 1 ? 'book' : 'books',
                      ),
                    ),
                  ),
                if (updatedNextBookBadge != null &&
                    updatedNextTimeBadge != null)
                  const SizedBox(width: 12),
                if (updatedNextTimeBadge != null)
                  Expanded(
                    child: PulseAnimation(
                      duration: const Duration(milliseconds: 2000),
                      minOpacity: 0.85,
                      child: _buildCircularBadgeCard(
                        updatedNextTimeBadge['name'] as String,
                        updatedNextTimeBadge['icon'] as IconData,
                        updatedReadingMinutes,
                        updatedNextTimeBadge['target'] as int,
                        'minutes',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _getBadgeDefinitions() {
    final achievementService = AchievementService();
    final allAchievements = achievementService.getDefaultAchievements();

    return {
      'books': allAchievements
          .where((a) => a.category == 'reading')
          .map((a) => {
                'target': a.requiredValue,
                'name': a.name,
                'icon': IconMapper.getAchievementIcon(a.emoji),
              })
          .toList(),
      'time': allAchievements
          .where((a) => a.category == 'time')
          .map((a) => {
                'target': a.requiredValue,
                'name': a.name,
                'icon': IconMapper.getAchievementIcon(a.emoji),
              })
          .toList(),
    };
  }

  Map<String, dynamic>? _getNextBadge(
      List<Map<String, dynamic>> badges, int current) {
    for (final badge in badges) {
      if ((badge['target'] as int) > current) {
        return badge;
      }
    }
    return null;
  }

  Widget _buildCircularBadgeCard(
    String badgeName,
    IconData badgeIcon,
    int current,
    int target,
    String unit,
  ) {
    final remaining = target - current;
    final isCompleted = current >= target;
    final progress = isCompleted ? 1.0 : (current / target);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200, width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey.shade200),
                  ),
                ),
                SizedBox(
                  width: 70,
                  height: 70,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryPurple,
                        ),
                      );
                    },
                  ),
                ),
                Icon(badgeIcon, color: AppTheme.primaryPurple, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            badgeName,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: AppTheme.heading.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                TextSpan(
                  text: '/$target',
                  style: AppTheme.body.copyWith(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCompleted
                ? 'Done! 🎉'
                : remaining == 1
                    ? '1 $unit to go!'
                    : '$remaining $unit to go!',
            style: AppTheme.bodySmall.copyWith(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallengeCard({required String? userId}) {
    if (userId == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .distinct((prev, next) {
        final prevData = prev.data();
        final nextData = next.data();

        return prevData?['weeklyChallengeProgress'] ==
                nextData?['weeklyChallengeProgress'] &&
            prevData?['weeklyChallengeCompleted'] ==
                nextData?['weeklyChallengeCompleted'] &&
            prevData?['currentChallengeTarget'] ==
                nextData?['currentChallengeTarget'] &&
            prevData?['currentChallengeType'] ==
                nextData?['currentChallengeType'];
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        // Read challenge data from Firestore (set by WeeklyChallengeService)
        final challengeName =
            data?['currentChallengeName'] as String? ?? 'Complete 1 book';
        final challengeEmoji =
            data?['currentChallengeEmoji'] as String? ?? '📚';
        final targetValue = data?['currentChallengeTarget'] as int? ?? 1;
        final description = data?['currentChallengeDescription'] as String?;

        // Get stored progress (calculated and updated by service)
        final storedProgress = data?['weeklyChallengeProgress'] as int? ?? 0;
        final isComplete = data?['weeklyChallengeCompleted'] as bool? ?? false;
        final hasSeenCelebration =
            data?['weeklyChallengeSeen'] as bool? ?? false;
        final weekKey = data?['lastWeeklyChallengeWeek'] as String?;

        // Use stored progress, capped at target
        final currentProgress = storedProgress.clamp(0, targetValue);
        final progress = targetValue > 0 ? currentProgress / targetValue : 0.0;
        final daysRemaining = 7 - DateTime.now().weekday;

        // If the challenge completes later (not on first load), show celebration.
        // Do this post-frame to avoid navigation during build.
        if (isComplete &&
            !hasSeenCelebration &&
            !_isShowingWeeklyCelebration &&
            weekKey != null &&
            _weeklyCelebrationShownWeekKey != weekKey) {
          final capturedProgress = currentProgress;
          final capturedTarget = targetValue;
          final capturedWeekKey = weekKey;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_isShowingWeeklyCelebration) return;
            if (_weeklyCelebrationShownWeekKey == capturedWeekKey) return;

            setState(() {
              _isShowingWeeklyCelebration = true;
              _weeklyCelebrationShownWeekKey = capturedWeekKey;
            });

            () async {
              final authProvider = Provider.of<auth_provider.AuthProvider>(
                context,
                listen: false,
              );
              final uid = authProvider.userId;
              if (uid == null) return;

              await _showWeeklyCelebration(capturedProgress, capturedTarget);
              await WeeklyChallengeService().markCelebrationSeen(uid);
            }()
                .whenComplete(() {
              if (!mounted) return;
              setState(() => _isShowingWeeklyCelebration = false);
            });
          });
        }

        // StreamBuilder is read-only - display only, no updates scheduled here
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF8E44AD).withValues(alpha: 0.2),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -20,
                right: -15,
                child: Text(
                  challengeEmoji,
                  style: TextStyle(
                    fontSize: 100,
                    color: Colors.grey.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E44AD).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isComplete) ...[
                          const Icon(Icons.check_circle,
                              color: Color(0xFF8E44AD), size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isComplete
                              ? 'Complete'
                              : '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8E44AD),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This Week\'s Challenge',
                    style: AppTheme.heading.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete
                        ? 'You crushed it! 🎉'
                        : description ?? challengeName,
                    style: AppTheme.body.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 195,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress > 1.0 ? 1.0 : progress,
                            backgroundColor:
                                const Color(0xFF8E44AD).withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$currentProgress',
                              style: AppTheme.heading.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8E44AD),
                              ),
                            ),
                            TextSpan(
                              text: '/$targetValue',
                              style: AppTheme.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Update challenge progress - called ONLY on real events
  Future<void> _refreshWeeklyChallengeProgress({bool force = false}) async {
    // Debounce: don't update more than once per 5 seconds (batches rapid events)
    final now = DateTime.now();
    if (!force &&
        _lastChallengeUpdate != null &&
        now.difference(_lastChallengeUpdate!) < const Duration(seconds: 5)) {
      return;
    }

    if (!mounted) return;
    _lastChallengeUpdate = now;

    try {
      final authProvider =
          Provider.of<auth_provider.AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.userId == null) return;

      final challengeService = WeeklyChallengeService();
      await challengeService.refreshCurrentChallengeProgress(
        userId: authProvider.userId!,
        userProgress: bookProvider.userProgress
            .map((p) => {
                  'isCompleted': p.isCompleted,
                  'lastReadAt': Timestamp.fromDate(p.lastReadAt),
                  'readingTimeMinutes': p.readingTimeMinutes,
                })
            .toList(),
        weeklyReadingProgress: userProvider.weeklyProgress,
      );
    } catch (e) {
      if (mounted) {
        appLog('Error updating challenge progress: $e', level: 'ERROR');
      }
    }
  }

  Widget _buildContinueReading(BookProvider bookProvider) {
    // IMPORTANT: Don't iterate raw userProgress rows, because duplicates/stale rows
    // can exist for the same book. Always use the provider's aggregated view.
    final bookIds = bookProvider.userProgress.map((p) => p.bookId).toSet();

    final ongoingBooks = bookIds
        .map(bookProvider.getProgressForBook)
        .whereType<ReadingProgress>()
        .where((p) => !p.isCompleted && p.progressPercentage > 0)
        .toList()
      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));

    final validBooks = ongoingBooks
        .take(2)
        .map((progress) => {
              'progress': progress,
              'book': bookProvider.getBookById(progress.bookId),
            })
        .where((item) => item['book'] != null)
        .toList();

    if (validBooks.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Keep Going', style: AppTheme.heading),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  SlideRightRoute(page: const LibraryScreen(initialTab: 2)),
                );
              },
              child: Text(
                'Show all',
                style: AppTheme.bodyMedium
                    .copyWith(color: const Color(0xFF8E44AD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...validBooks.map((item) {
          final progress = item['progress'] as ReadingProgress;
          final book = item['book'] as Book;
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _buildContinueReadingCard(book, progress),
          );
        }),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildContinueReadingCard(Book book, ReadingProgress progress) {
    return PressableCard(
      onTap: () {
        if (book.hasPdf && book.pdfUrl != null) {
          Navigator.push(
            context,
            SlideUpRoute(
              page: PdfReadingScreenSyncfusion(
                bookId: book.id,
                title: book.title,
                author: book.author,
                pdfUrl: book.pdfUrl!,
                initialPage: progress.currentPage,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            SlideUpRoute(
              page: BookDetailsScreen(
                bookId: book.id,
                title: book.title,
                author: book.author,
                description: book.description,
                ageRating: book.ageRating,
                emoji: book.displayCover,
              ),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppTheme.greyOpaque10,
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            BookCover(book: book, width: 80, height: 100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_stories,
                          size: 16, color: Color(0xFF8E44AD)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.title,
                          style: AppTheme.body
                              .copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          size: 16, color: Color(0xFF8E44AD)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.author,
                          style:
                              AppTheme.bodyMedium.copyWith(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Continue reading >',
                    style: AppTheme.bodyMedium.copyWith(
                      color: const Color(0xFF8E44AD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.progressPercentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress.progressPercentage * 100).round()}%',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedBooks(
    auth_provider.AuthProvider authProvider,
    BookProvider bookProvider,
  ) {
    // Match the Library "For You" list exactly and just take the first 3.
    // But Home's "Start Reading" should only show books the kid hasn't started yet.
    final availableBooks = bookProvider.combinedRecommendedBooksForDisplay
        .where((book) {
          final progress = bookProvider.getProgressForBook(book.id);
          if (progress == null) return true;
          if (progress.isCompleted) return false;
          return progress.progressPercentage <= 0;
        })
        .take(3)
        .toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Start Reading', style: AppTheme.heading),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  SlideRightRoute(page: const LibraryScreen(initialTab: 1)),
                );
              },
              child: Text(
                'Show all',
                style: AppTheme.bodyMedium
                    .copyWith(color: const Color(0xFF8E44AD)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (availableBooks.isEmpty)
          _buildEmptyRecommendations(
              authProvider.getPersonalityTraits().isNotEmpty)
        else
          ...availableBooks.map((book) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: PressableCard(
                onTap: () {
                  Navigator.push(
                    context,
                    SlideUpRoute(
                      page: BookDetailsScreen(
                        bookId: book.id,
                        title: book.title,
                        author: book.author,
                        description: book.description,
                        ageRating: book.ageRating,
                        emoji: book.displayCover,
                      ),
                    ),
                  );
                },
                child: _buildBookCard(book),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBookCard(Book book) {
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final progress = bookProvider.getProgressForBook(book.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyOpaque10,
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          BookCover(book: book),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.title,
                        style:
                            AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.author,
                        style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Text(
                      '${book.estimatedReadingTime} min',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.child_care,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Text(
                      book.ageRating,
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                if (progress != null && progress.progressPercentage > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.progressPercentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress.progressPercentage * 100).round()}%',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ProgressButton(
            text: progress?.isCompleted == true
                ? 'Re-read'
                : progress != null && progress.progressPercentage > 0
                    ? 'Resume'
                    : 'Start',
            type: progress?.isCompleted == true
                ? ProgressButtonType.completed
                : progress != null && progress.progressPercentage > 0
                    ? ProgressButtonType.inProgress
                    : ProgressButtonType.notStarted,
            onPressed: () {
              Navigator.push(
                context,
                SlideUpRoute(
                  page: BookDetailsScreen(
                    bookId: book.id,
                    title: book.title,
                    author: book.author,
                    emoji: book.displayCover,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecommendations(bool hasCompletedQuiz) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Text(
              hasCompletedQuiz
                  ? 'Amazing! You\'ve explored all available books. Check back soon for new recommendations!'
                  : 'Complete your personality quiz to get personalized recommendations!',
              style: AppTheme.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!hasCompletedQuiz)
              CompactButton(
                text: 'Take Quiz',
                onPressed: () {
                  Navigator.push(
                    context,
                    ScaleFadeRoute(page: const QuizScreen()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😔', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: AppTheme.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              error,
              style: AppTheme.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            CompactButton(
              text: 'Try Again',
              onPressed: onRetry,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVerticalDayBars(
    List<bool> streakDays,
  ) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1;

    // We only want to visualize the *current streak* (consecutive days).
    // If the user hasn't read today yet, the streak can still include
    // previous consecutive days (ending yesterday), but today stays grey.
    final Set<int> streakDaysAgo = <int>{};
    if (streakDays.isNotEmpty) {
      final start = streakDays[0] ? 0 : 1;
      for (var i = start; i < streakDays.length; i++) {
        if (streakDays[i] != true) break;
        streakDaysAgo.add(i);
      }
    }

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final isFutureDay = index > currentDayIndex;
      final isToday = index == currentDayIndex;

      final daysAgo = currentDayIndex - index;
      final bool hasRead =
          !isFutureDay && daysAgo >= 0 && streakDaysAgo.contains(daysAgo);

      final Color barColor;
      if (hasRead) {
        // Only turns "white" once they've actually read that day.
        barColor = Colors.white;
      } else if (isFutureDay) {
        // Future days: faint.
        barColor = Colors.white.withValues(alpha: 0.12);
      } else if (isToday) {
        // Today (not read yet): a bit brighter grey.
        barColor = Colors.white.withValues(alpha: 0.32);
      } else {
        // Past days with no reading: greyish.
        barColor = Colors.white.withValues(alpha: 0.22);
      }

      return Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }).toList();
  }
}
