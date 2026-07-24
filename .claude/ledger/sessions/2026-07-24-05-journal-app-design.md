# Session 2026-07-24-05 — journal-app-design

## Where it started
Resumed the paused thread on explicit instruction. The human reported four CRITICAL macOS video-capture
defects from real hardware (built-in + external camera) and asked for reproduction, root cause, fixes,
and a Flutter package update.

## What shipped
Branch `fix/macos-camera-lifecycle` (4 + follow-up commits, NOT merged, no PR):
- Live preview now starts on modal open, not on Record — `openSession()` called from `initState`/`_prepare`
  (lib/features/capture/video/video_composer.dart), sheet renders preview in idle (video_recorder_sheet.dart).
- Camera release implemented — `release()` is the only caller of `controller.destroy()`; wired to save,
  cancel, dispose and device-switch (lib/features/capture/platform/camera_video_recorder.dart:306-329).
- Camera picker — `listDevices()` results surfaced and `deviceId` passed through to preview + recording;
  selection remembered per session, falls back when the remembered device is gone
  (lib/features/capture/video/camera_picker.dart, camera_selection.dart).
- Swift: `latestBuffer` behind an NSLock (TOCTOU/use-after-free), `defer` unlock balancing the
  base-address lock, guarded `makeImage()`, image-stream conversion gated on a live `eventSink`
  (third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift).
- third_party/camera_macos/LOCAL_MODIFICATIONS.md added so a re-vendor cannot silently revert the Swift fixes.

Branch `chore/package-upgrade` in worktree /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees/pkg-upgrade
(NOT merged, no PR):
- 48a4fb8 — `flutter pub upgrade`: drift 2.34.2, sqlite3 3.5.0, video_player_android 2.12.0, posix,
  source_gen, synchronized, uuid.
- b4331fa — camera 0.12.0+2, camera_android_camerax 0.7.4+2, camera_avfoundation 0.10.2.

## Tried and failed
- First fix attempt was BLOCKED in review: `release()` returned early when `_controller` was null, which is
  exactly the 0.5-2s init warmup window, so cancel-during-warmup reproduced the original leak. The test suite
  was structurally blind to it (fake incremented release unconditionally; every test let init finish first).
  Fixed on the second pass via a pending-destroy intent (`_destroyRequested` + `_onControllerReady`).
- share_plus 12 -> 13.x: does NOT resolve. Whole 13.x line needs win32 ^6; file_picker 11.0.2 needs win32
  ^5.9.0. `pub outdated` advertises "Resolvable 13.3.0" but that resolution requires prerelease
  file_picker 12.0.0-beta.7. Reverted, not committed. See decisions/2026-07-24-share-plus-13-blocked-by-file-picker.md.
- build_runner 2.15.2 / drift_dev 2.34.5: unreachable, gated by riverpod_generator's analyzer ^12 ceiling.

## Verification
- `flutter analyze` — No issues found (both branches).
- `flutter test` on fix branch — 704 passed. Baseline measured on main this session is 681, not the ~690
  the ledger previously implied.
- `flutter test integration_test/capture_ui_flow_test.dart -d macos` — 4 passed; recompiles the Swift plugin.
- Every behavioral fix demonstrated RED-when-reverted then GREEN, including the CRITICAL: a receipt gates
  native `initialize` behind a Completer, calls `release()` mid-flight, completes init, and asserts the
  channel spy records exactly one `destroy`.
- `flutter build macos --debug` on the upgrade branch — Built field_notes.app; warnings all pre-existing.
- camera bump guard: `macos/Flutter/GeneratedPluginRegistrant.swift` before/after diff EMPTY; camera_macos
  remains the sole macOS camera registration.

## Running state
- none. Both worktrees left in place per decisions/2026-07-20-keep-stale-worktrees.md.

## Deferred + open
- NOTHING IS HARDWARE-VERIFIED. The menu-bar camera indicator (on at open, off after close) and the
  built-in vs external switch are unconfirmed — the agent cannot see the macOS menu bar. Proximate cause
  was proven instead (native `destroy` fires on every dismissal route incl. the warmup race).
- Neither branch is merged. Merge order is open; the two are textually disjoint (the camera branch touches
  no dependency files).
- The `latestBuffer` lock and base-address unlock are argued from code and confirmed to compile/link; not
  runtime race reproductions.
- Android/iOS path has unit-level receipts only (no Android SDK on this machine).
- Remembered camera persists within a session (keepAlive provider), not across app restarts.
- Arming-cancel temp-file discard is best-effort; not exercised against a real half-written movie.
- sqlite3_flutter_libs ^0.6.0+eol is EOL and appears unused, but historically supplied drift's native
  SQLite binaries. Deliberately left alone — removal needs a runtime-verified cleanup.
- Demoted from the PROJECT.md decision index to hold the 80-line cap (files retained, still readable):
  decisions/2026-07-10-mitosis-run-contract.md and decisions/2026-07-11-receipts-ci-fix-and-relaunch-semantics.md
  — both mitosis-engine-era operational decisions, superseded in relevance now that 31/31 MSPs are shipped.

## Pick up here
Human hardware-verifies `fix/macos-camera-lifecycle` via `flutter run -d macos` (NEVER the raw binary):
preview live on modal open, indicator on at open and OFF after close/cancel, and the picker switching
between built-in and external for both preview and recording. Then merge both branches (human-gated per
decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md).
