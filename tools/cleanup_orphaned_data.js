/**
 * Cleanup Orphaned User Data Script
 * 
 * This script finds and deletes documents in collections that reference
 * deleted users (userIds that no longer exist in the users collection).
 * 
 * This includes:
 * - reading_progress for deleted users
 * - favorites for deleted users
 * - reading_sessions for deleted users
 * - user_achievements for deleted users
 * - notifications for deleted users
 * - etc.
 * 
 * Usage: node cleanup_orphaned_data.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Collections that have userId fields to check
const COLLECTIONS_WITH_USERID = [
  { name: 'reading_progress', userField: 'userId' },
  { name: 'favorites', userField: 'userId' },
  { name: 'reading_sessions', userField: 'userId' },
  { name: 'user_achievements', userField: 'userId' },
  { name: 'notifications', userField: 'userId' },
  { name: 'reading_reminders', userField: null }, // Uses doc ID = userId
  { name: 'notification_preferences', userField: null }, // Uses doc ID = userId
  { name: 'content_filters', userField: null }, // Uses doc ID = userId
  { name: 'daily_reading_time', userField: 'userId' },
  { name: 'content_reports', userField: 'userId' },
  { name: 'parental_controls', userField: null }, // Uses doc ID = userId
  { name: 'quiz_results', userField: 'userId' },
  { name: 'quiz_analytics', userField: 'userId' },
  { name: 'book_interactions', userField: 'userId' },
  { name: 'app_sessions', userField: 'userId' },
];

async function cleanupOrphanedData() {
  try {
    console.log('🔍 Finding orphaned user data...\n');
    console.log('═'.repeat(70));

    // Step 1: Get all valid user IDs
    console.log('\n📋 Step 1: Loading all valid user IDs...');
    const usersSnapshot = await db.collection('users').get();
    const validUserIds = new Set();
    
    usersSnapshot.forEach(doc => {
      validUserIds.add(doc.id);
    });

    console.log(`   ✅ Found ${validUserIds.size} valid users\n`);

    // Step 2: Check each collection for orphaned data
    console.log('📋 Step 2: Scanning collections for orphaned data...\n');

    let totalOrphaned = 0;
    const orphanedByCollection = {};

    for (const collection of COLLECTIONS_WITH_USERID) {
      try {
        const collectionRef = db.collection(collection.name);
        const snapshot = await collectionRef.get();

        if (snapshot.empty) {
          console.log(`   ⚪ ${collection.name.padEnd(30)} (empty collection)`);
          continue;
        }

        const orphanedDocs = [];

        for (const doc of snapshot.docs) {
          const data = doc.data();
          let userId;

          if (collection.userField === null) {
            // Collection uses document ID as userId
            userId = doc.id;
            // Check if it contains underscore (like daily_reading_time: userId_date)
            if (userId.includes('_')) {
              userId = userId.split('_')[0];
            }
          } else {
            // Collection has a userId field
            userId = data[collection.userField];
          }

          if (userId && !validUserIds.has(userId)) {
            orphanedDocs.push(doc.id);
          }
        }

        if (orphanedDocs.length > 0) {
          orphanedByCollection[collection.name] = orphanedDocs;
          totalOrphaned += orphanedDocs.length;
          console.log(`   🗑️  ${collection.name.padEnd(30)} ${orphanedDocs.length.toString().padStart(6)} orphaned docs`);
        } else {
          console.log(`   ✅ ${collection.name.padEnd(30)} ${snapshot.size.toString().padStart(6)} docs (all valid)`);
        }

      } catch (err) {
        console.log(`   ⚠️  ${collection.name.padEnd(30)} (collection doesn't exist)`);
      }
    }

    console.log('\n' + '═'.repeat(70));

    if (totalOrphaned === 0) {
      console.log('\n🎉 No orphaned data found! Database is clean.\n');
      process.exit();
    }

    console.log(`\n📊 Summary:`);
    console.log(`   Total orphaned documents: ${totalOrphaned}`);
    console.log(`   Collections affected: ${Object.keys(orphanedByCollection).length}\n`);

    console.log('⚠️  WARNING: This will permanently delete orphaned data!');
    console.log('⏳ Starting deletion in 5 seconds... (Press Ctrl+C to cancel)\n');

    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('🗑️  Starting cleanup...\n');

    let deletedCount = 0;

    for (const [collectionName, docIds] of Object.entries(orphanedByCollection)) {
      console.log(`📁 Cleaning ${collectionName}...`);
      
      const collectionRef = db.collection(collectionName);
      
      // Delete in batches of 500 (Firestore limit)
      for (let i = 0; i < docIds.length; i += 500) {
        const batch = db.batch();
        const batchDocIds = docIds.slice(i, i + 500);
        
        batchDocIds.forEach(docId => {
          batch.delete(collectionRef.doc(docId));
        });
        
        await batch.commit();
        deletedCount += batchDocIds.length;
        console.log(`   ✅ Deleted ${batchDocIds.length} docs (${deletedCount}/${totalOrphaned})`);
      }
    }

    console.log('\n' + '═'.repeat(70));
    console.log(`\n🎉 Cleanup complete!`);
    console.log(`   ✅ Deleted ${deletedCount} orphaned documents`);
    console.log(`   ✅ Cleaned ${Object.keys(orphanedByCollection).length} collections`);
    console.log(`   ✅ ${validUserIds.size} valid users remain\n`);

  } catch (error) {
    console.error('❌ Fatal error:', error);
  } finally {
    process.exit();
  }
}

cleanupOrphanedData();
