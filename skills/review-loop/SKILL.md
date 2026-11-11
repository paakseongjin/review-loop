---
name: review-loop
description: Evidence-based code review loop for AI-generated code. Use when reviewing, auditing, or fixing AI-written code before merge or deploy, when the user asks whether AI-generated code is safe, well-structured, or production-ready, or when a fix must be verified rather than trusted. Runs a mechanical gate first (tests, types, lint, secrets, dependencies), then isolated lens reviews (security, ACID/transactions, concurrency/idempotency, data integrity, dependencies, architecture), requires reproduction before any fix, and ends with a plain-language verdict. Never claims a pass it did not run.
argument-hint: "[branch, PR, commit range, or path to review] [risk tier: prototype|internal|public|critical]"
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
2. **No reproduction, no fix.** A finding without a concrete failing
   scenario (input, steps, expected vs. actual) is a hypothesis.
   Label it `UNVERIFIED` and do not modify code for it.
3. **Never weaken tests to go green.** Do not edit, delete, skip, or
   relax a test, assertion, lint rule, or type setting in order to make
   a check pass. If a test itself is wrong, stop and report why, with
   evidence, and let the operator decide.
4. **No praise, no generalities.** Every finding states: file and line,
   severity, the failing scenario, expected vs. actual behavior, and
   the evidence. Findings that cannot meet this format are dropped or
   marked `UNVERIFIED`.
5. **Fix one finding at a time.** Minimal diff per fix. After each fix,
   re-run the mechanical gate (Phase 1) plus the reproduction for that
   finding. A fix that breaks a previously passing check is reverted.
6. **Secrets are never printed.** If a secret scan finds a credential,
   report only its type and location, never its value.
7. **Small scope.** Review the requested diff/scope only. If the diff
   exceeds ~400 changed lines, warn the operator that detection quality
   drops sharply and propose splitting before reviewing.
8. **Loop limits.** At most 3 fix attempts per finding and 2 full loop
   passes. If a finding is still failing after that, stop, mark it
   `BLOCKED`, and report what was tried. Never loop indefinitely and
   never silently drop a blocked finding.

## Inputs

- `$ARGUMENTS`: scope (branch / PR / commit range / paths) and optional
  risk tier. If scope is missing, default to the current uncommitted
  diff plus the last commit, and say so.
- Risk tier (default `public` if data or other users are involved,
  otherwise ask once):
  - `prototype` — no real users, no real data. Run Phases 0–6,
    limiting Phase 2 to lenses 1 and 6.
  - `internal` — team tool, no payment/personal data. Phases 1–5.
  - `public` — public SaaS, user accounts, personal data. All phases.
  - `critical` — payments, health, destructive data operations.
    All phases, plus: state in the verdict that a human expert audit
    is still required before launch. Your verdict alone is not enough.

## The loop

### Phase 0 — Freeze scope and establish the oracle

1. Record the exact scope: base ref, head ref, changed file list,
   changed line count (`git diff --stat`).
2. Find the oracle — what the code is *supposed* to do:
   - Look for `SPEC.md`, `specs/`, `AGENTS.md`, `CLAUDE.md`, PR
     description, acceptance criteria, issue text.
   - If none exists, write an *inferred spec* (5–15 plain statements of
     intended behavior plus invariants) from the diff and mark the whole
     review `ORACLE: INFERRED`. Use `templates/spec-invariants.md`.
   - Always extract invariants of the form "X must always / must never
     happen", including ACID invariants for anything that writes data
     (see `references/lenses.md`, Lens 2).
3. Output the scope and oracle summary before reviewing anything.

### Phase 1 — Mechanical gate (deterministic checks first)

Run the gate before reading code for review. Prefer the bundled script:

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
contact external services. Inspect them first and use an isolated or
appropriate environment. Its exit code 0 means only that no executed
check failed; skipped or undetected checks are not passes. Suppressed
failure output may contain secrets: inspect it separately and redact it.

Record each check as `PASS / FAIL / SKIPPED` with the command and exit
code in a gate table. A missing tool is `SKIPPED`, with the install
hint noted — it is not a pass. If the test suite itself fails on the
*base* ref, record that: pre-existing failures are reported, not
quietly absorbed into the review.

**Gate rule:** if the gate is red, lens review still proceeds, but the
final verdict can never be "deployable" until the gate is green.

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

Each lens outputs findings in the evidence format of
`references/evidence-and-severity.md`. Findings are one of:
`CONFIRMED` (reproduced or mechanically proven), `UNVERIFIED`
(plausible, not yet reproduced), or dropped.

### Phase 3 — Reproduction

For every `Critical` or `Major` finding, produce a reproduction before
any fix: a failing test, a script, or an exact request sequence.
Run it and capture the actual output. If you cannot reproduce it after
a genuine attempt, downgrade it to `UNVERIFIED`, keep it in the
report, and do not fix it in this loop.

Where a reproduction becomes a test, keep it: it is the regression
test for the fix.

### Phase 4 — Fix loop

For each `CONFIRMED` finding, in severity order:

1. Write or keep the failing reproduction/regression test.
2. Apply the smallest fix that addresses the root cause.
3. Re-run: the reproduction, the full mechanical gate, and the lens
   that produced the finding, on the new diff only.
4. Log the attempt in the fix log (`templates/fix-loop-log.md`):
   finding id, change made, checks re-run, result.
5. If the fix fails 3 times or breaks another check, revert it, mark
   the finding `BLOCKED`, and continue with the next finding.

Forbidden in this phase: refactoring unrelated code, upgrading
dependencies, renaming for style, or "while I'm here" changes.

### Phase 5 — Cross-check of the fixes

Re-review only the fix diffs, in a fresh pass (new context or a
different model/agent where the environment supports it), asking one
question: *did the fixes introduce a new defect or quietly change
behavior outside the finding's scope?* Compare behavior against the
Phase 0 oracle. Any new issue re-enters Phase 3.

Note the limit honestly in the report: cross-model checks reduce, but
do not eliminate, shared blind spots. That is why Phases 1 and 3 are
mechanical.

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
7. For tier `critical`: the standing statement that a human expert
   audit is still required.

## Mode shortcuts

- If the operator says "gate only": run Phase 1 and report the table.
- If the operator says "quick review": Phases 0, 1, and lenses 1–3,
  and state in the verdict that this was a partial review.
- If the operator asks to "just fix everything": refuse the shortcut
  politely and run the loop; unverified findings are reported, not
  fixed. This rule exists because fixing unverified findings is how
  AI review loops manufacture new bugs.
