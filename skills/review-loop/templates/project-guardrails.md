# Project Guardrails (paste into AGENTS.md / CLAUDE.md)

These standing rules apply to every change in this project.

## Verification

- Before claiming any work is done, run the project's test, type,
  lint, and build checks and report their real results. A check that
  was not run is reported as not run.
- Never edit, delete, skip, or relax a test, assertion, lint rule, or
  type setting to make checks pass.
- For a bug fix, run a failing reproduction before the fix and again
  afterward when practical. Otherwise record a deterministic proof and
  explain why a reproduction could not be run.

## Data safety

- When an invariant requires multiple database writes to succeed or
  fail together, use a transaction or equivalent atomic mechanism.
- Business invariants (uniqueness, non-negative balance/stock,
  referential integrity) are enforced by database constraints, not
  only by application code.
- Prevent duplicate payment and other non-idempotent effects on retry;
  use an idempotency key or another mechanism suited to the operation.
- Never hardcode secrets. Never log secrets or personal data.

## Authorization

- Every access to user-owned data is authorized on the server.
  UI hiding is not authorization.
- Database row-level policies, where supported, stay enabled.

## Change discipline

- Small changes. One concern per change. No unrelated refactors,
  dependency upgrades, or renames inside a fix.
- New dependencies must exist in the official registry, be pinned,
  and be justified in the change description.
- If a requested change conflicts with these rules, stop and say so
  instead of silently breaking the rule.
