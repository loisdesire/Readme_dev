# PdfReadingScreenSyncfusion — full audit

Status: **audit only, nothing implemented.** Requested directly after
the fourth bug fix to this screen this session, with the fair
observation that this file has been a recurring source of "drama" —
inaccurate page counting, completion that never triggered on the true
last page (worked around by completing on the *second*-to-last page
instead), and now a completion path that could fire *instantly*. This
doc catalogs what's actually wrong, explains the root cause of the
page-counting complaint specifically, and lays out real alternatives —
so the next decision here is deliberate, not another patch on a patch.

File: `lib/screens/book/pdf_reading_screen_syncfusion.dart`, ~1550
lines. Library: `syncfusion_flutter_pdfviewer` 31.1.23.

## The page-counting complaint, root-caused

**What you remember is real and is still exactly how the code works
today**: `_commitPageChange` (line ~632) treats *either* the true last
page *or* the second-to-last page as "the end," because — per the
comment already in the code — "On mobile, PDF viewer doesn't always
report the absolute last page reliably."

**Why**: this screen uses Syncfusion's default page layout,
`PdfPageLayoutMode.continuous` — the whole document renders as one tall
scrollable strip, and "current page" is inferred from *scroll
position* (whichever page is topmost/most-visible in the viewport),
not from a discrete navigation event. Near the very end of a document,
that inference can genuinely never settle on "page N of N": if the
last page is short, or the viewport already shows all of it the moment
the second-to-last page scrolls out, there may be no further scroll
distance left to trigger `onPageChanged` again with the true final
page number. The viewer isn't buggy so much as "current page" is an
inherently fuzzy concept in continuous-scroll mode — this is a
known characteristic of scroll-based PDF rendering generally, not a
Syncfusion-specific defect. The second-to-last-page workaround was a
reasonable way to route around that fuzziness at the time, but it's a
symptom patch, not a fix to the underlying ambiguity — and it's part of
why completion logic has stayed fragile ever since (three of the last
four bugs in this file trace back to how "have we reached the end" gets
decided).

## Full issue catalog

**Correctness (already fixed this session, listed for completeness)**
1. Dwell-timer threshold captured once instead of recomputed per tick — fixed 2026-09-13.
2. 98%-progress failsafe not gated by `_isInitialJump` — a 1-page book, or resuming near the end, completed instantly with zero real reading — fixed 2026-09-14.
3. Local PDF cache never re-validated its own contents — a single bad download broke a book permanently on-device — fixed 2026-09-13.

**Structural — why this file keeps producing bugs**
4. **Completion is decided in three different places** that don't share logic: the dwell timer in `_commitPageChange` (page-index based, anti-cheat gated), the 98% failsafe in `_updateReadingProgress` (percentage based, was ungated until yesterday), and implicitly via `_isInitialJump`'s timing. Each was patched independently as bugs surfaced; nothing enforces they stay consistent, and nothing about this is unit-testable (see below), so the next change here is one edit away from reintroducing exactly the class of bug just fixed twice.
5. **`_isInitialJump` is a flat 1.5-second timer, not an event.** It's a guess at "how long until the PDF viewer has settled," not a real signal. Too short on a slow device or a large PDF and the old instant-completion bug class can resurface in a new shape; too long and it's just dead time. There's no way to know which without a real device farm.
6. **`_extractTextFromCurrentPage` re-parses the entire PDF into a new `PdfDocument` on every single text-to-speech page turn** (line ~768) — disposing and reconstructing native document state per page instead of once. For a longer book being read aloud, that's real, avoidable per-page latency and battery cost, not just a style nit.
7. **Dead code**: `_showQuizDialog` (line ~1461, ~90 lines) is explicitly commented as superseded ("Achievement popups are now handled by global AchievementListener," "Quiz popup removed") and is only kept alive by an `// ignore: unused_element` suppressing the analyzer's own warning that nothing calls it.
8. **No automated test coverage at all**, for any of it. Syncfusion's `SfPdfViewer` isn't mockable in the Flutter widget-test harness (documented earlier this session), so every fix here — including the two shipped in this session — was verified by reasoning through the code plus the full regression suite, never by a test that would catch a regression here specifically. This is the main reason issue #4 above keeps recurring: the completion logic is exactly the kind of branchy, stateful code a unit test would normally catch regressions in, and it's the one part of this screen most resistant to being pulled out and tested the way `looksLikePdf`/`AppReadinessTracker` were this session — its state (`_hasReachedLastPage`, `_isInitialJump`, `_currentPage`) is woven directly into instance fields other methods also mutate, rather than passed as parameters.

**Minor**
9. `SfPdfViewer.file` and `SfPdfViewer.network` (lines ~1272 and ~1298) are near-identical ~25-line widget trees with duplicated callbacks — a small factor-out, not a bug.

## Real alternatives for the page-counting problem specifically

Direct answer to "what better options could I have used":

### Option 1 — `PdfPageLayoutMode.single` instead of `.continuous`
Available today, in the exact Syncfusion version already installed
(`31.1.23`) — just an unset constructor parameter
(`SfPdfViewer.file(..., pageLayoutMode: PdfPageLayoutMode.single)`).
In single mode, the viewer shows one page at a time and page changes
are discrete swipe/navigation events, not scroll-position inference —
`pageNumber == totalPages` becomes an exact, trustworthy check with no
fuzziness. This would let the second-to-last-page workaround be
deleted outright, not patched further.
- **Tradeoff**: loses the smooth continuous-scroll feel — some readers
  (especially older kids or picture-book-style layouts) may prefer
  scrolling to discrete page-turns. This is a genuine product/UX
  choice, not just an engineering one.

### Option 2 — an explicit "Finish this book" action
Instead of *inferring* completion from scroll/page position at all,
show a deliberate action once the reader reaches the last page (a
button, or a small "The End 🎉" screen after it) that the child taps to
mark the book finished. This sidesteps the entire reliability question
— there's no ambiguity to route around because nothing is being
inferred — and arguably reads better for a children's app: a
celebratory, deliberate action instead of an invisible background
trigger the reader never notices happening (which is also, structurally,
*why* an instant/premature completion is possible to begin with — an
inferred trigger has no natural way to ask "are you sure/did you
mean to").
- **Tradeoff**: an extra tap. For picture books/short books especially,
  this is a minor cost; some product ownership opinions will differ
  on whether it's worth it.

### Why not switch PDF libraries instead
Every mainstream Flutter PDF viewer package has historically struggled
with precise last-page/scroll-position detection in continuous-scroll
mode — it's close to an inherent property of continuous rendering, not
a defect specific to Syncfusion. Migrating packages would be a much
larger, riskier change (a full re-integration: caching, text
extraction for TTS, text selection, rules around what's tested) for a
problem that isn't actually specific to the current library. Not
recommended.

### Recommendation
Option 1 (`PdfPageLayoutMode.single`) is the lower-risk, higher-leverage
fix: one parameter change plus deleting the now-unnecessary
second-to-last-page workaround and the associated dwell-timer
complexity built around it, which also shrinks issue #4's "three places
decide completion" down to something much closer to one. Option 2 is
worth layering on top regardless of layout mode, independent of this
decision, since it also directly closes the "opened it and it was
already marked complete" class of complaint at the UX level, not just
the code level — an explicit tap can't fire "by accident."

Neither should be done as a silent drive-by edit: switching page layout
mode is a visible interaction change real users will notice immediately,
and deserves a deliberate yes before it ships, same as any other
product-facing decision made this way in this engagement.

## Smaller, lower-risk cleanups worth doing regardless of the above

These don't require a product decision and carry little risk:
- Delete the dead `_showQuizDialog` (issue #7).
- Parse the `PdfDocument` once for TTS instead of per page-turn (issue #6).
- Factor the duplicated `SfPdfViewer.file`/`.network` trees into one (issue #9).

## Open questions before Option 1 or 2 is built

1. Continuous scroll vs. single-page: does the product want to keep
   scroll-based reading, accept the UX change to page-by-page, or offer
   both (a per-user or per-book setting)?
2. Does an explicit "Finish" action fit the intended reading experience,
   or should completion stay implicit/automatic even if that means
   accepting some residual fuzziness at the boundary?
3. If Option 1 ships, does the second-to-last-page workaround (and its
   longer anti-cheat dwell threshold) get deleted outright, or kept as
   defense-in-depth even though it should no longer be reachable?

No implementation attached to this doc — see recommendation above for
why switching page layout mode specifically should wait for an explicit
decision rather than being folded into a "fix" commit.
