Status: accepted
Date: 2026-07-21
Thread: journal-app-design

## Context
Visual verification of the running macOS app needs a screenshot, but `screencapture` fails
("could not create image from display"): the host process is com.anthropic.claudefordesktop, which
lacks Screen Recording TCC until a full Claude Desktop quit+reopen. `flutter screenshot` can't
substitute (`device` needs the same TCC; `skia` emits a non-viewable .skp; `rasterizer` gone in 3.44).

## Decision
Capture frames via the engine RPC `_flutter.screenshot` over the Dart VM Service WebSocket, decoding
the base64 PNG. Script: scratchpad/vm_screenshot.dart, run `dart vm_screenshot.dart
ws://127.0.0.1:<port>/<token>/ws <out.png>`; get the WS URL from the app's "Dart VM service is
listening on http://..." stderr line. Launch the app directly (not `open`) to capture that line.

## Consequences
- Screenshots need NO Screen Recording permission; works every session.
- Only screenshotting is unblocked; click-driving (Accessibility) still needs the Claude Desktop
  quit+reopen. Full detail: sessions/2026-07-21-05-journal-app-design.md.
