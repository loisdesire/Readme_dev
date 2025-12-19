/**
 * Cleanup Unused Collections Script
 * 
 * This script safely deletes unused/empty collections from Firestore.
 * Based on code analysis, only specific collections are kept.
 * 
 * Usage: node cleanup_unused_collections.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Collections that are ACTIVELY USED in the codebase
const COLLECTIONS_IN_USE = [
  'users',                    // Core - user profiles
  'books',                    // Core - book catalog
  'reading_progress',         // Core - user reading progress
  'favorites',               // Core - user favorites
  'reading_sessions',        // Used in analytics & firestore_helpers
  'user_achievements',       // Used in achievement system
  'notifications',           // Used in notification_service
  'reading_reminders',       // Used in notification_service  
  'notification_preferences', // Used in notification_service
  'content_filters',         // Used in content_filter_service
  'daily_reading_time',      // Used in content_filter_service
  'content_reports',         // Used in content_filter_service (reporting)
  'parental_controls',       // Used in content_filter_service
  'quiz_questions',          // Used in api_service (quiz system)
  'quiz_results',            // Used in api_service
  'quiz_analytics',          // Used in analytics_service
  'book_interactions',       // Used in analytics_service
  'app_sessions',            // Used in analytics_service
];

async function cleanupUnusedCollections() {
  try {
    console.log('🔍 Analyzing Firestore collections...\n');
    console.log('═'.repeat(70));

    // Get all collections
    const allCollections = await db.listCollections();
    
    const toKeep = [];
    const toDelete = [];

    for (const collection of allCollections) {
      const name = collection.id;
      const count = await collection.count().get();
      const totalDocs = count.data().count;

      if (COLLECTIONS_IN_USE.includes(name)) {
        toKeep.push({ name, count: totalDocs });
      } else {
        toDelete.push({ name, count: totalDocs });
      }
    }

    console.log('\n✅ COLLECTIONS TO KEEP (Used in code):');
    toKeep.forEach(c => {
      console.log(`   ${c.name.padEnd(30)} ${c.count.toString().padStart(6)} docs`);
    });

    if (toDelete.length === 0) {
      console.log('\n🎉 No unused collections found! Database is clean.\n');
      process.exit();
    }

    console.log('\n🗑️  COLLECTIONS TO DELETE (Not used in code):');
    toDelete.forEach(c => {
      console.log(`   ${c.name.padEnd(30)} ${c.count.toString().padStart(6)} docs`);
    });

    const totalDocsToDelete = toDelete.reduce((sum, c) => sum + c.count, 0);

    console.log('\n' + '═'.repeat(70));
    console.log(`\n⚠️  WARNING: This will delete ${toDelete.length} collection(s) with ${totalDocsToDelete} total documents!`);
    console.log('⏳ Starting deletion in 5 seconds... (Press Ctrl+C to cancel)\n');

    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('🗑️  Starting cleanup...\n');

    for (let i = 0; i < toDelete.length; i++) {
      const collection = toDelete[i];
      console.log(`[${i + 1}/${toDelete.length}] Deleting collection: ${collection.name}`);
      
      try {
        await deleteCollection(db, collection.name, 100);
        console.log(`   ✅ Deleted ${collection.name} (${collection.count} docs)\n`);
      } catch (err) {
        console.error(`   ❌ Error deleting ${collection.name}:`, err.message);
      }
    }

    console.log('═'.repeat(70));
    console.log(`\n🎉 Cleanup complete!`);
    console.log(`   Deleted: ${toDelete.length} collection(s)`);
    console.log(`   Kept: ${toKeep.length} collection(s)\n`);

  } catch (error) {
    console.error('❌ Fatal error:', error);
  } finally {
    process.exit();
  }
}

// Helper function to delete a collection in batches
async function deleteCollection(db, collectionPath, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    // All documents deleted
    resolve();
    return;
  }

  // Delete documents in a batch
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  // Recurse on the next process tick to avoid blocking
  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}

cleanupUnusedCollections();
