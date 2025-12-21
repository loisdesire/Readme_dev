// Script to delete all child accounts for testing
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function deleteAllChildren() {
  try {
    console.log('Deleting all child accounts...');
    
    // Get all child users
    const childrenSnapshot = await db.collection('users')
      .where('accountType', '==', 'child')
      .get();
    
    console.log(`Found ${childrenSnapshot.size} children to delete`);
    
    for (const doc of childrenSnapshot.docs) {
      const childData = doc.data();
      const childUid = doc.id;
      
      console.log(`Deleting child: ${childData.username} (${childUid})`);
      
      // Delete from Firestore
      await doc.ref.delete();
      
      // Try to delete from Firebase Auth
      try {
        await auth.deleteUser(childUid);
        console.log(`  ✅ Deleted from Auth`);
      } catch (e) {
        console.log(`  ⚠️  Auth delete failed (might not exist): ${e.message}`);
      }
    }
    
    // Remove children arrays from all parent accounts
    const parentsSnapshot = await db.collection('users')
      .where('accountType', '==', 'parent')
      .get();
    
    console.log(`\nCleaning up ${parentsSnapshot.size} parent accounts...`);
    
    for (const doc of parentsSnapshot.docs) {
      await doc.ref.update({ children: [] });
      console.log(`  ✅ Cleaned ${doc.data().username}`);
    }
    
    console.log('\n✅ All children deleted successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

deleteAllChildren();
