Status: accepted
Date: 2026-07-22
Thread: journal-app-design

## Context
The macOS app rendered a BLACK, empty window; engine logged `rasterizer.cc: Last layer tree was null`
(zero frames). This also explains why VM-RPC screenshots failed on relaunches, resolving the open
ambiguity in decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md.

## Decision
Root cause: launching the standalone `.app` binary directly produces NO first frame in this
environment. Ruled out: stale instances (clean restart still black), data (empty DB still black),
widget errors (no exception logged). `flutter run -d macos` renders correctly. So: to run a VISIBLE
app for testing, ALWAYS use `flutter run`, never the raw binary.

## Consequences
- VM-RPC `_flutter.screenshot` works ONLY against a `flutter run` instance.
- Not an app-code bug: MainFlutterWindow.swift is stock; "merged UI/platform thread" is a Flutter
  3.44.6 macOS default. Deeper engine root-cause deferred — the `flutter run` workaround suffices.
