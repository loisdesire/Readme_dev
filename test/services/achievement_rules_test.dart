import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/achievement_rules.dart';
import 'package:readme_app/services/achievement_service.dart';

Achievement _achievement({required String type, required int requiredValue}) {
  return Achievement(
    id: 'a1',
    name: 'Test Achievement',
    description: 'desc',
    emoji: '🏅',
    category: 'general',
    requiredValue: requiredValue,
    type: type,
    points: 10,
  );
}

void main() {
  group('shouldUnlockAchievement — books_read', () {
    final achievement = _achievement(type: 'books_read', requiredValue: 5);

    test('unlocks when progress meets the requirement exactly', () {
      final result = shouldUnlockAchievement(
        achievement,
        const AchievementProgress(booksCompleted: 5),
      );
      expect(result, isTrue);
    });

    test('unlocks when progress exceeds the requirement', () {
      final result = shouldUnlockAchievement(
        achievement,
        const AchievementProgress(booksCompleted: 6),
      );
      expect(result, isTrue);
    });

    test('does not unlock when progress falls short', () {
      final result = shouldUnlockAchievement(
        achievement,
        const AchievementProgress(booksCompleted: 4),
      );
      expect(result, isFalse);
    });

    test('missing progress value defaults to 0 (does not unlock)', () {
      final result = shouldUnlockAchievement(achievement, const AchievementProgress());
      expect(result, isFalse);
    });
  });

  group('shouldUnlockAchievement — reading_streak', () {
    test('checks readingStreak, ignoring other progress fields', () {
      final achievement = _achievement(type: 'reading_streak', requiredValue: 3);
      expect(
        shouldUnlockAchievement(
          achievement,
          const AchievementProgress(readingStreak: 3, booksCompleted: 0),
        ),
        isTrue,
      );
      expect(
        shouldUnlockAchievement(
          achievement,
          const AchievementProgress(readingStreak: 2, booksCompleted: 999),
        ),
        isFalse,
      );
    });
  });

  group('shouldUnlockAchievement — reading_time', () {
    test('checks totalReadingMinutes', () {
      final achievement = _achievement(type: 'reading_time', requiredValue: 60);
      expect(
        shouldUnlockAchievement(achievement, const AchievementProgress(totalReadingMinutes: 60)),
        isTrue,
      );
      expect(
        shouldUnlockAchievement(achievement, const AchievementProgress(totalReadingMinutes: 59)),
        isFalse,
      );
    });
  });

  group('shouldUnlockAchievement — reading_sessions', () {
    test('checks totalSessions', () {
      final achievement = _achievement(type: 'reading_sessions', requiredValue: 10);
      expect(
        shouldUnlockAchievement(achievement, const AchievementProgress(totalSessions: 10)),
        isTrue,
      );
      expect(
        shouldUnlockAchievement(achievement, const AchievementProgress(totalSessions: 9)),
        isFalse,
      );
    });
  });

  group('shouldUnlockAchievement — unknown type', () {
    test('never unlocks for an unrecognized achievement.type', () {
      final achievement = _achievement(type: 'quiz_completed', requiredValue: 1);
      final result = shouldUnlockAchievement(
        achievement,
        const AchievementProgress(
          booksCompleted: 999,
          readingStreak: 999,
          totalReadingMinutes: 999,
          totalSessions: 999,
        ),
      );
      expect(result, isFalse);
    });
  });

  group('Achievement.fromMap / toMap round-trip', () {
    test('fromMap fills in defaults for missing fields', () {
      final achievement = Achievement.fromMap(const {});
      expect(achievement.id, '');
      expect(achievement.category, 'general');
      expect(achievement.requiredValue, 1);
      expect(achievement.type, 'books_read');
      expect(achievement.points, 10);
    });

    test('toMap then fromMap preserves core fields', () {
      final original = _achievement(type: 'reading_streak', requiredValue: 7);
      final roundTripped = Achievement.fromMap(original.toMap());

      expect(roundTripped.id, original.id);
      expect(roundTripped.type, original.type);
      expect(roundTripped.requiredValue, original.requiredValue);
      expect(roundTripped.points, original.points);
    });
  });
}
