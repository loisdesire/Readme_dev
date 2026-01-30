const admin = require('firebase-admin');

// Initialize Firebase Admin for readmev2
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://readmev2.firebaseio.com`
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

// USER IDs TO KEEP (edit this list with the users you want to keep)
const USERS_TO_KEEP = [
  'WCcrHcrEKwf5Q8Lv6Dv8O18c2dz2', // lois
  'boCN9qGjCJeySyoT2QdV279f9ix2', // kobbie
  // Add more user IDs here that you want to keep
];

async function deleteUnwantedUsers() {
  try {
    console.log('🗑️  Starting cleanup of unwanted users...\n');
    console.log(`✅ Users to KEEP: ${USERS_TO_KEEP.length}`);
    USERS_TO_KEEP.forEach(id => {
      console.log(`   - ${id}`);
    });
    console.log('');
    
    const usersSnapshot = await db.collection('users').get();
    
    console.log(`📊 Total users in database: ${usersSnapshot.size}\n`);
    
    const batch = db.batch();
    let deleteCount = 0;
    let keepCount = 0;
    
    console.log('Processing users:\n');
    
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      
      if (USERS_TO_KEEP.includes(doc.id)) {
        console.log(`✅ KEEPING: ${data.username || doc.id}`);
        keepCount++;
      } else {
        console.log(`❌ DELETING: ${data.username || doc.id} (${doc.id})`);
        batch.delete(doc.ref);
        deleteCount++;
      }
    });
    
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📊 Summary:`);
    console.log(`   ✅ Keeping: ${keepCount} users`);
    console.log(`   ❌ Deleting: ${deleteCount} users`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    if (deleteCount > 0) {
      const readline = require('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      rl.question('⚠️  Type "DELETE" to confirm deletion: ', async (answer) => {
        rl.close();
        
        if (answer === 'DELETE') {
          await batch.commit();
          console.log(`\n✅ Successfully deleted ${deleteCount} users!\n`);
        } else {
          console.log('\n❌ Deletion cancelled.\n');
        }
        
        await admin.app().delete();
        process.exit(0);
      });
    } else {
      console.log('No users to delete.\n');
      await admin.app().delete();
      process.exit(0);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    await admin.app().delete();
    process.exit(1);
  }
}

deleteUnwantedUsers();
