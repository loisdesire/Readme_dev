/**
 * List all collections in old database
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267'
});

const db = admin.firestore();

async function listCollections() {
  console.log('🔍 Listing all top-level collections in readme-40267...\n');
  
  const collections = await db.listCollections();
  
  console.log('📁 Found collections:\n');
  for (const collection of collections) {
    const snapshot = await collection.limit(1).get();
    console.log(`   • ${collection.id} (${snapshot.size > 0 ? 'has data' : 'empty'})`);
  }
  
  console.log('\n✅ Done!\n');
  process.exit(0);
}

listCollections();
