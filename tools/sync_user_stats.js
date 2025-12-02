/**
 * Script to sync totalBooksRead and currentStreak for existing users
 * Run this to ensure leaderboard shows accurate data
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function calculateReadingStreak(userId) {
  try {
    const now = new Date();
    now.setHours(0, 0, 0, 0); // Start of today
    
    let streak = 0;
    let checkDate = new Date(now);
    
    // Check last 365 days for reading activity
    for (let i = 0; i < 365; i++) {
      const dayStart = new Date(checkDate);
      dayStart.setHours(0, 0, 0, 0);
      
      const dayEnd = new Date(checkDate);
      dayEnd.setHours(23, 59, 59, 999);
      
      const sessionsSnap = await db.collection('reading_sessions')
        .where('userId', '==', userId)
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(dayStart))
        .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(dayEnd))
        .limit(1)
        .get();
      
      if (sessionsSnap.empty) {
        // No activity this day, streak broken
        break;
      }
      
      streak++;
      checkDate.setDate(checkDate.getDate() - 1); // Go back one day
    }
    
    return streak;
  } catch (error) {
    console.error(`Error calculating streak for ${userId}:`, error.message);
    return 0;
  }
}

async function syncUserStats() {
  console.log('🚀 Starting user stats sync...\n');

  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users\n`);

    let updatedCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      // Calculate total books read (completed)
      const progressSnap = await db.collection('reading_progress')
        .where('userId', '==', userId)
        .where('isCompleted', '==', true)
        .get();
      
      const totalBooksRead = progressSnap.size;
      
      // Calculate reading streak
      const currentStreak = await calculateReadingStreak(userId);
      
      // Update user document
      await db.collection('users').doc(userId).update({
        totalBooksRead: totalBooksRead,
        currentStreak: currentStreak
      });

      console.log(`✅ ${userData.username || userId}: ${totalBooksRead} books, ${currentStreak} day streak`);
      updatedCount++;
    }

    console.log(`\n🎉 Sync complete! Updated ${updatedCount} users`);
    process.exit(0);

  } catch (error) {
    console.error('❌ Error syncing user stats:', error);
    process.exit(1);
  }
}

syncUserStats();
