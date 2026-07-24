---
thread: journal-app-design
status: paused
updated: 2026-07-24
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: FRESH SESSION. Reproduce the voice+video playback failure via `flutter run -d macos`, root-cause it fully, fix on a dedicated branch cut from origin/main (local main is STALE), verify, open a PR, return to the human for manual testing.
branch: origin/main (e0ee77d) — the playback fix gets its own branch
---

## Status
PR #34 MERGED (squash e0ee77d): macOS camera lifecycle fixes + dependency sweep. Human hardware-verified
the camera work this session, so preview-on-open, camera release, and the device picker are CONFIRMED.
NEW CRITICAL defect reported immediately after: saved voice and video entries will not PLAY BACK.

## Active Goal
Restore playback for saved voice and video entries. Capture/save is proven; playback is not.

## Next Step
Fresh session. Reproduce "Can't play this video" / "Can't play this recording" in the Today feed via
`flutter run -d macos` (never the raw .app binary). Root-cause fully before proposing a fix, fix it on a
dedicated branch cut from origin/main, verify, open a PR, then hand back for manual testing.

## Open Risks
- Playback has NEVER been hardware-exercised. Save was proven in PR #33; the read/render path was not.
  Unknown whether the fault is the stored path, the file bytes, the player widget, or macOS sandbox reach.
- Local `main` is STALE and diverged (6ca6544 vs origin/main e0ee77d). The agent could not `git reset`
  (harness gates destructive git even with explicit human consent). Branch from origin/main.
- This thread's completion_criteria are design-spec-era and all appear met, yet the thread keeps absorbing
  post-ship bug work. Criteria are never edited retroactively — needs a human call to close and re-scope.
- Swift concurrency fixes are argued from code + compile/link, not runtime race reproductions.
- Android/iOS capture path has unit-level receipts only; no Android SDK on this machine.
- Remembered camera does not persist across app restarts (keepAlive provider only).
- share_plus is pinned at 12.x indefinitely; build_runner/drift_dev pinned by an upstream analyzer ceiling.
- sqlite3_flutter_libs is EOL and seemingly unused but may supply drift's native SQLite binaries; removing
  it needs a runtime-verified cleanup, not a pub upgrade.

## Key Decisions
- decisions/2026-07-24-combined-camera-deps-pr.md — both branches shipped as one PR (#34); camera 0.12.x cannot register a competing macOS camera plugin
- decisions/2026-07-24-camera-preview-lifecycle-root-causes.md — all four defects were Dart-side; the vendored plugin already exposed what was needed
- decisions/2026-07-24-share-plus-13-blocked-by-file-picker.md — share_plus 13.x unreachable without a prerelease file_picker
- decisions/2026-07-24-macos-videorotationangle-crash.md — REAL crash = videoRotationAngle setter, not save-path
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the raw binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — human merges each PR; gh pr merge agent-blocked
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run NO Dart test; local validation is the only real gate
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- lib/features/entry_cards/cards/video_body.dart:102 — renders "Can't play this video"; playback entry point
- lib/features/entry_cards/cards/voice_body.dart:137 — renders "Can't play this recording"
- lib/features/capture/platform/camera_video_recorder.dart — session lifecycle, release/destroy, device listing
- lib/features/capture/video/video_composer.dart — modal orchestration, prepare/release/device-switch
- third_party/camera_macos/LOCAL_MODIFICATIONS.md — vendored Swift delta; read before any re-vendor
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-24-06-journal-app-design.md — PR #34 MERGED (e0ee77d) + camera hardware-verified; NEW critical playback defect reported
- sessions/2026-07-24-05-journal-app-design.md — camera lifecycle fixes + package upgrade, both unmerged
- sessions/2026-07-24-04-journal-app-design.md — PR #33 MERGED (902a659); local main reconciled
