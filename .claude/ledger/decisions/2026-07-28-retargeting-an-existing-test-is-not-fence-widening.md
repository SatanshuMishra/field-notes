Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
C1 and C6 independently stopped and reported rather than shipping red, on the same shape. C1: the MSP mandates replacing `Icons.local_fire_department` with the procedural `FlameIcon`, and `test/features/streak/streak_card_test.dart:21` asserts `find.byIcon(Icons.local_fire_department)`. C6: the MSP mandates replacing the single empty-state sentence, and `test/features/today/today_entry_feed_test.dart:123` hardcodes the old literal. Neither test file is in its MSP's row of the Cluster C slice's §0 fence table, while C2's row does list `test/features/today/today_date_test.dart` — so both omissions read as deliberate. In each case the two facts cannot both be honoured: the mandated change necessarily reds that assertion.

## Decision
When an MSP changes a public rendering, it MAY retarget the existing assertions that pin that rendering, in the test files that already cover it, without those files appearing in its fence row. This is maintenance of an existing receipt, not a new test, so §5.2's "a styling change warrants no new test" does not bar it. The edit is bounded to retargeting: no restructuring, no weakening or deleting of sibling assertions, no test renamed.

The test on the retarget is that it pins the SAME BEHAVIOUR through the changed surface, not that the assertion count is preserved. C6 surfaced the case: one copy string became two (a headline plus a sub-line), so the faithful retarget asserts both. Splitting one assertion to track one rendering that split is retargeting; asserting a behaviour the old test never covered is not.

## Consequences
- A fence row omitting a test file is a spec defect when the MSP's own target values force that test red — not a reserved product decision. The agent still stops and reports; the orchestrator rules and records it here.
- The green-branch invariant is what forces this: a red branch is not shippable, so "leave it failing" was never an available option.
- Expected to recur on C4 (existing tests assert the type-name eyebrow it replaces) and possibly C5 and C7. C4's dispatch already carried this authorization inline.
- HARD CARVE-OUT, unchanged: `test/features/entry_cards/playback/**` and the eight files of the 106-case playback suite are NEVER edited under any circumstances (N24). A red there is fixed in the implementation or the MSP stops. This decision grants no reach into them.
- The amendment is per-file and per-report. An agent that finds a second out-of-fence test failing stops again rather than generalizing.
- Rejected: adding the test files to the fence table pre-emptively. The stop-and-report round trip is cheap and it surfaced a real spec defect that would otherwise have been silently absorbed.
