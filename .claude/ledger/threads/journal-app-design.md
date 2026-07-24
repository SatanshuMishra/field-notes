---
thread: journal-app-design
status: paused
updated: 2026-07-24
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: HUMAN ACTION. Hardware-test PR #35 via `flutter run -d macos` per the PR's manual test plan, then merge it on GitHub. Also answer whether to delete the two junk voice entries.
branch: fix/media-blob-extension-playback (PR #35, open)
---

## Status
Playback root-caused and fixed. Media blobs were stored as extensionless SHA-256 files; AVFoundation
picks its demuxer from the path UTI and never content-sniffs, so every blob was rejected (`-12847`
video, `-11828` audio) and both engines failed together. PR #35 stores the extension in `rel_path`,
backfills existing rows, and adds a resilient read path. Export was broken identically and is fixed too.
Verified 737 tests, analyze clean, a real-natives macOS receipt RED-then-GREEN, and a full migration
dry-run against a copy of the live container. Awaiting the human's hardware test and merge.

## Active Goal
Get PR #35 hardware-tested and merged so saved voice and video entries play back.

## Next Step
Human: run `flutter run -d macos` (never the raw binary) and follow the PR's manual test plan — three
video entries and two of four voice entries should play; the other two voice entries should still show
the placeholder (junk bytes, expected). Then merge #35 on GitHub.

## Open Risks
- Playback is verified by an automated real-natives receipt and a dry-run on copied real data, but NOT
  yet by a human on the live app. The backfill renames real journal media on first launch after merge.
- Backup of the live container: /Users/satanshumishra/field-notes-container-backup-2026-07-24 (21MB,
  all 6 blob sha256 verified). Restore from there if the first real launch goes wrong.
- Two of four live voice entries reference a 4096-byte synthetic blob written by
  integration_test/capture_save_persist_test.dart against the REAL container. Never playable; unchanged
  by this fix. Deleting them is a pending human decision.
- Integration tests still write into the user's real journal container (task chip spawned).
- Entry cards still swallow every playback exception via `catch (_)`, which masked this bug entirely
  (task chip spawned).
- `videoRecordingMime` declares video/mp4 while macOS writes QuickTime; harmless, deliberately unbundled.
- Wall-clock `duration_ms` overstates real media duration on every row.
- completion_criteria are design-spec-era and all appear met, yet this thread keeps absorbing post-ship
  bug work. Criteria are never edited retroactively — needs a human call to close and re-scope.
- Swift concurrency fixes argued from code + compile/link, not runtime race reproductions.
- Android/iOS capture path has unit-level receipts only; no Android SDK on this machine.
- Remembered camera does not persist across app restarts (keepAlive provider only).
- share_plus pinned at 12.x; build_runner/drift_dev pinned by an upstream analyzer ceiling.
- sqlite3_flutter_libs is EOL and seemingly unused but may supply drift's native SQLite binaries.

## Key Decisions
- decisions/2026-07-24-blob-extension-playback-root-cause.md — extensionless blobs broke AVFoundation; store the extension, backfill, resilient read path; link shim and plugin forks rejected
- decisions/2026-07-24-combined-camera-deps-pr.md — camera-lifecycle + dep sweep shipped as one PR (#34)
- decisions/2026-07-24-camera-preview-lifecycle-root-causes.md — all four camera defects were Dart-side
- decisions/2026-07-24-share-plus-13-blocked-by-file-picker.md — share_plus 13.x needs a prerelease file_picker
- decisions/2026-07-24-macos-videorotationangle-crash.md — REAL crash = videoRotationAngle setter
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the raw binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — human merges each PR; gh pr merge agent-blocked
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run NO Dart test; local validation is the only real gate
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user;
  pooled Memories gallery. All sync/server work is v2. Reminders day-2 pre-arm is post-31.

## Pointers
- lib/data/media/blob_paths.dart — extension derivation + `idFromRelPath`, the GC keystone
- lib/data/media/blob_extension_backfill.dart — the startup migration that renames real journal media
- lib/data/media/filesystem_media_store.dart — three-candidate `absolutePath` fallback
- integration_test/media_playback_format_test.dart — real-natives macOS playback receipt
- lib/features/entry_cards/cards/video_body.dart — renders "Can't play this video"
- lib/features/entry_cards/cards/voice_body.dart — renders "Can't play this recording"
- third_party/camera_macos/LOCAL_MODIFICATIONS.md — vendored Swift delta; read before any re-vendor
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec

## Recent Sessions
- sessions/2026-07-24-07-journal-app-design.md — playback root-caused + fixed; PR #35 open, awaiting hardware test
- sessions/2026-07-24-06-journal-app-design.md — PR #34 MERGED; camera hardware-verified; playback defect reported
- sessions/2026-07-24-05-journal-app-design.md — camera lifecycle fixes + package upgrade
