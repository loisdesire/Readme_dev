// File: lib/services/points_engine_client.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Test-only seam type: swap out the real Cloud Functions call with a fake
/// one. There's no official fake/mock package for cloud_functions the way
/// there is for firestore/auth/storage, so this is the app's own seam.
typedef PointsFunctionCaller = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> data,
);

/// Single point of contact for every point-awarding Cloud Function (see
/// functions/lib/points_engine.js and SECURITY.md's "Point-award security
/// migration"). Every point-earning action in the app used to write
/// totalAchievementPoints/allTimePoints/etc. directly to Firestore from
/// here — since firestore.rules lets an account's own owner write any
/// field on their own doc except `role`, that meant a modified client
/// could set its own point total to anything, and the leaderboard ranks
/// real users against each other by that exact field. Now every award
/// goes through a Cloud Function that computes the amount itself (never a
/// client-supplied number), so this class exists to give every call site
/// one seam instead of six separate ad-hoc httpsCallable() calls.
class PointsEngineClient {
  static final PointsEngineClient _instance = PointsEngineClient._internal();
  factory PointsEngineClient() => _instance;
  PointsEngineClient._internal() : _caller = null;

  @visibleForTesting
  PointsEngineClient.withCaller(PointsFunctionCaller caller) : _caller = caller;

  final PointsFunctionCaller? _caller;

  // FirebaseFunctions.instance is resolved lazily, on first real call —
  // never in the constructor — because unlike FirebaseFirestore.instance/
  // FirebaseAuth.instance, it throws immediately if Firebase hasn't been
  // initialized yet, rather than returning a lazy proxy. Since this is a
  // singleton, simply *constructing* PointsEngineClient() (e.g. as another
  // service's default field value) must never require a real Firebase app
  // to exist — only actually making a call does.
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (_caller != null) return _caller!(name, data);
    final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> awardBookCompletionPoints({
    required String bookId,
  }) =>
      _call('awardBookCompletionPoints', {'bookId': bookId});

  Future<Map<String, dynamic>> awardQuizPoints({required String attemptId}) =>
      _call('awardQuizPoints', {'attemptId': attemptId});

  Future<Map<String, dynamic>> awardPersonalityQuizPoints() =>
      _call('awardPersonalityQuizPoints', const {});

  Future<Map<String, dynamic>> awardWeeklyChallengePoints() =>
      _call('awardWeeklyChallengePoints', const {});

  Future<Map<String, dynamic>> claimDailyQuestRewards() =>
      _call('claimDailyQuestRewards', const {});

  Future<Map<String, dynamic>> unlockAchievement({
    required String achievementId,
    int readingStreak = 0,
  }) =>
      _call('unlockAchievement', {
        'achievementId': achievementId,
        'readingStreak': readingStreak,
      });
}

/// True if [error] is a Cloud Functions error with the given `code` (e.g.
/// 'already-exists', 'failed-precondition') — the errors points_engine.js
/// deliberately throws for "not qualified yet" / "already awarded", which
/// callers generally want to treat as a quiet no-op rather than a real
/// failure to log loudly.
bool isFunctionsErrorCode(Object error, String code) {
  return error is FirebaseFunctionsException && error.code == code;
}
