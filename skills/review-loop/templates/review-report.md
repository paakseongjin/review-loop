# Review Report — <scope> — <YYYY-MM-DD>

## Verdict: DEPLOYABLE | DEPLOYABLE WITH CONDITIONS | NOT DEPLOYABLE | BLOCKED

Plain-language summary (for the operator, no jargon):
- What was checked:
- What was found:
- What remains risky:

Risk tier: prototype | internal | public | critical
Oracle: REAL (source: <file/PR>) | INFERRED (spec was reconstructed, not confirmed)
Scope: base <ref> → head <ref>, <N> files, <M> changed lines

## Mechanical gate

| Check | Result (PASS/FAIL/SKIPPED) | Exit | Command |
|---|---|---|---|
| tests | | | |
| types | | | |
| lint | | | |
| build | | | |
| secrets | | | |
| deps audit | | | |
| SAST | | | |

Pre-existing failures on base ref: none | <list>

Review rounds: <count> / 3
Stop reason: <converged / review only / blocked / round cap>
Last re-review scope and snapshot: <details>
Deferred pre-existing risks: <none / details>

## Findings

Counts: Critical <n> · Major <n> · Minor <n> · Note <n>
UNVERIFIED: <n> · BLOCKED: <n>

| ID | Lens | Severity | Status | Location | One-line summary |
|---|---|---|---|---|---|
| F-01 | | | | | |

### Finding details

<one block per finding, in the format of references/evidence-and-severity.md>

## Unverified and blocked (never omitted)

- <UNVERIFIED items with what would be needed to verify them>
- <BLOCKED items with the attempts log reference>

## Fix log reference

<path or summary of templates/fix-loop-log.md entries>

## Rollback

To undo this change set: `git revert <range>` / redeploy <previous release>.
Data touched by this change that a code rollback does NOT undo: <list or "none identified">

## Standing notes

- <critical tier only> A human expert audit is still required before launch.
- Checks marked SKIPPED did not run. They are not passes.
