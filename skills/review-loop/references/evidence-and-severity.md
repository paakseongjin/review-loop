# Evidence Format and Severity

## Finding format (required)

```
ID: F-03
Lens: 2 (ACID — Atomicity)
Severity: Critical
Status: CONFIRMED | UNVERIFIED | BLOCKED | FIXED
Location: src/orders/create.ts:84-121
Scenario: Payment succeeds, then the points-ledger insert throws
  (simulate by making the ledger table reject the insert).
Expected: The database writes roll back, and the external charge is
  prevented or compensated through a reliable, idempotent workflow.
Actual: Order and stock deduction are already committed; the user is
  charged with no order record.
Evidence: reproduction script repro/F-03.sh run output, exit code 1
  (attach or quote the relevant lines).
Fix: (after Phase 4) made database writes atomic and added an
  idempotent compensation workflow for the external charge;
  regression test tests/orders/atomicity.test.ts fails before the
  fix and passes after. Gate re-run: all PASS.
```

A finding missing Location, Scenario, or Expected vs. Actual is
automatically UNVERIFIED.

## Severity

- **Critical** — exploitable security hole; data loss or corruption;
  duplicate/lost money movement; other users' data reachable;
  acknowledged writes can disappear. Blocks deploy.
- **Major** — a realistic user flow breaks; an invariant (Lens 2–4)
  can be violated without an attacker; a fix regression is likely.
  Blocks deploy on `public` and `critical` tiers.
- **Minor** — a concrete correctness issue with limited impact and a
  practical workaround. Do not turn style preferences or speculative
  maintenance concerns into findings; see `loop-engineering.md`.
- **Note** — observation without a failing scenario. Keep few.

## Status rules

- `CONFIRMED` requires reproduction output or a deterministic trace
  establishing the scenario. A scanner hit or missing constraint alone
  is a lead, not proof that the stated consequence can occur.
- `UNVERIFIED` is honest, not shameful. It means: plausible, worth a
  human look, not safe to auto-fix.
- `FIXED` requires: the reproduction now passes, or the deterministic
  proof is no longer valid after the fix; applicable checks were rerun;
  and the fix diff was re-checked (Phase 5). Report failed or skipped
  checks separately; they still constrain the verdict.
- `BLOCKED` requires a log of what was tried (see fix-loop-log).

## Verdict mapping

- Any confirmed Critical not FIXED → `NOT DEPLOYABLE`.
- Any confirmed Major not FIXED on `public`/`critical` → `NOT DEPLOYABLE`;
  on `prototype`/`internal` → `DEPLOYABLE WITH CONDITIONS` at best.
- Gate red or incomplete → never unconditional `DEPLOYABLE`.
  Use `BLOCKED` when required evidence cannot be obtained and no
  meaningful verdict is possible; otherwise state the conditions.
- An UNVERIFIED Critical or Major is not proof of a defect; describe
  the potential impact, missing evidence, and whether the uncertainty
  prevents a verdict. Do not count it as confirmed.
- Oracle INFERRED → at best `DEPLOYABLE WITH CONDITIONS`, and the
  verdict says the review checked the code against an inferred spec,
  not against confirmed intent.
- Everything else → the verdict still lists accepted Minor findings,
  material UNVERIFIED concerns, and SKIPPED checks. A clean verdict with hidden caveats is a failure of
  this skill, not a success.
