# Personality quiz → book matching: how valid is it actually?

Requested review: is the 10-question personality quiz actually measuring
what it claims to, and does the book-matching pipeline downstream of it
actually work? This traces the full pipeline end to end against the
actual code, checks it against the published research on child
personality assessment, and looks at what the app's own usage data can
(and can't) tell us right now.

## Bottom line

**The pipeline has three independent, compounding sources of noise, and
none of them has ever been empirically checked.** Each stage is a
plausible-sounding design choice, not a validated one:

1. A 10-item self-report Big Five quiz, answered directly by a 4-7-year-old,
   with methodological choices (no reverse-keyed items, only 2 items per
   dimension, a 3-point scale) that the published research on this exact
   age band flags as weak points even in instruments *designed* for
   validity.
2. Books get 3-5 personality-trait labels from an LLM reading a
   2000-character excerpt against a hand-written heuristic ("problem-solving
   stories → organized/careful") with no human or empirical check that the
   heuristic is actually true.
3. Matching is a naive count of overlapping trait labels between child and
   book, weighted equally regardless of whether a trait was the child's
   clearest signal or a borderline one.

None of this means it's *useless* — trait-overlap recommenders are a
completely standard, reasonable starting design, and there's real
evidence that personalized book selection improves reading engagement.
But "personalized" in that evidence base usually means matching on
*stated preference* (what a kid has already shown interest in), not
*inferred personality*, and this app is currently only doing the second,
harder, unvalidated thing. The honest answer to "how good is this" right
now is: **nobody knows, including the people who built it** — and that's
fixable, cheaply, using data the app is already collecting.

---

## Stage 1: the quiz itself

`lib/screens/quiz/quiz_screen.dart` + `lib/services/personality_scoring.dart`

- 10 questions, exactly 2 per OCEAN dimension (Openness, Conscientiousness,
  Extraversion, Agreeableness, Neuroticism/emotional stability).
- 3-point scale: 🙁 No (1) / 😐 Sometimes (3) / 😄 Yes! (5) — simplified in
  this session from an original 5-point Likert scale specifically because
  a 4-7-year-old can't reliably distinguish 5 fine-grained options
  (SECURITY.md, 2026-09-17).
- **Every single item is positively keyed.** `isReversed: false` on all 10
  questions (confirmed by reading every entry in the `questions` list).
  This includes the Neuroticism items, which are *worded* toward emotional
  stability rather than reverse-scored — functionally fine for the score
  math, but it means there are zero items anywhere in the instrument
  designed to catch acquiescence bias (the tendency to agree with
  whatever's asked, which is a well-documented, strong effect in young
  children answering adults' questions).
- Each OCEAN dimension is scored from only 2 items. This is below the
  item count psychometric convention generally treats as a floor for
  acceptable internal-consistency reliability (Cronbach's alpha) — a
  2-item scale's reliability swings heavily on a single answer.

### What the research actually says about this age band

- The most encouraging evidence for self-report Big Five in young
  children comes from the **Berkeley Puppet Interview** studies (Measelle
  et al., ages 5-7): children's self-reports "approached" adult-level
  consistency and differentiation, and predicted independent parent/
  teacher ratings for Extraversion, Agreeableness, and Conscientiousness
  reasonably well. [PubMed](https://pubmed.ncbi.nlm.nih.gov/16060748/) ·
  [full paper (PDF)](https://pages.uoregon.edu/dslab/Papers_files/Measelle%20et%20al%202005%20JPSP.pdf)
- Critically, **that same study found Neuroticism specifically did not
  correlate with adult ratings** at all, even though it predicted
  observed anxious/sad behavior in the lab. Neuroticism/emotional
  stability is exactly the dimension this app maps to `resilient`,
  `calm`, `positive` — one of five trait families feeding book matching,
  and the one the best available evidence says is least trustworthy from
  a young child's own self-report.
- The BPI's actual *method* is not a tap-through quiz — it's a structured
  interview where a puppet says a statement about itself and the child
  says which puppet they're more like, delivered by an adult, one item at
  a time. That interactive, forced-choice-between-two-options format is
  doing real work for validity; a self-administered Likert-style app quiz
  is a materially different (and less validated) delivery mechanism, even
  with the same underlying dimension structure.
- A 2025 systematic review of Big Five self-report questionnaires for
  children found essentially all of them were built and validated for
  ages 7-18, with "limitations in the validity or reliability of some of
  them" even in that older, easier-to-assess range.
  [Systematic review (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12423744/) ·
  [Wiley](https://onlinelibrary.wiley.com/doi/10.1111/sjop.13110)
- There is a real, purpose-built alternative for this exact problem: the
  **Pictorial Personality Traits Questionnaire for Children (PPTQ-C)** —
  a picture-based instrument designed specifically to avoid the reading/
  abstraction demands of a text Likert scale.
  [PPTQ-C paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4879772/)

This lines up exactly with what `docs/early-childhood-audit.md` already
found and flagged in finding #1 — self-report Big Five wasn't built for
this age — and with the "third path" this project consciously chose
instead of the full fix: reword the questions to be concrete, simplify
the scale, but keep the underlying self-report-Likert *instrument type*.
That was a reasonable, cheap call given the constraints at the time. It
was never a claim that the instrument became valid — just answerable.
Worth being explicit about that distinction going forward, since it's
easy for "the wording is better now" to quietly get read as "the quiz is
now accurate."

---

## Stage 2: book → trait tagging

`functions/lib/ai_helpers.js`'s `buildTaggingPrompt`, feeding the daily
`dailyAiTagging` Cloud Function.

Every book's 3-5 personality traits come from an LLM given a 2000-character
excerpt and a hand-written heuristic table baked into the prompt:

```
Learning, exploring, asking questions → curious, adventurous
Solving problems, planning → focused, organized, careful
Staying brave, facing fears → brave, confident, calm
...
```

This is the developers' own theory of what kind of child enjoys what kind
of story, encoded as instructions to an LLM, with **no human review step
and no empirical check anywhere in the pipeline** that the theory holds.
It's a plausible starting heuristic (theme → likely appeal is a real
intuition), but it's unvalidated in the same sense the quiz is — nobody
has checked whether children who score high on `organized` in the quiz
actually engage more with books the AI tagged `organized` than with any
other book.

Two compounding risks worth naming directly:
- **The excerpt is only the first 2000 characters** (`bookText.substring(0, 2000)`
  in both the tagging and quiz-generation prompts) — a book whose
  personality-relevant content appears later (a character's growth arc, a
  twist, the actual resolution) is tagged from an incomplete read.
- Trait selection depends on the LLM correctly weighing a *hand-written
  heuristic table* against the story's actual content on every single
  call — prompt-following of this kind is not perfectly consistent
  run-to-run for a given book, though this hasn't been measured either.

---

## Stage 3: matching

`lib/providers/book_provider.dart`'s `calculateBookRelevanceScore` (rule-based
tier, always runs) and `buildRecommendationPrompt` (AI tier, daily batch,
overrides the rule-based list when available).

- **Rule-based tier**: `score += 10` per exact trait-string overlap between
  the child's 5 derived traits and the book's 3-5 tagged traits. Flat,
  binary, unweighted — a book matching the child's single clearest trait
  scores identically per-match as a book matching one of the two
  long-tail traits the D'Hondt allocation in `personality_scoring.dart`
  assigned almost as a tiebreak among close-scoring dimensions (see that
  file's own doc comment on trait allocation). The scoring function has
  no concept of "how confidently does this trait actually describe the
  child."
- **AI tier**: hands the same two trait-label lists to an LLM and asks it
  to rank by "match." This doesn't add a new signal — it's the same
  shallow trait vocabulary, just with an LLM's judgment substituted for
  the rule-based count. It may `be` better than a flat count, but nothing
  in the pipeline checks whether it actually is; it could equally add
  LLM-inconsistency noise on top of an already-unvalidated label match.
  (The ID-filtering safety net in `parseRecommendationResponse` is good
  engineering against hallucinated/stale IDs, but that's a correctness
  guard, not a relevance one.)

---

## What the evidence base says about personality-driven recommendation generally

- A 2024 randomized controlled trial in an ed-tech reading app found
  content selected by **stated preference** produced a 60%+ engagement
  increase over editor-picked content, plus a 15% lift in overall app
  usage. [arXiv](https://arxiv.org/pdf/2208.13940)
- A systematic review of book recommender systems (32 studies,
  2020-2024) found personalized recommenders generally have positive,
  measurable effects on reading frequency, duration, and motivation.
  [Springer](https://link.springer.com/article/10.1007/s44163-026-00911-2)

The important nuance: most of this evidence is about matching on
**explicit, observed preference** (what a child has read, liked,
searched for, or directly said they want) — a fundamentally easier and
better-grounded signal than **inferring five abstract personality
dimensions from a 10-item child self-report and hoping they map onto
story themes correctly**. This app already collects real preference
signal it isn't using for matching at all: `book_interactions`
(favorites/bookmarks, 325 docs currently), `reading_progress`
(completion, re-reads, time spent — 79 docs), and `reading_sessions`
(101 docs). A hybrid that leans more on "kids who finished/favorited
book X also engaged with book Y" and less on personality inference alone
would be standing on much firmer ground, evidence-wise, than the current
personality-only design.

---

## What the app's own data can tell us right now — and can't yet

Checked directly against the live Firestore data (`readmev2`):

| Collection | Count | Relevant to |
|---|---|---|
| `users` with personality traits saved | 9 of 21 | quiz completion |
| `reading_progress` | 79 docs | completion rate, time spent |
| `reading_sessions` | 101 docs | engagement duration |
| `book_interactions` | 325 docs | favoriting/bookmarking (preference signal) |
| `quiz_analytics` | 0 docs | (appears unused — personality results actually live on the `users` doc itself, not this collection) |

**9 users with saved traits is not enough to draw any real statistical
conclusion yet** — this is stated plainly rather than papered over. A
correlational check ("do recommended books get finished more often than
non-recommended ones?") is possible to build today and would cost
nothing to run, but with this few users any result would be noise, not
signal. The right move is to build the tracking now (see below) so it's
answerable once usage grows, not to over-interpret a 9-person sample
today.

---

## Recommended path forward, cheapest first

1. **Instrument recommendation outcomes now, even with a small user base.**
   When a book is shown because it was recommended (rule-based or AI
   tier), tag that fact on the resulting `reading_progress`/
   `book_interactions` record. Costs almost nothing to add, and turns
   "how good is this" from a permanently open question into something
   that gets a real, growing-in-confidence answer over time — completion
   rate and re-read rate for recommended vs. non-recommended reads is the
   single most direct test of whether the *whole pipeline* (quiz +
   tagging + matching combined) is doing anything useful, independent of
   which stage is responsible.
2. **Test-retest the quiz.** Have the same child (with parent help) take
   the quiz twice, a few days apart, with nothing else changing. If the
   resulting 5 traits are wildly different between attempts, the
   instrument isn't measuring anything stable at this age — a cheap,
   fast, concrete check that needs no new code, just a handful of real
   families.
3. **Spot-check the AI book tagging against a human.** Pull a random
   sample of 20-30 already-tagged books, have a person (you, or better, a
   parent/teacher panel) independently pick traits for the same books
   using the same allowed-trait list, and compare. This directly tests
   Stage 2's core assumption without touching any code.
4. **Weight the matching score by how strongly a trait was expressed.**
   `personality_scoring.dart` already has the raw OCEAN dimension scores
   before they get flattened into 5 equally-weighted trait strings — that
   information currently gets thrown away before it reaches
   `calculateBookRelevanceScore`. Feeding it through so the child's
   clearest trait counts for more than the borderline third pick is a
   small, contained change with a plausible direct improvement, testable
   against (1) once that instrumentation exists.
5. **Consider leaning the matching algorithm toward preference signal
   (favorites, completions, re-reads) rather than personality inference
   alone**, given that's where the actual outside evidence is strongest.
   This doesn't require abandoning the personality quiz — it can be a
   secondary signal or tie-breaker rather than the sole input — but the
   current design treats inferred personality as the *only* signal, which
   the evidence doesn't clearly support over preference-based matching.
6. **If deeper quiz validity ever becomes worth investing in**, the
   PPTQ-C (picture-based) or a BPI-style interactive interview format
   both have actual published validity evidence at this age band that a
   text Likert quiz doesn't — this is the "real fix" the early-childhood
   audit already identified and consciously deferred, not a new finding.

None of items 1-4 require the bigger product decision in #5-6 to be
settled first — they're all independently useful, cheap, and buildable
now.
