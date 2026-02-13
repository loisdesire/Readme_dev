const admin = require('firebase-admin');

// One-time admin script to ensure Firestore achievement definitions match app defaults.
//
// Usage:
//   node tools/sync_achievements.js            (dry run)
//   node tools/sync_achievements.js --apply    (write changes)

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://readmev2.firebaseio.com',
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

function hasFlag(flag) {
  return process.argv.includes(flag);
}

function pick(obj, keys) {
  const out = {};
  for (const k of keys) out[k] = obj[k];
  return out;
}

function normalizeString(v) {
  if (v == null) return '';
  return String(v);
}

function shallowEqual(a, b) {
  const keys = Object.keys(a);
  for (const k of keys) {
    if (a[k] !== b[k]) return false;
  }
  return true;
}

const ACHIEVEMENTS = [
  // Reading achievements
  {
    id: 'first_book',
    name: 'First Book',
    description: 'Finish 1 book',
    emoji: 'book',
    category: 'reading',
    requiredValue: 1,
    type: 'books_read',
    points: 3,
  },
  {
    id: 'three_books',
    name: 'Story Explorer',
    description: 'Finish 3 books',
    emoji: 'menu_book',
    category: 'reading',
    requiredValue: 3,
    type: 'books_read',
    points: 5,
  },
  {
    id: 'book_lover',
    name: 'Book Lover',
    description: 'Finish 5 books',
    emoji: 'favorite',
    category: 'reading',
    requiredValue: 5,
    type: 'books_read',
    points: 7,
  },
  {
    id: 'bookworm',
    name: 'Bookworm',
    description: 'Finish 10 books',
    emoji: 'auto_stories',
    category: 'reading',
    requiredValue: 10,
    type: 'books_read',
    points: 10,
  },
  {
    id: 'fifteen_books',
    name: 'Super Reader',
    description: 'Finish 15 books',
    emoji: 'import_contacts',
    category: 'reading',
    requiredValue: 15,
    type: 'books_read',
    points: 14,
  },
  {
    id: 'twenty_books',
    name: 'Reading Star',
    description: 'Finish 20 books',
    emoji: 'library_books',
    category: 'reading',
    requiredValue: 20,
    type: 'books_read',
    points: 18,
  },
  {
    id: 'thirty_books',
    name: 'Book Champion',
    description: 'Finish 30 books',
    emoji: 'star',
    category: 'reading',
    requiredValue: 30,
    type: 'books_read',
    points: 25,
  },
  {
    id: 'forty_books',
    name: 'Reading Hero',
    description: 'Finish 40 books',
    emoji: 'emoji_events',
    category: 'reading',
    requiredValue: 40,
    type: 'books_read',
    points: 30,
  },
  {
    id: 'fifty_books',
    name: 'Book Master',
    description: 'Finish 50 books',
    emoji: 'stars',
    category: 'reading',
    requiredValue: 50,
    type: 'books_read',
    points: 35,
  },
  {
    id: 'seventyfive_books',
    name: 'Reading Genius',
    description: 'Finish 75 books',
    emoji: 'workspace_premium',
    category: 'reading',
    requiredValue: 75,
    type: 'books_read',
    points: 45,
  },
  {
    id: 'hundred_books',
    name: 'Book Wizard',
    description: 'Finish 100 books',
    emoji: 'military_tech',
    category: 'reading',
    requiredValue: 100,
    type: 'books_read',
    points: 55,
  },
  {
    id: 'hundred_fifty_books',
    name: 'Reading Legend',
    description: 'Finish 150 books',
    emoji: 'diamond',
    category: 'reading',
    requiredValue: 150,
    type: 'books_read',
    points: 70,
  },
  {
    id: 'twohundred_books',
    name: 'Ultimate Reader',
    description: 'Finish 200 books',
    emoji: 'crown',
    category: 'reading',
    requiredValue: 200,
    type: 'books_read',
    points: 90,
  },

  // Streak achievements
  {
    id: 'streak_starter',
    name: 'Streak Starter',
    description: 'Read 3 days in a row',
    emoji: 'local_fire_department',
    category: 'streak',
    requiredValue: 3,
    type: 'reading_streak',
    points: 3,
  },
  {
    id: 'five_day_streak',
    name: 'Week Warrior',
    description: 'Read 7 days in a row',
    emoji: 'whatshot',
    category: 'streak',
    requiredValue: 7,
    type: 'reading_streak',
    points: 5,
  },
  {
    id: 'two_week_streak',
    name: 'Two Week Streak',
    description: 'Read 14 days in a row',
    emoji: 'done_outline',
    category: 'streak',
    requiredValue: 14,
    type: 'reading_streak',
    points: 8,
  },
  {
    id: 'three_week_streak',
    name: 'Monthly Reader',
    description: 'Read 30 days in a row',
    emoji: 'power_settings_new',
    category: 'streak',
    requiredValue: 30,
    type: 'reading_streak',
    points: 12,
  },
  {
    id: 'month_master',
    name: 'Streak Master',
    description: 'Read 60 days in a row',
    emoji: 'flash_on',
    category: 'streak',
    requiredValue: 60,
    type: 'reading_streak',
    points: 18,
  },
  {
    id: 'fifty_day_streak',
    name: 'Century Streak',
    description: 'Read 100 days in a row',
    emoji: 'star_border',
    category: 'streak',
    requiredValue: 100,
    type: 'reading_streak',
    points: 25,
  },

  // Time achievements
  {
    id: 'half_hour_reader',
    name: 'Quick Start',
    description: 'Read for 5 minutes total',
    emoji: 'schedule',
    category: 'time',
    requiredValue: 5,
    type: 'reading_time',
    points: 1,
  },
  {
    id: 'hour_hero',
    name: 'Warm-Up Reader',
    description: 'Read for 15 minutes total',
    emoji: 'flash_on',
    category: 'time',
    requiredValue: 15,
    type: 'reading_time',
    points: 2,
  },
  {
    id: 'two_hour_reader',
    name: 'Half-Hour Hero',
    description: 'Read for 30 minutes total',
    emoji: 'rocket_launch',
    category: 'time',
    requiredValue: 30,
    type: 'reading_time',
    points: 3,
  },
  {
    id: 'time_traveler',
    name: 'One-Hour Reader',
    description: 'Read for 60 minutes total',
    emoji: 'sunny',
    category: 'time',
    requiredValue: 60,
    type: 'reading_time',
    points: 5,
  },
  {
    id: 'marathon_reader',
    name: 'Two-Hour Reader',
    description: 'Read for 2 hours total',
    emoji: 'brightness_7',
    category: 'time',
    requiredValue: 120,
    type: 'reading_time',
    points: 8,
  },
  {
    id: 'time_master',
    name: 'Five-Hour Reader',
    description: 'Read for 5 hours total',
    emoji: 'nights_stay',
    category: 'time',
    requiredValue: 300,
    type: 'reading_time',
    points: 12,
  },
  {
    id: 'time_champion',
    name: 'Ten-Hour Champion',
    description: 'Read for 10 hours total',
    emoji: 'celebration',
    category: 'time',
    requiredValue: 600,
    type: 'reading_time',
    points: 18,
  },

  // Reading session achievements (only sessions 2+ minutes count)
  {
    id: 'first_session',
    name: 'First Reading!',
    description: 'Read for 2 minutes',
    emoji: 'play_circle',
    category: 'sessions',
    requiredValue: 1,
    type: 'reading_sessions',
    points: 2,
  },
  {
    id: 'five_sessions',
    name: 'Reading Buddy',
    description: 'Read 3 times',
    emoji: 'play_arrow',
    category: 'sessions',
    requiredValue: 3,
    type: 'reading_sessions',
    points: 5,
  },
  {
    id: 'session_starter',
    name: 'Getting the Hang of It',
    description: 'Read 7 times',
    emoji: 'favorite_border',
    category: 'sessions',
    requiredValue: 7,
    type: 'reading_sessions',
    points: 8,
  },
  {
    id: 'regular_reader',
    name: 'Regular Reader',
    description: 'Read 15 times',
    emoji: 'verified_user',
    category: 'sessions',
    requiredValue: 15,
    type: 'reading_sessions',
    points: 12,
  },
  {
    id: 'dedicated_reader',
    name: 'Dedicated Reader',
    description: 'Read 30 times',
    emoji: 'star_outline',
    category: 'sessions',
    requiredValue: 30,
    type: 'reading_sessions',
    points: 18,
  },
  {
    id: 'session_master',
    name: 'Super Regular',
    description: 'Read 50 times',
    emoji: 'badge',
    category: 'sessions',
    requiredValue: 50,
    type: 'reading_sessions',
    points: 25,
  },
  {
    id: 'session_champion',
    name: 'Reading Champ',
    description: 'Read 75 times',
    emoji: 'card_giftcard',
    category: 'sessions',
    requiredValue: 75,
    type: 'reading_sessions',
    points: 30,
  },
];

async function syncAchievements() {
  const apply = hasFlag('--apply');

  console.log('🔧 Sync achievement definitions');
  console.log(`   Project: ${serviceAccount.project_id}`);
  console.log(`   Mode: ${apply ? 'APPLY' : 'DRY RUN'}`);
  console.log(`   Target: collection(achievements) upsert ${ACHIEVEMENTS.length} docs`);
  console.log('');

  // Basic validation
  const seen = new Set();
  for (const a of ACHIEVEMENTS) {
    if (!a.id || !normalizeString(a.id).trim()) {
      throw new Error('Achievement missing id');
    }
    if (seen.has(a.id)) {
      throw new Error(`Duplicate achievement id: ${a.id}`);
    }
    seen.add(a.id);
  }

  const existingSnap = await db.collection('achievements').get();
  const existingById = new Map(existingSnap.docs.map((d) => [d.id, d.data()]));

  const keysToCompare = [
    'id',
    'name',
    'description',
    'emoji',
    'category',
    'requiredValue',
    'type',
    'points',
  ];

  let willCreate = 0;
  let willUpdate = 0;
  const updates = [];

  for (const a of ACHIEVEMENTS) {
    const ref = db.collection('achievements').doc(a.id);
    const desired = { ...a, id: a.id };

    const currentRaw = existingById.get(a.id);
    if (!currentRaw) {
      willCreate++;
      updates.push({ ref, id: a.id, desired, action: 'create' });
      continue;
    }

    const current = pick({ id: a.id, ...currentRaw }, keysToCompare);
    const desiredComparable = pick(desired, keysToCompare);

    if (!shallowEqual(current, desiredComparable)) {
      willUpdate++;
      updates.push({ ref, id: a.id, desired, action: 'update', current });
    }
  }

  console.log(`📦 Existing docs: ${existingSnap.size}`);
  console.log(`🆕 Would create: ${willCreate}`);
  console.log(`✏️  Would update: ${willUpdate}`);
  console.log('');

  if (!apply) {
    console.log('Dry run complete. To apply changes:');
    console.log('  node tools/sync_achievements.js --apply');
    console.log('');

    const sample = updates.slice(0, 10);
    if (sample.length) {
      console.log('Sample changes (first 10):');
      for (const u of sample) {
        console.log(`  - ${u.action.toUpperCase()} ${u.id}`);
      }
    }

    return;
  }

  // Batch in chunks (<= 500 ops)
  const batchSize = 450;
  let written = 0;

  for (let i = 0; i < ACHIEVEMENTS.length; i += batchSize) {
    const chunk = ACHIEVEMENTS.slice(i, i + batchSize);
    const batch = db.batch();

    for (const a of chunk) {
      const ref = db.collection('achievements').doc(a.id);
      batch.set(ref, { ...a, id: a.id }, { merge: true });
    }

    await batch.commit();
    written += chunk.length;
    console.log(`✅ Committed ${written}/${ACHIEVEMENTS.length} achievement definitions...`);
  }

  console.log('');
  console.log('🎉 Sync complete');
}

syncAchievements()
  .then(async () => {
    await admin.app().delete();
    process.exit(0);
  })
  .catch(async (err) => {
    console.error('❌ Error:', err);
    try {
      await admin.app().delete();
    } catch (_) {}
    process.exit(1);
  });
