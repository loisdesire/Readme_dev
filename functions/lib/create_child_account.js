/**
 * Core logic behind the createChildAccount callable, pulled out of index.js
 * so it can be tested against the Auth + Firestore emulators without
 * needing the Functions emulator or a real deployment. Takes its Admin SDK
 * dependencies as parameters instead of reaching for module-level globals.
 */

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Creates a child Firebase Auth account, its Firestore profile, and links
 * it into the parent's `children` array.
 *
 * @param {{email: string, password: string, username: string, parentId: string}} data
 * @param {{auth: import('firebase-admin').auth.Auth, db: FirebaseFirestore.Firestore, FieldValue: typeof import('firebase-admin').firestore.FieldValue}} deps
 * @returns {Promise<{success: true, childId: string, message: string}>}
 * @throws {ValidationError} if a required field is missing.
 */
async function createChildAccountHandler(data, { auth, db, FieldValue }) {
  const { email, password, username, parentId } = data || {};

  if (!email || !password || !username || !parentId) {
    throw new ValidationError(
      'Missing required fields: email, password, username, parentId'
    );
  }

  const userRecord = await auth.createUser({
    email,
    password,
    displayName: username,
  });

  // Legacy singular field — the client (auth_provider.dart) and Firestore
  // rules both fall back to this when a child's `parentIds` array is empty,
  // so this is intentional, not an oversight.
  await db.collection('users').doc(userRecord.uid).set({
    uid: userRecord.uid,
    email,
    username,
    accountType: 'child',
    parentId,
    avatar: '👦',
    createdAt: FieldValue.serverTimestamp(),
    hasCompletedQuiz: false,
    personalityTraits: [],
    children: [],
    isRemoved: false,
  });

  await db.collection('users').doc(parentId).update({
    children: FieldValue.arrayUnion(userRecord.uid),
  });

  return {
    success: true,
    childId: userRecord.uid,
    message: 'Child account created successfully',
  };
}

module.exports = { createChildAccountHandler, ValidationError };
