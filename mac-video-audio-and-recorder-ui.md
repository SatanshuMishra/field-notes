# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T05:42:46.210Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 2, resuming the first build. mic-recovery is committed and gated; its gap filler padded the first chunk after writing began, now fixed on its branch and merged into video-starts-like-a-camera. Lanes mac-movie-start-signal and shared-pressable failed (that padding; a wrong mouse device id in its tests) and resume from hand-offs in the run home's handoff/; everything stacked after them waits. mic-recovery breaks camera_macos_audio_input_test (3) and voice_level_response_test (2), all passing on main: a take left running when the recorder screen is torn down keeps its watchdog timer, because neither the voice composer nor voiceRecorderProvider cancels or disposes it; this goes to mic-recovery's review round 1, whose suite (red only in those 5 tests plus android_dump_rules_test, which passes alone on main and on mic-recovery, so is load-flaky and not a finding) is done; its conformance audit returned A1 and A2 (rows of 5.1 and 5.2 whose tests belong to later MSPs' Steps, saved in review/round-1/arrays/), its security review returned S1-S4, all LOW (S1: the Dart watchdog's reopen falls back to the default microphone when the chosen one dropped; S2: the orphaned-take watchdog; S3: abandoned native recorders pile up while starts hang, no backoff; S4: duplicated start and rebuild in RecorderStreamDelegate.swift), threats appended to review/mic-recovery.obligations.md; its code reviewer is running. Smoke runs happen once on the top of the stack after all four MSPs build. Root causes, both reproduced on real hardware: (a) macOS AVAudioEngine stops itself when a Bluetooth headset (HS80) switches HFP/A2DP as the mic reopens, and record_macos 2.1.1 neither restarts nor reports it, so a take saves under a second of sound; (b) camera_macos replies "started" before the movie begins, so every take holds about 1.05 s of sound recorded before the picture.

## Next step

When the resume (output build-1-resume.out) ends, read its last JSON line; when mic-recovery's suite (review/round-1/mic-recovery.suite.txt) ends, dispatch its code, conformance and security reviewers; review each further MSP as it commits.

Needs: D2, R1.

## Decisions in force

- D2 Interphase hand-off (re-cut): build four stacked pull requests with no file shared across them: Re-cut the Steps. MSPs mic-recovery, video-starts-like-a-camera, hearing-and-ring and button-consistency on fix/mac-video-audio-and-recorder-ui cut from origin/main 9eb6c237, stacked in that order, 23 Steps; recorded as an I4 assumption in the spec. ADRs 0005 and 0006 and the glossary term Hearing ship with the first pull request.

## Open risks

- R1 The lab macOS guest has no microphone or camera, so the silent take and the lag can only be proven end to end on real Mac hardware. Bears on c1.

## Settled, do not reopen

## Where the details live

- Spec folder: docs/specs/mac-video-audio-and-recorder-ui.* (decisions, record, guard, and the reproduction tests in .repro.dart, destined for test/features/capture/video/mac_video_sound_repro_test.dart).
- Owner's evidence takes: the three 2026-10-18 .mp4 blobs under the app container's Documents/media/blobs (52/, 17/, 92/).
- Mac recorder: lib/features/capture/platform/camera_video_recorder.dart; sound capture lib/features/capture/audio/live_audio_capture.dart; native join macos/Runner/LiveAudioBridge.swift; camera plugin third_party/camera_macos.
- Run home ~/.mitosis/field-notes/mac-video-audio-and-recorder-ui: charter, run.zsh, rounds.md, review/ (assumption files, obligations, per-round diffs and suites), handoff/ (notes for resumed Lanes), build outputs, base-tree/ (detached worktree at 9eb6c237 for checking failures against main), and harness/ (real-hardware repro app for the 5.9 Mac check). Run dir ~/.mitosis/runs/field-notes/mac-video-audio-and-recorder-ui.
