// test_ai_recommendation.js
const { recommendBooksForUser, aggregateUserSignals } = require('./ai_recommendation.js');

async function testRecommendations() {
  console.log('🧪 Testing AI recommendation system...\n');
  
  // Let's test with a sample user ID from reading progress
  const admin = require('firebase-admin');
  
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'readme-40267',
    });
  } catch (error) {
    // Already initialized
  }
  
  const db = admin.firestore();
  
  // Get a user who has reading activity
  const progressSnapshot = await db.collection('reading_progress').limit(1).get();
  
  if (progressSnapshot.empty) {
    console.log('❌ No reading progress found - no users to test with');
    return;
  }
  
  const userId = progressSnapshot.docs[0].data().userId;
  console.log(`📱 Testing recommendations for user: ${userId}\n`);
  
  // Test signal aggregation
  console.log('🔍 Aggregating user signals...');
  const signals = await aggregateUserSignals(userId);
  console.log('User signals:', JSON.stringify(signals, null, 2));
  
  // Test recommendations
  console.log('\n🤖 Getting AI recommendations...');
  const recommendations = await recommendBooksForUser(userId);
  
  if (recommendations && recommendations.length > 0) {
    console.log('✅ AI recommendation system is working!');
    console.log(`   Generated ${recommendations.length} recommendations`);
  } else {
    console.log('⚠️  No recommendations returned');
  }
}

testRecommendations().catch(console.error);