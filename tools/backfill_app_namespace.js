const admin = require('firebase-admin');

// Initialize Firebase Admin for readmev2
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://readmev2.firebaseio.com',
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

function getArgValue(prefix) {
  const arg = process.argv.find((a) => a.startsWith(prefix));
  if (!arg) return null;
  const [, value] = arg.split('=');
  return value ?? null;
}

function hasFlag(flag) {
  return process.argv.includes(flag);
}

async function backfillAppNamespace() {
  const namespace = getArgValue('--namespace') || 'readme_dev';
  const apply = hasFlag('--apply');
  const limitStr = getArgValue('--limit');
  const accountType = getArgValue('--accountType') || 'child'; // child | all

  const limit = limitStr ? Math.max(1, parseInt(limitStr, 10)) : null;

  console.log('🔧 Backfill user app namespace');
  console.log(`   Project: ${serviceAccount.project_id}`);
  console.log(`   Namespace: ${namespace}`);
  console.log(`   AccountType filter: ${accountType}`);
  console.log(`   Mode: ${apply ? 'APPLY' : 'DRY RUN'}`);
  if (limit != null) console.log(`   Limit: ${limit}`);
  console.log('');

  const field = 'appNamespace';

  let query = db.collection('users');
  if (accountType !== 'all') {
    query = query.where('accountType', '==', accountType);
  }

  const snapshot = await query.get();

  let scanned = 0;
  let alreadyOk = 0;
  let needsUpdate = 0;
  let updated = 0;

  const refsToUpdate = [];

  for (const doc of snapshot.docs) {
    scanned++;

    if (limit != null && refsToUpdate.length >= limit) {
      break;
    }

    const data = doc.data() || {};
    const current = data[field];

    if (current === namespace) {
      alreadyOk++;
      continue;
    }

    // Only backfill missing or different namespace.
    needsUpdate++;
    refsToUpdate.push({ ref: doc.ref, id: doc.id, username: data.username, current });
  }

  console.log(`📊 Scanned: ${scanned}`);
  console.log(`✅ Already OK: ${alreadyOk}`);
  console.log(`🟡 Needs update: ${needsUpdate}${limit != null ? ' (capped by --limit)' : ''}`);
  console.log('');

  if (!apply) {
    console.log('Dry run complete. To apply updates:');
    console.log(`  node tools/backfill_app_namespace.js --apply --namespace=${namespace} --accountType=${accountType}${limit != null ? ` --limit=${limit}` : ''}`);
    console.log('');

    // Print a small sample
    const sample = refsToUpdate.slice(0, 10);
    if (sample.length) {
      console.log('Sample updates (first 10):');
      for (const u of sample) {
        console.log(`  - ${u.username || 'Unknown'} (${u.id}) ${field}: ${u.current || 'null'} -> ${namespace}`);
      }
    }

    return;
  }

  // Apply in batches of 450 to stay under limits (500 ops max).
  const batchSize = 450;
  for (let i = 0; i < refsToUpdate.length; i += batchSize) {
    const chunk = refsToUpdate.slice(i, i + batchSize);
    const batch = db.batch();

    for (const u of chunk) {
      batch.set(u.ref, { [field]: namespace }, { merge: true });
    }

    await batch.commit();
    updated += chunk.length;
    console.log(`✅ Committed ${updated}/${refsToUpdate.length} updates...`);
  }

  console.log('');
  console.log('🎉 Backfill complete');
  console.log(`   Updated: ${updated}`);
}

backfillAppNamespace()
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
