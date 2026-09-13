# Reading-session integrity — scoping doc

Status: **Option B and a lightweight variant of Option A are both
implemented** (see "What actually shipped" below); Option C remains
unimplemented. This was the one gap the point-award security migration
(see `SECURITY.md`) deliberately left open: `reading_progress`,
`reading_sessions`, and `quiz_attempts` were still written directly by
the client, and nothing server-side proved the reading/quiz-taking
activity they described actually happened. Every point/achievement
calculation built (`functions/lib/points_engine.js`) faithfully computes
from these records — but "faithfully computes from" isn't the same as
"the records are true."

This doc originally laid out what closing that gap for real would take,
so it could be a deliberate decision rather than something quietly
folded into a future change — that decision has now been made for B and
a scaled-down A; see below for what was actually built and why it
differs from the original Option A sketch.

## The gap, concretely

- `ReadingSessionService.startSession()` writes a `reading_sessions` doc
  when a book opens; `endSession()` computes `duration = now - startTime`
  **on the client** and writes it when the book closes. A modified
  client (or a hand-written Firestore write, same as the points exploit)
  can create a doc claiming any duration at all, with no session ever
  having happened.
- `BookProvider.updateReadingProgress()` posts `currentPage`/`totalPages`
  /`additionalReadingTime` periodically, throttled client-side only.
- `QuizGeneratorService.saveQuizAttempt()` submits a score/percentage the
  client itself computed from the user's answers — the server never sees
  the actual answer-by-answer process, only the claimed result.
- No server ever observes reading "as it happens." Everything arrives as
  an already-finished summary, after the fact, from the same account
  that benefits from inflating it.

## Load-bearing facts about the current app that any redesign must respect

- **Offline reading already works today, for free, and kids plausibly
  use it.** `pdf_reading_screen_syncfusion.dart` caches PDFs locally
  (from this engagement's earlier PDF audit), so a book can be opened
  and read with no connectivity. The app has no custom sync/queue system
  for this — it's simply relying on the Cloud Firestore **client SDK's**
  built-in offline persistence (queues writes locally, replays them on
  reconnect; serves cached reads). `OfflineService`
  (`lib/services/offline_service.dart`) only *detects* connectivity to
  show a banner — it does not implement queueing itself; the queueing is
  invisible platform behavior the app has never had to think about.
- **That free behavior is specific to plain Firestore writes.** A Cloud
  Function called via `httpsCallable()` does **not** queue itself while
  offline the way a Firestore write does — the call simply fails (or
  hangs, depending on platform/plugin behavior) with no connectivity.
  Any design that moves reading-session truth from "a Firestore doc the
  client writes" to "a Cloud Function the client calls" loses this
  automatic offline behavior and must reimplement the equivalent
  (buffer locally, retry on reconnect) by hand — exactly the kind of
  invisible regression that's easy to ship without noticing until a
  parent reports "my kid's reading time didn't count on the flight."
- **Firestore persistence defaults differ by platform.** It's on by
  default on iOS/Android, off by default on web unless explicitly
  enabled (this app doesn't call `Settings(persistenceEnabled: ...)`
  anywhere, so it's running on whatever each platform's default is) —
  worth confirming which platforms this app actually ships to before
  assuming today's offline behavior is uniform across all of them.
- **A cruder anti-cheat guard already exists client-side.** The PDF
  screen's dwell-timer logic (audited and fixed earlier this session —
  see `SECURITY.md`'s "PdfReadingScreenSyncfusion" entries) already
  makes some effort to gate page-turns by realistic read time. Any
  server-side redesign should fold that intent in rather than duplicate
  it as a second, possibly-inconsistent guard.

## Three options, from strongest guarantee to cheapest

### Option A — periodic authenticated heartbeats (strongest, most invasive)

**Implemented — as a deliberately lighter-weight variant of this
original sketch. See "What actually shipped" below for the real design;
this section is kept as the original strongest-guarantee sketch for
context on what was traded away and why.**

While a book is open and the app is foregrounded, the client calls a
lightweight `heartbeat` Cloud Function every N seconds (e.g. 30–60s)
identifying the open session. The **server** accumulates minutes into
the session doc (Admin SDK write); the client's own locally-computed
duration becomes purely cosmetic display, never the credited source of
truth.

- **Closes:** the core gap — genuinely proves the app was open and
  pinging for that duration, not just that a doc says so.
- **Costs:**
  - Offline queueing has to be rebuilt from scratch (see above). Once
    rebuilt, a *replayed batch* of heartbeats sent after reconnecting is
    still fundamentally a client-reported claim about the past — a
    weaker guarantee than a live heartbeat, and arguably reopens a
    version of the same gap unless replay batches are bounded and
    sanity-checked (e.g. capped total minutes per batch, rejected if
    wildly inconsistent with elapsed wall-clock time since last contact).
  - Foreground/backgrounding semantics need a real answer (does
    switching apps pause the session? how strict?), with real
    platform quirks (iOS background execution limits, Android Doze).
  - N× more Cloud Functions invocations per session than today's two
    (start + end) — real cost and rate-limit surface at scale.
  - A live-feeling progress/streak UI now has to reconcile optimistic
    local state against confirmed server state, reintroducing some of
    the eventual-consistency complexity Firestore's offline queue
    already hides today.

### Option B — server-timestamped start/end, no heartbeats (middle ground)

**Implemented** (`functions/lib/reading_sessions.js`,
`lib/services/reading_session_engine_client.dart`/`reading_session_service.dart`).

Client calls a `startReadingSession` Cloud Function (server timestamps
the start, hands back a session token) and an `endReadingSession`
function when done (server timestamps the end, computes the duration
itself from its own two timestamps — never from anything the client
reports).

- **Closes:** fabricating an entire session out of thin air (the most
  blatant version of this exploit — claiming hours of reading with zero
  app interaction). The elapsed wall-clock time between the two calls is
  bracketed by the server's own clock, not the client's.
- **Doesn't close:** opening a book, backgrounding the app for hours,
  and calling `endSession` on return — still counts as a long "session"
  even though no real reading happened in between. A materially smaller
  problem than fabricating a session outright, and one `endSession`'s
  existing max-duration clamp (6 hours) already partially blunts.
- **Costs:** much lower than Option A — still just two calls per
  session (same shape as today), no heartbeat cadence to design, no new
  offline-queueing system needed if the two calls are allowed to queue
  and replay the same way Firestore writes do today (a `startSession`/
  `endSession` pair replayed together after reconnect, both timestamped
  by the server at call time, is a reasonable, bounded thing to accept).

### Option C — keep today's model, add anomaly detection (cheapest, weakest)

Don't change the write path. Add a scheduled Cloud Function (daily,
alongside the existing `resetWeeklyLeaderboard`-style scheduled jobs)
that flags statistically implausible patterns — impossible daily
minutes, session counts with no plausible page-turn cadence, etc. — for
human review, following the same `needsReview`-on-`AdminDashboard`
pattern already built for flagged book content.

- **Closes:** nothing at write time. Surfaces likely abuse after the
  fact for a parent/admin to act on.
- **Costs:** the least by far — no client changes, no offline-story
  changes, just a new scheduled job and a dashboard surface.

## What actually shipped (Option A, scaled down from the original sketch)

The cost/precision tradeoff was worked through explicitly rather than
building the strongest version by default: the original sketch's 30–60s
cadence multiplies invocation and Firestore-write volume roughly
15-30x over Option B's flat two-calls-per-session (a 20-minute session
becomes ~40 heartbeat calls instead of 2). A 10-minute cadence gets
volume back down close to Option B's own range while still bounding the
walk-away gap to a small, fixed window instead of an entire session —
a reasonable middle ground, not the strongest guarantee possible.

What's actually built, in `functions/lib/reading_sessions.js`:

- The client (`pdf_reading_screen_syncfusion.dart`) calls a new
  `recordReadingHeartbeat` Cloud Function roughly every 10 minutes while
  a book is open **and the app is in the foreground** — a
  `WidgetsBindingObserver` pauses the timer on anything other than
  `AppLifecycleState.resumed`, so backgrounding stops credit from
  accruing immediately, not just eventually.
- Each heartbeat (and the final segment at `endReadingSession`) only
  credits the time elapsed since the *previous* check-in, capped at 12
  minutes (10-minute cadence + 2 minutes' grace for jitter/latency). A
  session that stops checking in — backgrounded, killed, or genuinely
  abandoned — stops accruing credit beyond that cap, rather than the
  full gap being paid out when `endReadingSession` eventually runs.
- A session with **zero** heartbeats (a short session, or an older
  client version) still gets credited up to that same 12-minute cap at
  `endReadingSession` — `lastHeartbeatAt` defaults to the session's own
  start time — but nothing beyond it. This is intentional, not a bug: a
  long session with no check-ins at all is exactly the pattern being
  guarded against, so it can't be exempted from the cap just by never
  calling heartbeat.
- The 6-hour outer clamp (`MAX_SESSION_SECONDS`) still applies
  regardless of how many heartbeats arrive.

What was deliberately **not** rebuilt from the original Option A
sketch: there is no offline queueing or replay for heartbeats. A
heartbeat call is fire-and-forget from `ReadingSessionService
.sendHeartbeat` — on any failure (no connectivity, cold start) it's
logged and dropped, exactly like a missed check-in. This means a kid
reading offline for more than ~12 minutes without a successful heartbeat
landing will have that time undercounted once they reconnect and end
the session — a real, accepted tradeoff (worse UX for genuine offline
readers, in exchange for not having to design and build a bounded
replay-batch system, which the original sketch flagged as reopening a
weaker version of the same trust problem anyway). If offline reading
turns out to be common enough that this undercounting becomes a real
complaint, that replay-batch design is the next thing to revisit — not
something to bolt on quietly.

## Recommendation

Shipped: Option B, then this scaled-down Option A. Together they close
fabricating a whole session and bound (rather than fully close) leaving
one open and walking away. Option C is still worth adding on top of
both, since it catches the "technically real, implausibly exaggerated"
case neither A nor B fully addresses (e.g. many short bursts of exactly
12-minutes-of-credit heartbeats back to back) — nothing here polices
that pattern at write time, only after the fact via a review queue.

## Open questions

1. ~~**Offline reading** — is it acceptable for the point-bearing "this
   session counted" signal to require connectivity?~~ Answered by what
   shipped: session start/end require connectivity (with a same-as-before
   unverified fallback when offline), and heartbeat credit is lost, not
   queued, when offline for more than ~12 minutes at a stretch. Revisit
   if this proves to be a real complaint.
2. ~~**Backgrounding** — should switching away from the app pause a
   session?~~ Answered: yes, immediately — no grace period. A kid who
   steps away for a phone call mid-chapter simply stops accruing credit
   for that gap, which is the intended behavior, not a UX bug to soften.
3. **Which platforms** does this app actually ship to, and does each
   one's Firestore persistence default match what today's UX quietly
   assumes? Still open — unaffected by A/B shipping.
4. **Is Option C worth doing yet**, relative to other product
   priorities, given there's still no evidence of actual abuse in the
   wild beyond the theoretical hole? Still open.
