---
thread: post-ship-hardening
status: paused
updated: 2026-07-24
priority: medium
completion_criteria:
  - Saved voice and video entries play back on real macOS hardware, human-confirmed
  - An exported ZIP opens in Finder with usable file extensions, human-confirmed
  - Integration tests can no longer write into the user's real journal container
  - Playback failures log the real underlying error instead of a bare `catch (_)`
next_step: Stop integration tests writing into the real journal container (integration_test/capture_save_persist_test.dart:47 is the source of the junk 4096-byte blob). Then confirm an exported ZIP carries usable file extensions.
branch: "-"
---

## Status
PR #35 MERGED (origin/main 5cb5bad) and hardware-confirmed: video entries play and a newly recorded
voice entry plays repeatedly. Criterion 1 is effectively met for newly captured media; criterion 4
was met by PR #36. Two criteria remain: the export-ZIP confirmation and stopping integration tests
from writing into the real container. The video-card defects found during that same hardware test
were split out into their own thread rather than absorbed here.

## Active Goal
Close the two remaining hygiene gaps that PR #35's investigation exposed.

## Next Step
Stop integration tests writing into the real journal container. `integration_test/
capture_save_persist_test.dart:47` runs against the REAL container and is how the junk 4096-byte
blob got into live data. Then confirm an exported ZIP opens in Finder with usable extensions.

## Open Risks
- The blob backfill has NOT yet run against the live container. The next `flutter run -d macos`
  executes it against real journal media for the first time. Dry-run against a copy passed 6/6 with
  every sha256 unchanged. Restore point:
  /Users/satanshumishra/field-notes-container-backup-2026-07-24 (21MB, all 6 blob sha256 verified).
- Two live voice entries reference a 4096-byte synthetic blob and can never play. The human elected
  to delete them IN-APP; do not write to the live DB to do it.
- A stray `probe_voice_1784705764374.m4a` sits loose in the container's Documents root, unreferenced.
- Merged branch `fix/media-blob-extension-playback` still exists locally and on the remote. Pruning
  is destructive and needs explicit consent.
- `videoRecordingMime` declares video/mp4 while macOS writes QuickTime; harmless, deliberately
  unbundled.
- Wall-clock `duration_ms` overstates real media duration on every row.
- `media_image.dart:32` builds its resolve future inside `build()`, now carrying sync stat IO.
- Backfill `missing` rows never converge, so the cheap count scan re-runs on every launch.
- CI runs NO Dart tests; local validation is the only real gate before any merge.

## Key Decisions
- decisions/2026-07-24-blob-extension-playback-root-cause.md — extensionless blobs broke
  AVFoundation; store the extension, backfill, resilient read path; link shim and plugin forks
  rejected
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the
  raw binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the human merges each PR
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run no Dart test
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. This thread is bug work and hygiene only.
- The video-card preview and control defects — split out into video-card-playback-controls.

## Pointers
- integration_test/capture_save_persist_test.dart — writes into the REAL container; source of the
  junk blob and the immediate next step
- lib/data/media/blob_paths.dart — extension derivation + `idFromRelPath`, the GC keystone
- lib/data/media/blob_extension_backfill.dart — startup migration that renames real journal media
- lib/data/media/filesystem_media_store.dart — three-candidate `absolutePath` fallback
- integration_test/media_playback_format_test.dart — real-natives macOS playback receipt
- lib/features/data/journal_export_service.dart — export path, pending ZIP confirmation
- .claude/ledger/threads/video-card-playback-controls.md — sibling thread carrying the video work
- .claude/ledger/threads/journal-app-design.md — closed predecessor thread

## Recent Sessions
- sessions/2026-07-24-08-post-ship-hardening.md — PR #35 merged; video defects split into a new
  thread
- sessions/2026-07-24-07-journal-app-design.md — playback root-caused + fixed; PR #35 opened
