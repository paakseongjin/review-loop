# Review Lenses

Run each lens separately, in order. For every item: produce a finding
only with file:line, a concrete failing scenario, and expected vs.
actual behavior. Apply checks only to relevant paths and invariants. A
missing implementation pattern alone is not a defect: show how the
actual design violates a requirement, or mark the concern UNVERIFIED.

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
- Where an invariant requires multiple database writes to succeed or
  fail together, verify a transaction or equivalent atomic mechanism.
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
- For app-only validation, identify an actual bypass or race before
  confirming a finding; otherwise record the concern as UNVERIFIED.
- Totals match their parts (order total = sum of items); derived
  values cannot drift from source values without a reconciliation.

### Isolation
- Concurrent execution test: fire the same operation 2–10 times in
  parallel (two buyers for the last item, double-click submit, two
  coupon redemptions). Exactly one may win where the invariant says so.
- Read-modify-write sequences (check stock, then decrement) are
  atomic in the DB (single UPDATE with condition, row lock, or
  optimistic version column) — not two separate app-level steps.
- For money and stock paths, trace the isolation and locking behavior;
  report a confirmed issue only if a concrete interleaving breaks an
  invariant. If isolation cannot be determined, mark it UNVERIFIED.

### Durability
- A success response is returned only after the write is committed.
  Fire-and-forget async saves for acknowledged work are a finding.
- Critical data is not stored only in memory, local storage, or an
  ephemeral file system.
- Backup exists and a restore has been tested at least once; if this
  cannot be verified from the repo/environment, report it as an
  operational UNVERIFIED item in the verdict.

## Lens 3 — Concurrency & Idempotency

- For retried payment, order, send, or charge operations, trace how
  duplicate effects are prevented. An idempotency key is one possible
  mechanism; confirm a defect only when a duplicate effect can occur.
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
- For new packages, record their registry identity, release and
  maintenance dates, and whether the lockfile matches project policy.
  Explain any concrete supply-chain risk rather than applying an
  undefined age or maintenance threshold.
- Dependency audit shows no known critical/high CVEs in the added
  set, or each is listed in the report with a decision.
- No install scripts or binary fetches were added silently.

## Lens 7 — Architecture & Drift

- Verify changed imports and called methods against installed project
  dependencies or their authoritative definitions when their availability
  is uncertain. An unresolved import or incompatible API is a finding only
  when it affects a reachable path; record unavailable verification.
- Where changed data access or UI work could materially affect latency or
  resource use, trace representative scale and look for repeated queries,
  unbounded results or blocking operations. Confirm impact with a relevant
  measurement or a concrete scaling argument; do not prescribe caching,
  indexes or pagination solely because they are absent.

- The change reuses existing modules/components/utilities instead of
  adding a parallel implementation of the same rule.
- The same business rule is not implemented twice with different
  behavior (e.g. price calculation in two places).
- No dead code, commented-out blocks, or TODO placeholders shipped
  as finished work.
- Compare changed behavior with explicit requirements and inferred
  assumptions. Report missing required behavior and concrete unexpected
  behavior; lack of mention in an incomplete spec is not proof of a bug.
- When duplicate implementations disagree, cite both locations and a
  concrete input producing inconsistent results. Treat style differences
  without a correctness impact as observations rather than defects.
