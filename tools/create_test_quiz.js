// Quick script to manually create a quiz for testing
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

const bookId = '5WIIxGpXmSLc86AneD94';

const testQuiz = {
  bookId: bookId,
  bookTitle: 'Test Book',
  questions: [
    {
      question: 'What is the main character\'s name?',
      options: ['Alice', 'Bob', 'Charlie', 'Diana'],
      correctAnswer: 0
    },
    {
      question: 'Where does the story take place?',
      options: ['City', 'Forest', 'Beach', 'Mountain'],
      correctAnswer: 1
    },
    {
      question: 'What did the character learn?',
      options: ['Kindness', 'Bravery', 'Honesty', 'Patience'],
      correctAnswer: 0
    },
    {
      question: 'Who helped the main character?',
      options: ['A friend', 'A teacher', 'A parent', 'A stranger'],
      correctAnswer: 0
    },
    {
      question: 'How does the story end?',
      options: ['Happily', 'Sadly', 'Mysteriously', 'Suddenly'],
      correctAnswer: 0
    }
  ],
  createdAt: admin.firestore.Timestamp.now(),
  generatedBy: 'manual'
};

async function createQuiz() {
  try {
    console.log('Creating quiz for book:', bookId);
    await db.collection('book_quizzes').doc(bookId).set(testQuiz);
    console.log('✅ Quiz created successfully');
    
    // Verify it was created
    const check = await db.collection('book_quizzes').doc(bookId).get();
    if (check.exists) {
      console.log('✅ Verified: Quiz exists in Firestore');
      console.log('Questions count:', check.data().questions.length);
    } else {
      console.log('❌ ERROR: Quiz not found after creation!');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating quiz:', error);
    process.exit(1);
  }
}

createQuiz();
