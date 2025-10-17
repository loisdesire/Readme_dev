// check_recent_book.js
const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
});

const db = admin.firestore();

async function checkRecentBook() {
  try {
    const snapshot = await db.collection('books').where('title', '==', 'jkanrg').get();
    
    if (snapshot.empty) {
      console.log('Book "jkanrg" not found');
      return;
    }
    
    const doc = snapshot.docs[0];
    const data = doc.data();
    
    console.log('📚 Book Details:');
    console.log(`   Title: ${data.title}`);
    console.log(`   ID: ${doc.id}`);
    console.log(`   Created: ${data.createdAt?.toDate?.().toLocaleString() || 'Unknown'}`);
    console.log(`   Author: ${data.author || 'Unknown'}`);
    console.log(`   Age Rating: ${data.ageRating || 'Unknown'}`);
    console.log(`   Description: ${data.description?.substring(0, 100) || 'No description'}...`);
    console.log();
    console.log('🏷️ Tagging Status:');
    console.log(`   needsTagging: ${data.needsTagging}`);
    console.log(`   Has traits: ${!!data.traits}`);
    console.log(`   Has tags: ${!!data.tags}`);
    console.log();
    
    if (data.traits) {
      console.log('🎭 Traits:', JSON.stringify(data.traits, null, 2));
    }
    
    if (data.tags) {
      console.log('🏷️ Tags:', JSON.stringify(data.tags, null, 2));
    }
    
    // Check if this book appears in any user's reading data
    console.log('\n📖 Reading Activity:');
    
    // Check reading progress
    const progressSnapshot = await db.collection('reading_progress')
      .where('bookId', '==', doc.id)
      .get();
    console.log(`   Reading progress entries: ${progressSnapshot.size}`);
    
    // Check reading sessions
    const sessionsSnapshot = await db.collection('reading_sessions')
      .where('bookId', '==', doc.id)
      .get();
    console.log(`   Reading session entries: ${sessionsSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkRecentBook();