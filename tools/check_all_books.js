// check_all_books.js
const admin = require('firebase-admin');

try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267',
  });
  console.log('✅ Firebase connected');
} catch (error) {
  console.error('❌ Firebase connection failed:', error);
  process.exit(1);
}

const db = admin.firestore();

async function checkAllBooks() {
  try {
    console.log('🔍 Checking ALL books for tagging status...\n');
    
    const snapshot = await db.collection('books').get();
    console.log(`Found ${snapshot.size} total books\n`);
    
    let needsTagging = 0;
    let alreadyTagged = 0;
    let recentBooks = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const created = data.createdAt?.toDate?.() || new Date(0);
      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      
      if (data.needsTagging === true) {
        needsTagging++;
        console.log(`❌ NEEDS TAGGING: ${data.title} (ID: ${doc.id})`);
      } else if (data.traits && data.tags) {
        alreadyTagged++;
      }
      
      if (created > weekAgo) {
        recentBooks.push({
          title: data.title,
          id: doc.id,
          created: created,
          needsTagging: data.needsTagging,
          hasTraits: !!data.traits,
          hasTags: !!data.tags
        });
      }
    });
    
    console.log(`\n📊 Summary:`);
    console.log(`   Books needing tagging: ${needsTagging}`);
    console.log(`   Books already tagged: ${alreadyTagged}`);
    
    console.log(`\n📅 Recent books (last 7 days):`);
    if (recentBooks.length === 0) {
      console.log('   No books created in the last 7 days');
    } else {
      recentBooks.forEach(book => {
        console.log(`   📚 ${book.title}`);
        console.log(`      Created: ${book.created.toLocaleDateString()}`);
        console.log(`      Needs tagging: ${book.needsTagging}`);
        console.log(`      Has traits: ${book.hasTraits}`);
        console.log(`      Has tags: ${book.hasTags}`);
        console.log();
      });
    }
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkAllBooks();