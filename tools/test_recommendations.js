// test_recommendations.js
// Test the AI recommendations function locally

const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));

// Load environment variables from .env file
require('dotenv').config();

// Validate environment variables
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) {
  console.error('❌ Error: OPENAI_API_KEY environment variable is required');
  process.exit(1);
}

// Initialize Firebase Admin SDK
let db;
try {
  const serviceAccount = require('./serviceAccountKey.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267',
    storageBucket: 'readme-40267.firebasestorage.app',
    databaseURL: 'https://readme-40267-default-rtdb.firebaseio.com'
  });
  
  db = admin.firestore();
  console.log('✅ Firebase Admin SDK initialized successfully\n');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:', error);
  process.exit(1);
}

// CONSISTENT VALUES
const ALLOWED_TAGS = [
  'adventure', 'fantasy', 'friendship', 'animals', 'family',
  'learning', 'kindness', 'creativity', 'imagination', 'responsibility',
  'cooperation', 'resilience', 'organization', 'enthusiasm', 'positivity',
  'bravery', 'sharing', 'art', 'exploration', 'teamwork', 'emotions',
  'self-acceptance', 'problem-solving', 'leadership', 'confidence', 'patience',
  'generosity', 'helpfulness', 'playfulness', 'curiosity', 'innovation',
];

const ALLOWED_TRAITS = [
  'curious', 'imaginative', 'creative', 'adventurous', 'artistic', 'inventive',
  'hardworking', 'careful', 'persistent', 'focused', 'responsible', 'organized',
  'outgoing', 'energetic', 'talkative', 'playful', 'cheerful', 'social', 'enthusiastic',
  'kind', 'helpful', 'caring', 'friendly', 'cooperative', 'gentle', 'sharing',
  'calm', 'relaxed', 'positive', 'brave', 'confident', 'easygoing',
];

async function aggregateUserSignals(userId) {
  try {
    console.log(`\n📊 Aggregating signals for user: ${userId}`);
    
    // 1. Book interactions (favorites/bookmarks)
    const interactionsSnap = await db.collection('book_interactions')
      .where('userId', '==', userId)
      .get();
    const favoriteBookIds = interactionsSnap.docs
      .filter(doc => ['favorite', 'bookmark'].includes(doc.data().action))
      .map(doc => doc.data().bookId);
    console.log(`   📚 Found ${favoriteBookIds.length} favorite/bookmarked books`);

    // 2. Completed books
    const progressSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .get();
    const completedBookIds = progressSnap.docs.map(doc => doc.data().bookId);
    console.log(`   ✅ Found ${completedBookIds.length} completed books`);

    // 3. Session durations
    const sessionsSnap = await db.collection('reading_sessions')
      .where('userId', '==', userId)
      .get();
    const sessionBookDurations = {};
    sessionsSnap.docs.forEach(doc => {
      const data = doc.data();
      if (!sessionBookDurations[data.bookId]) sessionBookDurations[data.bookId] = 0;
      sessionBookDurations[data.bookId] += data.sessionDurationSeconds || 0;
    });
    console.log(`   ⏱️  Found ${sessionsSnap.size} reading sessions`);

    // 4. Quiz results
    const quizSnap = await db.collection('quiz_analytics')
      .where('userId', '==', userId)
      .orderBy('completedAt', 'desc')
      .limit(1)
      .get();
    let quizTraits = [];
    if (!quizSnap.empty) {
      quizTraits = quizSnap.docs[0].data().dominantTraits || [];
      console.log(`   🎯 Quiz traits: ${quizTraits.join(', ')}`);
    } else {
      console.log(`   ⚠️  No quiz results found`);
    }

    // 5. Aggregate traits/tags from books
    const allBookIds = Array.from(new Set([...favoriteBookIds, ...completedBookIds, ...Object.keys(sessionBookDurations)]));
    console.log(`   📖 Total unique books interacted with: ${allBookIds.length}`);
    
    const traitCounts = {};
    const tagCounts = {};
    
    for (const bookId of allBookIds) {
      const bookDoc = await db.collection('books').doc(bookId).get();
      if (!bookDoc.exists) {
        console.log(`   ⚠️  Book ${bookId} not found`);
        continue;
      }
      
      const bookData = bookDoc.data();
      const traits = bookData.traits || [];
      const tags = bookData.tags || [];
      
      // Weighting: favorites/bookmarks +2, completed +2, session duration normalized
      const weight = (favoriteBookIds.includes(bookId) ? 2 : 0)
        + (completedBookIds.includes(bookId) ? 2 : 0)
        + ((sessionBookDurations[bookId] || 0) / 1800); // 30min session = +1
      
      console.log(`   📕 "${bookData.title}" - Weight: ${weight.toFixed(2)}`);
      
      traits.forEach(trait => {
        traitCounts[trait] = (traitCounts[trait] || 0) + weight;
      });
      tags.forEach(tag => {
        tagCounts[tag] = (tagCounts[tag] || 0) + weight;
      });
    }

    // Add quiz traits with base weight
    quizTraits.forEach(trait => {
      traitCounts[trait] = (traitCounts[trait] || 0) + 1.5;
    });

    // Sort and select top traits/tags
    const topTraits = Object.entries(traitCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([trait]) => trait);
    const topTags = Object.entries(tagCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([tag]) => tag);

    console.log(`\n   🎯 Top Traits: ${topTraits.join(', ')}`);
    console.log(`   🏷️  Top Tags: ${topTags.join(', ')}`);

    return { topTraits, topTags };
    
  } catch (error) {
    console.error('❌ Error aggregating user signals:', error);
    return {
      topTraits: [],
      topTags: []
    };
  }
}

async function generateAIRecommendations(userSignals) {
  try {
    const { topTraits, topTags } = userSignals;
    console.log(`\n🤖 Generating AI recommendations...`);
    console.log(`   User traits: ${topTraits.join(', ')}`);
    console.log(`   User tags: ${topTags.join(', ')}`);

    // Get available books from Firestore
    const booksSnap = await db.collection('books').get();
    const availableBooks = booksSnap.docs.map(doc => ({
      id: doc.id,
      title: doc.data().title,
      author: doc.data().author,
      description: doc.data().description,
      tags: doc.data().tags || [],
      traits: doc.data().traits || [],
      ageRating: doc.data().ageRating
    }));
    console.log(`   Found ${availableBooks.length} available books`);

    const prompt = `You are an expert children's librarian specializing in personalized book recommendations.

User Profile:
- Preferred traits: ${topTraits.join(', ')}
- Interested in topics: ${topTags.join(', ')}

Available Books (ID | Title | Author | Age | Tags | Traits | Description):
${availableBooks.map(book => `ID: ${book.id} | "${book.title}" by ${book.author} (Age: ${book.ageRating}) - Tags: [${book.tags.join(', ')}], Traits: [${book.traits.join(', ')}] - ${book.description}`).join('\n')}

Instructions:
1. Recommend 3-5 books from the available list that best match the user's traits and interests
2. Prioritize books that align with the user's preferred traits: ${topTraits.join(', ')}
3. Consider books with relevant tags: ${topTags.join(', ')}
4. Only recommend books from the provided list
5. Order recommendations by relevance (best match first)
6. IMPORTANT: Return the book IDs (the alphanumeric codes like "1401v39Y2u55ILCuHtDk"), NOT the titles

Return ONLY a valid JSON array of book IDs in order of recommendation:
Example: ["1401v39Y2u55ILCuHtDk", "21v8kQj1tnVtqOdXKuvc", "3MbYQantsdJkyGI6jRb5"]`;

    console.log(`   Sending request to OpenAI...`);

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'You are an expert children\'s book recommendation specialist. Return only valid JSON.' },
          { role: 'user', content: prompt }
        ]
      })
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
    }
    
    const data = await response.json();
    const content = data.choices[0].message.content;
    console.log(`   AI Response: ${content}`);
    
    const match = content.match(/\[[\s\S]*\]/);
    if (match) {
      const recommendedIds = JSON.parse(match[0]);
      console.log(`   📚 Recommended book IDs: ${recommendedIds.join(', ')}`);
      
      const validRecommendations = recommendedIds.filter(id => 
        availableBooks.some(book => book.id === id)
      );
      console.log(`   ✅ Valid recommendations: ${validRecommendations.length}`);
      
      return validRecommendations;
    }
    
    console.warn('⚠️  Could not parse AI response, returning empty recommendations');
    return [];
    
  } catch (error) {
    console.error('❌ Error generating AI recommendations:', error);
    return [];
  }
}

async function main() {
  try {
    console.log('🚀 Starting AI recommendations test...\n');
    
    // Get users who have reading activity OR quiz results
    console.log('📋 Fetching users with activity or quiz results...');
    const usersWithActivity = await db.collection('reading_progress')
      .get();
    
    const usersWithQuiz = await db.collection('quiz_analytics')
      .get();
    
    const uniqueUsers = [...new Set([
      ...usersWithActivity.docs.map(doc => doc.data().userId),
      ...usersWithQuiz.docs.map(doc => doc.data().userId)
    ])];
    
    console.log(`\n✅ Found ${uniqueUsers.length} users:`);
    uniqueUsers.forEach((userId, index) => {
      console.log(`   ${index + 1}. ${userId}`);
    });
    
    if (uniqueUsers.length === 0) {
      console.log('\n⚠️  No users found with activity or quiz results!');
      console.log('   Check your Firestore collections: reading_progress, quiz_analytics');
      process.exit(0);
    }
    
    // Process each user
    let processedUsers = 0;
    for (const userId of uniqueUsers) {
      try {
        console.log(`\n${'='.repeat(60)}`);
        console.log(`Processing user ${processedUsers + 1}/${uniqueUsers.length}: ${userId}`);
        console.log('='.repeat(60));
        
        // Aggregate user reading signals
        const userSignals = await aggregateUserSignals(userId);
        
        if (userSignals.topTraits.length === 0 && userSignals.topTags.length === 0) {
          console.log('   ⚠️  No traits or tags found for this user, skipping...');
          continue;
        }
        
        // Generate AI recommendations
        const recommendations = await generateAIRecommendations(userSignals);
        
        if (recommendations.length === 0) {
          console.log('   ⚠️  No recommendations generated');
          continue;
        }
        
        // Save recommendations to user document
        await db.collection('users').doc(userId).set({
          aiRecommendations: recommendations,
          lastRecommendationUpdate: new Date()
        }, { merge: true });
        
        console.log(`\n   ✅ Saved ${recommendations.length} recommendations to Firestore`);
        processedUsers++;
        
      } catch (userError) {
        console.error(`\n   ❌ Error processing user ${userId}:`, userError);
      }
    }
    
    console.log(`\n${'='.repeat(60)}`);
    console.log(`✅ Completed! Processed ${processedUsers}/${uniqueUsers.length} users`);
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  } finally {
    process.exit(0);
  }
}

main();
