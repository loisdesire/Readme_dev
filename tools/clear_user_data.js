/**
 * Clear user-generated collections from new database
 * Keeps: achievements, content_filters, books, book_quizzes
 * Clears: everything else (user data, reading logs, etc.)
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey_new.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readmev2'
});

const db = admin.firestore();

// Collections to DELETE (user-generated data)
const COLLECTIONS_TO_CLEAR = [
  'admin_settings',
  'book_interactions',
  'daily_reading_time',
  'notifications',
  'quiz_attempts',
  'reading_progress',
  'reading_sessions',
  'user_achievements',
  'user_favorites',
  'users'
];

async function clearCollection(collectionName) {
  console.log(`🗑️  Clearing collection: ${collectionName}`);
  
  try {
    const snapshot = await db.collection(collectionName).get();
    console.log(`   Found ${snapshot.size} documents to delete`);
    
    if (snapshot.size === 0) {
      console.log(`   ⚠️  Collection is already empty`);
      return;
    }
    
    const batch = db.batch();
    let count = 0;
    
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      count++;
      
      // Commit batch every 500 documents (Firestore batch limit)
      if (count % 500 === 0) {
        await batch.commit();
        console.log(`   ✓ Deleted ${count} documents...`);
      }
    }
    
    // Commit remaining documents
    if (count % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`   ✅ Successfully deleted ${count} documents from ${collectionName}\n`);
    
  } catch (error) {
    console.error(`   ❌ Error clearing ${collectionName}:`, error.message);
  }
}

async function main() {
  console.log('🚀 Starting Database Cleanup');
  console.log('   Project: readmev2');
  console.log('\n📌 KEEPING these collections:');
  console.log('   • achievements (achievement definitions)');
  console.log('   • books (book library)');
  console.log('   • book_quizzes (quiz definitions)');
  console.log('   • content_filters (content settings)');
  console.log('\n🗑️  CLEARING these collections:\n');
  
  for (const collection of COLLECTIONS_TO_CLEAR) {
    await clearCollection(collection);
  }
  
  console.log('✅ Database cleanup complete!');
  console.log('\n📊 Summary:');
  console.log('   - System/metadata collections preserved');
  console.log('   - All user-generated data cleared');
  console.log('   - Ready for fresh start with new users!\n');
  
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Cleanup failed:', error);
  process.exit(1);
});
