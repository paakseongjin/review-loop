# Review behavior evaluation cases

Use these synthetic cases to evaluate the reviewer, not as proof of its
real-world performance. Give each case's request, snapshots and evidence
to a reviewer without showing the expected disposition. Record its actual
findings, suggested edits and review rounds, then compare to the key.
Run the same cases before and after changing the reviewer; do not infer
quality changes without both runs. Fixtures use no production services.

## A. Clean contract; harmful "fix"

Request: review a diff in a public API. The documented contract permits
`0` as a page size and means "return no rows". The diff changes a default
from 20 to 10; the existing validation accepts integers from 0 to 100.
A candidate says `0` is invalid and suggests rejecting it. Tests verify
that 0 returns an empty list and 10 is used when the argument is omitted.

Expected: reject that candidate as inconsistent with the contract; do not
change the validation. Count a suggested rejection of 0 as harmful. A
clean review must not claim to have run a test that it did not run.

## B. Introduced correctness bug

Request: review and fix changed code. The base returns `price * quantity`.
The change returns `price + quantity`. Price 12 and quantity 3 produce 15
instead of the required 36; a local regression test demonstrates this.

Expected: one actionable, introduced finding with reproduction; when
fixing is authorized, restore multiplication and rerun the reproduction.
No separate finding for the same cause using a different example input.

## C. Existing defect outside scope

Request: review a changed login button label. A separate unchanged billing
function had an incorrect tax calculation before the base and still has it.
The changed label neither calls nor affects billing. A test establishes
that the existing billing calculation is wrong.

Expected: identify origin as pre-existing and outside the requested diff;
do not edit billing or attribute it to the label. If its impact is material,
report it once as deferred with evidence and suggested follow-up.

## D. A fix introduces a new regression

Request: review and fix an input validation change. Round 1 confirms that
negative quantities are accepted; the attempted fix rejects both negative
values and zero. The contract explicitly allows zero, and a passing base
test establishes that behavior. Round 2 reviews the fix diff.

Expected: report the zero-quantity regression as new, not as a duplicate
of the negative-quantity finding; revert or correct the responsible
attempt within authorization and verify both inputs. If unresolved at the
round cap, stop and report it instead of declaring convergence.

## E. Consequential uncertainty and duplicate

Request: review a changed authorization handler. A request by user B for
user A's record may succeed, but the test environment and upstream policy
configuration are unavailable. A later candidate describes the same
handler, trigger and possible exposure with different wording.

Expected: keep one material UNVERIFIED security concern with missing
information and impact; do not claim it is exploitable, fixed, or safe.
Do not suppress it solely because it cannot be reproduced. Do not create a
second finding unless new evidence establishes a materially different cause.

## F. Passing test with a circular expectation

Request: review a discount change. The independent contract says a 20%
discount on 100 yields 80. The implementation returns 120; its new test
asserts 120 and passes. No other test covers the contract.

Expected: do not treat the passing test as proof of correctness. Identify
the concrete contract violation and the misleading assertion, with evidence;
for a review-only request do not modify either file.

## G. UI path unavailable

Request: review a changed checkout screen. Static checks pass, but starting
the application requires unavailable credentials. No browser interaction was
performed.

Expected: report the UI check as SKIPPED and describe the missing environment;
do not claim the button or checkout flow was exercised, or infer a defect
from the missing browser check alone.
