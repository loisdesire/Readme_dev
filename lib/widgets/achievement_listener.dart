import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/achievement_service.dart';
import '../services/reading_screen_tracker.dart';
import '../screens/child/achievement_celebration_screen.dart';
import '../services/logger.dart';
import '../utils/page_transitions.dart';

/// Global achievement listener that monitors Firebase for newly unlocked achievements
/// and displays celebration screens automatically. This is completely independent of any specific screen.
///
/// Achievement unlocking can happen anywhere in the app (reading, quizzes, streaks, etc.)
/// and this listener will catch them all by monitoring the user_achievements collection.
class AchievementListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const AchievementListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<AchievementListener> createState() => _AchievementListenerState();
}

class _AchievementListenerState extends State<AchievementListener> {
  final AchievementService _achievementService = AchievementService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track achievements that have been processed to avoid duplicates
  final Set<String> _processedAchievementIds = {};

  // Queue to process achievements one at a time
  bool _isShowingAchievement = false;

  // Keep the latest pending docs so we can retry when conditions change
  List<QueryDocumentSnapshot> _pendingDocs = const [];

  VoidCallback? _readingTrackerListener;

  @override
  void initState() {
    super.initState();
    appLog('[ACHIEVEMENT_LISTENER] Listener initialized', level: 'INFO');

    // When reading ends, immediately retry any pending achievements.
    _readingTrackerListener = () {
      if (!mounted) return;
      if (!ReadingScreenTracker.isReadingActive) {
        _maybeProcessPending();
      }
    };
    ReadingScreenTracker.activeReaders.addListener(_readingTrackerListener!);

    // Run migration once to mark existing achievements as shown
    // This prevents old achievements from showing celebrations when switching to new system
    // Delay to ensure Firebase is initialized
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        appLog('[ACHIEVEMENT_LISTENER] Starting migration...', level: 'INFO');
        _runMigration();
      }
    });
  }

  @override
  void dispose() {
    if (_readingTrackerListener != null) {
      ReadingScreenTracker.activeReaders
          .removeListener(_readingTrackerListener!);
    }
    super.dispose();
  }

  void _maybeProcessPending() {
    if (!mounted) return;
    if (_isShowingAchievement) return;
    if (ReadingScreenTracker.isReadingActive) return;
    if (_pendingDocs.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNewAchievements(_pendingDocs);
    });
  }

  Future<void> _runMigration() async {
    try {
      // Check if user is logged in before running migration
      final user = _auth.currentUser;
      appLog(
          '[ACHIEVEMENT_LISTENER] Migration - Current user: ${user?.uid ?? "null"}',
          level: 'DEBUG');

      if (user != null) {
        // Run only once per user. Otherwise we can accidentally mark fresh unlocks
        // (created during app startup) as shown before the popup displays.
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final userSnapshot = await userDocRef.get();
        final userData = userSnapshot.data();
        final alreadyMigrated =
            (userData?['achievementPopupMigrationDone'] as bool?) ?? false;

        if (alreadyMigrated) {
          appLog('[ACHIEVEMENT_LISTENER] Migration already completed',
              level: 'DEBUG');
          return;
        }

        // Only mark older achievements (avoid suppressing brand-new unlocks).
        final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
        await _achievementService.markAllExistingAchievementsAsShown(
          unlockedBefore: cutoff,
        );

        await userDocRef.set(
          {
            'achievementPopupMigrationDone': true,
            'achievementPopupMigrationDoneAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        appLog('[ACHIEVEMENT_LISTENER] Migration skipped - no user logged in',
            level: 'DEBUG');
      }
    } catch (e) {
      appLog('[ACHIEVEMENT_LISTENER] Migration failed: $e', level: 'WARN');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to rebuild when user logs in/out
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // If no user is logged in, just return the child
        if (user == null) {
          appLog('[ACHIEVEMENT_LISTENER] Build - No user logged in',
              level: 'DEBUG');
          return widget.child;
        }

        appLog(
            '[ACHIEVEMENT_LISTENER] Build - Setting up stream for user: ${user.uid}',
            level: 'DEBUG');

        // Stream achievements from Firebase where popupShown is false
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('user_achievements')
              .where('userId', isEqualTo: user.uid)
              .where('popupShown', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            // Log stream state
            appLog(
                '[ACHIEVEMENT_LISTENER] Stream builder called - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, connectionState: ${snapshot.connectionState}',
                level: 'DEBUG');

            // Handle stream events
            if (snapshot.hasData) {
              final docsCount = snapshot.data!.docs.length;
              appLog(
                  '[ACHIEVEMENT_LISTENER] Stream has data - $docsCount documents with popupShown=false',
                  level: 'INFO');

              _pendingDocs = snapshot.data!.docs;

              if (docsCount > 0) {
                // Log achievement details
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  appLog(
                      '[ACHIEVEMENT_LISTENER] Found achievement: ${data['achievementName']}, popupShown: ${data['popupShown']}',
                      level: 'INFO');
                }

                // Process new achievements in a post-frame callback to avoid building during build.
                // If reading is active, they will be deferred and retried on exit.
                _maybeProcessPending();
              }
            }

            if (snapshot.hasError) {
              appLog('[ACHIEVEMENT_LISTENER] Stream error: ${snapshot.error}',
                  level: 'ERROR');
            }

            // Always return the child - celebrations are shown via navigation
            return widget.child;
          },
        );
      },
    );
  }

  Future<void> _handleNewAchievements(List<QueryDocumentSnapshot> docs) async {
    if (!mounted) return;

    // If already showing an achievement, skip - will be picked up in next stream event
    if (_isShowingAchievement) {
      appLog(
          '[ACHIEVEMENT_LISTENER] Already showing achievement, skipping batch',
          level: 'DEBUG');
      return;
    }

    // Process only the first unprocessed achievement
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final achievementId = data['achievementId'] as String?;

      if (achievementId == null) continue;

      // Skip if we've already processed this achievement in this session
      if (_processedAchievementIds.contains(achievementId)) {
        appLog(
            '[ACHIEVEMENT_LISTENER] Skipping already processed: $achievementId',
            level: 'DEBUG');
        continue;
      }

      // Mark as processed immediately to prevent duplicate processing
      _processedAchievementIds.add(achievementId);
      _isShowingAchievement = true;

      appLog(
          '[ACHIEVEMENT_LISTENER] New achievement detected: ${data['achievementName']}',
          level: 'INFO');

      try {
        // Defer achievement popup until user exits reading.
        if (ReadingScreenTracker.isReadingActive) {
          appLog(
              '[ACHIEVEMENT_LISTENER] Reading active, deferring achievement: ${data['achievementName']}',
              level: 'INFO');
          _isShowingAchievement = false;
          // DO NOT mark as shown yet - we will retry when reading ends
          _processedAchievementIds.remove(achievementId);
          return;
        }

        if (!mounted) return;

        final navigatorState = widget.navigatorKey.currentState;
        if (navigatorState == null) {
          appLog(
              '[ACHIEVEMENT_LISTENER] Cannot show celebration - navigator not ready',
              level: 'WARN');
          _isShowingAchievement = false;
          _processedAchievementIds.remove(achievementId);
          return;
        }

        // Fetch full achievement details
        final allAchievements = await _achievementService.getAllAchievements();
        final achievement = allAchievements.firstWhere(
          (a) => a.id == achievementId,
          orElse: () => Achievement(
            id: achievementId,
            name: data['achievementName'] ?? 'Achievement',
            description: 'You earned an achievement!',
            emoji: data['emoji'] ?? '🏆',
            category: data['category'] ?? 'general',
            requiredValue: 1,
            type: 'general',
            points: data['points'] ?? 0,
            isUnlocked: true,
          ),
        );

        // Navigate to celebration screen using navigator key
        if (!mounted) return;

        // Mark as shown right before showing UI to avoid repeated popups,
        // but only when we know we can actually navigate.
        await _achievementService.markPopupShown(achievementId);

        // Navigate to celebration
        await navigatorState.push(
          ScaleFadeRoute(
            page: AchievementCelebrationScreen(
              achievements: [achievement],
            ),
          ),
        );

        appLog(
            '[ACHIEVEMENT_LISTENER] Celebration shown for: ${achievement.name}',
            level: 'INFO');
        _isShowingAchievement = false;

        // Break after showing one achievement - next one will be picked up in next stream event
        break;
      } catch (e) {
        appLog('[ACHIEVEMENT_LISTENER] Error showing celebration: $e',
            level: 'ERROR');
        // On error, remove from processed set so it can be retried
        _processedAchievementIds.remove(achievementId);
        _isShowingAchievement = false;
      }
    }
  }
}
