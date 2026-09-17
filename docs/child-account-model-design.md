# Child-account/login model — scoping doc

Status: **scoped out, not implemented.** This is the other big item
from `docs/early-childhood-audit.md` (finding #2), covering "there
might only be the child login from the parent side" from the original
request list. Like the reading-session-integrity and PDF-reading
redesigns earlier, this is architecture-affecting and visible to real
users, so it gets a design pass before any code changes — especially
since the actual current state turned out to be more nuanced than the
audit first suggested. Nothing here has been built.

## What's actually there today (checked directly, not assumed)

There are **three** paths into a "child" account today, not one:

1. **Self-serve signup** (`account_type_screen.dart` → `register_screen.dart`)
   — anyone picks "I'm a Child" and types their own
   username/email/password/confirm-password directly. Zero parental
   involvement at signup. This is the one the audit flagged, and it's
   real: nothing stops a child from doing this themselves, or an adult
   from creating one with no age gate.
2. **Parent-initiated creation** (`AddChildScreen`'s "Create New" tab,
   reached from the parent's own dashboard) — the *parent* types a
   username/email/password for their child, which calls the
   `createChildAccount` Cloud Function
   (`functions/lib/create_child_account.js`). This already exists and
   already works — it creates a real Firebase Auth user via
   `auth.createUser()`, a Firestore profile (`accountType: 'child'`,
   `parentId`), and links it into the parent's `children` array. The
   parent then sees a one-time "Save these credentials!" dialog.
3. **Linking an existing child to an additional parent**
   (`AddChildScreen`'s "Scan QR" / "Enter PIN" tabs) — reads the
   `parentAccessPin` shown in the child's own Settings screen (now
   gated behind the parental math-gate from the smaller-items pass)
   and adds the scanning parent's uid to the child's `parentIds` array.
   Firestore rules (`firestore.rules`) already support multiple parents
   per child via that array.

**The real gap isn't "no parent-driven path exists" — it's two other things:**

- **Path 1 (self-serve) is still open to anyone**, unfenced, alongside
  the parent-driven paths. For a 4-7 target this shouldn't be reachable
  by a child at all.
- **Even path 2, the "good" parent-driven path, still ends with the
  child needing a typed email + password to sign in on their own,
  every time.** `createChildAccountHandler` creates a full,
  independent Firebase Auth user — there's no lighter-weight "profile"
  concept underneath it. A 4-7-year-old still can't operate that
  day-to-day, and there's no way for two children sharing one family
  tablet to switch between their accounts without a full sign-out and
  a fresh email+password sign-in each time (confirmed:
  `login_screen.dart` is a plain email/password form; there is no
  profile-switcher screen anywhere in the app).

## Why this matters for the rest of the backend

Nearly everything built this session — `points_engine.js`'s six award
functions, `reading_sessions.js`, the weekly-challenge/achievement
system, and `firestore.rules` itself — is keyed directly off
`request.auth.uid` **being** the child. Firestore rules check a child
document's `parentIds`/`parentId` against `request.auth.uid` to decide
parent access; every Cloud Function in `points_engine.js` trusts
`request.auth.uid` as "the child this award is for," by design (that
trust is exactly what the whole point-award security migration made
safe to rely on). Any redesign that gets rid of a real Firebase Auth
UID per child would mean touching all of that — a much bigger, riskier
change than the login-flow problem actually requires.

## Three options

### Option A — Remove the self-serve path only (cheapest, partial)

Delete (or hide behind an adult-gate) "I'm a Child" from
`account_type_screen.dart`. Only a parent can ever create a child
account, via the already-working `AddChildScreen` "Create New" flow.

- **Closes:** a child (or anyone) self-registering with zero parental
  involvement — the worst part of the current gap.
- **Doesn't close:** the day-to-day credential problem. A child still
  can't operate their own login; a parent has to either hand over an
  already-signed-in device or type the child's email/password in for
  them every time they switch.
- **Cost:** near-zero. Delete one UI entry point, maybe repurpose
  `account_type_screen.dart` into "Parent" vs. "I already have a PIN
  to link a child" instead of "Parent" vs. "Child."

### Option B — Device-remembered credentials, "tap your avatar" resume (moderate)

Keep `createChildAccount` exactly as it is (parent still sets up the
account, sees the credentials once). But instead of ever showing those
credentials to the child, store them securely on-device
(`flutter_secure_storage`) after the parent's one-time setup. Add a
lightweight profile picker: on that device, show avatars for every
child the parent has set up there; tapping one calls
`signInWithEmailAndPassword` using the stored credentials — the child
never types anything.

- **Closes:** day-to-day credential entry for a child on a device
  their parent has already set up.
- **Doesn't close:** cleanly moving between devices (a child visiting
  grandma's tablet still needs the parent to set that device up too,
  or type credentials manually) — plausible for a first release, but
  worth naming as a real limitation, not something this quietly solves.
- **Cost:** small-to-moderate. No backend changes at all — every
  Cloud Function, every Firestore rule, keeps trusting
  `request.auth.uid` exactly as today. Mainly local storage + a new
  profile-picker screen. The one real wrinkle: storing a password
  on-device, even encrypted via secure storage, is a legitimate
  security tradeoff worth being upfront about — it's a common pattern
  for kids'-mode apps, but not a "no downside" one.

### Option C — Parent-session profile switching via custom auth tokens (most correct, most work)

Parent stays signed in on the family device. Add a `switchToChildProfile`
Cloud Function: given a child uid already linked to the calling
parent (checked the same way `AddChildScreen`'s linking flow already
checks `parentIds`), it mints a short-lived Firebase **custom auth
token** for that child uid (`admin.auth().createCustomToken(childUid)`).
The client calls `FirebaseAuth.instance.signInWithCustomToken(token)`
to actually become that child's session — no email, no password,
anywhere in the flow, ever. Switching back to the parent (or to a
different child) is the same flow in reverse/again.

- **Closes:** everything Option A and B close, plus multi-device and
  multi-child switching cleanly — this is the actual "family account,
  many lightweight child profiles" model the audit envisioned.
- **Preserves everything already built:** since the child still signs
  in as a real Firebase Auth UID (just minted via a custom token
  instead of typed credentials), every existing Cloud Function and
  Firestore rule keeps working completely unchanged. This is
  deliberately *not* a data-model rewrite.
- **Cost:** moderate. One new Cloud Function (with its own
  authorization check — this needs the same rigor as everything else
  built this session, since minting a token for an arbitrary uid is
  exactly the kind of thing that must never be reachable for a uid the
  caller doesn't actually parent), a client-side profile-picker UI, and
  handling the two session boundaries cleanly (parent → child, child →
  back to parent or Settings' parental-gate-protected areas).

## Recommendation

Option A first, immediately — it's cheap, safe, and closes the worst
part of the gap (self-serve signup with zero parental involvement) on
its own. Option C is the real fix and where this should end up: it
solves the actual day-to-day problem (a child can't handle
credentials) without touching any of the backend security work already
shipped this session, unlike a full data-model rewrite would. Option B
is a reasonable *middle* step if Option C's scope doesn't fit right
now — smaller, single-device-only, with the on-device-credential
tradeoff named plainly rather than glossed over — but I'd treat it as
a stepping stone, not the destination, given Option C isn't actually
that much more work once Option A is done.

## Open questions before Option B or C is built

1. Should Option A ship on its own first (fast, real improvement), or
   wait and ship together with B/C?
2. For Option C: does switching *back* from a child profile to the
   parent need its own gate (the parental math-gate already built, or
   something stronger), or is "the child hands the device back" enough
   in practice?
3. Multi-child households: is a device-level "which children have been
   set up here" list the right mental model, or should it always be
   "parent signs in, then picks a child" every time the app is
   (re)opened?
4. Does the one-time "Save these credentials!" dialog in
   `AddChildScreen` still make sense once children no longer sign in
   with them directly (Option C), or should it be removed/reworded
   entirely at that point?

No implementation attached to this doc — see recommendation above.
