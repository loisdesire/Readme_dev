/**
 * Aggregates a user's positive reading signals into a weighted trait score,
 * used to feed both the rule-based fallback and the AI recommendation
 * prompt. Extracted from index.js so it can be tested against the
 * Firestore emulator, taking `db` as a parameter instead of a module-level
 * global.
 *
 * Signal weights (higher = stronger evidence the child enjoys books with
 * that trait):
 *   - Personality quiz's dominant traits: +1 each (base signal)
 *   - Favorited a book: +3 per trait (strongest explicit signal)
 *   - Completed a book: +2 per trait, or +5 if it's a re-read
 *   - 70%+ progress on an unfinished book: +1 per trait (engagement)
 *   - 80%+ score on a book's quiz: +2 per trait (comprehension + interest)
 *   - 2+ reading sessions of 30+ minutes on the same book: +1 per trait
 *
 * @param {string} userId
 * @param {FirebaseFirestore.Firestore} db
 * @param {{error: Function, info: Function}} [log] Injectable logger (defaults to console).
 * @returns {Promise<{topTraits: string[]}>} The top 5 traits by total score.
 *   Never throws — a failure during aggregation yields an empty list, same
 *   as before extraction, since callers treat this as "not enough signal
 *   yet" rather than a hard error.
 */
async function aggregateUserSignals(userId, db, log = console) {
  try {
    const traitCounts = {};

    const addTraits = (traits, weight) => {
      (traits || []).forEach((trait) => {
        traitCounts[trait] = (traitCounts[trait] || 0) + weight;
      });
    };

    // 1. Quiz traits (base personality - weight 1)
    const quizSnap = await db.collection('quiz_analytics')
      .where('userId', '==', userId)
      .orderBy('completedAt', 'desc')
      .limit(1)
      .get();

    if (!quizSnap.empty) {
      const quizTraits = quizSnap.docs[0].data().dominantTraits || [];
      quizTraits.forEach((trait) => {
        traitCounts[trait] = 1; // Base weight from personality quiz
      });
    }

    // Gather every other signal source first, WITHOUT fetching any book
    // data yet, so every distinct book referenced across all of them can
    // be fetched exactly once below — the original version issued one
    // sequential `db.collection('books').doc(id).get()` per interaction
    // (per favorite, per completion, per progress record, per quiz
    // attempt, per book with 2+ long sessions), awaited one at a time in
    // a loop. For an active user that's easily 50-100+ round trips, and
    // the same popular book could be fetched repeatedly across
    // categories (e.g. favorited AND completed AND in-progress).

    // 2. Favorite books (weight +3 - strongest explicit signal)
    const favoritesSnap = await db.collection('book_interactions')
      .where('userId', '==', userId)
      .where('type', '==', 'favorite')
      .get();
    const favoriteBookIds = favoritesSnap.docs.map((doc) => doc.data().bookId);

    // 3. Completed books and re-reads
    const completedSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .get();
    // Weight per completion record (not deduplicated per book): the Nth
    // completion of the same book is a re-read and worth more than the 1st.
    const completedBooks = {};
    const completionWeights = []; // {bookId, weight}
    for (const doc of completedSnap.docs) {
      const bookId = doc.data().bookId;
      completedBooks[bookId] = (completedBooks[bookId] || 0) + 1;
      const isReread = completedBooks[bookId] > 1;
      completionWeights.push({ bookId, weight: isReread ? 5 : 2 });
    }

    // 4. High-progress (70%+) but not-yet-completed books (weight +1)
    const allProgressSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .get();
    const unfinishedProgressDocs = allProgressSnap.docs
      .map((doc) => doc.data())
      .filter((progress) => !progress.isCompleted);

    // 5. Good quiz scores (80%+) on a book's quiz (weight +2)
    const quizAttemptsSnap = await db.collection('quiz_attempts')
      .where('userId', '==', userId)
      .get();
    const goodQuizAttemptBookIds = quizAttemptsSnap.docs
      .map((doc) => doc.data())
      .filter((attempt) => {
        const score = attempt.score || 0;
        const totalQuestions = attempt.totalQuestions || 5;
        return (score / totalQuestions) * 100 >= 80;
      })
      .map((attempt) => attempt.bookId);

    // 6. Long reading sessions (30+ min), 2+ of them on the same book (weight +1)
    const sessionsSnap = await db.collection('reading_sessions')
      .where('userId', '==', userId)
      .get();
    const longSessionCountByBook = {};
    for (const doc of sessionsSnap.docs) {
      const session = doc.data();
      const duration = session.sessionDurationSeconds || 0;
      if (duration >= 1800) {
        const bookId = session.bookId;
        longSessionCountByBook[bookId] = (longSessionCountByBook[bookId] || 0) + 1;
      }
    }
    const engagingBookIds = Object.entries(longSessionCountByBook)
      .filter(([, sessionCount]) => sessionCount >= 2)
      .map(([bookId]) => bookId);

    // One batched fetch (a single round trip via Firestore's getAll, not
    // one .get() per interaction) covering every distinct book any signal
    // above needs, deduplicated.
    const neededBookIds = new Set([
      ...favoriteBookIds,
      ...completionWeights.map((c) => c.bookId),
      ...unfinishedProgressDocs.map((p) => p.bookId),
      ...goodQuizAttemptBookIds,
      ...engagingBookIds,
    ]);
    const bookDataById = await fetchBooksByIds(db, neededBookIds);

    // Now apply every signal's weight using that single shared lookup —
    // same per-record weighting as before, just no longer re-fetching.
    for (const bookId of favoriteBookIds) {
      const book = bookDataById[bookId];
      if (book) addTraits(book.traits, 3);
    }

    for (const { bookId, weight } of completionWeights) {
      const book = bookDataById[bookId];
      if (book) addTraits(book.traits, weight);
    }

    for (const progress of unfinishedProgressDocs) {
      const book = bookDataById[progress.bookId];
      if (!book) continue;
      const totalPages = book.totalPages || 1;
      const currentPage = progress.currentPage || 0;
      const progressPercent = (currentPage / totalPages) * 100;
      if (progressPercent >= 70) {
        addTraits(book.traits, 1);
      }
    }

    for (const bookId of goodQuizAttemptBookIds) {
      const book = bookDataById[bookId];
      if (book) addTraits(book.traits, 2);
    }

    for (const bookId of engagingBookIds) {
      const book = bookDataById[bookId];
      if (book) addTraits(book.traits, 1);
    }

    const topTraits = Object.entries(traitCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([trait]) => trait);

    log.info(`[SIGNALS] User ${userId} top traits:`, topTraits);
    log.info('[SIGNALS] Trait scores:', traitCounts);
    return { topTraits };
  } catch (error) {
    log.error('Error aggregating user signals:', error);
    return { topTraits: [] };
  }
}

/**
 * Fetches multiple `books` documents in a single round trip (via
 * Firestore's `getAll`) instead of one `.get()` per id, and returns a
 * plain `{ [id]: data }` map covering only the ids that actually exist.
 * Also used by generateAIRecommendations's completed-books exclusion.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {Iterable<string>} bookIds Possibly containing duplicates/falsy
 *   values - deduplicated and filtered here.
 * @returns {Promise<Record<string, FirebaseFirestore.DocumentData>>}
 */
async function fetchBooksByIds(db, bookIds) {
  const ids = [...new Set(bookIds)].filter(Boolean);
  if (ids.length === 0) return {};

  const refs = ids.map((id) => db.collection('books').doc(id));
  const snaps = await db.getAll(...refs);

  const result = {};
  snaps.forEach((snap) => {
    if (snap.exists) {
      result[snap.id] = snap.data();
    }
  });
  return result;
}

module.exports = { aggregateUserSignals, fetchBooksByIds };
