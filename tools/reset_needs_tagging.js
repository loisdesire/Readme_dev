// reset_needs_tagging.js
// Sets needsTagging: true for all books in Firestore

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
});

const db = admin.firestore();

async function resetNeedsTagging() {
  console.log('Starting reset of needsTagging for all books...');
  const booksRef = db.collection('books');
  const snapshot = await booksRef.get();

  if (snapshot.empty) {
    console.log('No books found in Firestore.');
    return;
  }

  console.log(`Found ${snapshot.size} books. Beginning update...`);
  let updated = 0;
  for (const doc of snapshot.docs) {
    const title = doc.data().title || '[Untitled]';
    process.stdout.write(`Updating: ${title} ... `);
    await doc.ref.update({ needsTagging: true });
    updated++;
    console.log('done');
  }
  console.log(`All done! ${updated} books reset to needsTagging: true.`);
}

console.log('Connecting to Firestore...');
resetNeedsTagging()
  .then(() => console.log('Reset process complete.'))
  .catch((err) => {
    console.error('Error during reset:', err);
  });
