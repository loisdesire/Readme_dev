// tools/normalize_traits_and_age.js
// Normalizes Firestore trait vocabulary + ageRating formatting to match the in-app canonical set.
//
// Default is DRY RUN (no writes).
// Usage:
//   node .\tools\normalize_traits_and_age.js
//   node .\tools\normalize_traits_and_age.js --apply

const admin = require('firebase-admin');

let db;
try {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  db = admin.firestore();
} catch (e) {
  console.error('❌ Failed to initialize Firebase Admin SDK.');
  console.error(String(e));
  process.exit(1);
}

const APPLY = process.argv.includes('--apply');

const CANONICAL_TRAITS = [
  'curious', 'creative', 'imaginative',
  'responsible', 'organized', 'persistent',
  'social', 'enthusiastic', 'outgoing',
  'kind', 'cooperative', 'caring',
  'resilient', 'calm', 'positive',
];

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

function normalizeString(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length ? trimmed.toLowerCase() : null;
}

function normalizeTraits(value) {
  const canonical = new Set(CANONICAL_TRAITS);
  const out = new Set();

  const list = Array.isArray(value) ? value : [];
  for (const v of list) {
    const s = normalizeString(v);
    if (!s) continue;
    const mapped = TRAIT_SYNONYMS[s] || s;
    if (canonical.has(mapped)) out.add(mapped);
  }

  return [...out];
}

function normalizeAgeRating(raw) {
  if (raw == null) return null;

  if (typeof raw === 'number') {
    return `${Math.trunc(raw)}+`;
  }

  if (typeof raw === 'string') {
    const s = raw.trim();
    if (!s) return null;
    if (/^\d+$/.test(s)) return `${s}+`;
    return s;
  }

  return null;
}

function arraysEqualAsSets(a, b) {
  const sa = new Set(a);
  const sb = new Set(b);
  if (sa.size !== sb.size) return false;
  for (const v of sa) if (!sb.has(v)) return false;
  return true;
}

async function normalizeCollection({ collectionName, docUpdateFn }) {
  console.log(`\n🔧 Scanning ${collectionName}…`);

  const snap = await db.collection(collectionName).get();
  console.log(`Found ${snap.size} docs`);

  let batch = db.batch();
  let pending = 0;
  let updated = 0;

  for (const doc of snap.docs) {
    const before = doc.data() || {};
    const update = docUpdateFn(before);
    if (!update) continue;

    updated++;

    if (APPLY) {
      batch.update(doc.ref, update);
      pending++;

      if (pending >= 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    } else {
      console.log(`- ${collectionName}/${doc.id} -> ${JSON.stringify(update)}`);
    }
  }

  if (APPLY && pending > 0) {
    await batch.commit();
  }

  console.log(`${APPLY ? 'Applied' : 'Would apply'} updates: ${updated}`);
}

async function main() {
  console.log(APPLY ? '🚨 APPLY MODE: will write to Firestore' : '🧪 DRY RUN: no Firestore writes');

  await normalizeCollection({
    collectionName: 'books',
    docUpdateFn: (data) => {
      const nextTraits = normalizeTraits(data.traits);
      const nextAge = normalizeAgeRating(data.ageRating);

      const currentTraits = Array.isArray(data.traits)
        ? data.traits.map((t) => normalizeString(t)).filter(Boolean)
        : [];

      const traitsChanged = !arraysEqualAsSets(currentTraits, nextTraits);
      const ageChanged = nextAge != null && nextAge !== data.ageRating;

      if (!traitsChanged && !ageChanged) return null;

      const update = {};
      if (traitsChanged) update.traits = nextTraits;
      if (ageChanged) update.ageRating = nextAge;
      return update;
    },
  });

  await normalizeCollection({
    collectionName: 'users',
    docUpdateFn: (data) => {
      const nextTraits = normalizeTraits(data.personalityTraits);

      const currentTraits = Array.isArray(data.personalityTraits)
        ? data.personalityTraits.map((t) => normalizeString(t)).filter(Boolean)
        : [];

      const traitsChanged = !arraysEqualAsSets(currentTraits, nextTraits);
      if (!traitsChanged) return null;

      return { personalityTraits: nextTraits };
    },
  });

  console.log('\n✅ Done');
}

main().catch((e) => {
  console.error('❌ Failed');
  console.error(String(e));
  process.exit(1);
});
