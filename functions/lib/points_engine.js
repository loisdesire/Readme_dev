/**
 * Server-side point/reward engine.
 *
 * WHY THIS FILE EXISTS: every point-earning action in this app used to be
 * a plain Firestore write made directly from the Flutter client
 * (AchievementService.awardPoints/awardBookCompletionPoints/
 * awardPersonalityQuizCompletion, DailyQuestService.upsertTodayFromStats,
 * and the achievement-unlock path in book_provider.dart). firestore.rules
 * lets an account's own owner write any field on their own `users/{uid}`
 * doc except `role` — so a modified client (or literally opening browser
 * devtools on a signed-in web session) could set `totalAchievementPoints`
 * to any number directly, with nothing server-side to stop it. Since
 * `leaderboard_screen_impl.dart` ranks real users against each other by
 * that same field, this wasn't just "a kid can fake their own save file"
 * — it undermined the entire point/league/leaderboard system. See
 * SECURITY.md for the full writeup.
 *
 * Every function here runs with the Admin SDK (bypasses firestore.rules)
 * and is called only from an authenticated `onCall` wrapper in index.js
 * that passes `request.auth.uid` as `userId` — never a client-supplied
 * uid. Each function:
 *   - computes the credited amount itself, from a fixed rule table or an
 *     achievement's own stored `points` field — never from a
 *     client-supplied number;
 *   - checks a server-only idempotency marker so the same qualifying
 *     event can't be paid out twice;
 *   - re-derives whatever evidence is CHEAP to re-derive from Firestore
 *     (a real quiz_attempts/reading_progress doc, an actual count of
 *     completed books or summed reading-session minutes) instead of
 *     trusting a bare client claim.
 *
 * HONEST LIMITS (documented, not silently glossed over — see SECURITY.md
 * "Point-award security migration" for the full reasoning): the
 * underlying *evidence* collections (reading_progress, reading_sessions,
 * quiz_attempts) are themselves still writable by their owning account,
 * same as before this migration — closing that fully would mean
 * server-verified reading sessions (e.g. authenticated heartbeats), a
 * much larger project outside this pass's scope, deliberately left as a
 * documented limitation rather than started here. What this migration
 * guarantees is narrower but real: the *point fields themselves* can no
 * longer be set to an arbitrary value directly, a qualifying event
 * (however it was produced) can only ever be paid out once, and every
 * achievement/quest/streak stat is verified against real Firestore
 * records — including reading_streak (calculateReadingStreak, ported
 * from FirestoreHelpers.calculateReadingStreak), the one category that
 * initially shipped still trusting a client-reported number.
 */

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

class NotFoundError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NotFoundError';
  }
}

class AlreadyAwardedError extends Error {
  constructor(message) {
    super(message);
    this.name = 'AlreadyAwardedError';
  }
}

// ---------------------------------------------------------------------
// Point-value constants — must stay in sync with the (now dead, kept
// only for reference in comments) Dart constants they replaced:
// AchievementService.awardBookCompletionPoints defaults, BookQuizScreen's
// tier table, AchievementService.awardPersonalityQuizCompletion's default,
// ChildHomeScreen._weeklyChallengePoints, DailyQuestService's `rewards`.
// ---------------------------------------------------------------------
const BOOK_COMPLETION_POINTS = { first: 5, reread: 2 };
const PERSONALITY_QUIZ_POINTS = 3;
const WEEKLY_CHALLENGE_POINTS = 50;
const DAILY_QUEST_REWARDS = { read_goal: 5, keep_streak: 3, mini_read: 2 };
const DAILY_GOAL_MINUTES = 15; // kept in sync with UserProvider.getDailyGoalProgress
const QUIZ_POINTS_TIERS = [
  [90, 5], // 90-100%: 5 points
  [70, 3], // 70-89%: 3 points
  [50, 1], // 50-69%: 1 point
]; // below 50%: 0 points

function quizPointsForPercentage(percentage) {
  for (const [min, points] of QUIZ_POINTS_TIERS) {
    if (percentage >= min) return points;
  }
  return 0;
}

// Same thresholds as lib/utils/league_helper.dart's LeagueHelper.getLeague
// — kept here rather than imported since this is a different runtime
// (Cloud Functions, not Flutter); a change to one without the other would
// only affect *display* (which league name a point total maps to), not
// point security, but should still be kept in sync manually.
const LEAGUE_THRESHOLDS = [
  ['diamond', 1500],
  ['platinum', 700],
  ['gold', 300],
  ['silver', 100],
  ['bronze', 0],
];

function getLeague(totalPoints) {
  for (const [name, min] of LEAGUE_THRESHOLDS) {
    if (totalPoints >= min) return name;
  }
  return 'bronze';
}

// Same pure logic as lib/services/reading_metrics.dart's
// extractSessionMinutes — see that file for why the fallback chain exists
// (different session-writing code paths over the app's history used
// different field names).
function extractSessionMinutes(data) {
  const durationMinutes = Number(data.durationMinutes) || 0;
  if (durationMinutes > 0) return Math.trunc(durationMinutes);

  const sessionDurationMinutes = Number(data.sessionDurationMinutes) || 0;
  if (sessionDurationMinutes > 0) return Math.trunc(sessionDurationMinutes);

  const seconds = Number(data.sessionDurationSeconds) || 0;
  return seconds > 0 ? Math.floor((seconds + 59) / 60) : 0;
}

// Same format as lib/utils/date_utils.dart's AppDateUtils.formatDateKey
// ("2025-10-28") and startOfWeek (Monday 00:00).
function formatDateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function startOfWeek(date) {
  // JS getDay(): 0=Sunday..6=Saturday. Dart's weekday: 1=Monday..7=Sunday.
  const jsDay = date.getDay();
  const daysFromMonday = jsDay === 0 ? 6 : jsDay - 1;
  return startOfDay(new Date(date.getTime() - daysFromMonday * 86400000));
}

/**
 * Resolves "now" for day-bucketing purposes (which calendar day counts as
 * "today"), preferring the client's own reported local date over the
 * Cloud Function's clock.
 *
 * BUG this fixes: a Cloud Function's clock is the server's (effectively
 * UTC) — a child in any timezone noticeably behind UTC has an hours-wide
 * window around their own local midnight where the server's calendar day
 * has already advanced but theirs hasn't yet (or vice versa for timezones
 * ahead of UTC). Using the server's day unconditionally would silently
 * bucket a legitimate just-before-local-midnight reading session into the
 * wrong day, and could make a same-day daily quest or streak look like it
 * spans/misses a day it shouldn't from the child's point of view.
 *
 * `clientTodayDateKey` ("YYYY-MM-DD", from AppDateUtils.formatDateKey on
 * the device) is a hint, not a trusted value on its own: sanity-clamped
 * to within 1 day of the server's own date so a client can't claim to be
 * on some arbitrary other day to game day-boundary logic. Within that
 * ±1-day window it's just correcting for real timezone offsets (at most
 * ~26 hours worldwide), not something meaningfully exploitable — the
 * actual point AMOUNTS and idempotency markers this feeds into are still
 * fully server-computed and re-verified regardless of which day they land
 * on.
 */
function resolveEffectiveNow(clientTodayDateKey) {
  const serverNow = new Date();
  if (!clientTodayDateKey || typeof clientTodayDateKey !== 'string') {
    return serverNow;
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(clientTodayDateKey.trim());
  if (!match) return serverNow;
  const [, y, m, d] = match.map(Number);
  const parsed = new Date(y, m - 1, d);
  if (isNaN(parsed.getTime())) return serverNow;

  const dayMs = 86400000;
  const diffDays = Math.round(
    (startOfDay(parsed).getTime() - startOfDay(serverNow).getTime()) / dayMs
  );
  if (Math.abs(diffDays) > 1) return serverNow; // implausible — ignore the hint
  return parsed;
}

/**
 * Ports ReadingSessionService.getTodayReadingMinutes: a primary query on
 * `createdAt` within today's range, falling back to `createdAtClient`
 * then `startTime` only if the primary query found nothing (sessions
 * written under different historical schemas).
 */
async function getTodayReadingMinutes(db, userId, now) {
  const start = startOfDay(now);
  const end = new Date(start.getTime() + 86400000);

  const countedDocIds = new Set();
  let totalMinutes = 0;

  const primarySnap = await db
    .collection('reading_sessions')
    .where('userId', '==', userId)
    .where('createdAt', '>=', start)
    .where('createdAt', '<', end)
    .get();
  for (const doc of primarySnap.docs) {
    totalMinutes += extractSessionMinutes(doc.data());
    countedDocIds.add(doc.id);
  }

  if (totalMinutes === 0) {
    try {
      const byClient = await db
        .collection('reading_sessions')
        .where('userId', '==', userId)
        .where('createdAtClient', '>=', start)
        .where('createdAtClient', '<', end)
        .get();
      for (const doc of byClient.docs) {
        if (countedDocIds.has(doc.id)) continue;
        countedDocIds.add(doc.id);
        totalMinutes += extractSessionMinutes(doc.data());
      }
    } catch (e) {
      // Best-effort fallback, matches the Dart original's swallow-and-continue.
    }

    const byStart = await db
      .collection('reading_sessions')
      .where('userId', '==', userId)
      .where('startTime', '>=', start)
      .where('startTime', '<', end)
      .get();
    for (const doc of byStart.docs) {
      if (countedDocIds.has(doc.id)) continue;
      countedDocIds.add(doc.id);
      totalMinutes += extractSessionMinutes(doc.data());
    }
  }

  return totalMinutes;
}

/**
 * All-time reading stats, verified directly from `reading_sessions` —
 * deliberately simpler than the 30-day-windowed, multi-timestamp-field
 * version the client uses for its own display (AnalyticsService.
 * getUserReadingAnalytics): an unbounded `userId`-only query needs no
 * date-range/timestamp-field fallback at all. Using an all-time count
 * instead of a 30-day window only ever makes an achievement threshold
 * *easier* to legitimately reach sooner, never exploitable in the
 * cheating direction, so the simplification is safe for this purpose
 * even though it isn't pixel-identical to what the app displays.
 */
async function countCompletedBooksInTx(tx, db, userId) {
  const snap = await tx.get(
    db
      .collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
  );
  return snap.size;
}

async function getAllTimeReadingStatsInTx(tx, db, userId) {
  const snap = await tx.get(
    db.collection('reading_sessions').where('userId', '==', userId)
  );
  let totalReadingMinutes = 0;
  for (const doc of snap.docs) {
    totalReadingMinutes += extractSessionMinutes(doc.data());
  }
  return { totalReadingMinutes, totalSessions: snap.size };
}

// Same pure logic as lib/services/reading_metrics.dart's
// progressIndicatesReading: a reading_progress doc only counts as real
// activity if it shows actual progress or tracked time, not just having
// been touched (e.g. a book opened and immediately closed).
function progressIndicatesReading(data) {
  const progressPercent = Number(data.progressPercentage) || 0;
  const readingTimeMinutes = Number(data.readingTimeMinutes) || 0;
  return progressPercent > 0 || readingTimeMinutes > 0;
}

// Same pure logic as lib/services/reading_metrics.dart's
// extractSessionTimeForBucketing: several historical session-writing code
// paths used different timestamp field names, so try each in the same
// preference order.
function extractSessionTimeForBucketing(data) {
  const fields = [
    'clientStartTime', 'sessionStart', 'startTime', 'createdAtClient', 'createdAt',
  ];
  for (const field of fields) {
    const value = data[field];
    if (value && typeof value.toDate === 'function') return value.toDate();
  }
  return null;
}

/**
 * Ports FirestoreHelpers.calculateReadingStreak: consecutive-day reading
 * activity, built from real reading_progress/reading_sessions records —
 * not a client-reported number — so the reading_streak achievement
 * category (previously the one gap left trusting the client) is now
 * verified the same way books_read/reading_time/reading_sessions already
 * are. See SECURITY.md's "Point-award security migration" follow-up.
 *
 * Not run inside a transaction (unlike the other verification helpers):
 * it needs 4 separate range queries, and Firestore transactions cap reads
 * more tightly — this function's result is used as an input to a
 * decision, not itself something requiring transactional isolation from
 * the credit that follows.
 */
async function calculateReadingStreak(db, userId, { now, lookbackDays = 365 } = {}) {
  const effectiveNow = now || new Date();
  const startDate = new Date(effectiveNow.getTime() - lookbackDays * 86400000);

  const progressSnap = await db
    .collection('reading_progress')
    .where('userId', '==', userId)
    .where('lastReadAt', '>=', startDate)
    .get();

  const [byCreatedAt, byCreatedAtClient, byStartTime] = await Promise.all([
    db.collection('reading_sessions').where('userId', '==', userId)
      .where('createdAt', '>=', startDate).get(),
    db.collection('reading_sessions').where('userId', '==', userId)
      .where('createdAtClient', '>=', startDate).get(),
    db.collection('reading_sessions').where('userId', '==', userId)
      .where('startTime', '>=', startDate).get(),
  ]);

  const activityByDate = {};

  for (const doc of progressSnap.docs) {
    const data = doc.data();
    const lastReadAt = data.lastReadAt && data.lastReadAt.toDate
      ? data.lastReadAt.toDate() : null;
    if (lastReadAt && progressIndicatesReading(data)) {
      activityByDate[formatDateKey(lastReadAt)] = true;
    }
  }

  const seenSessionIds = new Set();
  for (const doc of [...byCreatedAt.docs, ...byCreatedAtClient.docs, ...byStartTime.docs]) {
    if (seenSessionIds.has(doc.id)) continue;
    seenSessionIds.add(doc.id);
    const ts = extractSessionTimeForBucketing(doc.data());
    if (!ts) continue;
    activityByDate[formatDateKey(ts)] = true;
  }

  const streakDays = [];
  let todayRead = false;
  for (let i = 0; i < lookbackDays; i++) {
    const checkDate = new Date(effectiveNow.getTime() - i * 86400000);
    const hasActivity = activityByDate[formatDateKey(checkDate)] || false;
    if (hasActivity) {
      streakDays.push(true);
      if (i === 0) todayRead = true;
    } else if (i === 0) {
      streakDays.push(false);
    } else {
      break;
    }
  }

  let streak = 0;
  if (todayRead) {
    for (const day of streakDays) {
      if (day) streak++; else break;
    }
  } else {
    for (let i = 1; i < streakDays.length; i++) {
      if (streakDays[i]) streak++; else break;
    }
  }

  return { streak, todayRead };
}

/** Computes {newTotalPoints, promotedLeague} for a points credit, given the user doc data BEFORE the credit. */
function computeCredit(userData, points) {
  const currentPoints = Number(userData.totalAchievementPoints) || 0;
  const currentAllTime = Number(userData.allTimePoints) || 0;
  const oldLeague = getLeague(currentPoints);
  const newTotalPoints = currentPoints + points;
  const newAllTimePoints = currentAllTime + points;
  const newLeague = getLeague(newTotalPoints);
  return {
    newTotalPoints,
    newAllTimePoints,
    promotedLeague: newLeague !== oldLeague ? newLeague : null,
  };
}

// ---------------------------------------------------------------------
// 1. Book completion points
// ---------------------------------------------------------------------
/**
 * Awards book-completion points. Requires `reading_progress` for
 * (userId, bookId) to already show `isCompleted: true` — callers must
 * update reading progress *before* calling this (previously the client
 * awarded points first, then wrote the completion flag; that ordering
 * doesn't work now that this function verifies against the flag, so
 * pdf_reading_screen_syncfusion.dart was reordered to match).
 *
 * isFirstCompletion is determined server-side from a dedicated
 * `book_completion_awards/{userId}_{bookId}` doc — not a client-supplied
 * flag — so the same book can only ever pay out the first-completion
 * bonus once; every award after that is the reread amount.
 */
async function awardBookCompletionPoints(db, userId, { bookId }) {
  if (!bookId || typeof bookId !== 'string') {
    throw new ValidationError('bookId is required.');
  }

  return db.runTransaction(async (tx) => {
    const progressSnap = await tx.get(
      db
        .collection('reading_progress')
        .where('userId', '==', userId)
        .where('bookId', '==', bookId)
    );
    const isCompleted = progressSnap.docs.some(
      (d) => d.data().isCompleted === true
    );
    if (!isCompleted) {
      throw new ValidationError(
        'This book is not recorded as completed yet.'
      );
    }

    const awardRef = db
      .collection('book_completion_awards')
      .doc(`${userId}_${bookId}`);
    const awardSnap = await tx.get(awardRef);
    const isFirstCompletion = !awardSnap.exists;
    const points = isFirstCompletion
      ? BOOK_COMPLETION_POINTS.first
      : BOOK_COMPLETION_POINTS.reread;

    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    const currentBooksCompleted = Number(userData.booksCompleted) || 0;
    const newBooksCompleted = isFirstCompletion
      ? currentBooksCompleted + 1
      : currentBooksCompleted;

    const { newTotalPoints, newAllTimePoints, promotedLeague } =
      computeCredit(userData, points);

    tx.set(
      userRef,
      {
        totalAchievementPoints: newTotalPoints,
        allTimePoints: newAllTimePoints,
        ...(isFirstCompletion ? { booksCompleted: newBooksCompleted } : {}),
      },
      { merge: true }
    );

    const existingAward = awardSnap.data() || {};
    tx.set(
      awardRef,
      {
        userId,
        bookId,
        firstAwardedAt: isFirstCompletion
          ? new Date()
          : existingAward.firstAwardedAt || new Date(),
        rereadCount: isFirstCompletion
          ? 0
          : (Number(existingAward.rereadCount) || 0) + 1,
        lastAwardedAt: new Date(),
      },
      { merge: true }
    );

    return {
      pointsEarned: points,
      isFirstCompletion,
      totalBooksCompleted: newBooksCompleted,
      newTotalPoints,
      promotedLeague,
    };
  });
}

// ---------------------------------------------------------------------
// 2. Book quiz points
// ---------------------------------------------------------------------
/**
 * Awards points for a book quiz, re-reading the actual `quiz_attempts`
 * doc for its real score/percentage rather than trusting a
 * client-supplied percentage — closes the "call this claiming 100% with
 * a made-up attemptId's worth of fabricated data" gap as much as is
 * possible without also locking down quiz_attempts writes themselves
 * (a pre-existing, documented limitation — see file header).
 */
async function awardQuizPoints(db, userId, { attemptId }) {
  if (!attemptId || typeof attemptId !== 'string') {
    throw new ValidationError('attemptId is required.');
  }

  return db.runTransaction(async (tx) => {
    const attemptRef = db.collection('quiz_attempts').doc(attemptId);
    const attemptSnap = await tx.get(attemptRef);
    if (!attemptSnap.exists) {
      throw new NotFoundError('Quiz attempt not found.');
    }
    const attempt = attemptSnap.data();
    if (attempt.userId !== userId) {
      throw new ValidationError('This quiz attempt does not belong to you.');
    }
    if (attempt.pointsAwarded === true) {
      throw new AlreadyAwardedError(
        'Points have already been awarded for this quiz attempt.'
      );
    }

    const percentage = Number(attempt.percentage) || 0;
    const points = quizPointsForPercentage(percentage);

    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    const { newTotalPoints, newAllTimePoints, promotedLeague } =
      computeCredit(userData, points);

    if (points > 0) {
      tx.set(
        userRef,
        {
          totalAchievementPoints: newTotalPoints,
          allTimePoints: newAllTimePoints,
        },
        { merge: true }
      );
    }
    tx.set(
      attemptRef,
      { pointsAwarded: true, pointsEarned: points },
      { merge: true }
    );

    return {
      pointsEarned: points,
      percentage,
      newTotalPoints: points > 0 ? newTotalPoints : Number(userData.totalAchievementPoints) || 0,
      promotedLeague: points > 0 ? promotedLeague : null,
    };
  });
}

// ---------------------------------------------------------------------
// 3. Personality quiz completion points
// ---------------------------------------------------------------------
async function awardPersonalityQuizPoints(db, userId) {
  return db.runTransaction(async (tx) => {
    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};

    if (userData.quizCompleted === true) {
      throw new AlreadyAwardedError(
        'Personality quiz points have already been awarded.'
      );
    }

    const { newTotalPoints, newAllTimePoints, promotedLeague } =
      computeCredit(userData, PERSONALITY_QUIZ_POINTS);

    tx.set(
      userRef,
      {
        totalAchievementPoints: newTotalPoints,
        allTimePoints: newAllTimePoints,
        quizCompleted: true,
        quizCompletedAt: new Date(),
      },
      { merge: true }
    );

    return {
      pointsEarned: PERSONALITY_QUIZ_POINTS,
      newTotalPoints,
      promotedLeague,
    };
  });
}

// ---------------------------------------------------------------------
// 4. Weekly challenge points
// ---------------------------------------------------------------------
/**
 * Re-reads the user's own `weeklyChallengeCompleted`/`weeklyChallengeProgress`
 * fields (still client-written by WeeklyChallengeService — a documented
 * residual trust gap, see file header) but adds a server-only
 * idempotency marker (`weeklyChallengeLastAwardedWeek`) so toggling
 * those flags back and forth can't re-pay the same week's challenge
 * over and over, which is the part that was actually unbounded before.
 */
async function awardWeeklyChallengePoints(db, userId) {
  return db.runTransaction(async (tx) => {
    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};

    const isCompleted = userData.weeklyChallengeCompleted === true;
    const progress = Number(userData.weeklyChallengeProgress) || 0;
    const target = Number(userData.currentChallengeTarget) || 1;
    if (!isCompleted || progress < target) {
      throw new ValidationError('The weekly challenge is not completed yet.');
    }

    const weekKey = userData.lastWeeklyChallengeWeek;
    if (!weekKey) {
      throw new ValidationError('No active weekly challenge week found.');
    }
    if (userData.weeklyChallengeLastAwardedWeek === weekKey) {
      throw new AlreadyAwardedError(
        'Weekly challenge points have already been awarded for this week.'
      );
    }

    const { newTotalPoints, newAllTimePoints, promotedLeague } =
      computeCredit(userData, WEEKLY_CHALLENGE_POINTS);

    tx.set(
      userRef,
      {
        totalAchievementPoints: newTotalPoints,
        allTimePoints: newAllTimePoints,
        weeklyChallengeLastAwardedWeek: weekKey,
      },
      { merge: true }
    );

    return {
      pointsEarned: WEEKLY_CHALLENGE_POINTS,
      newTotalPoints,
      promotedLeague,
    };
  });
}

// ---------------------------------------------------------------------
// 5. Daily quest stars
// ---------------------------------------------------------------------
/**
 * Full replacement for DailyQuestService.upsertTodayFromStats: instead
 * of trusting client-supplied minutesReadToday/hasReadToday, this
 * re-derives minutesReadToday itself from `reading_sessions` (see
 * getTodayReadingMinutes above) before deciding which quests are
 * complete. The per-day idempotency ("rewarded" flag) and reward
 * bookkeeping are otherwise unchanged from the original.
 */
async function claimDailyQuestRewards(db, userId, { now, todayDateKey } = {}) {
  // `now` is test-only (see points_engine.test.js); real callers pass
  // todayDateKey — see resolveEffectiveNow's doc comment for why the
  // server's own clock isn't used unconditionally.
  const effectiveNow = now || resolveEffectiveNow(todayDateKey);
  const dateKey = formatDateKey(effectiveNow);
  const weekStartKey = formatDateKey(startOfWeek(effectiveNow));

  const minutesReadToday = await getTodayReadingMinutes(
    db,
    userId,
    effectiveNow
  );
  const hasReadToday = minutesReadToday > 0;
  const completedReadGoal = minutesReadToday >= DAILY_GOAL_MINUTES;
  const completedKeepStreak = hasReadToday;
  const completedMiniRead = minutesReadToday >= 2;
  const allCompleted =
    completedReadGoal && completedKeepStreak && completedMiniRead;

  const ref = db
    .collection('users')
    .doc(userId)
    .collection('dailyQuests')
    .doc(dateKey);
  const userRef = db.collection('users').doc(userId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};
    const alreadyRewarded = data.rewarded === true;

    const quests = {
      read_goal: {
        key: 'read_goal',
        title: `Read ${DAILY_GOAL_MINUTES} minutes`,
        subtitle: `${minutesReadToday} / ${DAILY_GOAL_MINUTES} min`,
        rewardStars: DAILY_QUEST_REWARDS.read_goal,
        completed: completedReadGoal,
      },
      keep_streak: {
        key: 'keep_streak',
        title: 'Keep your streak',
        subtitle: hasReadToday
          ? 'You read today — streak protected'
          : 'Read today to keep it going',
        rewardStars: DAILY_QUEST_REWARDS.keep_streak,
        completed: completedKeepStreak,
      },
      mini_read: {
        key: 'mini_read',
        title: 'Do a mini read',
        subtitle: completedMiniRead ? 'Done!' : 'Even 2 minutes counts',
        rewardStars: DAILY_QUEST_REWARDS.mini_read,
        completed: completedMiniRead,
      },
    };

    let awardedStars = 0;

    if (allCompleted && !alreadyRewarded) {
      awardedStars =
        DAILY_QUEST_REWARDS.read_goal +
        DAILY_QUEST_REWARDS.keep_streak +
        DAILY_QUEST_REWARDS.mini_read;

      const userSnap = await tx.get(userRef);
      const userData = userSnap.data() || {};
      const { newTotalPoints, newAllTimePoints } = computeCredit(
        userData,
        awardedStars
      );
      const currentDailyQuestStars =
        Number(userData.dailyQuestStarsEarned) || 0;
      const existingWeekKey = (userData.clubWeekKey || '').trim();
      const currentWeeklyClubStars = Number(userData.weeklyClubStars) || 0;

      const userUpdates = {
        totalAchievementPoints: newTotalPoints,
        allTimePoints: newAllTimePoints,
        dailyQuestStarsEarned: currentDailyQuestStars + awardedStars,
      };
      if (existingWeekKey === weekStartKey) {
        userUpdates.weeklyClubStars = currentWeeklyClubStars + awardedStars;
      } else {
        userUpdates.clubWeekKey = weekStartKey;
        userUpdates.weeklyClubStars = awardedStars;
      }

      tx.set(userRef, userUpdates, { merge: true });
    }

    tx.set(
      ref,
      {
        dateKey,
        dailyGoalMinutes: DAILY_GOAL_MINUTES,
        minutesReadToday,
        quests,
        ...(allCompleted && !alreadyRewarded
          ? {
              rewarded: true,
              rewardedStars: awardedStars,
              rewardedAt: new Date(),
            }
          : {}),
        ...(snap.exists ? {} : { createdAt: new Date() }),
        updatedAt: new Date(),
      },
      { merge: true }
    );

    return {
      doc: { dateKey, dailyGoalMinutes: DAILY_GOAL_MINUTES, minutesReadToday, quests },
      awardedStars,
    };
  });
}

// ---------------------------------------------------------------------
// 6. Achievement unlocks
// ---------------------------------------------------------------------
/**
 * Unlocks an achievement and credits its points. The achievement's own
 * `type`/`requiredValue`/`points` are read from the real `achievements`
 * doc (admin-only-writable) — never from client-supplied values, closing
 * "claim an achievementId with an inflated point amount" entirely.
 *
 * Every stat category is now verified directly against Firestore:
 * books_read via a real reading_progress count, reading_time/
 * reading_sessions via a real reading_sessions sum/count (see file header
 * for why these are safe to compute all-time rather than matching the
 * client's 30-day-windowed display value), and reading_streak via
 * calculateReadingStreak (consecutive-day activity from the same real
 * records) — no achievement category trusts a client-reported number
 * anymore.
 */
async function unlockAchievement(db, userId, { achievementId, now, todayDateKey }) {
  if (!achievementId || typeof achievementId !== 'string') {
    throw new ValidationError('achievementId is required.');
  }

  // Read the achievement once, outside the transaction, purely to know
  // its type: reading_streak's evidence (calculateReadingStreak) needs
  // several queries that don't belong inside db.runTransaction (see that
  // function's own doc comment on why). Re-read inside the transaction
  // below for the actual credit decision, so this pre-read can't create a
  // window where a since-changed achievement doc is trusted.
  const preSnap = await db.collection('achievements').doc(achievementId).get();
  if (!preSnap.exists) {
    throw new NotFoundError('Unknown achievement.');
  }
  let precomputedStreak = null;
  if (preSnap.data().type === 'reading_streak') {
    const effectiveNow = now || resolveEffectiveNow(todayDateKey);
    precomputedStreak = (await calculateReadingStreak(db, userId, { now: effectiveNow })).streak;
  }

  return db.runTransaction(async (tx) => {
    const achievementRef = db.collection('achievements').doc(achievementId);
    const achievementSnap = await tx.get(achievementRef);
    if (!achievementSnap.exists) {
      throw new NotFoundError('Unknown achievement.');
    }
    const achievement = achievementSnap.data();

    const existingSnap = await tx.get(
      db
        .collection('user_achievements')
        .where('userId', '==', userId)
        .where('achievementId', '==', achievementId)
    );
    if (!existingSnap.empty) {
      throw new AlreadyAwardedError('Achievement already unlocked.');
    }

    let actualValue;
    switch (achievement.type) {
      case 'books_read':
        actualValue = await countCompletedBooksInTx(tx, db, userId);
        break;
      case 'reading_time':
        actualValue = (await getAllTimeReadingStatsInTx(tx, db, userId))
          .totalReadingMinutes;
        break;
      case 'reading_sessions':
        actualValue = (await getAllTimeReadingStatsInTx(tx, db, userId))
          .totalSessions;
        break;
      case 'reading_streak':
        // Falls back to 0 (fails the threshold check below) if the
        // achievement's type changed between the pre-read above and now
        // — an extreme edge case, safe to fail closed on.
        actualValue = precomputedStreak ?? 0;
        break;
      default:
        throw new ValidationError(
          `Unknown achievement type: ${achievement.type}`
        );
    }

    const requiredValue = Number(achievement.requiredValue) || 0;
    if (actualValue < requiredValue) {
      throw new ValidationError(
        "This achievement's requirements haven't been met yet."
      );
    }

    const points = Number(achievement.points) || 0;
    const userRef = db.collection('users').doc(userId);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    const currentWeeklyPoints = Number(userData.weeklyPoints) || 0;
    const currentUnlockedThisWeek =
      Number(userData.achievementsUnlockedThisWeek) || 0;
    const { newTotalPoints, newAllTimePoints, promotedLeague } =
      computeCredit(userData, points);

    tx.set(
      userRef,
      {
        totalAchievementPoints: newTotalPoints,
        allTimePoints: newAllTimePoints,
        weeklyPoints: currentWeeklyPoints + points,
        // Feeds the weekly-challenge "unlock 1 achievement" type; the
        // actual challenge-progress recompute still happens the same way
        // it always has (WeeklyChallengeService, client-triggered) — this
        // just makes sure the counter it reads is accurate.
        achievementsUnlockedThisWeek: currentUnlockedThisWeek + 1,
      },
      { merge: true }
    );

    const unlockRef = db.collection('user_achievements').doc();
    tx.set(unlockRef, {
      userId,
      achievementId,
      achievementName: achievement.name,
      category: achievement.category,
      points,
      unlockedAt: new Date(),
      popupShown: false,
    });

    return {
      unlocked: true,
      achievementId,
      achievementName: achievement.name,
      points,
      newTotalPoints,
      promotedLeague,
    };
  });
}

module.exports = {
  ValidationError,
  NotFoundError,
  AlreadyAwardedError,
  BOOK_COMPLETION_POINTS,
  PERSONALITY_QUIZ_POINTS,
  WEEKLY_CHALLENGE_POINTS,
  DAILY_QUEST_REWARDS,
  DAILY_GOAL_MINUTES,
  QUIZ_POINTS_TIERS,
  quizPointsForPercentage,
  getLeague,
  extractSessionMinutes,
  progressIndicatesReading,
  extractSessionTimeForBucketing,
  formatDateKey,
  startOfWeek,
  resolveEffectiveNow,
  getTodayReadingMinutes,
  calculateReadingStreak,
  awardBookCompletionPoints,
  awardQuizPoints,
  awardPersonalityQuizPoints,
  awardWeeklyChallengePoints,
  claimDailyQuestRewards,
  unlockAchievement,
};
