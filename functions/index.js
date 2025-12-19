/**
 * Firebase Cloud Functions for AI Tagging and Recommendations
 * UPDATED: Now uses consistent traits/tags/ages across tagging and recommendations
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
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
      "triggerAiRecommendations",
      "createChildAccount"
    ]
  });
});

/**
 * Create child account (HTTP endpoint)
 * Called by parents to create a child account without logging out
 */
exports.createChildAccount = onCall(async (request) => {
  try {
    const { email, password, username, parentId } = request.data;

    if (!email || !password || !username || !parentId) {
      throw new HttpsError(
        'invalid-argument', 
        'Missing required fields: email, password, username, parentId'
      );
    }

    logger.info(`Creating child account: ${username} (${email}) for parent ${parentId}`);

    // Import admin auth
    const admin = require('firebase-admin');
    const auth = admin.auth();

    // Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email,
      password: password,
      displayName: username
    });

    logger.info(`Created Firebase Auth user: ${userRecord.uid}`);

    // Create Firestore profile
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email,
      username: username,
      accountType: 'child',
      parentId: parentId,
      avatar: '👦',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      hasCompletedQuiz: false,
      personalityTraits: [],
      children: [],
      isRemoved: false
    });

    logger.info(`Created Firestore profile for ${userRecord.uid}`);

    // Add child to parent's children array
    await db.collection('users').doc(parentId).update({
      children: admin.firestore.FieldValue.arrayUnion(userRecord.uid)
    });

    logger.info(`Added child ${userRecord.uid} to parent ${parentId}`);

    return {
      success: true,
      childId: userRecord.uid,
      message: 'Child account created successfully'
    };

  } catch (error) {
    logger.error('Error creating child account:', error);
    throw new HttpsError('internal', error.message || 'Failed to create child account');
  }
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

Based on the book's ACTUAL content and themes:
1. Select 3-5 TAGS that categorize the book's themes/genre from: ${ALLOWED_TAGS.join(", ")}
2. Select 3-5 TRAITS that match children who would enjoy this book from: ${ALLOWED_TRAITS.join(", ")}
   
   CRITICAL: Choose traits based on what the story ACTUALLY emphasizes, not defaults:
   - Openness: curious, imaginative, creative, adventurous, artistic, inventive
   - Conscientiousness: hardworking, careful, persistent, focused, responsible, organized
   - Extraversion: outgoing, energetic, talkative, playful, cheerful, social, enthusiastic
   - Agreeableness: kind, helpful, caring, friendly, cooperative, gentle, sharing
   - Emotional Stability: calm, relaxed, positive, brave, confident, easygoing
   
   If the story is about:
   - Art/creativity → artistic, creative, imaginative
   - Hard work/dedication → hardworking, persistent, focused
   - Social activities/friendship → social, friendly, outgoing
   - Helping others → helpful, kind, caring
   - Staying calm under pressure → calm, relaxed, confident
   
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
    
    // Validate and filter traits/tags to ensure they're in allowed lists
    if (result.traits && Array.isArray(result.traits)) {
      result.traits = result.traits.filter(trait => ALLOWED_TRAITS.includes(trait));
    }
    if (result.tags && Array.isArray(result.tags)) {
      result.tags = result.tags.filter(tag => ALLOWED_TAGS.includes(tag));
    }
    
    // Apply varied defaults if needed (avoid always using same defaults)
    if (!result.tags || result.tags.length === 0) {
      // Use varied defaults based on title/content
      const randomTags = ['learning', 'emotions', 'creativity', 'animals', 'family'];
      result.tags = [randomTags[Math.floor(Math.random() * randomTags.length)], 'friendship'];
    }
    if (!result.traits || result.traits.length === 0) {
      // Use varied defaults instead of always 'curious, imaginative'
      const randomTraits = ['kind', 'creative', 'persistent', 'social', 'brave'];
      result.traits = [randomTraits[Math.floor(Math.random() * randomTraits.length)], 'responsible'];
    }
    if (!result.ageRating || !ALLOWED_AGES.includes(result.ageRating)) {
      result.ageRating = '6+';
    }
    
    return {
      traits: result.traits,
      tags: result.tags,
      ageRating: result.ageRating
    };
    
  } catch (error) {
    logger.error('Error calling OpenAI:', error);
    // Use varied defaults instead of always the same ones
    const randomTraits = ['kind', 'creative', 'persistent', 'social', 'brave'];
    const randomTags = ['learning', 'emotions', 'creativity', 'animals', 'family'];
    return {
      traits: [randomTraits[Math.floor(Math.random() * randomTraits.length)], 'responsible'],
      tags: [randomTags[Math.floor(Math.random() * randomTags.length)], 'teamwork'],
      ageRating: '6+'
    };
  }
}

/**
 * Aggregate user signals for recommendations
 * SIMPLIFIED: Only uses traits (personality-based matching)
 * Tags are just descriptive metadata, not used for scoring
 */
async function aggregateUserSignals(userId) {
  try {
    const traitCounts = {};

    // 1. Get quiz traits (base personality - weight 2)
    const quizSnap = await db.collection('quiz_analytics')
      .where('userId', '==', userId)
      .orderBy('completedAt', 'desc')
      .limit(1)
      .get();
    
    if (!quizSnap.empty) {
      const quizTraits = quizSnap.docs[0].data().dominantTraits || [];
      quizTraits.forEach(trait => {
        traitCounts[trait] = 2;  // Base weight from personality quiz
      });
    }

    // 2. Get favorite books (weight +3)
    const favoritesSnap = await db.collection('book_interactions')
      .where('userId', '==', userId)
      .where('type', '==', 'favorite')
      .get();
    
    for (const doc of favoritesSnap.docs) {
      const bookDoc = await db.collection('books').doc(doc.data().bookId).get();
      if (bookDoc.exists) {
        const traits = bookDoc.data().traits || [];
        traits.forEach(trait => {
          traitCounts[trait] = (traitCounts[trait] || 0) + 3;
        });
      }
    }

    // 3. Get completed books (weight +2)
    const completedSnap = await db.collection('reading_progress')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .get();
    
    for (const doc of completedSnap.docs) {
      const bookDoc = await db.collection('books').doc(doc.data().bookId).get();
      if (bookDoc.exists) {
        const traits = bookDoc.data().traits || [];
        traits.forEach(trait => {
          traitCounts[trait] = (traitCounts[trait] || 0) + 2;
        });
      }
    }

    // Sort and get top 5 traits
    const topTraits = Object.entries(traitCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([trait]) => trait);

    logger.info(`[SIGNALS] User ${userId} top traits:`, topTraits);
    return { topTraits };
    
  } catch (error) {
    logger.error('Error aggregating user signals:', error);
    return { topTraits: [] };
  }
}

/**
 * Generate AI recommendations for user
 * SIMPLIFIED: Only matches on personality traits
 */
async function generateAIRecommendations(userSignals) {
  const openaiApiKey = process.env.OPENAI_KEY;
  
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured');
  }
  
  try {
    const { topTraits } = userSignals;
    logger.info(`[RECOMMEND] User traits:`, topTraits);

    // Get available books
    const booksSnap = await db.collection('books')
      .where('isVisible', '==', true)
      .get();
    
    const availableBooks = booksSnap.docs.map(doc => ({
      id: doc.id,
      title: doc.data().title,
      author: doc.data().author,
      traits: doc.data().traits || [],
      ageRating: doc.data().ageRating,
      description: doc.data().description?.substring(0, 100) || ''
    }));
    
    logger.info(`[RECOMMEND] Found ${availableBooks.length} books`);

    const prompt = `You are recommending books for a child with these personality traits: ${topTraits.join(', ')}.

Match books whose traits align with the child's personality.

Available Books:
${availableBooks.map(book => 
  `ID: ${book.id} | "${book.title}" by ${book.author} | Age: ${book.ageRating} | Traits: [${book.traits.join(', ')}]`
).join('\n')}

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

// ============================================================================
// BOOK QUIZ GENERATION
// ============================================================================

/**
 * Generate quiz questions for a book using AI
 * Called when a user finishes reading a book
 * Quiz is saved to Firestore and reused for all users
 */
exports.generateBookQuiz = onCall(async (request) => {
  try {
    const { bookId } = request.data;

    if (!bookId) {
      throw new HttpsError('invalid-argument', 'Missing required field: bookId');
    }

    logger.info(`Generating quiz for book: ${bookId}`);

    // Check if quiz already exists
    const quizDoc = await db.collection('book_quizzes').doc(bookId).get();
    if (quizDoc.exists) {
      logger.info(`Quiz already exists for book ${bookId}, returning cached version`);
      return { 
        success: true, 
        quiz: quizDoc.data(),
        cached: true 
      };
    }

    // Get book details
    const bookDoc = await db.collection('books').doc(bookId).get();
    if (!bookDoc.exists) {
      throw new HttpsError('not-found', 'Book not found');
    }

    const bookData = bookDoc.data();
    logger.info(`Fetched book: ${bookData.title} by ${bookData.author}`);

    // Download and extract text from PDF
    const pdfBuffer = await downloadPdfFromStorage(bookData.pdfUrl);
    const pdfData = await pdfParse(pdfBuffer);
    const bookText = pdfData.text.substring(0, 8000); // First 8000 characters

    // Generate quiz using AI
    const quiz = await generateQuizWithAI(bookData.title, bookData.author, bookText);

    // Save quiz to Firestore
    const quizData = {
      bookId: bookId,
      bookTitle: bookData.title,
      questions: quiz,
      createdAt: new Date(),
      generatedBy: 'ai'
    };

    await db.collection('book_quizzes').doc(bookId).set(quizData);
    logger.info(`✅ Quiz saved for book ${bookId}`);

    return { 
      success: true, 
      quiz: quizData,
      cached: false 
    };

  } catch (error) {
    logger.error('Error generating book quiz:', error);
    throw new HttpsError('internal', error.message || 'Failed to generate quiz');
  }
});

/**
 * Generate quiz questions using OpenAI
 */
async function generateQuizWithAI(title, author, bookText) {
  const openaiApiKey = process.env.OPENAI_KEY;
  
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured');
  }

  const prompt = `You are creating a fun, engaging reading comprehension quiz for children who just finished reading a book.

Book Title: ${title}
Author: ${author}
Content excerpt: ${bookText.substring(0, 3000)}

Create 5 multiple-choice questions that test understanding of the story. Questions should be:
- Fun and engaging for children
- Test comprehension of plot, characters, and themes
- Have 4 answer options (A, B, C, D)
- Only ONE correct answer per question
- Age-appropriate language

Return ONLY a JSON array with this exact format:
[
  {
    "question": "What was the main character's name?",
    "options": ["Alice", "Bob", "Charlie", "Diana"],
    "correctAnswer": 0
  }
]

The correctAnswer should be the index (0-3) of the correct option.`;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openaiApiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a helpful assistant that creates educational quiz questions for children. Always respond with valid JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1000
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error('OpenAI API error:', errorText);
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content.trim();
    
    // Parse JSON response
    const jsonMatch = content.match(/\[[\s\S]*\]/);
    if (jsonMatch) {
      const quiz = JSON.parse(jsonMatch[0]);
      logger.info(`Generated ${quiz.length} quiz questions`);
      return quiz;
    }
    
    throw new Error('Could not parse quiz from AI response');
    
  } catch (error) {
    logger.error('Error calling OpenAI for quiz generation:', error);
    throw error;
  }
}