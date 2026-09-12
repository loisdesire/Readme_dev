import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/daily_quest_service.dart';
import 'package:readme_app/utils/date_utils.dart';

void main() {
  group('DailyQuestService.getTodayDoc', () {
    test('returns null before any quest doc exists for today', () async {
      final firestore = FakeFirebaseFirestore();
      final service = DailyQuestService(firestore: firestore);
      expect(await service.getTodayDoc('u1'), isNull);
    });
  });

  group('DailyQuestService.upsertTodayFromStats — individual quests', () {
    test('only the mini-read quest completes on light reading (2-4 minutes, '
        'below the daily goal)', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final service = DailyQuestService(firestore: firestore);

      final result = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 3,
        dailyGoalMinutes: 20,
        hasReadToday: true,
      );

      final quests = result.doc['quests'] as Map;
      expect((quests[DailyQuestService.questMiniRead] as Map)['completed'], true);
      expect((quests[DailyQuestService.questReadGoal] as Map)['completed'], false);
      // hasReadToday true also completes the streak quest independently.
      expect((quests[DailyQuestService.questKeepStreak] as Map)['completed'], true);
      expect(result.awardedStars, 0); // not all three complete yet
      expect(result.doc['rewarded'], isNot(true));
    });

    test('no reading at all completes nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = DailyQuestService(firestore: firestore);

      final result = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 0,
        dailyGoalMinutes: 20,
        hasReadToday: false,
      );

      final quests = result.doc['quests'] as Map;
      expect(quests.values.every((q) => (q as Map)['completed'] == false), isTrue);
      expect(result.awardedStars, 0);
    });
  });

  group('DailyQuestService.upsertTodayFromStats — full completion & reward', () {
    test('completing all three quests awards the sum of their stars (5+3+2) '
        'exactly once, updating the user\'s points', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({
        'totalAchievementPoints': 10,
        'allTimePoints': 10,
      });
      final service = DailyQuestService(firestore: firestore);

      final result = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
      );

      expect(result.awardedStars, 10);
      expect(result.doc['rewarded'], true);
      expect(result.doc['rewardedStars'], 10);

      final userDoc = await firestore.collection('users').doc('u1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 20);
      expect(userDoc.data()!['allTimePoints'], 20);
      expect(userDoc.data()!['dailyQuestStarsEarned'], 10);
    });

    test('calling again the same day after already rewarded does not '
        'double-award', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final service = DailyQuestService(firestore: firestore);

      final first = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
      );
      expect(first.awardedStars, 10);

      // Same stats recomputed later the same day (e.g. app reopened).
      final second = await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 25,
        dailyGoalMinutes: 20,
        hasReadToday: true,
      );
      expect(second.awardedStars, 0);

      final userDoc = await firestore.collection('users').doc('u1').get();
      expect(userDoc.data()!['totalAchievementPoints'], 10); // not 20
    });
  });

  group('DailyQuestService.upsertTodayFromStats — weekly club stars', () {
    // A fixed Monday/Wednesday pair so the test doesn't depend on when it
    // happens to run.
    final monday = DateTime(2026, 1, 5);
    final wednesdaySameWeek = DateTime(2026, 1, 7);
    final mondayNextWeek = DateTime(2026, 1, 12);

    test('the first completion of a week initializes weeklyClubStars, and a '
        "later day's completion in the SAME week adds to it (not replaces)",
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final service = DailyQuestService(firestore: firestore);

      await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
        now: monday,
      );
      final afterMonday = await firestore.collection('users').doc('u1').get();
      expect(afterMonday.data()!['weeklyClubStars'], 10);
      expect(
        afterMonday.data()!['clubWeekKey'],
        AppDateUtils.formatDateKey(AppDateUtils.startOfWeek(monday)),
      );

      // Wednesday: a different day, same week — a fresh dailyQuests doc
      // (different dateKey), so this is a genuinely new completion+reward.
      await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
        now: wednesdaySameWeek,
      );
      final afterWednesday = await firestore.collection('users').doc('u1').get();

      expect(afterWednesday.data()!['weeklyClubStars'], 20); // 10 + 10, not reset
      expect(afterWednesday.data()!['totalAchievementPoints'], 20);
    });

    test('a completion in a new week resets weeklyClubStars rather than '
        'continuing to add to the previous week\'s total', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'totalAchievementPoints': 0});
      final service = DailyQuestService(firestore: firestore);

      await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
        now: monday,
      );
      await service.upsertTodayFromStats(
        userId: 'u1',
        minutesReadToday: 20,
        dailyGoalMinutes: 20,
        hasReadToday: true,
        now: mondayNextWeek,
      );

      final userDoc = await firestore.collection('users').doc('u1').get();
      expect(userDoc.data()!['weeklyClubStars'], 10); // reset, not 20
      expect(
        userDoc.data()!['clubWeekKey'],
        AppDateUtils.formatDateKey(AppDateUtils.startOfWeek(mondayNextWeek)),
      );
      // Lifetime points still accumulate across weeks regardless.
      expect(userDoc.data()!['totalAchievementPoints'], 20);
    });
  });
}
