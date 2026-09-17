# Early-childhood (4-7) audit — what has to change and why

Status: **audit only, nothing implemented.** Requested as the starting
point for shifting the app's target age band down to 4-7. This doc
grounds "what needs to change" in the actual code rather than general
assumptions about children's apps — every finding below cites the
specific file/flow it came from. Nothing here has been built yet.

## Bottom line

The app was not built for 4-7. Concretely: the onboarding personality
quiz is a Likert-scale self-report instrument a 4-year-old cannot
answer, every account (including "child" accounts) signs up with a
typed email and password, book comprehension quizzes have no audio and
no age parameter at all, and the content filter's default ceiling is
**12+**. None of this is a style nit — these are the things that
determine whether a 4-7-year-old can use the app *at all*, independent
of any parent help.

The reading experience itself is closer than expected: text-to-speech
already exists and works, and page-by-page navigation (just shipped)
is about as simple an interaction model as this kind of app gets. The
gap is concentrated in onboarding, assessment, and account setup — not
in the core "read a book" loop.

## Findings, most to least severe

### 1. The onboarding personality quiz cannot be answered by a 4-7-year-old — ADDRESSED, via a third path

**Update:** neither of the two directions below was ultimately taken.
Discussed and settled on a cheaper third option: keep the existing BFI-C
structure entirely (10 questions, 5 dimensions, same scoring) and fix
the actual barrier — the wording — by rewriting every question as a
concrete, everyday behavior instead of an abstract self-report
statement, and simplifying the 5-point Likert scale to a 3-point
No/Sometimes/Yes! one. See SECURITY.md's "Personality quiz: concrete
wording + a simpler 3-point scale" entry. The original findings below
are kept for context on why the wording was the problem.

`lib/screens/quiz/quiz_screen.dart` — 10 first-person Likert-scale
statements ("I stay calm when things don't go my way," "I keep my
things neat and tidy," "I use my imagination a lot"), each rated
Not-like-me / Sometimes-like-me / Very-much-like-me. This is a
simplified Big-Five/OCEAN-style self-report inventory
(`lib/services/personality_scoring.dart`). Self-report personality
instruments like this are validated for meaningfully older children —
they require reading the statement, understanding abstract
self-concepts ("I keep my things neat and tidy" requires a stable
self-image about tidiness), and introspecting honestly. A 4-6-year-old
can't reliably do this; the recommendation engine downstream
(`BookProvider.loadRecommendedBooks`) is fed from these traits, so a
meaningless answer here produces a meaningless recommendation.

**This has no small fix.** It needs a genuinely different instrument
for this age band — most early-childhood apps solve this either by
having the *parent* answer a short proxy questionnaire about the child,
or by replacing self-report entirely with a visual preference picker
("tap the pictures you like": animals, space, princesses, trucks,
dinosaurs...) that infers interest categories without requiring
introspection or reading at all. This is a product decision, not
something to guess at — see open questions below.

### 2. Every account signs up with a typed email + password, including "child" accounts

`lib/screens/auth/account_type_screen.dart` offers "I'm a Child" /
"I'm a Parent" as a self-selected choice at signup, both leading into
the same `register_screen.dart` — username, email, password, confirm
password, all `TextFormField`s. A 4-7-year-old cannot reliably type an
email address or a password, let alone remember one across sessions.

This directly matches what you flagged (#5, "only child login from the
parent side"). There's already a `parentAccessPin` concept in
`settings_screen.dart`/`parent_link_qr_screen.dart` for parent-linking
an existing child account — worth understanding fully before designing
the new flow, since some of the plumbing may already exist. The shape
this probably needs: the *parent* creates the real account (email/
password, normal auth), then adds one or more child profiles under it
(name + a picked avatar, no credentials) that the child can select with
a single tap — no typing required to "log in" as the child. Scoped
right, this is a self-contained auth-flow change, not a rewrite; see
the "what to do first" section below.

### 3. Book comprehension quizzes: no audio, no age parameter, 4 text-only options

`functions/lib/ai_helpers.js`'s `buildQuizPrompt` (feeding
`generateBookQuiz` in `functions/index.js`) tells the AI to write
"age-appropriate language" — with no age actually specified anywhere
in the prompt. The AI has no signal for what "age-appropriate" means
here, so it's almost certainly defaulting to whatever "children" means
to it in general, not 4-7 specifically. Every question ships as 4
text-only options (A/B/C/D) with zero text-to-speech support on the
quiz screen (confirmed: no TTS/speak calls anywhere in
`book_quiz_screen.dart`) — meaning a pre-reader or emerging reader
cannot take this quiz independently at all, even though the *reading*
screen right next to it already has full read-aloud support.

**This is the cheapest real fix in this whole list.** `buildQuizPrompt`
is one template string — it can take an explicit age-band parameter
(shorter questions, simpler vocabulary, maybe 3 options instead of 4,
maybe pair each option with an emoji/icon) with a fairly small, safe
change. Adding TTS to the quiz screen is also small — the reading
screen's `FlutterTts` usage is a direct model to copy from. This is a
strong candidate for "do now," not something that needs a big design
doc first, once the age-band decision (item 1) tells us exactly how
simple "simple" needs to be.

### 4. Content filter defaults to a 12+ ceiling; book age rating is an unstructured free-text field — PARTIALLY ADDRESSED

`lib/services/content_filter_service.dart`: `ContentFilter`'s default
constructor and Firestore fallback both set `maxAgeRating: '12+'`; a
book with no `ageRating` set defaults to `'6+'`. Neither of these
defaults fits a 4-7 target — a parent who never visits the content
filter screen (the common case, per the earlier "Content filter
silently hiding legitimate books" finding this session) gets a filter
ceiling three times too old.

Separately, `ageRating` is a free-text `TextEditingController` field in
the admin upload form (`book_upload_form.dart`) — an admin can type
literally anything ("6+", "Ages 6-12", "PG"), with no structured
minimum-age value to filter, sort, or recommend by. This matters for
book acquisition too (item #7 on your list): without a real minimum-age
field, there's no reliable way to query "show me only books for a
4-year-old" versus a 7-year-old, even once better books are sourced.

**Update, found while building the comprehension-quiz fix (item 3):**
there's actually a *second*, more structured age source —
`functions/lib/ai_helpers.js`'s `ALLOWED_AGES` — a controlled list used
when the AI-tagging pipeline suggests a rating for a newly-uploaded
book. It's more trustworthy than the free-text admin field, but it
bottoms out at `'6+'`: there is currently no way, anywhere in the app,
for a book to be classified as suitable for a 4-5-year-old
specifically.

**Addressed, partially:** `ALLOWED_AGES` now includes `'4+'` and
`'5+'` — a book can be tagged for that band now, purely additive, no
behavior change for anything already tagged `6+` and up (see
SECURITY.md). The free-text admin field and the default filter ceiling
are **deliberately left untouched**: while looking into this,
discovered `maxAgeRating` has no UI control anywhere in the app at
all — `content_filter_screen.dart` reads and re-saves the existing
value but never lets a parent actually change it, so whatever the code
default is applies to *every* parent, permanently, with no escape
valve. Lowering that default blind, before there's any real 4-5-rated
content in the library to point it at, risks hiding most of today's
catalog from every family by default — the same failure shape as the
"Content filter silently hiding legitimate books" bug found earlier
this session. That default change, and giving parents an actual control
for it, is better scoped as its own follow-up once book acquisition
(#7 on your original list) has produced real content in that band to
verify against — not bundled into this smaller-items pass.

### 5. The child's own Settings tab exposes account-level actions directly — ADDRESSED (partially)

`lib/widgets/app_bottom_nav.dart` puts Settings as a full tab
alongside Home/Library/Ranks on the *child's* own navigation —
`settings_screen.dart` includes Sign Out (behind a confirm dialog, at
least) and profile editing, directly reachable by whoever is holding
the phone. For a 4-7-year-old operating mostly unsupervised, this is
worth reconsidering once the account model in item #2 changes — some
of this probably becomes moot if children stop having independent
sign-in/sign-out at all and just pick a profile.

**Addressed, partially:** added a lightweight "parental gate" (a simple
arithmetic problem, the standard pattern used across children's apps
generally) in front of Sign Out, Profile Edit, and revealing the
parent-linking PIN — see SECURITY.md. This is deliberately *not* the
account-model redesign item #2 still calls for; it's a small,
self-contained guard chosen specifically because it still makes sense
whatever that eventual redesign looks like, so it didn't need to wait.

### 6. Library browsing depends on typed search — LESS SEVERE THAN FIRST STATED, not touched

`lib/screens/child/library_screen.dart`'s primary filter mechanism is
a `TextField`-based search bar. A non-reading or non-typing 4-6-year-old
can't use it.

**Correction, checked more closely for this pass:** the library's top
level is 5 tabs (All Books / For You / Reading Now / Finished / My
Favorites) — tap targets, not typing — with search only available as
an *optional* narrowing tool once inside a tab, not the only way to
browse. A child can already scroll and tap covers within "All Books"
without ever touching search. So this isn't "browsing is impossible,"
it's "one specific narrowing feature is inaccessible" — a real but
noticeably smaller gap than first stated. There's also no genre/category
tap-filter today, which would be a reasonable small addition on top of
what already works, but not an urgent one. Not built in this pass.

### 7. Gamification complexity — flagged, not judged

Leagues (bronze/silver/gold/platinum/diamond), day-streaks, weekly
challenges with percentage progress bars, a numeric points total — all
of this assumes some ability to read English words and grasp
abstractions like "3-day streak" or "67%." Whether this is *too*
abstract for a 4-7-year-old (versus something a parent explains, or
something that still motivates through color/shape/size even if the
child can't read the exact number) is a genuine design judgment call,
not a clear-cut bug the way item 1 or item 2 is. Flagged as an open
question, not a recommendation either way.

## What's already in reasonably good shape

- **Text-to-speech on the reading screen** already exists and works
  end-to-end (`FlutterTts` in `pdf_reading_screen_syncfusion.dart`) —
  this is the single biggest asset for a pre-reading audience, and it's
  already built.
- **Page-by-page reading** (just shipped) is about as simple an
  interaction model as this category gets — one clear "next" action,
  exact progress, no ambiguity.
- **The onboarding welcome screen** (`onboarding_screen.dart`) is
  parent-facing marketing copy a parent reads before handing the device
  over — not something a child needs to parse themselves. Fine as-is.

## Recommended sequencing

**Do now, low risk, no big design decision needed:**
- Lower the content-filter default ceiling (item 4) — a one-line
  default change plus deciding what the new default should be (7+? a
  narrower band?).
- Add an explicit age-band parameter to `buildQuizPrompt` and simplify
  quiz question/option format (item 3) — contained to one Cloud
  Function and its prompt.
- Add TTS to the book-comprehension quiz screen (item 3) — mirrors code
  that already exists on the reading screen.

**Needs your input before building (this is where I'd want your call,
same as the PDF reading redesign earlier):**
- What replaces the personality quiz (item 1) — parent-proxy
  questionnaire, visual preference picker, or something else?
- The exact shape of "child profile under a parent account, no
  credentials" (item 2) — how many child profiles per parent, what
  happens to a child profile when the parent isn't signed in on that
  device, does the existing `parentAccessPin` flow fold into this or
  get replaced?
- Whether library browsing needs a real redesign (item 6) toward
  cover/category-first browsing, or just a lower-priority cleanup.
- The gamification complexity question (item 7) — not urgent, but
  worth a decision rather than defaulting either way by accident.

**Structural, larger, and worth a dedicated field (not code) decision:**
- A real minimum-age field on the book model (item 4) — needed before
  book acquisition (#7 on your original list) can be done well, since
  there's currently no structured way to query "books for a
  4-year-old."

No implementation attached to this doc. Given how much of this (items
1 and 2 especially) shapes the pre/post-test design and book-acquisition
criteria you also flagged, I'd suggest settling items 1 and 2 first —
everything else on this list, and a good chunk of the other items on
your original list, gets easier to scope once those two are decided.
