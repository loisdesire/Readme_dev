/**
 * Real Firestore-emulator-backed tests for server-timestamped reading
 * sessions (see reading_sessions.js's file header and
 * docs/reading-session-integrity-design.md). Run via `npm run test:emulator`.
 */
const admin = require('firebase-admin');
const {
  ValidationError,
  NotFoundError,
  HEARTBEAT_MAX_CREDIT_SECONDS,
  startReadingSession,
  endReadingSession,
  recordReadingHeartbeat,
} = require('../../reading_sessions');

let app;
let db;

beforeAll(() => {
  app = admin.initializeApp({ projectId: 'readme-functions-test-sessions' });
  db = admin.firestore();
});

afterAll(async () => {
  await app.delete();
});

const uid = () => `u-${Date.now()}-${Math.random().toString(36).slice(2)}`;

// Backdates both the "checked in at session start" timestamp
// (lastHeartbeatAt) and the schema-variant start fields together, since
// recordReadingHeartbeat/endReadingSession consult lastHeartbeatAt first
// once it exists — it's set at session creation, same as sessionStart.
async function backdateStart(sessionId, minutesAgo) {
  const then = new Date(Date.now() - minutesAgo * 60000);
  await db.collection('reading_sessions').doc(sessionId).update({
    sessionStart: then,
    startTime: then,
    lastHeartbeatAt: then,
  });
}

describe('startReadingSession', () => {
  test('creates a session doc stamped with the server clock, marked '
      + 'server-verified', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, {
      bookId: 'b1', bookTitle: 'The Great Adventure',
    });
    expect(sessionId).toBeTruthy();

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    const data = doc.data();
    expect(data.userId).toBe(userId);
    expect(data.bookId).toBe('b1');
    expect(data.bookTitle).toBe('The Great Adventure');
    expect(data.startedViaCloudFunction).toBe(true);
    expect(data.sessionEnd).toBeNull();
    expect(data.endTime).toBeNull();
    // Both schema variants other code reads are populated.
    expect(data.sessionStart).toBeTruthy();
    expect(data.startTime).toBeTruthy();
  });

  test('also initializes heartbeat accounting fields (Option A)', async () => {
    const { sessionId } = await startReadingSession(db, uid(), { bookId: 'b1' });
    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    const data = doc.data();
    expect(data.accountedSeconds).toBe(0);
    expect(data.heartbeatCount).toBe(0);
    expect(data.lastHeartbeatAt).toBeTruthy();
  });

  test('rejects a missing bookId', async () => {
    await expect(
      startReadingSession(db, uid(), {})
    ).rejects.toBeInstanceOf(ValidationError);
  });
});

describe('recordReadingHeartbeat', () => {
  test('credits elapsed time since the last check-in', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 4);

    const result = await recordReadingHeartbeat(db, userId, { sessionId });
    expect(result.accountedSeconds).toBeGreaterThanOrEqual(4 * 60);
    expect(result.accountedSeconds).toBeLessThan(HEARTBEAT_MAX_CREDIT_SECONDS);

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    expect(doc.data().heartbeatCount).toBe(1);
    expect(doc.data().accountedSeconds).toBe(result.accountedSeconds);
  });

  test('caps a large gap since the last check-in — idle, backgrounded, or '
      + 'a killed app don\'t get credited for the whole gap', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 120); // 2 hours since "start", no heartbeats in between

    const result = await recordReadingHeartbeat(db, userId, { sessionId });
    expect(result.accountedSeconds).toBe(HEARTBEAT_MAX_CREDIT_SECONDS);
  });

  test('accumulates across multiple heartbeats, and a following heartbeat '
      + 'only credits the new gap, not the whole session again', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 5);

    const first = await recordReadingHeartbeat(db, userId, { sessionId });
    expect(first.accountedSeconds).toBeGreaterThanOrEqual(5 * 60);

    // Immediately-following heartbeat: almost no new time has passed.
    const second = await recordReadingHeartbeat(db, userId, { sessionId });
    expect(second.accountedSeconds).toBeGreaterThanOrEqual(first.accountedSeconds);
    expect(second.accountedSeconds).toBeLessThan(first.accountedSeconds + 5);

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    expect(doc.data().heartbeatCount).toBe(2);
  });

  test('a heartbeat on an already-ended session is a no-op, not an error',
      async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 2);
    await endReadingSession(db, userId, { sessionId });

    const result = await recordReadingHeartbeat(db, userId, { sessionId });
    expect(result.ended).toBe(true);

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    expect(doc.data().heartbeatCount).toBe(0); // untouched — heartbeat didn't re-credit anything
  });

  test('rejects a missing sessionId', async () => {
    await expect(
      recordReadingHeartbeat(db, uid(), {})
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('rejects a heartbeat for someone else\'s session', async () => {
    const owner = uid();
    const attacker = uid();
    const { sessionId } = await startReadingSession(db, owner, { bookId: 'b1' });

    await expect(
      recordReadingHeartbeat(db, attacker, { sessionId })
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('rejects a made-up sessionId', async () => {
    await expect(
      recordReadingHeartbeat(db, uid(), { sessionId: 'does-not-exist' })
    ).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe('endReadingSession', () => {
  test('computes duration from the server\'s own check-in record, never '
      + 'from a client-supplied number', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 5);

    const result = await endReadingSession(db, userId, { sessionId });
    expect(result.durationMinutes).toBeGreaterThanOrEqual(5);

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    const data = doc.data();
    expect(data.durationMinutes).toBe(result.durationMinutes);
    expect(data.sessionDurationMinutes).toBe(result.durationMinutes);
    expect(data.endedViaCloudFunction).toBe(true);
    expect(data.sessionEnd).toBeTruthy();
  });

  test('a session with no heartbeats only credits up to the heartbeat cap '
      + 'at end, not the full elapsed time — leaving a session open and '
      + 'walking away no longer pays out the whole gap (Option A)', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 10 * 60); // "forgotten open" for 10 hours, no check-ins

    const result = await endReadingSession(db, userId, { sessionId });
    expect(result.durationMinutes).toBe(HEARTBEAT_MAX_CREDIT_SECONDS / 60);
    expect(result.durationMinutes).toBeLessThan(360);
  });

  test('a genuinely long session built from regular heartbeats can still '
      + 'reach the 6-hour outer clamp', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    // Simulate ~50 heartbeats' worth of already-accumulated, legitimately
    // checked-in time (more than 6 hours), as if many real 10-minute
    // heartbeats had already landed.
    await db.collection('reading_sessions').doc(sessionId).update({
      accountedSeconds: 7 * 60 * 60, // 7 hours already accounted
    });
    await backdateStart(sessionId, 5); // last check-in 5 minutes ago

    const result = await endReadingSession(db, userId, { sessionId });
    expect(result.durationMinutes).toBe(360);
  });

  test('rejects ending a session that belongs to someone else', async () => {
    const owner = uid();
    const attacker = uid();
    const { sessionId } = await startReadingSession(db, owner, { bookId: 'b1' });

    await expect(
      endReadingSession(db, attacker, { sessionId })
    ).rejects.toBeInstanceOf(ValidationError);
  });

  test('rejects a made-up sessionId', async () => {
    await expect(
      endReadingSession(db, uid(), { sessionId: 'does-not-exist' })
    ).rejects.toBeInstanceOf(NotFoundError);
  });

  test('ending an already-ended session is idempotent — returns the same '
      + 'duration instead of erroring, for a safely-retried call', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await backdateStart(sessionId, 3);

    const first = await endReadingSession(db, userId, { sessionId });
    const second = await endReadingSession(db, userId, { sessionId });

    expect(second.durationMinutes).toBe(first.durationMinutes);
    expect(second.alreadyEnded).toBe(true);
  });
});
