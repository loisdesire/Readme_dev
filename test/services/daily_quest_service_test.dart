import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/daily_quest_service.dart';
import 'package:readme_app/services/points_engine_client.dart';

// SECURITY.md's "Point-award security migration": upsertTodayFromStats no
// longer computes quest completion or awards stars itself — it delegates
// entirely to the claimDailyQuestRewards Cloud Function, which re-derives
// minutesReadToday from the real reading_sessions collection rather than
// trusting the minutesReadToday/hasReadToday/now parameters below (kept
// only for call-site compatibility). That reward logic (quest completion
// rules, the 5+3+2 star sum, one-award-per-day idempotency, weekly club
// star accumulation/reset at week boundaries) is now covered by
// functions/lib/__tests__/emulator/points_engine.test.js instead — these
// tests just verify DailyQuestService correctly delegates to and
// translates the response from PointsEngineClient.

void main() {
  group('DailyQuestService.getTodayDoc', () {
    test('returns null before any quest doc exists for today', () async {
      final firestore = FakeFirebaseFirestore();
      final service = DailyQuestService(firestore: firestore);
      expect(await service.getTodayDoc('u1'), isNull);
    });

    test('returns the persisted doc once claimDailyQuestRewards has written '
        'one', () async {
      final firestore = FakeFirebaseFirestore();
      final dateKey = DailyQuestService.todayDateKey();
      await firestore
          .collection('users')
          .doc('u1')
          .collection(DailyQuestService.collectionName)
          .doc(dateKey)
          .set({'dateKey': dateKey, 'minutesReadToday': 12});

      final service = DailyQuestService(firestore: firestore);
      final doc = await service.getTodayDoc('u1');

      expect(doc, isNotNull);
      expect(doc!['minutesReadToday'], 12);
    });
  });

  group('DailyQuestService.upsertTodayFromStats', () {
    test('delegates to claimDailyQuestRewards and translates its response, '
        'not the minutesReadToday/hasReadToday/now parameters (which the '
        'server re-derives itself and no longer trusts from here)', () async {
      final firestore = FakeFirebaseFirestore();
      var capturedCall = '';
      final service = DailyQuestService(
        firestore: firestore,
        pointsEngine: PointsEngineClient.withCaller((name, data) async {
          capturedCall = name;
          return {
            'doc': {'dateKey': '2026-01-05', 'minutesReadToday': 20},
            'awardedStars': 10,
          };
        }),
      );

      final result = await service.upsertTodayFromStats(
        userId: 'u1',
        // These are intentionally ignored now — passed only because
        // existing call sites still supply them.
        minutesReadToday: 999,
        dailyGoalMinutes: 15,
        hasReadToday: true,
      );

      expect(capturedCall, 'claimDailyQuestRewards');
      expect(result.awardedStars, 10);
      expect(result.doc['minutesReadToday'], 20);
    });

    test('a zero-star response (nothing newly completed) round-trips '
        'cleanly', () async {
      final firestore = FakeFirebaseFirestore();
      final service = DailyQuestService(
        firestore: firestore,
        pointsEngine: PointsEngineClient.withCaller((name, data) async {
          return {
            'doc': {'dateKey': '2026-01-05', 'minutesReadToday': 0},
            'awardedStars': 0,
          };
        }),
      );

      final result = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 0,
        dailyGoalMinutes: 15,
        hasReadToday: false,
      );

      expect(result.awardedStars, 0);
      expect(result.doc['minutesReadToday'], 0);
    });
  });
}
