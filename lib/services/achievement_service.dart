// File: lib/services/achievement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int requiredValue;
  final String type; // 'books_read', 'reading_streak', 'reading_time', 'quiz_completed'
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

  factory Achievement.fromMap(Map<String, dynamic> data, {bool isUnlocked = false, DateTime? unlockedAt}) {
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
      
      print('Achievements initialized successfully!');
    } catch (e) {
      print('Error initializing achievements: $e');
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

      return query.docs.map((doc) => Achievement.fromMap({
        'id': doc.id,
        ...doc.data(),
      })).toList();
    } catch (e) {
      print('Error getting all achievements: $e');
      return [];
    }
  }

  // Get user's achievements
  Future<List<Achievement>> getUserAchievements() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get all achievements
      final allAchievements = await getAllAchievements();
      
      // Get user's unlocked achievements
      final unlockedQuery = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .get();

      final unlockedMap = <String, DateTime>{};
      for (final doc in unlockedQuery.docs) {
        final data = doc.data();
        final achievementId = data['achievementId'] as String;
        final unlockedAt = (data['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        unlockedMap[achievementId] = unlockedAt;
      }

      // Mark achievements as unlocked
      return allAchievements.map((achievement) {
        final isUnlocked = unlockedMap.containsKey(achievement.id);
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
          unlockedAt: unlockedMap[achievement.id],
        );
      }).toList();
    } catch (e) {
      print('Error getting user achievements: $e');
      return [];
    }
  }

  // Check and unlock achievements based on user progress
  Future<List<Achievement>> checkAndUnlockAchievements({
    int? booksCompleted,
    int? readingStreak,
    int? totalReadingMinutes,
    bool? quizCompleted,
    int? totalSessions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final allAchievements = await getAllAchievements();
      final userAchievements = await getUserAchievements();
      final unlockedIds = userAchievements
          .where((a) => a.isUnlocked)
          .map((a) => a.id)
          .toSet();

      final newlyUnlocked = <Achievement>[];

      for (final achievement in allAchievements) {
        if (unlockedIds.contains(achievement.id)) continue;

        bool shouldUnlock = false;

        switch (achievement.type) {
          case 'books_read':
            shouldUnlock = (booksCompleted ?? 0) >= achievement.requiredValue;
            break;
          case 'reading_streak':
            shouldUnlock = (readingStreak ?? 0) >= achievement.requiredValue;
            break;
          case 'reading_time':
            shouldUnlock = (totalReadingMinutes ?? 0) >= achievement.requiredValue;
            break;
          case 'quiz_completed':
            shouldUnlock = quizCompleted == true;
            break;
          case 'reading_sessions':
            shouldUnlock = (totalSessions ?? 0) >= achievement.requiredValue;
            break;
        }

        if (shouldUnlock) {
          await _unlockAchievement(achievement);
          newlyUnlocked.add(achievement);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      print('Error checking achievements: $e');
      return [];
    }
  }

  // Unlock a specific achievement
  Future<void> _unlockAchievement(Achievement achievement) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Add to user achievements
      await _firestore.collection('user_achievements').add({
        'userId': user.uid,
        'achievementId': achievement.id,
        'achievementName': achievement.name,
        'category': achievement.category,
        'points': achievement.points,
        'unlockedAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      await _notificationService.sendAchievementNotification(
        achievementName: achievement.name,
        description: achievement.description,
        emoji: achievement.emoji,
      );

      print('Achievement unlocked: ${achievement.name}');
    } catch (e) {
      print('Error unlocking achievement: $e');
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
        (sum, doc) => sum + (doc.data()['points'] as int? ?? 0),
      );
    } catch (e) {
      print('Error getting user total points: $e');
      return 0;
    }
  }

  // Get achievements by category
  Future<List<Achievement>> getAchievementsByCategory(String category) async {
    final allAchievements = await getUserAchievements();
    return allAchievements.where((a) => a.category == category).toList();
  }

  // Get recently unlocked achievements
  Future<List<Achievement>> getRecentlyUnlockedAchievements({int limit = 5}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('user_achievements')
          .where('userId', isEqualTo: user.uid)
          .orderBy('unlockedAt', descending: true)
          .limit(limit)
          .get();

      final achievementIds = query.docs.map((doc) => doc.data()['achievementId'] as String).toList();
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
                .data()['unlockedAt']?.toDate(),
          ))
          .toList();
    } catch (e) {
      print('Error getting recently unlocked achievements: $e');
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
      final lockedAchievements = userAchievements.where((a) => !a.isUnlocked).toList();
      
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
        lockedAchievements.sort((a, b) => a.requiredValue.compareTo(b.requiredValue));
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
      print('Error getting progress towards next achievement: $e');
      return {'hasNext': false};
    }
  }

  // Get default achievements
  List<Achievement> _getDefaultAchievements() {
    return [
      // Reading achievements
      Achievement(
        id: 'first_book',
        name: 'First Steps',
        description: 'Complete your first book',
        emoji: '',
        category: 'reading',
        requiredValue: 1,
        type: 'books_read',
        points: 10,
      ),
      Achievement(
        id: 'book_lover',
        name: 'Book Lover',
        description: 'Complete 5 books',
        emoji: '',
        category: 'reading',
        requiredValue: 5,
        type: 'books_read',
        points: 25,
      ),
      Achievement(
        id: 'bookworm',
        name: 'Bookworm',
        description: 'Complete 10 books',
        emoji: '',
        category: 'reading',
        requiredValue: 10,
        type: 'books_read',
        points: 50,
      ),
      Achievement(
        id: 'reading_champion',
        name: 'Reading Champion',
        description: 'Complete 25 books',
        emoji: '',
        category: 'reading',
        requiredValue: 25,
        type: 'books_read',
        points: 100,
      ),

      // Streak achievements
      Achievement(
        id: 'streak_starter',
        name: 'Streak Starter',
        description: 'Read for 3 days in a row',
        emoji: '',
        category: 'streak',
        requiredValue: 3,
        type: 'reading_streak',
        points: 15,
      ),
      Achievement(
        id: 'week_warrior',
        name: 'Week Warrior',
        description: 'Read for 7 days in a row',
        emoji: '',
        category: 'streak',
        requiredValue: 7,
        type: 'reading_streak',
        points: 30,
      ),
      Achievement(
        id: 'month_master',
        name: 'Month Master',
        description: 'Read for 30 days in a row',
        emoji: '',
        category: 'streak',
        requiredValue: 30,
        type: 'reading_streak',
        points: 100,
      ),

      // Time achievements
      Achievement(
        id: 'hour_hero',
        name: 'Hour Hero',
        description: 'Read for 60 minutes total',
        emoji: '',
        category: 'time',
        requiredValue: 60,
        type: 'reading_time',
        points: 20,
      ),
      Achievement(
        id: 'time_traveler',
        name: 'Time Traveler',
        description: 'Read for 5 hours total',
        emoji: '',
        category: 'time',
        requiredValue: 300,
        type: 'reading_time',
        points: 50,
      ),
      Achievement(
        id: 'marathon_reader',
        name: 'Marathon Reader',
        description: 'Read for 10 hours total',
        emoji: '',
        category: 'time',
        requiredValue: 600,
        type: 'reading_time',
        points: 100,
      ),

      // Quiz achievements
      Achievement(
        id: 'personality_explorer',
        name: 'Personality Explorer',
        description: 'Complete the personality quiz',
        emoji: '',
        category: 'quiz',
        requiredValue: 1,
        type: 'quiz_completed',
        points: 15,
      ),

      // Session achievements
      Achievement(
        id: 'session_starter',
        name: 'Session Starter',
        description: 'Complete 10 reading sessions',
        emoji: '',
        category: 'sessions',
        requiredValue: 10,
        type: 'reading_sessions',
        points: 25,
      ),
      Achievement(
        id: 'dedicated_reader',
        name: 'Dedicated Reader',
        description: 'Complete 50 reading sessions',
        emoji: '',
        category: 'sessions',
        requiredValue: 50,
        type: 'reading_sessions',
        points: 75,
      ),
    ];
  }
}
