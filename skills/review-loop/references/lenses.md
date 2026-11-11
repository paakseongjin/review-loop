# Review Lenses

Run each lens separately, in order. For every item: produce a finding
only with file:line, a concrete failing scenario, and expected vs.
actual behavior — otherwise mark it UNVERIFIED or drop it.

## Lens 1 — Security & Authorization

- Every read/write of user-owned data checks ownership/permission on
  the server, not only in the UI. Test pattern: logged in as user B,
  request user A's object by id (IDOR). Expected: 403/404.
- All queries parameterized; no string-built SQL. All rendered user
  input escaped (XSS). Server-side URL fetching restricted (SSRF).
- Passwords hashed with a modern KDF; sessions/tokens expire and can
  be revoked; password reset does not leak account existence.
- Database row-level security / policies enabled where the platform
  supports them (e.g. Supabase RLS), and enforced in the DB, not only
  in app code. An app-only check is a finding if direct DB/API access
  can bypass it.
- No secrets in source, logs, or client bundles. `.env` not committed.
  Public keys and secret keys not mixed up.
- Admin/destructive endpoints require elevated authorization, checked
  on the server for every call.
- File uploads: type/size validated server-side, stored outside the
  web root or served with safe content types.

## Lens 2 — ACID & Transactions

For every operation that writes data, ask four questions.

### Atomicity
- Operations touching 2+ tables/rows (order + stock + points,
  payment record + balance) run in one transaction.
- Mid-operation failure (simulate by forcing an error in step 2 of 3)
  leaves **no** partial writes: no orphan rows, no deducted stock
  without an order, no charged payment without a record.
- External effects (email, payment API) are not inside the DB
  transaction; they are queued (outbox/job) or compensated, so a
  rollback does not leave a sent email for a cancelled order.

### Consistency
- Business invariants are enforced by the database, not only by app
  code: UNIQUE (email, idempotency key), CHECK (balance >= 0,
  stock >= 0), FOREIGN KEY, NOT NULL.
- App-level validation alone is a finding: it can be bypassed by a
  direct API/DB call, a race, or a second client.
- Totals match their parts (order total = sum of items); derived
  values cannot drift from source values without a reconciliation.

### Isolation
- Concurrent execution test: fire the same operation 2–10 times in
  parallel (two buyers for the last item, double-click submit, two
  coupon redemptions). Exactly one may win where the invariant says so.
- Read-modify-write sequences (check stock, then decrement) are
  atomic in the DB (single UPDATE with condition, row lock, or
  optimistic version column) — not two separate app-level steps.
- Isolation level / locking choice is deliberate for money and stock
  paths; default-and-hope is a finding on `public`/`critical` tiers.

### Durability
- A success response is returned only after the write is committed.
  Fire-and-forget async saves for acknowledged work are a finding.
- Critical data is not stored only in memory, local storage, or an
  ephemeral file system.
- Backup exists and a restore has been tested at least once; if this
  cannot be verified from the repo/environment, report it as an
  operational UNVERIFIED item in the verdict.

## Lens 3 — Concurrency & Idempotency

- Every non-idempotent POST (payment, order, send, charge) accepts or
  generates an idempotency key; a retry with the same key returns the
  original result instead of duplicating the effect.
- Client retries, double clicks, and webhook redeliveries do not
  duplicate effects (webhook handlers deduplicate by event id).
- Counters and quotas are incremented atomically, not computed as
  read-then-write in app code.
- Scheduled jobs are safe to run twice after a crash/restart.

## Lens 4 — Data Integrity & Migrations

- Migrations are reversible or have a written rollback; destructive
  changes (drop column/table, type narrowing) are staged (add →
  backfill → switch → drop), not one-step.
- Backfills handle nulls and legacy rows; the migration runs against
  production-shaped data in staging before production.
- Deletes: soft vs. hard delete is deliberate; cascades do not remove
  records other features still need (orders of a deleted product).
- Seed/demo data cannot reach production paths.

## Lens 5 — Error Handling & Observability

- Errors are not swallowed: empty catch blocks, ignored return codes,
  and `catch {}` that returns success are findings.
- The API never reports success for work that failed downstream.
- Critical paths (payment, signup, order, data deletion) emit logs or
  metrics sufficient to reconstruct what happened, without logging
  secrets or personal data.
- External calls have timeouts; retries are bounded and do not
  multiply side effects (ties back to Lens 3).

## Lens 6 — Dependencies & Supply Chain

- Every newly added package actually exists in its official registry
  and is the package the author intended (hallucinated or
  typosquatted names are a Critical finding).
- New packages are not brand-new/abandoned for critical functions;
  lockfile is updated and committed; versions pinned per project
  convention.
- Dependency audit shows no known critical/high CVEs in the added
  set, or each is listed in the report with a decision.
- No install scripts or binary fetches were added silently.

## Lens 7 — Architecture & Drift

- The change reuses existing modules/components/utilities instead of
  adding a parallel implementation of the same rule.
- The same business rule is not implemented twice with different
  behavior (e.g. price calculation in two places).
- No dead code, commented-out blocks, or TODO placeholders shipped
  as finished work.
- The code does nothing the oracle/spec does not mention (silent
  scope growth), and everything the spec requires is present
  (silent scope loss). List both directions explicitly.
- Naming and structure follow the repository's existing conventions;
  a second style island is a Minor finding, a second data model for
  the same concept is a Major finding.
