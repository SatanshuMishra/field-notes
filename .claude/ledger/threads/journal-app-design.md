---
thread: journal-app-design
status: done
updated: 2026-07-24
priority: high
completion_criteria:
  - [x] Design spec written to docs/superpowers/specs/ and user-approved
  - [x] 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - [x] Implementation plan produced via the writing-plans skill
closure: All three criteria are met — the v1 design spec was written and approved, all four starred reconciliation decisions were resolved, and the implementation plan was produced and executed to 31/31 shipped MSPs; post-ship bug work continues in threads/post-ship-hardening.md.
next_step: "-"
branch: "-"
---

## Status
CLOSED 2026-07-24 by human decision. Design, planning and the full v1 build are complete (31/31 MSPs
shipped). Post-ship hardening — including the open PR #35 — moved to threads/post-ship-hardening.md.

## Historical Status
Playback root-caused and fixed. Media blobs were stored as extensionless SHA-256 files; AVFoundation
picks its demuxer from the path UTI and never content-sniffs, so every blob was rejected (`-12847`
video, `-11828` audio) and both engines failed together. PR #35 stores the extension in `rel_path`,
backfills existing rows, and adds a resilient read path. Export was broken identically and is fixed too.
Verified 737 tests, analyze clean, a real-natives macOS receipt RED-then-GREEN, and a full migration
dry-run against a copy of the live container. Awaiting the human's hardware test and merge.

## Active Goal
- Achieved and closed. Post-ship work continues in threads/post-ship-hardening.md.

## Open Risks
- Carried forward to threads/post-ship-hardening.md; see also sessions/2026-07-24-07-journal-app-design.md.

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
