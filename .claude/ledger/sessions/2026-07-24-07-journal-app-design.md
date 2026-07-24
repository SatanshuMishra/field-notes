# Session 2026-07-24-07 — journal-app-design

## Where it started
Resumed on an explicit slug to reproduce and root-cause the voice+video playback failure reported at the end of session 06. Ledger claimed local main was STALE at 6ca6544; verified FALSE — local main, origin/main and the working tree were all clean at c0e414b (the prior handoff's fast-forward had already reconciled it).

## What shipped
- PR #35 open on branch `fix/media-blob-extension-playback` (cut from origin/main): media blobs now carry a file extension in `rel_path`.
- `lib/data/media/blob_paths.dart` — `blobExtensionFor` (total: mime map + exhaustive MediaKind fallback, never empty/.bin/.dat), `relPathForBlob`; `idFromRelPath` strips a trailing extension and accepts both legacy and new forms.
- `lib/data/media/filesystem_media_store.dart` — `_finalize` writes via `relPathForBlob`; `absolutePath` gains a three-candidate fallback and can never throw.
- `lib/data/media/blob_extension_backfill.dart` (new) — idempotent, count-guarded, rename-only, no FS work inside a drift transaction, path containment enforced on both stored and derived paths.
- `lib/state/media_provider.dart` — backfill runs behind a broad catch so it can never gate the media store.
- `lib/features/data/journal_export_service.dart` — resolves via `MediaStore.absolutePath`; skipped blobs surface on `ExportBundle.skippedMediaIds` instead of being dropped.
- decisions/2026-07-24-blob-extension-playback-root-cause.md.

## Tried and failed
- Initial lean toward a link shim was WRONG and was overturned by grounded analysis: `dart:io` has no hard-link API, and links outside `blobs/` silently defeat Delete-All and GC. Recorded in the decision record.
- The implementer's first RED run failed on `PathAccessException` before reaching any player: the macOS App Sandbox blocks the test app from reading repo files. Worked around by embedding the fixtures as base64 in `integration_test/fixtures/tiny_media_fixtures.dart`; entitlements were NOT touched. The two binary fixtures were then deleted as dead weight.
- Commit atomicity defect, accepted not fixed: the `git rm` of the binary fixtures rode along inside 12630ab instead of its own `chore:` commit. Declined the offered `git reset --soft` history rewrite — the branch squash-merges, so grouping is cosmetic.

## Verification
- Swift AVURLAsset probe on the REAL blobs — extensionless THROW `-11828`/`-12847`; identical bytes with a media extension load with tracks + duration. Symlink, hard link and out-of-band MIME all also proven to work; `.txt`/`.bin` proven to fail like no extension.
- RED receipt captured verbatim before any fix existed: `PlatformException(VideoError, ... OSStatus error -12847)` and `PlayerException (-11828) Cannot Open`.
- `flutter test integration_test/media_playback_format_test.dart -d macos` — 2 passing (GREEN) against the real video_player/just_audio natives over a temp root.
- `flutter analyze` — No issues found. `flutter test` — 737 passing (baseline 704).
- MIGRATION DRY-RUN against a COPY of the live container: 6/6 blobs renamed, every sha256 unchanged and still equal to its id, 7/7 entries resolve, second run a no-op including cold start. Crash windows (rename-then-crash, file missing, both paths present, read-only shard, concurrent runs) all converge with no data loss. AVFoundation then opened all 5 real blobs at their new paths.
- Live container re-verified byte-identical after the dry-run. Backup at `/Users/satanshumishra/field-notes-container-backup-2026-07-24` (21MB, 8 files, all 6 blob sha256 confirmed).
- Two independent reviews (code review + adversarial data-loss dry-run) INDEPENDENTLY flagged the same blocker: a backfill failure escaping into the keepAlive `mediaStore` provider would be cached for the process lifetime and blank the whole entry feed, text entries included. Fixed before push.

## Running state
- none.

## Deferred + open
- AWAITING THE HUMAN: manual hardware test of PR #35, then merge on GitHub (`gh pr merge` is hook-blocked). Manual plan is in the PR body.
- AWAITING THE HUMAN, unanswered: whether to delete the two junk voice entries (see below). Their data, not touched without consent.
- Two of the four live voice entries reference blob `d41d438c...`, a 4096-byte synthetic ramp that is NOT media — traced to `integration_test/capture_save_persist_test.dart:47` running against the REAL container. They were never playable and still will not be after the fix. A stray `probe_voice_1784705764374.m4a` also sits loose in the container's Documents root.
- Spawned as background task chips: (1) stop integration tests writing into the real journal container; (2) fix the entry cards' `catch (_)` swallowing, which masked a precise AVFoundation error as a generic placeholder.
- Still deferred, unbundled by design: `videoRecordingMime` declares `video/mp4` while macOS writes QuickTime (harmless); wall-clock `duration_ms` overstates real media duration on every row; `media_image.dart:32` builds its future inside `build()`; backfill `missing` rows never converge so the cheap count scan re-runs each launch.
- Thread metadata is still stale: `completion_criteria` are design-spec-era and all met, yet the thread keeps absorbing post-ship bug work. Needs a human call to close and re-scope.

## Pick up here
PR #35 is open and awaiting the human's hardware test and merge. Launch via `flutter run -d macos` (never the raw binary); the three video entries and two of the four voice entries should play, and the other two voice entries should still show the placeholder (expected — junk bytes). Then confirm entries survive a relaunch and that an exported ZIP carries file extensions.
