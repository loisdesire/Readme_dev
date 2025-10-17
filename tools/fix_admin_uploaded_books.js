// fix_admin_uploaded_books.js
// Fixes books uploaded through admin portal that might be missing proper tagging flags

const admin = require('firebase-admin');

try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267',
  });
  console.log('✅ Firebase connected');
} catch (error) {
  console.log('Firebase already initialized');
}

const db = admin.firestore();

async function fixAdminUploadedBooks() {
  try {
    console.log('🔧 Checking for books that need tagging flag fixes...\n');
    
    // Find books that don't have proper traits/tags or needsTagging field
    const allBooksSnapshot = await db.collection('books').get();
    
    console.log(`📚 Checking ${allBooksSnapshot.size} total books...\n`);
    
    let needsFixing = [];
    let alreadyGood = 0;
    
    allBooksSnapshot.forEach(doc => {
      const data = doc.data();
      const id = doc.id;
      
      // Check if book needs fixing
      const hasEmptyTraits = !data.traits || data.traits.length === 0 || (data.traits.length === 1 && data.traits[0] === "");
      const hasEmptyTags = !data.tags || data.tags.length === 0 || (data.tags.length === 1 && data.tags[0] === "");
      const needsTaggingUndefined = data.needsTagging === undefined;
      const needsTaggingFalseButEmpty = data.needsTagging === false && (hasEmptyTraits || hasEmptyTags);
      
      if (hasEmptyTraits || hasEmptyTags || needsTaggingUndefined || needsTaggingFalseButEmpty) {
        needsFixing.push({
          id,
          title: data.title,
          author: data.author,
          hasEmptyTraits,
          hasEmptyTags,
          needsTaggingUndefined,
          needsTaggingFalseButEmpty,
          pdfUrl: data.pdfUrl,
          createdAt: data.createdAt?.toDate?.() || new Date(0)
        });
      } else {
        alreadyGood++;
      }
    });
    
    console.log(`📊 Results:`);
    console.log(`   ✅ Books properly tagged: ${alreadyGood}`);
    console.log(`   🔧 Books needing fixes: ${needsFixing.length}\n`);
    
    if (needsFixing.length === 0) {
      console.log('🎉 All books are properly configured!');
      return;
    }
    
    console.log('📋 Books that need fixing:');
    needsFixing.forEach((book, index) => {
      console.log(`\n${index + 1}. "${book.title}" by ${book.author}`);
      console.log(`   ID: ${book.id}`);
      console.log(`   Created: ${book.createdAt.toLocaleDateString()}`);
      console.log(`   Issues:`);
      if (book.hasEmptyTraits) console.log(`     - Empty or missing traits`);
      if (book.hasEmptyTags) console.log(`     - Empty or missing tags`);
      if (book.needsTaggingUndefined) console.log(`     - needsTagging field missing`);
      if (book.needsTaggingFalseButEmpty) console.log(`     - needsTagging=false but has empty traits/tags`);
      console.log(`   PDF URL: ${book.pdfUrl ? 'Available' : 'Missing'}`);
    });
    
    console.log(`\n🛠️  Fixing books...`);
    
    let fixed = 0;
    for (const book of needsFixing) {
      try {
        // Set needsTagging to true and clear empty traits/tags
        const updateData = {
          needsTagging: true
        };
        
        // Remove empty traits/tags arrays
        if (book.hasEmptyTraits) {
          updateData.traits = admin.firestore.FieldValue.delete();
        }
        if (book.hasEmptyTags) {
          updateData.tags = admin.firestore.FieldValue.delete();
        }
        
        await db.collection('books').doc(book.id).update(updateData);
        console.log(`   ✅ Fixed: ${book.title}`);
        fixed++;
        
      } catch (error) {
        console.log(`   ❌ Failed to fix ${book.title}: ${error.message}`);
      }
    }
    
    console.log(`\n🎉 Fixed ${fixed} out of ${needsFixing.length} books!`);
    console.log(`\n📝 Next steps:`);
    console.log(`   1. Run: node ai_tagging_fixed.js`);
    console.log(`   2. Books will be properly processed with AI tagging`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

fixAdminUploadedBooks();