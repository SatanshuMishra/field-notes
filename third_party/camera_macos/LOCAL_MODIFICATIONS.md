# camera_macos — local modifications

This is a vendored copy of `camera_macos` (pub name `camera_macos`, version `0.0.9`),
sourced from https://github.com/riccardo-lomazzi/camera_macos.

Field Notes carries local fixes on top of the upstream sources. A future re-vendor
(bumping the upstream version or re-cloning) MUST re-apply the deltas below, or the
macOS camera will regress. Verify each item is still present after any upstream sync.

## Delta

All changes are in `macos/Classes/CameraMacosPlugin.swift` unless noted.

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
