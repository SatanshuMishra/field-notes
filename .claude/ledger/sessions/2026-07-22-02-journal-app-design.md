# Session 2026-07-22-02 — journal-app-design

## Where it started
Resumed the paused thread with the open question "does real-mic voice actually persist, or
only fail-gracefully?" The human then reported (with a screenshot) that BOTH voice AND video
captures fail to save on the running app, and asked for a gated investigation:
reproduce -> root-cause -> research robust fix -> report, then implement the most robust fix.

## What shipped
- INVESTIGATION (subagent-driven, gated) established TWO DISTINCT root causes:
  - VOICE = a genuine native HANG. Direct real-hardware probe: mic granted, start OK, native
    `record_macos` 1.2.2 `stop()` never returned (>8s), no file, dispose() also hung. Mechanism:
    RecorderFileDelegate.stop() tears down the AVCaptureSession before the didFinishRecordingTo
    delegate fires, so the MethodChannel reply is never sent -> composer 20s timeout -> "Saving
    took too long." HIGH confidence.
  - VIDEO = a fast THROW, not a hang. The string "Could not finish that recording…" is
    `videoStopMessage` (video_recorder.dart:13-14), thrown only from CameraMacosVideoRecorder.stop()
    (camera_video_recorder.dart:197/212-213). App-side fully CLEARED (start succeeded, isRecording
    true, plugin's own writable caches/output.mp4 URL). Native root cause = camera_macos 0.0.9
    finalizes an AVAssetWriter while appending sample buffers on a `.concurrent` DispatchQueue —
    a data race (writer -> .failed, or 0-byte "file empty"). Known open bug: github.com/
    riccardo-lomazzi/camera_macos/issues/4 (open since 2023, fix only in a stale third-party fork,
    never merged; still present in 0.1.0). The robust AVCaptureMovieFileOutput path exists natively
    (`useMovieFileOutput`) but is dead code — never forwarded by the Dart API. MEDIUM-HIGH confidence.
- VOICE FIX IMPLEMENTED + HARDWARE-VERIFIED (branch fix/macos-capture-finalize, off fix/capture-save-hang):
  - `record` 6.2.1 -> 7.1.1 (record_macos 1.2.2 -> 2.1.1, the rewritten native impl). Resolved
    cleanly on Flutter 3.44.6 / Dart 3.12.2; no API migration needed (7.x surface == 6.x).
    Commit 4263c50 (pubspec.yaml + pubspec.lock).
  - SECOND bug found during verification: record_macos 2.1.1 stopRecording() does NOT create
    missing parent dirs, so the m4a was silently lost when the Caches/<bundle-id> subdir was absent.
    Fixed via resolveVoiceRecordingPath() -> directory.create(recursive:true) + 2 unit tests.
    Commit 3bbd440 (record_voice_recorder.dart + test).
  - Real-hardware probe (throwaway, removed): hasPermission=true, stop() RETURNED in 26ms (was an
    infinite hang), file exists 82,797 bytes, flushWaitMs=0. VOICE SAVE WORKS end-to-end.
  - flutter analyze clean; flutter build macos --debug exit 0; voice tests 17/17.
- Entitlements ruled OUT as a cause: Debug + Release both already carry app-sandbox +
  device.camera + device.audio-input (grep-confirmed). Camera preview works -> TCC is fine.

## Tried and failed
- Video real-hardware probe was NOT attainable autonomously: the separate `flutter test -d macos`
  binary was DENIED camera TCC (mic granted, camera not), so the probe never reached stop(). The
  human's signed app has camera access (preview works), so this is a probe-binary limit, not the
  defect. Video's exact native branch (ASSET_WRITER_FAIL .failed vs "file empty") is therefore
  still unconfirmed — see the 1-line diagnostic in Deferred.
- Could not finish video + guardrail + PR this session: hit the context ceiling (82%) after the
  voice fix. Chose to bank the verified voice win via handoff rather than truncate the untestable
  native video work.

## Verification
- `flutter pub get` — record resolved 7.1.1 / record_macos 2.1.1, no SDK conflict.
- `flutter analyze` — No issues found!
- `flutter build macos --debug` — exit 0 (field_notes.app built).
- `flutter test integration_test/_probe_voice_v7_test.dart -d macos` (throwaway, removed) — stop()
  returned 26ms; file 82,797 bytes; PASSED. Real mic signal confirmed (~-63 dBFS after warmup).
- `flutter test test/features/capture/voice/` — 17/17 passed (15 pre-existing + 2 new).

## Running state
- none. Voice agent completed; all Phase-1/2 investigation agents completed. Working tree clean on
  fix/macos-capture-finalize. Two voice commits (4263c50, 3bbd440) are LOCAL, unpushed. No PR.

## Deferred + open (the next session's work)
- VIDEO fix (decided approach — decisions/2026-07-22-capture-finalize-fix-strategy.md): vendor
  camera_macos 0.0.9 into the repo as a PINNED path dependency (e.g. third_party/camera_macos/),
  drop the hosted dep, and route RECORDING through Apple's self-finalizing AVCaptureMovieFileOutput
  (add it to the existing session; implement AVCaptureFileOutputRecordingDelegate; send the
  didFinishRecordingTo result to Dart). This ELIMINATES the AVAssetWriter concurrent-queue race at
  the root and REUSES the working AVCaptureVideoPreviewLayer preview + macOS platform view (the
  finicky part that already works). First read the plugin's dormant useMovieFileOutput native path;
  enable-as-is if sound, else implement the movie-file-output recorder cleanly. Rejected:
  camera_desktop (unproven), live external fork (drifts). Cannot camera-test autonomously — verify
  compile + analyze + Dart tests, and hand the human a validation checklist. camera_macos pubspec
  constraint is `>=0.0.8 <0.1.0` — the path dep replaces it.
- OPTIONAL cheap diagnostic to confirm the video native branch on the human's real app BEFORE the
  rewrite: camera_video_recorder.dart:213, change `throw VideoRecorderException(videoStopMessage,
  cause: error)` -> `throw VideoRecorderException('$videoStopMessage [$error]', cause: error)`; one
  real Save prints the native code (ASSET_WRITER_FAIL "File not saved" = writer .failed; "File is
  empty" = 0 frames). Confirms but does not change the fix direction.
- GUARDRAIL (cross-cutting, both surfaces + shared service): after stop(), do NOT trust the
  returned path. Poll File(path).existsSync() && lengthSync()>0 with a bounded backoff before
  declaring "saved"; surface native errors distinctly (do not collapse ASSET_WRITER_FAIL and
  "produced no file" into one message); treat 0-byte/missing as hard failure. Keep the existing
  bounded-timeout fail-safe (0a9902c). Voice-specific: record_macos 2.1.1 returns the path BEFORE
  the async didFinishRecordingTo flush completes, and the file lands in purgeable getTemporaryDirectory()
  Caches — the pipeline must copy bytes into the DB media blob promptly (capture_save_persist_test
  blob assertion already covers the blob landing).
- PR: when video + guardrail land, push fix/macos-capture-finalize and open a PR (MAIN THREAD only —
  gh pr create is blocked for delegated agents; git push works for all). Leave it OPEN for human
  review + the human's real-camera validation. Human explicitly authorized opening the PR.

## Pick up here
Voice is fixed + verified. Next: implement the VIDEO fix (vendor camera_macos -> AVCaptureMovieFileOutput,
reuse preview) and the verify-on-disk GUARDRAIL across voice/video/shared service, keeping the bounded
timeout; run analyze + build + Dart tests (camera is human-validated); then push and open the PR from the
main thread, left open for review. Always run the app via `flutter run -d macos`, never the standalone binary.
