/**
 * Script to sync totalAchievementPoints for existing users
 * Run this once to migrate existing achievement data
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function syncAchievementPoints() {
  console.log('🚀 Starting achievement points sync...\n');

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users\n`);

    let updatedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      // Get all achievements for this user
      const achievementsSnapshot = await db.collection('user_achievements')
        .where('userId', '==', userId)
        .get();

      if (achievementsSnapshot.empty) {
        console.log(`⏭️  User ${userData.username || userId}: No achievements, setting to 0`);
        await db.collection('users').doc(userId).update({
          totalAchievementPoints: 0
        });
        continue;
      }

      // Calculate total points
      let totalPoints = 0;
      achievementsSnapshot.docs.forEach(doc => {
        const points = doc.data().points || 0;
        totalPoints += points;
      });

      // Update user document
      await db.collection('users').doc(userId).update({
        totalAchievementPoints: totalPoints
      });

      console.log(`✅ User ${userData.username || userId}: ${achievementsSnapshot.size} achievements = ${totalPoints} points`);
      updatedCount++;
    }

    console.log(`\n🎉 Sync complete! Updated ${updatedCount} users`);
    process.exit(0);

  } catch (error) {
    console.error('❌ Error syncing achievement points:', error);
    process.exit(1);
  }
}

syncAchievementPoints();
