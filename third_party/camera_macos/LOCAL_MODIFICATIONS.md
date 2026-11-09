# camera_macos — local modifications

This is a vendored copy of `camera_macos` (pub name `camera_macos`, version `0.0.9`),
sourced from https://github.com/riccardo-lomazzi/camera_macos.

Field Notes carries local fixes on top of the upstream sources. A future re-vendor
(bumping the upstream version or re-cloning) MUST re-apply the deltas below, or the
macOS camera will regress. Verify each item is still present after any upstream sync.

## Delta

All changes are in `macos/camera_macos/Sources/camera_macos/CameraMacosPlugin.swift` unless noted.

1. videoRotationAngle crash fix — the capture-connection rotation setter path that
   crashed on real hardware was corrected during the original capture-finalize work
   (PR #33). Removing it reintroduces a hard crash when recording starts.

2. Self-finalizing movie-file-output recording path — the `AVCaptureMovieFileOutput`
   recording/finalization path was reworked so `stopRecording` returns a finalized
   file. Do not revert to the asset-writer-only path.

3. `latestBuffer` serialized access — `latestBuffer` is backed by private storage
   guarded by an `NSLock` (computed property with locked get/set). This removes the
   cross-thread check-then-use race between the capture-output queue (writer) and the
   texture/raster thread (`copyPixelBuffer`). Upstream exposes `latestBuffer` as an
   unguarded `CVImageBuffer!`.

4. `imageFromSampleBuffer` base-address lock balance — every
   `CVPixelBufferLockBaseAddress` is paired with an unlock on all return paths via a
   `defer`, and `context.makeImage()` is a guarded `let` (no force-unwrap). Upstream
   returns early on two guards without unlocking and force-unwraps `makeImage()`,
   which starves the `AVCaptureVideoDataOutput` pool (frozen preview) once
   `copyPixelBuffer` tolerates nil.

5. Preview stream gated on a real subscriber — the per-frame full-frame conversion and
   main-thread copy in `copyPixelBuffer` runs only when
   `imageStreamHandler.eventSink != nil`. The app never attaches an image-stream
   listener, so this is a no-op in practice; upstream runs the conversion on every
   frame regardless.

6. Swift Package Manager support: the sources live in
   `macos/camera_macos/Sources/camera_macos/`, described by
   `macos/camera_macos/Package.swift`, and the podspec's `source_files` points there
   so CocoaPods still builds the plugin. Swift Package Manager compiles each file with
   only its own imports, so `macos/camera_macos/Sources/camera_macos/URL+Extension.swift`
   imports AppKit for `NSWorkspace`. Upstream has no `Package.swift` and imports only
   Foundation there, which fails with "cannot find 'NSWorkspace' in scope".

7. `pauseRecording` and `resumeRecording` methods: the plugin answers the method-channel
   calls `pauseRecording` and `resumeRecording`, and `CameraMacOSController`, the
   platform interface and the method-channel implementation expose them as
   `Future<bool?> pauseRecording()` and `Future<bool?> resumeRecording()`. Each finds the
   session's `AVCaptureMovieFileOutput` as `stopRecording` does and, when the plugin and
   that output are both recording, calls its `pauseRecording()` or `resumeRecording()`
   and replies `true`, so a paused take resumes into the same file and `stopRecording`
   still finalizes it. Otherwise it replies a real `FlutterError` with code
   `NOT_RECORDING` (not a success reply carrying an `error` map). Upstream has neither
   method.

8. Microphone discovery as `record` lists it: `initCamera` looks up `audioDeviceId` among
   `.builtInMicrophone` and `.externalUnknown` plus, under `if #available(macOS 14.0, *)`,
   `.microphone` and `.external`, so a Bluetooth headset (`.microphone` on macOS 14 and
   later) or a USB microphone (`.external`) that `record` lists is found. When an id is
   given and no discovered device has it, the plugin records from
   `AVCaptureDevice.default(for: .audio)` instead of adding no microphone. The id is read
   with `as? String`, so an absent, empty or non-string value records from the system
   default as before. Upstream searches only `.builtInMicrophone` and `.externalUnknown`
   and records without sound when the id is not found.

9. No preview layers on a running session: after `startRunning()`, `initCamera` no longer
   creates `self.previewLayer` with `AVCaptureVideoPreviewLayer(session:)` nor hands the
   factory a second `AVCaptureVideoPreviewLayer(session:)` when `useMovieFileOutput` is
   set. Field Notes draws the camera through a Flutter `Texture` and never shows either
   layer, and connecting a layer to a running session changes its connections, which is
   followed by the screen flash that turns off macOS Video Effects (Portrait, Studio
   Light, Backgrounds). The capture session is configured once, started once, and given
   nothing afterwards. A re-vendor MUST keep both `AVCaptureVideoPreviewLayer(session:)`
   calls out of `initCamera`; upstream creates them on every open.
