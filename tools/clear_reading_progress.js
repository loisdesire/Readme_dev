// clear_reading_progress.js
// Deletes all documents in the reading_progress collection

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
});

const db = admin.firestore();

async function clearReadingProgress() {
  const progressRef = db.collection('reading_progress');
  const snapshot = await progressRef.get();

  if (snapshot.empty) {
    console.log('No reading progress found.');
    return;
  }

  let deleted = 0;
  for (const doc of snapshot.docs) {
    await doc.ref.delete();
    deleted++;
    console.log(`Deleted reading progress: ${doc.id}`);
  }
  console.log(`Done. ${deleted} reading progress records deleted.`);
}

clearReadingProgress().catch(console.error);
