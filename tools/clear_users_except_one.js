// clear_users_except_one.js
// Deletes all user documents except the one you want to keep

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
});

const db = admin.firestore();

// Set this to the userId you want to keep
const userIdToKeep = 'IcGosa1ANIP5U1eyJDpydpXg6w02';

async function clearUsersExceptOne() {
  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();

  let deleted = 0;
  for (const doc of snapshot.docs) {
    if (doc.id !== userIdToKeep) {
      await doc.ref.delete();
      deleted++;
      console.log(`Deleted user: ${doc.id}`);
    }
  }
  console.log(`Done. ${deleted} user accounts deleted.`);
}

clearUsersExceptOne().catch(console.error);
