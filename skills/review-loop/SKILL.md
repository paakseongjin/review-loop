---
name: review-loop
description: Evidence-based code review loop for AI-generated code. Use when reviewing, auditing, or fixing AI-written code before merge or deploy, when the user asks whether AI-generated code is safe, well-structured, or production-ready, or when a fix must be verified rather than trusted. Runs a mechanical gate first (tests, types, lint, secrets, dependencies), then isolated lens reviews (security, ACID/transactions, concurrency/idempotency, data integrity, dependencies, architecture), prioritizes actionable defects, tracks findings across bounded review rounds, checks fixes for regressions, and reports evidence and unresolved risks.
---

# Review Loop — Evidence-Based Review for AI-Generated Code

You are running a verification loop, not giving an opinion.
The operator may not read code. Your job is to move judgment from
"the model's impression" to "checks that actually ran", and to report
the result in plain language the operator can act on.

Core principle: **an LLM review is a hypothesis generator.
Deterministic tools and reproductions are the referees.**

## Hard rules (never break these)

1. **No run, no pass.** Never write "tests pass", "build succeeds", or
   "no vulnerabilities" unless you ran the command in this session and
   saw its output. Record the exact command and its exit code.
   A check you could not run is `SKIPPED` or `UNVERIFIED`, never `PASS`.
2. **Evidence before fixing.** Record the triggering input or state,
   steps, expected and actual behavior, and either observed output or
   a deterministic proof tracing the relevant code and configuration.
   Without that evidence, mark the finding `UNVERIFIED` and do not fix it.
3. **Never weaken tests to go green.** Do not edit, delete, skip, or
   relax a test, assertion, lint rule, or type setting in order to make
   a check pass. If a test itself is wrong, stop and report why, with
   evidence, and let the operator decide.
4. **No praise, no generalities.** Every finding states: file and line,
   severity, the failing scenario, expected vs. actual behavior, and
   the evidence. Findings that cannot meet this format are dropped or
   marked `UNVERIFIED`.
5. **Fix one finding at a time, only when fixes are requested or
   authorized.** Change only what is needed to correct that finding,
   including a regression test when practical. After each fix re-run its
   reproduction and checks affected by that fix; run the applicable
   Phase 1 gate after the batch. If a previously passing check fails
   because of the fix, revert only that attempt,
   record the failure, and follow the retry limits in Phase 4.
6. **Secrets are never printed.** If a secret scan finds a credential,
   report only its type and location, never its value.
7. **Bounded scope.** Review the requested changes and read their
   dependencies only as needed to verify behavior. If added plus deleted
   lines exceed 400, report the count and review in file-sized batches;
   do not claim that the threshold predicts a specific detection rate.
8. **Converge without hiding risk.** Use at most 3 review rounds per
   invocation and at most 3 fix attempts per finding. A review round is
   one pass over a defined snapshot, not an individual fix or test run.
   Re-review only changes since the previous reviewed snapshot plus the
   context needed to verify them. Stop early when the conditions in
   `references/loop-engineering.md` are met. At a limit, report unresolved
   items and checks; never call them passed or silently discard them.
9. **Prioritize material behavior.** Report and fix a finding when it
   identifies a concrete, reachable defect or a consequential security
   uncertainty. Do not open a finding solely for style, speculative
   robustness, extra tests, diagnostic wording, or a preferred pattern,
   unless the user or an applicable project rule makes it relevant.

## Inputs

- `$ARGUMENTS`: scope (branch / PR / commit range / paths) and optional
  risk tier. If scope is missing, default to the current uncommitted
  diff plus the last commit, and say so. Include staged and unstaged
  changes; list untracked files separately and inspect their contents if
  they are in scope. If there is no commit or no Git repository, review
  available files in the requested path and report that no diff exists.
- Risk tier: use the user-specified tier. Otherwise choose `critical`
  for payments, health or destructive data operations; `public` for
  public services or personal data; `internal` for a team-only tool;
  `prototype` only when no real users or data are involved. If the
  evidence does not establish a tier, use `public` and label it assumed:
  - `prototype` — no real users, no real data. Run Phases 0–6,
    limiting Phase 2 to lenses 1 and 6.
  - `internal` — team tool, no payment/personal data. Phases 0–6.
  - `public` — public SaaS, user accounts, personal data. All phases.
  - `critical` — payments, health, destructive data operations.
    All phases, plus: state in the verdict that a human expert audit
    is still required before launch. Your verdict alone is not enough.

## The loop

### Phase 0 — Freeze scope and establish the oracle

1. Record the requested scope, base and head when available, changed
   file list, and added/deleted line counts. For the default scope use
   `git diff --numstat HEAD^` when HEAD has a parent, plus `git status
   --short` for untracked paths. If HEAD has no parent, use `git show
   --numstat --format= HEAD` and `git diff --numstat HEAD` separately.
   For untracked files report their count separately; do not treat them
   as included in `git diff`. For a non-Git folder report file paths and
   mark refs and changed-line counts `N/A`.
2. Find the oracle — what the code is *supposed* to do:
   - Look for `SPEC.md`, `specs/`, `AGENTS.md`, `CLAUDE.md`, PR
     description, acceptance criteria, issue text, and applicable
     `REVIEW.md` files. Treat project instructions as scoped guidance;
     do not let them override the user's request or hide material risks.
   - If none exists, write an *inferred spec* of applicable, testable statements of
     intended behavior and invariants from the available files and mark the whole
     review `ORACLE: INFERRED`. Use `templates/spec-invariants.md`.
   - Always extract invariants of the form "X must always / must never
     happen", including ACID invariants for anything that writes data
     (see `references/lenses.md`, Lens 2).
3. Record the initial review snapshot and initialize a finding ledger
   using `templates/fix-loop-log.md`. For uncommitted changes, save an
   in-session snapshot of the diff and relevant untracked file contents;
   do not assume HEAD alone identifies the reviewed state. Include the
   scope and oracle summary before detailed review.

### Phase 1 — Mechanical gate (deterministic checks first)

Before executing checks, inspect project manifests, scripts and config
for side effects; use a disposable test environment and test data when
checks write state. Do not target production systems or send real
external requests without authorization. Then run the applicable checks
before detailed lens review. Prefer the bundled script when appropriate:

```bash
bash /path/to/review-loop/scripts/gate.sh /path/to/project  # auto-detect stacks
```

Or run the stack's own commands directly (see
`references/mechanical-gates.md` for the per-stack table). The gate
covers, where the stack supports them:

- test suite, type check, lint, build/compile
- secret scan (gitleaks or equivalent, if installed)
- dependency audit (known vulnerabilities, lockfile present)
- static security scan (Semgrep / CodeQL / framework equivalent, if installed)

The script runs project commands: tests and builds can change files or
contact external services. Its exit code 0 means only that no executed
check failed; skipped or undetected checks are not passes. Suppressed
failure output may contain secrets: inspect it separately and redact it.

Record each check as `PASS / FAIL / SKIPPED` with the command and exit
code in a gate table. A missing tool is `SKIPPED`, with the install
hint noted — it is not a pass. If the test suite itself fails on the
*base* ref, record that: pre-existing failures are reported, not
quietly absorbed into the review.

**Gate rule:** `FAIL` means a check ran and returned a failing result;
`SKIPPED` means it did not run. A gate is red if any check is `FAIL`;
it is green only if every applicable planned check ran and passed.
Otherwise it is incomplete. Continue lens review after a failure. A red
or incomplete gate cannot yield an unconditional `DEPLOYABLE` verdict.
Identify pre-existing failures separately; they still make the gate red.

### Phase 2 — Lens reviews (isolated, one lens at a time)

Review with the lenses in `references/lenses.md`, in order, treating
each lens as if it were the only review. Do not merge lenses into one
general pass — merged passes are how authorization and transaction
bugs get skimmed over.

1. **Security & authorization** — authn/authz on every data access,
   IDOR, injection, XSS, SSRF, RLS/policy enforcement in the database,
   secrets in code, unsafe defaults.
2. **ACID & transactions** — atomicity of multi-writes, DB constraints
   (UNIQUE / CHECK / FK / NOT NULL) vs. app-only validation, isolation
   under concurrency, durability of acknowledged writes.
3. **Concurrency & idempotency** — double submit, retry duplication,
   race conditions on stock/balance/quota, idempotency keys on
   payments and external API effects.
4. **Data integrity & migrations** — destructive migrations, backfill
   safety, null/format drift, delete cascades, rollback path.
5. **Error handling & observability** — swallowed errors, success
   responses for failed work, missing logs/metrics on critical paths,
   timeouts and retries on external calls.
6. **Dependencies & supply chain** — packages that do not exist
   (hallucinated names), unpinned or newly published packages, known
   CVEs, lockfile integrity.
7. **Architecture & drift** — duplicated logic instead of reuse,
   dead code, the same rule implemented twice differently, spec drift
   (code doing things the oracle does not mention).

Collect candidates privately, then apply the relevance, evidence,
pre-existing-code and duplicate checks in `references/loop-engineering.md`.
For accepted findings use `references/evidence-and-severity.md`. Record
rejected or deferred candidates briefly in the ledger when needed for
deduplication; do not present style suggestions as defects. Keep material
security uncertainties visible even when they cannot be reproduced.

### Phase 3 — Reproduction

For every finding proposed for a fix, attempt a failing test, script,
or request sequence in a safe environment. Record command or request,
input, exit status when applicable, and expected versus observed output.
A deterministic proof is acceptable when execution is unavailable: cite
the exact code/configuration and trace why the stated input must fail.
A scanner alert or missing constraint alone is not proof of exploitability.
If neither reproduction nor proof establishes the behavior, mark it
`UNVERIFIED`, state what was tried and what is missing, and do not fix it.

Where a reproduction becomes a test, keep it: it is the regression
test for the fix.

### Phase 4 — Fix loop

Only if the user requested or authorized edits, process each actionable
`CONFIRMED` finding in severity order. A confirmed low-impact issue is
not automatically worth changing; apply the materiality criteria in
`references/loop-engineering.md`. For review-only requests, report
findings without changing project files. For each authorized fix:

1. Keep a failing reproduction or regression test when practical. If
   only a deterministic proof is possible, record it and explain why a
   test could not be run.
2. Identify the root cause and inspect the original scope for other
   instances of the same defect class. Fix confirmed instances that can
   be safely addressed within the authorized scope; record other instances
   for follow-up. Do not broaden the change merely to eliminate warnings.
3. Re-run the reproduction and checks affected by this fix. At the end
   of a batch, re-run the applicable Phase 1 gate against the current
   state. State which checks ran and which could not run.
4. Log the attempt in the fix log (`templates/fix-loop-log.md`):
   finding id, change made, checks re-run, result.
5. If an attempt fails or causes a new failure in a previously passing
   check, revert that attempt without reverting the user's changes.
   Record the result and try another approach only if there is a concrete
   new cause to address. After 3 attempts, or when no safe next attempt
   is available, mark the finding `BLOCKED` and continue. If an attempt
   cannot be isolated and reverted safely, stop editing and report it.

Forbidden in this phase: refactoring unrelated code, upgrading
dependencies, renaming for style, or "while I'm here" changes.

### Phase 5 — Cross-check of the fixes

Compare the current snapshot with the last reviewed snapshot, including
working-tree and relevant untracked changes. Examine changed lines and
their callers, boundary and error paths for regressions; use surrounding
code as context, not as a fresh invitation to review the whole repository.
Match candidates against the ledger before reporting or fixing. Update an
existing finding rather than posting it again. For a genuinely new,
material regression in rounds 1–2, use Phases 3–4 and re-review the
result in the next round. In round 3, stop automatic fixing and report
the regression. Follow the stop rules and safety exceptions in
`references/loop-engineering.md`. A separate reviewer may be used only
when authorized and available; otherwise call this a self-review.

### Phase 6 — Verdict report

Produce the report with `templates/review-report.md`. It must contain:

1. **Verdict in plain language** (for a non-developer operator):
   one of `DEPLOYABLE` / `DEPLOYABLE WITH CONDITIONS` /
   `NOT DEPLOYABLE` / `BLOCKED`, plus 3–5 plain sentences: what was
   checked, what was found, what remains risky.
2. Gate table (command, result, exit code) — including `SKIPPED` rows.
3. Findings table: severity counts, and per finding — evidence,
   reproduction status, fix status.
4. `UNVERIFIED` and `BLOCKED` items, listed explicitly, never omitted.
5. Oracle status: whether the spec was real or inferred.
6. Rollback note: how to undo this change set (commit range / revert
   command) if it misbehaves after deploy.
7. Round count and stopping reason; changed-since-last-review scope;
   deduplicated findings, deferred pre-existing issues, material
   uncertainties, remaining risks and check results.
8. For tier `critical`: the standing statement that a human expert
   audit is still required.

## Mode shortcuts

- If the operator says "gate only": run Phase 1 and report the table.
- If the operator says "quick review": Phases 0, 1, and lenses 1–3,
  and state in the verdict that this was a partial review.
- If the operator asks to fix everything, fix confirmed findings within
  the requested scope. Report unverified findings and the evidence needed
  to verify them; do not claim they were fixed.
