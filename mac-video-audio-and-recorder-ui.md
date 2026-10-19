# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T13:21:56.036Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 3. mic-recovery (round 2, 2dd055e0) and video-starts-like-a-camera (round 3, 2d0091ff) are green and wait for ship; each green MSP is merged up the stack. hearing-and-ring is in round 3 at 32ff2edc: after its green round 2, the Android lab showed its input panel rows and drop-down choices nameless on Android (named on main), because a Semantics wrapper around Pressable splits each row into an empty outer node and a named inner one; both are fixed with receipts, its suite is running in suite-hearing and its code-review brief is rendered in review/round-3/briefs. button-consistency is in round 2 at adcefe11: suite clean, conformance 5.12-5.14 met, findings C1 (settings text field padding shows the text cursor but ignores clicks), C2 (three pass-through hover wrappers) and U1 (the Android rows); the validator is running. The same wrapper split remains in button-consistency's meadow_tabs.dart and settings_segmented.dart (use Pressable's inMutuallyExclusiveGroup). android_dump_rules_test fails now and then under machine load and is not a finding. Smoke: Windows is unproven while the owner's PC is offline on Tailscale; the Android camera-off notice passes; the Mac repro app is building in harness/repro-tree from 32ff2edc for the built-in microphone check (a rebuilt ad-hoc app may raise a microphone prompt only the owner can answer). Known gap outside the fixed classes: a dead stretch just before a pause is dropped if the take is resumed rather than kept. Root causes, both reproduced on real hardware: (a) macOS AVAudioEngine stops itself when a Bluetooth headset (HS80) switches HFP/A2DP as the mic reopens, and record_macos 2.1.1 neither restarts nor reports it; (b) camera_macos replies "started" about 1.05 s before the movie begins.

## Next step

Record button-consistency's round 2 verdicts and verdict, merge hearing-and-ring into it, fix the confirmed findings and the two remaining wrapper sites, then round 3 with an Android rerun of the input panel and drop-down names. Dispatch hearing-and-ring's round 3 code reviewer when its suite lands. Run the Mac 5.9 check when the repro app builds, then ship.

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
- review/checks/ in the run home: the diagnoses' selecting checks and repro tests.
- suite-tree/ and suite-hearing/ in the run home: detached worktrees for review suites away from mitosis's live worktrees, one per concurrent run.
