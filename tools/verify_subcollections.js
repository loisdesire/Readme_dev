/**
 * Verify subcollections were migrated
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey_new.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readmev2'
});

const db = admin.firestore();

async function verifySubcollections() {
  console.log('🔍 Checking subcollections in new database...\n');
  
  const usersSnapshot = await db.collection('users').limit(5).get();
  
  for (const userDoc of usersSnapshot.docs) {
    console.log(`👤 User: ${userDoc.id}`);
    console.log(`   Name: ${userDoc.data().displayName || userDoc.data().email}`);
    
    // Check achievements
    const achievementsSnapshot = await db
      .collection('users').doc(userDoc.id)
      .collection('achievements').get();
    console.log(`   🏆 Achievements: ${achievementsSnapshot.size} documents`);
    
    // Check reading progress
    const progressSnapshot = await db
      .collection('users').doc(userDoc.id)
      .collection('reading_progress').get();
    console.log(`   📖 Reading Progress: ${progressSnapshot.size} documents`);
    
    console.log('');
  }
  
  console.log('✅ Verification complete!\n');
  process.exit(0);
}

verifySubcollections();
