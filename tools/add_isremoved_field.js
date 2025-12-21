// Script to add isRemoved field to all existing users
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addIsRemovedField() {
  try {
    console.log('Starting migration: Adding isRemoved field to all users...');
    
    const usersSnapshot = await db.collection('users').get();
    
    console.log(`Found ${usersSnapshot.size} users to update`);
    
    let updated = 0;
    const batch = db.batch();
    
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      
      // Only add if field doesn't exist
      if (data.isRemoved === undefined) {
        batch.update(doc.ref, {
          isRemoved: false
        });
        updated++;
      }
    });
    
    if (updated > 0) {
      await batch.commit();
      console.log(`✅ Successfully added isRemoved field to ${updated} users`);
    } else {
      console.log('✅ All users already have isRemoved field');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addIsRemovedField();
