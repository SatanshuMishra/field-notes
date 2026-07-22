---
thread: journal-app-design
status: paused
updated: 2026-07-21
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: 31/31 SHIPPED + local main reconciled (b542a4b = origin/main 54b81a2 + ledger). App is code-complete. Fresh session: finalize (recommend DEFER the reminders day-2 follow-up) then build + run locally on macOS for testing — gate is the Phase 8 HUMAN toolchain install (Xcode/CocoaPods; Android SDK absent). Full plan in sessions/2026-07-21-04. No mitosis anywhere.
branch: main
---

## Status
31/31 SHIPPED — all MSPs merged (origin/main 54b81a2, PR #31 merged). App is code-complete:
lib/main.dart is a runnable entry, zero stray TODO/UnimplementedError (only the intentional inert v2
sync placeholder). Local main reconciled to origin/main (b542a4b + 3 unpushed ledger commits).

## Active Goal
Finalize the minimal remaining parts and build + run Field Notes v1 locally (macOS) for manual testing.

## Next Step
Follow the recommended plan in sessions/2026-07-21-04: workspace is clean + app code-complete; decide
reminders day-2 follow-up (recommend DEFER); then drive the macOS local build/run (`flutter run -d
macos`; the `run` skill can help) — the gate is the Phase 8 HUMAN toolchain install (full Xcode +
CocoaPods; Android SDK absent). Then a manual test pass against the spec. No mitosis relaunch anywhere.

## Open Risks
- LOCAL-RUN GATE: Phase 8 toolchain is a HUMAN install (agent cannot — downloads blocked): full Xcode +
  CocoaPods for macOS. Android SDK is ABSENT (no `flutter build apk`); macOS is the viable first target.
- reminders day-2+ reach is NOT built yet (deferred follow-up MSP; needs a new msp id). The app arms only
  the NEXT reminder occurrence. Decide build-now vs defer with the user (recommend defer until after test).
- `gh pr merge` stays agent-blocked for any future PR (the HUMAN merges). Local main is 3 ledger commits
  ahead of origin (unpushed, per the established pattern); push is optional.

## Key Decisions
- decisions/2026-07-21-shellnav-built-via-delegated-implementer.md — shell-nav BUILT via a delegated
  implementer on origin/main (fresh-context rule barred a relaunch; also sidesteps composition); PR #31
- decisions/2026-07-21-shellnav-checkpoint-refs-unblock.md — (superseded) checkpoint refs recreated;
  not needed once shell-nav was built directly on merged main
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the HUMAN merges every PR
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — local validation before every merge
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact base line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated mode (merge mechanism superseded above)
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell). The reminders
  day-2 pre-arm follow-up MSP is post-31 work (needs a NEW msp id; not in this run).

## Pointers
- .mitosis/run.json — STAGED 31-msp manifest (gitignored; base + park deltas + built checkpoints)
- .mitosis/run.json.pristine-backup — untouched 31-MSP source; gitignored
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block (flip mergePolicy to human-gated)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- GitHub: https://github.com/SatanshuMishra/field-notes (PRIVATE). Project name is field-notes.

## Recent Sessions
- sessions/2026-07-21-04-journal-app-design.md — 31/31 confirmed; local main reconciled; app code-complete; hand-off for local-run phase
- sessions/2026-07-21-03-journal-app-design.md — shell-nav BUILT via delegated implementer; PR #31 open + validated (660 tests); awaiting merge
- sessions/2026-07-21-02-journal-app-design.md — 26→30/31; gh-merge hook-block found; shell-nav parked+unblocked
- sessions/2026-07-21-01-journal-app-design.md — final run: 26/31, usage-limit parked 5, repo pristine
- sessions/2026-07-20-03-journal-app-design.md — 23/31; engine verified; final run staged, not launched
