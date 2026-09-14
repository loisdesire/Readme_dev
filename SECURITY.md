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

## First screen-level widget tests, and a content-filter regression already in progress (2026-09-12)

Continued widget testing from small reusable widgets into full screens:
`BookQuizScreen` and `ContentFilterScreen`. Both singletons they construct
(`QuizGeneratorService`, `WeeklyChallengeService`, `ContentFilterService`)
had no seam for a screen to override, so each screen gained the same
`@visibleForTesting` optional-constructor-param pattern used throughout
`lib/services/` — defaulting to the real singleton, so every other caller
and production behavior are unchanged.

**`BookQuizScreen`** (4 cases): loads a cached quiz, blocks advancing past
an unanswered question (the guard read through and confirmed safe earlier
in this session), and submits with the correct score/percentage/points
tier for both a perfect and a partial run — exercising the exact scoring
logic fixed in `QuizGeneratorService` earlier, now end-to-end through the
screen that actually drives it. Along the way: `BookQuizCelebrationScreen`
(the screen this one navigates to) runs a multi-second staggered reveal
animation via chained `Future.delayed` calls that its `dispose()` doesn't
cancel — harmless in the real app (each step no-ops via a `mounted` check
after disposal) but it meant the test had to explicitly pump the fake
clock through the whole sequence rather than use `pumpAndSettle()`, which
can't resolve raw `Timer`-based delays it doesn't know are safe to abandon.
Not fixed, since it's cosmetic/inert in production — noted here in case
whoever touches that screen next wants to add proper cancellation.

**`ContentFilterScreen`** (4 cases) — **found a live regression connected
to the earlier content-filter fix**: this screen (the actual parent-facing
UI for editing content filters) had its own hardcoded copy of the
category list, separate from `ContentFilterService`'s default filter —
and it still had the old, stale 23-category list, missing the same 7
categories (`organization`, `enthusiasm`, `positivity`, `patience`,
`generosity`, `helpfulness`, `playfulness`, `innovation`) that were added
to the service's default earlier in this file. Since this screen is how a
parent actually edits their filter, a parent who opened it and hit Save —
the screen's whole purpose — would have overwritten their filter with one
missing those 7 categories again, re-introducing the "book invisible
because none of its tags are in the allowlist" bug from a different entry
point than the one already fixed. Fixed by extracting the category list
into a single shared constant (`kAllContentFilterCategories` in
`content_filter_service.dart`) that both the service's default and this
screen now build from, specifically to stop this exact kind of
same-list-in-two-places drift from happening a third time.

## ChildHomeScreen and LibraryScreen: a build()-time singleton crash, an untestable raw Firestore call, a layout overflow, and two Flutter-test-framework gotchas worth recording (2026-09-12)

Continued the screen-level widget-testing pass into `ChildHomeScreen` (the
signed-in child's main landing screen) and `LibraryScreen`. Found and
fixed three real bugs across the two screens, and hit two non-obvious
`flutter_test` behaviors that are worth recording here since the patterns
they invalidate (`buildAuthProvider()`, a bare
`tester.pump()`) are used throughout this test suite.

**Bug 1 — `AchievementService().getDefaultAchievements()` didn't need the
singleton it was forcing into existence.** The home screen's badge-progress
card calls this method, from directly inside `build()`, purely to read a
pure, hardcoded list of achievement definitions — no Firestore/Auth touch
in the method itself. But it was an *instance* method, so reaching it meant
constructing `AchievementService()` first: the real singleton, whose
`_internal()` constructor eagerly touches `FirebaseFirestore.instance`/
`FirebaseAuth.instance`. In any environment without a real Firebase app
already initialized, that construction alone throws `[core/no-app]` —
crashing this part of the screen's `build()`. Fixed by making
`getDefaultAchievements()` `static` (verified via `flutter analyze` that
its one internal unqualified call site still resolves correctly) and
updating the call site to `AchievementService.getDefaultAchievements()`.

**Bug 2 — the weekly-challenge card's live update listener reached straight
for `FirebaseFirestore.instance`, with no seam to override it.** Unlike
every other Firestore access on this screen (all routed through the
injected `BookProvider`/`UserProvider`), `_buildWeeklyChallengeCard`'s
`StreamBuilder` builds its `stream:` argument from the raw
`FirebaseFirestore.instance` singleton getter directly. That getter throws
synchronously (not inside the stream — evaluating the `stream:` expression
itself throws) in any environment without `Firebase.initializeApp()`
having run, which took down the *entire* screen body: Flutter's framework
catches the exception and replaces the enclosing `Consumer3` subtree with
an `ErrorWidget`, meaning nothing else in the screen renders either.
Fixed with the same `@visibleForTesting`-optional-constructor-param seam
used elsewhere in this codebase: `ChildHomeScreen` now takes an optional
`firestoreOverride`, defaulting to `FirebaseFirestore.instance` in
production and overridable to a fake in tests. (A second, already-inert
raw `FirebaseFirestore.instance` read in `_checkWeeklyChallengeOnce` —
wrapped in `try/catch` and only used to check weekly-celebration state —
was routed through the same seam for consistency, though it wasn't
crash-prone.)

**Gotcha 1 — `buildAuthProvider()`'s `Future.delayed` must be awaited from
`setUp()`, never directly inside a `testWidgets()` body.** This helper
(used across several screen tests already) does
`await Future<void>.delayed(Duration.zero)` to let `MockFirebaseAuth`'s
initial `authStateChanges()` event settle. `TestWidgetsFlutterBinding`
runs the entire `testWidgets()` callback body inside a fake-clock zone
that only advances when a test explicitly calls `tester.pump(...)` — so a
`Future.delayed` awaited directly in that body, before any pump exists to
advance the clock, **hangs forever**. The identical code awaited inside
`setUp()` (a plain `package:test` hook, outside that special zone) runs on
the real event loop and resolves normally. Every test in
`child_home_screen_test.dart` now builds every provider — including a
second, signed-out `AuthProvider` used by two of the tests — inside
`setUp()` for exactly this reason.

**Gotcha 2 — a bare `tester.pump()` doesn't elapse the fake clock at all,
so a `Future.delayed(Duration.zero)`-based `notifyListeners()` never
fires, and `pumpAndSettle()` doesn't help either.** `BaseProvider.setLoading`/
`setError` dispatch their `notifyListeners()` through `safeNotify()`,
which itself uses a zero-duration `Future.delayed` (to dodge
"setState during build" issues) — i.e. a real `Timer`, just a zero-length
one. `WidgetTester.pump()` only elapses the fake clock when given an
explicit `Duration` argument; called with none (as most tests in this
suite do), it never fires that timer, and it's still pending when the test
tears down — which fails Flutter's own "no leftover Timer" invariant
check. The obvious fix, `pumpAndSettle()`, doesn't work on this specific
screen: it renders a looping `PulseAnimation`, which keeps scheduling new
frames forever, so pumpAndSettle's "stop once nothing more is scheduled"
condition never becomes true and it times out after its internal 10-minute
budget. The fix used here: pass an explicit `Duration.zero` to `pump()`
for the simple loading/error-state tests (one elapse is enough to fire a
single pending zero-timer), and a small bounded loop of zero-duration
pumps (`pumpAndDrain()`, 10 iterations) for the tests that trigger the
screen's own real (fast, fake-backed) `initState` data-reload chain —
enough to drain that finite chain's cascading `safeNotify()` timers
without ever waiting on the infinite animation the way `pumpAndSettle()`
does.

**`ChildHomeScreen` test coverage added** (`test/screens/child_home_screen_test.dart`,
6 cases): the loading spinner and error-state-with-retry screens (each
using the signed-out `AuthProvider`, so the screen's own real data load
never fires and overwrites the injected state before the test can observe
it); the header showing the signed-in user's username/avatar; the streak
count from `UserProvider`; the badge-progress card rendering without
crashing (the Bug 1 regression check); and Continue Reading showing an
in-progress book but not a completed or not-yet-started one — scoped to
just that section's own widget subtree, since Recommended Books
legitimately can and does list the same not-yet-started book elsewhere on
the same screen.

**`library_screen.dart`** (1841 lines) — unlike `ChildHomeScreen`, its
`initState`/data loading is properly routed entirely through injected
providers, with no raw-singleton calls of its own, so it needed no
`firestoreOverride`-style test seam. Added
`test/screens/library_screen_test.dart` (6 cases): the All Books tab
listing every loaded book; the inline search field filtering it by title;
the Reading Now and Finished tabs each showing only the book matching
their own status; My Favorites showing its empty state and then the
favorited book once one is added; and a layout regression (next
paragraph).

**Found and fixed a real layout bug:** `_buildEmptyState` (the shared
"no books here" view used by every tab) laid out its icon, title,
subtitle, and button in a plain fixed-size `Column` inside a `Padding`,
with no scroll fallback. Writing a test that opened the inline search
field (which claims 56px of vertical space) while an empty-state tab was
showing reproduced a real `RenderFlex overflowed` error — content that
legitimately doesn't fit is silently clipped rather than made reachable.
The same collision (search open + an empty tab) is fully reachable in the
real app, and an on-screen keyboard shrinking the available height
further would make it worse. Fixed by wrapping the content in a
`LayoutBuilder` + `SingleChildScrollView` + min-height `ConstrainedBox`:
it still centers vertically via the existing `Center` when the content
fits (the common case), and scrolls instead of overflowing when it
doesn't.

One pre-existing architectural concern noted but intentionally not fixed,
since it matches an already-deferred question from earlier in this file:
`BookProvider.getBooksByStatus('ongoing'/'completed')` reads raw,
non-deduplicated `_userProgress` entries, so a book with duplicate
`reading_progress` docs (one marked complete, one not) could in theory
appear in both the Ongoing and Completed library tabs simultaneously — the
same root cause as the duplicate-progress-doc question already on record,
not a new one.

## Auth screens: a provider-scoping test gotcha worth recording, and two off-screen tap gotchas (2026-09-12)

Continued the screen-level widget-testing pass into the three auth screens:
`LoginScreen`, `RegisterScreen`, `AccountTypeScreen`. All three were
already properly injected/testable — no production bugs found here — but
writing tests that follow a screen's own `Navigator.pushReplacement`
across to whatever it navigates to (a first for this test suite; every
screen tested so far was checked in isolation) surfaced a real test-harness
gotcha worth recording, plus two smaller ones.

**Gotcha — providers must wrap `MaterialApp`, not sit as `home:`'s
child, in any test that navigates.** The first draft of
`login_screen_test.dart` built its harness the same way every other
screen test in this suite does:
```dart
MaterialApp(home: MultiProvider(providers: [...], child: const LoginScreen()))
```
This works fine for a screen tested in isolation, but `MaterialApp.home`
becomes part of its *first route's own page widget* — which is exactly
what `Navigator.pushReplacement` (used by `LoginScreen` to move to
`ParentHomeScreen`/`ChildHomeScreen`/`QuizScreen` after sign-in) discards
wholesale, `MultiProvider` included. The destination screen then can't
find `AuthProvider` above it and throws `ProviderNotFoundException` —
which fails the test outright (any exception during a pumped frame does,
whether or not it's related to what the test is actually asserting).
Fixed by wrapping `MaterialApp` itself in the provider instead:
```dart
MultiProvider(providers: [...], child: const MaterialApp(home: LoginScreen()))
```
— matching how the real app's own `main.dart` wraps its `MaterialApp`,
so providers now sit above `Navigator` and survive route replacement.
Applied to both `login_screen_test.dart` and `register_screen_test.dart`,
since both navigate this way.

**Gotcha — a downstream screen's own unrelated crash is an expected,
consumable exception, not a test failure.** Navigating a bare
`ChildHomeScreen` (no `firestoreOverride`, no `BookProvider`/
`UserProvider` supplied — this is `LoginScreen`'s own hardcoded
`const ChildHomeScreen()`, with no way to inject test doubles into it from
here) reproduces exactly the crash already described and fixed at its
*own* screen level above; from `LoginScreen`'s side, that's an accepted,
irrelevant side effect of testing navigation *to* it, not a regression to
chase down again. Consumed with `tester.takeException()` rather than
threading full `ChildHomeScreen` DI through a screen that isn't the one
under test.

**Gotcha — a submit button below the fold fails its tap silently.**
`RegisterScreen`'s longer form (illustration + 4 fields + button) and
`AccountTypeScreen`'s scrolling column both place their primary
tap target below the default test viewport's visible area. `tester.tap()`
computes a real screen offset and warns (rather than erroring) when that
offset lands outside the render view — so the tap event fires into empty
space, the button's `onPressed` never runs, and every assertion downstream
fails for a reason that has nothing to do with the thing being tested.
Fixed by calling `tester.ensureVisible(...)` before each such tap.

Added `test/screens/login_screen_test.dart` (6 cases: empty-field
validation, a wrong-password failure with no navigation, and each of the
three post-sign-in destinations — parent/child-with-quiz/
child-without-quiz — plus the "Create Account" tab), `register_screen_test.dart`
(8 cases: every field's validation including the confirm-password mismatch,
a duplicate-email failure, both post-sign-up destinations —
parent straight to `ParentHomeScreen`, child to `QuizScreen` — and the
"Sign In" tab), and `account_type_screen_test.dart` (3 cases: both account
type cards pre-setting `RegisterScreen.initialAccountType` correctly, and
the named-route `/login` navigation, replicating `main.dart`'s own
`routes` table so the tap has somewhere real to go).

## ParentHomeScreen, ParentDashboardScreen, and a real layout-overflow bug in the QR scanner (2026-09-12)

Continued the screen-level widget-testing pass into `ParentHomeScreen` and
`ParentDashboardScreen`.

**Found and fixed a real layout bug in `QRScannerWidget`** (the "scan your
child's QR code" tab of `AddChildScreen`, surfaced while testing
`ParentHomeScreen`'s "Add Child" button): its overlay `Column` — two
`Spacer`s plus a fixed 250×250 scan frame, instructional text, and a flash
button, roughly 430px of fixed content — overflowed by 42px at this
suite's default test viewport height once the screen's own header is
accounted for. The same math applies on a real short screen (an older/
smaller phone, or landscape), not just the test viewport. Fixed by
measuring the actually-available height with a `LayoutBuilder` and
shrinking the scan frame (`(availableHeight * 0.4).clamp(120.0, 250.0)`)
instead of leaving it fixed at 250, so the fixed content shrinks to fit
rather than overflowing.

**`ParentDashboardScreen` needed the same kind of DI seam as
`ChildHomeScreen`, but for five different singletons at once.** This
screen reaches directly for `FirebaseFirestore.instance`,
`FirebaseAuth.instance`, `AnalyticsService()`, `ContentFilterService()`,
and a bare `UserProvider()` — all constructed fresh in-screen with no
Provider/service layer in between, and (unlike `ChildHomeScreen`'s single
StreamBuilder case) several of these calls sit directly in `initState`'s
own call chain with **no surrounding try/catch**, so the resulting
`[core/no-app]` crash aborts the widget's `initState()` itself rather than
just a build()-time descendant. That distinction matters for testing:
**an exception during `initState()` is a different beast than one during
`build()`.** Flutter's framework only converts a `build()`-time exception
into an inline `ErrorWidget` for that subtree; an exception raised while a
`StatefulElement` is still mounting (i.e., inside `initState()`) aborts
that element's mount outright, so the widget never appears in the tree at
all — `find.byType()` finds nothing, and — a further surprise — the
exception propagates as a genuine synchronous Dart exception straight out
of the `tester.pump()`/`pumpAndSettle()` call that triggered it, rather
than merely being recorded for `tester.takeException()` to consume
afterward the way a `build()`-time exception is. (`ParentHomeScreenScreen`
navigates to a bare, un-injected `ParentDashboardScreen` this same way;
rather than let its own test either crash or need this same DI threaded
through a screen that isn't the one under test, a `NavigatorObserver`
captures the pushed route and asserts on its `childId` field directly,
without ever pumping the frame that would try to build it.)

Given that, `ParentDashboardScreen` got the full DI treatment: five new
`@visibleForTesting` optional constructor params
(`firestoreOverride`/`authOverride`/`analyticsServiceOverride`/
`contentFilterServiceOverride`/`userProviderOverride`), each defaulting to
the real singleton in production, with the screen's own getters
(`_firestore`/`_auth`/`_analyticsService`/`_contentFilterService`/
`_userProvider`) routing to whichever is present.

Added `test/screens/parent_home_screen_test.dart` (8 cases: the empty
state, a populated child card with correct stats, a removed child
correctly excluded, "Add Child" navigation, a child-card tap capturing the
right `childId` via the `NavigatorObserver` approach above, the
delete-confirmation flow including cancel, and sign-out) and
`test/screens/parent_dashboard_screen_test.dart` (6 cases, using the new
DI seam throughout: the no-user error state, a fully-loaded child
dashboard — name, today/goal minutes, all-time totals, recent reading,
content-filter tags — the empty reading-history/achievements states,
navigation to `ReadingHistoryScreen` and `ContentFilterScreen`, and the
no-`childId` fallback to the signed-in user).

**Noted, not fixed:** `_childDataStream`, a real-time Firestore listener
`ParentDashboardScreen` sets up in `_loadDashboardData`, is never actually
subscribed to (no `StreamBuilder`/`.listen()` anywhere in the file) —
dead code, harmless since Firestore does no work until something
subscribes, but presumably meant to drive a live-updating view that was
never wired up.

## AddChildScreen, QRScannerWidget, ReadingHistoryScreen, and a dead SetGoalsScreen (2026-09-12)

Finished the parent-screens pass: `AddChildScreen` (all three tabs),
`QRScannerWidget`'s actual QR-linking logic, `ReadingHistoryScreen`, and
`SetGoalsScreen`.

**A test-harness gotcha that cost real time here, worth its own note:**
`Navigator.pop(context, ...)` on the *last* route in a Navigator's history
doesn't safely no-op the way it might seem to — it actually tears the
route down, taking anything hosted in it (including a queued SnackBar's
Scaffold, if that Scaffold was the one being popped) with it. Both
`AddChildScreen`'s successful-PIN-link path and `QRScannerWidget`'s
successful-scan path call `Navigator.pop(context, true)` immediately after
queuing a success `SnackBar` — exactly the pattern that trips this. Wrapped
directly as `MaterialApp(home: AddChildScreen())` (no route underneath),
the pop silently discards the screen and its SnackBar, so
`find.text('... linked successfully!')` always found nothing — not because
linking failed, but because the test harness didn't mirror how these
widgets are actually used (always pushed onto an existing route). Fixed by
giving each test a real host route to push onto and pop back to, matching
production; `QRScannerWidget`'s own dedicated test didn't need this
fix for its SnackBar checks (nothing there asserts on the pop itself), but
`AddChildScreen`'s does, and now also confirms the pop actually happens
(back on the host screen) rather than just hoping it did.

**`ReadingHistoryScreen`** reached directly for `FirebaseFirestore.instance`
(two call sites) wrapped in a blanket `try/catch` that swallows errors into
an empty list — safe in tests (no crash) but silently untestable for its
actual populated-list behavior without a seam. Added the same
`firestoreOverride`-style `@visibleForTesting` param used elsewhere.

**`SetGoalsScreen` is dead code** — grep confirms nothing under `lib/`
navigates to it (no route, no button, no reference anywhere outside its
own file); it also has a large block of an old, unused, commented-out
duplicate implementation still sitting in the file. Tested anyway for
completeness, since it's cheap once reached, but flagging the underlying
issue: **even if it were wired up, "Save Goal" persists nothing** — no
Firestore write, no provider call, and no `childId` param to say whose
goal it would even be. It only shows a confirmation `SnackBar` and pops;
the goal a parent "sets" here would vanish the instant the screen closes.
The reading goal actually read elsewhere in the app
(`ParentDashboardScreen`'s `readingGoal`) comes from
`ContentFilterService.maxReadingTimeMinutes`, which this screen never
touches — if this screen is meant to be resurrected, it needs to write
through that same service (with a `childId`), not stand alone.

Added `test/screens/add_child_screen_test.dart` (10 cases: all three tabs
present; the PIN-link flow's empty/not-found/already-linked/removed/
success paths, the last including the pop-and-SnackBar fix above; and the
Create tab's client-side validation, since its actual submission calls
`FirebaseFunctions.instance` directly with no fake/mock package available
for `cloud_functions` — the same accepted, already-documented gap as
`QuizGeneratorService.getBookQuiz`), `test/screens/qr_scanner_widget_test.dart`
(8 cases exercising the actual QR-linking logic directly — grabbing the
mounted `MobileScanner` and invoking its public `onDetect` callback with a
synthetic `BarcodeCapture`, since the parsing/linking logic itself is a
private method with no other way in: wrong prefix, wrong part count,
unknown child, non-child account, wrong PIN, removed account,
already-linked account, and a full successful link),
`test/screens/reading_history_screen_test.dart` (5 cases: the empty state,
a populated ongoing+completed pair with all their displayed fields, a
progress doc pointing at a since-deleted book being silently skipped,
scoping to only the requested child, and back navigation), and
`test/screens/set_goals_screen_test.dart` (5 cases covering the slider,
presets, the reminder toggle, and the save/pop/SnackBar flow — see the
dead-code and no-persistence notes above for why this coverage is
lower-value than the rest of this pass).

## Admin screens: two real, always-reproducible overflow bugs, and the mock-package limits that finally forced a line to be drawn (2026-09-12)

Finished the last un-tested corner of the app: the web-only admin console
(`AdminPortalScreen` and its four tabs — `AdminDashboard`, `BookUploadForm`,
`BooksTable`, `CloudFunctionsPanel`). This completes screen-level test
coverage across the entire codebase — every screen in `lib/screens/` now
has a corresponding test file.

**All five reach directly for Firebase singletons** (`FirebaseAuth.instance`/
`FirebaseFirestore.instance`/`FirebaseStorage.instance`, `BookUploadForm`
needing all three) with no Provider/service layer in between — the same
pattern as every screen fixed earlier in this pass. Gave each the matching
`@visibleForTesting` optional constructor params, and `AdminPortalScreen`
now threads its own overrides down into whichever tab `_buildContent()`
returns.

**Found and fixed two real, always-reproducible layout bugs** — unlike the
earlier screens' overflow findings, which only manifested at unusually
short viewport heights, both of these break at *any* window size, since
they come from a fixed-width sidebar/column rather than a height
constraint:
- `_NavItem` (the admin sidebar's own nav row) lays out an icon, spacing,
  and a label `Text` with no `Expanded`/ellipsis. The sidebar's own width
  is hardcoded to 260px, leaving exactly 212px for icon + label after
  padding — "Cloud Functions" and "Manage Books" (this file's own longest
  labels) don't fit unclipped into that regardless of how wide the actual
  browser window is. Fixed by wrapping the label in `Expanded` +
  `TextOverflow.ellipsis`.
- `CloudFunctionsPanel`'s "Scheduled Functions" section lays out a
  colored badge + a function-name label in an unwrapped `Row` inside each
  of two `Expanded` halves — "AI Recommendations" (this file's own
  longest label) doesn't fit its half at any width narrower than
  the desktop-generous headroom this console assumes. Same fix: wrapped
  each label in `Expanded` + ellipsis.

**Where to draw the line on viewport-dependent findings:** this console
also overflows (in `CloudFunctionsPanel`'s three-column function-card row,
and in the same `_NavItem` row from the previous section, though at
different widths) at `flutter_test`'s default 800×600 surface specifically
because a fixed 260px sidebar leaves an unusually narrow remainder — width
no real user of this desktop-only admin tool would ever actually have.
Rather than chase every overflow reachable only at that artificial size,
`admin_portal_screen_test.dart`'s dashboard-reaching tests set a realistic
1600×1000 surface (`tester.binding.setSurfaceSize`) instead, the same way
a prior finding in this file already distinguished a real device-reachable
overflow from a test-harness artifact.

**Two more mock-package limits, on top of the already-documented
cloud_functions-callable and QR/mobile_scanner-rendering gaps:**
- `FilePicker.platform` is a settable `PlatformInterface` field (the
  standard federated-plugin pattern) — no fake package exists for it, but
  writing a ~15-line fake `FilePicker` subclass overriding `pickFiles` was
  enough to drive `BookUploadForm`'s file-selection flow directly, no
  external dependency needed.
- `firebase_storage_mocks`' upload path could not be made to work at all:
  `MockReference.putData` performs real `dart:io` file I/O, which Flutter
  test's `FakeAsync` zone cannot control — it only resolves through the
  test binding's own "real-async-interplay" mechanism, which runs *after*
  a test's body has already returned. The exact failure —
  `MockTaskSnapshot` doesn't implement `bytesTransferred`/`totalBytes`,
  which `BookUploadForm`'s own upload-progress listener reads on every
  snapshot event — is consequently unreachable from any pump/
  `takeException()` sequence inside the test body, however it's phased.
  `book_upload_form_test.dart` covers every other path (both validation
  paths, the PDF-required and non-admin checks, and file selection) and
  documents this one gap rather than fighting it further.
- `CloudFunctionsPanel`'s own actual trigger calls go through the
  top-level `http.post` function directly (no injectable `http.Client`),
  so — like the two above — they're documented as untested rather than
  refactored around.

**Also found (not fixed): `CloudFunctionsPanel`'s disabled-function guard
in `_triggerFunction` is dead code.** Its "Trigger" button already has
`onPressed: null` whenever the function is disabled, so a tap never
reaches `_triggerFunction` at all — its own
`'This function is currently disabled'` check can never actually run
through the UI. Harmless (the button is already correctly inert), just
redundant.

Added `test/screens/admin_dashboard_test.dart` (3 cases), `test/screens/books_table_test.dart`
(7 cases), `test/screens/book_upload_form_test.dart` (5 cases), `test/screens/cloud_functions_panel_test.dart`
(4 cases), and `test/screens/admin_portal_screen_test.dart` (9 cases: the
sign-in gate for both admin-detection paths — a `role: admin` on the
user's own doc, and the `admins` collection fallback — a non-admin's
access-denied auto-sign-out, a failed and a successful sign-in, the
sidebar's tab-switching, and sign-out).

## Cleanup pass: a predictable-PIN vulnerability, dead code, and a lot of orphaned-but-working code left for a decision (2026-09-12)

With every screen now covered, did a repo-wide pass for dead code,
duplication, and lingering vulnerabilities.

**Real vulnerability fixed: the parent-access PIN was predictable, not
random.** `ParentLinkQRScreen` generates the 6-digit PIN a child shows a
parent to link accounts (`100000 + DateTime.now().millisecondsSinceEpoch %
900000`). This PIN is a bearer credential — `AddChildScreen._linkChildWithPin`
and `QRScannerWidget` both grant parent access (reading history, analytics,
the ability to remove the child's account) to anyone who presents it,
looked up by a direct Firestore query with no rate limiting. Deriving it
from wall-clock time means anyone who roughly knows *when* a PIN was
issued (e.g. watching a child open this screen) can narrow the guess space
from 900,000 down to a handful of candidates, and any authenticated user
could try candidates directly against Firestore with no lockout. Fixed by
switching to `Random.secure()`, which draws from the OS's cryptographically
secure RNG. Added `test/screens/parent_link_qr_screen_test.dart` (3 cases),
including a regression test that would have caught the original bug
directly: two PINs generated back-to-back (achievable within the same
millisecond during a fast test run) must differ — under the old
clock-derived generator they'd have been identical.

**Note, not fixed:** the underlying lookup — any signed-in user can query
`users` where `accountType == 'child' && parentAccessPin == <guess>`
directly against Firestore, with no attempt throttling — is a real
residual weakness in the design (900,000 possibilities is a lot to brute
force by hand, but not against an automated script with no rate limit).
Properly closing this needs either a Cloud Function that throttles PIN
attempts server-side, or shortening the PIN's validity window (e.g.
expiring/rotating it after use or after a few minutes) — a bigger design
change than this cleanup pass, flagged here for whoever owns this feature
next.

**Confirmed-dead code removed** (each verified as truly unreferenced
before deletion, not merely "looks unused"):
- `lib/main_debug.dart` — an empty (0-byte) file.
- `lib/screens/child/change_avatar_screen.dart` — a full standalone
  avatar-picker screen, entirely superseded by `profile_edit_screen.dart`,
  which has its own inline avatar picker doing the same job; nothing
  navigates to the standalone screen anywhere.
- `SetGoalsScreen`'s ~67-line trailing block of old, commented-out,
  fully-duplicate implementation (leftover from whatever produced the
  current, working version above it in the same file).
- `ParentDashboardScreen`'s `_childDataStream` field: a real-time Firestore
  listener created (`.snapshots()`) but never actually subscribed to
  anywhere in the file (no `StreamBuilder`, no `.listen()`) — inert,
  presumably a half-finished live-update feature.

**Book-card duplication — since consolidated (user approved: "Yes,
consolidate now").** Book-card rendering — cover image/emoji fallback,
title, author, progress bar, and the Start/Resume/Re-read action button —
was implemented separately at least **six times**: the standalone, tested
`BookCard` widget (unused before this), `ChildHomeScreen._buildBookCard`,
and five near-identical inline copies inside `LibraryScreen` (one per tab:
All Books, For You, Reading Now, Finished, My Favorites), each with its
own duplicate cover-rendering method to boot (`LibraryScreen._buildBookCover`
duplicated the already-existing shared `BookCover` widget, whose own doc
comment said it was built to replace exactly this). Earlier in this pass,
a real progress-bar unit-mismatch bug was found and fixed in the
standalone `BookCard` widget specifically because it had its own test
file — `ChildHomeScreen`'s copy was checked at the time and confirmed
already correct, but the fact that one of six near-identical
implementations had a real bug and the other didn't is exactly the risk
duplicated code like this carries: a fix to one copy did nothing for the
other five.

Rewrote `lib/widgets/book_card.dart`'s `BookCard` to the design that was
actually live everywhere (`ChildHomeScreen`'s version — Container with a
purple-tinted shadow, `BookCover` + title/author/time/age rows +
conditional progress row + a `ProgressButton`), parameterized with
`enableHero` (library tabs render several of the same book across
simultaneously-mounted `TabBarView` children, so their call sites pass
`false` to avoid duplicate-Hero-tag collisions; `ChildHomeScreen` keeps the
default `true`), `buttonTextOverride`/`buttonTypeOverride` (the
Ongoing/Completed tabs already know their book's bucket and shouldn't
re-derive a possibly-stale one from `progress`), and `alwaysShowProgress`
(the Completed tab shows 100% even for an entry with no progress doc yet).
`ChildHomeScreen._buildBookCard` and all 5 `LibraryScreen` tabs now build
this one widget instead of their own inline copy;
`LibraryScreen._buildBookCover` was deleted along with it. Rewrote
`test/widgets/book_card_test.dart` for the new design (7 cases, including
regressions for the override params and for `enableHero: false` actually
omitting the `Hero`). Full suite re-run after the change: still 321/321
passing, `flutter analyze` clean. (After the `LeagueWidget`
deletion/`DailyQuestService` wiring below, the suite sits at 319/319 —
net of removing `league_widget_test.dart`'s 6 cases and adding
`leaderboard_screen_test.dart`'s 3.)

**Admin console — now wired up (user asked for a recommendation).**
`AdminPortalScreen` and its four tabs (`AdminDashboard`, `BookUploadForm`,
`BooksTable`, `CloudFunctionsPanel`; ~1,930 lines, fully tested earlier in
this session) were unreachable from either app entry point — no route, no
button, no gesture led to it anywhere in `lib/`. Recommended and added a
`/admin` route in `lib/main.dart`: the screen is fully built and tested,
the functionality (managing books, monitoring Cloud Functions) is valuable
enough to be worth exposing, and — most importantly — the screen already
gates itself independently (it checks the signed-in user's Firestore role
or the `admins` collection fallback and shows its own sign-in form to
anyone who isn't an admin), so a route name reaching it costs nothing on
its own. If a proper admin entry point (a hidden gesture, a separate build
flavor, an internal-only web build) is wanted instead, that's a follow-up
decision for whoever owns this feature.

**`LeagueWidget` / `DailyQuestService` — resolved (user: "remove whatever
isn't necessary and anything that really makes sense to have, make it
work").** After explaining what each did (previous entry), followed up by
actually deciding each rather than leaving both parked:

- **`LeagueWidget` — deleted** (`lib/widgets/league_widget.dart` +
  `test/widgets/league_widget_test.dart`). It rendered a "current league +
  progress toward the next tier" card, but nothing needed exactly that
  layout: `LeaderboardScreen` already has its own inline per-league
  grouping UI (`_buildTop3ByLeagueSection`, using `LeagueHelper` directly
  for each league's name/color/icon), which is the only place in the app
  that presents league information at all. An unused, never-embedded
  presentational widget duplicating ground the leaderboard already covers
  isn't worth keeping on the chance a future screen wants this exact card.
  `LeagueHelper` itself (the logic `LeagueWidget` wrapped) is untouched and
  still live via the leaderboard and `league_promotion_screen.dart`.
- **`DailyQuestService` — wired up, actually working now.** While
  reviewing where this would plug in, found that `LeaderboardScreen`
  already had a "Today's Goals" card (`_buildDailyGoalsCard`) — showing
  "Read 15 minutes" / "Keep your streak" rows with "+3 ⭐" / "+2 ⭐" labels —
  that was **purely cosmetic**: it computed completion live from
  `UserProvider` stats on every build and never persisted anything or
  actually credited a single star, despite promising to. Meanwhile the
  real, tested, persistence-and-reward backend for exactly this
  (`DailyQuestService`) sat completely unused. Wired the two together:
  `LeaderboardScreen` now calls `DailyQuestService.upsertTodayFromStats`
  on load with the child's real today's-minutes/goal/hasReadToday, stores
  the result, and renders the three quest rows (including the "mini read"
  quest the old card never showed at all) from the persisted doc, falling
  back to the live-computed values only until that finishes loading. When
  all three quests complete for the first time that day, stars are now
  actually awarded (`totalAchievementPoints`/`allTimePoints` incremented
  server-side) and `AuthProvider.reloadUserProfile()` is called so the
  rest of the app picks up the new total, with a confirmation SnackBar.
  Added `test/screens/leaderboard_screen_test.dart` (3 cases): a fresh
  visit persists a real quest doc instead of just computing one in memory,
  all three quests (including the previously-missing "mini read" row)
  show as not completed with no reading yet, and — regression for the old
  cosmetic-only behavior — no stars are silently granted and the user's
  point totals stay untouched when nothing is actually complete.

**Eight small, entirely unreferenced and untested widgets — deleted (user
approved: "Yes, delete all 8").** `book_list_item.dart`,
`loading_indicator.dart`, `shimmer_loading.dart`, `achievement_popup.dart`,
`floating_animation.dart`, `animated_list_item.dart`, `bounce_button.dart`,
`rotating_animation.dart`. Unlike `LeagueWidget`/`DailyQuestService`, none
of these had test coverage, which read as early-development scaffolding
rather than a shipped-then-orphaned feature — confirmed zero references
via `grep` immediately before deletion, then confirmed `flutter analyze`
still clean afterward.

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
  320 cases total): the app's core scoring logic pulled into pure
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
  the `BookCard` progress-bar bug); `LeagueHelper` (16 cases — see
  "League thresholds" above for the restored Platinum tier and the
  rebalanced point values); and the screen-level tests
  (`test/screens/`, 110 cases — `BookQuizScreen` and `ContentFilterScreen`,
  see "First screen-level widget tests" above for the content-filter
  regression that surfaced; `ChildHomeScreen`, see "ChildHomeScreen: a
  build()-time singleton crash..." above for the two bugs and two
  Flutter-test-framework gotchas that surfaced there; `LibraryScreen`, see
  the same section for the empty-state layout-overflow bug that surfaced
  there; `LoginScreen`/`RegisterScreen`/`AccountTypeScreen`, see "Auth
  screens" above for the provider-scoping and off-screen-tap test gotchas
  that surfaced there; `ParentHomeScreen`/`ParentDashboardScreen`, see
  "ParentHomeScreen, ParentDashboardScreen, and a real layout-overflow bug
  in the QR scanner" above for the QR-scanner layout bug and the
  initState()-vs-build()-time exception test gotcha that surfaced there;
  `AddChildScreen`/`QRScannerWidget`/`ReadingHistoryScreen`/
  `SetGoalsScreen`, see "AddChildScreen, QRScannerWidget,
  ReadingHistoryScreen, and a dead SetGoalsScreen" above for the
  pop-discards-the-SnackBar test gotcha and the dead-screen/
  no-persistence findings; and the admin console (`AdminPortalScreen`,
  `AdminDashboard`, `BookUploadForm`, `BooksTable`, `CloudFunctionsPanel`),
  see "Admin screens" above for the two always-reproducible layout-overflow
  bugs and the file_picker/firebase_storage_mocks findings — this
  completes screen-level coverage for every screen in `lib/screens/`; and
  `ParentLinkQRScreen`, see "Cleanup pass" above for the predictable-PIN
  vulnerability fix).
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
- Widget/screen tests now exist (see "First widget tests" and "First
  screen-level widget tests" above) for four widgets under `lib/widgets/`
  and two screens (`BookQuizScreen`, `ContentFilterScreen`) — but that's 2
  of ~40 screens under `lib/screens/`. Everything else is still untested:
  the library/home screens, onboarding, auth, the rest of the parent
  dashboard, the admin panel. This is a real gap, not just an omission: a
  widget test catches a different class of bug (a screen crashing on null
  data, a button wired to the wrong handler) than any other test in this
  file can — and it's already found two real, unrelated bugs (the
  progress-bar unit mismatch, the content-filter category drift) in the
  two screens actually covered so far.
- Recommendation/business logic runs client-side in Dart rather than in a
  trusted backend — Cloud Functions bypass Firestore rules entirely via the
  Admin SDK, but the Flutter client's own scoring/matching logic is still
  visible to and tamperable by a sufficiently motivated user.
- The in-app privacy policy claims "COPPA Compliant" — that claim should be
  re-reviewed (parental consent flow, data minimization, deletion handling)
  now that the data-access story has actually changed, not left as boilerplate.

## Emoji-to-vector-icon pass, and a systematic narrow-phone overflow scan (2026-09-12)

Two related UI passes, done together since both involved touching most of
the same gamification screens:

**Emoji cleanup.** Removed purely decorative emoji from titles, status
text, share messages, admin console headers, and push-notification copy
(left untouched: avatars and book-cover fallback art, where the emoji
genuinely is the content). Separately, converted the remaining
"judgment call" bucket — league badges, weekly-challenge icons, and
celebration-screen badges — from literal emoji glyphs to Material
`Icon`s, per your explicit request that this **not** turn into a wall of
uniform purple: `LeagueHelper.getLeagueIcon` (replacing
`getLeagueEmoji`) keeps each tier's existing non-purple color
(bronze/silver/gold/platinum/diamond-blue); `WeeklyChallenge.emoji` now
holds an `IconMapper` key rendered through a new
`IconMapper.getChallengeColor`, one of 12 distinct colors per challenge
type; the three celebration-screen badges and the leaderboard's "stars"
chips got the same treatment. While screenshotting `LeaguePromotionScreen`
to verify the color changes, found and fixed a real, unrelated bug it
was hiding: its Lottie animation referenced
`assets/animations/trophy.json`, which never existed (the real file is
`trophy_badge_animation.json`) — `Lottie.asset()` throws on a missing
asset, so the trophy animation had been broken for every user reaching a
league promotion. Added `test/asset_paths_test.dart`, which scans every
asset-path string literal in `lib/` and asserts the file exists, so this
class of typo can't ship silently again for any asset.

**Overflow scan.** Grepped `lib/` for the specific shape that had already
caused two real bugs earlier in this file (an unconstrained `Row` mixing
an icon and/or multiple `Text` widgets with no `Expanded`/`Flexible`/
`Wrap`), then verified each candidate with a real `tester.binding.
setSurfaceSize` widget test at a phone-realistic width (320-360px)
before touching anything — several candidates that looked suspicious by
the grep alone turned out not to actually overflow and were left alone.
Confirmed and fixed real overflow bugs in: `ChildHomeScreen` (three
section headers), `LeaderboardScreen` (the "Top 3 by league" header),
`LibraryScreen` (the page header) and `BookCard` (the time/age-rating
row — one fix that covers every screen using the card), `book_quiz_screen.dart`
and `quiz_screen.dart` (both share a near-identical "Question X of Y /
Z% Complete" header, plus `quiz_screen.dart`'s own intro-dialog info
rows and its five-fixed-circle 1-5 Likert rating row, made responsive
via `LayoutBuilder` since `spaceEvenly` can't shrink fixed-size
children), `ProfileBadgesWidget`'s badge grid (`FittedBox` per tile),
and `BadgesScreen`'s unlock-count row. Also found and fixed
`CelebrationConfetti`: its decorative `ConfettiWidget`s were hit-testing
over their full area, making buttons underneath briefly untappable
while confetti played — wrapped in `IgnorePointer`. This overflow work
continued into the screen-by-screen pass below, where several more
instances of the same anti-pattern turned up in screens that had no
test coverage at all yet.

## Fourteen screens that turned out to have no test coverage, and the real bugs each one surfaced (2026-09-12)

The "Admin screens" entry above claimed screen-level test coverage for
"every screen in `lib/screens/`". That claim was wrong (or went stale as
screens were added after it was written) — a fresh check found **14
screens with zero test coverage**: `BookCompletionCelebrationScreen`,
`BookQuizCelebrationScreen`, `AchievementCelebrationScreen`,
`BadgesScreen`, `HelpSupportScreen`, `LeaguePromotionScreen`,
`PrivacyPolicyScreen`, `WeeklyChallengeCelebrationScreen`,
`OnboardingScreen`, `SettingsScreen`, `ProfileEditScreen`,
`QuizResultScreen`, `SplashScreen`, and `BookDetailsScreen`. All 14 now
have render/interaction/narrow-width-overflow test coverage (`test/
screens/`, +14 files). Real bugs found and fixed along the way, beyond
the overflow-scan findings folded in above:

- **Missing `mounted` guards on delayed callbacks** (the same class of
  bug as the Lottie/confetti findings above): `BookCompletionCelebrationScreen`
  and `BookQuizCelebrationScreen` each had a `Future.delayed` animation-start
  callback with no `mounted` check, so closing the screen before the
  delay elapsed could call methods on an already-disposed
  State/AnimationController.
- **No scroll fallback on fixed-size celebration layouts**:
  `BookCompletionCelebrationScreen`, `BookQuizCelebrationScreen`,
  `AchievementCelebrationScreen`, and `WeeklyChallengeCelebrationScreen`
  all laid out a trophy/badge icon plus title/message/points in an
  `Expanded(child: Center(...))` with no scrollable fallback — genuinely
  didn't fit on shorter real devices, not just an artificial test
  viewport. Fixed with `LayoutBuilder` + `SingleChildScrollView` +
  a min-height `ConstrainedBox` (replacing any `Spacer`, which needs a
  bounded main axis, with a fixed-height gap).
- **`SettingsScreen`**: the badges card's row of up to 4 fixed-70px
  tiles (≈304px minimum) had no scroll/wrap fallback — wrapped in a
  horizontal `SingleChildScrollView`. Separately, its `_buildSettingsCard`
  wrapped each `ListTile` in a `Container` with its own white background,
  so the tiles' ink splashes painted on the Scaffold's `Material` far up
  the tree instead — invisible ripples, and a `FlutterError` on every
  build in debug/test mode. Fixed by giving the card its own transparent
  `Material`. Also found and fixed the same overflow shape in the
  **shared bottom nav bar** (`AppBottomNav`, used by
  Home/Library/Leaderboard/Settings): its 4 tabs had no flex/shrink
  behavior and overflowed by 25px at 320px width — every screen using it
  inherited the bug.
- **`ProfileEditScreen`** and **`QuizResultScreen`**: both reached
  directly for real singletons (`FirebaseAuth.instance`/
  `FirebaseFirestore.instance`, and a bare `AchievementService()`
  respectively) with no way to substitute a fake in tests — gave both
  the same `@visibleForTesting` optional-constructor-param seam used
  everywhere else in this file. `QuizResultScreen`'s "Books We'll
  Recommend:" header also had the same unflexed icon+text `Row`
  overflow as the rest of this scan.
- **`BookDetailsScreen`**: the same untestable-singleton gap (the
  bottom action bar's real-time-progress `StreamBuilder` read
  `FirebaseFirestore.instance` directly). Also a real, if usually
  self-correcting, unit-mismatch bug: before that stream's first
  snapshot arrives, the Quiz-unlock check compared
  `freshProgress.progressPercentage` (a 0.0-1.0 fraction) against a
  `>= 100` threshold meant for a 0-100 percentage — so a book already
  at 100% progress would render with Quiz still locked for one Firestore
  round trip. Scaled the fallback value to match.
- `test/asset_paths_test.dart`'s regex (added above) was extended to
  allow spaces in filenames after discovering real illustration assets
  with spaces in their names that it had been silently skipping.

**A `flutter_test`-specific gotcha worth recording, found while testing
`SplashScreen`**: a helper that builds an `AuthProvider` and awaits a
`Future.delayed(Duration.zero)` so its `authStateChanges()` listener has
a chance to run works fine when called from a `setUp()` callback (a
normal Dart zone), but hangs forever if the exact same helper is called
directly inside a `testWidgets` body — the whole test body runs inside
`flutter_test`'s `FakeAsync` zone, which never auto-advances a real
`Timer`-backed delay without an explicit `tester.pump(duration)`. Fixed
by swapping the real delay for a plain microtask yield
(`Future<void>.value()`) in that one helper, since the only thing it
needs to wait for (the listener setting `_status`/`_user`) happens
synchronously before that listener's own internal `await`.

**Also, unrelated to any of the above:** found and deleted four leftover
`test/_scratch_*.dart` debugging files from earlier ad-hoc screenshot
work in this pass. They matched the `.gitignore` pattern (so `git
status` never showed them) but were still on disk, and a bare
`flutter test` (no path filter) picks up every `.dart` file under
`test/` regardless of `.gitignore` — one of them looped one of its own
test names hundreds of times and the whole run never reached the rest
of the suite before timing out. This is the same failure mode already
noted in this file for stray scratch files; the fix this time is the
same (delete them), the note here is just to flag that `.gitignore`
alone doesn't prevent this class of self-inflicted flakiness — a
leftover file left in place after `.gitignore` was updated to cover it
retroactively is still a live landmine until it's actually deleted.

## PdfReadingScreenSyncfusion: assessed, not widget-tested (2026-09-12)

The one screen deliberately left without test coverage. Assessed it
specifically (rather than skipping silently) since it's the largest and
most complex screen in `lib/screens/` (1,362 lines): widget-level test
coverage is impractical here without a disproportionate refactor. It
directly touches `FirebaseAuth.instance` at 8 call sites plus
`FirebaseFirestore.instance` and 3 more real singletons
(`ReadingSessionService`, `ContentFilterService`, `AchievementService`)
with no DI seams; makes real network requests (`http.get` to download
the PDF, at two separate call sites); does real file I/O
(`path_provider` + local file caching); and drives a native
text-to-speech plugin (`flutter_tts`) and the Syncfusion PDF viewer,
neither of which is mockable in this project's `flutter_test` setup.
Retrofitting DI across all of that is a much larger change than the
small, optional-constructor-param seams used everywhere else in this
pass, so no test file was added — this gap is being documented instead
of silently left unmentioned.

That review, done by reading rather than running, still surfaced real
bugs worth fixing on their own:
- The AppBar's book-title `Text` had no `maxLines`/`overflow`, unlike
  the identical title text in this same file's own loading skeleton
  (which already used `maxLines: 2` + ellipsis) — a real overflow risk
  for a long title or a narrow phone. Fixed to match.
- Four `setState()` calls in the PDF caching flow (`_checkPdfCache` /
  `_downloadAndCachePdf`), each after awaiting file-system or network
  I/O, had no `mounted` guard — popping the screen mid-download and
  then having that download resolve calls `setState()` on a disposed
  State. Guarded all four, matching the pattern already found and
  fixed twice elsewhere in this pass.
- Five more `setState()` calls in the text-to-speech flow
  (`_togglePlayPause`, `_readCurrentPageContent`, `_speakSelectedText`),
  each after an awaited TTS or PDF-text-extraction call, had the same
  gap. Guarded them too, and removed one now-redundant duplicate
  `mounted` check left over from the fix.

## Final verification for this pass (2026-09-12)

`flutter analyze`: clean across the whole project, no issues.
`flutter test` (full suite, all `test/` files, run fresh after deleting
the leftover scratch files noted above): **395/395 passing**, up from
320 at the start of this pass — the difference is the icon/overflow
regression tests folded into existing files plus the 14 new screen
test files above.

## PdfReadingScreenSyncfusion, take two: a deeper manual read finds a read-aloud bug worth fixing (2026-09-13)

Went back for a closer line-by-line pass on the one screen left without
test coverage, since "impractical to widget-test" isn't the same as
"nothing left to find by reading." Two more real bugs, fixed:

- **Read-aloud ignored its own PDF cache and leaked memory.**
  `_checkPdfCache()` downloads the PDF once and saves it to
  `_cachedPdfFile` specifically so the viewer doesn't re-fetch it — but
  `_extractTextFromCurrentPage()`, which runs on every single
  text-to-speech page turn (including every auto-advance to the next
  page while reading aloud), never looked at that cached file. It called
  `http.get(widget.pdfUrl)` and re-downloaded and re-parsed the entire
  PDF from scratch on every page turn, adding a full network round-trip
  to the read-aloud pacing and wasting bandwidth for no reason — the
  cached file was sitting right there unused. Worse, each call
  reassigned `_pdfDocument` to a freshly-constructed `PdfDocument`
  without disposing the previous one first (only the very last one gets
  disposed, in `dispose()`) — `PdfDocument` holds native resources, so a
  longer read-aloud session leaked one per page turn. A second-order
  effect: if the device went offline after the initial (cached) view had
  already loaded, read-aloud broke entirely, and the resulting empty
  string was indistinguishable from a page that's genuinely just an
  image — so the child saw "This page appears to contain images or
  non-readable content" instead of anything indicating a connectivity
  problem. Fixed by reading from `_cachedPdfFile` when it exists
  (falling back to the network fetch only when it doesn't) and disposing
  the previous `PdfDocument` before replacing the reference.
- **A literal `\n\n` shown to the child.** The screen-time-limit dialog's
  message used `'...\\n\\n...'` in the Dart source — an escaped
  backslash followed by a literal `n`, not a newline. A kid hitting
  their daily limit would see the raw text `minutes.\n\nPlease take a
  break...` instead of a line break. Fixed to a real `\n\n`.

**Found but not fixed — lower confidence, needs device verification
rather than a blind change:**
- No cache invalidation: the cache key is a hash of the URL alone, so
  replacing a book's PDF at the same URL (e.g. fixing a typo) would
  leave every device that already opened it serving the stale cached
  copy indefinitely, with no expiry or version check.

`flutter analyze`: clean. Full `flutter test` suite re-run after these
changes: still passing (this screen has no dedicated test file, per the
feasibility assessment above, so this run is a regression check on the
rest of the suite, not new coverage of this fix).

## PdfReadingScreenSyncfusion, take three: the dwell-timer threshold gap (2026-09-13)

Fixed the anti-cheat gap flagged above rather than leaving it
undecided. The page-dwell timer's required threshold (300ms normally,
600ms near the end of the book, to stop rapid swiping from counting as
"read") was computed once, when `_onPageChanged` started the timer, and
captured in a local variable. But the timer's own defensive polling
loop — there specifically to catch the PDF viewer's `onPageChanged`
callback missing an intermediate page during a fast swipe — could
silently retarget `_pendingPage` to a different page mid-timer without
ever recomputing that threshold. Landing on a near-the-end page that
way would still use whichever threshold the timer originally started
with, potentially the shorter 300ms one instead of the intended 600ms
anti-cheat delay.

Fixed by extracting the threshold computation into
`_dwellThresholdForPage(page)` and calling it fresh against the
*current* `_pendingPage` on every timer tick, instead of capturing a
value once at timer start — so a mid-timer retarget to a near-the-end
page now correctly picks up the longer threshold from that point
forward. `flutter analyze` clean; full suite still passing (regression
check only, same caveat as above — no dedicated test file for this
screen).

## Recommendation engine: already-finished books were never excluded, and a real N+1 Firestore pattern (2026-09-13)

Went from "app logic suggestions" to fixing two of them: the recommendation
engine recommending books a child already finished, and a genuine
performance/cost problem in the signal-aggregation Cloud Function.

**Already-completed books could keep occupying recommendation slots.**
Traced the whole pipeline (`BookProvider.loadRecommendedBooks`,
`combinedRecommendedBooks`, and the Cloud Functions side in
`generateAIRecommendations`) and confirmed none of it excluded books the
child has already finished from the candidate pool — only
`combinedRecommendedBooksForDisplay` (used by `ChildHomeScreen`) sorted
completed books to the bottom, and even that was a display-only
reordering, not an exclusion, and wasn't applied to the Library screen's
"Recommended" tab (which calls `combinedRecommendedBooks` directly) or
to the AI tier at all. Since a child's already-favorite, best-loved
books are exactly the ones most likely to score highest by trait match,
this could crowd out books they haven't tried yet with ones they just
finished.

Fixed at the source on both sides:
- `BookProvider` gained `_completedBookIds` and
  `_excludingCompletedUnlessEmpty(books)` — the latter degrades
  gracefully (returns the unfiltered list) if a child has finished every
  book currently in their library, rather than recommending nothing.
  Applied to `loadRecommendedBooks`'s rule-based scoring pool, its
  "no trait matches" fallback, and `combinedRecommendedBooks`'s own
  rule-based pass. Deliberately *not* applied to
  `getBooksSortedByRelevance` (plain library browsing/sorting, where a
  child should still see books they've read).
- `functions/index.js`'s `generateAIRecommendations` now takes `userId`
  and queries the child's completed `reading_progress` docs before
  building the OpenAI prompt, filtering `availableBooks` the same way
  (with the same graceful-degradation fallback).

**`aggregateUserSignals` batched: was up to 100+ sequential Firestore
reads per user, per daily run.** Every favorited book, every completed
book, every in-progress book, every quiz attempt, and every book with
2+ long sessions each triggered its own `await
db.collection('books').doc(id).get()`, one at a time in a loop — and
the same book could be fetched repeatedly across categories (e.g.
favorited *and* completed *and* in-progress). For an engaged user with
dozens of interactions across a school year, that's dozens to 100+
sequential round trips in the 3 AM daily job, run once per active user.

Restructured to collect every signal source's referenced book IDs
first (without fetching anything), then fetch all of them in a single
batched round trip via Firestore's `getAll(...)`, deduplicated, and
apply each signal's existing per-record weight from that one shared
lookup. Weighting semantics are unchanged (a re-read still counts more
than a first completion, multiple qualifying records for the same book
still each contribute their own weight, quiz traits still seed the
scores at a flat weight before everything else adds on top) — this was
a performance/cost fix, not a scoring-behavior change, and the existing
emulator tests (which exercise every weighting rule) confirm that:
29/29 passing unchanged. New helper `fetchBooksByIds(db, ids)` is now
also what `generateAIRecommendations`'s completed-books check could
reuse if that function ever needs per-book data.

`flutter analyze` clean on `book_provider.dart`; `eslint` clean on both
Cloud Functions files; `npm test` (35/35) and `npm run test:emulator`
(29/29) both still passing; full Dart suite re-run as a regression
check.

## Two more app-logic suggestions implemented: exploration slots and a proportional personality split (2026-09-13)

**Exploration slots in `combinedRecommendedBooks`.** Every recommendation
slot up to this point was earned by an actual trait match — meaning a
child who tested strongly into a couple of traits would only ever see
books tagged with those same traits, forever. Reserved up to 2 slots for
books with zero trait overlap, picked newest-first (favoring likely-
undiscovered new arrivals over a random pick, so this stays deterministic
and testable) and always ranked after every real match, never displacing
one. Scoped deliberately to `combinedRecommendedBooks` (the actual
UI-facing entry point, via both the Library "Recommended" tab and
`combinedRecommendedBooksForDisplay` on the home screen) rather than
`loadRecommendedBooks`'s own `_recommendedBooks`/AI-tier state, which
other code and tests key off of as "the current AI or rule-based pick" —
touching that directly would have had much wider, less predictable
ripple effects for comparatively little gain, since the AI tier
overwrites it outright whenever it has data.

This intentionally relaxes an invariant a couple of existing tests
encoded ("a zero-match book is always excluded") — updated those to
verify the new, intended behavior instead (a real match still always
outranks an exploration pick; the exploration pool is capped at 2 and
never duplicates a book already present via AI or rule-based matching)
and added dedicated tests for the ordering and dedup rules.

**Proportional split for the OCEAN quiz's trait allocation.** The
personality quiz always handed exactly 3 of the 5 saved traits to the
top-scoring dimension and the other 2 to whichever dimension placed
2nd — regardless of how close 2nd and 3rd actually were. Since every
OCEAN dimension has exactly 3 sub-traits to offer, the top dimension can
never contribute *more* than 3 (there's no "landslide" case to reflect
there) — the only real lever is whether a 3rd-place dimension within
striking distance of 2nd ever gets a look-in, or is flattened away just
for placing one rank lower. Replaced the flat "2nd place always gets
both remaining slots" rule with D'Hondt allocation (the same
divisor-based method used for allocating parliamentary seats by vote
share) across the 2 remaining slots: a clearly-separated runner-up (more
than double the 3rd-place score) still keeps both, unchanged from
before, but a genuinely 3-way-split personality now gets that reflected
in the traits saved for book matching instead of one arbitrary
tie-break-driven trait set.

Deliberately scoped to affect only [`getAllTraits`]'s traits #4-5 (the
book-matching signal saved to Firestore) — [`getTopTraits`]'s 3 displayed
traits ("Your Top 3") are always exactly the top dimension's own 3 and
are provably unaffected by this change (verified by a dedicated test),
so the results-screen copy a child actually reads is unchanged; only the
less-visible recommendation-matching signal got more nuanced. Two
existing characterization tests whose example scores happened to fall
into "3rd place deserves a share" territory were updated to document the
new, intentional output for those exact inputs, and 3 new tests pin down
the boundary explicitly: a distant 3rd place still loses out entirely,
a close 3rd place shares a slot, and a tie between two contenders for a
D'Hondt slot resolves the same way the existing top-place tie-break
already did (whichever appears first in the input map's construction
order).

`flutter analyze` clean on both files; `personality_scoring_test.dart`
(17 cases, up from 14) and `book_provider_test.dart` (14 cases, up from
12) both passing; full suite re-run as a regression check.

## Point-value audit: weekly challenges promised points they never paid (2026-09-13)

Went through every point-earning path in the app — achievement unlocks
(`getDefaultAchievements()`), book completion, daily quests, quiz
completion, and weekly challenges — to sanity-check the actual numbers
against the league thresholds set earlier in this file. Found one real,
unambiguous bug and one piece of genuinely dead code; both fixed. The
numbers themselves check out (see the calibration summary at the end).

**Weekly challenges never actually awarded their advertised points —
same "cosmetic reward" bug class as the daily-quests card fixed earlier
in this file.** `WeeklyChallengeCelebrationScreen` has always taken a
`pointsEarned` parameter and rendered a "+N points" badge, and
`ChildHomeScreen` has always passed it a hardcoded `50`. But nothing in
`WeeklyChallengeService` or either of `ChildHomeScreen`'s two
challenge-completion code paths (`_checkWeeklyChallengeOnce`, run once
on load, and the live Firestore-listener path behind
`_buildWeeklyChallengeCard` that reacts to the challenge flipping
complete while the screen is open) ever called
`AchievementService.awardPoints` or wrote to `totalAchievementPoints` —
the celebration screen was purely cosmetic. A child could complete every
weekly challenge all year and their league point total would never move
because of it, despite the UI insisting otherwise every single time.

Fixed by awarding the points (via `AchievementService.awardPoints`,
which applies the existing streak multiplier — see below) at both
completion sites, gated by the same `weeklyChallengeSeen` flag that
already prevents the celebration from re-showing, so a completion is
credited exactly once. The `50` is now a single `_weeklyChallengePoints`
constant shared between the award call and the celebration screen's
displayed number, so they can't drift apart again. Added a regression
test (`child_home_screen_test.dart`) exercising the live-listener path
end-to-end with fake-backed services, asserting `totalAchievementPoints`
actually increases when the challenge flips to completed — this required
adding `achievementServiceOverride`/`weeklyChallengeServiceOverride`
test seams to `ChildHomeScreen` (it previously reached both as real,
untestable singletons; only `firestoreOverride` existed).

**The streak-based point multiplier was fully implemented and tested,
but wired to nothing.** `AchievementService.getStreakMultiplier` (1.0x /
1.1x at 7+ days / 1.25x at 30+ days / 1.5x at 100+ days) is only ever
consulted through `awardPoints(currentStreak: ...)`, and the *only* real
call site (`QuizGeneratorService.awardQuizPoints`, for book-quiz points)
hardcoded `currentStreak: 0` — meaning every quiz-point award used a
1.0x multiplier no matter how long a child's streak actually was. The
multiplier logic itself was correct and covered by tests; it just never
received real data. Added a `currentStreak` parameter to
`awardQuizPoints` (default `0`, so existing callers/tests are
unaffected) and wired `book_quiz_screen.dart` to pass the child's real
`UserProvider.dailyReadingStreak`; the new weekly-challenge award above
does the same. Displayed point amounts (the quiz celebration screen, and
the weekly-challenge one) still show the pre-multiplier base tier —
a streak bonus can now silently credit a little more than what's shown,
which is a minor, harmless "at least this many" undersell rather than
the previous "shows a number, credits nothing" bug, and not worth the
larger refactor `awardPoints` would need to report back its
post-multiplier total.

**Point-value calibration, checked against the League thresholds
section above:** one-time achievement unlocks sum to 627 points if every
tier is unlocked (books_read 407, reading_streak 71, reading_time 49,
reading_sessions 100); book completion is 5 points first time / 2 on a
re-read; quiz completion is tiered 0/1/3/5 by score (now streak-boosted,
per above); daily quests pay 10/day but only as an all-or-nothing bundle
gated on actually meeting the daily reading-minutes goal; weekly
challenges pay a flat 50 (now actually delivered). Re-checked this
against the reasoning already on record in this file's "League
thresholds" section, which explicitly priced in daily-quest and quiz
points when landing on Diamond at 1,500 — that reasoning holds up: a
consistently engaged reader clears Diamond in a few months primarily
through daily quests and streak-boosted quizzes, with book completions
and one-time achievement unlocks adding a slower but steady baseline
underneath. Weekly challenges' 50 points (now real) is a meaningful but
not dominant top-up — roughly one Bronze/Silver tier's worth every 12
weeks. Nothing here contradicts the earlier judgment call; the fixes
above just make the numbers already reasoned about actually true.

`flutter analyze` clean; full suite passing (401 tests, up from 395 —
the new weekly-challenge regression test plus the `UserProvider` seam
now required by `book_quiz_screen_test.dart`'s existing tests).

## Content-filter and admin-upload deep dive (2026-09-13)

Reviewed `ContentFilterService`'s actual word lists/category logic as a
safety-critical component, and the admin console's book-upload/AI-tagging
pipeline it depends on. One real, silently-non-functional parental
control found and fixed; one more significant gap found in the AI
tagging pipeline and fixed; a third finding turned out, on tracing it all
the way through, to not be a live bug — noted below for the record so it
isn't re-investigated from scratch later.

**"Allowed reading hours" was computed but never enforced — a bedtime
restriction a parent set would silently do nothing.**
`ContentFilterService.getReadingTimeRestrictions()` has always computed
`isCurrentTimeAllowed` from the filter's `allowedTimes` window (default
`06:00-22:00`), but the only caller
(`pdf_reading_screen_syncfusion.dart`'s `_checkScreenTimeLimit`) only
ever read `hasRestrictions`/`maxReadingTimeMinutes` from that map — the
daily-minutes limit was enforced, the time-of-day window never was. Wired
it in: opening a book outside the allowed window now shows an "Outside
Reading Hours" dialog and backs out, the same enforcement point already
used for the minutes limit. Worth noting this is a smaller win than it
sounds today — `content_filter_screen.dart` (the parent-facing settings
UI) never actually exposes `allowedTimes` for editing, so every family is
on the default 6am-10pm window right now; the enforcement fix at least
means that default now does something (a child reading at midnight is
now actually stopped), and a future settings UI for it would have
something real to plug into.

**Investigated, not a live bug: `_isSafeModeCompliant`'s hardcoded
inappropriate-words list scans `book['content']`, a field that doesn't
exist on any real book.** The `Book` model (`book_provider.dart`) has no
stored per-page text — books are read as PDFs via `pdfUrl`, not
page-by-page Firestore text — and the actual production filtering call
site (`BookProvider.loadAllBooks`) never includes a `content` key when
building the map passed to `filterBooks` in the first place. So this
loop has always executed against an empty list; in the current
PDF-based architecture, both the built-in safe-mode word list and a
parent's own custom `blockedWords` have only ever been checked against a
book's title and short description, never its real content. This isn't
a coding mistake in `_isSafeModeCompliant` so much as a leftover
assumption from a pre-PDF, page-array content model — and a client-side
per-page scan wouldn't be the right fix for it anyway (extracting text
from a PDF on every filter pass, for every book, for every filter
evaluation would be prohibitively expensive at client-side). The right
place to actually screen a book's real content is upload/tagging time,
server-side, where the text is already extracted once — which is
exactly the next finding.

**The AI tagging pipeline read a book's actual text but was never asked
to screen it for anything — the one automated point that could catch
unsafe content did categorization only.**
`processBookForTagging` (functions/lib/process_book_for_tagging.js)
downloads the PDF, extracts its text, and sends the first ~2000
characters to OpenAI — but the prompt (`buildTaggingPrompt` in
ai_helpers.js) only ever asked for tags/traits/age rating, never a
safety read. Combined with the previous finding (client-side safe-mode
filtering never sees real content either) and `book_upload_form.dart`
setting `isVisible: true` at upload time with no moderation step at all,
this meant a book's actual PDF content was never screened by anything,
at any stage, before becoming visible to children — the AI only ever
categorized, never screened. (In practice, an untagged book is already
invisible to every child by the *existing* categories filter, since
`allowedCategories` is non-empty by default and a fresh upload starts
with zero tags — a fully accidental protection during the tagging
window, not a deliberate one.)

Added a 4th instruction to `buildTaggingPrompt` asking the model to flag
`contentConcern` (+ a short `concernReason`) using the same theme
vocabulary `_isSafeModeCompliant` already checks client-side
(`CONTENT_CONCERN_THEMES`, kept explicitly in sync in a comment), scoped
the same way — real safety themes only, not ordinary sadness/fear/conflict.
`parseAndValidateTaggingResponse` sanitizes it the same way as
everything else the model returns: `contentConcern` is `true` only for
the literal boolean `true` (never guessed at from a truthy-ish string),
and `concernReason` is discarded unless there's an actual concern and
capped at 300 characters so a verbose response can't write an unbounded
field to Firestore. `processBookForTagging` now acts on it: a flagged
book gets `needsReview: true` and `isVisible: false` instead of sailing
through to full visibility the moment tagging completes.

Also hardened the *failure* path: if the whole OpenAI call fails
(`fallbackTaggingResult`, used for network errors/missing API key/bad
responses), `contentConcern` now defaults to **true**, not false — a
failed call means the safety check never ran at all, which is a
meaningfully different situation from "the model looked and found
nothing," and treating them the same would let a book go fully live with
zero content review of any kind whenever the AI call happens to fail.
Tags/traits still get their existing varied fallback so the book isn't
stuck in permanent `needsTagging` limbo — it's just held for a quick
human look instead of either silently blocked forever or silently made
fully visible.

`buildTaggingPrompt`'s extra instruction needs a little more room in the
model's response, so bumped `max_tokens` 200 → 300 on that OpenAI call
(index.js) to avoid the added fields getting the response truncated
mid-JSON.

Since there was no existing way for an admin to even discover a flagged
book (no moderation screen exists yet), added a fifth "Needs Review"
stat card to `AdminDashboard` counting `needsReview` books, matching the
existing "Needs Tagging"/"Missing PDF" cards. A dedicated review screen
(showing the flagged book's `concernReason` and a way to clear the flag
or delete the book) would be the natural next step, but is a real UI
decision left for a follow-up rather than guessed at here.

`npm run lint` clean; Cloud Functions unit tests 43/43 (up from 35) and
emulator tests 29/29, both passing; `flutter analyze` clean;
`admin_dashboard_test.dart` extended (5 cases, up from 3) and full
Flutter suite passing (402 tests, up from 401).

## Point-award security migration: every point field was directly client-writable (2026-09-13)

The deepest finding of this pass. `firestore.rules`' `users/{uid}` rule
let an account's own owner write **any field on their own doc except
`role`**:

```
allow update: if isAdmin() ||
  (canAccessAsUser(uid) && roleUnchanged()) ||
  isSelfLinkingAsParent();
```

Every point-earning action in the app — book completion, book quiz
scores, the personality quiz's one-time bonus, weekly challenges, daily
quests, achievement unlocks — was a plain Firestore write made **directly
from Flutter client code** (`AchievementService.awardPoints`/
`awardBookCompletionPoints`/`awardPersonalityQuizCompletion`/
`_unlockAchievement`, `DailyQuestService.upsertTodayFromStats`). Nothing
server-side ever checked these writes. That meant a modified client — or
literally opening browser devtools on a signed-in web session and
calling `firebase.firestore().collection('users').doc(myUid).update(...)`
by hand — could set `totalAchievementPoints` to any number directly.
This isn't "a kid can fake their own save file": `leaderboard_screen_impl.dart`
ranks real users against each other by that exact field, so it undermined
every league threshold, streak multiplier, and anti-cheat mechanism
fixed earlier in this file. User asked directly to fix this properly
("since 1 is the best, that's what we should go for — lazy work might
cost us later") rather than patch around it.

**The fix: every point-earning action now goes through an authenticated
Cloud Function, and the underlying fields are locked out of direct
client writes entirely.**

### New `functions/lib/points_engine.js`

Six functions, each exposed as an authenticated `onCall` in `index.js`
(`awardBookCompletionPoints`, `awardQuizPoints`, `awardPersonalityQuizPoints`,
`awardWeeklyChallengePoints`, `claimDailyQuestRewards`, `unlockAchievement`).
Every one:
- uses `request.auth.uid` as the acting user — **never** a client-supplied
  uid, so a caller can only ever award points to themselves;
- computes the credited amount itself from a fixed rule table or an
  achievement's own stored `points` field — never a client-supplied number;
- checks a server-only idempotency marker so the same qualifying event
  can't be paid out twice;
- re-derives whatever evidence is cheap to re-derive from Firestore
  instead of trusting a bare claim:
  - **book completion** re-reads the real `reading_progress` doc to
    confirm `isCompleted: true`, and determines first-vs-reread from a
    new `book_completion_awards/{userId}_{bookId}` doc instead of a
    client-reported flag (`pdf_reading_screen_syncfusion.dart` was
    reordered to update reading progress *before* awarding, since the
    award now depends on that write already having happened);
  - **quiz points** re-read the real `quiz_attempts` doc for its actual
    stored percentage rather than trusting a client-supplied one;
  - **weekly challenge** points re-read `weeklyChallengeCompleted`/
    `weeklyChallengeProgress` and add a new server-only
    `weeklyChallengeLastAwardedWeek` marker so toggling the (still
    client-written, see below) completed flag can't re-pay the same week;
  - **daily quests** are the most thoroughly closed: `claimDailyQuestRewards`
    re-derives `minutesReadToday` itself from the real `reading_sessions`
    collection (porting `ReadingSessionService.getTodayReadingMinutes`'s
    exact fallback-query logic to JS) instead of trusting a client-reported
    minutes/hasReadToday pair at all;
  - **achievement unlocks** read the real `achievements` doc for the
    unlock's true `type`/`requiredValue`/`points` (never a client-supplied
    point amount), and independently re-verify `books_read`/`reading_time`/
    `reading_sessions` achievements against real `reading_progress`/
    `reading_sessions` counts computed all-time (simpler than the
    client's 30-day-windowed display value, and only ever makes a
    threshold easier to legitimately reach sooner — never exploitable in
    the cheating direction).

**Honest, documented limits, not glossed over:** the underlying evidence
collections (`reading_progress`, `reading_sessions`, `quiz_attempts`) are
still writable by their owning account, same as before — closing that
fully means server-verified reading sessions (authenticated heartbeats),
a much larger project outside this pass's scope. `reading_streak`
achievements (71 of 627 total one-time achievement points) still trust
the client-reported streak — verifying it needs the same multi-source-
timestamp streak algorithm `FirestoreHelpers.calculateReadingStreak`
uses, and porting a second, easily-drifting copy of that logic felt
riskier than the gap it would close. Weekly-challenge *progress*
computation (whether 5 books were actually read this week) likewise
stays client-computed — only the point *payout* for a completed
challenge is now guarded. The streak-based point multiplier
(1.0x-1.5x, added earlier this session) was dropped rather than
half-secured: verifying it server-side has the same streak-algorithm
cost as above, so Cloud Function awards are base-rate only for now.

### The fallback path fails closed, not open

`fallbackTaggingResult`-style reasoning applied here too: `awardQuizPoints`
on an unrecognized `attemptId` throws `NotFoundError`; on someone else's
attempt, `ValidationError`; a repeat claim, `AlreadyAwardedError`. Each
maps to a distinct `HttpsError` code (`not-found`/`failed-precondition`/
`already-exists`) that Dart callers check for by name
(`isFunctionsErrorCode`) to distinguish "nothing to do" from a real
failure worth logging.

### Dart-side migration

New `lib/services/points_engine_client.dart` — one seam
(`PointsEngineClient`, with a `.withCaller()` test override, since
`cloud_functions` has no official fake/mock package) instead of six
separate ad-hoc `httpsCallable()` calls scattered across services.
`AchievementService`, `QuizGeneratorService`, and `DailyQuestService` now
call through it instead of writing to Firestore directly;
`QuizGeneratorService.saveQuizAttempt` now returns the created doc's ID
(needed by `awardQuizPoints`, which awards against a real attempt, not a
client-supplied score). `AchievementService.awardPoints`/
`getStreakMultiplier` and `WeeklyChallengeService.trackAchievementUnlock`
were deleted outright rather than left as unused, insecure-if-ever-called-
again dead code once every caller was migrated.

**Pitfall hit and fixed:** `PointsEngineClient`'s constructor originally
grabbed `FirebaseFunctions.instance` eagerly, which — unlike
`FirebaseFirestore.instance`/`FirebaseAuth.instance` — throws immediately
if Firebase hasn't been initialized, rather than returning a lazy proxy.
Since `PointsEngineClient()` is a singleton referenced as a default field
value in several services' constructors, this crashed *any* test building
one of those services at all, even tests that never touched points.
Fixed by resolving `FirebaseFunctions.instance` lazily, on the first real
call only (matching `QuizGeneratorService`'s own pre-existing
`_functions` getter, which already used this pattern for the same
reason).

### `firestore.rules` lockdown

Once every award path was migrated (verified via a repo-wide grep for
remaining direct writes to each field), added a `protectedPointFields()`
allowlist (`totalAchievementPoints`, `allTimePoints`, `weeklyPoints`,
`booksCompleted`, `dailyQuestStarsEarned`, `weeklyClubStars`,
`clubWeekKey`, `achievementsUnlockedThisWeek`,
`weeklyChallengeLastAwardedWeek`, `quizCompleted`, `quizCompletedAt`) and
denied non-admin clients from touching any of them, on create or update:

```
allow create: if isSelf(uid) && createTouchesNoProtectedFields();
allow update: if isAdmin() ||
  (canAccessAsUser(uid) && roleUnchanged() && updateTouchesNoProtectedFields()) ||
  isSelfLinkingAsParent();
```

`create` needed its own check too — the original rule let any user
create their own `users/{uid}` doc from scratch with **no field
restriction at all**, so a client could have set an inflated starting
`totalAchievementPoints` at signup, bypassing every update-side
protection entirely. `auth_provider.dart`'s `_createUserProfile` no
longer initializes `totalAchievementPoints`/`allTimePoints`/`weeklyPoints`
to `0` at signup (previously explicit); every reader already treats an
absent field as `0`, and the fields are simply absent until a real
Cloud Function first credits them. `updateTouchesNoProtectedFields()`
only flags fields whose *value* actually changes (via
`diff().affectedKeys()`, the same technique `isSelfLinkingAsParent()`
already used) — an unrelated update (changing avatar, say) that happens
to echo back an unchanged protected field's current value is not a
violation.

Also deleted the now-fully-superseded `WeeklyChallengeService.trackAchievementUnlock`
client-side increment of `achievementsUnlockedThisWeek` (that field is
now incremented atomically inside `unlockAchievement`'s own transaction);
`AchievementService._unlockAchievement` calls
`refreshCurrentChallengeProgress` directly instead, to pick up that
server-written counter immediately rather than waiting for the next
periodic refresh.

### Verification

- `functions/lib/__tests__/emulator/points_engine.test.js` (new, 18
  cases): every award function's idempotency, ownership checks, and
  server-side re-verification against fabricated/insufficient claims,
  run against a real Firestore emulator (a hand-rolled fake can't
  faithfully reproduce real transactions/queries).
- Cloud Functions: `npm run lint` clean; unit tests 43/43; emulator
  tests 47/47 (up from 29).
- `firestore-tests`: 10 new rule tests (a user can't set
  `totalAchievementPoints` or any of the other 9 protected fields
  directly, can't smuggle one in at account creation, an unrelated
  update with an unchanged protected field still succeeds, an admin can
  still correct a value directly) — 36/36 passing (up from 26).
- Flutter: every affected Dart test updated to inject a fake
  `PointsEngineClient` mirroring the server's behavior against the same
  fake Firestore, rather than re-deriving the server's logic a second
  time — the actual reward/idempotency/verification logic is the Cloud
  Functions emulator suite's job, not these tests'.
  `flutter analyze` clean; full suite 400/400 (the count moved down
  slightly from 402 despite new coverage: `daily_quest_service_test.dart`'s
  old tests re-verified quest-completion business logic that now lives
  entirely server-side, so they were replaced with fewer, more targeted
  delegation tests instead of duplicating the emulator suite's coverage).

## Point-award follow-up: reading-streak verification, and a real day-boundary bug (2026-09-13)

User pushed back on leaving `reading_streak` achievements trusting the
client after the migration above ("why not do this as well?"). Went back
and closed it — and found a genuine correctness bug already shipped in
the migration while doing so.

**Reading-streak achievements now verified server-side.**
`calculateReadingStreak` in `points_engine.js` ports
`FirestoreHelpers.calculateReadingStreak`'s consecutive-day algorithm
faithfully: same 4 parallel queries (`reading_progress` by `lastReadAt`,
`reading_sessions` by `createdAt`/`createdAtClient`/`startTime`,
deduped by doc ID), same `progressIndicatesReading`/
`extractSessionTimeForBucketing` pure helpers ported from
`reading_metrics.dart`, same streak-counting logic (a run ending today,
or ending yesterday if today hasn't been read yet). `unlockAchievement`
now verifies **every** achievement category against real records —
`readingStreak` is no longer accepted as a parameter from the client at
all (removed from `PointsEngineClient.unlockAchievement` and
`AchievementService._unlockAchievement`'s call to it), closing the one
gap this migration initially shipped with. This was a bounded extension
of the exact same pattern already used for `books_read`/`reading_time`/
`reading_sessions` — not a new category of work.

**Real bug found in the process: server-side "today" used the Cloud
Function's clock (effectively UTC), not the child's local day.**
`claimDailyQuestRewards` (shipped in the previous entry) computed
`minutesReadToday`/day-boundaries from `new Date()` on the server. For
any user not close to UTC, there's an hours-wide window around their own
local midnight where the server's calendar day and the child's actual
calendar day disagree by a full day — a legitimate reading session late
at night could get bucketed into the wrong day, silently breaking a
same-day quest or streak from the child's point of view. This wasn't
theoretical: it would have affected a meaningful fraction of daily-quest
claims for any user outside a UTC-adjacent timezone, not a rare edge
case.

Fixed with `resolveEffectiveNow(clientDateKey)`: `PointsEngineClient`
now sends the device's own local calendar day
(`AppDateUtils.formatDateKey(DateTime.now())`, "YYYY-MM-DD") alongside
every `claimDailyQuestRewards`/`unlockAchievement` call, and the server
uses it for day-bucketing **if and only if** it's within 1 day of the
server's own date — sanity-clamped, not blindly trusted, so a client
claiming to be on some arbitrary other day to game a day-boundary can't
get further than a real timezone's worst case (~26 hours worldwide).
This only affects which calendar day activity is bucketed under, not any
point amount or idempotency check, which remain fully server-computed
and re-verified exactly as before — a wrong day bucket is a minor UX
correctness issue, not a reopened security hole.

**Still not doing, and said so directly rather than quietly expanding
scope:** making the underlying `reading_progress`/`reading_sessions`/
`quiz_attempts` records themselves unforgeable. That's a different kind
of project — proving a reading session actually happened (e.g.
authenticated heartbeats while a book is open, with the server, not the
client, accumulating minutes) touches `ReadingSessionService`,
`book_provider.dart`'s progress tracking, and the app's offline-reading
story. Raised with the user as a separate, larger scope decision rather
than started here.

Verification: `functions/lib/__tests__/emulator/points_engine.test.js`
extended with `calculateReadingStreak` (6 cases: no activity, a clean
run, a gap breaking it, "today not read yet" still counting through
yesterday, `reading_progress` activity counting, a no-real-progress
`reading_progress` doc NOT counting), `resolveEffectiveNow` (4 cases:
server fallback, a plausible client date honored, an implausible one
rejected, a malformed one rejected), and the two `reading_streak`
`unlockAchievement` cases rewritten to assert against real seeded
activity instead of a trusted parameter — 59/59 emulator tests passing
(up from 47). `npm run lint` clean; unit tests 43/43 unchanged;
`flutter analyze` clean; full Flutter suite 400/400 unchanged (no Dart
test needed new coverage — the seams already in place only gained an
extra field in the request payload).

## Reading-session integrity — scoped out as its own project (2026-09-13)

The one remaining gap from the point-award migration above (`reading_progress`/
`reading_sessions`/`quiz_attempts` records themselves are still
self-reported, with nothing server-side proving the underlying reading
actually happened) is a redesign of `ReadingSessionService` and how
`book_provider.dart` tracks progress, not an extension of the migration
already shipped — it changes reading UX (latency, offline behavior), so
it's deliberately not folded in quietly. User agreed: scope it out
separately rather than start it or leave it as a one-line limitation.

Full design writeup, with three concrete options (server-timestamped
session start/end being the recommended first step, ahead of full
heartbeat-based live verification), the offline-support tradeoffs each
one carries (the app's offline reading today is entirely free, implicit
Firestore-client-SDK behavior — easy to break without noticing), and the
open product questions that need answers before any of it is built:
**`docs/reading-session-integrity-design.md`**. Not started.

## Reading-session integrity, Option B implemented: server-timestamped session start/end (2026-09-13)

User asked to go ahead with the design doc's recommended first step.
Implemented exactly what that doc scoped — not heartbeats (Option A),
not left as a limitation (the do-nothing option) — the middle ground:
the server now stamps both ends of a reading session and computes
duration itself, closing the single most blatant version of the gap
(fabricating an entire session, start and end timestamps included, with
no reading having happened) without touching the offline story or
requiring a heartbeat-cadence design.

**New `functions/lib/reading_sessions.js`**: `startReadingSession` writes
the `reading_sessions` doc with the server's own clock for every
timestamp field the rest of the app already reads (both the
"analytics-friendly" and "legacy/alternate" schema — no downstream
reader needed to change), plus `startedViaCloudFunction: true`.
`endReadingSession` re-reads that same server-set start time and
computes `duration = now - startTime` **entirely from its own clock** —
never from a client-supplied number — applying the same 6-hour clamp the
original client-side `endSession` always had for stuck/forgotten-open
sessions. Idempotent: ending an already-ended session returns its
already-computed duration instead of erroring, so a retried call after a
flaky response doesn't look like a failure. Both exposed as authenticated
`onCall` functions in `index.js`, matching the point-award functions'
conventions (never a client-supplied uid, typed errors mapped to
specific `HttpsError` codes).

**What this still doesn't close, deliberately** (same honesty standard
as the rest of this migration): a client can still choose *when* to call
`endReadingSession` — leaving a book open for hours without actually
reading still counts as a long "session," just one bracketed by real
server timestamps rather than fabricated ones. The design doc discusses
why this is a materially smaller gap than fabricating a session outright,
and why full heartbeat verification (Option A) wasn't pursued given no
evidence yet of actual abuse.

**Dart side, `ReadingSessionService.startSession`/`endSession` now try
the Cloud Function first and fall back to the original direct-Firestore-
write behavior on *any* failure** — no connectivity, cold start,
anything. This was the resolution to the design doc's open offline
question: rather than rebuilding an offline queue/replay system for
Cloud Function calls (which don't queue while offline the way Firestore
writes do), a session that can't reach the server just falls back to
being created/ended exactly like every session was before this change —
unverified, but reading is never interrupted. A session can even be
server-verified at the start and fall back at the end (or vice versa) if
connectivity drops mid-read; the fallback `endSession` still computes
duration from whatever start time is on the doc, so a server-set start
stays trustworthy even if the end has to fall back. New
`ReadingSessionEngineClient` (`lib/services/reading_session_engine_client.dart`)
mirrors `PointsEngineClient`'s `.withCaller()` test-injection shape but
is kept as its own class — starting/ending a session isn't a point
award, it's the evidence a later point award gets verified against.

No changes needed to `points_engine.js`'s verification logic (`getAllTimeReadingStatsInTx`,
`calculateReadingStreak`, `getTodayReadingMinutes`) — they already read
whatever's in `reading_sessions` regardless of which path wrote it.
Distinguishing verified-vs-fallback sessions when computing points
(e.g. weighting them differently) was deliberately not done here — no
data yet on what fraction of real sessions end up falling back, and
doing it speculatively risked penalizing legitimate offline readers for
no measured benefit; the `startedViaCloudFunction`/`endedViaCloudFunction`
flags are there for a future pass to use once that data exists.

**Cost note**, since it came up directly: this does add two Cloud
Functions invocations per reading session where there were previously
zero (session start/end were plain client Firestore writes). Rough
math: even 5 sessions/day/user is ~300 invocations/month/user against
Firebase's 2M/month free tier — several thousand daily active readers
before this specific change alone has any cost impact, on a project
already on the Blaze plan for its existing AI-tagging/quiz-generation
functions.

Verification: `functions/lib/__tests__/emulator/reading_sessions.test.js`
(new, 7 cases: server-stamped creation, duration computed from the
server's own clock not a client claim, the 6-hour clamp, rejecting
someone else's session, rejecting a made-up sessionId, idempotent
re-ending). `npm run lint` clean; emulator tests 66/66 (up from 59);
unit tests 43/43 unchanged. `reading_session_service_test.dart` extended
(3 new cases: Cloud-Function-success path for both start and end, and
explicit fallback-on-failure behavior) — `flutter analyze` clean; full
Flutter suite 403/403 (up from 400).

## Reading-session integrity, Option A implemented (scaled down): a 10-minute heartbeat bounds the walk-away gap (2026-09-13)

Follow-up to Option B above. That closed fabricating an entire session
out of thin air, but left one gap open by design: a client could still
start a session, background the app or walk away for hours, and call
`endReadingSession` on return — still credited as one long "session"
bracketed by real server timestamps, even though no real reading
happened for most of it.

Before building this, worked through the actual cost tradeoff rather
than defaulting to the design doc's strongest sketch (a 30-60s heartbeat
cadence): that cadence multiplies Cloud Functions invocations and
Firestore writes roughly 15-30x over Option B's flat two-calls-per-
session (a 20-minute session becomes ~40 heartbeat calls instead of 2).
A 10-minute cadence gets volume back down close to Option B's own range
while still bounding the walk-away gap to a small, fixed window instead
of an entire session — a deliberate middle ground, not the strongest
guarantee possible, chosen once it was clear the coarser cadence still
closes the gap that mattered.

**`functions/lib/reading_sessions.js`**: added `recordReadingHeartbeat(db,
userId, {sessionId})` — a transactional "still actively reading"
check-in. Each call (and the final segment computed inside
`endReadingSession`) credits only the time elapsed since the *previous*
check-in (`lastHeartbeatAt`, defaulting to the session's own start time),
capped at `HEARTBEAT_MAX_CREDIT_SECONDS` (12 minutes — the 10-minute
target cadence plus 2 minutes' grace for jitter/latency). A session that
stops checking in — backgrounded, killed, or genuinely abandoned — stops
accruing credit beyond that cap; `endReadingSession` no longer sums a
raw start-to-end diff, it sums accumulated capped segments
(`accountedSeconds`) plus one final capped segment. The 6-hour outer
clamp (`MAX_SESSION_SECONDS`) still applies regardless of how many
heartbeats land. A heartbeat on an already-ended session is a no-op
(returns `{ended: true}`), not an error, since a client can't always
know its previous `endReadingSession` call landed first.

**A deliberate consequence, not a bug**: a session with *zero*
heartbeats (a short session, or an older client build) still gets
credited up to the same 12-minute cap at `endReadingSession` —
`lastHeartbeatAt` starts equal to the session's start time — but nothing
beyond it. Reading for longer than that without a single check-in is
exactly the pattern being guarded against, so it isn't exempt just
because no heartbeat was ever sent. This changed two existing emulator
tests' premises (a session backdated 10 hours with no heartbeats used to
assert the 6-hour clamp; it now asserts the 12-minute heartbeat cap
instead) — both updated to verify the new intended behavior, plus a new
test confirming the 6-hour clamp still applies to a *genuinely* long
session built from real accumulated heartbeat credit.

**Dart side**: `ReadingSessionEngineClient.recordReadingHeartbeat` mirrors
the existing start/end calls. `ReadingSessionService.sendHeartbeat`
wraps it with no fallback and no rethrow — a failed heartbeat (offline,
cold start) is logged and dropped, exactly like a missed check-in;
reading is never interrupted by it. `PdfReadingScreenSyncfusion` now
mixes in `WidgetsBindingObserver`: a `Timer.periodic(10 minutes)` calls
`sendHeartbeat` while the session is active, started once the session
begins and paused the instant `didChangeAppLifecycleState` reports
anything other than `AppLifecycleState.resumed` (backgrounding stops
credit accruing immediately, not eventually) — and cancelled on session
end or screen dispose either way.

**What was deliberately not built**: no offline queueing/replay for
heartbeats, unlike Firestore's automatic write-queueing that
`startSession`/`endSession`'s fallback path already relies on. A
heartbeat call is fire-and-forget; a kid reading offline for more than
~12 minutes without a heartbeat successfully landing will have that
stretch undercounted once they reconnect and end the session. This is
an accepted, documented tradeoff (see the design doc's updated "What
actually shipped" section) rather than an oversight — building a bounded
replay-batch system was the same complexity the original Option A
sketch flagged as reopening a weaker version of the same trust problem,
and there's no evidence yet that offline reading sessions long enough to
matter here are common.

Verification: `functions/lib/__tests__/emulator/reading_sessions.test.js`
extended (9 new cases: heartbeat accumulates elapsed time, caps a large
gap since last check-in, accumulates correctly across repeated
heartbeats without double-crediting, a heartbeat on an already-ended
session no-ops, rejects a missing/someone-else's/made-up sessionId; a
session with no heartbeats caps at 12 minutes rather than the full
elapsed time at end; a genuinely long session built from real
accumulated heartbeat credit still reaches the 6-hour clamp) — emulator
tests 75/75 (up from 66); `npm run lint` clean.
`reading_session_service_test.dart` extended (2 new cases: `sendHeartbeat`
relays to the engine, and swallows a failure instead of throwing) —
`flutter analyze` clean; full Flutter suite 405/405 (up from 403).

## PdfReadingScreenSyncfusion: a corrupted local PDF cache was never re-validated, and failed permanently (2026-09-13)

Reported directly: a specific book ("Memory") that used to open fine
started showing "Failed to load PDF: There was an error opening this
document" — permanently, on that device, across app restarts — after
what was described as "some Firebase issue" months earlier. Nothing in
this session's Cloud Functions work touches PDF loading at all, so this
was a pre-existing bug, investigated on its own once the actual
screenshot (not just "books weren't loading") made the real symptom
clear.

**Root cause**: `_checkPdfCache()` trusted a cached file's mere
*existence* on disk — it never checked the file's contents were an
actual PDF. `_downloadAndCachePdf()` only checked the HTTP response was
a `200` — it never checked the downloaded bytes were an actual PDF
either. So the very first time anything went wrong mid-download (an
interrupted connection, the app getting killed mid-write, a transient
Storage error, low disk space) — a plausible one-time "Firebase
issue" — whatever partial or wrong bytes had landed got written to the
local cache file and were trusted forever after. No code path ever
re-validated an existing cache entry or retried a failed one; every
future attempt to open that specific book on that specific device kept
loading the same broken file and failing the same way, indefinitely,
long after whatever originally caused it was gone. This is a strictly
local, per-device, per-book problem — it explains why it was permanent
for this one book on this one phone rather than a wider outage.

**Fix, in `pdf_reading_screen_syncfusion.dart`**:
- New `lib/utils/pdf_validation.dart` — `looksLikePdf(bytes)`, checking
  for the real PDF file signature (`%PDF-`). Pulled out as a standalone
  pure function specifically so it has real unit test coverage — this
  screen itself has never been widget-tested (Syncfusion's native PDF
  viewer isn't mockable in the Flutter test harness, per the earlier
  "assessed, not widget-tested" entry), so logic worth testing has to
  live outside it.
- `_checkPdfCache()` now validates an existing cached file's contents
  before trusting it; an invalid one is deleted and a fresh download is
  attempted, instead of being reused forever.
- `_downloadAndCachePdf()` now validates the downloaded bytes before
  writing them to the cache at all, so a bad download can never poison
  the cache in the first place going forward.
- `_onPdfLoadFailed()` (the Syncfusion viewer's own "couldn't parse
  this" callback) now self-heals once per screen visit: if a cached
  file was in use, it's discarded and a fresh download is attempted
  automatically before giving up and showing the permanent error
  banner. This is the part that actually fixes *already-poisoned*
  caches on real devices right now — the validation above only prevents
  *new* ones, it can't retroactively un-poison a cache entry a device
  already has sitting on disk from before this fix shipped.

Verification: new `test/utils/pdf_validation_test.dart` (5 cases: real
PDF signature accepted; an HTML/XML error-page body — the actual shape
a failed Storage response can take — rejected; empty bytes rejected; a
truncated/interrupted download shorter than the signature rejected;
plain garbage rejected). `flutter analyze` clean; full Flutter suite
410/410 (up from 405).

## Leaderboard tab: no bottom nav, and its back arrow "signed you out" (2026-09-13)

Reported directly, from the built release APK: the Leaderboard tab showed
no bottom navigation bar at all, and tapping the AppBar's back arrow
landed on the sign-in screen — indistinguishable from being logged out.

Root cause: `AppBottomNav`'s four tabs (Home/Library/Ranks/Settings) are
wired entirely with `Navigator.pushReplacement` — switching tabs replaces
the current route rather than pushing on top of it, so there is never a
meaningful "previous screen" to go back to between tabs. Home, Library,
and Settings all already knew this and don't use a Scaffold `AppBar` at
all (no back button possible). `LeaderboardScreen` was the one exception:
it used a plain `AppBar(title: ...)`, so Flutter's default
`automaticallyImplyLeading` auto-showed a back arrow whenever `canPop()`
was true — which happens whenever a user reached Leaderboard by a route
that still has something real underneath it (e.g. having drilled into a
book before switching tabs). Popping there doesn't go "back a tab" (tabs
aren't stacked) — it pops to whatever unrelated route is genuinely
underneath, which for many real navigation paths is the pre-login screen.

Fixed in `leaderboard_screen_impl.dart`: `automaticallyImplyLeading: false`
on the AppBar (matching the other three tabs' no-back-button behavior)
and added `bottomNavigationBar: const AppBottomNav(currentTab:
NavTab.leaderboard)` (matching their persistent nav bar). Leaderboard now
behaves as a peer tab like the other three, not a screen drilled into.

Verification: `test/screens/leaderboard_screen_test.dart` extended (1 new
case: bottom nav present with Ranks active, no `BackButton`/"Back" tooltip
present). `flutter analyze` clean; full suite passing.

## Books and covers failing to load: two separate, non-code root causes found (2026-09-13)

Reported directly (with a screenshot): "Failed to load PDF: There was an
error opening this document" on every book, plus covers not rendering.
Neither turned out to be a bug in this app's code at all.

**Root cause 1 — every book PDF/cover pointed at a bucket, in a Firebase
project, that isn't the one this app runs in.** `firebase.json`/
`.firebaserc`/`google-services.json`/`firebase_options.dart` all
configure this app for project `readmev2`, storage bucket
`readmev2.firebasestorage.app`. But `readmev2`'s own `books` Firestore
collection had `pdfUrl`/`coverImageUrl` fields — for every single one of
its 57 books — still pointing at a *different*, older project's bucket:
`readme-40267.firebasestorage.app` (94 fields as raw GCS V2 signed URLs,
16 as Firebase Storage download-URLs, both still naming the old bucket).
This is the classic signature of a Firestore data migration between
Firebase projects that copied documents but never touched the file
references inside them, or moved the underlying Storage objects.

**Root cause 2 — the old project's Google Cloud billing account was
closed**, which makes Cloud Storage refuse to serve *any* object out of
its buckets — confirmed by fetching the actual signed URLs directly and
reading the response body:
`<Error><Code>UserProjectAccountProblem</Code><Message>The project to be
billed is associated with a closed billing account.</Message></Error>`.
Verified this blocks even fully-authenticated, project-owner-level Admin
SDK access (not just the public signed URLs) — `bucket.exists()`/
`getFiles()` (metadata/"control plane" calls) still worked, but
`file.download()` (actual data egress) failed with the identical billing
error regardless of credentials. This is a hard, whole-project block, not
a rules or expiry problem — the signed URLs' own `Expires` timestamps
were still valid decades out; billing was the only blocker.

**Fix — migrated the files to the project actually being paid for and
built against**, rather than depending on the old project's billing
staying open indefinitely: after billing was briefly reactivated on
`readme-40267` (required — there's no way to read a billing-suspended
project's Storage objects with any credential, so a copy operation is
the only way this is fixable without indefinitely keeping two paid
projects alive), ran a one-time migration script (`tools/`-adjacent, not
committed — used the existing `tools/serviceAccountKey.json` /
`serviceAccountKey_1.json` pair, the same credentials `tools/
set_admin.js` already documents and gitignores) that, for each of the 57
books: downloaded the PDF/cover bytes from the old bucket, re-uploaded
them to `readmev2`'s own bucket at the same relative path with a fresh
Firebase Storage download token, and updated the book's Firestore
`pdfUrl`/`coverImageUrl` to the new download URL. 110 fields migrated, 3
were already correctly pointing at `readmev2` (newer uploads via
`book_upload_form.dart` already do this right), 1 cover was legitimately
empty (untouched), zero errors. A local backup of every {bookId, field,
oldUrl, newUrl} mapping was written before any Firestore write, in case
of rollback. A quick follow-up pass corrected the migrated files'
content-type metadata (faithfully copied from the old files, which had
generic `application/octet-stream` instead of `application/pdf`/
`image/png` etc.) to the correct MIME type per file extension.

Verified after migration: all 113 non-empty URLs return HTTP 200 with
correct content-type and real byte counts, independent of the old
project's billing state (confirmed by testing again after billing was
closed a second time — the new URLs, served entirely from `readmev2`'s
own bucket, were unaffected).

**Why this matters beyond just this app**: this fully explains the
earlier "Memory" book's permanently-broken PDF cache from this session's
prior fix too — the corrupted cache wasn't a fluke, it was **every**
download failing with a 403/XML body from the very start, and the old
cache-trusting code just silently poisoned itself on the first attempt
and never recovered. That fix (validate cache contents, self-heal on
`onDocumentLoadFailed`) remains correct and necessary on its own merits
even now that the underlying data is fixed — it's exactly the kind of
defense that should have prevented this class of failure from being
silently permanent in the first place, regardless of what causes a given
download to fail in the future.

**Still open**: `readme-40267`'s billing account is presumably fine to
close again now that nothing depends on it, but that's a call for
whoever owns that Google Cloud billing account, not something to do from
here silently.

## PdfReadingScreenSyncfusion, take four: a book could complete itself the instant it was opened (2026-09-14)

Reported directly: opening a book ("barely completed it") immediately
triggered an achievement AND a weekly-challenge celebration — no real
reading involved. Traced to a second, independent completion path this
screen has always had, alongside the dwell-timer one already hardened
in the two previous entries above.

**Root cause**: `_updateReadingProgress()` has always carried its own
"failsafe" completion check — `progressPercentage >= 0.98` — for mobile
PDF viewers that don't always reliably report landing on the true last
page. Unlike the dwell-timer path in `_commitPageChange` (which
correctly requires 300-600ms of real presence before counting a page as
read), this failsafe was never gated by `_isInitialJump`, the flag that
exists specifically to suppress completion detection during the first
1.5 seconds after a book opens or resumes. For a one-page book,
`currentPage / totalPages` is `1.0` from the moment the book loads —
satisfying the failsafe instantly, with zero dwell time enforced at
all. The same applies to resuming any book already within ~2% of its
end. `_markBookAsCompleted()` then runs immediately, which (via this
session's earlier point-award migration) genuinely, correctly awards
points and unlocks achievements/weekly-challenge progress server-side
for what the server has no way to know was a false completion signal —
the server verifies the *record* is real, not that the record was
honestly earned by the client that wrote it.

**Fix**: gated the failsafe with `!_isInitialJump`, same as the
dwell-timer path already was. But `_isInitialJump` merely expiring
after its 1.5s delay used to just silently clear the flag — for a
one-page book (or a book resumed already on its last page), no further
`onPageChanged` event will ever fire afterward to trigger the normal
completion check, since there's nowhere left to navigate to. Simply
gating the failsafe without also fixing this would have made such books
never auto-complete at all. So the delayed callback now also runs one
real completion check (`_commitPageChange(_currentPage)`) once the flag
clears — completion still happens for a genuinely-read short book, just
only after 1.5 real seconds have passed (longer than the near-end
dwell-timer's own 600ms threshold), not from the instant of opening it.

Verification: `flutter analyze` clean; full suite passing (regression
check only — same caveat as the two entries above, no dedicated test
file for this screen; Syncfusion's native PDF viewer isn't mockable in
the Flutter test harness).

## AchievementListener: a celebration could pop over the splash screen (2026-09-14)

Reported directly, alongside the above: closing and reopening the app
showed an achievement celebration while the splash screen was still
on screen — before the user had reached any real screen, or even had
the app decide which account/screen to show.

**Root cause**: `AchievementListener` wraps the entire `MaterialApp` via
`main.dart`'s `builder`, so it's live from the very first frame —
including while `SplashScreen` (a fixed ~3-second delay plus async
book/user-data loading) is the active route. It already had one
"defer until it's safe" gate (`ReadingScreenTracker.isReadingActive`,
for not interrupting an open book), but nothing equivalent for splash.
Its Firestore stream (`user_achievements` where `popupShown == false`)
can resolve well within that 3-second window — trivially so for an
achievement left over from closing the app right after earning one, or
from the premature-completion bug above — and it pushes the celebration
via the app's *global* navigator key regardless of what's currently
showing, landing directly on top of the splash screen.

**Fix**: new `lib/services/app_readiness_tracker.dart` — a
`ValueNotifier<bool>` defaulting to "splash active", flipped once via
`SplashScreen`'s new `dispose()` override (the one choke point every
exit branch reaches, since they're all `pushReplacement` calls that
dispose the widget regardless of which branch ran). `AchievementListener`
now defers on this the same way it already deferred on
`ReadingScreenTracker`, and retries the moment splash hands off.

Verification: new `test/services/app_readiness_tracker_test.dart` isn't
needed — this trivial pure state holder is exercised directly by
`splash_screen_test.dart`'s extended coverage instead (2 new cases:
stays "active" while splash is genuinely showing; flips to "inactive"
once splash hands off to a real screen — the transition
`AchievementListener` depends on). `AchievementListener` itself remains
untested (it hardcodes `FirebaseAuth.instance`/`FirebaseFirestore.instance`
rather than accepting injected instances like every other service in
this codebase — a larger DI refactor, out of scope for this fix).
`flutter analyze` clean; full suite 412/412 (up from 410).

## PdfReadingScreenSyncfusion: three safe cleanups from the audit (2026-09-14)

Follow-up to `docs/pdf-reading-audit.md`. These three don't require the
product decision the audit flags for the page-layout-mode question
(`PdfPageLayoutMode.single` vs. `.continuous`, or an explicit "Finish
this book" action) — they carry no user-visible behavior change, so
they're done now rather than left blocked on that decision:

- **Deleted `_showQuizDialog`** (~90 lines) — dead code, already
  explicitly superseded per its own neighboring comments ("Achievement
  popups are now handled by global AchievementListener," "Quiz popup
  removed"), kept alive only by an `// ignore: unused_element`
  suppressing the analyzer's own warning that nothing called it.
  Removed the now-unused `book_quiz_screen.dart`/`app_button.dart`/
  `page_transitions.dart` imports along with it.
- **Text-to-speech no longer re-parses the whole PDF on every page
  turn.** `_extractTextFromCurrentPage` used to dispose and reconstruct
  a fresh `PdfDocument` from the cached/downloaded bytes on every single
  TTS-triggered page change — real, avoidable latency and battery cost
  for longer books being read aloud. New `_ensurePdfDocumentForTts()`
  parses once and reuses the result for the rest of the screen's life;
  safe because the underlying bytes don't change once read-aloud has
  actually started (by then the initial load has already succeeded, and
  any cache-recovery retry is long done). Still disposed in `dispose()`
  as before.
- **Factored the duplicated `SfPdfViewer.file`/`.network` widget trees**
  (near-identical ~25-line blocks) into one `_buildPdfViewer()` plus
  shared `_onPdfDocumentLoaded`/`_onPdfTextSelectionChanged` callbacks —
  removes the risk of the two variants silently drifting apart the next
  time one of them needs a change.

Verification: `flutter analyze` clean; full suite 412/412 unchanged
(regression check only — same caveat as every other entry for this
file, no dedicated test file; see the audit doc for why).

## PdfReadingScreenSyncfusion: switched to page-by-page mode, with a progress bar (2026-09-14)

The product decision `docs/pdf-reading-audit.md` flagged as needing an
explicit yes: made. Requested directly, with one condition attached —
a visual progress indicator, since page-by-page reading loses the free
"how much is left" sense continuous scrolling gives via a scrollbar.

**`_buildPdfViewer()`** now sets `pageLayoutMode: PdfPageLayoutMode.single`
on both the file and network `SfPdfViewer` variants. This is the fix
the whole audit was building toward: in single mode, page changes are
discrete navigation events, not scroll-position inference, so
`currentPage == totalPages` is now an *exact* check — no more fuzziness
to route around. The second-to-last-page workaround (`_commitPageChange`,
`_dwellThresholdForPage`) is deleted outright, not kept as
defense-in-depth — there's nothing left for it to defend against.

**Progress bar**: a thin `LinearProgressIndicator` docked to the
`AppBar`'s `bottom`, tracking `currentPage / totalPages` live, alongside
the existing "Page X of Y" text. Exact for the same reason completion
detection now is — no rounding or estimation involved.

**Not built**: the audit's Option 2 (an explicit "Finish this book"
action) — it was offered as worth layering on independently, but this
pass was specifically about the layout-mode decision plus its attached
condition, not a request for both options.

Verification: `flutter analyze` clean; full suite 412/412 unchanged
(regression check only — same caveat as every other entry for this
file, no dedicated test file exists; see the audit doc for why).
