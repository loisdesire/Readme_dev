# Security notes

## Firestore rules rewrite (2026-09-12)

`firestore.rules` previously read:

```
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

Any signed-in user — including a child account — could read or write *any*
document in the database: other children's personality/reading data, the
`admins` collection, `books`, `admin_settings`. The in-app admin check
(`admin_portal_screen.dart`'s `_isAdmin` bool) was cosmetic; nothing enforced
it server-side.

The rules now grant access per-collection, based on how the app actually
uses each one (see the comments at the top of `firestore.rules`):

- `books`, `book_quizzes`, `quiz_questions`, `achievements` stay readable by
  **any signed-in user** — tightening this by accident is what broke the
  library once before, so it's called out explicitly in the rules file and
  covered by a test.
- Per-child activity (`reading_progress`, `reading_sessions`, `quiz_results`,
  etc.) is readable/writable by its owner, readable by a linked parent
  (`users/{child}.parentIds` contains the parent's uid), and readable/writable
  by admins.
- `role: 'admin'` on a user's own doc can no longer be self-granted.
- The PIN/QR parent-linking flow (`add_child_screen.dart`,
  `qr_scanner_widget.dart`) still works for a *not-yet-linked* parent — the
  rule allows adding your own uid to a child's `parentIds` and nothing else.

### Before you deploy this

**Do not just push this to production.** Run the test suite first, and after
deploying, smoke-test the real app against it in a dev/staging build (log in
as a child and confirm the library loads, as a parent confirm linking and the
dashboard work, as an admin confirm the upload panel works) before trusting
it with real users.

```bash
cd firestore-tests
npm install
npm test        # spins up the Firestore emulator, runs 26 rule tests, tears down
```

Deploy once tests pass and you've reviewed the diff:

```bash
firebase deploy --only firestore:rules
```

### Bootstrapping the first admin

Because the open write-anywhere hole is closed, a user can no longer make
themselves admin from the app. Use the Admin SDK instead:

```bash
node tools/set_admin.js you@example.com
```

Requires `tools/serviceAccountKey.json` (gitignored — generate a **new** one
from Firebase Console → Project settings → Service accounts; see below for
why "new").

## Exposed service account key — rotate it

Commit `5bfd28e` ("upload books") added `tools/serviceAccountKey.json` to
this repo. A later commit updated `.gitignore` to stop it from being
re-added, but the key file itself is still present in git history (project
`readme-40267` — check whether that project is still active; if it is,
treat this as urgent).

**Action needed (not done by this change):** in Google Cloud / Firebase
Console, revoke that specific service account key and generate a new one for
local tooling. Moving branches or repos does not undo the exposure — the key
has to be rotated at the source regardless of where the code lives.

## Known gaps not addressed by this change

- Automated tests now cover, on the Dart/Flutter side (`flutter test`,
  76 cases total): the app's core scoring logic pulled into pure
  functions specifically so it could be tested
  (`personality_scoring_test.dart`, `achievement_rules_test.dart`,
  `book_model_test.dart`'s `calculateBookRelevanceScore`/
  `normalizeTraitsForMatching`); `AuthProvider` end-to-end (signUp/signIn,
  Firebase-error-to-friendly-message mapping, quiz-result persistence,
  parent/child linking, the account-removed auto-signout path);
  `AchievementService.checkAndUnlockAchievements` end-to-end (unlock
  writes, points, notifications, no double-awarding); `BookProvider`
  end-to-end (loading/ranking books, the AI+rule-based recommendation
  merge, reading-progress writes and its don't-un-complete-a-finished-book
  rule, favorites) plus `Book`/`ReadingProgress` Firestore model
  round-trips (malformed URLs, the legacy 0-100-vs-0-1 progress format);
  and `UserProvider` end-to-end (stats/streak/weekly-progress loading and
  its leaderboard sync, the reload-coalescing throttle, its own separate
  local badge scheme). `FirebaseService`, `NotificationService`,
  `WeeklyChallengeService`, `FirestoreHelpers`, `ApiService`,
  `AnalyticsService`, `ContentFilterService`, and `ReadingSessionService`
  all gained a `.withInstances(...)` constructor for this (see each
  file) — production behavior is unchanged, since the default
  constructor still uses the real Firebase singletons. Plus the Firestore
  rules themselves (`firestore-tests/`, 26 cases, separate Node/Jest
  suite against the emulator).

  On the Cloud Functions side (`functions/`, Node — `npx jest`,
  25 cases): `functions/lib/ai_helpers.js` extracts the parts of
  `functions/index.js` that don't need Firebase Admin or a real OpenAI
  call — prompt building and, more importantly, validating whatever the
  model hands back: filtering AI-suggested traits/tags down to the
  allowed vocabulary, filtering AI-recommended book IDs down to ones that
  actually exist (so a hallucinated ID can't produce a broken
  recommendation), and rejecting a malformed quiz before it reaches
  Firestore. `index.js` itself still can't be unit-tested directly (it
  calls `initializeApp()`/`getFirestore()` at module load) — testing
  `createChildAccount` and the Firestore/Storage-touching orchestration
  (`processBookForTagging`, `aggregateUserSignals`, the scheduled/triggered
  functions) would need the Functions/Auth emulator, a bigger lift than
  this pass.

  The Chapter 4 thesis test tables (unit/integration/functional, all
  "Pass") still describe manual testing from before this change, not
  this regression suite.
- Recommendation/business logic runs client-side in Dart rather than in a
  trusted backend — Cloud Functions bypass Firestore rules entirely via the
  Admin SDK, but the Flutter client's own scoring/matching logic is still
  visible to and tamperable by a sufficiently motivated user.
- The in-app privacy policy claims "COPPA Compliant" — that claim should be
  re-reviewed (parental consent flow, data minimization, deletion handling)
  now that the data-access story has actually changed, not left as boilerplate.
