# Session 2026-07-24-01 — journal-app-design

## Where it started
Resumed paused thread. User: voice saves now work; VIDEO recording still fails with "the same
critical issue as before." Ran systematic-debugging (two prior blind fixes had passed all offline
checks yet failed on the real camera, which cannot be autonomously tested — camera TCC + Accessibility
are human-gated).

## What shipped (all uncommitted on fix/macos-capture-finalize except 301232b)
- ROOT CAUSE FOUND (the real one): the app CRASHES in CameraMacosPlugin.initCamera the instant camera
  TCC is granted — before any preview/recording. `connection.videoRotationAngle = self.orientation`
  (third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift, was lines 507/524/541) throws
  NSInvalidArgumentException "-[AVCaptureConnection_Tundra setVideoOrientation:] Not supported" even
  though the guarding `isVideoRotationAngleSupported(...)` returns true (macOS 26 _Tundra quirk). Swift
  can't catch the ObjC NSException -> app terminates. All PR #32/#33 save-path work was downstream of a
  crash that never let capture start. decisions/2026-07-24-macos-videorotationangle-crash.md.
- FIX (uncommitted): deleted the three `videoRotationAngle` assignment blocks. `grep -rn videoRotationAngle
  third_party/camera_macos/macos/` = no matches. Mirroring guards (isVideoMirroringSupported) untouched.
  Rotation is cosmetic on a desktop webcam (frames upright; orientation defaults to 0).
- H2 FIX (COMMITTED 301232b): the movie-output delegate's two `pending(...)` FlutterResult replies now
  dispatch on the main thread (mirroring the file's :933 idiom). A real correctness fix (Flutter channel
  replies must be on the platform thread) — belongs in PR #33 regardless. NOTE: this was never the crash;
  it's downstream of init and never executed.
- [VIDCAP] instrumentation (uncommitted, 5 files): boundary logs across the video save path (Dart
  debugPrint + native NSLog). KEPT so the next human run finally exercises the save path (the crash was
  upstream, so these never fired yet). 3 avoid_print info-lints are expected throwaway noise.

## Tried and failed (the diagnostic journey — do not repeat)
- Blind hypotheses H1-H4 (delegate never fires / off-main reply / empty file / disk-verify) were ALL wrong:
  the flow never reaches recording. Instrumentation was the right call but the crash is upstream of it.
- Stale-build theory (chased hard, DISPROVEN): fresh binary is clean; `flutter clean && pub get && run`
  reproduced the SAME crash. There is NO stale bundle. The crash-report camera_macos UUID
  16970FA8-048E-30CD-87C9-200E83AAB10C == our fresh build's UUID (otool -l LC_UUID) -> it IS our binary.
- The misleading clue: the crash reason names `setVideoOrientation:`, but our binary's objc_methname table
  (otool -v -s __TEXT __objc_methname) contains ONLY setVideoRotationAngle:. The reason string is emitted
  by Apple's AVFCapture, NOT our code — the modern rotation setter internally routes through the legacy
  orientation path and throws. Lesson: a crash-reason selector need not exist in the app binary.

## Verification
- `grep -rn videoRotationAngle third_party/camera_macos/macos/` — expected + observed: no matches.
- `flutter build macos --debug` — exit 0, `✓ Built build/macos/Build/Products/Debug/field_notes.app`.
- Crash reproduced by human twice (raw + after flutter clean) — deterministic, in initCamera TCC callback.
- Video runtime save path: UNVERIFIED — awaits the human's post-fix `flutter run -d macos`.

## Running state
- none. All subagents completed. Working tree is on branch fix/macos-capture-finalize (checked out from
  main this session). Uncommitted: [VIDCAP] instrumentation + the videoRotationAngle removal, intermingled
  in third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift and 4 other files. HEAD = 301232b.

## Deferred + open
- HUMAN: `flutter run -d macos 2>&1 | tee /tmp/vidcap.log`, record -> stop, then `grep VIDCAP /tmp/vidcap.log`.
  Expect: NO crash, live preview, save reached. If save stumbles, the last [VIDCAP] line pinpoints the
  boundary (H1/H2/H3/H4 semantics in session log 2026-07-24 chat / the boundary map).
- AFTER a GREEN run: strip the [VIDCAP] instrumentation from all 5 files, commit the videoRotationAngle
  removal as a clean `fix(capture): ...` commit (keep 301232b H2 fix), push to PR #33 (git push works;
  gh pr merge is agent-blocked — human merges).
- If save stumbles: keep instrumentation, read the trace, fix the identified boundary.
- Pre-existing follow-ups (post-merge): latestBuffer preview-frame lockless race; 30-min auto-stop UI push.

## Pick up here
The crash fix is applied + compiles but is UNCOMMITTED and awaits the human's one verification run. Do NOT
re-diagnose — root cause is proven (decisions/2026-07-24-macos-videorotationangle-crash.md). Get the human's
run result; then either ship (strip logs + commit + push PR #33) or read the [VIDCAP] trace. Always run via
`flutter run -d macos`, never the raw binary.
