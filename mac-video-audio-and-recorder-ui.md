# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T11:31:02.126Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 3. mic-recovery is green (round 2) with its advisories fixed at 2dd055e0 and no slow checks left; it waits for ship. video-starts-like-a-camera is green (round 3) at 2d0091ff with no slow checks left and waits for ship. Each green MSP is merged up the stack, so button-consistency holds all four. android_dump_rules_test fails now and then in a full suite while Workers load the machine (passes alone and in most folder runs, on main too); it is not a finding. hearing-and-ring is committed and gated (13 pass); its round 1 suite runs in its own worktree suite-hearing, with diff and 36 obligations written (criteria 5.1,5.4,5.5,5.6,5.7,5.8,5.13); its reviewers wait for the running resume to finish, since that run may re-gate its worktree. button-consistency has every Lane landed but Lane 22 (tap-target-scan), held with its scan test; a fourth resume lands it and gates the MSP, and the gate should find the scan inconclusive (it fails with the work) because the camera picker and the compact log card still tap through hand-built GestureDetectors. Converting the card onto Pressable needs care: Pressable's own button node splits from the action reveal's focus node and breaks the shell Tab-reach tests, so the conversion goes to round 1's fix pass. Also failing at button-consistency and passing on hearing-and-ring or main: onboarding_targets_test, day_detail_header_position_test, one log_actions_pill_reach_test, about_section_test and more in test/design; these become round 1 suite findings. Known gap outside the fixed classes: a dead stretch just before a pause is dropped if the take is resumed rather than kept. Smoke runs happen once on the top of the stack after all four MSPs build. Root causes, both reproduced on real hardware: (a) macOS AVAudioEngine stops itself when a Bluetooth headset (HS80) switches HFP/A2DP as the mic reopens, and record_macos 2.1.1 neither restarts nor reports it, so a take saves under a second of sound; (b) camera_macos replies "started" before the movie begins, so every take holds about 1.05 s of sound recorded before the picture.

## Next step

When the fourth resume (build-1-resume-4.out) ends, read its last JSON line, record lane assumptions, dispatch hearing-and-ring's round 1 reviewers once its suite (suite-hearing) finishes, and start button-consistency's round 1 (diff, obligations, suite in suite-tree, never switching a suite worktree while its run is live).

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
