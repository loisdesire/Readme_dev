/**
 * Permanently Delete User Script
 * 
 * This script PERMANENTLY deletes a user and all their associated data from Firestore and Firebase Auth.
 * WARNING: This action cannot be undone!
 * 
 * Usage: node delete_user_permanently.js <email_or_uid>
 * Example: node delete_user_permanently.js test@example.com
 *          node delete_user_permanently.js abc123uid456
 *          node delete_user_permanently.js test1@example.com,test2@example.com,test3@example.com
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function deleteUserPermanently(identifier) {
  try {
    console.log(`🔍 Searching for user: ${identifier}\n`);

    let userId = null;
    let userEmail = null;

    // Try to find user by email or UID
    if (identifier.includes('@')) {
      // It's an email
      try {
        const userRecord = await auth.getUserByEmail(identifier);
        userId = userRecord.uid;
        userEmail = userRecord.email;
      } catch (err) {
        console.log('⚠️  User not found in Firebase Auth, checking Firestore...');
      }
    } else {
      // It's a UID
      userId = identifier;
      try {
        const userRecord = await auth.getUser(userId);
        userEmail = userRecord.email;
      } catch (err) {
        console.log('⚠️  User not found in Firebase Auth, checking Firestore...');
      }
    }

    // If not found in Auth, try Firestore
    if (!userId) {
      const usersSnapshot = await db.collection('users')
        .where('email', '==', identifier)
        .limit(1)
        .get();
      
      if (usersSnapshot.empty) {
        console.error('❌ User not found in Auth or Firestore!');
        process.exit(1);
      }
      
      userId = usersSnapshot.docs[0].id;
      userEmail = usersSnapshot.docs[0].data().email;
    }

    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : null;

    console.log('👤 User found:');
    console.log(`   UID: ${userId}`);
    console.log(`   Email: ${userEmail || 'N/A'}`);
    console.log(`   Username: ${userData?.username || 'N/A'}`);
    console.log(`   Account Type: ${userData?.accountType || 'N/A'}\n`);

    // Confirm deletion
    console.log('⚠️  WARNING: This will PERMANENTLY delete:');
    console.log('   ✗ User authentication account');
    console.log('   ✗ User profile document');
    console.log('   ✗ All reading progress records');
    console.log('   ✗ All achievements');
    console.log('   ✗ All favorites');
    console.log('   ✗ Parent-child relationships\n');

    // Wait 3 seconds to allow user to cancel (Ctrl+C)
    console.log('⏳ Starting deletion in 3 seconds... (Press Ctrl+C to cancel)');
    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('\n🗑️  Starting permanent deletion...\n');

    let deletedCount = 0;

    // 1. Delete reading progress
    const progressSnapshot = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of progressSnapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }
    console.log(`✅ Deleted ${progressSnapshot.size} reading progress records`);

    // 2. Delete favorites
    const favoritesSnapshot = await db.collection('favorites')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of favoritesSnapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }
    console.log(`✅ Deleted ${favoritesSnapshot.size} favorite records`);

    // 3. Remove from parent's children array (if child account)
    if (userData?.accountType === 'child' && userData?.parentIds) {
      let removedCount = 0;
      for (const parentId of userData.parentIds) {
        try {
          const parentDoc = await db.collection('users').doc(parentId).get();
          if (parentDoc.exists) {
            await db.collection('users').doc(parentId).update({
              children: admin.firestore.FieldValue.arrayRemove(userId)
            });
            removedCount++;
          }
        } catch (err) {
          // Parent may not exist, skip
        }
      }
      if (removedCount > 0) {
        console.log(`✅ Removed from ${removedCount} parent account(s)`);
      }
    }

    // 4. Delete children relationships (if parent account)
    if (userData?.accountType === 'parent' && userData?.children) {
      let unlinkedCount = 0;
      for (const childId of userData.children) {
        try {
          const childDoc = await db.collection('users').doc(childId).get();
          if (childDoc.exists) {
            await db.collection('users').doc(childId).update({
              parentIds: admin.firestore.FieldValue.arrayRemove(userId)
            });
            unlinkedCount++;
          }
        } catch (err) {
          // Child may not exist, skip
        }
      }
      if (unlinkedCount > 0) {
        console.log(`✅ Unlinked ${unlinkedCount} child account(s)`);
      }
    }

    // 5. Delete user document from Firestore
    await db.collection('users').doc(userId).delete();
    console.log('✅ Deleted user profile document');

    // 6. Delete from Firebase Authentication
    try {
      await auth.deleteUser(userId);
      console.log('✅ Deleted user from Firebase Auth');
    } catch (err) {
      console.log('⚠️  User not found in Auth (may have been deleted already)');
    }

    console.log(`\n🎉 User permanently deleted!`);
    console.log(`   Total records deleted: ${deletedCount + 1}`);

  } catch (error) {
    console.error('❌ Error during deletion:', error);
  } finally {
    process.exit();
  }
}

// Get identifiers from command line (can be comma-separated)
const identifiersInput = process.argv[2];

if (!identifiersInput) {
  console.error('❌ Usage: node delete_user_permanently.js <email_or_uid>');
  console.error('   Example: node delete_user_permanently.js test@example.com');
  console.error('   Multiple: node delete_user_permanently.js test1@example.com,test2@example.com');
  process.exit(1);
}

// Split by comma and trim whitespace
const identifiers = identifiersInput.split(',').map(id => id.trim()).filter(id => id);

if (identifiers.length === 0) {
  console.error('❌ No valid identifiers provided');
  process.exit(1);
}

// Process each user sequentially
(async () => {
  console.log(`\n📋 Found ${identifiers.length} user(s) to delete\n`);
  console.log('═'.repeat(60));
  
  for (let i = 0; i < identifiers.length; i++) {
    console.log(`\n[${i + 1}/${identifiers.length}] Processing: ${identifiers[i]}`);
    console.log('─'.repeat(60));
    await deleteUserPermanently(identifiers[i]);
    
    if (i < identifiers.length - 1) {
      console.log('\n⏳ Waiting 1 second before next deletion...');
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
  
  console.log('\n' + '═'.repeat(60));
  console.log(`\n✨ Batch deletion complete! Deleted ${identifiers.length} user(s)\n`);
})();
