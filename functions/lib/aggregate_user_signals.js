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

    // 2. Favorite books (weight +3 - strongest explicit signal)
    const favoritesSnap = await db.collection('book_interactions')
      .where('userId', '==', userId)
      .where('type', '==', 'favorite')
      .get();

    for (const doc of favoritesSnap.docs) {
      const bookDoc = await db.collection('books').doc(doc.data().bookId).get();
      if (bookDoc.exists) {
        addTraits(bookDoc.data().traits, 3);
      }
    }

    // 3. Completed books and re-reads
    const completedSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .get();

    const completedBooks = {};
    for (const doc of completedSnap.docs) {
      const bookId = doc.data().bookId;
      completedBooks[bookId] = (completedBooks[bookId] || 0) + 1;

      const bookDoc = await db.collection('books').doc(bookId).get();
      if (bookDoc.exists) {
        const isReread = completedBooks[bookId] > 1;
        addTraits(bookDoc.data().traits, isReread ? 5 : 2);
      }
    }

    // 4. High-progress (70%+) but not-yet-completed books (weight +1)
    const allProgressSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .get();

    for (const doc of allProgressSnap.docs) {
      const progress = doc.data();
      const bookDoc = await db.collection('books').doc(progress.bookId).get();

      if (bookDoc.exists && !progress.isCompleted) {
        const totalPages = bookDoc.data().totalPages || 1;
        const currentPage = progress.currentPage || 0;
        const progressPercent = (currentPage / totalPages) * 100;

        if (progressPercent >= 70) {
          addTraits(bookDoc.data().traits, 1);
        }
      }
    }

    // 5. Good quiz scores (80%+) on a book's quiz (weight +2)
    const quizAttemptsSnap = await db.collection('quiz_attempts')
      .where('userId', '==', userId)
      .get();

    for (const doc of quizAttemptsSnap.docs) {
      const attempt = doc.data();
      const score = attempt.score || 0;
      const totalQuestions = attempt.totalQuestions || 5;
      const scorePercent = (score / totalQuestions) * 100;

      if (scorePercent >= 80) {
        const bookDoc = await db.collection('books').doc(attempt.bookId).get();
        if (bookDoc.exists) {
          addTraits(bookDoc.data().traits, 2);
        }
      }
    }

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

    for (const [bookId, sessionCount] of Object.entries(longSessionCountByBook)) {
      if (sessionCount >= 2) {
        const bookDoc = await db.collection('books').doc(bookId).get();
        if (bookDoc.exists) {
          addTraits(bookDoc.data().traits, 1);
        }
      }
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

module.exports = { aggregateUserSignals };
