/**
 * Pure, dependency-free helpers for the OpenAI-backed Cloud Functions in
 * index.js: prompt building and — the more important half — validating and
 * sanitizing whatever the model hands back before it reaches Firestore.
 *
 * Nothing in this file touches Firebase, network, or the filesystem, so it
 * can be unit-tested with plain Jest, no emulator required. index.js
 * requires this module rather than duplicating the logic inline.
 */

// CONSISTENT VALUES - Used across ALL functions (tagging + recommendations)
const ALLOWED_TAGS = [
  'adventure', 'fantasy', 'friendship', 'animals', 'family',
  'learning', 'kindness', 'creativity', 'imagination', 'responsibility',
  'cooperation', 'resilience', 'organization', 'enthusiasm', 'positivity',
  'bravery', 'sharing', 'art', 'exploration', 'teamwork', 'emotions',
  'self-acceptance', 'problem-solving', 'leadership', 'confidence', 'patience',
  'generosity', 'helpfulness', 'playfulness', 'curiosity', 'innovation',
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

// Fallback pools used when the AI omits a field or fails outright — varied
// on purpose so every untagged book doesn't end up identically tagged.
const FALLBACK_TAG_CANDIDATES = ['learning', 'emotions', 'creativity', 'animals', 'family'];
const FALLBACK_TRAIT_CANDIDATES = ['kind', 'creative', 'persistent', 'social', 'brave'];

/**
 * Extracts a JSON object or array embedded in free-form AI text — handling
 * plain JSON, and JSON wrapped in ``` or ```json code fences, which models
 * commonly add despite being asked not to.
 *
 * @param {string} content Raw AI message content.
 * @param {'object'|'array'} shape Which bracket pair to look for.
 * @returns {any} The parsed JSON value.
 * @throws {Error} If no matching JSON could be found/parsed.
 */
function extractJsonFromAiContent(content, shape = 'object') {
  let text = content.trim();

  const fencedJson = text.match(/```json\s*([\s\S]*?)\s*```/);
  if (fencedJson) {
    text = fencedJson[1];
  } else {
    const fenced = text.match(/```\s*([\s\S]*?)\s*```/);
    if (fenced) text = fenced[1];
  }

  const pattern = shape === 'array' ? /\[[\s\S]*\]/ : /\{[\s\S]*\}/;
  const match = text.match(pattern);
  if (!match) {
    throw new Error(`No JSON ${shape} found in AI response`);
  }
  return JSON.parse(match[0]);
}

/**
 * Builds the prompt sent to the tagging model for a single book.
 */
function buildTaggingPrompt(title, author, description, bookText) {
  return `Analyze this children's book and suggest tags, personality traits, and age rating.

Title: ${title}
Author: ${author}
Description: ${description}
Content excerpt: ${bookText.substring(0, 2000)}

Based on the book's ACTUAL content and themes:
1. Select 3-5 TAGS that categorize the book's themes/genre from: ${ALLOWED_TAGS.join(", ")}
2. Select 3-5 TRAITS that match children who would enjoy this book from: ${ALLOWED_TRAITS.join(", ")}

   CRITICAL: DO NOT default to 'curious' or 'imaginative' for every book. Choose traits based on the PRIMARY themes:

   Story Focus → Recommended Traits:
   - Art, drawing, music, creativity → artistic, creative, inventive
   - Learning, exploring, asking questions → curious, adventurous
   - Building, making things → creative, inventive, focused
   - Working hard, practice, dedication → hardworking, persistent, responsible
   - Friends, parties, talking → social, friendly, outgoing, cheerful
   - Helping, caring for others → kind, helpful, caring, gentle
   - Solving problems, planning → focused, organized, careful
   - Staying brave, facing fears → brave, confident, calm
   - Sharing, teamwork → cooperative, sharing, friendly
   - Fantasy/imagination stories → imaginative (ONLY if heavy fantasy)

   Pick the 3-5 traits that BEST match the main character's personality and story themes.
   Avoid using curious/imaginative unless the story specifically focuses on discovery or fantasy.

3. Suggest an appropriate age rating from: ${ALLOWED_AGES.join(", ")}

Return ONLY a JSON object with this exact format:
{
  "tags": ["tag1", "tag2", "tag3"],
  "traits": ["trait1", "trait2", "trait3"],
  "ageRating": "6+"
}`;
}

/**
 * Picks a random entry from a fallback pool. Takes `randomFn` (defaulting
 * to Math.random) purely so tests can make the "random" choice deterministic.
 */
function pickFallback(candidates, randomFn = Math.random) {
  return candidates[Math.floor(randomFn() * candidates.length)];
}

/**
 * Parses and sanitizes the tagging model's raw text response: extracts the
 * JSON, drops any trait/tag the model invented that isn't in our allowed
 * vocabulary, and fills in varied defaults for anything missing or fully
 * filtered out. This is the boundary that keeps a hallucinating model from
 * writing arbitrary strings into Firestore.
 *
 * @param {string} content Raw AI message content.
 * @param {() => number} randomFn Injectable RNG for deterministic tests.
 * @returns {{traits: string[], tags: string[], ageRating: string}}
 */
function parseAndValidateTaggingResponse(content, randomFn = Math.random) {
  const result = extractJsonFromAiContent(content, 'object');

  if (result.traits && Array.isArray(result.traits)) {
    result.traits = result.traits.filter((trait) => ALLOWED_TRAITS.includes(trait));
  }
  if (result.tags && Array.isArray(result.tags)) {
    result.tags = result.tags.filter((tag) => ALLOWED_TAGS.includes(tag));
  }

  if (!result.tags || result.tags.length === 0) {
    result.tags = [pickFallback(FALLBACK_TAG_CANDIDATES, randomFn), 'friendship'];
  }
  if (!result.traits || result.traits.length === 0) {
    result.traits = [pickFallback(FALLBACK_TRAIT_CANDIDATES, randomFn), 'responsible'];
  }
  if (!result.ageRating || !ALLOWED_AGES.includes(result.ageRating)) {
    result.ageRating = '6+';
  }

  return { traits: result.traits, tags: result.tags, ageRating: result.ageRating };
}

/**
 * The fallback tagging result used when the whole OpenAI call fails
 * (network error, bad API key, malformed response, etc.) rather than just
 * returning an incomplete result.
 */
function fallbackTaggingResult(randomFn = Math.random) {
  return {
    traits: [pickFallback(FALLBACK_TRAIT_CANDIDATES, randomFn), 'responsible'],
    tags: [pickFallback(FALLBACK_TAG_CANDIDATES, randomFn), 'teamwork'],
    ageRating: '6+',
  };
}

/**
 * Builds the prompt asking the model to pick recommended book IDs for a
 * child's personality traits, from a fixed candidate list.
 */
function buildRecommendationPrompt(topTraits, availableBooks) {
  const bookLines = availableBooks
    .map((book) => `ID: ${book.id} | "${book.title}" by ${book.author} | Age: ${book.ageRating} | Traits: [${book.traits.join(', ')}]`)
    .join('\n');

  return `You are recommending books for a child with these personality traits: ${topTraits.join(', ')}.

Match books whose traits align with the child's personality.

Available Books:
${bookLines}

Instructions:
1. Recommend 3-5 books from the available list that best match the user's traits and interests
2. Prioritize books that align with the user's preferred traits: ${topTraits.join(', ')}
3. Only recommend books from the provided list
4. Order recommendations by relevance (best match first)
5. IMPORTANT: Return the book IDs (the alphanumeric codes like "1401v39Y2u55ILCuHtDk"), NOT the titles

Return ONLY a valid JSON array of book IDs in order of recommendation:
Example: ["1401v39Y2u55ILCuHtDk", "21v8kQj1tnVtqOdXKuvc", "3MbYQantsdJkyGI6jRb5"]`;
}

/**
 * Parses the recommendation model's response and — critically — filters the
 * returned IDs down to ones that actually exist in `availableBooks`. Without
 * this, a hallucinated or stale ID would silently produce a broken
 * recommendation (a book that fails to load, or an ID collision).
 *
 * Never throws: an unparseable response yields an empty recommendation list
 * (the caller falls back to rule-based matching), matching current behavior.
 *
 * @param {string} content Raw AI message content.
 * @param {Array<{id: string}>} availableBooks
 * @returns {string[]} Valid, order-preserved book IDs.
 */
function parseRecommendationResponse(content, availableBooks) {
  let recommendedIds;
  try {
    recommendedIds = extractJsonFromAiContent(content, 'array');
  } catch (e) {
    return [];
  }
  if (!Array.isArray(recommendedIds)) return [];

  const availableIds = new Set(availableBooks.map((book) => book.id));
  return recommendedIds.filter((id) => availableIds.has(id));
}

/**
 * Builds the prompt asking the model to write a 5-question comprehension
 * quiz for a book a child just finished.
 */
function buildQuizPrompt(title, author, bookText) {
  return `You are creating a fun, engaging reading comprehension quiz for children who just finished reading a book.

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
}

/**
 * Validates a parsed quiz array's shape: non-empty, and every question has
 * a question string, exactly 4 options, and an in-range correctAnswer
 * index. Throws with a descriptive message on the first problem found —
 * this is what stands between a malformed AI response and a broken quiz
 * being saved to Firestore and served to a child.
 *
 * @param {any} quiz Parsed JSON value (expected to be an array).
 * @returns {Array} The same array, if valid.
 * @throws {Error} If the shape is invalid.
 */
function validateQuizFormat(quiz) {
  if (!Array.isArray(quiz) || quiz.length === 0) {
    throw new Error('Quiz must be a non-empty array');
  }

  for (const q of quiz) {
    if (
      !q.question ||
      !q.options ||
      !Array.isArray(q.options) ||
      typeof q.correctAnswer !== 'number' ||
      q.options.length !== 4 ||
      q.correctAnswer < 0 ||
      q.correctAnswer > 3
    ) {
      throw new Error('Invalid quiz question format');
    }
  }

  return quiz;
}

module.exports = {
  ALLOWED_TAGS,
  ALLOWED_TRAITS,
  ALLOWED_AGES,
  FALLBACK_TAG_CANDIDATES,
  FALLBACK_TRAIT_CANDIDATES,
  extractJsonFromAiContent,
  buildTaggingPrompt,
  parseAndValidateTaggingResponse,
  fallbackTaggingResult,
  pickFallback,
  buildRecommendationPrompt,
  parseRecommendationResponse,
  buildQuizPrompt,
  validateQuizFormat,
};
