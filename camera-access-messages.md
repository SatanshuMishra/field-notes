# camera-access-messages: Spec and fix the video recorder's refused-camera-access message on macOS and Android
Status: active
Updated: 2026-10-17T05:49:35.162Z
Next ids: c5 D2 R6 S4

## Goal

When someone refuses camera (or microphone) access, the video recorder must say so with cameraPermissionMessage ("Field Notes needs camera and microphone access…") on both macOS and Android. Today macOS says "Could not find a camera" and Android shows a blank "Ready to record" then "Could not start recording". Spec both fixes with the interphase bug pathway, then dispatch them with mitosis as draft PRs.

## Done when

- [ ] c1 macOS: after the camera prompt is refused, the video recorder shows cameraPermissionMessage, not videoDeviceListMessage.
- [ ] c2 Android: after the camera or microphone prompt is refused, the video recorder shows cameraPermissionMessage straight away, instead of a blank Ready to record followed by videoStartMessage on Start.
- [ ] c3 The allowed paths are unchanged: a Mac with no camera still says videoDeviceListMessage and keeps it when Start is pressed, and recording still works on the owner's Mac and on the Note10+ when access is allowed.
- [ ] c4 The whole suite and analyzer are clean on the merged result.

## Where things stand

Converted from the old ledger.

## Next step

Start a fresh session on origin/main and run the interphase bug pathway (Skill interphase:bug) for both refusals. First write the two failing tests that reproduce them. macOS: in test/features/capture/video/no_camera_test.dart, the test 'a refused camera permission on macOS asks for access' (fake at lines ~99-103) must make the camera_macos channel return the plugin's real reply {"error": {"code": "CAMERA_INITIALIZATION_ERROR", "message": "Permission not granted"}} instead of throwing a PlatformException; that test should then fail on main. Android: a new test in which camera start-up in CameraVideoRecorder._initialise (lib/features/capture/platform/camera_video_recorder.dart ~284) throws CameraException('CameraAccessDenied'), expecting cameraPermissionMessage before Start. Then settle the two fix sites with the owner: the vendored plugin's Dart error mapping (recommended) and the openSession failure signal. Write the spec at docs/specs/camera-access-messages.md and dispatch with mitosis, using ~/.mitosis/field-notes/live-run-defects/ as the run template. Sequence against the recorder-android-followups branches.

## Decisions in force

- D1 Fix both platforms' refused-camera messages in a new thread, specced and dispatched with mitosis in a fresh session: A new thread, camera-access-messages, covers both platforms. A fresh session specs them with the interphase bug pathway and dispatches the fixes with mitosis as draft PRs, the owner's usual flow. It stays separate from recorder-android-followups because that thread's fixes are recorder semantics and layout, but the two touch neighbouring recorder files, so their branches must be sequenced (risk 01M3NSF3ZKVNES4Q3C3WQ3W2TQ).

## Open risks

- R1 macOS root cause, confirmed by code and live: the vendored camera_macos plugin never sends a refusal as a platform error. Swift listDevices calls requestPermission (video only) and, when refused, replies result(FlutterError(code: "CAMERA_INITIALIZATION_ERROR", message: "Permission not granted").toFlutterResult), which is the success value {"error": {code, message, details}} (CameraMacosPlugin.swift ~265, FlutterMacOS+Extension.swift). Its Dart listDevices finds no "devices" key and throws FlutterError("Invalid args: invalid platform response") (camera_macos_method_channel.dart ~41). The app's new branch in CameraMacosVideoRecorder.listDevices (camera_video_recorder.dart ~424) only matches `on PlatformException` with message 'Permission not granted', so the catch-all shows videoDeviceListMessage. The merged test passed only because it fakes a PlatformException (no_camera_test.dart ~99-103). Live: clean guest, fresh install, Don't Allow on the camera prompt gave 'Could not find a camera. Connect one and try again.' Bears on c1.
- R2 macOS fix-site choice for the spec: (a) recommended, since the plugin is vendored: make its Dart listDevices (and the other methods that `throw result["error"]` as a raw Map at camera_macos_method_channel.dart ~116, 154, 198) turn an {"error": {...}} reply into PlatformException(code, message, details); the app branch then works unchanged. (b) App-side: also catch FlutterError whose message is 'Invalid args: invalid platform response'. That is fragile, because the same message covers any malformed reply. Whichever is chosen, the acceptance test must fake the channel's real reply map, not a PlatformException. Bears on c1.
- R3 Android root cause, confirmed live and by code: availableCameras() works without permission, so listDevices succeeds and the composer goes idle ('Tap when you’re ready', blank preview). The refusal only surfaces inside CameraVideoRecorder._initialise (camera_video_recorder.dart ~280-307), where controller.initialize() throws CameraException('CameraAccessDenied' or 'AudioAccessDenied', from camera_android_camerax 0.7.4+2 CameraPermissionsManager.java) and the catch-all wraps it as VideoRecorderException(videoStartMessage). That failure sits in the session's ready future and is only seen when Start awaits it, giving 'Could not start recording. Check your camera and try again.' The fix needs two parts: map those CameraException codes to cameraPermissionMessage, and surface a session start-up failure to the composer as the denied state at once. VideoRecorder.openSession returns only a Widget today, so the second part is an interface change touching both recorders and every fake recorder in the tests. Bears on c2.
- R4 Unverified: what macOS does when camera is allowed but the microphone is refused. The vendored plugin's requestPermission asks for video only, and the guest run never showed a microphone prompt. cameraPermissionMessage names both camera and microphone. Check it live on the host or guest before the spec fixes the wording or the refusal set.
- R5 Live-test constraints that bind this work: never run flutter drive or flutter test integration_test/... against the owner's phone (it uninstalled their real app on 2026-09-29); use a .plain test build with its own package (testkit android-plain-build.patch), check `pm path` before and after, and uninstall only that exact id. The owner's real Android app dev.satanshumishra.field_notes is currently NOT installed. On macOS, never touch dev.satanshumishra.fieldNotes (the real journal); test in the Parallels guest, reverted to the `clean` snapshot first: open ~/Parallels/macOS.macvm, press Actions > Revert To Snapshot by AX, then open again. The guest disk still holds the 2026-09-29 run, so it needs reverting. The guest has no camera, so the refused path is testable there but a real recording is not. Mute the guest, and check the phone call state before any audio.

## Settled, do not reopen

- S1 Out of scope: The voice recorder's microphone-refusal message on either platform (not checked in the 2026-09-29 run).
- S2 Out of scope: Recorder semantics and camera-chip layout, which belong to the recorder-android-followups thread.
- S3 Out of scope: White text on the coral accent at 3.7:1 contrast; this is the prototype colour the owner chose.

## Where the details live

- Recorder platform code: macOS listDevices (lines ~419-439) and Android _initialise (lines ~280-307): lib/features/capture/platform/camera_video_recorder.dart
- Video composer: _prepare (lines ~94-125) and _start/_failBackToIdle (lines ~178-255): lib/features/capture/video/video_composer.dart
- Recorder messages: cameraPermissionMessage, videoStartMessage, videoDeviceListMessage: lib/features/capture/video/video_recorder.dart
- Vendored camera_macos Dart channel: listDevices throws FlutterError when the reply has no devices (line ~41); other methods throw the raw error map (lines ~116, 154, 198): third_party/camera_macos/lib/camera_macos_method_channel.dart
- Vendored camera_macos Swift: requestPermission asks for video only (line ~220); listDevices refusal returns FlutterError(...).toFlutterResult as a success map (line ~265); initialize refusal likewise (line ~615): third_party/camera_macos/macos/Classes/CameraMacosPlugin.swift
- toFlutterResult wraps an error as {"error": {code, message, details}}: third_party/camera_macos/macos/Classes/FlutterMacOS+Extension.swift
- Merged test whose fake (PlatformException 'Permission not granted', lines ~99-103) is a reply the real plugin never sends: test/features/capture/video/no_camera_test.dart
- Android plugin refusal codes CameraAccessDenied and AudioAccessDenied (camera_android_camerax 0.7.4+2, CameraPermissionsManager.java lines 31-39); thrown as CameraException from createCameraWithSettings (android_camera_camerax.dart ~line 370): U+007E/.pub-cache/hosted/pub.dev/camera_android_camerax-0.7.4+2/android/src/main/java/io/flutter/plugins/camerax/CameraPermissionsManager.java
- PR that shipped the incomplete macOS refusal fix: https://github.com/SatanshuMishra/field-notes/pull/237
- Previous spec (git-ignored, main checkout only): camera sections 4.6, 8.6, 10.12-10.14: /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/live-run-defects-and-garden-speed.md
- Previous spec's settled decisions (git-ignored): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/live-run-defects-and-garden-speed.decisions.md
- Live evidence, macOS guest: cam-refused.png (refused), cam-allowed.png (allowed, no camera): U+007E/.mitosis/field-notes/testkit/work/postmerge/results/mac-guest/
- Live evidence, Note10+: a-cam-refused.png (blank Ready to record), a-cam-refused-after.png (Could not start recording): U+007E/.mitosis/field-notes/testkit/work/postmerge/results/android/
- Live testing method (Parallels guest, phone test builds, safety rules): /Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/memory/live-macos-testing-method.md
- Test build patches: android-plain-build.patch (.plain package) and macos-plain-build.patch (.plain bundle id + PROBE_AX switch): U+007E/.mitosis/field-notes/testkit/patches/
- Guest driver (g, guest_lib.zsh with launch/press/ax/shot/alerts; ax_button for TCC prompts) and Android driver a.py: U+007E/.mitosis/field-notes/testkit/work/dmgs-tools/g and ~/.mitosis/field-notes/testkit/work/postmerge/a.py
- Previous mitosis run to copy as a template (CHARTER.md, worker-rules.txt, dispatch.zsh, accept.zsh, pr_adapter.py): U+007E/.mitosis/field-notes/live-run-defects/
- Old ledger record: thread 01M3QWADN4HGW6RH7DZJZFAJ53 in refs/logbook/archive/ledger
