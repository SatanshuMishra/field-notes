# Session 2026-07-22-01 — journal-app-design

## Where it started
Resumed at "31/31 shipped + runs on macOS; capture flows fixed in PR #32; next = local run +
confirm DB round-trip." Spanned 2026-07-21 late into 2026-07-22.

## What shipped
- LOCAL RUN + DB ROUND-TRIP PROVEN end-to-end (real capture write path, out-of-process):
  - `flutter build macos --debug` -> field_notes.app; launched, rendered the Today feed; live
    retrieval confirmed — feed content matched the on-disk SQL rows exactly (screenshot
    /private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/b11c0a3e-f319-48fb-863e-69f8a8e2cee7/scratchpad/live-feed-01.png).
  - On-disk DB: ~/Library/Containers/dev.satanshumishra.fieldNotes/Data/Documents/field_notes.sqlite
    (connection.dart:10-16: getApplicationDocumentsDirectory()/field_notes.sqlite). Schema =
    days/entries/entry_photos/media_blobs/settings. No seeding.
  - STORE: `flutter test integration_test/capture_save_persist_test.dart -d macos` (+2) — real
    JournalCaptureService.capture() path. After that process EXITED, a separate sqlite3 found the two
    new entry ids (entries 2->4). media_blobs stayed 1 = content-addressed dedup of identical test audio.
- CAPTURE SAVE-HANG fixed across voice/text/video (branch fix/capture-save-hang, commit 0a9902c):
  root cause = the PR #32 save "timeout" was a NO-OP (on TimeoutException it re-awaited the SAME
  still-running _persist future, unbounded). Fix: bounded fail-back that surfaces a timeout message +
  clears the saving state; stray future detached via unawaited(). See
  decisions/2026-07-22-save-hang-timeout-noop-root-cause.md.
- Receipts added (RED->GREEN): voice/text/video *_save_hang_test.dart (inject a never-completing
  recorder/persist; assert the save is bounded). Retargeted the three *_timeout_dedupe_test.dart to
  the surviving within-timeout invariant. Removed a dead import in the voice receipt.
- Restarted the app on the fixed code via `flutter run -d macos` — rendered the 2026-07-22 home
  (empty feed = new day; the 4 entries live under 2026-07-21 via Calendar). Screenshot
  .../scratchpad/newapp-check.png.

## Tried and failed
- Standalone .app BINARY launch -> BLACK window (engine logs "Last layer tree was null"; no first
  frame). Reproduced on clean restart AND empty DB; NO widget exception. `flutter run` renders fine.
  Root cause + workaround: decisions/2026-07-22-black-window-standalone-binary.md.
- Second live screenshot (4-row feed) never captured — same null-layer-tree of the binary launch.
  Confirmatory only; store proven out-of-process, retrieval proven by live-feed-01.
- My `flutter run` (VM :63713) "Lost connection to device" and exited when the turn was interrupted.

## Verification
- `flutter build macos --debug` — Built field_notes.app (exit 0).
- sqlite3 (out-of-process, after writer exited) — entries 2->4; ids 01ky44p03tnv8dstk7qm657pj2 (note)
  + 01ky44p05hj95gv33pzpkcjjr8 (voice) present.
- `flutter test integration_test/capture_save_persist_test.dart -d macos` — +2 passed.
- `flutter analyze` — No issues found!
- `flutter test test/features/capture/voice/voice_composer_save_hang_test.dart` — passed. Per the
  fixing agents: full voice suite 18, text 2, video 28 all green.

## Running state
- A `flutter run -d macos` app is RUNNING but was NOT started by this session's tracked shells
  (likely user-launched during the interrupt): flutter_tools PID 73282, dev-service PID 73788, VM
  service http://127.0.0.1:64788/z5dY23P9Q3M=/, plus the field_notes app process. Left running.
  To stop: `kill -9 73282 73788 2>/dev/null; pkill -9 -x field_notes`.
- All of this session's background shells (build, persist test, app launches) have exited.
- VM-RPC screenshot helper copied to
  /private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/b11c0a3e-f319-48fb-863e-69f8a8e2cee7/scratchpad/vm_screenshot.dart
  (works ONLY against a `flutter run` instance, never the standalone binary).

## Deferred + open
- Does a real-mic voice save now actually PERSIST, or only fail-gracefully? The fix kills the
  infinite hang (bounded error) but does NOT make a never-returning native recorder.stop() complete.
  Need the `flutter run` console line on a real Save to see whether stop() ever replies. If it
  genuinely hangs, debug the real macOS voice recorder (record plugin / AVAudioRecorder finalize
  under ad-hoc signing / mic TCC).
- Branch fix/capture-save-hang: push + open PR (not pushed).
- PR #32 decision doc (decisions/2026-07-21-capture-flow-root-cause-and-fix.md) still asserts a
  "bounded timeout"; corrected by the new decision but the old file's text stands.

## Pick up here (next session = bug-fixes / debugging)
On the running app, exercise a real voice Save and read the `flutter run` console: confirm it now
bounds-with-error instead of hanging, and determine whether the native stop() ever returns. If it
never returns, that is the next bug to root-cause (real voice recorder on macOS). Then push
fix/capture-save-hang + open the PR. Use `flutter run` (never the standalone binary) to get a visible app.
