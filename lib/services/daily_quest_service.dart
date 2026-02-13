import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/date_utils.dart';

class DailyQuestService {
  DailyQuestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'dailyQuests';

  static const String questReadGoal = 'read_goal';
  static const String questKeepStreak = 'keep_streak';
  static const String questMiniRead = 'mini_read';

  static String todayDateKey() => AppDateUtils.formatDateKey(DateTime.now());

  DocumentReference<Map<String, dynamic>> docRef({
    required String userId,
    required String dateKey,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(collectionName)
        .doc(dateKey);
  }

  Future<Map<String, dynamic>?> getTodayDoc(String userId) async {
    final dateKey = todayDateKey();
    final snap = await docRef(userId: userId, dateKey: dateKey).get();
    return snap.data();
  }

  /// Upserts today's daily quest doc using current reading stats.
  ///
  /// This keeps completion state in Firestore so:
  /// - quests are consistent across devices
  /// - we can reward/claim safely
  /// - history exists per day
  Future<({Map<String, dynamic> doc, int awardedStars})> upsertTodayFromStats({
    required String userId,
    required int minutesReadToday,
    required int dailyGoalMinutes,
    required bool hasReadToday,
  }) async {
    final dateKey = todayDateKey();
    final ref = docRef(userId: userId, dateKey: dateKey);
    final userRef = _firestore.collection('users').doc(userId);

    const rewards = {
      questReadGoal: 5,
      questKeepStreak: 3,
      questMiniRead: 2,
    };

    final completedReadGoal = minutesReadToday >= dailyGoalMinutes;
    final completedKeepStreak = hasReadToday;
    final completedMiniRead = minutesReadToday >= 2;

    var awardedStars = 0;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final alreadyRewarded = data['rewarded'] == true;

      final existingQuestsRaw = data['quests'];
      final existingQuests = existingQuestsRaw is Map
          ? Map<String, dynamic>.from(existingQuestsRaw)
          : <String, dynamic>{};

      Map<String, dynamic> mergeQuest(
        String key, {
        required bool completed,
        required int rewardStars,
        required String title,
        required String subtitle,
      }) {
        final existingRaw = existingQuests[key];
        final existing = existingRaw is Map
            ? Map<String, dynamic>.from(existingRaw)
            : <String, dynamic>{};

        final wasCompleted = existing['completed'] == true;

        return {
          ...existing,
          'key': key,
          'title': title,
          'subtitle': subtitle,
          'rewardStars': rewardStars,
          'completed': completed,
          if (completed && !wasCompleted)
            'completedAt': FieldValue.serverTimestamp(),
        };
      }

      existingQuests[questReadGoal] = mergeQuest(
        questReadGoal,
        completed: completedReadGoal,
        rewardStars: rewards[questReadGoal]!,
        title: 'Read $dailyGoalMinutes minutes',
        subtitle: '$minutesReadToday / $dailyGoalMinutes min',
      );

      existingQuests[questKeepStreak] = mergeQuest(
        questKeepStreak,
        completed: completedKeepStreak,
        rewardStars: rewards[questKeepStreak]!,
        title: 'Keep your streak',
        subtitle: hasReadToday
            ? 'You read today — streak protected'
            : 'Read today to keep it going',
      );

      existingQuests[questMiniRead] = mergeQuest(
        questMiniRead,
        completed: completedMiniRead,
        rewardStars: rewards[questMiniRead]!,
        title: 'Do a mini read',
        subtitle: completedMiniRead ? 'Done!' : 'Even 2 minutes counts',
      );

      final allCompleted =
          (existingQuests[questReadGoal] as Map?)?['completed'] == true &&
              (existingQuests[questKeepStreak] as Map?)?['completed'] == true &&
              (existingQuests[questMiniRead] as Map?)?['completed'] == true;

      if (allCompleted && !alreadyRewarded) {
        final readReward =
            ((existingQuests[questReadGoal] as Map?)?['rewardStars'] as num?)
                    ?.toInt() ??
                rewards[questReadGoal]!;
        final streakReward =
            ((existingQuests[questKeepStreak] as Map?)?['rewardStars'] as num?)
                    ?.toInt() ??
                rewards[questKeepStreak]!;
        final miniReward =
            ((existingQuests[questMiniRead] as Map?)?['rewardStars'] as num?)
                    ?.toInt() ??
                rewards[questMiniRead]!;

        awardedStars = readReward + streakReward + miniReward;

        tx.update(userRef, {
          'totalAchievementPoints': FieldValue.increment(awardedStars),
          'allTimePoints': FieldValue.increment(awardedStars),
          // Optional: keep a separate counter for analytics/visibility later.
          'dailyQuestStarsEarned': FieldValue.increment(awardedStars),
        });
      }

      tx.set(
        ref,
        {
          'dateKey': dateKey,
          'dailyGoalMinutes': dailyGoalMinutes,
          'minutesReadToday': minutesReadToday,
          'quests': existingQuests,
          if (allCompleted && !alreadyRewarded) ...{
            'rewarded': true,
            'rewardedStars': awardedStars,
            'rewardedAt': FieldValue.serverTimestamp(),
          },
          if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    final fresh = await ref.get();
    return (
      doc: fresh.data() ?? <String, dynamic>{},
      awardedStars: awardedStars,
    );
  }
}
