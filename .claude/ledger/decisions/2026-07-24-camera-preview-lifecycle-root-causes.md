# Camera preview/lifecycle defects: root causes are all Dart-side

Status: accepted
Date: 2026-07-24

Four reported macOS video-capture defects root-caused to app code, NOT the vendored Swift plugin,
which already exposed every capability needed.

- Dead preview / no menu-bar indicator: `buildPreview()` was reachable only from `_start()`, so
  `CameraMacOSView` mounted only on Record, so `initCamera` -> `startRunning()` never ran while the
  modal merely sat open. The absent indicator was accurate reporting, not a rendering bug.
- Camera never released: `controller.destroy()` had ZERO call sites in app code. `_resetSession()`
  only nils Dart fields; native `stopRecording` never calls `stopRunning()`. Only `destroy` does.
- Wrong camera: `listDevices()` was called only to test `isNotEmpty` and discarded; no `deviceId`
  passed, so the plugin fell through to `capturedVideoDevices.first` (OS enumeration order).
- `videoRecorderProvider` is NON-autoDispose, so the recorder is reused across opens; any leaked
  session or stale `_controller`/`_ready` survives into the next open.

First fix attempt still leaked: `release()` returned early when `_controller` was null — exactly the
0.5-2s init warmup window. LESSON: gate release on destroy-intent, never on controller presence.
