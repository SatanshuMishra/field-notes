---
thread: journal-app-design
status: paused
updated: 2026-07-11
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: From a FRESH session (NOT a near-full context): confirm HEAD==origin==ec7b959 + pre-flight clean (no stale worktrees; KEEP .mitosis/run.json + 4 remote PRs), then launch mitosis run 7 with the exact contract args (decisions/2026-07-10-mitosis-run-contract.md). Usage limit reset 17:30 so relaunch is viable. Expect the full run to span MULTIPLE usage windows — when it parks on a limit, relaunch to resume. Do NOT resume any prior run id.
branch: main
---

## Status
Design complete + user-approved; Phase 0 skeleton + fonts + receipts CI committed. THE MITOSIS ENGINE IS PROVEN: run 5 (wf_2a220c77-2e6) ran end-to-end — decomposed 31 MSPs (1 cluster), built + opened PRs #1-4 (platform-permissions, mood-catalog, design-tokens, drift-database), but ALL CI-RED on a spurious `npm ci` in receipts.yml. Fix landed: deleted receipts.yml:16 `npm ci`, pushed origin/main == ec7b959. Run 6 (wf_0e9953fd-8e2) relaunched but FAILED at ~18min purely on the Claude USAGE LIMIT (16/20 agents: "hit your session limit · resets 5:30pm America/Edmonton") — NOT a code/engine bug. Limit reset 17:30; now past it. State clean + relaunch-ready (no stale worktrees, ec7b959==origin, .mitosis/run.json + 4 remote PRs intact).

## Active Goal
Execute Field Notes v1 via mitosis — ship all 31 MSPs into the private repo (SatanshuMishra/field-notes).

## Next Step
Relaunch mitosis run 7 from a fresh session with the contract args. The engine is proven and the CI bug is fixed (ec7b959) — no debugging needed. It rebuilds the 4 foundation MSPs onto their existing PRs #1-4 and builds the other 27. Because a full run exceeds one usage window, plan to relaunch-to-resume across windows until all 31 ship. On full success, decide merge policy (review-and-merge the green PRs vs relaunch autonomous) and land v1 on main. Do NOT resume any prior run id.

## Open Risks
- Usage-window ceiling: a full 31-MSP run (~3.9M subagent tokens / 2h) exceeds one Claude usage window; run 6 died on it at ~18min. Expect multiple relaunch-to-resume cycles. Launch from a fresh context, not a near-full one.
- Relaunch pre-flight is mandatory each time: remove any stale worktrees (branch-prep collides otherwise), KEEP .mitosis/run.json (MSP-id stability -> no duplicate PRs), leave remote PRs/branches.
- Merge policy undecided: human-gated yields ~31 green PRs awaiting human merge; autonomous would auto-land v1 on main. See decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md.
- Binary assets CANNOT be agent-downloaded (harness blocks curl/wget); human-provided + committed. Applies to sound effects / future binaries.
- camera_macos community plugin + macOS video thumbnails — verify early (Phase 2).
- Platform build toolchains (full Xcode + CocoaPods, Android SDK) not installed — needed only at Phase 8 (human step).

## Key Decisions
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch rebuilds open-PR MSPs; keep run.json / remove worktrees pre-flight
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-fonts-vendored-human-provided.md — vendored OFL fonts, human-provided (downloads blocked)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both + custom REST sync + E2EE + Tailscale

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery.

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-11-02-journal-app-design.md
- sessions/2026-07-11-01-journal-app-design.md
