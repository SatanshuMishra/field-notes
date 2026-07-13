---
thread: journal-app-design
status: paused
updated: 2026-07-12
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Fresh session -> relaunch mitosis (mergePolicy "human-gated", KEEP run.json) against origin/main bb8cc4d to BUILD the remaining layer-1 (feedback-motion-kit [just ship], settings-fields-kit, journal-repository, media-store, settings-repository) + downstream; merge each green PR from main thread (re-confirm merge consent to clear the classifier). Do NOT resume wf_dcb8b488-bb9 or wf_a1015521-c4c.
branch: main
---

## Status
8/31 SHIPPED (origin/main bb8cc4d). This session shipped app-shell (#8) — a HUMAN-GATED mitosis ship agent published the PR (push + gh pr create, stopped before merge; first proof the human-gated publish path works), main thread squash-merged it. The human-gated relaunch (wf_dcb8b488-bb9) died on the ACCOUNT SESSION LIMIT ~92min in; the other 5 layer-1 MSPs parked (not a classifier/mitosis fault). 23 unbuilt dependents remain.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main. Remaining work (Option B) = BUILD the 23 dependents via human-gated mitosis relaunches (agents publish green PRs; main thread merges), layer by layer across usage windows.

## Next Step
Fresh session -> relaunch mitosis (human-gated) against origin/main bb8cc4d to build the remaining layer-1 + next layers -> merge each green PR (main thread) -> relaunch next layer. Repeat until 31/31, then Phase 8.

## Open Risks
- SESSION-LIMIT bound: a full run exhausts a usage window (~5.46M tokens / ~92min hit the cap). Multi-window relaunch-to-resume; the done-oracle skips the 8 merged, so each relaunch does less.
- Launch each mitosis relaunch from a FRESH (not near-full) context — runs die when launched near-full (run 8, wf_a1015521-c4c, and this session's near-full state).
- Human-gated agents publish-then-stop (PR creation PROVEN to work); the main thread does every merge, and the classifier requires EXPLICIT per-session merge consent even for the main thread.
- run.json is stale after a limit-killed run (park-checkpoints die) but self-healing via the gh/git done-oracle; leftover worktrees are safe (engine idempotent).
- Local launch blocked until Phase 8 (full Xcode+CocoaPods + Android SDK not installed). Binary assets human-provided + committed.

## Key Decisions
- decisions/2026-07-12-direct-ship-built-msps.md — direct main-thread ship of already-built MSPs (Option A); engine reserved for building unbuilt dependents (Option B)
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous structurally blocked; human-gated + main-thread merge (governs Option B builds)
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch/keep-run.json semantics
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp"
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse; done-oracle skips the 8 merged)
- sessions/2026-07-12-03-journal-app-design.md — latest (app-shell #8 shipped human-gated; run died on session limit; classifier gates main-thread merge)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-12-03-journal-app-design.md
- sessions/2026-07-12-02-journal-app-design.md
- sessions/2026-07-12-01-journal-app-design.md
