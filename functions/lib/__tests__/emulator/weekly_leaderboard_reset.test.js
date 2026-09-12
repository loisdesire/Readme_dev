/**
 * Real Firestore-emulator-backed tests for the weekly leaderboard reset and
 * its admin check — run via `npm run test:emulator`.
 */
const admin = require('firebase-admin');
const { isAdmin, resetWeeklyLeaderboard } = require('../../weekly_leaderboard_reset');

let app;
let db;

beforeAll(() => {
  app = admin.initializeApp({ projectId: 'readme-functions-test-leaderboard' });
  db = admin.firestore();
});

afterAll(async () => {
  await app.delete();
});

const quietLog = { info: () => {} };

describe('isAdmin', () => {
  test('true for a user doc with role: admin', async () => {
    const uid = `admin-${Date.now()}`;
    await db.collection('users').doc(uid).set({ role: 'admin' });
    expect(await isAdmin(db, uid)).toBe(true);
  });

  test('true for a user via the admins/{uid} fallback doc, even without a '
      + 'matching users/{uid} role', async () => {
    const uid = `admin2-${Date.now()}`;
    await db.collection('admins').doc(uid).set({ role: 'admin' });
    expect(await isAdmin(db, uid)).toBe(true);
  });

  test('false for a regular user', async () => {
    const uid = `user-${Date.now()}`;
    await db.collection('users').doc(uid).set({ role: 'user' });
    expect(await isAdmin(db, uid)).toBe(false);
  });

  test('false for a uid with no user doc at all', async () => {
    expect(await isAdmin(db, `nobody-${Date.now()}`)).toBe(false);
  });

  test('false for a null/undefined uid (the unauthenticated case)', async () => {
    expect(await isAdmin(db, null)).toBe(false);
    expect(await isAdmin(db, undefined)).toBe(false);
  });
});

describe('resetWeeklyLeaderboard', () => {
  test('zeroes every user\'s weekly stats', async () => {
    const uid1 = `reset-user-${Date.now()}-1`;
    const uid2 = `reset-user-${Date.now()}-2`;
    await db.collection('users').doc(uid1).set({
      totalAchievementPoints: 500, weeklyBooksRead: 3, weeklyPoints: 200, weeklyReadingMinutes: 120,
    });
    await db.collection('users').doc(uid2).set({
      totalAchievementPoints: 10, weeklyBooksRead: 1, weeklyPoints: 5, weeklyReadingMinutes: 15,
    });

    const result = await resetWeeklyLeaderboard(db, quietLog);

    expect(result.success).toBe(true);
    expect(result.usersUpdated).toBeGreaterThanOrEqual(2);

    const doc1 = await db.collection('users').doc(uid1).get();
    expect(doc1.data().totalAchievementPoints).toBe(0);
    expect(doc1.data().weeklyBooksRead).toBe(0);
    expect(doc1.data().weeklyPoints).toBe(0);
    expect(doc1.data().weeklyReadingMinutes).toBe(0);
    expect(doc1.data().lastWeeklyReset).toBeTruthy();

    const doc2 = await db.collection('users').doc(uid2).get();
    expect(doc2.data().totalAchievementPoints).toBe(0);
  });
});
