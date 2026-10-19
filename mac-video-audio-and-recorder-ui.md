# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T09:05:14.941Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 3. mic-recovery is green (round 2) with its advisories fixed at 2dd055e0 and no slow checks left; it waits for ship. It is merged into video-starts-like-a-camera and hearing-and-ring. video-starts-like-a-camera has its round 1 fixes committed at 8c5d0ff0 (C2: the Mac clock runs only once the movie has begun and the take is not paused; U1/U2: the pause tests' fake camera sends the movie start; advisory C4: one guarded warm-up), its round 2 suite passes apart from the known-flaky android_dump_rules_test (passes alone at the head and on main), and its round 2 fixes are committed at 2d0091ff (C1: each Mac take's clock starts from zero; advisory C2: one sendMacMovieStart test helper); capture and accessibility tests pass and its round 3 suite runs in suite-tree; it is not yet merged into hearing-and-ring, whose tree the running resume uses. hearing-and-ring's Lane 6 (hearing-notices) failed because the edit guard locked one pump in its own new test; a second resume re-dispatches it from handoff/hearing-and-ring-lane-6.md, and Lanes 7-9 plus all 12 button-consistency Lanes wait on it. Known gap outside the fixed classes: a dead stretch just before a pause is dropped if the take is resumed rather than kept. Smoke runs happen once on the top of the stack after all four MSPs build. Root causes, both reproduced on real hardware: (a) macOS AVAudioEngine stops itself when a Bluetooth headset (HS80) switches HFP/A2DP as the mic reopens, and record_macos 2.1.1 neither restarts nor reports it, so a take saves under a second of sound; (b) camera_macos replies "started" before the movie begins, so every take holds about 1.05 s of sound recorded before the picture.

## Next step

When the C1 diagnosis replies, save review/round-2/video-starts-like-a-camera.stale-clock-on-next-take.diagnosis.json, record it, re-run the verdict and run the round 2 fix pass (C1 receipt, the reset in start(), advisory C2); when the second resume (build-1-resume-2.out) ends, read its last JSON line and start round 1 for hearing-and-ring and button-consistency.

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
- suite-tree/ in the run home: detached worktree for running a review suite away from mitosis's live worktrees.
