// delete_non_pdf_books.js
// Delete all books that don't have PDF files

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require('./serviceAccountKey.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267'
  });
  
  console.log('✅ Firebase Admin SDK initialized successfully\n');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:', error);
  process.exit(1);
}

const db = admin.firestore();

async function deleteNonPdfBooks() {
  try {
    console.log('🔍 Finding books without PDFs...\n');
    
    // Get all books
    const snapshot = await db.collection('books').get();
    console.log(`📚 Found ${snapshot.docs.length} books total\n`);
    
    const booksToDelete = [];
    const booksToKeep = [];
    
    // Categorize books
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const bookTitle = data.title || 'Unknown';
      
      if (!data.pdfUrl || data.pdfUrl.trim() === '') {
        booksToDelete.push({
          id: doc.id,
          title: bookTitle,
          author: data.author || 'Unknown'
        });
      } else {
        booksToKeep.push({
          id: doc.id,
          title: bookTitle
        });
      }
    }
    
    console.log(`📊 Summary:`);
    console.log(`   📄 Books with PDFs (will keep): ${booksToKeep.length}`);
    console.log(`   ❌ Books without PDFs (will delete): ${booksToDelete.length}`);
    console.log(`   📚 Total: ${snapshot.docs.length}\n`);
    
    if (booksToDelete.length === 0) {
      console.log('✅ No books to delete. All books have PDFs!');
      process.exit(0);
    }
    
    // Show books that will be deleted
    console.log('📋 Books that will be DELETED:\n');
    booksToDelete.forEach((book, index) => {
      console.log(`   ${index + 1}. "${book.title}" by ${book.author}`);
    });
    
    console.log(`\n${'='.repeat(60)}`);
    console.log('⚠️  WARNING: This action cannot be undone!');
    console.log(`   ${booksToDelete.length} books will be permanently deleted.`);
    console.log(`${'='.repeat(60)}\n`);
    
    // Ask for confirmation
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    readline.question('Type "DELETE" to confirm deletion: ', async (answer) => {
      if (answer.trim() === 'DELETE') {
        console.log('\n🗑️  Deleting books...\n');
        
        let deletedCount = 0;
        let failedCount = 0;
        
        for (const book of booksToDelete) {
          try {
            await db.collection('books').doc(book.id).delete();
            console.log(`   ✅ Deleted: "${book.title}"`);
            deletedCount++;
          } catch (error) {
            console.error(`   ❌ Failed to delete "${book.title}": ${error.message}`);
            failedCount++;
          }
        }
        
        console.log(`\n${'='.repeat(60)}`);
        console.log(`📊 Deletion Summary:`);
        console.log(`   ✅ Successfully deleted: ${deletedCount} books`);
        console.log(`   ❌ Failed to delete: ${failedCount} books`);
        console.log(`   📄 Remaining books (with PDFs): ${booksToKeep.length}`);
        console.log(`${'='.repeat(60)}\n`);
        console.log('✨ Deletion complete!');
        
        readline.close();
        process.exit(0);
      } else {
        console.log('\n❌ Deletion cancelled. No books were deleted.');
        readline.close();
        process.exit(0);
      }
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Run the script
deleteNonPdfBooks();
