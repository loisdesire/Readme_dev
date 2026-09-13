/**
 * Real Firestore-emulator-backed tests for the point-award security
 * migration (see points_engine.js's file header and SECURITY.md). Run via
 * `npm run test:emulator`. Uses real transactions/queries, which a
 * hand-rolled fake db can't faithfully reproduce — that's why these live
 * here rather than as plain Jest unit tests.
 */
const admin = require('firebase-admin');
const {
  ValidationError,
  AlreadyAwardedError,
  NotFoundError,
  awardBookCompletionPoints,
  awardQuizPoints,
  awardPersonalityQuizPoints,
  awardWeeklyChallengePoints,
  claimDailyQuestRewards,
  unlockAchievement,
  getLeague,
} = require('../../points_engine');

let app;
let db;

beforeAll(() => {
  app = admin.initializeApp({ projectId: 'readme-functions-test-points' });
  db = admin.firestore();
});

afterAll(async () => {
  await app.delete();
});

const uid = () => `u-${Date.now()}-${Math.random().toString(36).slice(2)}`;

describe('getLeague', () => {
  test('matches the documented thresholds', () => {
    expect(getLeague(0)).toBe('bronze');
    expect(getLeague(99)).toBe('bronze');
    expect(getLeague(100)).toBe('silver');
    expect(getLeague(300)).toBe('gold');
    expect(getLeague(700)).toBe('platinum');
    expect(getLeague(1500)).toBe('diamond');
  });
});

describe('awardBookCompletionPoints', () => {
  test('rejects when reading_progress does not show the book completed — '
      + 'the core protection this migration exists for', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    await expect(
      awardBookCompletionPoints(db, userId, { bookId: 'b1' })
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('first completion pays 5, increments booksCompleted, and marks the '
      + 'award so a second call for the same book pays the reread rate '
      + 'instead of another first-time bonus', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    await db.collection('reading_progress').add({
      userId, bookId: 'b1', isCompleted: true,
    });

    const first = await awardBookCompletionPoints(db, userId, { bookId: 'b1' });
    expect(first.pointsEarned).toBe(5);
    expect(first.isFirstCompletion).toBe(true);
    expect(first.totalBooksCompleted).toBe(1);

    const second = await awardBookCompletionPoints(db, userId, { bookId: 'b1' });
    expect(second.pointsEarned).toBe(2);
    expect(second.isFirstCompletion).toBe(false);
    expect(second.totalBooksCompleted).toBe(1); // not double-counted

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(7);
  });

  test('rejects a bookId that was never even opened, let alone completed — '
      + 'fabricating a claim with no matching reading_progress doc at all '
      + 'earns nothing', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    await expect(
      awardBookCompletionPoints(db, userId, { bookId: 'never-opened' })
    ).rejects.toBeInstanceOf(ValidationError);
  });
});

describe('awardQuizPoints', () => {
  test('computes the tier from the real quiz_attempts doc, ignoring '
      + 'whatever a caller might have wanted it to be', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    const attempt = await db.collection('quiz_attempts').add({
      userId, bookId: 'b1', percentage: 92,
    });

    const result = await awardQuizPoints(db, userId, { attemptId: attempt.id });
    expect(result.pointsEarned).toBe(5); // 90-100% tier

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(5);
  });

  test('rejects an attempt belonging to a different user — closes the '
      + '"guess someone else\'s attemptId" gap', async () => {
    const userId = uid();
    const otherUserId = uid();
    await db.collection('users').doc(userId).set({});
    const attempt = await db.collection('quiz_attempts').add({
      userId: otherUserId, bookId: 'b1', percentage: 100,
    });

    await expect(
      awardQuizPoints(db, userId, { attemptId: attempt.id })
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('rejects a made-up attemptId', async () => {
    const userId = uid();
    await expect(
      awardQuizPoints(db, userId, { attemptId: 'does-not-exist' })
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  test('the same attempt cannot be paid out twice', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    const attempt = await db.collection('quiz_attempts').add({
      userId, bookId: 'b1', percentage: 80,
    });

    await awardQuizPoints(db, userId, { attemptId: attempt.id });
    await expect(
      awardQuizPoints(db, userId, { attemptId: attempt.id })
    ).rejects.toBeInstanceOf(AlreadyAwardedError);
  });
});

describe('awardPersonalityQuizPoints', () => {
  test('awards 3 points once, and rejects a repeat claim', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});

    const result = await awardPersonalityQuizPoints(db, userId);
    expect(result.pointsEarned).toBe(3);

    await expect(awardPersonalityQuizPoints(db, userId)).rejects.toBeInstanceOf(
      AlreadyAwardedError
    );

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(3);
  });
});

describe('awardWeeklyChallengePoints', () => {
  test('rejects when the challenge is not actually marked completed', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({
      weeklyChallengeCompleted: false,
    });
    await expect(awardWeeklyChallengePoints(db, userId)).rejects.toBeInstanceOf(
      ValidationError
    );
  });

  test('awards 50 once per week, and a second claim for the same week — '
      + 'even with the completed flag still true — is rejected, closing '
      + 'the "toggle the flag to farm points" gap', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({
      weeklyChallengeCompleted: true,
      weeklyChallengeProgress: 1,
      currentChallengeTarget: 1,
      lastWeeklyChallengeWeek: '2026-01-05',
    });

    const result = await awardWeeklyChallengePoints(db, userId);
    expect(result.pointsEarned).toBe(50);

    await expect(awardWeeklyChallengePoints(db, userId)).rejects.toBeInstanceOf(
      AlreadyAwardedError
    );

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(50);
  });

  test('a new week (different lastWeeklyChallengeWeek) can be claimed '
      + 'again', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({
      weeklyChallengeCompleted: true,
      weeklyChallengeProgress: 1,
      currentChallengeTarget: 1,
      lastWeeklyChallengeWeek: '2026-01-05',
      weeklyChallengeLastAwardedWeek: '2025-12-29', // a previous week
    });

    const result = await awardWeeklyChallengePoints(db, userId);
    expect(result.pointsEarned).toBe(50);
  });
});

describe('claimDailyQuestRewards', () => {
  test('no reading_sessions today means no quests complete and no stars', async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});

    const result = await claimDailyQuestRewards(db, userId, { now: new Date() });
    expect(result.awardedStars).toBe(0);
    expect(result.doc.minutesReadToday).toBe(0);
  });

  test('real session records covering the daily goal award all 10 stars '
      + 'once, derived from reading_sessions rather than a trusted claim',
  async () => {
    const userId = uid();
    await db.collection('users').doc(userId).set({});
    const now = new Date();
    await db.collection('reading_sessions').add({
      userId, createdAt: now, durationMinutes: 20,
    });

    const result = await claimDailyQuestRewards(db, userId, { now });
    expect(result.awardedStars).toBe(10); // 5 + 3 + 2
    expect(result.doc.minutesReadToday).toBe(20);

    // Calling again the same day does not re-award.
    const again = await claimDailyQuestRewards(db, userId, { now });
    expect(again.awardedStars).toBe(0);

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(10);
  });
});

describe('unlockAchievement', () => {
  test('rejects an unknown achievementId', async () => {
    const userId = uid();
    await expect(
      unlockAchievement(db, userId, { achievementId: 'does-not-exist' })
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  test('rejects a books_read achievement when the real reading_progress '
      + 'count does not actually meet the threshold — the client can no '
      + 'longer just assert a books-completed number', async () => {
    const userId = uid();
    await db.collection('achievements').doc('first-book').set({
      name: 'First Book', category: 'books_read', type: 'books_read',
      requiredValue: 1, points: 3,
    });
    await db.collection('users').doc(userId).set({});
    // No completed reading_progress docs at all.

    await expect(
      unlockAchievement(db, userId, { achievementId: 'first-book' })
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('unlocks and credits the achievement\'s own stored points (never a '
      + 'client-supplied amount) once the real count meets the threshold, '
      + 'and rejects a repeat unlock', async () => {
    const userId = uid();
    await db.collection('achievements').doc('first-book').set({
      name: 'First Book', category: 'books_read', type: 'books_read',
      requiredValue: 1, points: 3,
    });
    await db.collection('users').doc(userId).set({});
    await db.collection('reading_progress').add({
      userId, bookId: 'b1', isCompleted: true,
    });

    const result = await unlockAchievement(db, userId, { achievementId: 'first-book' });
    expect(result.points).toBe(3);

    const userDoc = await db.collection('users').doc(userId).get();
    expect(userDoc.data().totalAchievementPoints).toBe(3);
    expect(userDoc.data().achievementsUnlockedThisWeek).toBe(1);

    await expect(
      unlockAchievement(db, userId, { achievementId: 'first-book' })
    ).rejects.toBeInstanceOf(AlreadyAwardedError);
  });

  test('a reading_streak achievement still trusts the client-reported '
      + 'streak (documented gap) but only up to the achievement\'s real '
      + 'requiredValue/points', async () => {
    const userId = uid();
    await db.collection('achievements').doc('week-streak').set({
      name: 'Week Warrior', category: 'reading_streak', type: 'reading_streak',
      requiredValue: 7, points: 5,
    });
    await db.collection('users').doc(userId).set({});

    await expect(
      unlockAchievement(db, userId, { achievementId: 'week-streak', readingStreak: 2 })
    ).rejects.toBeInstanceOf(ValidationError);

    const result = await unlockAchievement(db, userId, {
      achievementId: 'week-streak', readingStreak: 10,
    });
    expect(result.points).toBe(5);
  });
});
