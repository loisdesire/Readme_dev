const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey_1.json');

console.log('🔍 Checking service account configuration...\n');
console.log(`Project ID: ${serviceAccount.project_id}`);
console.log(`Client Email: ${serviceAccount.client_email}`);
console.log('');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://readmev2.firebaseio.com`
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

async function checkConnection() {
  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Connected to database with ${usersSnapshot.size} users\n`);
    
    // Check a few users to see which project
    if (usersSnapshot.size > 0) {
      console.log('Sample users:');
      let count = 0;
      for (const doc of usersSnapshot.docs) {
        if (count >= 3) break;
        const data = doc.data();
        console.log(`  - ${data.username || 'Unknown'} (${data.email || 'N/A'})`);
        count++;
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await admin.app().delete();
    process.exit(0);
  }
}

checkConnection();
