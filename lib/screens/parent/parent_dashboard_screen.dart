// File: lib/screens/parent/parent_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'content_filter_screen.dart';
import 'reading_history_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/content_filter_service.dart';
import '../../services/logger.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/common_widgets.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';

class _WeeklyTotals {
  final List<int> minutesByDay;
  final int totalMinutes;
  final int daysRead;

  const _WeeklyTotals({
    required this.minutesByDay,
    required this.totalMinutes,
    required this.daysRead,
  });
}

class ParentDashboardScreen extends StatefulWidget {
  final String? childId;

  const ParentDashboardScreen({super.key, this.childId});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String? selectedChildId;
  String selectedChildName = "Child";
  Map<String, dynamic>? analytics;
  List<dynamic> recentHistory = [];
  List<Map<String, dynamic>> recentAchievements = [];
  List<Map<String, dynamic>> weeklyData = [];
  List<String> allowedCategories = [];
  int readingGoal = 0;
  int todayMinutes = 0;
  bool isLoading = true;
  String? error;

  // UserProvider data for correct totals
  int totalBooksRead = 0;
  int totalReadingMinutes = 0;
  int currentStreak = 0;

  // Caching variables
  DateTime? _lastLoadTime;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  // Real-time listener
  Stream<DocumentSnapshot>? _childDataStream;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    // Clean up listeners if any
    super.dispose();
  }

  Future<void> _initializeAndLoadData() async {
    // Use provided childId or fall back to current user
    if (widget.childId != null) {
      // Load specific child's data
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .get();

      if (childDoc.exists) {
        final childData = childDoc.data() as Map<String, dynamic>;
        setState(() {
          selectedChildId = widget.childId;
          selectedChildName = childData['username'] ?? 'Child';
        });
        await _loadDashboardData();
        return;
      }
    }

    // Fallback: Get the current authenticated user
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // For now, use the current user as the child
      // In a full implementation, you would fetch the parent's children from Firestore
      setState(() {
        selectedChildId = currentUser.uid;
        selectedChildName = currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            "Child";
      });
      await _loadDashboardData();
    } else {
      setState(() {
        error = "No user authenticated. Please log in.";
        isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    if (selectedChildId == null) {
      setState(() {
        error = "No child selected";
        isLoading = false;
      });
      return;
    }

    // CACHING: Check if cached data is still valid
    if (!forceRefresh && _lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad < _cacheValidityDuration) {
        appLog(
            '[ParentDashboard] Using cached data (age: ${timeSinceLastLoad.inSeconds}s)',
            level: 'DEBUG');
        return; // Use cached data
      }
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      appLog('[ParentDashboard] Loading data for child: $selectedChildId',
          level: 'DEBUG');

      // Set up real-time listener for child data
      _childDataStream ??= FirebaseFirestore.instance
          .collection('users')
          .doc(selectedChildId!)
          .snapshots();

      // OPTIMIZATION: Load all data in parallel using Future.wait()
      final results = await Future.wait([
        AnalyticsService().getParentAnalytics(selectedChildId!),
        ContentFilterService().getContentFilter(selectedChildId!),
        ContentFilterService().getDailyReadingTime(selectedChildId!),
      ]);

      final analyticsData = results[0] as Map<String, dynamic>;
      final contentFilter = results[1];
      final todayMinutesVal = results[2] as int;

      // OPTIMIZATION: Create UserProvider once and reuse
      // Use a new instance since this is a parent-initiated fetch, not from widget tree
      final userProvider = UserProvider();
      await userProvider.loadUserData(selectedChildId!);

      // Filter recentHistory to only include books with progress > 0 (ongoing or completed)
      final allRecentRaw = analyticsData['recentBooks'];
      final List recentList = (allRecentRaw is List) ? allRecentRaw : [];
      final filteredRecent = recentList
          .where((session) =>
              session is Map<String, dynamic> &&
              (session['progressPercentage'] ?? 0.0) > 0.0)
          .map((session) => session as Map<String, dynamic>)
          .toList();

      final weeklyRaw = analyticsData['weeklyData'];
      final weekly = (weeklyRaw is List)
          ? weeklyRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final achievementsRaw = analyticsData['recentAchievements'];
      final achievements = (achievementsRaw is List)
          ? achievementsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      appLog(
          '[ParentDashboard] Data loaded successfully: ${filteredRecent.length} recent books',
          level: 'DEBUG');

      if (mounted) {
        setState(() {
          analytics = analyticsData;
          recentHistory = filteredRecent;
          weeklyData = weekly;
          recentAchievements = achievements;
          allowedCategories =
              (contentFilter as ContentFilter?)?.allowedCategories ?? [];
          readingGoal = contentFilter?.maxReadingTimeMinutes ?? 0;
          todayMinutes = todayMinutesVal;

          // Use UserProvider data for correct totals
          totalBooksRead = userProvider.totalBooksRead;
          totalReadingMinutes = userProvider.totalReadingMinutes;
          currentStreak = userProvider.dailyReadingStreak;

          // Update cache timestamp
          _lastLoadTime = DateTime.now();

          isLoading = false;
        });
      }
    } catch (e) {
      appLog('Error loading dashboard data: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeklyTotals = _computeWeeklyTotals(weeklyData);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorRed,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                        const SizedBox(height: 16),
                        CompactButton(
                          text: 'Retry',
                          onPressed: _initializeAndLoadData,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadDashboardData(forceRefresh: true),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Viewing',
                                        style: AppTheme.bodySmall,
                                      ),
                                      Text(
                                        "$selectedChildName's reading journey",
                                        style: AppTheme.heading
                                            .copyWith(fontSize: 20),
                                      ),
                                    ],
                                  ),
                                ),
                                // Child avatar
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryPurpleOpaque10,
                                    border: Border.all(
                                      color: AppTheme.primaryPurple,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 28,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // At-a-glance summary (Today / This week / Overall)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'At a glance',
                                    style: AppTheme.heading,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSummaryRow(
                                    icon: Icons.today,
                                    title: 'Today',
                                    primary: '$todayMinutes min',
                                    secondary: readingGoal > 0
                                        ? 'Goal: $readingGoal min'
                                        : 'No goal set',
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: readingGoal > 0
                                        ? (todayMinutes / readingGoal)
                                            .clamp(0.0, 1.0)
                                        : 0.0,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.12),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppTheme.primaryPurple),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSummaryRow(
                                    icon: Icons.calendar_view_week,
                                    title: 'This week',
                                    primary: '${weeklyTotals.totalMinutes} min',
                                    secondary:
                                        '${weeklyTotals.daysRead}/7 days read',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildWeeklyBars(weeklyTotals.minutesByDay),
                                  const SizedBox(height: 16),
                                  _buildSummaryRow(
                                    icon: Icons.insights,
                                    title: 'Overall',
                                    primary:
                                        '$totalBooksRead books • $totalReadingMinutes min',
                                    secondary:
                                        'Streak: $currentStreak days • Avg session: ${_formatDurationShort((analytics?['averageSessionLengthSeconds'] as int?) ?? 0)}',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Daily Reading Goal
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGray,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Daily reading goal',
                                      style: AppTheme.heading,
                                    ),
                                    AppTextButton(
                                      text: 'Custom',
                                      onPressed: () => _showCustomGoalDialog(),
                                      icon: Icons.edit,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      '$todayMinutes/$readingGoal min',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      readingGoal > 0
                                          ? '${((todayMinutes / readingGoal) * 100).round()}%'
                                          : '0%',
                                      style: AppTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: readingGoal > 0
                                      ? (todayMinutes / readingGoal)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.12),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.primaryPurple),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    _buildGoalButton(
                                        '5min', readingGoal == 5, 5),
                                    const SizedBox(width: 8),
                                    _buildGoalButton(
                                        '10min', readingGoal == 10, 10),
                                    const SizedBox(width: 8),
                                    _buildGoalButton(
                                        '15min', readingGoal == 15, 15),
                                    const SizedBox(width: 8),
                                    _buildGoalButton(
                                        '30min', readingGoal == 30, 30),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Content Control
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGray,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Content control',
                                  style: AppTheme.heading,
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: allowedCategories
                                      .map((cat) => _buildContentTag(cat, true))
                                      .toList(),
                                ),
                                const SizedBox(height: 20),
                                SecondaryButton(
                                  text: 'Manage Content Filters',
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      FadeRoute(
                                        page: const ContentFilterScreen(),
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    if (result == true) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Content filters applied! Your child\'s library has been updated.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Recent achievements
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent achievements',
                                  style: AppTheme.heading,
                                ),
                                const SizedBox(height: 15),
                                if (recentAchievements.isEmpty)
                                  AppCard(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.emoji_events,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.35),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No achievements yet',
                                            style: AppTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...recentAchievements.map((a) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _buildAchievementItem(a),
                                      )),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Reading History
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Reading history',
                                      style: AppTheme.heading,
                                    ),
                                    AppTextButton(
                                      text: 'See all >',
                                      onPressed: () {
                                        if (selectedChildId != null) {
                                          Navigator.push(
                                            context,
                                            FadeRoute(
                                              page: ReadingHistoryScreen(
                                                  childId: selectedChildId!),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),

                                // Recent reading items
                                if (recentHistory.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.history,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No reading history yet',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...recentHistory.map((session) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _buildHistoryItem(
                                          session['bookTitle'] ?? 'Unknown',
                                          _formatLastReadAt(
                                              session['lastReadAt']),
                                          (session['progressPercentage'] ??
                                                      0.0) >=
                                                  1.0
                                              ? 'Completed'
                                              : 'Ongoing',
                                          '',
                                        ),
                                      )),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Settings
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settings',
                                  style: AppTheme.heading,
                                ),
                                const SizedBox(height: 15),
                                _buildSettingsItem(
                                  Icons.refresh,
                                  'Reset app',
                                  'Clear all data and start fresh',
                                  onTap: () {
                                    _showResetDialog();
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  _WeeklyTotals _computeWeeklyTotals(List<Map<String, dynamic>> data) {
    final minutesByDay = <int>[];
    int totalMinutes = 0;
    int daysRead = 0;

    for (final entry in data) {
      final minutes = (entry['readingTimeMinutes'] as int?) ?? 0;
      minutesByDay.add(minutes);
      totalMinutes += minutes;
      if (minutes > 0) daysRead++;
    }

    // Ensure exactly 7 bars so the layout is stable.
    while (minutesByDay.length < 7) {
      minutesByDay.insert(0, 0);
    }
    if (minutesByDay.length > 7) {
      minutesByDay.removeRange(0, minutesByDay.length - 7);
    }

    return _WeeklyTotals(
      minutesByDay: minutesByDay,
      totalMinutes: totalMinutes,
      daysRead: daysRead,
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String primary,
    required String secondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryPurple, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                primary,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black87,
                ),
              ),
              Text(
                secondary,
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBars(List<int> minutesByDay) {
    int maxMinutes = 0;
    for (final m in minutesByDay) {
      if (m > maxMinutes) maxMinutes = m;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(minutesByDay.length, (i) {
        final minutes = minutesByDay[i];
        final normalized = maxMinutes > 0 ? (minutes / maxMinutes) : 0.0;
        final barHeight = 8.0 + (26.0 * normalized);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 10,
              height: barHeight,
              decoration: BoxDecoration(
                color:
                    minutes > 0 ? AppTheme.primaryPurple : AppTheme.borderGray,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAchievementItem(Map<String, dynamic> achievement) {
    final name = achievement['achievementName'] as String? ?? 'Achievement';
    final category = achievement['category'] as String?;
    final unlockedAtLabel = _formatUnlockedAt(achievement['unlockedAt']);

    return AppCard(
      child: Row(
        children: [
          IconContainer(
            icon: Icons.emoji_events,
            size: 28,
            padding: 11,
            style: IconContainerStyle.rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style:
                      AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (category != null && category.isNotEmpty) category,
                    if (unlockedAtLabel.isNotEmpty) unlockedAtLabel,
                  ].join(' • '),
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastReadAt(dynamic raw) {
    if (raw == null) return '';

    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }

    if (dt == null) return raw.toString();

    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  String _formatUnlockedAt(dynamic raw) {
    if (raw == null) return '';
    if (raw is Timestamp) {
      final dt = raw.toDate().toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    if (raw is DateTime) {
      final dt = raw.toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '';
  }

  String _formatDurationShort(int seconds) {
    if (seconds <= 0) return '0s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes <= 0) return '${remainingSeconds}s';
    if (remainingSeconds == 0) return '${minutes}m';
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildGoalButton(String text, bool isActive, int minutes) {
    return PressableCard(
      onTap: () async {
        FeedbackService.instance.playTap();
        if (!isActive && selectedChildId != null) {
          final filter =
              await ContentFilterService().getContentFilter(selectedChildId!);
          if (filter != null) {
            final updated = ContentFilter(
              userId: filter.userId,
              allowedCategories: filter.allowedCategories,
              blockedWords: filter.blockedWords,
              maxAgeRating: filter.maxAgeRating,
              enableSafeMode: filter.enableSafeMode,
              allowedAuthors: filter.allowedAuthors,
              blockedAuthors: filter.blockedAuthors,
              maxReadingTimeMinutes: minutes,
              allowedTimes: filter.allowedTimes,
              createdAt: filter.createdAt,
              updatedAt: DateTime.now(),
            );
            await ContentFilterService().updateContentFilter(updated);
            if (!mounted) return;
            await _loadDashboardData();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryPurple : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildContentTag(String text, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isEnabled ? AppTheme.primaryPurpleOpaque10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled ? AppTheme.primaryPurple : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isEnabled ? AppTheme.primaryPurple : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isEnabled ? Icons.check_circle : Icons.remove_circle,
            size: 16,
            color: isEnabled ? AppTheme.primaryPurple : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
      String title, String time, String status, String emoji) {
    return AppCard(
      child: Row(
        children: [
          IconContainer(
            icon: Icons.menu_book,
            size: 28,
            padding: 11,
            style: IconContainerStyle.rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Removed status badge to simplify reading history display
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return PressableCard(
      onTap: () {
        FeedbackService.instance.playTap();
        if (onTap != null) onTap();
      },
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryPurple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCustomGoalDialog() {
    final TextEditingController controller = TextEditingController(
      text: readingGoal > 0 ? readingGoal.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Custom Reading Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter daily reading goal in minutes:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., 20',
                suffixText: 'minutes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryPurple, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppTextButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          PrimaryButton(
            text: 'Save',
            height: 45,
            width: 80,
            onPressed: () async {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0 && value <= 180) {
                Navigator.pop(context);

                // Show loading indicator
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Updating goal...'),
                        ],
                      ),
                      backgroundColor: AppTheme.primaryPurple,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Update goal
                if (selectedChildId != null) {
                  final filter = await ContentFilterService()
                      .getContentFilter(selectedChildId!);
                  if (filter != null) {
                    final updated = ContentFilter(
                      userId: filter.userId,
                      allowedCategories: filter.allowedCategories,
                      blockedWords: filter.blockedWords,
                      maxAgeRating: filter.maxAgeRating,
                      enableSafeMode: filter.enableSafeMode,
                      allowedAuthors: filter.allowedAuthors,
                      blockedAuthors: filter.blockedAuthors,
                      maxReadingTimeMinutes: value,
                      allowedTimes: filter.allowedTimes,
                      createdAt: filter.createdAt,
                      updatedAt: DateTime.now(),
                    );
                    await ContentFilterService().updateContentFilter(updated);
                    if (!mounted) return;
                    await _loadDashboardData();

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Goal set to $value minutes per day!'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Please enter a valid number between 1 and 180'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
            'Are you sure you want to reset all data? This action cannot be undone.'),
        actions: [
          AppTextButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AppTextButton(
            text: 'Reset',
            color: Colors.red,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App reset functionality coming soon!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
