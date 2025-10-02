// ai_recommendation.js
// Aggregates user signals from Firestore for AI-powered book recommendations
// References: book_interactions, reading_progress, reading_sessions, quiz_analytics, books

const admin = require('firebase-admin');
const { Configuration, OpenAIApi } = require('openai');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// --- CONFIGURE YOUR OPENAI API KEY ---
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '<YOUR_OPENAI_API_KEY>';
const openai = new OpenAIApi(new Configuration({ apiKey: OPENAI_API_KEY }));

// Helper: Get book metadata (traits, tags) by bookId
async function getBookMetadata(bookId) {
  const doc = await db.collection('books').doc(bookId).get();
  if (!doc.exists) return {};
  const data = doc.data();
  return {
    traits: data.traits || [],
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
    quizTraits = quizSnap.docs[0].data().dominantTraits || [];
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

// Example: Recommend books using OpenAI
async function recommendBooksForUser(userId) {
  const { topTraits, topTags } = await aggregateUserSignals(userId);
  // You can now use topTraits/topTags in your OpenAI prompt
  // ...
  console.log('User profile:', { topTraits, topTags });
  // Example OpenAI prompt (customize as needed)
  /*
  const prompt = `Recommend children's books for a user with these traits: ${topTraits.join(', ')} and interests: ${topTags.join(', ')}.`;
  const response = await openai.createCompletion({
    model: 'gpt-3.5-turbo',
    prompt,
    max_tokens: 200,
  });
  console.log('AI Recommendations:', response.data.choices[0].text);
  */
}

// Usage example
// recommendBooksForUser('<USER_ID>');

module.exports = { aggregateUserSignals, recommendBooksForUser };
