---
thread: journal-app-design
status: paused
updated: 2026-07-16
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Fresh session (CLEAN context) -> relaunch mitosis human-gated (KEEP run.json; contract in sessions/2026-07-11-03) against origin/main 66a12a46. Expect the 7 session-limit MSPs to build + publish; expect entry-cards to re-park on its deterministic add/add conflict. VERIFY published PRs via `gh pr list --state open`, NOT result.shipped. Merge each green PR from the main thread under explicit per-batch consent. Do NOT resume any prior run id.
branch: main
---

## Status
PAUSED at 14/31 SHIPPED (origin/main 66a12a46; local main b359ddc, reconciled — contains core-providers). Session 2026-07-16-01 merged PR #14 core-providers (13 -> 14/31), then burned three mitosis launches for ZERO new PRs: wf_f28d7d12-1cd died in a ~3h idle gap (process exit), wf_bfb12095-952 ran ~2h and hit the account session limit (parking all 17 remaining MSPs, 0 published), wf_1245a178-eaf was launched at ~83% context and stopped cleanly. A fresh usage window (reset 11:30pm MDT Jul 15) was UNUSED at handoff. All three runs dead — never resume any run id.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main. Remaining (Option B) = BUILD the 17 downstream dependents via human-gated mitosis relaunches (agents publish green PRs; main thread merges), layer by layer across usage windows.

## Next Step
Fresh session, CLEAN context -> relaunch mitosis human-gated -> verify via `gh pr list --state open` -> merge green PRs under per-batch consent -> repeat until 31/31, then Phase 8. Fix entry-cards harness ownership before the screens layer.

## Open Risks
- **entry-cards is STRUCTURALLY broken (new 2026-07-16):** add/add conflict on `test/features/entry_cards/support/entry_cards_harness.dart`, created independently by BOTH `task-media-resolver-harness` (de79f13, 137-line version) and `task-note-body`. A task-graph ownership defect — DETERMINISTIC; re-parks every relaunch until the plan gives that file exactly one owner. Blocks 5 screen MSPs (today-screen, day-detail, calendar-screen, search-screen, shell-nav-integration).
- The mitosis `result.shipped` array is MISLEADING — it lists only done-oracle fast-skips (already-merged), NOT PRs the run just published. Always verify via `gh pr list --state open`. Re-confirmed 2026-07-16: all 14 entries were fast-skips; 0 published.
- SESSION-LIMIT bound: a full run exhausts a usage window (~2h). Multi-window relaunch-to-resume; the done-oracle skips the merged, so each relaunch does less. Park checkpoints may FAIL to persist when the limit hits (written=null), so parked MSPs rebuild fresh from plan — idempotent, but no partial reuse.
- Launch each relaunch from a FRESH (not near-full) context — runs die when launched near-full. PROVEN AGAIN 2026-07-16: a run launched at ~83% context had to be stopped immediately; an earlier run died when its launching process exited.
- Human-gated agents publish-then-stop (PROVEN); the main thread does every merge, and the classifier requires EXPLICIT per-batch merge consent even for the main thread.
- The safety classifier (opus-4-8) was UNAVAILABLE when reviewing `parallelize:garden-screen` and `sec:streak-service` on wf_bfb12095-952 — that work is unverified; re-review if reused.
- Leftover local msp/* branches (~90) and worktrees (~16) are safe (branch-prep does observe-then-converge). run.json is stale-but-self-healing via the gh/git done-oracle.
- Local launch blocked until Phase 8 (full Xcode+CocoaPods + Android SDK not installed). Binary assets human-provided + committed.

## Key Decisions
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main onto origin/main before EVERY relaunch (engine cuts worktrees from the bare LOCAL `main` ref)
- decisions/2026-07-12-direct-ship-built-msps.md — direct main-thread ship of already-built MSPs (Option A); engine builds unbuilt dependents (Option B)
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous structurally blocked; human-gated + main-thread merge (governs Option B builds)
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch/keep-run.json semantics
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp"
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse; done-oracle skips the 14 merged)
- .mitosis/entry-cards.plan.md — the plan whose task graph carries the harness-ownership defect
- sessions/2026-07-16-01-journal-app-design.md — latest (merged #14; 3 dead runs; entry-cards defect; full parked breakdown)
- sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; mergePolicy "human-gated")
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-16-01-journal-app-design.md
- sessions/2026-07-14-02-journal-app-design.md
- sessions/2026-07-14-01-journal-app-design.md
- sessions/2026-07-12-03-journal-app-design.md
