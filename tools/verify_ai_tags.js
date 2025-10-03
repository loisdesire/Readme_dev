// verify_ai_tags.js
// Script to verify what fields were actually added by AI tagging

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('./serviceAccountKey.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267',
    storageBucket: 'readme-40267.firebasestorage.app'
  });
  
  console.log('✅ Firebase Admin SDK initialized successfully\n');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:', error);
  process.exit(1);
}

const db = admin.firestore();

async function verifyTags() {
  try {
    console.log('📊 Checking books in database...\n');
    
    const snapshot = await db.collection('books').limit(5).get();
    
    if (snapshot.empty) {
      console.log('No books found in database');
      return;
    }
    
    console.log(`Found ${snapshot.size} books. Showing details:\n`);
    
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`Book ${index + 1}: ${data.title}`);
      console.log(`  ID: ${doc.id}`);
      console.log(`  Has 'tags' field: ${data.tags !== undefined}`);
      console.log(`  Has 'traits' field: ${data.traits !== undefined}`);
      console.log(`  Has 'needsTagging' field: ${data.needsTagging !== undefined}`);
      
      if (data.tags) {
        console.log(`  Tags value: ${JSON.stringify(data.tags)}`);
      }
      if (data.traits) {
        console.log(`  Traits value: ${JSON.stringify(data.traits)}`);
      }
      if (data.needsTagging !== undefined) {
        console.log(`  Needs tagging: ${data.needsTagging}`);
      }
      console.log(`  Age Rating: ${data.ageRating || 'not set'}`);
      console.log('');
    });
    
    // Check for books that were tagged
    const taggedSnapshot = await db.collection('books')
      .where('needsTagging', '==', false)
      .limit(3)
      .get();
    
    if (!taggedSnapshot.empty) {
      console.log('\n📝 Books that have been tagged:\n');
      taggedSnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`Tagged Book ${index + 1}: ${data.title}`);
        console.log(`  Tags: ${JSON.stringify(data.tags || 'none')}`);
        console.log(`  Traits: ${JSON.stringify(data.traits || 'none')}`);
        console.log(`  Age Rating: ${data.ageRating || 'not set'}`);
        console.log('');
      });
    }
    
    // Check for books still needing tagging
    const needsTaggingSnapshot = await db.collection('books')
      .where('needsTagging', '==', true)
      .limit(3)
      .get();
    
    if (!needsTaggingSnapshot.empty) {
      console.log('\n⏳ Books still needing tagging:\n');
      needsTaggingSnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`Untagged Book ${index + 1}: ${data.title}`);
        console.log(`  Has PDF: ${data.pdfUrl ? 'Yes' : 'No'}`);
        console.log('');
      });
    } else {
      console.log('\n✅ All books have been tagged!');
    }
    
  } catch (error) {
    console.error('❌ Error verifying tags:', error);
  }
}

// Run the verification
verifyTags()
  .then(() => {
    console.log('\n✅ Verification complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
