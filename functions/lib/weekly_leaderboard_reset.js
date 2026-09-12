/**
 * Shared logic behind the weekly leaderboard reset — both the scheduled
 * job (resetWeeklyLeaderboard) and the manual admin trigger
 * (manualWeeklyReset) call this instead of duplicating it.
 */

/**
 * Whether `uid` is an admin, checked the same way the rest of the app does
 * (admin_portal_screen.dart, firestore.rules): `users/{uid}.role == 'admin'`,
 * falling back to the `admins/{uid}` doc.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {string|null|undefined} uid
 * @returns {Promise<boolean>}
 */
async function isAdmin(db, uid) {
  if (!uid) return false;

  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists && userDoc.data().role === 'admin') return true;

  const adminDoc = await db.collection('admins').doc(uid).get();
  return adminDoc.exists && adminDoc.data().role === 'admin';
}

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

module.exports = { isAdmin, resetWeeklyLeaderboard };
