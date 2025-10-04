// Quick Firebase test
const admin = require('firebase-admin');

console.log('Testing Firebase with current service account...');

try {
  // Use environment variable for credentials
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'readme-40267'
  });
  
  const db = admin.firestore();
  console.log('✅ Firebase initialized successfully');
  
  // Test a simple query
  db.collection('books').limit(1).get()
    .then(snapshot => {
      console.log('✅ Successfully connected to Firestore!');
      console.log('📊 Found', snapshot.size, 'book(s)');
      if (snapshot.size > 0) {
        const book = snapshot.docs[0].data();
        console.log('📖 Sample book:', book.title);
        console.log('🏷️ Needs tagging:', book.needsTagging);
      }
      process.exit(0);
    })
    .catch(error => {
      console.error('❌ Firestore query failed:', error.code || error.message);
      process.exit(1);
    });
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  process.exit(1);
}