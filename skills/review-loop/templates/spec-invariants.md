# SPEC / Invariants — <project or feature>

Write these in plain language before (or, for a review, reconstruct
them and mark the spec INFERRED). Each line is a testable promise.
Format: "WHEN <situation>, THE SYSTEM MUST / MUST NEVER <behavior>."

## Intended behavior

- WHEN a user signs up with an email that already exists, THE SYSTEM
  MUST reject it and MUST NEVER create a second account.
- WHEN …

## Money / data invariants (always / never)

- A user's balance MUST NEVER go below 0.
- Stock MUST NEVER go below 0, even under simultaneous orders.
- An order total MUST always equal the sum of its items.
- A payment MUST be recorded exactly once per successful charge,
  even if the request or webhook is delivered twice.
- A user MUST NEVER read or modify another user's data.
- WHEN any step of order creation fails, THE SYSTEM MUST roll back
  all of its writes (order, stock, points) — all or nothing.
- A write that returned success MUST survive a server restart.

## Permissions

- <role> MAY … / MUST NEVER …

## Out of scope (the system must not do these)

- …
