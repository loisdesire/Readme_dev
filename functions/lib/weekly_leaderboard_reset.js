/**
 * Shared logic behind the weekly leaderboard reset — both the scheduled
 * job (resetWeeklyLeaderboard) and the manual admin trigger
 * (manualWeeklyReset) call this instead of duplicating it.
 */

const { isAdmin } = require('./admin_check');

/**
 * Zeroes every user's weekly leaderboard stats.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{info: Function}} [log]
 * @returns {Promise<{success: true, usersUpdated: number}>}
 */
async function resetWeeklyLeaderboard(db, log = console) {
  const usersSnapshot = await db.collection('users').get();
  const batch = db.batch();
  let count = 0;

  usersSnapshot.forEach((doc) => {
    batch.update(doc.ref, {
      totalAchievementPoints: 0,
      weeklyBooksRead: 0,
      weeklyPoints: 0,
      weeklyReadingMinutes: 0,
      lastWeeklyReset: new Date(),
    });
    count++;
  });

  await batch.commit();
  log.info(`Weekly leaderboard reset complete! Updated ${count} users.`);

  return { success: true, usersUpdated: count };
}

// Re-exported for backwards compatibility with existing importers/tests.
module.exports = { isAdmin, resetWeeklyLeaderboard };
