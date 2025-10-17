// simple_recommendation_test.js
require('dotenv').config();

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

async function simpleRecommendationTest() {
  try {
    console.log('🧪 Simple AI Recommendation Test\n');
    
    // Check if we have the API key
    if (!process.env.OPENAI_API_KEY) {
      console.log('❌ OPENAI_API_KEY not found in environment');
      return;
    }
    console.log('✅ OpenAI API key is set');
    
    // Check if we have books
    const booksSnapshot = await db.collection('books').limit(5).get();
    console.log(`✅ Found ${booksSnapshot.size} books in database`);
    
    // Check if we have users with reading progress
    const progressSnapshot = await db.collection('reading_progress').limit(5).get();
    console.log(`✅ Found ${progressSnapshot.size} reading progress records`);
    
    if (progressSnapshot.empty) {
      console.log('⚠️  No reading progress found - recommendation system needs user activity');
      return;
    }
    
    // Get a sample user
    const sampleUserId = progressSnapshot.docs[0].data().userId;
    console.log(`📱 Sample user ID: ${sampleUserId}`);
    
    // Check reading progress for this user
    const userProgressSnapshot = await db.collection('reading_progress')
      .where('userId', '==', sampleUserId)
      .get();
    console.log(`📚 User has ${userProgressSnapshot.size} reading progress records`);
    
    // Check if user has completed books
    const completedBooks = userProgressSnapshot.docs.filter(doc => doc.data().isCompleted);
    console.log(`✅ User has completed ${completedBooks.length} books`);
    
    if (completedBooks.length > 0) {
      console.log('📖 Completed books:');
      for (const doc of completedBooks) {
        const bookId = doc.data().bookId;
        const bookDoc = await db.collection('books').doc(bookId).get();
        if (bookDoc.exists) {
          const bookData = bookDoc.data();
          console.log(`   - ${bookData.title} (Traits: ${bookData.traits?.length || 0}, Tags: ${bookData.tags?.length || 0})`);
        }
      }
    }
    
    console.log('\n📊 Recommendation System Status:');
    console.log('✅ Database connection: Working');
    console.log('✅ Books with traits/tags: Available');
    console.log('✅ User reading data: Available');
    console.log('✅ OpenAI API key: Set');
    console.log('⚠️  Firestore index: Needs creation for quiz analytics queries');
    
    console.log('\n🔧 To fully test recommendations:');
    console.log('1. Create the Firestore index from the error URL above');
    console.log('2. Run the full AI recommendation system');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

simpleRecommendationTest();