import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/date_utils.dart';
import 'points_engine_client.dart';

class DailyQuestService {
  DailyQuestService({FirebaseFirestore? firestore, PointsEngineClient? pointsEngine})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _pointsEngine = pointsEngine ?? PointsEngineClient();

  final FirebaseFirestore _firestore;
  final PointsEngineClient _pointsEngine;

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

  /// Upserts today's daily quest doc and claims any newly-earned stars.
  ///
  /// SECURITY: this used to compute quest completion from — and award
  /// stars based on — [minutesReadToday]/[hasReadToday] as reported by
  /// the caller, then write totalAchievementPoints/allTimePoints directly
  /// to Firestore. Since firestore.rules lets an account's own owner
  /// write any field on their own doc except `role`, that whole
  /// award path could be triggered with entirely made-up minutes. Now
  /// delegates to a Cloud Function that re-derives minutesReadToday
  /// itself from the real `reading_sessions` collection — the
  /// [minutesReadToday]/[dailyGoalMinutes]/[hasReadToday]/[now] params
  /// are kept only for call-site compatibility and are no longer used.
  /// See SECURITY.md's "Point-award security migration".
  Future<({Map<String, dynamic> doc, int awardedStars})> upsertTodayFromStats({
    required String userId,
    required int minutesReadToday,
    required int dailyGoalMinutes,
    required bool hasReadToday,
    @visibleForTesting DateTime? now,
  }) async {
    final result = await _pointsEngine.claimDailyQuestRewards();
    return (
      doc: Map<String, dynamic>.from(result['doc'] as Map? ?? {}),
      awardedStars: (result['awardedStars'] as num?)?.toInt() ?? 0,
    );
  }
}
