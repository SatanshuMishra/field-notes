---
thread: post-ship-hardening
status: paused
updated: 2026-07-24
priority: high
completion_criteria:
  - Saved voice and video entries play back on real macOS hardware, human-confirmed
  - An exported ZIP opens in Finder with usable file extensions, human-confirmed
  - Integration tests can no longer write into the user's real journal container
  - Playback failures log the real underlying error instead of a bare `catch (_)`
next_step: HUMAN ACTION. Hardware-test PR #35 via `flutter run -d macos` per the PR's manual test plan, then merge it on GitHub (gh pr merge is hook-blocked for the agent).
branch: fix/media-blob-extension-playback (PR #35, open)
---

## Status
Successor to journal-app-design (closed done 2026-07-24), which had covered design, planning and the
31/31 v1 build. This thread carries post-ship bug work only. First item: PR #35, which root-caused and
fixed voice+video playback plus a silently broken export.

## Active Goal
Get PR #35 hardware-tested and merged, then close the two hygiene gaps it exposed.

## Next Step
Human: `flutter run -d macos` (never the raw binary). Three video entries and two of four voice entries
should play; the other two voice entries should still show the placeholder (junk bytes, expected — the
human will delete those two in-app after merge). Then confirm entries survive a relaunch, export a
bundle and confirm the ZIP's media carry extensions, and merge #35 on GitHub.

## Open Risks
- The backfill renames real journal media on first launch after merge. Verified by dry-run against a
  copy, not yet on the live container. Backup: /Users/satanshumishra/field-notes-container-backup-2026-07-24
  (21MB, all 6 blob sha256 verified). Restore from there if the first real launch goes wrong.
- Two of four live voice entries reference a 4096-byte synthetic blob and can never play. Human elected
  to delete them IN-APP after merge — do not write to the live DB to do it.
- A stray `probe_voice_1784705764374.m4a` sits loose in the container's Documents root, unreferenced.
- Integration tests still write into the real journal container (this is how the junk blob got there).
- Entry cards swallow every playback exception via `catch (_)`, which masked a precise AVFoundation
  error as a generic placeholder and cost a full investigation to diagnose.
- `videoRecordingMime` declares video/mp4 while macOS writes QuickTime; harmless, deliberately unbundled.
- Wall-clock `duration_ms` overstates real media duration on every row.
- `media_image.dart:32` builds its resolve future inside `build()`, now carrying sync stat IO.
- Backfill `missing` rows never converge, so the cheap count scan re-runs on every launch.
- CI runs NO Dart tests; local validation is the only real gate before any merge.

## Key Decisions
- decisions/2026-07-24-blob-extension-playback-root-cause.md — extensionless blobs broke AVFoundation; store the extension, backfill, resilient read path; link shim and plugin forks rejected
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the raw binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the human merges each PR; gh pr merge is agent-blocked
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run no Dart test
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. This thread is bug work and hygiene only.

## Pointers
- lib/data/media/blob_paths.dart — extension derivation + `idFromRelPath`, the GC keystone
- lib/data/media/blob_extension_backfill.dart — startup migration that renames real journal media
- lib/data/media/filesystem_media_store.dart — three-candidate `absolutePath` fallback
- integration_test/media_playback_format_test.dart — real-natives macOS playback receipt
- integration_test/capture_save_persist_test.dart — writes into the REAL container; source of the junk blob
- lib/features/entry_cards/cards/video_body.dart — renders "Can't play this video"
- lib/features/entry_cards/cards/voice_body.dart — renders "Can't play this recording"
- .claude/ledger/threads/journal-app-design.md — closed predecessor thread

## Recent Sessions
- sessions/2026-07-24-07-journal-app-design.md — playback root-caused + fixed; PR #35 open; this thread created
