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
 * from anything the client reports. A client can still choose *when* to
 * call end (e.g. leave a session open for hours without reading), which
 * this doesn't fully close — see the design doc for why that's an
 * accepted, much smaller gap than fabricating a session outright, and
 * why full heartbeat-based verification (Option A) was not pursued.
 *
 * Deliberately NOT wrapped in the same "fails closed" pattern as
 * points_engine.js: `ReadingSessionService` calls these first and falls
 * back to its original direct-Firestore-write behavior on any failure
 * (offline, cold start, etc.) so reading itself never breaks — a
 * fallback-created session is simply unverified, exactly like every
 * session was before this change. See that fallback for the offline
 * story; nothing here handles offline itself.
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
  });
  return { sessionId: ref.id };
}

/**
 * Ends a reading session, computing duration from the server's own
 * start-time record to end-of-call clock reading — never from a
 * client-supplied duration. Idempotent: ending an already-ended session
 * just returns its already-computed duration instead of erroring, so a
 * retried call after a flaky response doesn't look like a failure.
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

    const startTime = (data.sessionStart && data.sessionStart.toDate
      ? data.sessionStart.toDate()
      : (data.startTime && data.startTime.toDate ? data.startTime.toDate() : null));
    const now = new Date();
    const rawSeconds = startTime
      ? Math.max(0, Math.round((now.getTime() - startTime.getTime()) / 1000))
      : 0;
    const cappedSeconds = Math.min(rawSeconds, MAX_SESSION_SECONDS);
    const durationMinutes = cappedSeconds > 0 ? Math.ceil(cappedSeconds / 60) : 0;

    tx.update(ref, {
      sessionEnd: now,
      clientEndTime: now,
      sessionDurationSeconds: cappedSeconds,
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
  startReadingSession,
  endReadingSession,
};
