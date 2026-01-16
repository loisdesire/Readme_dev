// Get all books and their quiz status
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readmev2'
});

const db = admin.firestore();

async function getBooksAndQuizStatus() {
  try {
    console.log('Fetching all books...\n');
    
    // Get all books
    const booksSnap = await db.collection('books').get();
    
    if (booksSnap.empty) {
      console.log('No books found');
      process.exit(0);
    }
    
    console.log(`Found ${booksSnap.size} books\n`);
    console.log('=' .repeat(80));
    
    let booksWithQuiz = 0;
    let booksWithoutQuiz = 0;
    const booksNeedingQuiz = [];
    
    for (const doc of booksSnap.docs) {
      const bookData = doc.data();
      const bookId = doc.id;
      
      // Check if quiz exists
      const quizDoc = await db.collection('book_quizzes').doc(bookId).get();
      const hasQuiz = quizDoc.exists;
      
      const status = hasQuiz ? '✅ HAS QUIZ' : '❌ NO QUIZ';
      
      console.log(`\n${status}`);
      console.log(`ID: ${bookId}`);
      console.log(`Title: ${bookData.title || 'N/A'}`);
      console.log(`Author: ${bookData.author || 'N/A'}`);
      console.log(`Description: ${bookData.description ? bookData.description.substring(0, 80) + '...' : 'N/A'}`);
      
      if (hasQuiz) {
        booksWithQuiz++;
      } else {
        booksWithoutQuiz++;
        booksNeedingQuiz.push({
          id: bookId,
          title: bookData.title,
          author: bookData.author,
          description: bookData.description
        });
      }
    }
    
    console.log('\n' + '=' .repeat(80));
    console.log(`\nSummary:`);
    console.log(`✅ Books with quizzes: ${booksWithQuiz}`);
    console.log(`❌ Books needing quizzes: ${booksWithoutQuiz}`);
    
    if (booksNeedingQuiz.length > 0) {
      console.log('\nBooks that need quizzes:');
      booksNeedingQuiz.forEach(book => {
        console.log(`  - ${book.title} by ${book.author} (ID: ${book.id})`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

getBooksAndQuizStatus();
