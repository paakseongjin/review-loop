# Review loop: selection, state, and stopping

Read this reference for every full review or review-and-fix request. The
limits below are this skill's defaults, informed by the Claude Code
team's published process; they are not a claim about its exact internals.

## 1. Select useful findings

For each candidate, answer all of these before opening a finding:

1. **Scope and origin:** Is this in the requested changes? Compare the
   base with the initial snapshot where available. Classify it as
   `INTRODUCED`, `PRE_EXISTING`, `FIX_REGRESSION`, or `UNKNOWN`. A line
   number change alone does not establish origin. If base is unavailable,
   use `UNKNOWN` and explain. A whole-project audit can include old code.
2. **Concrete consequence:** Identify a reachable input or state, expected
   behavior, actual behavior, and the affected user, data, operation or
   explicit requirement. Read surrounding guards and callers first.
3. **Evidence:** Run a reproduction or give a deterministic trace; label
   anything else `UNVERIFIED`. Record commands and output without secrets.
4. **Materiality:** Fix/report as a defect when the consequence affects
   correctness, security, privacy, data integrity, availability, cost, or
   an explicit requirement in a plausible operating scenario. Do not
   elevate a hypothetical scenario that contradicts the actual trust
   boundary or supported input contract. Do not invent a numeric score or
   dismiss high-impact risks merely because they are difficult to reproduce.
5. **Disposition:** `ACTIONABLE`, `DEFERRED`, `REJECTED`, or `UNVERIFIED`.
   Style, naming, generic cleanup, hypothetical extra checks and preference
   for a pattern are `REJECTED` unless explicitly requested or required.
   A relevant but pre-existing issue outside the requested scope is
   `DEFERRED`, not attributed to the change or silently fixed. Report it
   concisely if material; surface urgent security/data-loss risks even if
   pre-existing, and do not call the system safe. A material uncertainty
   remains visible as `UNVERIFIED` with its impact and missing evidence.

A finding may be both `PRE_EXISTING` and `ACTIONABLE` in a whole-project
review. If the change newly exposes or worsens it, explain that causal
link and classify the new exposure as introduced. Do not use age or
pre-existing status to ignore an actual regression or urgent risk.

## 2. Maintain one ledger for the invocation

Use `templates/fix-loop-log.md` as an in-memory table or place it in the
requested report; do not create or commit a file just to store the ledger.
Before each review round record the snapshot and compare with the previous
snapshot. A snapshot covers HEAD, staged and unstaged diff, plus the
contents of relevant untracked files. For non-Git work, retain the actual
reviewed file contents or an equivalent reliable comparison. If a snapshot
cannot be compared, mark its scope unknown; do not claim a diff-only pass.

Give each finding one stable ID. Match by underlying cause, invariant,
trigger and impact, not line number or wording alone; moved lines and
rewritten descriptions are not new findings. Related instances of the
same root cause can share one finding with a list of locations; keep
separate IDs when trigger, cause, impact or fix is materially different.
Track origin, status, evidence, disposition, fix attempts and resolution.
When a previously rejected or resolved finding comes back, do not reopen
it unless new evidence or a changed implementation invalidates the prior
reason. Update the existing record with that evidence; never silently
suppress a real regression because it resembles an older finding.

## 3. Round procedure

- **Round 1:** review the full requested scope, relevant project guidance,
  and necessary dependencies. Record findings and deferred risks.
- **Rounds 2–3:** after an authorized fix batch, compare against the last
  reviewed snapshot and examine only changed code plus callers and guards
  needed to test behavior. Re-run the reproductions and relevant checks.
  Record newly introduced regressions separately from old findings.
- Search the original authorized scope for confirmed instances of an
  actionable defect class, and fix only instances within that scope when
  fixes are authorized. Record locations outside scope for follow-up.
- Within a round, update the ledger as fixes are made. Do not restart a
  full review after each fix. A failed fix may be retried up to 3 times
  per finding, following Phase 4; the round limit is separate.

Stop early once all actionable in-scope findings are fixed or explicitly
resolved, the fix diff has been checked, applicable checks have been run,
and no new actionable regression was found in the latest review round.
An unresolved failed/skipped required check or material unverified risk
may end the loop, but must constrain the verdict and be stated. Review-only
requests stop after the initial review and report, without modifying code.

In round 3, do not start another automatic fix; report each unresolved
finding, attempted fixes, evidence, checks and recommended next action.
Do not mark an unresolved issue fixed, and do not suppress a newly found
critical issue. If continuing would expose data, incur irreversible side
effects, or require broader authorization, stop that action immediately.
A user may explicitly request another review cycle; carry the prior ledger
and unresolved items forward instead of re-posting them as new. The cap
is an engineering guardrail, not proof that the code is safe.

## 4. Improve the reviewer with real feedback

When feedback or actual incidents are available, record for each finding
whether it was fixed, rejected as incorrect, accepted as intentional, or
judged immaterial, with a reason and the relevant snapshot. Treat feedback
as a signal, not proof of correctness. Capture a missed incident as a
reproducible regression case and preserve the expected behavior. Include
known-clean examples that should produce no material findings, including
one where a proposed fix would break intended behavior. Only use fixtures
and data the user has authorized; remove secrets and personal data.

For a small starter set, use `references/evaluation-cases.md`; supplement
it with real incidents and clean cases when available. When evaluating
changes to review instructions, run the same cases before and after. Report separately: known defects found / total known defects,
false or immaterial findings / total findings, harmful suggested fixes on
clean cases, and review rounds per case. Label small samples and unknown
outcomes; do not claim these metrics prove safety or infer a causal effect
from one case. No telemetry or external upload is implied by this process.

Source: Claude Code team, “How the Claude Code team does code review”
(2026-10-15), https://claude.dev/blog/solving-code-review-at-anthropic/ .
