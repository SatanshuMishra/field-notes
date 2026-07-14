---
thread: journal-app-design
status: paused
updated: 2026-07-14
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Fresh session -> relaunch mitosis (mergePolicy "human-gated", KEEP run.json) against origin/main 6339c6f to BUILD the 19 downstream MSPs (core-providers, capture-*, entry-cards, mood-picker, screens, streak-service, sound-effects, reminders, data-management, settings-screen, shell-nav-integration) + next layers; merge each green PR from main thread (re-confirm merge consent to clear the classifier). VERIFY published PRs via `gh pr list`, not the run summary. Do NOT resume any prior run id.
branch: main
---

## Status
13/31 SHIPPED (origin/main 6339c6f). Session 2026-07-14 ran the human-gated relaunch loop 8 -> 13/31: 3 runs published green PRs, main thread merged 5 under per-batch consent — #9 feedback-motion-kit, #10 settings-fields-kit, #11 journal-repository, #12 settings-repository, #13 media-store. LAYER-1 + repository + media layer COMPLETE. 19 downstream dependents remain, all now unblocked by media-store #13.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main. Remaining (Option B) = BUILD the 19 downstream dependents via human-gated mitosis relaunches (agents publish green PRs; main thread merges), layer by layer across usage windows.

## Next Step
Fresh session -> relaunch mitosis (human-gated) against origin/main 6339c6f to build the 19 downstream MSPs -> merge each green PR (main thread, re-confirm consent) -> relaunch next layer. Repeat until 31/31, then Phase 8.

## Open Risks
- The mitosis `result.shipped` array is MISLEADING — it lists only done-oracle fast-skips (already-merged), NOT PRs the run just published. Always verify via `gh pr list --state open`; the summary hid every newly-published PR this session.
- SESSION-LIMIT bound: full runs exhaust a usage window (two runs died at ~3h and ~1.8h; each still published green PRs first). Multi-window relaunch-to-resume; done-oracle skips the merged, so each relaunch does less.
- Launch each relaunch from a FRESH (not near-full) context — runs die when launched near-full. Handed off this session at 72% rather than relaunch downstream.
- Human-gated agents publish-then-stop (PROVEN); the main thread does every merge, and the classifier requires EXPLICIT per-session merge consent even for the main thread (asked per batch this session).
- run.json is stale after a limit-killed run but self-healing via the gh/git done-oracle; leftover worktrees are safe (engine idempotent).
- Local launch blocked until Phase 8 (full Xcode+CocoaPods + Android SDK not installed). Binary assets human-provided + committed.

## Key Decisions
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
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse; done-oracle skips the 13 merged)
- sessions/2026-07-14-01-journal-app-design.md — latest (8 -> 13/31; layer-1+repo+media complete; shipped-array lesson)
- sessions/2026-07-11-03-journal-app-design.md — verbatim mitosis relaunch block (contract args; mergePolicy "human-gated")
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-14-01-journal-app-design.md
- sessions/2026-07-12-03-journal-app-design.md
- sessions/2026-07-12-02-journal-app-design.md
