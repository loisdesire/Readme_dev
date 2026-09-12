/**
 * Real Firestore-emulator-backed tests for the recommendation engine's
 * signal-weighting logic — run via `npm run test:emulator`.
 */
const admin = require('firebase-admin');
const { aggregateUserSignals } = require('../../aggregate_user_signals');

let app;
let db;

beforeAll(() => {
  app = admin.initializeApp({ projectId: 'readme-functions-test-signals' });
  db = admin.firestore();
});

afterAll(async () => {
  await app.delete();
});

const quietLog = { info: () => {}, error: () => {} };

async function seedBook(id, traits, extra = {}) {
  await db.collection('books').doc(id).set({ title: id, traits, ...extra });
}

describe('aggregateUserSignals', () => {
  test('a personality quiz result contributes its traits at weight 1', async () => {
    const userId = `u-quiz-${Date.now()}`;
    await db.collection('quiz_analytics').add({
      userId,
      dominantTraits: ['curious', 'kind'],
      completedAt: new Date(),
    });

    const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

    expect(topTraits).toEqual(expect.arrayContaining(['curious', 'kind']));
  });

  test('only the most recent quiz result counts, not older ones', async () => {
    const userId = `u-quiz2-${Date.now()}`;
    await db.collection('quiz_analytics').add({
      userId,
      dominantTraits: ['calm'],
      completedAt: new Date('2020-01-01'),
    });
    await db.collection('quiz_analytics').add({
      userId,
      dominantTraits: ['brave'],
      completedAt: new Date(), // most recent
    });

    const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

    expect(topTraits).toContain('brave');
    expect(topTraits).not.toContain('calm');
  });

  test('a favorited book outweighs a merely-completed one (weight 3 vs 2)',
      async () => {
        const userId = `u-fav-${Date.now()}`;
        await seedBook('fav-book', ['adventurous']);
        await seedBook('completed-book', ['calm']);

        await db.collection('book_interactions').add({
          userId, type: 'favorite', bookId: 'fav-book',
        });
        await db.collection('reading_progress').add({
          userId, bookId: 'completed-book', isCompleted: true,
        });

        const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

        expect(topTraits.indexOf('adventurous')).toBeLessThan(topTraits.indexOf('calm'));
      });

  test('re-reading a book (weight 5) outweighs a single completion (weight 2)',
      async () => {
        const userId = `u-reread-${Date.now()}`;
        await seedBook('reread-book', ['persistent']);
        await seedBook('once-book', ['social']);

        // Two completion records for the same book = a re-read.
        await db.collection('reading_progress').add({
          userId, bookId: 'reread-book', isCompleted: true,
        });
        await db.collection('reading_progress').add({
          userId, bookId: 'reread-book', isCompleted: true,
        });
        await db.collection('reading_progress').add({
          userId, bookId: 'once-book', isCompleted: true,
        });

        const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

        expect(topTraits.indexOf('persistent')).toBeLessThan(topTraits.indexOf('social'));
      });

  test('70%+ progress on an unfinished book counts; under 70% does not',
      async () => {
        const userId = `u-progress-${Date.now()}`;
        await seedBook('almost-done', ['creative'], { totalPages: 100 });
        await seedBook('barely-started', ['outgoing'], { totalPages: 100 });

        await db.collection('reading_progress').add({
          userId, bookId: 'almost-done', isCompleted: false, currentPage: 75,
        });
        await db.collection('reading_progress').add({
          userId, bookId: 'barely-started', isCompleted: false, currentPage: 10,
        });

        const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

        expect(topTraits).toContain('creative');
        expect(topTraits).not.toContain('outgoing');
      });

  test('an 80%+ book-quiz score counts that book\'s traits; a lower score '
      + 'does not', async () => {
        const userId = `u-quizscore-${Date.now()}`;
        await seedBook('understood-book', ['organized']);
        await seedBook('struggled-book', ['playful']);

        await db.collection('quiz_attempts').add({
          userId, bookId: 'understood-book', score: 4, totalQuestions: 5, // 80%
        });
        await db.collection('quiz_attempts').add({
          userId, bookId: 'struggled-book', score: 2, totalQuestions: 5, // 40%
        });

        const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

        expect(topTraits).toContain('organized');
        expect(topTraits).not.toContain('playful');
      });

  test('two+ long (30min+) reading sessions on a book count; a single long '
      + 'session does not meet the 2-session threshold', async () => {
        const userId = `u-sessions-${Date.now()}`;
        await seedBook('engaging-book', ['inventive']);
        await seedBook('one-long-session-book', ['cheerful']);

        await db.collection('reading_sessions').add({
          userId, bookId: 'engaging-book', sessionDurationSeconds: 1900,
        });
        await db.collection('reading_sessions').add({
          userId, bookId: 'engaging-book', sessionDurationSeconds: 2000,
        });
        await db.collection('reading_sessions').add({
          userId, bookId: 'one-long-session-book', sessionDurationSeconds: 1900,
        });

        const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

        expect(topTraits).toContain('inventive');
        expect(topTraits).not.toContain('cheerful');
      });

  test('returns at most the top 5 traits by total weighted score', async () => {
    const userId = `u-top5-${Date.now()}`;
    await db.collection('quiz_analytics').add({
      userId,
      dominantTraits: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
      completedAt: new Date(),
    });

    const { topTraits } = await aggregateUserSignals(userId, db, quietLog);

    expect(topTraits.length).toBeLessThanOrEqual(5);
  });

  test('a user with no signals at all gets an empty list, not an error',
      async () => {
        const { topTraits } = await aggregateUserSignals(`u-nobody-${Date.now()}`, db, quietLog);
        expect(topTraits).toEqual([]);
      });
});
