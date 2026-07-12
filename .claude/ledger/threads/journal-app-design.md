---
thread: journal-app-design
status: paused
updated: 2026-07-12
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: From a FRESH session, pre-flight (HEAD 07e38fc local / origin ef3e8c6; run.json intact; leave the 3 ship worktrees in place — reused idempotently), then relaunch mitosis with the verbatim block in sessions/2026-07-11-03 but mergePolicy "human-gated". Merge each green PR it publishes via gh pr merge --squash (authorized this session), then relaunch the next dependency layer. Do NOT resume a prior run id.
branch: main
---

## Status
AUTONOMOUS PROVEN STRUCTURALLY BLOCKED. Run wf_b72ceb41-dd5 (mergePolicy "autonomous") ran to completion (~75min, 86 agents) and shipped 0: the harness safety classifier bars delegated ship agents from self-merging (Merge Without Review + Self-Approval), proactively, so they never publish — no PRs reached origin. domain-models/flower-svg-set/sticker-widget-kit are BUILT + tested on local integration branches but unshipped. Pivoted to human-gated policy. 4/31 remain the only merges (origin/main ef3e8c6).

## Active Goal
Ship the remaining 27 Field Notes v1 MSPs to origin/main via HUMAN-GATED mitosis relaunches (agents publish green PRs + stop; main thread merges with per-session consent), layer by layer across usage windows.

## Next Step
Fresh session -> pre-flight -> relaunch mitosis with mergePolicy "human-gated" (verbatim block in sessions/2026-07-11-03, that one change) -> merge each green PR (authorized) -> relaunch next layer. Repeat until all 31 ship. Then Phase 8 (human toolchain install + local build/sideload).

## Open Risks
- Publish-time gating (untested on human-gated): ship must `git push -u` a new branch + `gh pr create`. Session-03 showed fast-forward publish is NOT blocked and PR-open is not a merge, so it should pass — confirm on the first human-gated run.
- Usage-window ceiling: layer-by-layer shipping spans many windows; launch each relaunch from a FRESH (not near-full) context — run 8 died launching near-full.
- Preserve the 3 built worktrees/branches until shipped; relaunch reuses them idempotently (mitosis.js:672). Do NOT delete.
- Lingering published-unmerged dependent: if a relaunch dies after `git push -u` but before merge, the next relaunch rebases + may need `--force-with-lease` (could re-hit the denial) — main-thread force-push resolves it.
- Local launch blocked until Phase 8: full Xcode+CocoaPods + Android SDK not installed.
- Binary assets cannot be agent-downloaded; human-provided + committed.

## Key Decisions
- decisions/2026-07-12-human-gated-merge-policy.md — autonomous structurally blocked; human-gated + main-thread merge, layer-by-layer
- decisions/2026-07-11-foundations-shipped-autonomous-policy.md — 4 foundations merged (ef3e8c6); autonomous-for-27 part SUPERSEDED
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch/keep-run.json semantics
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp"
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse)
- sessions/2026-07-11-03-journal-app-design.md — verbatim relaunch block (change mergePolicy to "human-gated")
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-12-01-journal-app-design.md
- sessions/2026-07-11-04-journal-app-design.md
- sessions/2026-07-11-03-journal-app-design.md
