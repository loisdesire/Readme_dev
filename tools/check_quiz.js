// Check if quiz exists for a book
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const bookId = '5WIIxGpXmSLc86AneD94';

async function checkQuiz() {
  try {
    const quizDoc = await db.collection('book_quizzes').doc(bookId).get();
    
    if (quizDoc.exists) {
      console.log('✅ Quiz EXISTS for book:', bookId);
      console.log('Quiz data:', JSON.stringify(quizDoc.data(), null, 2));
    } else {
      console.log('❌ NO QUIZ found for book:', bookId);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkQuiz();
