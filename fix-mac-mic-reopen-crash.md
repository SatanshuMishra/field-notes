# fix-mac-mic-reopen-crash: Fix the macOS microphone reopen crashes (1.4.0 build 43)
Status: active
Updated: 2026-10-22T05:40:23.045Z
Next ids: c5 D1 R3 S1

## Goal

Stop Field Notes on macOS from crashing (SIGABRT in installTap, SIGSEGV use-after-free after engine stop) when a slow microphone start makes the watchdog reopen recorders, so several AVAudioEngines configure one microphone in parallel.

## Done when

- [ ] c1 At most one microphone engine start or teardown runs at a time per device on macOS, proven by a test with a fake recorder whose start takes longer than 2 s
- [ ] c2 installTap can no longer abort the app with an uncaught Objective-C exception
- [ ] c3 Stopping an engine can no longer free it while Apple's queued audio-unit callbacks still use it
- [ ] c4 A video take with a forced slow microphone start does not crash on the VM lab macOS instance

## Where things stand

interphase:bug grounding, slug mac-mic-reopen-crash; spec files started in docs/specs. Owner asked for an architectural fix, not a patch: every feature (take, level meter, input list) opens its own recorder and native engine on one microphone, and nothing owns the device. A scout is researching Apple's guidance on engine ownership.

## Next step

Wait for the owner's answer to the interphase intent round (I1 goal, I2 why, I3 success, pathway and split), save it to docs/specs/mac-mic-reopen-crash.decisions.md, then ask the first frontier round.

## Decisions in force

## Open risks

- R1 The macOS lab VM runs with --no-audio, so no real-engine test can run there until the golden image gets an input device. Bears on c4.
- R2 Apple says Cocoa is not exception-safe, so catching the installTap exception only buys a clean failure; the engine must be discarded, never reused. Bears on c2.

## Settled, do not reopen

## Where the details live

- Crash sites: third_party/record_macos/macos/record_macos/Sources/record_macos/delegate/RecorderStreamDelegate.swift (configure, installTap, stop)
- Per-recorder queue: third_party/record_macos/macos/record_macos/Sources/record_macos/RecordMacOsPlugin.swift:104
- Watchdog reopen: lib/features/capture/audio/live_audio_capture.dart (_reopen, _openWithin, _lostAfter)
- Spec files: docs/specs/mac-mic-reopen-crash.{decisions.md,record.json}
- Earlier decisions: docs/adr/0005 (own queue per recorder, 2 s native start bound), docs/adr/0006 (microphone opens with the recorder)
