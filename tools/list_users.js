const admin = require('firebase-admin');

// Initialize Firebase Admin for readmev2
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://readmev2.firebaseio.com`
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

async function listUsers() {
  try {
    console.log('📋 Listing all users in readmev2...\n');
    
    const usersSnapshot = await db.collection('users').get();
    
    console.log(`📊 Total users found: ${usersSnapshot.size}\n`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    let count = 1;
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`${count}. ${data.username || 'Unknown'}`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Email: ${data.email || 'N/A'}`);
      console.log(`   Role: ${data.role || 'N/A'}`);
      console.log(`   Created: ${data.createdAt ? new Date(data.createdAt.toDate()).toISOString() : 'N/A'}`);
      console.log(`   Points: ${data.totalAchievementPoints || 0}`);
      console.log('');
      count++;
    });
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
  } catch (error) {
    console.error('❌ Error listing users:', error);
  } finally {
    await admin.app().delete();
    process.exit(0);
  }
}

listUsers();
