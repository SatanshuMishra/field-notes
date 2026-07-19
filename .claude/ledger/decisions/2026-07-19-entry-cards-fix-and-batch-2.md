# Batch 2 composition + entry-cards fix disposition

Date: 2026-07-19
Status: accepted

## Decision

Batch 2 = **capture-core + entry-cards + reminders** (3 MSPs), user-approved at 18/31 merged.
entry-cards is **fixed and included**, not deferred.

## Context

At 18/31, four MSPs are dispatchable: capture-core, entry-cards, reminders, garden-screen.
entry-cards had previously halted the engine with an add/add conflict on
`test/features/entry_cards/support/entry_cards_harness.dart`.

## Rationale

- capture-core gates the three recorders plus today-screen and day-detail; entry-cards gates 5
  remaining MSPs; reminders gates settings-screen. All three are on the critical path.
- garden-screen deferred to batch 3: it gates only the terminal shell-nav-integration, so
  deferring costs no schedule, and its 2026-07-15 artifacts were produced while the safety
  classifier was down (unverified). Batch 3 gets a clean fresh plan.
- Three units (two heavy, one light) is the prudent load for one ~2h window; batch 1's four
  lighter units filled its window.

## entry-cards root cause and fix

Root cause: the task graph's ownership was correct (only Task 2 owns the harness), but Task 4
(note-body) embedded test code importing `../support/entry_cards_harness.dart`. Task 4 runs in
wave 1 without that file, so its worker authored an out-of-scope 14-line copy (81173a9) against
Task 2's real 137-line version (78474d2) -> deterministic add/add at integration merge -> park.

Fix (two edits to `.mitosis/entry-cards.plan.md`, applied this session):
1. Task 4's test is now self-contained — the harness import is gone, replaced by a local
   `noteBodyHarness`. Verified: zero `entry_cards_harness` references remain in Task 4.
2. A Global Constraints bullet declares Task 2 the sole owner of the harness and requires any
   task missing an imported support file to report BLOCKED rather than author its own copy.

Rejected alternative: keep excluding entry-cards. It gates 5 MSPs; every deferred round delays
the whole tail, and the resume path (Plan + plan-review skipped) makes the retry cheap.

## Resume mechanics this depends on

The pristine backup's entry-cards `execute` park delta is RETAINED by the trim (verified:
`retained deltas: [('entry-cards', 'park')]`). On resume the engine skips Plan and plan-review
but re-runs Parallelize, regenerating the task graph from the EDITED plan. Therefore:
keep the park delta, keep `.mitosis/entry-cards.plan.md`, and delete the stale derived graph
artifacts (done) so nothing shortcuts re-derivation.
