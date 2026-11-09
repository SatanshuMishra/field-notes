# camera_android_camerax — local modifications

This is a vendored copy of `camera_android_camerax` (pub name `camera_android_camerax`, version
`0.7.5`), by the Flutter authors, sourced from https://github.com/flutter/packages/tree/main/packages/camera/camera_android_camerax
through the pub cache (`~/.pub-cache/hosted/pub.dev/camera_android_camerax-0.7.5`).

Copied: `LICENSE`, `AUTHORS`, `CHANGELOG.md`, `README.md`, `pubspec.yaml`, `lib/`, `pigeons/`,
`android/build.gradle.kts`, `android/settings.gradle.kts`, `android/lint-baseline.xml` and
`android/src/main/`. Left out: `example/`, the Dart `test/` folder, `android/src/test/`,
`skills/`, `ci_config.yaml`, `skills_lint.yaml`, `TESTING.md`, `CONTRIBUTING.md` and
`analysis_options.yaml`.

Field Notes changes only when the plugin binds video capture. Upstream binds video capture to
the camera lifecycle when a take starts, which makes CameraX rebuild its camera session at the
moment recording should begin, and unbinds it again when the take stops. Field Notes opens the
camera with video capture already bound, so a take starts without a session rebuild and the next
take starts the same way. A future re-vendor (bumping the upstream version or re-copying) MUST
re-apply the deltas below, or Android takes go back to waiting on a session rebuild after the
countdown ends. Verify each item is still present after any upstream sync.

## Delta

1. `AndroidCameraCameraX.initializeCamera` in `lib/src/android_camera_camerax.dart`: the first
   `bindToLifecycle` call binds `preview!`, `imageCapture!` and `videoCapture!` together, in the
   one camera session it opens. Upstream binds `preview!`, `imageCapture!` and `imageAnalysis!`
   there and binds `videoCapture` only in `startVideoCapturing`; its comment "Video capture is
   bound at first use instead of here." is removed. In `startVideoCapturing`, the unbind of
   `imageAnalysis!` and the bind of `videoCapture!` return early because neither needs doing,
   and image streaming still binds `imageAnalysis` when it starts.

2. `AndroidCameraCameraX.stopVideoRecording` in `lib/src/android_camera_camerax.dart`: the call
   `_unbindUseCaseFromLifecycle(videoCapture!)` after the recording finalizes is deleted, so
   video capture stays bound for the next take. Upstream unbinds it there.

3. `AndroidCameraCameraX.startVideoCapturing` in `lib/src/android_camera_camerax.dart`: the
   `setTargetRotation` call runs before every take unless the capture orientation is locked.
   Upstream also requires `shouldSetDefaultRotation`, because it binds video capture at take
   start and so picks up the screen's rotation then. With video capture bound when the camera
   opens, the rotation would otherwise stay at what it was on opening, and a take started after
   turning the phone would save sideways. Setting the rotation does not rebuild the session.
