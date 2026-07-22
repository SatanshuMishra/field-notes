Status: accepted
Date: 2026-07-21
Thread: journal-app-design

## Context
Visual verification of the running macOS app needs a screenshot, but `screencapture` fails with
"could not create image from display": the shell's host process is com.anthropic.claudefordesktop,
which lacks Screen Recording TCC, and macOS only activates the grant after a full quit+reopen of
Claude Desktop. `flutter screenshot` can't substitute either (`device` type needs the same TCC;
`skia` type emits a non-viewable .skp; `rasterizer` was removed in Flutter 3.44).

## Decision
Capture the running Flutter app's frame by calling the engine RPC `_flutter.screenshot` over the
Dart VM Service WebSocket, decoding the base64 PNG. Reusable script: scratchpad/vm_screenshot.dart,
run as `dart vm_screenshot.dart ws://127.0.0.1:<port>/<token>/ws <out.png>`. Derive the WS URL from
the app's stderr line "Dart VM service is listening on http://...". This is the standard visual-check
path for macOS in this environment.

## Consequences
- Screenshots need NO Screen Recording permission and work in-session, every session.
- Only screenshotting is unblocked. DRIVING the app (click/keyboard injection via Accessibility) is
  still TCC-gated and needs a full Claude Desktop quit+reopen. Rejected the quit+reopen-first path as
  the default because the VM RPC removes the need for it just to see the UI.
- Launch the app directly (not via `open`) to capture stderr + the VM service URL in one shell.
