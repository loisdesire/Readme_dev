// tools/audit_tagging_sanity.js
// Sanity-checks Firestore `books` and `users` for trait/tag vocabulary consistency.
// Usage (PowerShell): node .\tools\audit_tagging_sanity.js

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK using local service account.
// Intentionally omit projectId/storageBucket to avoid hardcoding the wrong project.
let db;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  db = admin.firestore();
} catch (e) {
  console.error('❌ Failed to initialize Firebase Admin SDK.');
  console.error('   Ensure tools/serviceAccountKey.json exists and is valid.');
  console.error(String(e));
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

// Canonical age ratings seen in app UI.
const CANONICAL_AGE_RATINGS = ['6+', '7+', '8+', '9+', '10+', '12+'];

function normalizeString(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed.toLowerCase() : null;
}

function normalizeStringList(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map(normalizeString)
    .filter((v) => typeof v === 'string' && v.length > 0);
}

function incr(map, key, by = 1) {
  map.set(key, (map.get(key) || 0) + by);
}

function topEntries(map, limit = 20) {
  return [...map.entries()].sort((a, b) => b[1] - a[1]).slice(0, limit);
}

async function auditBooks() {
  console.log('📚 Auditing books…');

  const canonicalTraitsSet = new Set(CANONICAL_TRAITS);
  const canonicalAgeSet = new Set(CANONICAL_AGE_RATINGS);

  const traitFreq = new Map();
  const unknownTraitFreq = new Map();
  const tagFreq = new Map();
  const ageFreq = new Map();

  let total = 0;
  let needsTagging = 0;
  let missingTraits = 0;
  let missingTags = 0;
  let invalidAge = 0;
  let hasUnknownTraits = 0;
  let tooManyTraits = 0;

  const examples = {
    missingTraits: [],
    missingTags: [],
    invalidAge: [],
    unknownTraits: [],
  };

  const snap = await db.collection('books').get();
  for (const doc of snap.docs) {
    total++;
    const data = doc.data() || {};

    const title = typeof data.title === 'string' ? data.title : '';

    const traits = normalizeStringList(data.traits);
    const tags = normalizeStringList(data.tags);
    const ageRating = normalizeString(data.ageRating);

    if (data.needsTagging === true) needsTagging++;

    if (traits.length === 0) {
      missingTraits++;
      if (examples.missingTraits.length < 10) {
        examples.missingTraits.push({ id: doc.id, title });
      }
    }

    if (tags.length === 0) {
      missingTags++;
      if (examples.missingTags.length < 10) {
        examples.missingTags.push({ id: doc.id, title });
      }
    }

    if (!ageRating || !canonicalAgeSet.has(ageRating)) {
      invalidAge++;
      if (examples.invalidAge.length < 10) {
        examples.invalidAge.push({ id: doc.id, title, ageRating: data.ageRating });
      }
    } else {
      incr(ageFreq, ageRating);
    }

    if (traits.length > 5) {
      tooManyTraits++;
    }

    const unknownTraits = [];
    for (const t of traits) {
      incr(traitFreq, t);
      if (!canonicalTraitsSet.has(t)) {
        unknownTraits.push(t);
        incr(unknownTraitFreq, t);
      }
    }

    for (const tag of tags) {
      incr(tagFreq, tag);
    }

    if (unknownTraits.length > 0) {
      hasUnknownTraits++;
      if (examples.unknownTraits.length < 10) {
        examples.unknownTraits.push({ id: doc.id, title, unknownTraits });
      }
    }
  }

  console.log('\n** Books summary **');
  console.log(`Total books: ${total}`);
  console.log(`needsTagging==true: ${needsTagging}`);
  console.log(`Missing traits: ${missingTraits}`);
  console.log(`Missing tags: ${missingTags}`);
  console.log(`Invalid/unknown ageRating: ${invalidAge}`);
  console.log(`Books with unknown traits: ${hasUnknownTraits}`);
  console.log(`Books with >5 traits: ${tooManyTraits}`);

  console.log('\nTop traits (all):');
  for (const [trait, count] of topEntries(traitFreq, 20)) {
    console.log(`- ${trait}: ${count}`);
  }

  console.log('\nTop UNKNOWN traits (not in canonical quiz set):');
  const unknownTop = topEntries(unknownTraitFreq, 30);
  if (unknownTop.length === 0) {
    console.log('- (none)');
  } else {
    for (const [trait, count] of unknownTop) {
      console.log(`- ${trait}: ${count}`);
    }
  }

  console.log('\nAge ratings distribution (canonical-only):');
  for (const [age, count] of topEntries(ageFreq, 20)) {
    console.log(`- ${age}: ${count}`);
  }

  console.log('\nTop tags:');
  for (const [tag, count] of topEntries(tagFreq, 25)) {
    console.log(`- ${tag}: ${count}`);
  }

  if (examples.missingTraits.length) {
    console.log('\nExamples: missing traits');
    examples.missingTraits.forEach((b) => console.log(`- ${b.id} ${b.title ? `(${b.title})` : ''}`));
  }

  if (examples.unknownTraits.length) {
    console.log('\nExamples: unknown traits');
    examples.unknownTraits.forEach((b) => console.log(`- ${b.id} ${b.title ? `(${b.title})` : ''} -> ${b.unknownTraits.join(', ')}`));
  }

  if (examples.invalidAge.length) {
    console.log('\nExamples: invalid ageRating');
    examples.invalidAge.forEach((b) => console.log(`- ${b.id} ${b.title ? `(${b.title})` : ''} -> ${String(b.ageRating)}`));
  }

  return {
    total,
    needsTagging,
    missingTraits,
    missingTags,
    invalidAge,
    hasUnknownTraits,
    tooManyTraits,
    unknownTraitFreq: Object.fromEntries(unknownTraitFreq),
  };
}

async function auditUsers(limit = null) {
  console.log('\n👤 Auditing users…');

  const canonicalTraitsSet = new Set(CANONICAL_TRAITS);
  const userTraitFreq = new Map();
  const unknownUserTraitFreq = new Map();

  let total = 0;
  let hasCompletedQuiz = 0;
  let missingPersonalityTraits = 0;
  let usersWithUnknownTraits = 0;

  let query = db.collection('users');
  if (typeof limit === 'number') query = query.limit(limit);

  const snap = await query.get();
  for (const doc of snap.docs) {
    total++;
    const data = doc.data() || {};

    if (data.hasCompletedQuiz === true) hasCompletedQuiz++;

    const traits = normalizeStringList(data.personalityTraits);
    if (traits.length === 0) {
      missingPersonalityTraits++;
      continue;
    }

    let hasUnknown = false;
    for (const t of traits) {
      incr(userTraitFreq, t);
      if (!canonicalTraitsSet.has(t)) {
        hasUnknown = true;
        incr(unknownUserTraitFreq, t);
      }
    }

    if (hasUnknown) usersWithUnknownTraits++;
  }

  console.log('\n** Users summary **');
  console.log(`Total users scanned: ${total}`);
  console.log(`hasCompletedQuiz==true: ${hasCompletedQuiz}`);
  console.log(`Missing/empty personalityTraits: ${missingPersonalityTraits}`);
  console.log(`Users with unknown traits: ${usersWithUnknownTraits}`);

  console.log('\nTop user traits:');
  for (const [trait, count] of topEntries(userTraitFreq, 20)) {
    console.log(`- ${trait}: ${count}`);
  }

  console.log('\nTop UNKNOWN user traits (not in canonical quiz set):');
  const unknownTop = topEntries(unknownUserTraitFreq, 30);
  if (unknownTop.length === 0) {
    console.log('- (none)');
  } else {
    for (const [trait, count] of unknownTop) {
      console.log(`- ${trait}: ${count}`);
    }
  }

  return {
    total,
    hasCompletedQuiz,
    missingPersonalityTraits,
    usersWithUnknownTraits,
    unknownUserTraitFreq: Object.fromEntries(unknownUserTraitFreq),
  };
}

async function main() {
  try {
    const books = await auditBooks();
    const users = await auditUsers();

    console.log('\n✅ Audit complete');

    // Exit code: non-zero if we find clear vocabulary drift.
    const hasVocabDrift =
      books.hasUnknownTraits > 0 || users.usersWithUnknownTraits > 0;
    process.exit(hasVocabDrift ? 2 : 0);
  } catch (e) {
    console.error('❌ Audit failed');
    console.error(String(e));
    process.exit(1);
  }
}

main();
