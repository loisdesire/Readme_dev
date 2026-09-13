// File: lib/services/achievement_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'logger.dart';
import '../utils/league_helper.dart';
import 'weekly_challenge_service.dart';
import 'achievement_rules.dart';
import 'points_engine_client.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int requiredValue;
  final String
      type; // 'books_read', 'reading_streak', 'reading_time', 'quiz_completed'
  final int points;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.requiredValue,
    required this.type,
    required this.points,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromMap(Map<String, dynamic> data,
      {bool isUnlocked = false, DateTime? unlockedAt}) {
    return Achievement(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      emoji: data['emoji'] ?? '',
      category: data['category'] ?? 'general',
      requiredValue: data['requiredValue'] ?? 1,
      type: data['type'] ?? 'books_read',
      points: data['points'] ?? 10,
      isUnlocked: isUnlocked,
      unlockedAt: unlockedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'category': category,
      'requiredValue': requiredValue,
      'type': type,
      'points': points,
    };
  }
}

class AchievementService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;
  final WeeklyChallengeService _weeklyChallengeService;
  final PointsEngineClient _pointsEngine;

  // Cache for unlocked achievement IDs to avoid redundant Firestore queries
  Set<String>? _unlockedAchievementIds;
  String? _cachedUserId;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Lock to prevent race condition in achievement unlocking
  final Set<String> _unlockingInProgress = {};

  // Singleton pattern
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal()
      : _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance,
        _notificationService = NotificationService(),
        _weeklyChallengeService = WeeklyChallengeService(),
        _pointsEngine = PointsEngineClient();

  /// Test-only: an independent (non-singleton) instance wrapping fakes/mocks
  /// — e.g. a `FakeFirebaseFirestore` and `MockFirebaseAuth`, plus matching
  /// `NotificationService.withInstances`/`WeeklyChallengeService.withInstances`
  /// so a full checkAndUnlockAchievements() call can be tested end-to-end.
  @visibleForTesting
  AchievementService.withInstances({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required NotificationService notificationService,
    required WeeklyChallengeService weeklyChallengeService,
    PointsEngineClient? pointsEngineClient,
  })  : _firestore = firestore,
        _auth = auth,
        _notificationService = notificationService,
        _weeklyChallengeService = weeklyChallengeService,
        _pointsEngine = pointsEngineClient ??
            // ignore: invalid_use_of_visible_for_testing_member
            PointsEngineClient.withCaller(
              (name, data) => throw StateError(
                'PointsEngineClient not stubbed for test call: $name($data)',
              ),
            );

  // Book completion, book quiz, personality quiz, weekly challenge, daily
  // quest, and achievement-unlock points all used to be written directly
  // to Firestore from here (a plain runTransaction against
  // totalAchievementPoints/allTimePoints/etc.) — since firestore.rules lets
  // an account's own owner write any field on their own doc except `role`,
  // a modified client could set its own point total to anything, and the
  // leaderboard ranks real users against each other by that exact field.
  // Every award below now goes through a Cloud Function
  // (functions/lib/points_engine.js) that computes the amount itself and
  // re-verifies the underlying claim against Firestore instead of trusting
  // it. See SECURITY.md's "Point-award security migration".

  /// [userId] and [isFirstCompletion] are kept for call-site compatibility
  /// but no longer used directly: the Cloud Function always acts on the
  /// signed-in caller (never a client-supplied uid) and determines
  /// first-vs-reread itself from a server-only award record, precisely
  /// because trusting a client-reported `isFirstCompletion` flag was part
  /// of what let this be gamed before.
  Future<BookCompletionAwardResult> awardBookCompletionPoints({
    required String userId,
    required String bookId,
    required bool isFirstCompletion,
  }) async {
    try {
      final result =
          await _pointsEngine.awardBookCompletionPoints(bookId: bookId);
      return BookCompletionAwardResult(
        pointsEarned: (result['pointsEarned'] as num?)?.toInt() ?? 0,
        totalBooksCompleted:
            (result['totalBooksCompleted'] as num?)?.toInt() ?? 0,
        newTotalPoints: (result['newTotalPoints'] as num?)?.toInt() ?? 0,
        promotedLeague:
            LeagueHelper.parseLeagueKey(result['promotedLeague'] as String?),
      );
    } catch (e) {
      appLog('[COMPLETION] Error awarding book completion points: $e',
          level: 'ERROR');
      return const BookCompletionAwardResult(
        pointsEarned: 0,
        totalBooksCompleted: 0,
        newTotalPoints: 0,
        promotedLeague: null,
      );
    }
  }

  Future<League?> awardPersonalityQuizCompletion({
    required String userId,
  }) async {
    try {
      final result = await _pointsEngine.awardPersonalityQuizPoints();
      return LeagueHelper.parseLeagueKey(result['promotedLeague'] as String?);
    } catch (e) {
      if (isFunctionsErrorCode(e, 'already-exists')) {
        return null; // already awarded — not a real error, just a no-op.
      }
      appLog('[POINTS] Error awarding personality quiz completion: $e',
          level: 'ERROR');
      return null;
    }
  }

  // Initialize achievements (call this once to set up the achievement system)
  Future<void> initializeAchievements() async {
    try {
      final achievements = getDefaultAchievements();

      for (final achievement in achievements) {
        await _firestore.collection('achievements').doc(achievement.id).set(
              achievement.toMap(),
              SetOptions(merge: true),
            );
      }

      appLog('Achievements initialized successfully!', level: 'DEBUG');
    } catch (e) {
      appLog('Error initializing achievements: $e', level: 'ERROR');
    }
  }

  // Get all available achievements
  Future<List<Achievement>> getAllAchievements() async {
    try {
      final query = await _firestore
          .collection('achievements')
          .orderBy('category')
          .orderBy('requiredValue')
          .get();

      return query.docs
          .map((doc) => Achievement.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      appLog('Error getting all achievements: $e', level: 'ERROR');
      return [];
    }
  }

  // Get user's achievements
  Future<List<Achievement>> getUserAchievements() async {
    final user = _auth.currentUser;
    if (user == null) {
      appLog('[ACHIEVEMENTS] No user logged in', level: 'WARN');
      return [];
    }

    try {
      appLog('[ACHIEVEMENTS] Fetching achievements for user: ${user.uid}',
          level: 'INFO');

      // Get all achievements
      final allAchievements = await getAllAchievements();
      appLog(
          '[ACHIEVEMENTS] Found ${allAchievements.length} total achievements',
          level: 'INFO');

      if (allAchievements.isEmpty) {
        appLog(
            '[ACHIEVEMENTS] No achievements found in Firestore! Run initializeAchievements()',
            level: 'ERROR');
        return [];
      }

      // Get unlocked IDs (uses cache if available)
      final unlockedIds = await _getUnlockedAchievementIds();
      appLog(
          '[ACHIEVEMENTS] User has unlocked ${unlockedIds.length} achievements',
          level: 'INFO');

      // Mark achievements as unlocked
      final result = allAchievements.map((achievement) {
        final isUnlocked = unlockedIds.contains(achievement.id);
        return Achievement(
          id: achievement.id,
          name: achievement.name,
          description: achievement.description,
          emoji: achievement.emoji,
          category: achievement.category,
          requiredValue: achievement.requiredValue,
          type: achievement.type,
          points: achievement.points,
          isUnlocked: isUnlocked,
          unlockedAt: null, // Would need to fetch from Firestore if needed
        );
      }).toList();

      appLog('[ACHIEVEMENTS] Returning ${result.length} achievements to UI',
          level: 'INFO');
      return result;
    } catch (e) {
      appLog('Error getting user achievements: $e', level: 'ERROR');
      return [];
    }
  }

  // Get cached or fresh unlocked achievement IDs
  Future<Set<String>> _getUnlockedAchievementIds() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    // Check if cache is valid
    final now = DateTime.now();
    if (_cachedUserId == user.uid &&
        _unlockedAchievementIds != null &&
        _lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheExpiry) {
      appLog(
          '[ACHIEVEMENT CACHE] Using cached unlocked IDs (${_unlockedAchievementIds!.length} achievements)',
          level: 'DEBUG');
      return _unlockedAchievementIds!;
    }

    // Fetch fresh data
    try {
      final unlockedQuery = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .get();

      final unlockedIds = unlockedQuery.docs
          .map((doc) => doc.data()['achievementId'] as String)
          .toSet();

      // Update cache
      _unlockedAchievementIds = unlockedIds;
      _cachedUserId = user.uid;
      _lastCacheUpdate = now;

      appLog(
          '[ACHIEVEMENT CACHE] Refreshed cache with ${unlockedIds.length} unlocked achievements',
          level: 'DEBUG');
      return unlockedIds;
    } catch (e) {
      appLog('Error fetching unlocked achievement IDs: $e', level: 'ERROR');
      return {};
    }
  }

  // Invalidate cache (call this after unlocking a new achievement)
  void _invalidateCache() {
    _unlockedAchievementIds = null;
    _cachedUserId = null;
    _lastCacheUpdate = null;
    appLog('[ACHIEVEMENT CACHE] Cache invalidated', level: 'DEBUG');
  }

  // Check and unlock achievements based on user progress
  Future<List<Achievement>> checkAndUnlockAchievements({
    int? booksCompleted,
    int? readingStreak,
    int? totalReadingMinutes,
    int? totalSessions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Use cached unlocked IDs for faster checking
      final unlockedIds = await _getUnlockedAchievementIds();
      final allAchievements = await getAllAchievements();

      final newlyUnlocked = <Achievement>[];

      appLog(
          '[ACHIEVEMENT CHECK] Checking ${allAchievements.length} achievements against ${unlockedIds.length} already unlocked',
          level: 'DEBUG');

      for (final achievement in allAchievements) {
        if (unlockedIds.contains(achievement.id)) {
          // Skip already unlocked (no debug spam)
          continue;
        }

        final shouldUnlock = shouldUnlockAchievement(
          achievement,
          AchievementProgress(
            booksCompleted: booksCompleted,
            readingStreak: readingStreak,
            totalReadingMinutes: totalReadingMinutes,
            totalSessions: totalSessions,
          ),
        );

        if (shouldUnlock) {
          appLog(
              '[ACHIEVEMENT UNLOCK] ${achievement.name} (${achievement.type}: ${achievement.requiredValue})',
              level: 'INFO');
          final actuallyUnlocked = await _unlockAchievement(
            achievement,
            readingStreak: readingStreak ?? 0,
          );
          if (actuallyUnlocked) newlyUnlocked.add(achievement);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      appLog('Error checking achievements: $e', level: 'ERROR');
      return [];
    }
  }

  /// Unlock a specific achievement. [shouldUnlockAchievement] above is only
  /// a fast local pre-filter (avoids calling out for every already-hopeless
  /// achievement on every check) — the Cloud Function independently
  /// re-verifies the real books/time/sessions count server-side from
  /// Firestore before crediting anything, rather than trusting this
  /// client's numbers outright. See SECURITY.md's "Point-award security
  /// migration". Returns whether it was actually unlocked (false for an
  /// already-unlocked or not-actually-qualifying achievement, both of
  /// which the server may find even when the local pre-check thought
  /// otherwise).
  Future<bool> _unlockAchievement(
    Achievement achievement, {
    required int readingStreak,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Prevent race condition: Check if this achievement is already being unlocked
    final lockKey = '${user.uid}_${achievement.id}';
    if (_unlockingInProgress.contains(lockKey)) {
      appLog('[ACHIEVEMENT] Already unlocking: ${achievement.name}',
          level: 'DEBUG');
      return false;
    }

    try {
      _unlockingInProgress.add(lockKey);

      // readingStreak is used only for the local shouldUnlockAchievement
      // pre-check above — the Cloud Function now verifies reading_streak
      // achievements itself from real reading_progress/reading_sessions
      // records (functions/lib/points_engine.js's calculateReadingStreak),
      // so it's no longer sent here at all.
      await _pointsEngine.unlockAchievement(achievementId: achievement.id);

      // Invalidate cache so next check uses fresh data
      _invalidateCache();

      // Refresh weekly-challenge progress — the server already incremented
      // achievementsUnlockedThisWeek atomically with the unlock, this just
      // picks that up immediately instead of waiting for the next natural
      // periodic refresh elsewhere.
      await _weeklyChallengeService.refreshCurrentChallengeProgress(
        userId: user.uid,
      );

      // Send notification
      await _notificationService.sendAchievementNotification(
        achievementName: achievement.name,
        description: achievement.description,
        emoji: achievement.emoji,
      );

      appLog('Achievement unlocked: ${achievement.name}', level: 'INFO');
      return true;
    } catch (e) {
      if (isFunctionsErrorCode(e, 'already-exists')) {
        // Already unlocked server-side — not a real error.
        _invalidateCache();
        return false;
      }
      if (isFunctionsErrorCode(e, 'failed-precondition')) {
        // Server-side re-verification found the real count doesn't
        // actually meet the threshold yet — this client's numbers can be
        // stale/optimistic; expected occasionally, not an error.
        appLog(
            '[ACHIEVEMENT] Server declined unlock (requirements not met): ${achievement.name}',
            level: 'DEBUG');
        return false;
      }
      appLog('Error unlocking achievement: $e', level: 'ERROR');
      return false;
    } finally {
      // Always remove from in-progress set
      _unlockingInProgress.remove(lockKey);
    }
  }

  // Mark achievement popup as shown (called after displaying popup)
  Future<void> markPopupShown(String achievementId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .where('achievementId', isEqualTo: achievementId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({'popupShown': true});
      }

      appLog('[ACHIEVEMENT] Marked popup as shown for: $achievementId',
          level: 'DEBUG');
    } catch (e) {
      appLog('Error marking popup as shown: $e', level: 'ERROR');
    }
  }

  // Get user's total achievement points
  Future<int> getUserTotalPoints() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .get();

      return query.docs.fold<int>(
        0,
        (total, doc) => total + (doc.data()['points'] as int? ?? 0),
      );
    } catch (e) {
      appLog('Error getting user total points: $e', level: 'ERROR');
      return 0;
    }
  }

  // Get achievements by category
  Future<List<Achievement>> getAchievementsByCategory(String category) async {
    final allAchievements = await getUserAchievements();
    return allAchievements.where((a) => a.category == category).toList();
  }

  // Migration helper: Mark existing achievements as popupShown to prevent re-showing.
  // IMPORTANT: Use [unlockedBefore] to avoid accidentally suppressing brand-new unlocks
  // that happen right as the app starts.
  Future<void> markAllExistingAchievementsAsShown(
      {DateTime? unlockedBefore}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .get();

      int updated = 0;
      for (final doc in query.docs) {
        final data = doc.data();

        final unlockedAt = (data['unlockedAt'] as Timestamp?)?.toDate();
        if (unlockedBefore != null) {
          // If unlockedAt is missing (serverTimestamp pending), treat it as "too new".
          if (unlockedAt == null) continue;
          if (unlockedAt.isAfter(unlockedBefore)) continue;
        }

        // Only update if popupShown field doesn't exist or is false
        if (!data.containsKey('popupShown') || data['popupShown'] == false) {
          await doc.reference.update({'popupShown': true});
          updated++;
        }
      }

      appLog(
          '[ACHIEVEMENT] Migration: Marked $updated existing achievements as shown',
          level: 'INFO');
    } catch (e) {
      appLog('[ACHIEVEMENT] Error in migration: $e', level: 'ERROR');
    }
  }

  // Get recently unlocked achievements
  Future<List<Achievement>> getRecentlyUnlockedAchievements(
      {int limit = 5}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .orderBy('unlockedAt', descending: true)
          .limit(limit)
          .get();

      final achievementIds = query.docs
          .map((doc) => doc.data()['achievementId'] as String)
          .toList();
      final allAchievements = await getAllAchievements();

      return allAchievements
          .where((a) => achievementIds.contains(a.id))
          .map((a) => Achievement(
                id: a.id,
                name: a.name,
                description: a.description,
                emoji: a.emoji,
                category: a.category,
                requiredValue: a.requiredValue,
                type: a.type,
                points: a.points,
                isUnlocked: true,
                unlockedAt: query.docs
                    .firstWhere((doc) => doc.data()['achievementId'] == a.id)
                    .data()['unlockedAt']
                    ?.toDate(),
              ))
          .toList();
    } catch (e) {
      appLog('Error getting recently unlocked achievements: $e',
          level: 'ERROR');
      return [];
    }
  }

  // Get progress towards next achievement
  Future<Map<String, dynamic>> getProgressTowardsNextAchievement({
    required int booksCompleted,
    required int readingStreak,
    required int totalReadingMinutes,
    required int totalSessions,
  }) async {
    try {
      final userAchievements = await getUserAchievements();
      final lockedAchievements =
          userAchievements.where((a) => !a.isUnlocked).toList();

      if (lockedAchievements.isEmpty) {
        return {'hasNext': false};
      }

      // Find the closest achievement to unlock
      Achievement? nextAchievement;
      double bestProgress = 0;

      for (final achievement in lockedAchievements) {
        double progress = 0;
        int currentValue = 0;

        switch (achievement.type) {
          case 'books_read':
            currentValue = booksCompleted;
            break;
          case 'reading_streak':
            currentValue = readingStreak;
            break;
          case 'reading_time':
            currentValue = totalReadingMinutes;
            break;
          case 'reading_sessions':
            currentValue = totalSessions;
            break;
        }

        progress = currentValue / achievement.requiredValue;

        if (progress > bestProgress && progress < 1.0) {
          bestProgress = progress;
          nextAchievement = achievement;
        }
      }

      if (nextAchievement == null) {
        // Find the easiest achievement to unlock
        lockedAchievements
            .sort((a, b) => a.requiredValue.compareTo(b.requiredValue));
        nextAchievement = lockedAchievements.first;

        int currentValue = 0;
        switch (nextAchievement.type) {
          case 'books_read':
            currentValue = booksCompleted;
            break;
          case 'reading_streak':
            currentValue = readingStreak;
            break;
          case 'reading_time':
            currentValue = totalReadingMinutes;
            break;
          case 'reading_sessions':
            currentValue = totalSessions;
            break;
        }
        bestProgress = currentValue / nextAchievement.requiredValue;
      }

      return {
        'hasNext': true,
        'achievement': nextAchievement.toMap(),
        'progress': bestProgress.clamp(0.0, 1.0),
        'currentValue': (bestProgress * nextAchievement.requiredValue).round(),
        'requiredValue': nextAchievement.requiredValue,
      };
    } catch (e) {
      appLog('Error getting progress towards next achievement: $e',
          level: 'ERROR');
      return {'hasNext': false};
    }
  }

  // Get default achievements
  // Static: this is a pure, hardcoded list — no Firestore/Auth access —
  // but was an instance method, so anything calling it (e.g.
  // child_home_screen.dart, to build its badge-progress cards during
  // build()) had to construct AchievementService() first. That's the real
  // singleton's eager _internal() constructor, which touches
  // FirebaseFirestore.instance/FirebaseAuth.instance just to reach a
  // method that never uses them — unnecessary in production, and made the
  // calling screen untestable without a real Firebase app initialized.
  static List<Achievement> getDefaultAchievements() {
    return [
      // Reading achievements - using icon names instead of emojis
      Achievement(
        id: 'first_book',
        name: 'First Book',
        description: 'Finish 1 book',
        emoji: 'book',
        category: 'reading',
        requiredValue: 1,
        type: 'books_read',
        points: 3,
      ),
      Achievement(
        id: 'three_books',
        name: 'Story Explorer',
        description: 'Finish 3 books',
        emoji: 'menu_book',
        category: 'reading',
        requiredValue: 3,
        type: 'books_read',
        points: 5,
      ),
      Achievement(
        id: 'book_lover',
        name: 'Book Lover',
        description: 'Finish 5 books',
        emoji: 'favorite',
        category: 'reading',
        requiredValue: 5,
        type: 'books_read',
        points: 7,
      ),
      Achievement(
        id: 'bookworm',
        name: 'Bookworm',
        description: 'Finish 10 books',
        emoji: 'auto_stories',
        category: 'reading',
        requiredValue: 10,
        type: 'books_read',
        points: 10,
      ),
      Achievement(
        id: 'fifteen_books',
        name: 'Super Reader',
        description: 'Finish 15 books',
        emoji: 'import_contacts',
        category: 'reading',
        requiredValue: 15,
        type: 'books_read',
        points: 14,
      ),
      Achievement(
        id: 'twenty_books',
        name: 'Reading Star',
        description: 'Finish 20 books',
        emoji: 'library_books',
        category: 'reading',
        requiredValue: 20,
        type: 'books_read',
        points: 18,
      ),
      Achievement(
        id: 'thirty_books',
        name: 'Book Champion',
        description: 'Finish 30 books',
        emoji: 'star',
        category: 'reading',
        requiredValue: 30,
        type: 'books_read',
        points: 25,
      ),
      Achievement(
        id: 'forty_books',
        name: 'Reading Hero',
        description: 'Finish 40 books',
        emoji: 'emoji_events',
        category: 'reading',
        requiredValue: 40,
        type: 'books_read',
        points: 30,
      ),
      Achievement(
        id: 'fifty_books',
        name: 'Book Master',
        description: 'Finish 50 books',
        emoji: 'stars',
        category: 'reading',
        requiredValue: 50,
        type: 'books_read',
        points: 35,
      ),
      Achievement(
        id: 'seventyfive_books',
        name: 'Reading Genius',
        description: 'Finish 75 books',
        emoji: 'workspace_premium',
        category: 'reading',
        requiredValue: 75,
        type: 'books_read',
        points: 45,
      ),
      Achievement(
        id: 'hundred_books',
        name: 'Book Wizard',
        description: 'Finish 100 books',
        emoji: 'military_tech',
        category: 'reading',
        requiredValue: 100,
        type: 'books_read',
        points: 55,
      ),
      Achievement(
        id: 'hundred_fifty_books',
        name: 'Reading Legend',
        description: 'Finish 150 books',
        emoji: 'diamond',
        category: 'reading',
        requiredValue: 150,
        type: 'books_read',
        points: 70,
      ),
      Achievement(
        id: 'twohundred_books',
        name: 'Ultimate Reader',
        description: 'Finish 200 books',
        emoji: 'crown',
        category: 'reading',
        requiredValue: 200,
        type: 'books_read',
        points: 90,
      ),

      // Streak achievements (enhanced rewards for consistent reading)
      Achievement(
        id: 'streak_starter',
        name: 'Streak Starter',
        description: 'Read 3 days in a row',
        emoji: 'local_fire_department',
        category: 'streak',
        requiredValue: 3,
        type: 'reading_streak',
        points: 3,
      ),
      Achievement(
        id: 'five_day_streak',
        name: 'Week Warrior',
        description: 'Read 7 days in a row',
        emoji: 'whatshot',
        category: 'streak',
        requiredValue: 7,
        type: 'reading_streak',
        points: 5,
      ),
      Achievement(
        id: 'two_week_streak',
        name: 'Two Week Streak',
        description: 'Read 14 days in a row',
        emoji: 'done_outline',
        category: 'streak',
        requiredValue: 14,
        type: 'reading_streak',
        points: 8,
      ),
      Achievement(
        id: 'three_week_streak',
        name: 'Monthly Reader',
        description: 'Read 30 days in a row',
        emoji: 'power_settings_new',
        category: 'streak',
        requiredValue: 30,
        type: 'reading_streak',
        points: 12,
      ),
      Achievement(
        id: 'month_master',
        name: 'Streak Master',
        description: 'Read 60 days in a row',
        emoji: 'flash_on',
        category: 'streak',
        requiredValue: 60,
        type: 'reading_streak',
        points: 18,
      ),
      Achievement(
        id: 'fifty_day_streak',
        name: 'Century Streak',
        description: 'Read 100 days in a row',
        emoji: 'star_border',
        category: 'streak',
        requiredValue: 100,
        type: 'reading_streak',
        points: 25,
      ),

      // Time achievements
      Achievement(
        id: 'half_hour_reader',
        name: 'Quick Start',
        description: 'Read for 5 minutes total',
        emoji: 'schedule',
        category: 'time',
        requiredValue: 5,
        type: 'reading_time',
        points: 1,
      ),
      Achievement(
        id: 'hour_hero',
        name: 'Warm-Up Reader',
        description: 'Read for 15 minutes total',
        emoji: 'flash_on',
        category: 'time',
        requiredValue: 15,
        type: 'reading_time',
        points: 2,
      ),
      Achievement(
        id: 'two_hour_reader',
        name: 'Half-Hour Hero',
        description: 'Read for 30 minutes total',
        emoji: 'rocket_launch',
        category: 'time',
        requiredValue: 30,
        type: 'reading_time',
        points: 3,
      ),
      Achievement(
        id: 'time_traveler',
        name: 'One-Hour Reader',
        description: 'Read for 60 minutes total',
        emoji: 'sunny',
        category: 'time',
        requiredValue: 60,
        type: 'reading_time',
        points: 5,
      ),
      Achievement(
        id: 'marathon_reader',
        name: 'Two-Hour Reader',
        description: 'Read for 2 hours total',
        emoji: 'brightness_7',
        category: 'time',
        requiredValue: 120,
        type: 'reading_time',
        points: 8,
      ),
      Achievement(
        id: 'time_master',
        name: 'Five-Hour Reader',
        description: 'Read for 5 hours total',
        emoji: 'nights_stay',
        category: 'time',
        requiredValue: 300,
        type: 'reading_time',
        points: 12,
      ),
      Achievement(
        id: 'time_champion',
        name: 'Ten-Hour Champion',
        description: 'Read for 10 hours total',
        emoji: 'celebration',
        category: 'time',
        requiredValue: 600,
        type: 'reading_time',
        points: 18,
      ),

      // Reading session achievements (only sessions 2+ minutes count)
      Achievement(
        id: 'first_session',
        name: 'First Reading!',
        description: 'Read for 2 minutes',
        emoji: 'play_circle',
        category: 'sessions',
        requiredValue: 1,
        type: 'reading_sessions',
        points: 2,
      ),
      Achievement(
        id: 'five_sessions',
        name: 'Reading Buddy',
        description: 'Read 3 times',
        emoji: 'play_arrow',
        category: 'sessions',
        requiredValue: 3,
        type: 'reading_sessions',
        points: 5,
      ),
      Achievement(
        id: 'session_starter',
        name: 'Getting the Hang of It',
        description: 'Read 7 times',
        emoji: 'favorite_border',
        category: 'sessions',
        requiredValue: 7,
        type: 'reading_sessions',
        points: 8,
      ),
      Achievement(
        id: 'regular_reader',
        name: 'Regular Reader',
        description: 'Read 15 times',
        emoji: 'verified_user',
        category: 'sessions',
        requiredValue: 15,
        type: 'reading_sessions',
        points: 12,
      ),
      Achievement(
        id: 'dedicated_reader',
        name: 'Dedicated Reader',
        description: 'Read 30 times',
        emoji: 'star_outline',
        category: 'sessions',
        requiredValue: 30,
        type: 'reading_sessions',
        points: 18,
      ),
      Achievement(
        id: 'session_master',
        name: 'Super Regular',
        description: 'Read 50 times',
        emoji: 'badge',
        category: 'sessions',
        requiredValue: 50,
        type: 'reading_sessions',
        points: 25,
      ),
      Achievement(
        id: 'session_champion',
        name: 'Reading Champ',
        description: 'Read 75 times',
        emoji: 'card_giftcard',
        category: 'sessions',
        requiredValue: 75,
        type: 'reading_sessions',
        points: 30,
      ),
    ];
  }
}

class BookCompletionAwardResult {
  final int pointsEarned;
  final int totalBooksCompleted;
  final int newTotalPoints;
  final League? promotedLeague;

  const BookCompletionAwardResult({
    required this.pointsEarned,
    required this.totalBooksCompleted,
    required this.newTotalPoints,
    required this.promotedLeague,
  });
}
