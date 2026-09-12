/**
 * Promote a user to admin — needed now that firestore.rules no longer lets
 * any signed-in client grant themselves `role: 'admin'` (see
 * ../firestore-tests/rules.test.js: "a non-admin cannot grant themselves
 * admin by editing their own role field"). This script uses the Admin SDK,
 * which bypasses security rules entirely, so it's the supported way to
 * create the first admin (and any admin after that).
 *
 * Setup:
 *   1. Firebase Console → Project settings → Service accounts →
 *      "Generate new private key" → save as tools/serviceAccountKey.json
 *      (already gitignored — never commit this file).
 *   2. cd tools && npm install firebase-admin   (if not already installed)
 *
 * Usage:
 *   node tools/set_admin.js <uid-or-email>
 *
 * What it does: sets role:'admin' on users/{uid}, and mirrors the same
 * onto admins/{uid} (the fallback path admin_portal_screen.dart also checks).
 */

const admin = require('firebase-admin');

const target = process.argv[2];
if (!target) {
  console.error('Usage: node tools/set_admin.js <uid-or-email>');
  process.exit(1);
}

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

async function resolveUid(uidOrEmail) {
  if (!uidOrEmail.includes('@')) return uidOrEmail;
  const userRecord = await admin.auth().getUserByEmail(uidOrEmail);
  return userRecord.uid;
}

async function main() {
  const uid = await resolveUid(target);

  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    console.error(`No users/${uid} document found. Double-check the uid/email.`);
    process.exit(1);
  }

  await userRef.set({ role: 'admin' }, { merge: true });
  await db.collection('admins').doc(uid).set({ role: 'admin' }, { merge: true });

  console.log(`✔ ${uid} is now an admin (users/${uid}.role and admins/${uid}.role set to 'admin').`);
  process.exit(0);
}

main().catch((err) => {
  console.error('Failed to set admin:', err);
  process.exit(1);
});
