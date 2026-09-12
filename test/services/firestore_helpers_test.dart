import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/firestore_helpers.dart';

FirestoreHelpers buildHelpers(FakeFirebaseFirestore firestore) {
  return FirestoreHelpers.withInstances(firestore: firestore);
}

Future<void> seedProgressActivity(
  FakeFirebaseFirestore firestore, {
  required String userId,
  required DateTime day,
}) async {
  await firestore.collection('reading_progress').add({
    'userId': userId,
    'lastReadAt': Timestamp.fromDate(day),
    'progressPercentage': 0.5,
    'readingTimeMinutes': 10,
  });
}

Future<void> seedSession(
  FakeFirebaseFirestore firestore, {
  required String userId,
  required DateTime day,
  String schema = 'createdAt',
}) async {
  await firestore.collection('reading_sessions').add({
    'userId': userId,
    schema: Timestamp.fromDate(day),
    'durationMinutes': 10,
  });
}

DateTime dayAgo(int n) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12); // midday, avoids DST edges
  return today.subtract(Duration(days: n));
}

void main() {
  group('FirestoreHelpers.calculateReadingStreak', () {
    test('reading today and the two days before gives a streak of 3',
        () async {
      final firestore = FakeFirebaseFirestore();
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(0));
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(1));
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(2));
      final helpers = buildHelpers(firestore);

      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['streak'], 3);
      expect(result['todayRead'], true);
    });

    test('a gap breaks the streak — only the run ending today counts',
        () async {
      final firestore = FakeFirebaseFirestore();
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(0));
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(1));
      // Gap at day 2 (no activity)
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(3));
      final helpers = buildHelpers(firestore);

      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['streak'], 2);
    });

    test('not read today, but read yesterday and the day before: streak is '
        "2, counted from yesterday, and todayRead is false", () async {
      final firestore = FakeFirebaseFirestore();
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(1));
      await seedProgressActivity(firestore, userId: 'u1', day: dayAgo(2));
      final helpers = buildHelpers(firestore);

      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['todayRead'], false);
      expect(result['streak'], 2);
    });

    test('no reading activity at all gives a streak of 0', () async {
      final helpers = buildHelpers(FakeFirebaseFirestore());
      final result = await helpers.calculateReadingStreak(userId: 'nobody');
      expect(result['streak'], 0);
      expect(result['todayRead'], false);
    });

    test('a reading_sessions doc counts toward the streak the same as a '
        'reading_progress doc', () async {
      final firestore = FakeFirebaseFirestore();
      await seedSession(firestore, userId: 'u1', day: dayAgo(0));
      final helpers = buildHelpers(firestore);

      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['todayRead'], true);
      expect(result['streak'], 1);
    });

    test('the same session appearing under multiple legacy schema fields '
        'is de-duplicated, not double-processed', () async {
      final firestore = FakeFirebaseFirestore();
      // One real session, written the way startSession really writes it:
      // createdAt, createdAtClient and startTime all set together.
      await firestore.collection('reading_sessions').add({
        'userId': 'u1',
        'createdAt': Timestamp.fromDate(dayAgo(0)),
        'createdAtClient': Timestamp.fromDate(dayAgo(0)),
        'startTime': Timestamp.fromDate(dayAgo(0)),
        'durationMinutes': 10,
      });
      final helpers = buildHelpers(firestore);

      // This function only tracks presence, not minutes, so de-duplication
      // isn't independently observable via 'streak' — but it must not
      // throw or otherwise misbehave when a doc matches all three queries.
      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['todayRead'], true);
      expect(result['streak'], 1);
    });

    test('progressIndicatesReading gate: a progress doc with 0% progress '
        'and 0 minutes read does not count as activity', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reading_progress').add({
        'userId': 'u1',
        'lastReadAt': Timestamp.fromDate(dayAgo(0)),
        'progressPercentage': 0.0,
        'readingTimeMinutes': 0,
      });
      final helpers = buildHelpers(firestore);

      final result = await helpers.calculateReadingStreak(userId: 'u1');

      expect(result['todayRead'], false);
      expect(result['streak'], 0);
    });
  });

  group('FirestoreHelpers.getLastNDaysReadingSummary', () {
    test('returns days oldest-to-newest with per-day minutes', () async {
      final firestore = FakeFirebaseFirestore();
      await seedSession(firestore, userId: 'u1', day: dayAgo(0), schema: 'createdAt');
      await seedSession(firestore, userId: 'u1', day: dayAgo(1), schema: 'createdAt');
      final helpers = buildHelpers(firestore);

      final summary = await helpers.getLastNDaysReadingSummary(userId: 'u1', days: 3);

      expect(summary, hasLength(3));
      // Oldest day first.
      expect(
        DateTime.parse(summary.first['date'] as String)
            .isBefore(DateTime.parse(summary.last['date'] as String)),
        isTrue,
      );
      final total = summary.fold<int>(
        0,
        (total, day) => total + (day['readingTimeMinutes'] as int),
      );
      expect(total, 20);
    });
  });
}
