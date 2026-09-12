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

## Weekly "complete a book" challenge could be faked by reopening an old book (2026-09-12)

Writing tests for `WeeklyChallengeService` (previously untested) surfaced a
real, live bug in the "Complete 1/2 books" weekly challenge — one of the
12 challenges every user rotates through.

`calculateProgress`'s `completeBooks` case decided whether a book counted
toward *this week's* challenge using `lastReadAt >= startOfWeek`. But
`lastReadAt` is bumped on **every** read — including reopening a book
completed weeks or months ago (`book_provider.dart`'s "don't un-complete a
finished book" rule keeps `isCompleted: true` on a reread, but still
writes a fresh `lastReadAt`). So a child could satisfy "Complete 1 book"
by just reopening an old favorite for a minute, no new completion
required. `firestore_helpers.dart`'s `getReadingProgress` (a shared
Firestore-query helper other callers also use) has the identical
`lastReadAt`-based date filter when `completedOnly` and a date range are
combined, though `child_home_screen.dart`'s actual call site — the only
one that exercises this — goes through `calculateProgress`'s in-memory
`userProgress` branch, which is what's fixed here.

Fixed by adding a real `completedAt` field to `ReadingProgress` (and the
`reading_progress` Firestore schema): set once, in
`updateReadingProgress`, exactly on the transition from not-completed to
completed — never touched again on a later reread. `calculateProgress`
now uses `completedAt` (falling back to `lastReadAt` only for legacy docs
written before this field existed) to decide whether a completion
happened this week. `firestore_helpers.getReadingProgress` itself is
unchanged — it's shared by other callers not affected by this bug — but
now carries a comment warning the next person not to trust its
`lastReadAt`-based date filter for a "completed within this window"
question, the way this bug did.

**Second, related bug found while testing the fix:** `getProgressForBook`
reconstructs a fresh `ReadingProgress` object when returning a completed
book's progress (to normalize `progressPercentage` to 100% for display),
and that reconstruction dropped the new `completedAt` field entirely —
every completed book's `completedAt` read back as `null` through the
provider, silently defeating the fix above. Fixed by copying it through
like every other field.

Covered by `test/services/weekly_challenge_service_test.dart` (regression
case: reopening a book completed in a prior week no longer counts) and a
new case in `test/providers/book_provider_test.dart` (`completedAt` is set
once and doesn't move on a later reread, verified through
`getProgressForBook`, which is exactly the path that had the second bug).

## Functionality check: streaks, achievements, badges, quiz, analytics (2026-09-12)

Asked to specifically verify these five areas work correctly. Findings:

- **Streaks** (`FirestoreHelpers.calculateReadingStreak`): read through and
  tested end-to-end for the first time — consecutive-day counting, a gap
  correctly breaking the streak, the "not read today yet, count from
  yesterday" case, and de-duplication across the three legacy session
  schemas (`createdAt`/`createdAtClient`/`startTime`) it already handled
  correctly. No bug found; now covered by
  `test/services/firestore_helpers_test.dart` (8 cases) so a future change
  here can't regress silently.
- **Achievements & badges**: "badges" (`badges_screen.dart`) is UI
  terminology over the same `achievements`/`user_achievements` data
  `AchievementService` already writes — there's no separate badge system
  to check. This was already covered end-to-end from the earlier pass in
  this session (`achievement_service_test.dart`, `achievement_rules_test.dart`).
- **Quiz** (`book_quiz_screen.dart`'s scoring): read through — the
  answer-selection flow only ever advances past a question once it's
  answered, so the final `.cast<int>()` over all answers before scoring
  can't hit a null. Score/percentage/points-tier math checked and is
  correct. No bug found; this screen doesn't have a widget test (see
  "known gaps"), so this is reviewed, not test-locked.
- **Analytics** (`AnalyticsService`): found a real bug. `_calculateReadingStreak`
  and `_getWeeklyReadingData` called the bare `FirestoreHelpers()`
  singleton directly instead of the service's own injected
  `_firestoreHelpers` — meaning `.withInstances(...)` never actually
  reached these two methods; they always used the real
  `FirebaseService()`/`FirebaseFirestore.instance` regardless of what was
  passed in. In production this was silently harmless (there's only ever
  one real Firebase project, so both paths point to the same place), but
  it defeated the entire point of dependency injection for these two
  methods — and it's exactly what caused the stray
  `[core/no-app] No Firebase App '[DEFAULT]' has been created` error seen
  in earlier test output for unrelated `BookProvider` tests (which
  transitively call into `AnalyticsService` for achievement stats). Fixed
  by giving `AnalyticsService` its own `_firestoreHelpers` field, built
  from the same injected `firebaseService` in `.withInstances(...)` (or
  the real singleton in production), matching the pattern already used by
  `WeeklyChallengeService`. Covered by
  `test/services/analytics_service_test.dart` (7 cases, including a
  regression case that fails if this ever regresses back to the bare
  singleton) — and the stray `[core/no-app]` error is now gone from
  `BookProvider` test output, confirming the fix.

## ApiService, DailyQuestService, OfflineService (2026-09-12)

Continuing the same pass into the remaining unreviewed services.

- **`ApiService` is almost entirely dead code.** Of its 11 public methods,
  only `getRecommendedBooks` is actually called anywhere in `lib/`
  (`book_provider.dart`) — `getBookContent`, `trackReadingSession`,
  `getUserAnalytics`, `getQuizQuestions`, `submitQuizResults`,
  `getChildProgress`, `updateContentFilters`, `getContentFilters`,
  `scheduleReadingReminder`, `getUserAchievements`, and `unlockAchievement`
  have no callers at all (the app uses `AnalyticsService`/
  `AchievementService`/direct Firestore calls for the equivalent
  functionality instead). `baseUrl = 'https://your-api-endpoint.com/api/v1'`
  is a placeholder that was never replaced, which is a strong hint this
  class was early REST-API scaffolding that got superseded but never
  removed. Along the way, noticed `getChildProgress` (dead) has the same
  duplicate-counting shape as bugs fixed earlier in this file — it counts
  `isCompleted` progress docs without deduping by `bookId`, so if a
  duplicate `reading_progress` doc for the same book ever exists (the
  codebase's own comments in `book_provider.dart` acknowledge this can
  happen), it would double-count. Not fixed, since the method is
  unreachable — flagging in case it's ever revived. **Recommend deleting
  the 10 unused methods** rather than leaving them as a maintenance trap,
  but that's your call, not something to do silently. Added
  `test/services/api_service_test.dart` (7 cases) covering the one live
  method: AI-recommendation order preservation across the 10-ID `whereIn`
  chunk boundary, a hallucinated/deleted book ID being dropped rather than
  breaking the list, and the trait-based fallback.
- **`DailyQuestService`**: read through carefully (transaction-based
  upsert, per-quest completion tracking, one-time reward on all three
  completing, weekly "club star" accumulation) — no bug found, it already
  does the same "set `completedAt` once, on the real transition" pattern
  correctly that had to be fixed elsewhere in this file. Added
  `test/services/daily_quest_service_test.dart` (8 cases). Needed a small
  testing seam to verify the weekly accumulation logic at all (it had no
  way to control "now," so a scenario like "a second day's completion in
  the same week adds to the weekly total, but a new week resets it" was
  untestable) — added an `@visibleForTesting DateTime? now` parameter to
  `upsertTodayFromStats`; the real caller always omits it, so production
  behavior (`DateTime.now()`) is unchanged.
- **`OfflineService`**: found a real bug. `_updateConnectionStatus`'s own
  comment says "User is offline if there's no connectivity or only VPN,"
  but the code only ever checked for `ConnectivityResult.none` —
  `[ConnectivityResult.vpn]` alone (which `connectivity_plus` documents
  happening on iOS/macOS when it can't resolve a real underlying network
  type) was being treated as online, contradicting the comment's own
  stated intent. Fixed by extracting the decision into a pure
  `isOfflineFromConnectivity` function that actually implements it: offline
  iff every reported result is `none` or `vpn`, i.e. no real network type
  (wifi/mobile/ethernet/bluetooth) is present. Covered by
  `test/services/offline_service_test.dart` (9 cases) — this also made the
  logic testable at all, which it wasn't before (no seam existed to
  bypass the `connectivity_plus` platform channel).

## QuizGeneratorService, FeedbackService (2026-09-12)

Last two services in the pass.

- **`QuizGeneratorService`**: found and fixed a real bug in
  `saveQuizAttempt` — `(score / totalQuestions * 100).round()` throws
  (`Unsupported operation: Infinity or NaN toInt`) when `totalQuestions`
  is 0, since `0/0` is NaN and NaN has no int form. That exception was
  caught by the method's own outer try/catch, so the failure mode wasn't
  a crash — it was the quiz attempt silently never being saved at all,
  logged as an error with no other trace. `totalQuestions` should never
  really be 0 in practice, but a malformed or fallback-default quiz makes
  it a real possibility, so this is now guarded. Also found the same
  DI-escape shape as the `AnalyticsService` bug earlier in this file:
  `awardQuizPoints` called the bare `AchievementService()` singleton
  directly, ignoring anything injected into `QuizGeneratorService` itself.
  Fixed by giving it an injected `_achievementService`, same pattern as
  everywhere else.

  `getBookQuiz`'s actual `httpsCallable`-calling retry loop has no
  fake/mock package available for `cloud_functions` (unlike auth/
  firestore/storage), so it isn't unit-tested directly. Instead, its
  retry/error-classification decisions were extracted into pure,
  directly-tested functions (`isNonRetryableErrorResult`,
  `isNonRetryableExceptionCode`, `extractErrorMessage`) — the actual
  branching logic that decides "give up" vs. "retry" is covered even
  though the network call itself isn't. Building a `.withInstances()`
  constructor for this surfaced its own small bug: the constructor was
  eagerly evaluating the real `FirebaseFunctions.instance`/
  `AchievementService()` singletons even when a test never needed them
  (e.g. testing the cache-hit path, which touches neither) — any test
  that didn't explicitly pass every fake would crash on
  `[core/no-app]` just from *constructing* the service. Fixed by
  resolving both lazily, only when actually used; production behavior is
  unchanged (`FirebaseFunctions.instance` is itself a singleton accessor,
  so deferring when it's first read doesn't change which instance you
  get). Covered by `test/services/quiz_generator_service_test.dart`
  (10 cases).
- **`FeedbackService`**: found a related bug of its own. Its singleton
  constructor built a real `AudioPlayer()` unconditionally, which
  (confirmed by actually running a test against it) triggers the
  `audioplayers` plugin's own async platform-channel initialization as a
  side effect — meaning merely *touching* `FeedbackService.instance`
  anywhere (it's referenced from ~20 screens, most just for `.enabled`/
  `.playTap()`/`.setEnabled()`, none of which need audio at all) could
  throw a stray, hard-to-diagnose async platform error with no connection
  to what the caller was actually doing. Fixed by making `AudioPlayer`
  lazy — constructed only the first time a chime actually plays. Also
  hardened `setEnabled`'s fire-and-forget preference save with a real
  `.catchError` (the previous synchronous try/catch could never have
  caught a failure from the async `.then()` chain it wrapped). Covered by
  `test/services/feedback_service_test.dart` (6 cases, including
  registering fake handlers for the `audioplayers` plugin's own method
  channels — the standard Flutter technique for a plugin with no
  dedicated fake package).

## First widget tests, and a real progress-bar bug (2026-09-12)

Every automated test up to this point was a unit/service-level test — none
of them render an actual widget tree, so none could catch a bug in how a
widget wires its data to what's on screen. Started that category of
coverage with four widgets: `OfflineBanner`, `BookCard`, `LeagueWidget`,
`ProfileBadgesWidget`.

**Found and fixed a real bug in `BookCard`**: `ReadingProgress.progressPercentage`
is normalized to a 0.0–1.0 fraction (see `book_model_test.dart`'s coverage
of that normalization), but the shared `ProgressBar` widget's contract
(its own doc comment) is 0.0–100.0. `BookCard` passed the raw fraction
straight through, unconverted. Concretely: a book actually 50% read would
show a bar that's 0.5% full and a label reading "0%" — verified this
numerically before fixing it. `ProgressBar` itself is used by exactly one
caller in the whole app (`BookCard`), so fixing the caller (multiply by
100) was the safer fix over changing `ProgressBar`'s contract out from
under any future caller.

**Important caveat on severity**: neither `BookCard` nor `LeagueWidget` is
actually imported anywhere in `lib/` today (confirmed by grep) — both are
dead code, like `ApiService`'s unused methods noted earlier in this file.
So this bug, real as it is, isn't currently visible to any user. It's
still worth having fixed and tested: dead code gets revived (that's
exactly the `getChildProgress` situation already flagged), and a broken
progress indicator would be a meaningfully bad first impression for an
app whose whole premise is encouraging reading through visible progress.
`OfflineBanner` (wraps the entire app in `main.dart`) and
`ProfileBadgesWidget` (used in `badges_screen.dart`) are the two of the
four that are actually live.

`OfflineService` needed a small testing seam (`setOfflineForTesting`) to
drive `OfflineBanner` without the real `connectivity_plus` platform
channel — same reasoning as every other "no fake package exists for this
plugin" case in this file.

Covered by `test/widgets/{offline_banner,book_card,league_widget,
profile_badges_widget}_test.dart` (19 cases): the offline banner's
show/hide reactivity, the progress-bar regression above, completed-book
coloring, trait-chip truncation, age-rating visibility, tap handling,
league progress vs. the max-league state, and badge sorting (unlocked
first, then locked by how close it is) plus the locked/unlocked detail
dialog.

## League thresholds — a "local testing" shortcut had shipped (2026-09-12)

Testing `LeagueWidget` surfaced the diamond-at-31-points behavior
flagged after the widget-tests pass above. Traced it with `git log -p`:
commit `073d7fa` ("kk", 2026-05-12) reduced `league_helper.dart`'s
thresholds under the comment *"Reduced thresholds for local testing"*
and deleted the entire Platinum tier, and neither was ever reverted —
that commit is an ancestor of this branch's current `HEAD`, so it's
been live the whole time. Original values (recovered from the commit
before that one): Bronze 0-500, Silver 501-2,000, Gold 2,001-5,000,
Platinum 5,001-10,000, Diamond 10,001+.

Raised this with you directly since it's a game-balance call, not a
pure bug. You asked for the tier structure restored (Platinum
included) but with lower numbers than the original — the original
Diamond threshold (10,001) would take a genuinely engaged reader well
over a year to reach given the app's actual, known point sources
(daily quests: up to 10/day via `DailyQuestService`; book quizzes:
1-5 each via `QuizGeneratorService.awardQuizPoints`). Landed on:
**Bronze 0-99, Silver 100-299, Gold 300-699, Platinum 700-1,499,
Diamond 1,500+** — early tiers reachable within the first couple of
weeks (important for early retention), Diamond a multi-month but not
multi-year aspirational goal for a consistently engaged reader. These
are a judgment call, not a measured/tested rate from real usage data
(no real usage data exists to measure from yet) — revisit once the app
has actual point-earning telemetry to check the assumption against.

Also restored `leaderboard_screen_impl.dart`'s hardcoded per-league
leaderboard sections to include Platinum (it listed only 4 tiers,
matching the reduced enum).

Covered by `test/utils/league_helper_test.dart` (16 cases — every
tier's boundary, `getPointsToNextLeague`, `getCurrentLeagueProgress`,
`getProgressToNextLeague`, `getLeagueRange`, and that every tier
including the restored Platinum has a name/emoji/color) and a new
regression case in `league_widget_test.dart`.

## Storage rules — didn't exist at all (2026-09-12)

This project had no `storage.rules` file and no `"storage"` entry in
`firebase.json` — meaning `firebase deploy` has never once touched Storage
rules. Whatever is live in Firebase Console today for the Storage bucket
(which holds every book PDF and cover, uploaded via
`book_upload_form.dart`/deleted via `books_table.dart`) is unmanaged,
unreviewed, and unknown to this codebase — it could be wide open
(`allow read, write: if request.auth != null`, the same hole
`firestore.rules` had) or something else entirely.

Added `storage.rules`, reverse-engineered from actual usage (the only two
paths the app touches: `books/pdfs/*`, `books/covers/*`): any signed-in
user can read (same golden rule as Firestore — books must stay visible to
everyone), only an admin (`users/{uid}.role == 'admin'`, same fallback to
`admins/{uid}` as everywhere else) can write or delete, and everything
else defaults to fully denied rather than inheriting whatever the bucket's
previous default was. Wired into `firebase.json` so it actually deploys
from here on.

Tested in `firestore-tests/storage-rules.test.js` (Storage + Firestore
emulators together, since the admin check needs to read Firestore) — read
access for signed-in vs. denied for signed-out, a plain user blocked from
writing/deleting book files, and the default-deny catch-all. **One case
is `test.skip`, not passing:** that a real admin can write/delete. Storage
rules cross-checking Firestore (`firestore.get()`/`firestore.exists()`) is
a real, documented, production-supported feature, but it does not work in
the local Storage emulator's rules runtime under `@firebase/rules-unit-testing`
regardless of how the Firestore doc is seeded (tried both the test SDK and
the Admin SDK directly) — a known upstream limitation
([firebase-tools#5251](https://github.com/firebase/firebase-tools/issues/5251),
[firebase-js-sdk#6803](https://github.com/firebase/firebase-js-sdk/issues/6803)),
not a bug in this rule. **Action needed before trusting the admin-write
path:** verify it manually — Firebase Console's Rules Playground (which
does evaluate cross-service rules correctly) or an actual upload attempt
as an admin account against a staging project — before deploying this to
production and assuming admin uploads still work.

**Same "don't just push this" caution as the Firestore rules rewrite
applies here, doubly so given the untestable admin path:** run the tests,
review the diff, verify the admin path manually as above, then smoke-test
a real admin upload/delete and a real signed-in read against a
staging/dev project before deploying to production with
`firebase deploy --only storage`.

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
  211 cases total): the app's core scoring logic pulled into pure
  functions specifically so it could be tested
  (`personality_scoring_test.dart`, `achievement_rules_test.dart`,
  `book_model_test.dart`'s `calculateBookRelevanceScore`/
  `normalizeTraitsForMatching`, `reading_metrics.dart`'s pure extraction
  helpers); `AuthProvider` end-to-end (signUp/signIn,
  Firebase-error-to-friendly-message mapping, quiz-result persistence,
  parent/child linking, the account-removed auto-signout path);
  `AchievementService.checkAndUnlockAchievements` end-to-end (unlock
  writes, points, notifications, no double-awarding); `BookProvider`
  end-to-end (loading/ranking books, the AI+rule-based recommendation
  merge, reading-progress writes and its don't-un-complete-a-finished-book
  rule, the `completedAt` fix above, favorites) plus `Book`/
  `ReadingProgress` Firestore model round-trips (malformed URLs, the
  legacy 0-100-vs-0-1 progress format); `UserProvider` end-to-end
  (stats/streak/weekly-progress loading and its leaderboard sync, the
  reload-coalescing throttle, its own separate local badge scheme);
  `ContentFilterService.filterBooks` (the whole-word-matching and
  tag-list-drift regressions described above); `ReadingSessionService`
  end-to-end (session start/end duration math and clamping, the
  today's-minutes double-counting regression above, total/session-count
  aggregation); `WeeklyChallengeService` (every challenge-type's progress
  calculation including the completeBooks regression above, celebration-
  flag handling, the quiz-completion transaction's best-score tracking);
  `NotificationService` (per-user notification CRUD, the
  read/unread/cleanup batch operations, preferences round-tripping);
  `FirestoreHelpers.calculateReadingStreak`/`getLastNDaysReadingSummary`
  directly (streak counting, gaps, the "not read today yet" case,
  session-schema de-duplication); `AnalyticsService` (the injected-
  Firestore-escape regression above, the 120-second minimum session
  length, book-popularity ranking); `ApiService.getRecommendedBooks` (the
  one method of it that's actually used — order preservation, chunking,
  the dropped-hallucinated-ID case, trait-based fallback);
  `DailyQuestService` (per-quest completion, one-time reward, weekly
  club-star accumulation across days/weeks); the `OfflineService`
  VPN-detection bug above; `QuizGeneratorService` (the
  saveQuizAttempt divide-by-zero and achievement-service DI-escape bugs
  above, plus the extracted pure retry/error-classification logic); and
  `FeedbackService` (the enabled-gate, the lazy-AudioPlayer fix above).
  `FirebaseService` also gained a `.withInstances(...)` constructor but
  doesn't have a dedicated test file yet — production behavior is
  unchanged either way, since the default constructor still uses the
  real Firebase singletons. Plus the first widget-level tests
  (`test/widgets/`, 19 cases — see "First widget tests" above, including
  the `BookCard` progress-bar bug) and `LeagueHelper` (16 cases — see
  "League thresholds" above for the restored Platinum tier and the
  rebalanced point values).
  Plus the Firestore
  and Storage rules themselves (`firestore-tests/`, 31 passing + 1 skipped
  — see "Storage rules — didn't exist at all" above for the skip — separate
  Node/Jest suite against the Firestore + Storage emulators together).

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
  this regression suite — this wasn't updated as part of this pass since
  it lives in the thesis document, not this repo.
- Every service under `lib/services/` now has either dedicated tests or a
  documented reason it doesn't (`getBookQuiz`'s network call: no fake
  package for `cloud_functions`; `HapticFeedback`/`SystemSound`/
  `AudioPlayer` playback itself: no fake package, only channel-level
  stubs). `book_quiz_screen.dart`'s own scoring logic (separate from
  `QuizGeneratorService`) was also read through and found correctly
  guarded against the classic "submit with an unanswered question"
  crash — see the functionality-check section above.
- Widget tests now exist (see "First widget tests" above) but only for
  four widgets under `lib/widgets/` — everything under `lib/screens/`
  (~40 screens) is still untested, including every screen that isn't a
  small reusable widget: the actual quiz-taking flow, the library/home
  screens, onboarding, the admin panel. This is a real gap, not just an
  omission: a widget test catches a different class of bug (a screen
  crashing on null data, a button wired to the wrong handler, exactly the
  progress-bar unit mismatch just found) than any test before this pass
  could.
- Recommendation/business logic runs client-side in Dart rather than in a
  trusted backend — Cloud Functions bypass Firestore rules entirely via the
  Admin SDK, but the Flutter client's own scoring/matching logic is still
  visible to and tamperable by a sufficiently motivated user.
- The in-app privacy policy claims "COPPA Compliant" — that claim should be
  re-reviewed (parental consent flow, data minimization, deletion handling)
  now that the data-access story has actually changed, not left as boilerplate.
