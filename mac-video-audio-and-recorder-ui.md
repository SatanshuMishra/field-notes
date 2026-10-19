# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T12:04:28.357Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 3. mic-recovery is green (round 2) with its advisories fixed at 2dd055e0 and no slow checks left; it waits for ship. video-starts-like-a-camera is green (round 3) at 2d0091ff with no slow checks left and waits for ship. Each green MSP is merged up the stack, so button-consistency holds all four. android_dump_rules_test fails now and then in a full suite while Workers load the machine (passes alone and in most folder runs, on main too); it is not a finding. hearing-and-ring is committed and gated (13 pass); its round 1 suite has run and its reviewers are running (criteria 5.1,5.4,5.5,5.6,5.7,5.8,5.13). button-consistency is committed at 71b9768e and gated inconclusive on its tap-target scan (11 pass, 1 inconclusive), because the camera picker and the compact log card still tap through hand-built GestureDetectors; its round 1 suite has run and its three reviewers are running (criteria 5.12,5.13,5.14). Converting the card onto Pressable needs care: Pressable's own button node splits from the action reveal's focus node and breaks the shell Tab-reach tests, so the conversion goes to round 1's fix pass. Round 1 suite failures: hearing-and-ring fails input_dropdown_test (it counts InkWell rows; the shared dropdown now builds rows on Pressable). button-consistency fails in many folders (each failing folder's log sits beside its suite.txt in review/round-1); most, including the settings toggle size and the add-device panel failures, read the first or single DecoratedBox under a control and now hit Pressable's always-present hover fill (the toggle still draws 36x20), so a Pressable-level fix likely clears the class; the phone select no longer opening through PopupMenuButton is unexamined, and the toggle's focus ring now outlines the whole target instead of the track. Suite and mitosis findings are written to review/round-1/<msp>.suite-findings.json. Leftover test processes from earlier runs were loading the machine and are cleared. Known gap outside the fixed classes: a dead stretch just before a pause is dropped if the take is resumed rather than kept. Smoke runs happen once on the top of the stack after all four MSPs build. Root causes, both reproduced on real hardware: (a) macOS AVAudioEngine stops itself when a Bluetooth headset (HS80) switches HFP/A2DP as the mic reopens, and record_macos 2.1.1 neither restarts nor reports it, so a take saves under a second of sound; (b) camera_macos replies "started" before the movie begins, so every take holds about 1.05 s of sound recorded before the picture.

## Next step

As each round 1 reviewer returns, collect hearing-and-ring's and button-consistency's findings (reviewers' arrays plus a U finding per suite failure that passes on the base and an M finding for button-consistency's inconclusive gate), then candidates, validator, record and verdict. The Android lab smoke run on button-consistency's head is running (briefs in review/round-1/briefs/); the Mac hardware check follows it after confirming the owner is not on a call; Windows smoke is unproven until the owner's PC is back on Tailscale to build. Round 1 verdicts are recorded and both MSPs are at diagnose. hearing-and-ring blockers: C1, C2, C3 and U1 (advisory C5; C4 rejected). button-consistency blockers: C1, U1-U16 and M1 (advisories C2, C3 and C5; A1 and S1 rejected as repeats of C1; C4 rejected). hearing-and-ring's failing-test diagnosis is recorded (fixable: count Pressable rows instead of InkWell at input_dropdown_test.dart:211); six more Opus diagnoses are running, one per kind (verdict.json in review/round-1 lists the kinds); the fix pass starts once each is recorded with pipeline diagnosis and the verdict is re-run. hearing-and-ring's code reviewer found the voice recorder never re-arms on an input change (C1 HIGH), cannotHear survives close() and gates camera-off video takes (C2), the level meter's 500 ms quiet timer churns slow-opening mics (C3), the stale dropdown test (C4) and focus rings around icon plus caption (C5). button-consistency's found the 5.14 taps (C1, also A1 and S1), toggles losing their switch role because Pressable always sets button (C2 HIGH, fix lands in hearing-and-ring's pressable.dart), text fields reading as buttons (C3), the stale tests (C4) and 61 hand-written hover overlays (C5). Probe tests sit in review/checks/hearing-r1 and button-r1.

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
