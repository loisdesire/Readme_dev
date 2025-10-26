/**
 * Firebase Cloud Functions for AI Tagging and Recommendations
 * UPDATED: Now uses consistent traits/tags/ages across tagging and recommendations
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const fetch = require('node-fetch');
const pdfParse = require('pdf-parse');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Set global options
setGlobalOptions({ 
  maxInstances: 10,
  region: "us-central1" 
});

// CONSISTENT VALUES - Used across ALL functions
const ALLOWED_TAGS = [
  'adventure', 'fantasy', 'friendship', 'animals', 'family',
  'learning', 'kindness', 'creativity', 'imagination', 'responsibility',
  'cooperation', 'resilience', 'organization', 'enthusiasm', 'positivity',
  'bravery', 'sharing', 'art', 'exploration', 'teamwork', 'emotions',
  'self-acceptance', 'problem-solving', 'leadership', 'confidence', 'patience',
  'generosity', 'helpfulness', 'playfulness', 'curiosity', 'innovation',
  // Remove 'music', 'technology', 'history', 'sports', 'science', 'mystery' if not needed
];

const ALLOWED_TRAITS = [
  // Openness
  'curious', 'imaginative', 'creative', 'adventurous', 'artistic', 'inventive',
  // Conscientiousness
  'hardworking', 'careful', 'persistent', 'focused', 'responsible', 'organized',
  // Extraversion
  'outgoing', 'energetic', 'talkative', 'playful', 'cheerful', 'social', 'enthusiastic',
  // Agreeableness
  'kind', 'helpful', 'caring', 'friendly', 'cooperative', 'gentle', 'sharing',
  // Emotional Stability
  'calm', 'relaxed', 'positive', 'brave', 'confident', 'easygoing',
];

const ALLOWED_AGES = ['6+', '7+', '8+', '9+', '10', '12'];

/**
 * Firestore Trigger: Auto-flag new books for AI tagging
 * Triggers when a new book document is created
 */
exports.flagNewBookForTagging = onDocumentCreated("books/{bookId}", async (event) => {
  const bookId = event.params.bookId;
  const bookData = event.data.data();
  
  logger.info(`📚 New book detected: ${bookData.title} (ID: ${bookId})`);
  
  try {
    // Check if book has PDF and basic required fields
    const hasRequiredFields = bookData.title && bookData.author && bookData.pdfUrl;
    const alreadyTagged = bookData.traits && bookData.tags && 
                         bookData.traits.length > 0 && bookData.tags.length > 0 &&
                         !(bookData.traits.length === 1 && bookData.traits[0] === "") &&
                         !(bookData.tags.length === 1 && bookData.tags[0] === "");
    
    if (hasRequiredFields && !alreadyTagged) {
      // Flag for AI tagging
      await event.data.ref.update({
        needsTagging: true,
        taggedAt: null // Clear any previous tagging timestamp
      });
      
      logger.info(`✅ Flagged "${bookData.title}" for AI tagging`);
    } else if (!hasRequiredFields) {
      logger.warn(`⚠️ Book "${bookData.title}" missing required fields (title, author, or pdfUrl)`);
    } else {
      logger.info(`ℹ️ Book "${bookData.title}" already has tags/traits, skipping`);
    }
    
  } catch (error) {
    logger.error(`❌ Error flagging book for tagging: ${error.message}`);
  }
});

/**
 * Firestore Trigger: Auto-flag updated books if PDF changes
 * Triggers when a book document is updated
 */
exports.checkUpdatedBookForTagging = onDocumentUpdated("books/{bookId}", async (event) => {
  const bookId = event.params.bookId;
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  
  // Check if PDF URL changed
  const pdfUrlChanged = beforeData.pdfUrl !== afterData.pdfUrl;
  
  if (pdfUrlChanged && afterData.pdfUrl) {
    logger.info(`📝 PDF updated for book: ${afterData.title} (ID: ${bookId})`);
    
    try {
      // Re-flag for tagging since content changed
      await event.data.after.ref.update({
        needsTagging: true,
        taggedAt: null,
        traits: [], // Clear old traits
        tags: []    // Clear old tags
      });
      
      logger.info(`✅ Re-flagged "${afterData.title}" for AI tagging due to PDF change`);
      
    } catch (error) {
      logger.error(`❌ Error re-flagging updated book: ${error.message}`);
    }
  }
});

/**
 * Daily scheduled function to run AI tagging for new books
 * Runs every day at 2 AM UTC
 */
exports.dailyAiTagging = onSchedule({
  schedule: "0 2 * * *", // Daily at 2 AM UTC
  timeZone: "UTC",
  memory: "1GiB",
  timeoutSeconds: 540 // 9 minutes
}, async (event) => {
  logger.info("🚀 Starting daily AI tagging process...");
  
  try {
    // Check for books that need tagging
    const booksNeedingTagging = await db.collection('books')
      .where('needsTagging', '==', true)
      .get();
    
    logger.info(`📚 Found ${booksNeedingTagging.size} books needing tagging`);
    
    if (booksNeedingTagging.empty) {
      logger.info("✅ No books need tagging. All done!");
      return { success: true, message: "No books need tagging" };
    }
    
    // Process each book with AI tagging
    const bookTitles = [];
    let processedCount = 0;

    for (const doc of booksNeedingTagging.docs) {
      const bookData = doc.data();
      const bookId = doc.id;
      
      logger.info(`📖 Processing book: ${bookData.title} (ID: ${bookId})`);
      bookTitles.push(bookData.title);
      
      const success = await processBookForTagging(bookId, bookData);
      if (success) {
        processedCount++;
      }
    }

    logger.info(`✅ Daily AI tagging completed. Processed ${processedCount}/${booksNeedingTagging.size} books`);
    return { 
      success: true, 
      message: `Processed ${processedCount} books`,
      books: bookTitles
    };
    
  } catch (error) {
    logger.error("❌ Error in daily AI tagging:", error);
    throw error;
  }
});

/**
 * Daily scheduled function to update AI recommendations
 * Runs every day at 3 AM UTC (after tagging)
 */
exports.dailyAiRecommendations = onSchedule({
  schedule: "0 3 * * *", // Daily at 3 AM UTC
  timeZone: "UTC",
  memory: "1GiB",
  timeoutSeconds: 540
}, async (event) => {
  logger.info("🤖 Starting daily AI recommendations update...");
  
  try {
    // Get users who have reading activity OR quiz results
    const usersWithActivity = await db.collection('reading_progress')
      .select('userId')
      .get();
    
    const usersWithQuiz = await db.collection('quiz_analytics')
      .select('userId')
      .get();
    
    const uniqueUsers = [...new Set([
      ...usersWithActivity.docs.map(doc => doc.data().userId),
      ...usersWithQuiz.docs.map(doc => doc.data().userId)
    ])];
    logger.info(`👥 Found ${uniqueUsers.length} users (with reading activity or quiz results)`);
    
    let processedUsers = 0;
    for (const userId of uniqueUsers) {
      try {
        // Aggregate user reading signals
        const userSignals = await aggregateUserSignals(userId);
        
        // Generate AI recommendations
        const recommendations = await generateAIRecommendations(userSignals);
        
        // Save recommendations to user document as array of book IDs
        // Use set with merge to create document if it doesn't exist
        await db.collection('users').doc(userId).set({
          aiRecommendations: recommendations, // Array of book IDs from generateAIRecommendations
          lastRecommendationUpdate: new Date()
        }, { merge: true });
        
        processedUsers++;
        logger.info(`📱 Processed recommendations for user ${userId}`);
      } catch (userError) {
        logger.error(`❌ Error processing user ${userId}:`, userError);
      }
    }
    
    logger.info("✅ Daily AI recommendations completed");
    return { 
      success: true, 
      message: `Processed recommendations for ${processedUsers} users`
    };
    
  } catch (error) {
    logger.error("❌ Error in daily AI recommendations:", error);
    throw error;
  }
});

/**
 * Manual trigger for AI tagging (HTTP endpoint)
 * Can be called manually or for testing
 */
exports.triggerAiTagging = onRequest({
  memory: "1GiB",
  timeoutSeconds: 540
}, async (req, res) => {
  logger.info("🚀 Manual AI tagging triggered");
  
  try {
    // Check for books that need tagging
    const booksNeedingTagging = await db.collection('books')
      .where('needsTagging', '==', true)
      .get();
    
    logger.info(`📚 Found ${booksNeedingTagging.size} books needing tagging`);
    
    if (booksNeedingTagging.empty) {
      logger.info("✅ No books need tagging. All done!");
      return res.json({ success: true, message: "No books need tagging" });
    }
    
    // Process each book with AI tagging
    const bookTitles = [];
    let processedCount = 0;
    
    for (const doc of booksNeedingTagging.docs) {
      const bookData = doc.data();
      const bookId = doc.id;
      
      logger.info(`📖 Processing book: ${bookData.title} (ID: ${bookId})`);
      bookTitles.push(bookData.title);
      
      const success = await processBookForTagging(bookId, bookData);
      if (success) {
        processedCount++;
      }
    }
    
    const result = {
      success: true,
      message: `Processed ${processedCount} books`,
      books: bookTitles
    };
    
    res.json(result);
  } catch (error) {
    logger.error("❌ Error in manual AI tagging:", error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Manual trigger for AI recommendations (HTTP endpoint)
 */
exports.triggerAiRecommendations = onRequest({
  memory: "1GiB", 
  timeoutSeconds: 540
}, async (req, res) => {
  logger.info("🤖 Manual AI recommendations triggered");
  
  try {
    // Get users who have reading activity OR quiz results
    const usersWithActivity = await db.collection('reading_progress')
      .select('userId')
      .get();
    
    const usersWithQuiz = await db.collection('quiz_analytics')
      .select('userId')
      .get();
    
    const uniqueUsers = [...new Set([
      ...usersWithActivity.docs.map(doc => doc.data().userId),
      ...usersWithQuiz.docs.map(doc => doc.data().userId)
    ])];
    logger.info(`👥 Found ${uniqueUsers.length} users (with reading activity or quiz results)`);
    
    let processedUsers = 0;
    for (const userId of uniqueUsers) {
      try {
        // Aggregate user reading signals
        const userSignals = await aggregateUserSignals(userId);
        
        // Generate AI recommendations
        const recommendations = await generateAIRecommendations(userSignals);
        
        // Save recommendations to user document as array of book IDs
        // Use set with merge to create document if it doesn't exist
        await db.collection('users').doc(userId).set({
          aiRecommendations: recommendations, // Array of book IDs from generateAIRecommendations
          lastRecommendationUpdate: new Date()
        }, { merge: true });
        
        processedUsers++;
        logger.info(`📱 Processed recommendations for user ${userId}`);
      } catch (userError) {
        logger.error(`❌ Error processing user ${userId}:`, userError);
      }
    }
    
    const result = {
      success: true,
      message: `Processed recommendations for ${processedUsers} users`
    };
    
    res.json(result);
  } catch (error) {
    logger.error("❌ Error in manual AI recommendations:", error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Health check endpoint
 */
exports.healthCheck = onRequest((req, res) => {
  res.json({ 
    status: "healthy", 
    timestamp: new Date().toISOString(),
    functions: [
      "dailyAiTagging",
      "dailyAiRecommendations", 
      "triggerAiTagging",
      "triggerAiRecommendations"
    ]
  });
});

// ============================================================================
// HELPER FUNCTIONS FOR AI PROCESSING
// ============================================================================

/**
 * Process a book for AI tagging
 */
async function processBookForTagging(bookId, bookData) {
  try {
    logger.info(`🔍 Processing book: ${bookData.title}`);
    
    // Download PDF from Firebase Storage
    const pdfBuffer = await downloadPdfFromStorage(bookData.pdfUrl);
    
    // Extract text from PDF
    const pdfData = await pdfParse(pdfBuffer);
    const bookText = pdfData.text.substring(0, 8000); // First 8000 characters
    
    // Call OpenAI API for tagging
    const aiResponse = await callOpenAIForTagging(bookData.title, bookData.author, bookText, bookData.description);
    
    // Update book in Firestore
    const updateData = {
      traits: aiResponse.traits,
      tags: aiResponse.tags,
      needsTagging: false,
      taggedAt: new Date()
    };
    
    // Only update age rating if we got a valid one
    if (aiResponse.ageRating && aiResponse.ageRating.length > 0) {
      updateData.ageRating = aiResponse.ageRating;
    }
    
    await db.collection('books').doc(bookId).update(updateData);
    
    logger.info(`✅ Successfully tagged: ${bookData.title}`);
    return true;
    
  } catch (error) {
    logger.error(`❌ Error processing book ${bookData.title}:`, error);
    return false;
  }
}

/**
 * Download PDF from Firebase Storage
 */
async function downloadPdfFromStorage(pdfUrl) {
  try {
    const response = await fetch(pdfUrl);
    if (!response.ok) {
      throw new Error(`Failed to download PDF: ${response.statusText}`);
    }
    return Buffer.from(await response.arrayBuffer());
  } catch (error) {
    logger.error('Error downloading PDF:', error);
    throw error;
  }
}

/**
 * Call OpenAI API for book tagging
 * UPDATED: Now uses consistent ALLOWED_TAGS, ALLOWED_TRAITS, ALLOWED_AGES
 */
async function callOpenAIForTagging(title, author, bookText, description = '') {
  const openaiApiKey = process.env.OPENAI_KEY;
  
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured');
  }

  const prompt = `Analyze this children's book and suggest tags, personality traits, and age rating.

Title: ${title}
Author: ${author}
Description: ${description}
Content excerpt: ${bookText.substring(0, 2000)}

Based on this book:
1. Select 3-5 TAGS that categorize the book's themes/genre from: ${ALLOWED_TAGS.join(", ")}
2. Select 3-5 TRAITS that match children who would enjoy this book from: ${ALLOWED_TRAITS.join(", ")}
   Traits should be chosen from these domains: Openness (curious, creative, imaginative), Conscientiousness (responsible, organized, persistent), Extraversion (social, enthusiastic, outgoing), Agreeableness (kind, cooperative, caring), Emotional Stability (resilient, calm, positive).
3. Suggest an appropriate age rating from: ${ALLOWED_AGES.join(", ")}

Return ONLY a JSON object with this exact format:
{
  "tags": ["tag1", "tag2", "tag3"],
  "traits": ["trait1", "trait2", "trait3"],
  "ageRating": "6+"
}`;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4',
        messages: [
          { 
            role: 'system', 
            content: 'You are an expert children\'s book classifier. Return only valid JSON with no additional text.' 
          },
          { role: 'user', content: prompt }
        ],
        max_tokens: 200,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.statusText}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content.trim();
    
    // Parse JSON from OpenAI response
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in AI response');
    }
    
    const result = JSON.parse(jsonMatch[0]);
    
    // Validate and apply defaults if needed
    if (!result.tags || !Array.isArray(result.tags) || result.tags.length === 0) {
      result.tags = ['adventure', 'friendship'];
    }
    if (!result.traits || !Array.isArray(result.traits) || result.traits.length === 0) {
      result.traits = ['curious', 'imaginative'];
    }
    if (!result.ageRating) {
      result.ageRating = '6+';
    }
    
    return {
      traits: result.traits,
      tags: result.tags,
      ageRating: result.ageRating
    };
    
  } catch (error) {
    logger.error('Error calling OpenAI:', error);
    // Return defaults matching your system
    return {
      traits: ['curious', 'imaginative'],
      tags: ['adventure', 'friendship'],
      ageRating: '6+'
    };
  }
}

/**
 * Aggregate user signals for recommendations
 * UPDATED: Now matches the logic from ai_recommendation.js
 */
async function aggregateUserSignals(userId) {
  try {
    // 1. Book interactions (favorites/bookmarks)
    const interactionsSnap = await db.collection('book_interactions')
      .where('userId', '==', userId)
      .get();
    const favoriteBookIds = interactionsSnap.docs
      .filter(doc => ['favorite', 'bookmark'].includes(doc.data().action))
      .map(doc => doc.data().bookId);

    // 2. Completed books
    const progressSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .get();
    const completedBookIds = progressSnap.docs.map(doc => doc.data().bookId);

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

    // 4. Quiz results
    const quizSnap = await db.collection('quiz_analytics')
      .where('userId', '==', userId)
      .orderBy('completedAt', 'desc')
      .limit(1)
      .get();
    let quizTraits = [];
    if (!quizSnap.empty) {
      quizTraits = quizSnap.docs[0].data().dominantTraits || [];
    }

    // 5. Aggregate traits/tags from books
    const allBookIds = Array.from(new Set([...favoriteBookIds, ...completedBookIds, ...Object.keys(sessionBookDurations)]));
    const traitCounts = {};
    const tagCounts = {};
    
    for (const bookId of allBookIds) {
      const bookDoc = await db.collection('books').doc(bookId).get();
      if (!bookDoc.exists) continue;
      
      const bookData = bookDoc.data();
      const traits = bookData.traits || [];
      const tags = bookData.tags || [];
      
      // Weighting: favorites/bookmarks +2, completed +2, session duration normalized
      const weight = (favoriteBookIds.includes(bookId) ? 2 : 0)
        + (completedBookIds.includes(bookId) ? 2 : 0)
        + ((sessionBookDurations[bookId] || 0) / 1800); // 30min session = +1
      
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

    return { topTraits, topTags };
    
  } catch (error) {
    logger.error('Error aggregating user signals:', error);
    return {
      topTraits: [],
      topTags: []
    };
  }
}

/**
 * Generate AI recommendations for user
 * UPDATED: Now uses consistent ALLOWED_TAGS and ALLOWED_TRAITS
 */
async function generateAIRecommendations(userSignals) {
  const openaiApiKey = process.env.OPENAI_KEY;
  
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured');
  }
  
  try {
    const { topTraits, topTags } = userSignals;
    // Log user signals
    logger.info(`[RECOMMEND] User signals:`, { topTraits, topTags });

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
    logger.info(`[RECOMMEND] Found ${availableBooks.length} available books`, { bookIds: availableBooks.map(b => b.id) });

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

    logger.info(`[RECOMMEND] Prompt sent to OpenAI:`, { prompt });

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
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
      throw new Error(`OpenAI API error: ${response.status} ${response.statusText}`);
    }
    
    const data = await response.json();
    logger.info(`[RECOMMEND] OpenAI raw response:`, { data });
    
    const match = data.choices[0].message.content.match(/\[[\s\S]*\]/);
    if (match) {
      const recommendedIds = JSON.parse(match[0]);
      logger.info(`[RECOMMEND] Book IDs returned by OpenAI:`, { recommendedIds });
      const validRecommendations = recommendedIds.filter(id => 
        availableBooks.some(book => book.id === id)
      );
      logger.info(`[RECOMMEND] Valid recommendations after filtering:`, { validRecommendations });
      logger.info(`Generated ${validRecommendations.length} book recommendations`);
      return validRecommendations; // Return array of book IDs
    }
    
    logger.warn('[RECOMMEND] Could not parse AI response, returning empty recommendations');
    return [];
    
  } catch (error) {
    logger.error('[RECOMMEND] Error generating AI recommendations:', error);
    return []; // Return empty array on error
  }
}