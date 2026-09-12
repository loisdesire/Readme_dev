const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const { arrayUnion } = require('firebase/firestore');

let testEnv;

const PROJECT_ID = 'readme-rules-test';

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      // `npm test` copies ../firestore.rules here first (see package.json
      // "pretest") so this always exercises the real, deployed rules file.
      rules: fs.readFileSync(path.resolve(__dirname, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Seed data as admin (bypasses rules) so each test starts from known state.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await fn(db);
  });
}

describe('users & admin bootstrap', () => {
  test('signed-out user cannot read anything', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('books').doc('b1').get());
  });

  test('a user can create their own user doc on signup', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    await assertSucceeds(db.collection('users').doc('child1').set({ username: 'kid' }));
  });

  test('a user cannot create a user doc for someone else', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    await assertFails(db.collection('users').doc('child2').set({ username: 'kid' }));
  });

  test('a stranger cannot read another user profile', async () => {
    await seed((db) => db.collection('users').doc('child1').set({ username: 'kid' }));
    const db = testEnv.authenticatedContext('rando').firestore();
    await assertFails(db.collection('users').doc('child1').get());
  });

  test('a linked parent CAN read their child profile', async () => {
    await seed((db) =>
      db.collection('users').doc('child1').set({ username: 'kid', parentIds: ['parent1'] })
    );
    const db = testEnv.authenticatedContext('parent1').firestore();
    await assertSucceeds(db.collection('users').doc('child1').get());
  });

  test('an unlinked parent CANNOT read a different child profile', async () => {
    await seed((db) =>
      db.collection('users').doc('child1').set({ username: 'kid', parentIds: ['parent1'] })
    );
    const db = testEnv.authenticatedContext('parent2').firestore();
    await assertFails(db.collection('users').doc('child1').get());
  });

  test('a non-admin cannot write to admins/ or grant themselves admin', async () => {
    const db = testEnv.authenticatedContext('rando').firestore();
    await assertFails(db.collection('admins').doc('rando').set({ role: 'admin' }));
  });

  test('a non-admin cannot grant themselves admin by editing their own role field', async () => {
    await seed((db) => db.collection('users').doc('sneaky').set({ username: 'x', role: 'user' }));
    const db = testEnv.authenticatedContext('sneaky').firestore();
    await assertFails(db.collection('users').doc('sneaky').update({ role: 'admin' }));
  });

  test('a not-yet-linked parent CAN link themselves to a child via PIN/QR flow', async () => {
    await seed((db) =>
      db.collection('users').doc('child1').set({ accountType: 'child', parentIds: [] })
    );
    const db = testEnv.authenticatedContext('newParent').firestore();
    await assertSucceeds(
      db.collection('users').doc('child1').update({
        parentIds: arrayUnion('newParent'),
      })
    );
  });

  test('the PIN/QR linking path cannot be used to smuggle other field changes', async () => {
    await seed((db) =>
      db.collection('users').doc('child1').set({ accountType: 'child', parentIds: [], role: 'user' })
    );
    const db = testEnv.authenticatedContext('newParent').firestore();
    await assertFails(
      db.collection('users').doc('child1').update({
        parentIds: arrayUnion('newParent'),
        role: 'admin',
      })
    );
  });

  test('a stranger cannot add an arbitrary OTHER uid to a child\'s parentIds', async () => {
    await seed((db) =>
      db.collection('users').doc('child1').set({ accountType: 'child', parentIds: [] })
    );
    const db = testEnv.authenticatedContext('attacker').firestore();
    await assertFails(
      db.collection('users').doc('child1').update({
        parentIds: arrayUnion('someoneElsesUid'),
      })
    );
  });
});

describe('books — the collection that broke last time', () => {
  beforeEach(async () => {
    await seed((db) => db.collection('books').doc('b1').set({ title: 'Test Book' }));
  });

  test('ANY signed-in user (child, parent, freshly-registered) can read books', async () => {
    for (const uid of ['child1', 'parent1', 'brandNewUser']) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(db.collection('books').doc('b1').get());
      await assertSucceeds(db.collection('books').get());
    }
  });

  test('signed-out user cannot read books', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('books').get());
  });

  test('a non-admin cannot create/update/delete books', async () => {
    const db = testEnv.authenticatedContext('rando').firestore();
    await assertFails(db.collection('books').add({ title: 'sneaky' }));
    await assertFails(db.collection('books').doc('b1').update({ title: 'hacked' }));
    await assertFails(db.collection('books').doc('b1').delete());
  });

  test('an admin (via users/{uid}.role) can write books', async () => {
    await seed((db) => db.collection('users').doc('admin1').set({ role: 'admin' }));
    const db = testEnv.authenticatedContext('admin1').firestore();
    await assertSucceeds(db.collection('books').add({ title: 'new book' }));
    await assertSucceeds(db.collection('books').doc('b1').update({ title: 'updated' }));
  });

  test('an admin (via admins/{uid} fallback doc) can write books', async () => {
    await seed((db) => db.collection('admins').doc('admin2').set({ role: 'admin' }));
    const db = testEnv.authenticatedContext('admin2').firestore();
    await assertSucceeds(db.collection('books').add({ title: 'new book 2' }));
  });
});

describe('per-child activity: reading_progress', () => {
  test('a child can create/read their own reading_progress', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    const ref = db.collection('reading_progress').doc('rp1');
    await assertSucceeds(ref.set({ userId: 'child1', bookId: 'b1', currentPage: 3 }));
    await assertSucceeds(ref.get());
  });

  test('a child cannot create reading_progress claiming a different userId', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    await assertFails(
      db.collection('reading_progress').doc('rp2').set({ userId: 'child2', currentPage: 1 })
    );
  });

  test('an unrelated user cannot read another child reading_progress', async () => {
    await seed((db) =>
      db.collection('reading_progress').doc('rp1').set({ userId: 'child1', currentPage: 3 })
    );
    const db = testEnv.authenticatedContext('rando').firestore();
    await assertFails(db.collection('reading_progress').doc('rp1').get());
  });

  test('a linked parent can read but not write child reading_progress', async () => {
    await seed(async (db) => {
      await db.collection('users').doc('child1').set({ parentIds: ['parent1'] });
      await db.collection('reading_progress').doc('rp1').set({ userId: 'child1', currentPage: 3 });
    });
    const db = testEnv.authenticatedContext('parent1').firestore();
    await assertSucceeds(db.collection('reading_progress').doc('rp1').get());
    await assertFails(db.collection('reading_progress').doc('rp1').update({ currentPage: 99 }));
  });
});

describe('parent-keyed settings: content_filters / parental_controls', () => {
  test('parent can read/write their own parental_controls doc', async () => {
    const db = testEnv.authenticatedContext('parent1').firestore();
    await assertSucceeds(
      db.collection('parental_controls').doc('parent1').set({ screenTimeLimit: 60 })
    );
    await assertSucceeds(db.collection('parental_controls').doc('parent1').get());
  });

  test('parent can also read/write content_filters keyed by the CHILD uid', async () => {
    await seed((db) => db.collection('users').doc('child1').set({ parentIds: ['parent1'] }));
    const db = testEnv.authenticatedContext('parent1').firestore();
    await assertSucceeds(
      db.collection('content_filters').doc('child1').set({ blockedTags: ['scary'] })
    );
  });

  test('an unlinked user cannot touch someone else\'s parental_controls', async () => {
    await seed((db) => db.collection('parental_controls').doc('parent1').set({ screenTimeLimit: 60 }));
    const db = testEnv.authenticatedContext('rando').firestore();
    await assertFails(db.collection('parental_controls').doc('parent1').get());
    await assertFails(db.collection('parental_controls').doc('parent1').set({ screenTimeLimit: 0 }));
  });
});

describe('favorites subcollection', () => {
  test('a user can favorite a book for themselves', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    await assertSucceeds(
      db.collection('user_favorites').doc('child1').collection('favorites').doc('b1').set({ addedAt: 1 })
    );
  });

  test('a user cannot write favorites for someone else', async () => {
    const db = testEnv.authenticatedContext('child1').firestore();
    await assertFails(
      db.collection('user_favorites').doc('child2').collection('favorites').doc('b1').set({ addedAt: 1 })
    );
  });

  test('a linked parent can read but not write a child\'s favorites', async () => {
    await seed((db) => db.collection('users').doc('child1').set({ parentIds: ['parent1'] }));
    const db = testEnv.authenticatedContext('parent1').firestore();
    await assertSucceeds(
      db.collection('user_favorites').doc('child1').collection('favorites').get()
    );
    await assertFails(
      db.collection('user_favorites').doc('child1').collection('favorites').doc('b1').set({ addedAt: 1 })
    );
  });
});
