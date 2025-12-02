const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function removePersonalityExplorerAchievement() {
  try {
    console.log('🔍 Searching for Personality Explorer achievements...');

    // Query all user_achievements documents where achievement_id is 'personality_explorer'
    const achievementsSnapshot = await db.collection('user_achievements')
      .where('achievement_id', '==', 'personality_explorer')
      .get();

    if (achievementsSnapshot.empty) {
      console.log('✅ No Personality Explorer achievements found.');
      return;
    }

    console.log(`📋 Found ${achievementsSnapshot.size} user(s) with Personality Explorer achievement.`);

    // Delete each achievement document and update user's totalAchievementPoints
    const batch = db.batch();
    const userPointsToUpdate = {};

    for (const doc of achievementsSnapshot.docs) {
      const data = doc.data();
      const userId = data.user_id;
      const points = 15; // Personality Explorer gives 15 points

      console.log(`  - Removing achievement from user: ${userId}`);

      // Delete the achievement document
      batch.delete(doc.ref);

      // Track points to subtract from each user
      if (!userPointsToUpdate[userId]) {
        userPointsToUpdate[userId] = 0;
      }
      userPointsToUpdate[userId] += points;
    }

    // Update each user's totalAchievementPoints
    for (const [userId, pointsToSubtract] of Object.entries(userPointsToUpdate)) {
      const userRef = db.collection('users').doc(userId);
      batch.update(userRef, {
        totalAchievementPoints: admin.firestore.FieldValue.increment(-pointsToSubtract)
      });
      console.log(`  - Subtracting ${pointsToSubtract} points from user ${userId}`);
    }

    // Commit the batch
    await batch.commit();

    console.log(`✅ Successfully removed ${achievementsSnapshot.size} Personality Explorer achievement(s)`);
    console.log(`✅ Updated points for ${Object.keys(userPointsToUpdate).length} user(s)`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    // Exit the process
    process.exit(0);
  }
}

removePersonalityExplorerAchievement();
