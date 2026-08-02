# Session 2026-08-01-05 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. Brief presented against verified
git state (`origin/main` `93de164`, 24 of 39 MSPs landed). A TENTH ledger drift surfaced and
was fixed in place: the Cluster E recon's corrected anchor for `resolveGardenMotion` dropped
a path segment — the real path is `lib/features/garden/model/garden_motion.dart:5`, and
`meadow_painter.dart` is at `lib/features/garden/paint/meadow_painter.dart`. PROJECT.md and
the thread's Open Risks both corrected.

The user approved, settled the meadow-stroke open question as recommended, and directed a
dedicated small dynamic workflow to fully implement and ship Cluster F (mood picker, F1-F4)
as a native GitHub stack.

## Decisions locked
- decisions/2026-08-01-meadow-keeps-the-shared-stroke.md — E1's shared `_stroke(d)` change is
  accepted as shipped; no spec amendment, no second stroke path. Rules on the mechanism, not
  the pixels; the section 5.4 visual pass is still owed.

## Demoted from PROJECT.md (cap enforcement)

PROJECT.md hit its 80-line cap when the meadow decision's index line was added. One SPENT
line was demoted. The file remains on disk, unchanged, and is still valid history — it is
simply no longer load-bearing, because mitosis is excluded for the whole remaining spec
(decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md) and every
mechanic this record governs is a mitosis dispatch mechanic. Its live residue — land the
slice on base before dispatch, and re-verify every citation per section 7 — is carried by
decisions/2026-07-27-cluster-a-scoped-spec.md and the Pointers section. The displaced text:

- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec AND its citation
  source on the base branch before dispatching mitosis (worktrees see only base; spec §7
  makes implementers re-verify against `docs/prototype/`), then run Cluster A (A1-A5) ALONE
  and review before re-dispatching B-H. A single 39-MSP run was rejected: no inspection
  point, ~15x chat tokens, 39 PRs to retitle. `sourcePrefix` is `msp` with NO trailing slash
  — the engine appends it (`mitosis.js:1293`) and `msp/` failed run 1 with the invalid ref
  `msp//...`
