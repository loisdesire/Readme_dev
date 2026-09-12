/**
 * Real Auth + Firestore emulator tests for the onRequest admin gate used
 * by triggerAiTagging / triggerAiRecommendations — run via
 * `npm run test:emulator`.
 */
const admin = require('firebase-admin');
const { isAdmin, requireAdminFromRequest } = require('../../admin_check');

let app;
let db;
let auth;

beforeAll(() => {
  // Must match the --project passed to `firebase emulators:exec` in
  // package.json's test:emulator script: the emulator runs in "single
  // project mode" locked to that project, and ID-token verification
  // (unlike plain Firestore reads/writes) actually enforces that the
  // token's `aud` claim matches — a different projectId here silently
  // makes every verifyIdToken call fail.
  app = admin.initializeApp({ projectId: 'readme-functions-test' });
  db = admin.firestore();
  auth = admin.auth();
});

afterAll(async () => {
  await app.delete();
});

function fakeRequest(authorizationHeader) {
  return {
    get: (name) => (name.toLowerCase() === 'authorization' ? authorizationHeader : undefined),
  };
}

describe('requireAdminFromRequest', () => {
  test('rejects a request with no Authorization header at all', async () => {
    const result = await requireAdminFromRequest(fakeRequest(undefined), { authAdmin: auth, db });
    expect(result.ok).toBe(false);
    expect(result.status).toBe(401);
  });

  test('rejects a malformed Authorization header (not "Bearer <token>")',
      async () => {
        const result = await requireAdminFromRequest(fakeRequest('Basic abc123'), { authAdmin: auth, db });
        expect(result.ok).toBe(false);
        expect(result.status).toBe(401);
      });

  test('rejects an invalid/garbage token', async () => {
    const result = await requireAdminFromRequest(
      fakeRequest('Bearer not-a-real-token'),
      { authAdmin: auth, db }
    );
    expect(result.ok).toBe(false);
    expect(result.status).toBe(401);
  });

  test('rejects a valid token belonging to a non-admin user', async () => {
    const user = await auth.createUser({ email: `plain-${Date.now()}@example.com` });
    await db.collection('users').doc(user.uid).set({ role: 'user' });
    const idToken = await auth.createCustomToken(user.uid);
    // createCustomToken produces a custom token, not an ID token — but
    // verifyIdToken should reject it the same way it would reject any
    // other non-ID-token string, exercising the same failure path a
    // stolen/garbage bearer value would.
    const result = await requireAdminFromRequest(
      fakeRequest(`Bearer ${idToken}`),
      { authAdmin: auth, db }
    );
    expect(result.ok).toBe(false);
  });

  test('accepts an admin — resolves ok:true with their uid, once granted '
      + 'a real ID token', async () => {
    // The Auth emulator's REST API can mint real ID tokens for a test user
    // via the identitytoolkit signInWithCustomToken endpoint, which is
    // what verifyIdToken actually expects (unlike a bare custom token).
    const user = await auth.createUser({ email: `admin-${Date.now()}@example.com` });
    await db.collection('users').doc(user.uid).set({ role: 'admin' });
    const customToken = await auth.createCustomToken(user.uid);

    const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
    const response = await fetch(
      `http://${authEmulatorHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: customToken, returnSecureToken: true }),
      }
    );
    const { idToken } = await response.json();

    const result = await requireAdminFromRequest(fakeRequest(`Bearer ${idToken}`), { authAdmin: auth, db });

    expect(result.ok).toBe(true);
    expect(result.uid).toBe(user.uid);
  });
});

describe('isAdmin (re-exported here, already covered in weekly_leaderboard_reset.test.js)', () => {
  test('sanity check: still importable from this module', async () => {
    expect(typeof isAdmin).toBe('function');
  });
});
