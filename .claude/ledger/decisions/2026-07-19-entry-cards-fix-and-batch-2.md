Status: accepted
Date: 2026-07-19
Thread: journal-app-design

## Context
At 18/31 merged, four MSPs are dispatchable: capture-core, entry-cards, reminders, garden-screen.
entry-cards had parked the engine with an add/add conflict on the shared test harness
`test/features/entry_cards/support/entry_cards_harness.dart`.

## Decision
Batch 2 = capture-core + entry-cards + reminders. entry-cards is FIXED AND INCLUDED, not deferred;
garden-screen moves to batch 3.

## Consequences
- Root cause, the two applied plan edits, and verification: sessions/2026-07-19-02-journal-app-design.md.
- Resume depends on the retained entry-cards `execute` park delta: the engine skips Plan but re-runs
  Parallelize, regenerating the graph from the EDITED plan. Never delete `.mitosis/entry-cards.plan.md`;
  if the unit enters a fresh Plan stage, kill the run before it overwrites the fix.
- garden-screen deferred at zero schedule cost (it gates only shell-nav-integration) and its
  2026-07-15 artifacts are classifier-unverified, so batch 3 re-plans it cleanly.
- Rejected: keep excluding entry-cards — it gates 5 MSPs, so every deferred round delays the tail.
