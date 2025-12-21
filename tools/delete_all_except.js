/**
 * Delete All Users Except Specified Script
 * 
 * This script PERMANENTLY deletes ALL users EXCEPT the ones you specify.
 * WARNING: This action cannot be undone!
 * 
 * Usage: node delete_all_except.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// USERS TO KEEP (whitelist)
const KEEP_USERNAMES = [
  'admin1',
  'mede',
  'medemede',
  'bailu',
  'tobi',
  'gracewumi1',
  'fajuyiayodele',
  'fajuyimatilda',
  'osabuteyprecious187'
];

async function deleteUserPermanently(userId, username, userEmail) {
  try {
    let deletedCount = 0;

    // 1. Delete reading progress
    const progressSnapshot = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of progressSnapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    // 2. Delete favorites
    const favoritesSnapshot = await db.collection('favorites')
      .where('userId', '==', userId)
      .get();
    
    for (const doc of favoritesSnapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    // 3. Get user data for relationships
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : null;

    // 4. Remove from parent's children array (if child account)
    if (userData?.accountType === 'child' && userData?.parentIds) {
      for (const parentId of userData.parentIds) {
        try {
          const parentDoc = await db.collection('users').doc(parentId).get();
          if (parentDoc.exists) {
            await db.collection('users').doc(parentId).update({
              children: admin.firestore.FieldValue.arrayRemove(userId)
            });
          }
        } catch (err) {
          // Parent may not exist, skip silently
        }
      }
    }

    // 5. Unlink children (if parent account)
    if (userData?.accountType === 'parent' && userData?.children) {
      for (const childId of userData.children) {
        try {
          const childDoc = await db.collection('users').doc(childId).get();
          if (childDoc.exists) {
            await db.collection('users').doc(childId).update({
              parentIds: admin.firestore.FieldValue.arrayRemove(userId)
            });
          }
        } catch (err) {
          // Child may not exist, skip silently
        }
      }
    }

    // 6. Delete user document from Firestore
    await db.collection('users').doc(userId).delete();

    // 7. Delete from Firebase Authentication
    try {
      await auth.deleteUser(userId);
    } catch (err) {
      // User may not exist in Auth
    }

    console.log(`   ✅ Deleted: ${username} (${userEmail}) - ${deletedCount + 1} records`);

  } catch (error) {
    console.error(`   ❌ Error deleting ${username}:`, error.message);
  }
}

async function deleteAllExcept() {
  try {
    console.log('🔍 Fetching all users...\n');

    const usersSnapshot = await db.collection('users').get();
    const allUsers = [];
    const keepUsers = [];
    const deleteUsers = [];

    // Categorize users
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const username = (data.username || '').toLowerCase();
      const user = {
        id: doc.id,
        username: data.username || 'Anonymous',
        email: data.email || 'N/A',
        accountType: data.accountType || 'N/A'
      };

      if (KEEP_USERNAMES.map(u => u.toLowerCase()).includes(username)) {
        keepUsers.push(user);
      } else {
        deleteUsers.push(user);
      }
    }

    console.log('📊 User Summary:');
    console.log(`   Total users: ${usersSnapshot.size}`);
    console.log(`   Users to KEEP: ${keepUsers.length}`);
    console.log(`   Users to DELETE: ${deleteUsers.length}\n`);

    console.log('✅ Users that will be KEPT:');
    keepUsers.forEach(u => {
      console.log(`   ✓ ${u.username} (${u.email}) - ${u.accountType}`);
    });

    console.log('\n❌ Users that will be DELETED:');
    deleteUsers.forEach(u => {
      console.log(`   ✗ ${u.username} (${u.email}) - ${u.accountType}`);
    });

    console.log('\n⚠️  WARNING: This will PERMANENTLY delete ' + deleteUsers.length + ' users!');
    console.log('⏳ Starting deletion in 5 seconds... (Press Ctrl+C to cancel)\n');
    
    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('🗑️  Starting deletion...\n');
    console.log('═'.repeat(60));

    for (let i = 0; i < deleteUsers.length; i++) {
      const user = deleteUsers[i];
      console.log(`\n[${i + 1}/${deleteUsers.length}] Deleting: ${user.username}`);
      await deleteUserPermanently(user.id, user.username, user.email);
      
      // Small delay between deletions
      if (i < deleteUsers.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }

    console.log('\n' + '═'.repeat(60));
    console.log(`\n🎉 Deletion complete!`);
    console.log(`   ✅ Kept: ${keepUsers.length} users`);
    console.log(`   ✅ Deleted: ${deleteUsers.length} users\n`);

  } catch (error) {
    console.error('❌ Fatal error:', error);
  } finally {
    process.exit();
  }
}

deleteAllExcept();
