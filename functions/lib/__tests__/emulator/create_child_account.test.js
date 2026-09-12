/**
 * Real Admin SDK calls against the Auth + Firestore emulators — run via
 * `npm run test:emulator` (needs `firebase emulators:exec`, not plain jest).
 */
const admin = require('firebase-admin');
const {
  createChildAccountHandler,
  ValidationError,
  AuthorizationError,
} = require('../../create_child_account');

let app;
let db;
let auth;

beforeAll(() => {
  app = admin.initializeApp({ projectId: 'readme-functions-test' });
  db = admin.firestore();
  auth = admin.auth();
});

afterAll(async () => {
  await app.delete();
});

// `callerUid` defaults to matching `parentId` — the legitimate case, where
// a signed-in parent creates a child under their own account. Tests that
// specifically exercise the authorization check pass a different value.
function deps(callerUid) {
  return { auth, db, FieldValue: admin.firestore.FieldValue, callerUid };
}

// Unique email per test run so re-runs against a warm emulator don't collide.
function uniqueEmail(label) {
  return `${label}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
}

describe('createChildAccountHandler', () => {
  test('creates the Auth user, the Firestore profile, and links the child '
      + "into the parent's children array", async () => {
    const parentId = `parent-${Date.now()}`;
    await db.collection('users').doc(parentId).set({ username: 'Parent', children: [] });

    const email = uniqueEmail('kid');
    const result = await createChildAccountHandler(
      { email, password: 'password123', username: 'Kiddo', parentId },
      deps(parentId)
    );

    expect(result.success).toBe(true);
    expect(result.childId).toBeTruthy();

    const authUser = await auth.getUser(result.childId);
    expect(authUser.email).toBe(email);
    expect(authUser.displayName).toBe('Kiddo');

    const childDoc = await db.collection('users').doc(result.childId).get();
    expect(childDoc.exists).toBe(true);
    const data = childDoc.data();
    expect(data.accountType).toBe('child');
    expect(data.parentId).toBe(parentId); // legacy singular field, by design
    expect(data.hasCompletedQuiz).toBe(false);
    expect(data.personalityTraits).toEqual([]);
    expect(data.isRemoved).toBe(false);

    const parentDoc = await db.collection('users').doc(parentId).get();
    expect(parentDoc.data().children).toContain(result.childId);
  });

  test('a missing required field throws a ValidationError with the field '
      + 'list in its message (not a generic/internal-looking error)', async () => {
    await expect(
      createChildAccountHandler(
        { email: uniqueEmail('nopass'), username: 'X', parentId: 'p1' }, // no password
        deps('p1')
      )
    ).rejects.toThrow(ValidationError);

    await expect(
      createChildAccountHandler({}, deps(undefined))
    ).rejects.toThrow(/email, password, username, parentId/);
  });

  test('does not create an Auth user when validation fails', async () => {
    const email = uniqueEmail('shouldnotexist');
    await expect(
      createChildAccountHandler({ email, username: 'X', parentId: 'p1' }, deps('p1'))
    ).rejects.toThrow(ValidationError);

    await expect(auth.getUserByEmail(email)).rejects.toThrow();
  });

  test('a duplicate email surfaces the underlying Auth error, not a '
      + 'ValidationError — the caller (index.js) maps this to internal',
  async () => {
    const parentId = `parent-${Date.now()}-dup`;
    await db.collection('users').doc(parentId).set({ username: 'Parent', children: [] });
    const email = uniqueEmail('dup');

    await createChildAccountHandler(
      { email, password: 'password123', username: 'First', parentId },
      deps(parentId)
    );

    await expect(
      createChildAccountHandler(
        { email, password: 'password123', username: 'Second', parentId },
        deps(parentId)
      )
    ).rejects.not.toThrow(ValidationError);
  });

  test('documents current behavior for a parentId that does not exist: '
      + 'the Auth user and child profile are still created, but the parent '
      + 'update fails (the child is left unlinked) — worth knowing, not '
      + 'necessarily desired', async () => {
    const email = uniqueEmail('orphan');
    await expect(
      createChildAccountHandler(
        { email, password: 'password123', username: 'Orphan', parentId: 'no-such-parent' },
        deps('no-such-parent')
      )
    ).rejects.toThrow();

    // The child account exists despite the overall call rejecting —
    // a caller retrying naively could create duplicate child accounts.
    const created = await auth.getUserByEmail(email);
    expect(created).toBeTruthy();
  });

  describe('authorization (SECURITY: previously unchecked entirely)', () => {
    test('a caller cannot create a child account under someone else\'s '
        + 'parentId', async () => {
      const realParentId = `parent-${Date.now()}-real`;
      const attackerUid = `attacker-${Date.now()}`;
      await db.collection('users').doc(realParentId).set({ username: 'Real Parent', children: [] });

      const email = uniqueEmail('attacker-attempt');
      await expect(
        createChildAccountHandler(
          { email, password: 'password123', username: 'Sneaky', parentId: realParentId },
          deps(attackerUid) // signed in as someone else entirely
        )
      ).rejects.toThrow(AuthorizationError);

      // Nothing should have been created, and the real parent's children
      // array must be untouched.
      await expect(auth.getUserByEmail(email)).rejects.toThrow();
      const realParentDoc = await db.collection('users').doc(realParentId).get();
      expect(realParentDoc.data().children).toEqual([]);
    });

    test('an unauthenticated caller (no callerUid at all) is rejected',
        async () => {
          const parentId = `parent-${Date.now()}-anon`;
          await db.collection('users').doc(parentId).set({ username: 'Parent', children: [] });

          await expect(
            createChildAccountHandler(
              { email: uniqueEmail('anon'), password: 'password123', username: 'X', parentId },
              deps(undefined)
            )
          ).rejects.toThrow(AuthorizationError);
        });

    test('validation errors are still checked before authorization — a '
        + 'caller gets told about a missing field even if they also aren\'t '
        + 'authorized', async () => {
      await expect(
        createChildAccountHandler(
          { username: 'X', parentId: 'someone-elses-id' }, // no email/password
          deps('attacker-uid')
        )
      ).rejects.toThrow(ValidationError);
    });
  });
});
