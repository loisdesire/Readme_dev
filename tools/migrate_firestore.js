/**
 * Migrate Firestore data from old project to new project
 * Usage: node migrate_firestore.js
 */

const admin = require('firebase-admin');

// Initialize OLD Firebase project
const oldServiceAccount = require('./serviceAccountKey.json'); // Old project key
const oldApp = admin.initializeApp({
  credential: admin.credential.cert(oldServiceAccount),
  projectId: 'readme-40267'
}, 'oldApp');
const oldDb = oldApp.firestore();

// Initialize NEW Firebase project
// Download new service account key from Firebase Console and save as serviceAccountKey_new.json
const newServiceAccount = require('./serviceAccountKey_new.json'); // New project key
const newApp = admin.initializeApp({
  credential: admin.credential.cert(newServiceAccount),
  projectId: 'readmev2'
}, 'newApp');
const newDb = newApp.firestore();

// Collections to migrate
const COLLECTIONS_TO_MIGRATE = [
  'achievements',           // Achievement definitions
  'admin_settings',         // Admin configuration
  'book_interactions',      // User book interactions
  'book_quizzes',          // Quiz definitions for books
  'books',                  // Book library
  'content_filters',        // Content filtering settings
  'daily_reading_time',     // Reading time logs
  'notifications',          // System notifications
  'quiz_attempts',          // User quiz attempts
  'reading_progress',       // Reading progress (top-level)
  'reading_sessions',       // Reading session logs
  'user_achievements',      // User achievement unlocks
  'user_favorites',         // User favorite books
  'users'                   // User profiles
];

async function migrateCollection(collectionName) {
  console.log(`\n📦 Migrating collection: ${collectionName}`);
  
  try {
    const snapshot = await oldDb.collection(collectionName).get();
    console.log(`   Found ${snapshot.size} documents`);
    
    const batch = newDb.batch();
    let count = 0;
    
    for (const doc of snapshot.docs) {
      const newDocRef = newDb.collection(collectionName).doc(doc.id);
      batch.set(newDocRef, doc.data());
      count++;
      
      // Commit batch every 500 documents (Firestore batch limit)
      if (count % 500 === 0) {
        await batch.commit();
        console.log(`   ✓ Migrated ${count} documents...`);
      }
    }
    
    // Commit remaining documents
    if (count % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`   ✅ Successfully migrated ${count} documents from ${collectionName}`);
    
    // Migrate subcollections for users
    if (collectionName === 'users') {
      await migrateUserSubcollections(snapshot.docs);
    }
    
  } catch (error) {
    console.error(`   ❌ Error migrating ${collectionName}:`, error.message);
  }
}

async function migrateUserSubcollections(userDocs) {
  console.log(`\n📦 Migrating user subcollections...`);
  
  for (const userDoc of userDocs) {
    const userId = userDoc.id;
    
    // Migrate reading_progress
    try {
      const progressSnapshot = await oldDb
        .collection('users').doc(userId)
        .collection('reading_progress').get();
      
      if (progressSnapshot.size > 0) {
        const batch = newDb.batch();
        progressSnapshot.docs.forEach(doc => {
          const newDocRef = newDb
            .collection('users').doc(userId)
            .collection('reading_progress').doc(doc.id);
          batch.set(newDocRef, doc.data());
        });
        await batch.commit();
        console.log(`   ✓ Migrated ${progressSnapshot.size} reading progress for user ${userId}`);
      }
    } catch (error) {
      console.log(`   ⚠️  No reading progress for user ${userId}`);
    }
    
    // Migrate achievements
    try {
      const achievementsSnapshot = await oldDb
        .collection('users').doc(userId)
        .collection('achievements').get();
      
      if (achievementsSnapshot.size > 0) {
        const batch = newDb.batch();
        achievementsSnapshot.docs.forEach(doc => {
          const newDocRef = newDb
            .collection('users').doc(userId)
            .collection('achievements').doc(doc.id);
          batch.set(newDocRef, doc.data());
        });
        await batch.commit();
        console.log(`   ✓ Migrated ${achievementsSnapshot.size} achievements for user ${userId}`);
      }
    } catch (error) {
      console.log(`   ⚠️  No achievements for user ${userId}`);
    }
  }
}

async function main() {
  console.log('🚀 Starting Firestore Migration');
  console.log('   From: readme-40267');
  console.log('   To:   readmev2\n');
  
  for (const collection of COLLECTIONS_TO_MIGRATE) {
    await migrateCollection(collection);
  }
  
  console.log('\n✅ Migration complete!\n');
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Migration failed:', error);
  process.exit(1);
});
