# fix-mac-mic-reopen-crash: Fix the macOS microphone reopen crashes (1.4.0 build 43)
Status: active
Updated: 2026-10-22T05:33:01.600Z
Next ids: c5 D1 R1 S1

## Goal

Stop Field Notes on macOS from crashing (SIGABRT in installTap, SIGSEGV use-after-free after engine stop) when a slow microphone start makes the watchdog reopen recorders, so several AVAudioEngines configure one microphone in parallel.

## Done when

- [ ] c1 At most one microphone engine start or teardown runs at a time per device on macOS, proven by a test with a fake recorder whose start takes longer than 2 s
- [ ] c2 installTap can no longer abort the app with an uncaught Objective-C exception
- [ ] c3 Stopping an engine can no longer free it while Apple's queued audio-unit callbacks still use it
- [ ] c4 A video take with a forced slow microphone start does not crash on the VM lab macOS instance

## Where things stand

Not started.

## Next step

Run the interphase:bug interview (full lane) for the macOS microphone reopen crashes and get the read-back approved.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Crash sites: third_party/record_macos/macos/record_macos/Sources/record_macos/delegate/RecorderStreamDelegate.swift (configure, installTap, stop)
- Per-recorder queue: third_party/record_macos/macos/record_macos/Sources/record_macos/RecordMacOsPlugin.swift:104
- Watchdog reopen: lib/features/capture/audio/live_audio_capture.dart (_reopen, _openWithin, _lostAfter)
