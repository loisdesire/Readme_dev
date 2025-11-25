import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/achievement_service.dart';
import '../screens/child/achievement_celebration_screen.dart';
import '../services/logger.dart';

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

  // Track achievements that are currently being shown to avoid duplicates
  final Set<String> _showingAchievementIds = {};

  @override
  void initState() {
    super.initState();
    appLog('[ACHIEVEMENT_LISTENER] Listener initialized', level: 'INFO');

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

  Future<void> _runMigration() async {
    try {
      // Check if user is logged in before running migration
      final user = _auth.currentUser;
      appLog('[ACHIEVEMENT_LISTENER] Migration - Current user: ${user?.uid ?? "null"}', level: 'DEBUG');

      if (user != null) {
        await _achievementService.markAllExistingAchievementsAsShown();
      } else {
        appLog('[ACHIEVEMENT_LISTENER] Migration skipped - no user logged in', level: 'DEBUG');
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
          appLog('[ACHIEVEMENT_LISTENER] Build - No user logged in', level: 'DEBUG');
          return widget.child;
        }

        appLog('[ACHIEVEMENT_LISTENER] Build - Setting up stream for user: ${user.uid}', level: 'DEBUG');

        // Stream achievements from Firebase where popupShown is false
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('user_achievements')
              .where('userId', isEqualTo: user.uid)
              .where('popupShown', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            // Log stream state
            appLog('[ACHIEVEMENT_LISTENER] Stream builder called - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, connectionState: ${snapshot.connectionState}', level: 'DEBUG');

            // Handle stream events
            if (snapshot.hasData) {
              final docsCount = snapshot.data!.docs.length;
              appLog('[ACHIEVEMENT_LISTENER] Stream has data - $docsCount documents with popupShown=false', level: 'INFO');

              if (docsCount > 0) {
                // Log achievement details
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  appLog('[ACHIEVEMENT_LISTENER] Found achievement: ${data['achievementName']}, popupShown: ${data['popupShown']}', level: 'INFO');
                }

                // Process new achievements in a post-frame callback to avoid building during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleNewAchievements(snapshot.data!.docs);
                });
              }
            }

            if (snapshot.hasError) {
              appLog('[ACHIEVEMENT_LISTENER] Stream error: ${snapshot.error}', level: 'ERROR');
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

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final achievementId = data['achievementId'] as String?;

      if (achievementId == null) continue;

      // Skip if already showing this achievement
      if (_showingAchievementIds.contains(achievementId)) {
        continue;
      }

      // Mark as showing to prevent duplicates
      _showingAchievementIds.add(achievementId);

      appLog('[ACHIEVEMENT_LISTENER] New achievement detected: ${data['achievementName']}', level: 'INFO');

      try {
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
        
        final navigatorContext = widget.navigatorKey.currentContext;
        if (navigatorContext == null) {
          appLog('[ACHIEVEMENT_LISTENER] Cannot show celebration - navigator context not available', level: 'WARN');
          return;
        }
        
        // Check if user is currently reading (in PdfReadingScreen) - do this BEFORE any async
        // ignore: use_build_context_synchronously
        final isReading = ModalRoute.of(navigatorContext)?.settings.name?.contains('PdfReading') ?? false;
        
        if (isReading) {
          // Defer achievement popup until user exits reading screen
          appLog('[ACHIEVEMENT_LISTENER] User is reading, deferring celebration for: ${achievement.name}', level: 'INFO');
          // Don't mark as shown yet - it will show when they exit
          _showingAchievementIds.remove(achievementId);
          return;
        }
        
        // Navigate and mark as shown
        await widget.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AchievementCelebrationScreen(
              achievements: [achievement],
            ),
          ),
        );

        // Mark celebration as shown in Firebase
        await _achievementService.markPopupShown(achievementId);

        appLog('[ACHIEVEMENT_LISTENER] Celebration shown and marked for: ${achievement.name}', level: 'INFO');
      } catch (e) {
        appLog('[ACHIEVEMENT_LISTENER] Error showing celebration: $e', level: 'ERROR');
      } finally {
        // Remove from showing set
        _showingAchievementIds.remove(achievementId);
      }
    }
  }
}
