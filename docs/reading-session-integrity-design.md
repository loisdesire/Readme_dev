# Reading-session integrity — scoping doc (not started)

Status: **scoped out, not implemented.** This is the one gap the
point-award security migration (see `SECURITY.md`) deliberately left
open: `reading_progress`, `reading_sessions`, and `quiz_attempts` are
still written directly by the client, and nothing server-side proves the
reading/quiz-taking activity they describe actually happened. Every
point/achievement calculation now built (`functions/lib/points_engine.js`)
faithfully computes from these records — but "faithfully computes from"
isn't the same as "the records are true."

This doc lays out what closing that gap for real would actually take,
so it can be a deliberate decision rather than something quietly folded
into a future change. Nothing here has been built.

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

## Recommendation

Option B first. It removes the single most blatant exploit (inventing a
whole session from nothing) without touching the offline story or
committing to a heartbeat-cadence design, and it's a bounded, low-risk
change shaped like the point-award migration already shipped. Option C
is worth adding regardless of A/B, since it's cheap and catches the
"technically real session, implausibly exaggerated" case neither A nor B
fully addresses on its own. Option A is real but should wait for
evidence this is actually being exploited in practice — there's no
usage telemetry yet to know that (the same caveat already on record for
the league-threshold tuning earlier in this engagement).

## Open questions before any of this is built

1. **Offline reading** — is it acceptable for the point-bearing "this
   session counted" signal to require connectivity (Option B), even
   though page-position/progress could still sync later via today's
   existing Firestore writes? Or must reading-while-offline keep earning
   points/streak credit exactly as it invisibly does today?
2. **Backgrounding** — should switching away from the app pause a
   session? Immediately, or with a grace period (e.g. a phone call)?
3. **Which platforms** does this app actually ship to, and does each
   one's Firestore persistence default match what today's UX quietly
   assumes?
4. **Is this worth doing yet at all**, relative to other product
   priorities, given there's no evidence of actual abuse in the wild —
   only that the theoretical hole exists?

No timeline is estimated here on purpose: sizing this properly depends
on the answers above, particularly #1.
