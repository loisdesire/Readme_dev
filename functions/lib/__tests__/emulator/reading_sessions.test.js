/**
 * Real Firestore-emulator-backed tests for server-timestamped reading
 * sessions (see reading_sessions.js's file header and
 * docs/reading-session-integrity-design.md). Run via `npm run test:emulator`.
 */
const admin = require('firebase-admin');
const {
  ValidationError,
  NotFoundError,
  startReadingSession,
  endReadingSession,
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

  test('rejects a missing bookId', async () => {
    await expect(
      startReadingSession(db, uid(), {})
    ).rejects.toBeInstanceOf(ValidationError);
  });
});

describe('endReadingSession', () => {
  test('computes duration from the server\'s own start-to-end clock '
      + 'reading, never from a client-supplied number', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });

    // Backdate the server-set start time to simulate real elapsed time —
    // there's no way to make real wall-clock time pass in a fast test.
    await db.collection('reading_sessions').doc(sessionId).update({
      sessionStart: new Date(Date.now() - 5 * 60000),
      startTime: new Date(Date.now() - 5 * 60000),
    });

    const result = await endReadingSession(db, userId, { sessionId });
    expect(result.durationMinutes).toBeGreaterThanOrEqual(5);

    const doc = await db.collection('reading_sessions').doc(sessionId).get();
    const data = doc.data();
    expect(data.durationMinutes).toBe(result.durationMinutes);
    expect(data.sessionDurationMinutes).toBe(result.durationMinutes);
    expect(data.endedViaCloudFunction).toBe(true);
    expect(data.sessionEnd).toBeTruthy();
  });

  test('clamps to 6 hours for a stuck/forgotten-open session', async () => {
    const userId = uid();
    const { sessionId } = await startReadingSession(db, userId, { bookId: 'b1' });
    await db.collection('reading_sessions').doc(sessionId).update({
      sessionStart: new Date(Date.now() - 10 * 60 * 60000),
      startTime: new Date(Date.now() - 10 * 60 * 60000),
    });

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
    await db.collection('reading_sessions').doc(sessionId).update({
      sessionStart: new Date(Date.now() - 3 * 60000),
      startTime: new Date(Date.now() - 3 * 60000),
    });

    const first = await endReadingSession(db, userId, { sessionId });
    const second = await endReadingSession(db, userId, { sessionId });

    expect(second.durationMinutes).toBe(first.durationMinutes);
    expect(second.alreadyEnded).toBe(true);
  });
});
