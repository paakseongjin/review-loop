# Review Report — feature/order-api — 2026-11-11 (EXAMPLE — fictional)

## Verdict: NOT DEPLOYABLE

Plain-language summary (for the operator, no jargon):
- What was checked: the new order-creation API (6 files). Tests, type
  check, and secret scan were actually run. The order flow was also
  tested with two simultaneous orders and with a payment failure.
- What was found: if payment succeeds and the next step fails, the
  customer is charged but no order exists. Also, two people can buy
  the last item at the same time.
- What remains risky: until the two problems above are fixed and
  re-verified, this must not go live. Nothing else blocked deployment.

Risk tier: public
Oracle: REAL (source: SPEC.md, invariants 1–7)
Scope: base main → head feature/order-api, 6 files, 212 changed lines

## Mechanical gate

| Check | Result | Exit | Command |
|---|---|---|---|
| tests | PASS | 0 | `npm test` (41 passed) |
| types | PASS | 0 | `npx tsc --noEmit` |
| lint | PASS | 0 | `npm run lint` |
| build | PASS | 0 | `npm run build` |
| secrets | PASS | 0 | `gitleaks detect --no-banner` |
| deps audit | PASS | 0 | `npm audit --audit-level=high` |
| SAST | SKIPPED | - | semgrep not installed |

Pre-existing failures on base ref: none

## Findings

Counts: Critical 2 · Major 0 · Minor 1 · Note 0
UNVERIFIED: 1 · BLOCKED: 0

| ID | Lens | Severity | Status | Location | One-line summary |
|---|---|---|---|---|---|
| F-01 | 2 ACID | Critical | CONFIRMED | src/orders/create.ts:84-121 | Payment charged, order rolled back on later failure |
| F-02 | 2/3 ACID·Concurrency | Critical | CONFIRMED | src/orders/create.ts:47-63 | Last item can be sold twice under simultaneous orders |
| F-03 | 7 Architecture | Minor | CONFIRMED | src/orders/price.ts | Price calculation duplicated with different rounding |
| F-04 | 1 Security | — | UNVERIFIED | src/orders/list.ts | Admin export endpoint: could not verify role check without a seeded admin account |

### F-01 detail

Scenario: Payment succeeds, then the points-ledger insert throws
(simulated by making the ledger reject the insert).
Expected: Database writes roll back and the external charge is
prevented or compensated through an idempotent workflow.
Actual: Order and stock were already committed separately; the user
was charged with no order record.
Evidence: repro/F-01.sh output, exit code 1 (charge row exists,
order row missing).

## Rollback

To undo this change set: `git revert a1b2c3d..e4f5g6h`.
Data a code rollback does NOT undo: none identified (not deployed).

## Standing notes

- SAST was SKIPPED (tool not installed). It is not a pass.
- F-04 stays UNVERIFIED: reported, not fixed, needs a seeded admin
  account to test.
