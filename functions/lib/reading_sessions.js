/**
 * Server-timestamped reading sessions (the point-award migration's
 * follow-up, Option B from docs/reading-session-integrity-design.md).
 *
 * WHY THIS EXISTS: `ReadingSessionService.startSession`/`endSession`
 * wrote `reading_sessions` docs directly from the client, with the
 * client computing its own start time, end time, and therefore
 * duration. Nothing stopped a modified client from fabricating an
 * entire session — start and end timestamps included — with no reading
 * having happened at all. Since `points_engine.js`'s achievement/quest
 * verification reads exactly these records as "the evidence", a
 * fabricated session fed false evidence into an otherwise-correct
 * verification pipeline.
 *
 * These two functions close the most blatant version of that: the
 * server (Admin SDK clock) stamps both the start and the end, and
 * computes the duration itself from its own two timestamps — never
 * from anything the client reports.
 *
 * `recordReadingHeartbeat` (Option A, added once Option B shipped and
 * the cost/precision tradeoff was worked through — see the design doc)
 * closes the remaining gap: a client leaving a session open for hours
 * without reading. The client calls it roughly every 10 minutes while a
 * book is open and the app is foregrounded; each call only credits the
 * elapsed time since the *last* heartbeat (or session start), capped at
 * HEARTBEAT_MAX_CREDIT_SECONDS. So a session that stops sending
 * heartbeats — backgrounded, killed, or genuinely just left open and
 * abandoned — stops accruing credit beyond that cap, instead of
 * crediting the entire gap at endReadingSession the way a plain
 * start-to-end diff would. Reading is only fully credited while the
 * client keeps checking in; MAX_SESSION_SECONDS remains the outer clamp
 * regardless of how many heartbeats arrive.
 *
 * A session that never sends a heartbeat at all (short session, or an
 * older client) still gets *some* credit at endReadingSession — up to
 * HEARTBEAT_MAX_CREDIT_SECONDS — since `lastHeartbeatAt` defaults to the
 * session's own start time. Anything beyond that requires heartbeats;
 * this is intentional, not a bug, since a long session with zero
 * heartbeats is exactly the pattern being guarded against.
 *
 * Deliberately NOT wrapped in the same "fails closed" pattern as
 * points_engine.js: `ReadingSessionService` calls these first and falls
 * back to its original direct-Firestore-write behavior on any failure
 * (offline, cold start, etc.) so reading itself never breaks — a
 * fallback-created session is simply unverified, exactly like every
 * session was before this change. A missed or failed heartbeat call is
 * swallowed client-side too — it just means less credit for that gap,
 * never a crash. See that fallback for the offline story; nothing here
 * handles offline itself.
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

const MAX_SESSION_SECONDS = 6 * 60 * 60; // Same 6-hour clamp as the original client-side endSession.

// The client's target heartbeat cadence is 10 minutes (see
// pdf_reading_screen_syncfusion.dart). The credit cap is a little larger
// than that — enough grace for normal network latency/jitter and a
// slightly-delayed timer tick to not cost the reader real minutes — but
// nowhere near large enough to let someone walk away and still get
// credited for the gap.
const HEARTBEAT_INTERVAL_SECONDS = 10 * 60;
const HEARTBEAT_MAX_CREDIT_SECONDS = 12 * 60;

/** The Date a session was last "checked in" as actively read, for capping
 * how much of a gap since then can be credited. */
function _lastCheckinTime(data) {
  if (data.lastHeartbeatAt && data.lastHeartbeatAt.toDate) return data.lastHeartbeatAt.toDate();
  if (data.sessionStart && data.sessionStart.toDate) return data.sessionStart.toDate();
  if (data.startTime && data.startTime.toDate) return data.startTime.toDate();
  return null;
}

/** Elapsed seconds between `from` and `to`, capped at HEARTBEAT_MAX_CREDIT_SECONDS
 * so a gap in checking in (idle, backgrounded, killed) only credits up to
 * the cap rather than the whole gap. */
function _cappedElapsedSeconds(from, to) {
  if (!from) return 0;
  const raw = Math.max(0, Math.round((to.getTime() - from.getTime()) / 1000));
  return Math.min(raw, HEARTBEAT_MAX_CREDIT_SECONDS);
}

/**
 * Starts a reading session. Writes the same field shape
 * ReadingSessionService.startSession always has (both the
 * "analytics-friendly" and "legacy/alternate" schema fields other code
 * already reads) so no downstream reader needs to change, plus
 * `startedViaCloudFunction: true` marking this session's start time as
 * server-verified.
 */
async function startReadingSession(db, userId, { bookId, bookTitle }) {
  if (!bookId || typeof bookId !== 'string') {
    throw new ValidationError('bookId is required.');
  }
  const now = new Date();
  const ref = await db.collection('reading_sessions').add({
    userId,
    bookId,
    bookTitle: typeof bookTitle === 'string' ? bookTitle : '',
    // Analytics-friendly schema
    createdAt: now,
    createdAtClient: now,
    sessionStart: now,
    sessionEnd: null,
    sessionDurationSeconds: 0,
    sessionDurationMinutes: 0,
    // Legacy/alternate schema
    startTime: now,
    clientStartTime: now,
    endTime: null,
    durationMinutes: 0,
    startedViaCloudFunction: true,
    // Heartbeat accounting (Option A) — see file header.
    accountedSeconds: 0,
    lastHeartbeatAt: now,
    heartbeatCount: 0,
  });
  return { sessionId: ref.id };
}

/**
 * Records a "still actively reading" check-in for an open session.
 * Credits only the time elapsed since the last heartbeat (or session
 * start), capped at HEARTBEAT_MAX_CREDIT_SECONDS — see the file header
 * for why. Idempotent-safe against a session that's already ended: a
 * late/racing heartbeat there is a no-op, not an error, since the client
 * can't always know its previous endReadingSession call landed first.
 */
async function recordReadingHeartbeat(db, userId, { sessionId }) {
  if (!sessionId || typeof sessionId !== 'string') {
    throw new ValidationError('sessionId is required.');
  }

  return db.runTransaction(async (tx) => {
    const ref = db.collection('reading_sessions').doc(sessionId);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new NotFoundError('Reading session not found.');
    }
    const data = snap.data();
    if (data.userId !== userId) {
      throw new ValidationError('This reading session does not belong to you.');
    }

    if (data.sessionEnd || data.endTime) {
      return {
        sessionId,
        accountedSeconds: data.accountedSeconds || 0,
        ended: true,
      };
    }

    const now = new Date();
    const cappedElapsed = _cappedElapsedSeconds(_lastCheckinTime(data), now);
    const accountedSeconds = Math.min(
      (data.accountedSeconds || 0) + cappedElapsed,
      MAX_SESSION_SECONDS,
    );

    tx.update(ref, {
      accountedSeconds,
      lastHeartbeatAt: now,
      heartbeatCount: (data.heartbeatCount || 0) + 1,
    });

    return { sessionId, accountedSeconds };
  });
}

/**
 * Ends a reading session. Duration is the accumulated heartbeat-credited
 * time (see file header) plus one final capped segment from the last
 * check-in to now — never a client-supplied duration, and never a raw
 * start-to-end diff that would credit a whole abandoned session.
 * Idempotent: ending an already-ended session just returns its
 * already-computed duration instead of erroring, so a retried call
 * after a flaky response doesn't look like a failure.
 */
async function endReadingSession(db, userId, { sessionId }) {
  if (!sessionId || typeof sessionId !== 'string') {
    throw new ValidationError('sessionId is required.');
  }

  return db.runTransaction(async (tx) => {
    const ref = db.collection('reading_sessions').doc(sessionId);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new NotFoundError('Reading session not found.');
    }
    const data = snap.data();
    if (data.userId !== userId) {
      throw new ValidationError('This reading session does not belong to you.');
    }

    if (data.sessionEnd || data.endTime) {
      return {
        sessionId,
        durationMinutes: data.durationMinutes || data.sessionDurationMinutes || 0,
        alreadyEnded: true,
      };
    }

    const now = new Date();
    const finalSegment = _cappedElapsedSeconds(_lastCheckinTime(data), now);
    const accountedSeconds = Math.min(
      (data.accountedSeconds || 0) + finalSegment,
      MAX_SESSION_SECONDS,
    );
    const durationMinutes = accountedSeconds > 0 ? Math.ceil(accountedSeconds / 60) : 0;

    tx.update(ref, {
      sessionEnd: now,
      clientEndTime: now,
      sessionDurationSeconds: accountedSeconds,
      sessionDurationMinutes: durationMinutes,
      endTime: now,
      durationMinutes,
      endedViaCloudFunction: true,
    });

    return { sessionId, durationMinutes };
  });
}

module.exports = {
  ValidationError,
  NotFoundError,
  HEARTBEAT_INTERVAL_SECONDS,
  HEARTBEAT_MAX_CREDIT_SECONDS,
  MAX_SESSION_SECONDS,
  startReadingSession,
  endReadingSession,
  recordReadingHeartbeat,
};
