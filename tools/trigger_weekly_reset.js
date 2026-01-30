const admin = require('firebase-admin');

// Initialize Firebase Admin for readmev2
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://readmev2.firebaseio.com`
});

const db = admin.firestore();

// Configure Firestore settings
db.settings({
  ignoreUndefinedProperties: true
});

async function triggerWeeklyReset() {
  try {
    console.log('🔄 Starting manual weekly leaderboard reset...\n');
    
    const usersSnapshot = await db.collection('users').get();
    const batch = db.batch();
    let count = 0;
    
    console.log(`📊 Found ${usersSnapshot.size} users to reset\n`);
    
    usersSnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        totalAchievementPoints: 0,
        weeklyBooksRead: 0,
        weeklyPoints: 0,
        weeklyReadingMinutes: 0,
        lastWeeklyReset: new Date()
      });
      count++;
    });
    
    await batch.commit();
    
    console.log(`\n✅ Weekly leaderboard reset complete!`);
    console.log(`   📊 Updated ${count} users`);
    console.log(`   ⏰ Reset timestamp: ${new Date().toISOString()}\n`);
    
  } catch (error) {
    console.error('❌ Error during reset:', error);
  } finally {
    await admin.app().delete();
    process.exit(0);
  }
}

triggerWeeklyReset();
