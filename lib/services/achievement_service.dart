// File: lib/services/achievement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'logger.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

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
  AchievementService._internal();

  // Initialize achievements (call this once to set up the achievement system)
  Future<void> initializeAchievements() async {
    try {
      final achievements = _getDefaultAchievements();

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

        bool shouldUnlock = false;

        switch (achievement.type) {
          case 'books_read':
            shouldUnlock = (booksCompleted ?? 0) >= achievement.requiredValue;
            break;
          case 'reading_streak':
            shouldUnlock = (readingStreak ?? 0) >= achievement.requiredValue;
            break;
          case 'reading_time':
            shouldUnlock =
                (totalReadingMinutes ?? 0) >= achievement.requiredValue;
            break;
          case 'reading_sessions':
            shouldUnlock = (totalSessions ?? 0) >= achievement.requiredValue;
            break;
        }

        if (shouldUnlock) {
          appLog(
              '[ACHIEVEMENT UNLOCK] ${achievement.name} (${achievement.type}: ${achievement.requiredValue})',
              level: 'INFO');
          await _unlockAchievement(achievement);
          newlyUnlocked.add(achievement);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      appLog('Error checking achievements: $e', level: 'ERROR');
      return [];
    }
  }

  // Unlock a specific achievement
  Future<void> _unlockAchievement(Achievement achievement) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Prevent race condition: Check if this achievement is already being unlocked
    final lockKey = '${user.uid}_${achievement.id}';
    if (_unlockingInProgress.contains(lockKey)) {
      appLog('[ACHIEVEMENT] Already unlocking: ${achievement.name}',
          level: 'DEBUG');
      return;
    }

    try {
      // Add to in-progress set
      _unlockingInProgress.add(lockKey);

      // Check if achievement is already unlocked (prevent duplicates)
      final existingQuery = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .where('achievementId', isEqualTo: achievement.id)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        appLog('[ACHIEVEMENT] Already exists in database: ${achievement.name}',
            level: 'WARN');
        return;
      }

      // Add to user achievements
      await _firestore.collection('user_achievements').add({
        'userId': user.uid,
        'achievementId': achievement.id,
        'achievementName': achievement.name,
        'category': achievement.category,
        'points': achievement.points,
        'unlockedAt': FieldValue.serverTimestamp(),
        'popupShown':
            false, // For AchievementListener to know if popup was displayed
      });

      // Update user's total achievement points
      await _firestore.collection('users').doc(user.uid).set({
        'totalAchievementPoints': FieldValue.increment(achievement.points),
      }, SetOptions(merge: true));

      // Invalidate cache so next check uses fresh data
      _invalidateCache();

      // Send notification
      await _notificationService.sendAchievementNotification(
        achievementName: achievement.name,
        description: achievement.description,
        emoji: achievement.emoji,
      );

      appLog('Achievement unlocked: ${achievement.name}', level: 'INFO');
    } catch (e) {
      appLog('Error unlocking achievement: $e', level: 'ERROR');
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

  // Migration helper: Mark all existing achievements as popupShown to prevent re-showing
  // Call this once after deploying the new Firebase-streaming popup system
  Future<void> markAllExistingAchievementsAsShown() async {
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
  List<Achievement> _getDefaultAchievements() {
    return [
      // Reading achievements - using icon names instead of emojis
      Achievement(
        id: 'first_book',
        name: 'First Steps',
        description: 'Complete your first book',
        emoji: 'book',
        category: 'reading',
        requiredValue: 1,
        type: 'books_read',
        points: 10,
      ),
      Achievement(
        id: 'three_books',
        name: 'Getting Started',
        description: 'Complete 3 books',
        emoji: 'menu_book',
        category: 'reading',
        requiredValue: 3,
        type: 'books_read',
        points: 15,
      ),
      Achievement(
        id: 'book_lover',
        name: 'Book Lover',
        description: 'Complete 5 books',
        emoji: 'favorite',
        category: 'reading',
        requiredValue: 5,
        type: 'books_read',
        points: 25,
      ),
      Achievement(
        id: 'bookworm',
        name: 'Bookworm',
        description: 'Complete 10 books',
        emoji: 'auto_stories',
        category: 'reading',
        requiredValue: 10,
        type: 'books_read',
        points: 40,
      ),
      Achievement(
        id: 'fifteen_books',
        name: 'Reading Enthusiast',
        description: 'Complete 15 books',
        emoji: 'import_contacts',
        category: 'reading',
        requiredValue: 15,
        type: 'books_read',
        points: 60,
      ),
      Achievement(
        id: 'twenty_books',
        name: 'Avid Reader',
        description: 'Complete 20 books',
        emoji: 'library_books',
        category: 'reading',
        requiredValue: 20,
        type: 'books_read',
        points: 80,
      ),
      Achievement(
        id: 'thirty_books',
        name: 'Reading Star',
        description: 'Complete 30 books',
        emoji: 'star',
        category: 'reading',
        requiredValue: 30,
        type: 'books_read',
        points: 120,
      ),
      Achievement(
        id: 'forty_books',
        name: 'Book Champion',
        description: 'Complete 40 books',
        emoji: 'emoji_events',
        category: 'reading',
        requiredValue: 40,
        type: 'books_read',
        points: 160,
      ),
      Achievement(
        id: 'fifty_books',
        name: 'Super Reader',
        description: 'Complete 50 books',
        emoji: 'stars',
        category: 'reading',
        requiredValue: 50,
        type: 'books_read',
        points: 200,
      ),
      Achievement(
        id: 'seventyfive_books',
        name: 'Reading Master',
        description: 'Complete 75 books',
        emoji: 'workspace_premium',
        category: 'reading',
        requiredValue: 75,
        type: 'books_read',
        points: 300,
      ),
      Achievement(
        id: 'hundred_books',
        name: 'Century Reader',
        description: 'Complete 100 books',
        emoji: 'military_tech',
        category: 'reading',
        requiredValue: 100,
        type: 'books_read',
        points: 400,
      ),
      Achievement(
        id: 'hundred_fifty_books',
        name: 'Reading Legend',
        description: 'Complete 150 books',
        emoji: 'diamond',
        category: 'reading',
        requiredValue: 150,
        type: 'books_read',
        points: 600,
      ),
      Achievement(
        id: 'twohundred_books',
        name: 'Ultimate Reader',
        description: 'Complete 200 books',
        emoji: 'crown',
        category: 'reading',
        requiredValue: 200,
        type: 'books_read',
        points: 1000,
      ),

      // Streak achievements
      Achievement(
        id: 'streak_starter',
        name: 'Streak Starter',
        description: 'Read for 3 days in a row',
        emoji: 'local_fire_department',
        category: 'streak',
        requiredValue: 3,
        type: 'reading_streak',
        points: 15,
      ),
      Achievement(
        id: 'five_day_streak',
        name: 'Getting Hot',
        description: 'Read for 5 days in a row',
        emoji: 'local_fire_department',
        category: 'streak',
        requiredValue: 5,
        type: 'reading_streak',
        points: 25,
      ),
      Achievement(
        id: 'week_warrior',
        name: 'Week Warrior',
        description: 'Read for 7 days in a row',
        emoji: 'whatshot',
        category: 'streak',
        requiredValue: 7,
        type: 'reading_streak',
        points: 35,
      ),
      Achievement(
        id: 'two_week_streak',
        name: 'On Fire',
        description: 'Read for 14 days in a row',
        emoji: 'whatshot',
        category: 'streak',
        requiredValue: 14,
        type: 'reading_streak',
        points: 60,
      ),
      Achievement(
        id: 'three_week_streak',
        name: 'Unstoppable',
        description: 'Read for 21 days in a row',
        emoji: 'bolt',
        category: 'streak',
        requiredValue: 21,
        type: 'reading_streak',
        points: 80,
      ),
      Achievement(
        id: 'month_master',
        name: 'Month Master',
        description: 'Read for 30 days in a row',
        emoji: 'bolt',
        category: 'streak',
        requiredValue: 30,
        type: 'reading_streak',
        points: 100,
      ),
      Achievement(
        id: 'fifty_day_streak',
        name: 'Streak Champion',
        description: 'Read for 50 days in a row',
        emoji: 'stars',
        category: 'streak',
        requiredValue: 50,
        type: 'reading_streak',
        points: 150,
      ),
      Achievement(
        id: 'hundred_day_streak',
        name: 'Streak Legend',
        description: 'Read for 100 days in a row',
        emoji: 'diamond',
        category: 'streak',
        requiredValue: 100,
        type: 'reading_streak',
        points: 300,
      ),

      // Time achievements
      Achievement(
        id: 'half_hour_reader',
        name: 'Getting Started',
        description: 'Read for 30 minutes total',
        emoji: 'schedule',
        category: 'time',
        requiredValue: 30,
        type: 'reading_time',
        points: 10,
      ),
      Achievement(
        id: 'hour_hero',
        name: 'Hour Hero',
        description: 'Read for 60 minutes total',
        emoji: 'schedule',
        category: 'time',
        requiredValue: 60,
        type: 'reading_time',
        points: 20,
      ),
      Achievement(
        id: 'two_hour_reader',
        name: 'Time Keeper',
        description: 'Read for 2 hours total',
        emoji: 'access_time',
        category: 'time',
        requiredValue: 120,
        type: 'reading_time',
        points: 35,
      ),
      Achievement(
        id: 'time_traveler',
        name: 'Time Traveler',
        description: 'Read for 5 hours total',
        emoji: 'access_time',
        category: 'time',
        requiredValue: 300,
        type: 'reading_time',
        points: 60,
      ),
      Achievement(
        id: 'marathon_reader',
        name: 'Marathon Reader',
        description: 'Read for 10 hours total',
        emoji: 'timer',
        category: 'time',
        requiredValue: 600,
        type: 'reading_time',
        points: 100,
      ),
      Achievement(
        id: 'time_master',
        name: 'Time Master',
        description: 'Read for 20 hours total',
        emoji: 'timer',
        category: 'time',
        requiredValue: 1200,
        type: 'reading_time',
        points: 150,
      ),
      Achievement(
        id: 'time_champion',
        name: 'Time Champion',
        description: 'Read for 50 hours total',
        emoji: 'hourglass_full',
        category: 'time',
        requiredValue: 3000,
        type: 'reading_time',
        points: 250,
      ),

      // Reading Streak achievements (only sessions 5+ minutes count)
      Achievement(
        id: 'first_session',
        name: 'First Reading!',
        description: 'Read for 5 minutes or more',
        emoji: 'play_circle',
        category: 'sessions',
        requiredValue: 1,
        type: 'reading_sessions',
        points: 10,
      ),
      Achievement(
        id: 'five_sessions',
        name: 'Getting Started',
        description: 'Read for 5+ minutes, 5 different times',
        emoji: 'play_circle',
        category: 'sessions',
        requiredValue: 5,
        type: 'reading_sessions',
        points: 20,
      ),
      Achievement(
        id: 'session_starter',
        name: 'Book Lover',
        description: 'Read for 5+ minutes, 10 different times',
        emoji: 'favorite',
        category: 'sessions',
        requiredValue: 10,
        type: 'reading_sessions',
        points: 35,
      ),
      Achievement(
        id: 'regular_reader',
        name: 'Reading Champion',
        description: 'Read for 5+ minutes, 20 different times',
        emoji: 'verified',
        category: 'sessions',
        requiredValue: 20,
        type: 'reading_sessions',
        points: 60,
      ),
      Achievement(
        id: 'dedicated_reader',
        name: 'Super Reader',
        description: 'Read for 5+ minutes, 40 different times',
        emoji: 'star',
        category: 'sessions',
        requiredValue: 40,
        type: 'reading_sessions',
        points: 100,
      ),
      Achievement(
        id: 'session_master',
        name: 'Reading Master',
        description: 'Read for 5+ minutes, 75 different times',
        emoji: 'workspace_premium',
        category: 'sessions',
        requiredValue: 75,
        type: 'reading_sessions',
        points: 180,
      ),
      Achievement(
        id: 'session_champion',
        name: 'Reading Legend',
        description: 'Read for 5+ minutes, 100 different times',
        emoji: 'military_tech',
        category: 'sessions',
        requiredValue: 100,
        type: 'reading_sessions',
        points: 300,
      ),
    ];
  }
}
