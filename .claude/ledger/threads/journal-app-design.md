---
thread: journal-app-design
status: paused
updated: 2026-07-12
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Fresh session -> Option B. Relaunch mitosis with mergePolicy "human-gated" to BUILD the ~24 unbuilt dependents against origin/main 5e73d67 (this is where the engine is genuinely needed). Merge each green PR via gh pr merge --squash (authorized pattern), then relaunch the next dependency layer. Do NOT resume run wf_a1015521-c4c.
branch: main
---

## Status
7/31 SHIPPED (origin/main 5e73d67). This session shipped the 3 second-layer foundations (domain-models #5, flower-svg-set #6, sticker-widget-kit #7) via DIRECT main-thread push+PR+squash after proving a mitosis relaunch was the wrong tool for already-built code (its ship step adds no receipt metadata; a plain push passes receipts CI). 24 unbuilt dependents remain.

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main. Remaining work (Option B) = BUILD the 24 dependents via human-gated mitosis relaunches (agents publish green PRs; main thread merges), layer by layer across usage windows.

## Next Step
Fresh session -> relaunch mitosis (human-gated) to build the next dependency layer against origin/main 5e73d67 -> merge each green PR (main thread) -> relaunch next layer. Repeat until 31/31, then Phase 8.

## Open Risks
- Two ship modes now proven: (a) DIRECT main-thread ship works for ALREADY-BUILT branches (used this session); (b) mitosis is needed only to BUILD unbuilt code. Do not route already-built branches through the engine.
- Launch each mitosis relaunch from a FRESH (not near-full) context — runs die when launched near-full (run 8, and wf_a1015521-c4c killed on process exit).
- Delegated ship agents cannot self-merge (harness classifier) and human-gated agents publish-then-stop; main thread does every merge.
- Local launch blocked until Phase 8 (full Xcode+CocoaPods + Android SDK not installed).
- Binary assets cannot be agent-downloaded; human-provided + committed.

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
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse; done-oracle skips the 7 merged)
- sessions/2026-07-12-02-journal-app-design.md — this session (Option A: 3 direct-shipped; direct-vs-engine lesson)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-12-02-journal-app-design.md
- sessions/2026-07-12-01-journal-app-design.md
- sessions/2026-07-11-04-journal-app-design.md
