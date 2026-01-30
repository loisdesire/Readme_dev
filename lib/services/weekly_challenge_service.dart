// File: lib/services/weekly_challenge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';
import 'logger.dart';

enum ChallengeType {
  completeBooks,
  readDays,
  readingTime,
  completeQuizzes,
  consecutiveDays,
  quizScore,
  dailyMinutes,
  unlockAchievement,
  readGenres,
  readPages,
}

class WeeklyChallenge {
  final ChallengeType type;
  final String name;
  final String emoji;
  final String description;
  final int target;
  final int weekNumber; // 0-11 for 12-week rotation

  const WeeklyChallenge({
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    required this.target,
    required this.weekNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'name': name,
      'emoji': emoji,
      'description': description,
      'target': target,
      'weekNumber': weekNumber,
    };
  }
}

class WeeklyChallengeService {
  static final WeeklyChallengeService _instance =
      WeeklyChallengeService._internal();
  factory WeeklyChallengeService() => _instance;
  WeeklyChallengeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreHelpers _firestoreHelpers = FirestoreHelpers();

  /// Public wrapper for tolerant challenge-type parsing.
  ///
  /// Accepts values like "completeQuizzes" or "ChallengeType.completeQuizzes".
  ChallengeType parseChallengeType(String? value) => _parseChallengeType(value);

  ChallengeType _parseChallengeType(String? value) {
    if (value == null) return ChallengeType.completeBooks;
    final normalized = value.trim();
    if (normalized.isEmpty) return ChallengeType.completeBooks;

    // Accept either "completeQuizzes" or "ChallengeType.completeQuizzes"
    final lastSegment = normalized.contains('.')
        ? normalized.split('.').last.trim()
        : normalized;

    final lower = lastSegment.toLowerCase();
    try {
      return ChallengeType.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == lower,
        orElse: () => ChallengeType.completeBooks,
      );
    } catch (_) {
      return ChallengeType.completeBooks;
    }
  }

  /// Refreshes progress for the user's currently active weekly challenge.
  ///
  /// If [userProgress] or [weeklyReadingProgress] are omitted, this method will
  /// compute what it needs from Firestore.
  Future<void> refreshCurrentChallengeProgress({
    required String userId,
    List<dynamic>? userProgress,
    Map<String, int>? weeklyReadingProgress,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();
      final userData = snapshot.data();
      if (userData == null) return;

      final currentType =
          _parseChallengeType(userData['currentChallengeType'] as String?);
      final target = userData['currentChallengeTarget'] as int? ?? 1;
      final startOfWeek = getStartOfWeek();

      final progress = await calculateProgress(
        userId: userId,
        challengeType: currentType,
        startOfWeek: startOfWeek,
        userData: userData,
        userProgress: userProgress,
        weeklyReadingProgress: weeklyReadingProgress,
      );

      await updateProgress(
        userId: userId,
        progress: progress,
        target: target,
      );
    } catch (e) {
      appLog('Error refreshing current weekly challenge progress: $e',
          level: 'ERROR');
    }
  }

  Future<void> _refreshProgressIfCurrentChallengeIsOneOf({
    required String userId,
    required Set<ChallengeType> types,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();
      final userData = snapshot.data();
      if (userData == null) return;

      final currentChallengeTypeStr =
          userData['currentChallengeType'] as String?;
      final currentType = _parseChallengeType(currentChallengeTypeStr);
      if (!types.contains(currentType)) return;

      final target = userData['currentChallengeTarget'] as int? ?? 1;
      final startOfWeek = getStartOfWeek();
      final progress = await calculateProgress(
        userId: userId,
        challengeType: currentType,
        startOfWeek: startOfWeek,
        userData: userData,
      );

      await updateProgress(
        userId: userId,
        progress: progress,
        target: target,
      );
    } catch (e) {
      appLog('Error refreshing weekly challenge progress: $e', level: 'ERROR');
    }
  }

  // 12-week challenge rotation - Fixed and predictable
  static const List<WeeklyChallenge> challengeRotation = [
    WeeklyChallenge(
      type: ChallengeType.completeBooks,
      name: 'Complete 1 book',
      emoji: '📚',
      description: 'Finish reading one complete book this week',
      target: 1,
      weekNumber: 0,
    ),
    WeeklyChallenge(
      type: ChallengeType.readDays,
      name: 'Read 3 different days',
      emoji: '📅',
      description: 'Read on at least 3 different days',
      target: 3,
      weekNumber: 1,
    ),
    WeeklyChallenge(
      type: ChallengeType.readingTime,
      name: 'Read for 30 minutes',
      emoji: '⏱️',
      description: 'Spend a total of 30 minutes reading this week',
      target: 30,
      weekNumber: 2,
    ),
    WeeklyChallenge(
      type: ChallengeType.completeQuizzes,
      name: 'Complete 2 quizzes',
      emoji: '🎯',
      description: 'Take and complete 2 book quizzess',
      target: 2,
      weekNumber: 3,
    ),
    WeeklyChallenge(
      type: ChallengeType.consecutiveDays,
      name: 'Read 3 days in a row',
      emoji: '🔥',
      description: 'Build a 3-day reading streak',
      target: 3,
      weekNumber: 4,
    ),
    WeeklyChallenge(
      type: ChallengeType.readDays,
      name: 'Read 5 different days',
      emoji: '📖',
      description: 'Read on 5 different days',
      target: 5,
      weekNumber: 5,
    ),
    WeeklyChallenge(
      type: ChallengeType.quizScore,
      name: 'Score 80%+ on a quiz',
      emoji: '🎓',
      description: 'Get at least 4 out of 5 on one quiz',
      target: 80,
      weekNumber: 6,
    ),
    WeeklyChallenge(
      type: ChallengeType.dailyMinutes,
      name: 'Read 10 min for 3 days',
      emoji: '⚡',
      description: 'Read at least 10 minutes on 3 different days',
      target: 3,
      weekNumber: 7,
    ),
    WeeklyChallenge(
      type: ChallengeType.unlockAchievement,
      name: 'Unlock 1 achievement',
      emoji: '🌟',
      description: 'Earn any achievement badge',
      target: 1,
      weekNumber: 8,
    ),
    WeeklyChallenge(
      type: ChallengeType.completeBooks,
      name: 'Complete 2 books',
      emoji: '📚',
      description: 'Finish reading two complete books',
      target: 2,
      weekNumber: 9,
    ),
    WeeklyChallenge(
      type: ChallengeType.readGenres,
      name: 'Read 3 different genres',
      emoji: '🎨',
      description: 'Explore books from 3 different genres',
      target: 3,
      weekNumber: 10,
    ),
    WeeklyChallenge(
      type: ChallengeType.readingTime,
      name: 'Read for 60 minutes',
      emoji: '💪',
      description: 'Spend a total of 60 minutes reading',
      target: 60,
      weekNumber: 11,
    ),
  ];

  /// Get the start of the current week (Monday at 00:00)
  DateTime getStartOfWeek([DateTime? date]) {
    final now = date ?? DateTime.now();
    final mondayOffset = now.weekday - 1; // weekday is 1-7 (Mon-Sun)
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: mondayOffset));
  }

  /// Get week number in the year (0-based)
  int getWeekOfYear([DateTime? date]) {
    final now = date ?? DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final daysSinceYearStart = now.difference(startOfYear).inDays;
    return (daysSinceYearStart / 7).floor();
  }

  /// Get current challenge based on 12-week rotation
  WeeklyChallenge getCurrentChallenge() {
    final weekOfYear = getWeekOfYear();
    final rotationIndex = weekOfYear % challengeRotation.length;
    return challengeRotation[rotationIndex];
  }

  /// Initialize or update weekly challenge for a user
  /// Returns true if challenge was updated (new week), false if same week
  Future<bool> initializeWeeklyChallenge(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();
      final data = snapshot.data();

      final startOfWeek = getStartOfWeek();
      final weekKey =
          '${startOfWeek.year}_${startOfWeek.month}_${startOfWeek.day}';
      final lastWeekKey = data?['lastWeeklyChallengeWeek'] as String?;

      // Check if we need to initialize new week
      if (lastWeekKey != weekKey) {
        final currentChallenge = getCurrentChallenge();

        // Store previous week's completion status if it existed
        final wasCompleted =
            data?['weeklyChallengeCompleted'] as bool? ?? false;
        final previousProgress = data?['weeklyChallengeProgress'] as int? ?? 0;

        // Initialize new week's challenge
        await userDoc.set({
          'lastWeeklyChallengeWeek': weekKey,
          'weeklyChallengeSeen': false,
          'weeklyChallengeCompleted': false,
          'weeklyChallengeProgress': 0,
          'currentChallengeType':
              currentChallenge.type.toString().split('.').last,
          'currentChallengeTarget': currentChallenge.target,
          'currentChallengeName': currentChallenge.name,
          'currentChallengeEmoji': currentChallenge.emoji,
          'currentChallengeDescription': currentChallenge.description,
          'currentChallengeWeekNumber': currentChallenge.weekNumber,
          // Archive previous week's data
          'previousWeekKey': lastWeekKey,
          'previousWeekCompleted': wasCompleted,
          'previousWeekProgress': previousProgress,
          'weekTransitionedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        appLog('New weekly challenge initialized: ${currentChallenge.name}',
            level: 'INFO');
        return true; // New week started
      }

      return false; // Same week, no update needed
    } catch (e) {
      appLog('Error initializing weekly challenge: $e', level: 'ERROR');
      return false;
    }
  }

  /// Calculate current progress for a specific challenge type
  Future<int> calculateProgress({
    required String userId,
    required ChallengeType challengeType,
    required DateTime startOfWeek,
    Map<String, dynamic>? userData,
    List<dynamic>? userProgress,
    Map<String, int>? weeklyReadingProgress,
  }) async {
    try {
      // Load user doc lazily for challenges that rely on user-level counters.
      userData ??=
          (await _firestore.collection('users').doc(userId).get()).data();

      // Load weekly reading map lazily for challenges that rely on day-level minutes.
      Map<String, int>? effectiveWeeklyReadingProgress = weeklyReadingProgress;
      if (effectiveWeeklyReadingProgress == null &&
          (challengeType == ChallengeType.readDays ||
              challengeType == ChallengeType.readingTime ||
              challengeType == ChallengeType.consecutiveDays ||
              challengeType == ChallengeType.dailyMinutes)) {
        effectiveWeeklyReadingProgress =
            await _firestoreHelpers.getWeeklyReadingData(
          userId: userId,
          weekStart: startOfWeek,
        );
      }

      switch (challengeType) {
        case ChallengeType.completeBooks:
          // Count completed books this week
          if (userProgress != null) {
            return userProgress.where((p) {
              final progress = p as Map<String, dynamic>;
              if (progress['isCompleted'] != true) return false;
              final lastRead = (progress['lastReadAt'] as Timestamp?)?.toDate();
              if (lastRead == null) return false;
              return lastRead.isAfter(startOfWeek) ||
                  lastRead.isAtSameMomentAs(startOfWeek);
            }).length;
          }

          final completedQuery = await _firestoreHelpers.getReadingProgress(
            userId: userId,
            startDate: startOfWeek,
            completedOnly: true,
          );
          return completedQuery.docs.length;

        case ChallengeType.readDays:
          // Count days with reading activity this week
          if (effectiveWeeklyReadingProgress == null) return 0;
          return effectiveWeeklyReadingProgress.values
              .where((minutes) => minutes > 0)
              .length;

        case ChallengeType.readingTime:
          // Total reading minutes this week (prefer session-based daily minutes map if available).
          if (effectiveWeeklyReadingProgress != null) {
            return effectiveWeeklyReadingProgress.values
                .fold<int>(0, (total, minutes) => total + minutes);
          }

          // Fallback: approximate from provided reading_progress snapshots.
          if (userProgress == null) return 0;
          return userProgress.where((p) {
            final progress = p as Map<String, dynamic>;
            final lastRead = (progress['lastReadAt'] as Timestamp?)?.toDate();
            if (lastRead == null) return false;
            return lastRead.isAfter(startOfWeek) ||
                lastRead.isAtSameMomentAs(startOfWeek);
          }).fold<int>(0, (total, p) {
            final progress = p as Map<String, dynamic>;
            return total + (progress['readingTimeMinutes'] as int? ?? 0);
          });

        case ChallengeType.completeQuizzes:
          // Count quizzes completed this week
          final quizzesThisWeek =
              userData?['quizzesCompletedThisWeek'] as int? ?? 0;
          return quizzesThisWeek;

        case ChallengeType.consecutiveDays:
          // Longest consecutive reading streak this week.
          // Prefer computing from weeklyReadingProgress to avoid relying on a field that may not be written.
          if (effectiveWeeklyReadingProgress == null) {
            return userData?['longestConsecutiveStreakThisWeek'] as int? ?? 0;
          }

          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          var current = 0;
          var best = 0;
          for (final day in days) {
            final minutes = effectiveWeeklyReadingProgress[day] ?? 0;
            if (minutes > 0) {
              current += 1;
              if (current > best) best = current;
            } else {
              current = 0;
            }
          }
          return best;

        case ChallengeType.quizScore:
          // Best quiz score this week (0-100)
          final bestScore = userData?['bestQuizScoreThisWeek'] as int? ?? 0;
          return bestScore;

        case ChallengeType.dailyMinutes:
          // Days with at least 10 minutes of reading
          if (effectiveWeeklyReadingProgress == null) return 0;
          return effectiveWeeklyReadingProgress.values
              .where((minutes) => minutes >= 10)
              .length;

        case ChallengeType.unlockAchievement:
          // Achievements unlocked this week
          final achievementsThisWeek =
              userData?['achievementsUnlockedThisWeek'] as int? ?? 0;
          return achievementsThisWeek;

        case ChallengeType.readGenres:
          // Unique genres read this week
          final genresThisWeek = userData?['genresReadThisWeek'] as List? ?? [];
          return genresThisWeek.length;

        case ChallengeType.readPages:
          // Total pages read this week
          final pagesThisWeek = userData?['pagesReadThisWeek'] as int? ?? 0;
          return pagesThisWeek;
      }
    } catch (e) {
      appLog('Error calculating challenge progress: $e', level: 'ERROR');
      return 0;
    }
  }

  /// Update challenge progress
  Future<void> updateProgress({
    required String userId,
    required int progress,
    required int target,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final isCompleted = progress >= target;

      // Check if celebration has been seen
      final userData = (await userDoc.get()).data();
      final celebrationSeen =
          (userData?['weeklyChallengeSeen'] as bool?) ?? false;

      await userDoc.set({
        'weeklyChallengeProgress': progress,
        'weeklyChallengeCompleted': isCompleted,
        if (isCompleted && !celebrationSeen)
          'weeklyChallengeSeen': false, // Reset to show celebration
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error updating challenge progress: $e', level: 'ERROR');
    }
  }

  /// Mark challenge celebration as seen
  Future<void> markCelebrationSeen(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'weeklyChallengeSeen': true,
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error marking celebration as seen: $e', level: 'ERROR');
    }
  }

  /// Track quiz completion for weekly challenges
  Future<void> trackQuizCompletion({
    required String userId,
    required int score, // 0-100
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((txn) async {
        final snapshot = await txn.get(userDoc);
        final data = snapshot.data();
        final currentCount = data?['quizzesCompletedThisWeek'] as int? ?? 0;
        final currentBestScore = data?['bestQuizScoreThisWeek'] as int? ?? 0;
        final newBest = score > currentBestScore ? score : currentBestScore;

        txn.set(
          userDoc,
          {
            'quizzesCompletedThisWeek': currentCount + 1,
            'bestQuizScoreThisWeek': newBest,
          },
          SetOptions(merge: true),
        );
      });

      // If the active weekly challenge is quiz-based, refresh it immediately.
      await _refreshProgressIfCurrentChallengeIsOneOf(
        userId: userId,
        types: {ChallengeType.completeQuizzes, ChallengeType.quizScore},
      );
    } catch (e) {
      appLog('Error tracking quiz completion: $e', level: 'ERROR');
    }
  }

  /// Public helper: refresh weekly progress for quiz-based challenges.
  /// Safe to call after a quiz completes.
  Future<void> refreshQuizChallengeProgress(String userId) async {
    await _refreshProgressIfCurrentChallengeIsOneOf(
      userId: userId,
      types: {ChallengeType.completeQuizzes, ChallengeType.quizScore},
    );
  }

  /// Track achievement unlock for weekly challenges
  Future<void> trackAchievementUnlock(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      await userDoc.set({
        'achievementsUnlockedThisWeek': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await _refreshProgressIfCurrentChallengeIsOneOf(
        userId: userId,
        types: {ChallengeType.unlockAchievement},
      );
    } catch (e) {
      appLog('Error tracking achievement unlock: $e', level: 'ERROR');
    }
  }

  /// Track genre reading for weekly challenges
  Future<void> trackGenreRead({
    required String userId,
    required String genre,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      await userDoc.set({
        'genresReadThisWeek': FieldValue.arrayUnion([genre]),
      }, SetOptions(merge: true));

      await _refreshProgressIfCurrentChallengeIsOneOf(
        userId: userId,
        types: {ChallengeType.readGenres},
      );
    } catch (e) {
      appLog('Error tracking genre reading: $e', level: 'ERROR');
    }
  }

  /// Reset weekly tracking fields (called on week transition)
  Future<void> resetWeeklyTracking(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'quizzesCompletedThisWeek': 0,
        'bestQuizScoreThisWeek': 0,
        'longestConsecutiveStreakThisWeek': 0,
        'achievementsUnlockedThisWeek': 0,
        'genresReadThisWeek': [],
        'pagesReadThisWeek': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error resetting weekly tracking: $e', level: 'ERROR');
    }
  }
}
