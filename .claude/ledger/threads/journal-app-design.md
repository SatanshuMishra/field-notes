---
thread: journal-app-design
status: active
updated: 2026-07-24
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Human hardware-verifies PR #34 (branch fix/macos-camera-lifecycle-and-deps, already checked out) via `flutter run -d macos` (preview live on modal open; menu-bar indicator ON at open and OFF after close/cancel; picker switches built-in vs external for both preview and recording), then merges PR #34.
branch: fix/macos-camera-lifecycle-and-deps
---

## Status
Both branches are now merged into `fix/macos-camera-lifecycle-and-deps` and opened as PR #34 (zero
conflicts; the diffs share no files). The MERGED result was re-verified from scratch: analyze clean,
704 unit + 4 macOS integration passing, macOS debug build OK. Still NOT hardware-verified.

## Active Goal
Get the camera lifecycle fixes confirmed on real hardware, then merge PR #34.

## Next Step
Human runs `flutter run -d macos` on the already-checked-out fix/macos-camera-lifecycle-and-deps and
confirms the indicator turns OFF after closing the modal, and that the picker actually switches cameras.
Never launch the raw .app binary.

## Open Risks
- No hardware verification of ANY camera change. Menu-bar indicator behavior is unobservable to the agent;
  only the proximate cause (native `destroy` fires on every dismissal route) was proven.
- Swift concurrency fixes are argued from code + compile/link, not runtime race reproductions.
- Android/iOS capture path has unit-level receipts only; no Android SDK on this machine.
- Remembered camera does not persist across app restarts (keepAlive provider only).
- share_plus is pinned at 12.x indefinitely; build_runner/drift_dev pinned by an upstream analyzer ceiling.
- sqlite3_flutter_libs is EOL and seemingly unused but may supply drift's native SQLite binaries; removing
  it needs a runtime-verified cleanup, not a pub upgrade.

## Key Decisions
- decisions/2026-07-24-combined-camera-deps-pr.md — both branches ship as one PR (#34); camera 0.12.x cannot register a competing macOS camera plugin
- decisions/2026-07-24-camera-preview-lifecycle-root-causes.md — all four defects were Dart-side; the vendored plugin already exposed what was needed
- decisions/2026-07-24-share-plus-13-blocked-by-file-picker.md — share_plus 13.x unreachable without a prerelease file_picker
- decisions/2026-07-24-macos-videorotationangle-crash.md — REAL crash = videoRotationAngle setter, not save-path
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — human merges each PR; gh pr merge agent-blocked
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run NO Dart test; local validation is the only real gate
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- lib/features/capture/platform/camera_video_recorder.dart — session lifecycle, release/destroy, device listing
- lib/features/capture/video/video_composer.dart — modal orchestration, prepare/release/device-switch
- lib/features/capture/video/camera_picker.dart — device picker UI
- third_party/camera_macos/LOCAL_MODIFICATIONS.md — vendored Swift delta; read before any re-vendor
- test/features/capture/video/camera_macos_release_test.dart — native destroy contract incl. warmup race
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-24-05-journal-app-design.md — camera lifecycle fixes + package upgrade, both unmerged
- sessions/2026-07-24-04-journal-app-design.md — PR #33 MERGED (902a659); local main reconciled
- sessions/2026-07-24-03-journal-app-design.md — SHIP: VIDCAP stripped, crash fix committed + pushed
