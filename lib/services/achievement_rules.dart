// File: lib/services/achievement_rules.dart
//
// Pure decision logic for whether a given [Achievement] should unlock,
// extracted from AchievementService.checkAndUnlockAchievements so the
// thresholds can be unit-tested without Firebase Auth/Firestore. This is a
// pure extraction — behavior is unchanged from the switch statement it
// replaces.

import 'achievement_service.dart' show Achievement;

/// The progress snapshot checked against an achievement's requirement.
/// Mirrors the named parameters AchievementService.checkAndUnlockAchievements
/// already takes.
class AchievementProgress {
  final int? booksCompleted;
  final int? readingStreak;
  final int? totalReadingMinutes;
  final int? totalSessions;

  const AchievementProgress({
    this.booksCompleted,
    this.readingStreak,
    this.totalReadingMinutes,
    this.totalSessions,
  });
}

/// Whether [achievement] should unlock given [progress].
///
/// Unknown `achievement.type` values (anything other than 'books_read',
/// 'reading_streak', 'reading_time', 'reading_sessions') never unlock —
/// matches the original switch statement's fall-through-to-false behavior.
bool shouldUnlockAchievement(
  Achievement achievement,
  AchievementProgress progress,
) {
  switch (achievement.type) {
    case 'books_read':
      return (progress.booksCompleted ?? 0) >= achievement.requiredValue;
    case 'reading_streak':
      return (progress.readingStreak ?? 0) >= achievement.requiredValue;
    case 'reading_time':
      return (progress.totalReadingMinutes ?? 0) >= achievement.requiredValue;
    case 'reading_sessions':
      return (progress.totalSessions ?? 0) >= achievement.requiredValue;
    default:
      return false;
  }
}
