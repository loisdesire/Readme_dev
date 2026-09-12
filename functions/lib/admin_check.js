/**
 * Shared admin-check logic. `isAdmin` matches the convention used
 * everywhere else in the app (firestore.rules, admin_portal_screen.dart):
 * `users/{uid}.role == 'admin'`, falling back to the `admins/{uid}` doc.
 */

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string|null|undefined} uid
 * @returns {Promise<boolean>}
 */
async function isAdmin(db, uid) {
  if (!uid) return false;

  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists && userDoc.data().role === 'admin') return true;

  const adminDoc = await db.collection('admins').doc(uid).get();
  return adminDoc.exists && adminDoc.data().role === 'admin';
}

/**
 * Verifies the `Authorization: Bearer <idToken>` header on a plain HTTP
 * (`onRequest`) request and checks the token's owner is an admin.
 * `onCall` functions get `request.auth` for free from the SDK; `onRequest`
 * functions (raw HTTP, called here via a hardcoded Cloud Run URL from the
 * admin panel) get no such thing automatically, so this exists as the
 * `onRequest` equivalent. Never throws — callers respond directly using
 * the returned status/message.
 *
 * @param {{get?: Function, headers?: Record<string,string>}} req Express-like request.
 * @param {{authAdmin: import('firebase-admin').auth.Auth, db: FirebaseFirestore.Firestore}} deps
 * @returns {Promise<{ok: true, uid: string} | {ok: false, status: number, message: string}>}
 */
async function requireAdminFromRequest(req, { authAdmin, db }) {
  const header = typeof req.get === 'function'
    ? req.get('authorization')
    : (req.headers && (req.headers.authorization || req.headers.Authorization));

  const match = header && header.match(/^Bearer (.+)$/i);
  if (!match) {
    return { ok: false, status: 401, message: 'Missing Authorization: Bearer <idToken> header.' };
  }

  let decoded;
  try {
    decoded = await authAdmin.verifyIdToken(match[1]);
  } catch (e) {
    return { ok: false, status: 401, message: 'Invalid or expired ID token.' };
  }

  if (!(await isAdmin(db, decoded.uid))) {
    return { ok: false, status: 403, message: 'Admin privileges required.' };
  }

  return { ok: true, uid: decoded.uid };
}

module.exports = { isAdmin, requireAdminFromRequest };
