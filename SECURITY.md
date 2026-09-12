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

## Cloud Functions with no authorization check (2026-09-12)

Writing tests for `createChildAccount` surfaced something the tests for
its business logic alone couldn't have: **none of the three `onCall`
functions in `functions/index.js` checked `request.auth` at all.**

- **`manualWeeklyReset` had zero authorization check whatsoever.** The
  code literally had a comment reading *"Check if request is from admin
  (you can add auth check here)"* — and never did. Any caller, signed in
  or not, could zero every user's `totalAchievementPoints`,
  `weeklyBooksRead`, `weeklyPoints`, and `weeklyReadingMinutes` on demand.
  Fixed: now requires the caller to be an admin, using the same check as
  `firestore.rules` and `admin_portal_screen.dart`
  (`users/{uid}.role == 'admin'`, falling back to `admins/{uid}`).
- **`createChildAccount` never verified the caller owned `parentId`.**
  The Flutter client always sends its own signed-in uid, but nothing
  stopped a different caller from sending any other real `parentId` and
  attaching a fake child straight into a stranger's account — into their
  parent dashboard, their `children` array. Fixed: the handler now
  requires `callerUid === parentId`, throwing a new `AuthorizationError`
  otherwise (mapped to `HttpsError('permission-denied', ...)`).
- **`generateBookQuiz`** had `enforceAppCheck: false` and no auth check;
  every call that reaches OpenAI costs real money, so this was an open
  door for scripted cost abuse (lower severity than the two above — it
  only touches a shared `book_quizzes` cache, not user-specific data).
  Fixed: now requires `request.auth` to be present, which the app's own
  usage already always satisfies.

All three are covered by tests now (`npm run test:emulator` in
`functions/`) — including the specific attack shape for each: a caller
creating a child under someone else's `parentId`, an unauthenticated
caller of either fixed callable.

**The same audit found a fourth, arguably worse issue, because it isn't
an `onCall` at all:** `triggerAiTagging` and `triggerAiRecommendations`
are plain HTTP (`onRequest`) endpoints with **their production URLs
hardcoded directly in the app's own source**
(`cloud_functions_panel.dart`:
`https://triggeraitagging-y2edld2faq-uc.a.run.app` and
`.../triggerairecommendations-...`), `cors: true`
(`Access-Control-Allow-Origin: '*'`), and — until this fix — no
authentication of any kind. `onCall` functions get `request.auth` for
free from the SDK; `onRequest` functions get nothing, so this needed its
own check. Anyone who found either URL (trivial — it's sitting in a
public-facing app's source, and in this repo) could invoke them
directly, for free, on demand: each call iterates every book needing
tagging (GPT-4) or every user with reading activity (GPT-3.5-turbo) and
pays for it with **your** OpenAI key. This is a live, uncapped-cost
exposure — worse than `manualWeeklyReset` in one sense, since that one
only corrupted data; this one spends real money per call, with no rate
limit. Fixed: `functions/lib/admin_check.js` adds
`requireAdminFromRequest`, the `onRequest` equivalent of an admin
`onCall` check — verifies an `Authorization: Bearer <idToken>` header
and requires the token's owner to be an admin. The Flutter side
(`cloud_functions_panel.dart`) now attaches that header via
`FirebaseAuth.instance.currentUser?.getIdToken()`. `healthCheck` is
unchanged and stays public — no side effects, just static status text.

**Given this pattern — two real vulnerabilities, a live cost exposure,
and a cost-abuse hole, all four with the identical root cause of never
checking who was calling — these were the only externally-callable
functions in this file (three `onCall`, two `onRequest`), but it's worth
specifically re-checking that shape (no auth check on a callable or HTTP
function) if more get added later.**

## Content filter silently hiding legitimate books (2026-09-12)

You'd specifically flagged that a Firestore rules change once broke book
access before, so this is worth calling out even though it's a different
layer: `ContentFilterService` was doing the same thing to itself by
accident, on by default, for every user.

`loadAllBooks` (`book_provider.dart`, the actual library/home-screen load
path) runs every book through `ContentFilterService.filterBooks` whenever a
`userId` is present — i.e. always, for a signed-in child. Until a parent
explicitly visits the content-filter screen, every user gets the *default*
filter, which has `enableSafeMode: true` and a hardcoded blocklist checked
with plain `String.contains`, not whole-word matching. That means:

- `'skills'.contains('kill')` → true. Any book blurb mentioning
  "problem-solving **skills**" — one of the app's own tag categories —
  was blocked.
- `'begun'.contains('gun')`, `'warm'/'awarded'/'forward'.contains('war')` —
  ordinary phrases ("her adventure has **begun**", "a **warm**
  friendship", "looked **forward** to") were blocked the same way.

Verified directly (see the commit): every one of those phrases got
silently blocked before the fix. This isn't a hypothetical — it's the
default state for every user, running against completely ordinary
children's-book language. Fixed with whole-word matching
(`\bword\b`) in both the hardcoded safe-mode list and the
parent-configurable `blockedWords` list.

Separately, the default filter's `allowedCategories` (23 hardcoded tags a
book needs at least one of, to be shown at all) had drifted out of sync
with `ALLOWED_TAGS` in `functions/lib/ai_helpers.js` — the actual vocabulary
the AI tagging function assigns to books. Seven real tags (`organization`,
`enthusiasm`, `positivity`, `patience`, `generosity`, `helpfulness`,
`playfulness`, `innovation`) weren't in the allowlist, so a book tagged only
with one of those could disappear from every library too. Fixed by
reconciling the two lists; a code comment now flags the coupling so it
doesn't drift again silently.

Both covered by `test/services/content_filter_service_test.dart`.

**Update:** the emotion-word question above was raised with you and you
asked for it to be fixed. `_isSafeModeCompliant`'s hardcoded list no
longer includes `'angry'`, `'sad'`, `'cry'`, `'fear'`, or `'hate'` — a
character being scared, sad, angry, or crying (and getting comforted, or
working it out) is normal, healthy content in children's books, not a
safety issue, and shouldn't be hidden from anyone by default. The list is
now scoped to actual safety/graphic-content concerns: `violence`, `scary`,
`horror`, `death`, `kill`, `murder`, `blood`, `weapon`, `gun`, `knife`,
`fight`, `war`, `nightmare`. Covered by a new test case asserting that
ordinary emotional content (sadness, fear, anger, crying, hate) passes
safe mode, alongside the existing case confirming real unsafe content
(e.g. "kill") still doesn't.

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
  81 cases total): the app's core scoring logic pulled into pure
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
  `UserProvider` end-to-end (stats/streak/weekly-progress loading and
  its leaderboard sync, the reload-coalescing throttle, its own separate
  local badge scheme); and `ContentFilterService.filterBooks` (the
  whole-word-matching and tag-list-drift regressions described above).
  `FirebaseService`, `NotificationService`,
  `WeeklyChallengeService`, `FirestoreHelpers`, `ApiService`,
  `AnalyticsService`, `ContentFilterService`, and `ReadingSessionService`
  all gained a `.withInstances(...)` constructor for this (see each
  file) — production behavior is unchanged, since the default
  constructor still uses the real Firebase singletons. Plus the Firestore
  rules themselves (`firestore-tests/`, 26 cases, separate Node/Jest
  suite against the emulator).

  On the Cloud Functions side (`functions/`, Node — two tracks, since
  `index.js` calls `initializeApp()`/`getFirestore()` at module load and
  can't be unit-tested directly):
  - `npm test` (35 cases, no emulator, runs in under a second):
    `functions/lib/ai_helpers.js` — prompt building and, more importantly,
    validating whatever the model hands back: filtering AI-suggested
    traits/tags down to the allowed vocabulary, filtering AI-recommended
    book IDs down to ones that actually exist (so a hallucinated ID can't
    produce a broken recommendation), and rejecting a malformed quiz
    before it reaches Firestore. Plus `processBookForTagging`'s
    orchestration (download → parse → tag → write), with every external
    effect injected as a fake — the exact Firestore update payload, the
    8000-character excerpt limit, and that a failure at any stage returns
    `false` instead of throwing (it runs in a loop over many books).
  - `npm run test:emulator` (29 cases, real Auth + Firestore emulators via
    `firebase emulators:exec`): `createChildAccountHandler` (account
    creation, the parent-link update, the authorization fix below, and a
    documented gap — a nonexistent `parentId` still creates the Auth user
    and child profile before the link update fails, so a naive retry
    could create duplicate orphaned children); `aggregateUserSignals`
    (every weight tier in the recommendation engine's signal-scoring,
    verified against each other — a favorite outranks a plain completion,
    a re-read outranks a first read, etc.); `isAdmin`/
    `resetWeeklyLeaderboard`; and `requireAdminFromRequest` (the
    `onRequest` admin gate added for `triggerAiTagging`/
    `triggerAiRecommendations` below — missing/malformed/garbage/non-admin
    bearer tokens all rejected, a real admin's token accepted, using a
    genuine ID token minted via the Auth emulator's
    `signInWithCustomToken` REST endpoint since `verifyIdToken` won't
    accept a bare custom token). Along the way, fixed a real bug in
    `createChildAccount`: a missing-field validation error was being
    unconditionally re-wrapped as `HttpsError('internal', ...)` by the
    same function's own catch block, so a client checking for
    `invalid-argument` would never see it — it now round-trips correctly.

  Still not covered: the parts of `processBookForTagging` that actually
  call OpenAI/Storage for real (as opposed to the orchestration around
  them, which is covered), and the scheduled/triggered functions that
  call it — would need the Storage emulator and a mocked OpenAI client.

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
