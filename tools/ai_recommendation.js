// ai_recommendation.js
// Aggregates user signals from Firestore for AI-powered book recommendations
// References: book_interactions, reading_progress, reading_sessions, quiz_analytics, books

const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
  storageBucket: 'readme-40267.firebasestorage.app'
});
const db = admin.firestore();

// Validate environment variables
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) {
  console.error('Error: OPENAI_API_KEY environment variable is required');
  console.error('   Set it using: $env:OPENAI_API_KEY="your-api-key-here"');
  process.exit(1);
}

// Canonical trait vocabulary used by the in-app personality quiz + Library filters.
const CANONICAL_TRAITS = [
  'curious', 'creative', 'imaginative',
  'responsible', 'organized', 'persistent',
  'social', 'enthusiastic', 'outgoing',
  'kind', 'cooperative', 'caring',
  'resilient', 'calm', 'positive',
];

// Drifted traits we have historically seen in Firestore/scripts.
// Map them back to canonical quiz traits so exact-match scoring stays consistent.
const TRAIT_SYNONYMS = {
  brave: 'resilient',
  adventurous: 'curious',
  friendly: 'kind',
  helpful: 'caring',
  confident: 'positive',
  cheerful: 'positive',
  focused: 'persistent',
  hardworking: 'persistent',
  careful: 'responsible',
  playful: 'enthusiastic',
  relaxed: 'calm',
  easygoing: 'calm',
  artistic: 'creative',
  sharing: 'cooperative',
};

function normalizeTrait(raw) {
  if (typeof raw !== 'string') return null;
  const t = raw.trim().toLowerCase();
  if (!t) return null;
  return TRAIT_SYNONYMS[t] || t;
}

function normalizeTraits(rawList) {
  const canonical = new Set(CANONICAL_TRAITS);
  const list = Array.isArray(rawList) ? rawList : [];
  const out = new Set();
  for (const raw of list) {
    const t = normalizeTrait(raw);
    if (t && canonical.has(t)) out.add(t);
  }
  return [...out];
}

// Helper: Get book metadata (traits, tags) by bookId
async function getBookMetadata(bookId) {
  const doc = await db.collection('books').doc(bookId).get();
  if (!doc.exists) return {};
  const data = doc.data();
  return {
    traits: normalizeTraits(data.traits),
    tags: data.tags || [],
  };
}

// Aggregate user signals
async function aggregateUserSignals(userId) {
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
    quizTraits = normalizeTraits(quizSnap.docs[0].data().dominantTraits || []);
  }

  // 5. Aggregate traits/tags from books
  const allBookIds = Array.from(new Set([...favoriteBookIds, ...completedBookIds, ...Object.keys(sessionBookDurations)]));
  const traitCounts = {};
  const tagCounts = {};
  for (const bookId of allBookIds) {
    const { traits, tags } = await getBookMetadata(bookId);
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
}

// Get book recommendations using OpenAI
async function recommendBooksForUser(userId) {
  const { topTraits, topTags } = await aggregateUserSignals(userId);
  
  // Get available books from Firestore
  const booksSnap = await db.collection('books').get();
  const availableBooks = booksSnap.docs.map(doc => ({
    id: doc.id,
    title: doc.data().title,
    author: doc.data().author,
    description: doc.data().description,
    tags: doc.data().tags || [],
    traits: normalizeTraits(doc.data().traits || []),
    ageRating: doc.data().ageRating
  }));

  const allowedTags = [
    'adventure', 'fantasy', 'friendship', 'animals', 'family', 'learning', 'kindness', 'creativity', 'imagination'
  ];
  const allowedTraits = CANONICAL_TRAITS;

  const prompt = `You are an expert children's librarian specializing in personalized book recommendations.

User Profile:
- Preferred traits: ${topTraits.join(', ')}
- Interested in topics: ${topTags.join(', ')}

Available Books:
${availableBooks.map(book => `- "${book.title}" by ${book.author} (Age: ${book.ageRating}) - Tags: [${book.tags.join(', ')}], Traits: [${book.traits.join(', ')}] - ${book.description}`).join('\n')}

Instructions:
1. Recommend 3-5 books from the available list that best match the user's traits and interests
2. Prioritize books that align with the user's preferred traits: ${topTraits.join(', ')}
3. Consider books with relevant tags: ${topTags.join(', ')}
4. Only recommend books from the provided list
5. Order recommendations by relevance (best match first)

Return ONLY a valid JSON array of book IDs in order of recommendation:
Example: ["bookId1", "bookId2", "bookId3"]`;

  try {
    console.log('Requesting AI recommendations...');
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4',
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
    console.log('   AI recommendations completed');
    
    const match = data.choices[0].message.content.match(/\[[\s\S]*\]/);
    if (match) {
      const recommendedIds = JSON.parse(match[0]);
      const recommendedBooks = recommendedIds.map(id => availableBooks.find(book => book.id === id)).filter(Boolean);
      console.log('AI Recommendations for user:', userId);
      console.log('User profile:', { topTraits, topTags });
      console.log('Recommended books:', recommendedBooks.map(book => `${book.title} by ${book.author}`));
      return recommendedBooks;
    }
    
    console.warn('   Could not parse AI response, returning empty recommendations');
  } catch (error) {
    console.error(`Error getting AI recommendations: ${error.message}`);
  }
  
  return [];
}

// Usage example
// recommendBooksForUser('<USER_ID>');

module.exports = { aggregateUserSignals, recommendBooksForUser };
