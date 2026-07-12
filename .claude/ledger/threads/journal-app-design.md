---
thread: journal-app-design
status: paused
updated: 2026-07-11
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: From a FRESH session, pre-flight clean (HEAD 4bf206e local / origin ef3e8c6; only main worktree; KEEP .mitosis/run.json; remove any empty worktree dirs), then launch mitosis run 8 with the contract args PLUS mergePolicy "autonomous" (verbatim block in sessions/2026-07-11-03). Foundations fast-skip; 27 dependents build+publish+auto-merge. Relaunch-to-resume across usage windows until all 31 ship. Do NOT resume a prior run id.
branch: main
---

## Status
FOUNDATIONS SHIPPED: 4/31 MSPs merged to origin/main (ef3e8c6) — platform-permissions, mood-catalog, design-tokens, drift-database. CI green (receipts fix ec7b959 proven end-to-end). The mitosis engine is fully proven through the full pipeline incl. force-push unblock -> green CI -> squash-merge. 27 dependents remain (whole app: data/domain wiring, capture, UI kits, screens, features). Run 7 (wf_f16b0bef-2bf) parked 3 foundations on a force-push permission denial; resolved by user-authorized main-thread force-push + squash-merge this session.

## Active Goal
Ship the remaining 27 Field Notes v1 MSPs to origin/main via an AUTONOMOUS mitosis relaunch (run 8), across usage windows.

## Next Step
Fresh session -> pre-flight clean -> launch run 8 with the contract args PLUS `mergePolicy: "autonomous"` (verbatim block in sessions/2026-07-11-03-journal-app-design.md). Merged foundations fast-skip via the ship done-oracle; the 27 dependents publish via first-time fast-forward (no force-push) and autonomous squash-merges each green PR. Relaunch-to-resume until all 31 ship. Then decide on Phase 8 (human toolchain install + local build/sideload).

## Open Risks
- Ship-merge permission denial: the classifier that denied the delegated force-push may ALSO gate the ship agent's `gh pr merge --squash`. If run 8 ship agents park at merge, fall back to main-thread merge per green PR (as done for the 4 foundations) + relaunch. Determines whether autonomous actually cuts toil.
- Usage-window ceiling: 27-dependent run likely exceeds one Claude window; expect multiple relaunch-to-resume cycles. Launch from a fresh (not near-full) context.
- Relaunch pre-flight mandatory each time: remove any stale/empty worktree dirs, KEEP .mitosis/run.json, leave remote alone.
- Lingering published-unmerged dependent: if a relaunch dies after `git push -u` but before merge, the next relaunch rebases it and needs `--force-with-lease` (could re-hit the denial) — main-thread force-push resolves it.
- Local launch blocked until Phase 8: full Xcode+CocoaPods + Android SDK not installed. camera_macos + macOS video thumbnails to verify at Phase 2.
- Binary assets cannot be agent-downloaded (harness blocks curl/wget); human-provided + committed.

## Key Decisions
- decisions/2026-07-11-foundations-shipped-autonomous-policy.md — force-push authorized; 4 foundations merged (ef3e8c6); autonomous merge policy for the 27
- decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md — receipts.yml npm-ci fix (ec7b959); relaunch semantics; keep run.json / remove worktrees pre-flight
- decisions/2026-07-10-mitosis-run-contract.md — exact fresh-run inputs; sourcePrefix "msp" (no trailing slash)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync, light-only
- decisions/2026-07-09-tech-stack.md — Flutter + SQLite both + custom REST sync + E2EE + Tailscale

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell in v1).

## Pointers
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 notes pre-vendored fonts + skeleton status)
- .mitosis/run.json — 31 MSP manifest (KEEP across relaunches; MSP-id stability -> PR reuse)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace"; origin URL redirects)

## Recent Sessions
- sessions/2026-07-11-03-journal-app-design.md
- sessions/2026-07-11-02-journal-app-design.md
