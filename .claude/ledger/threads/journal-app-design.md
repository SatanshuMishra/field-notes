---
thread: journal-app-design
status: paused
updated: 2026-07-21
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Build and run the app locally for testing (flutter run -d macos; LANG=en_US.UTF-8 for pods), and confirm the app is connected to a DB — that a capture stores data and is retrievable — via the local persistence round-trip (lib/state/ drift DB; capture_save_persist_test / capture_ui_flow_test demonstrate it). See sessions/2026-07-21-07.
branch: main
---

## Status
31/31 shipped and runs on macOS. Capture flows fixed, the 4 code-review touch-ups applied, and
the COMPLETE real-UI app test is DONE — 3/3 on `-d macos`: note/voice/video drive the real
widgets (Save -> "Saving…" -> modal dismisses -> entry card appears). Shipped in PR #32,
human-merged (origin/main c2fbefd). Working tree clean except this handoff's ledger.

## Active Goal
Validate the app end-to-end on the local macOS build: run it and confirm DB-backed persistence
(a capture stores data and reappears).

## Next Step
Build + run locally (flutter run -d macos) for testing, and confirm DB connectivity — that a
capture persists to the local drift DB and is retrievable.

## Open Risks
- Live VM screenshots not yet captured (deferred under context budget); the -d macos integration
  test is the authoritative proof.
- Real camera/mic capture + TCC prompt: human/on-device only (ad-hoc signing, no paid Apple acct).
- Branch fix/capture-flows is merged; deletable (local+remote) — left in place, no confirmation.

## Key Decisions
- decisions/2026-07-21-capture-flow-root-cause-and-fix.md — capture root causes + fixes
- decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md — screenshot via VM RPC
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — CI runs no Dart test; validate locally
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- integration_test/capture_ui_flow_test.dart — real-UI -d macos receipt (note/voice/video)
- integration_test/capture_save_persist_test.dart — save-path persistence receipt
- lib/features/capture/ — the three capture flows + platform recorders
- lib/state/ — drift database + repository providers (DB connectivity lives here)
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-21-07-journal-app-design.md — 4 touch-ups + real-UI app test (3/3 macOS); PR #32 merged
- sessions/2026-07-21-06-journal-app-design.md — capture flows debugged + fixed; complete app test owed
- sessions/2026-07-21-05-journal-app-design.md — first macOS build+run; home screen visually confirmed
- sessions/2026-07-21-04-journal-app-design.md — 31/31 confirmed; local main reconciled
- sessions/2026-07-21-03-journal-app-design.md — shell-nav built; PR #31 validated
