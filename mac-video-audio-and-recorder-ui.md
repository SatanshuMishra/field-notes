# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T14:03:15.504Z
Next ids: c5 D3 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Pipeline stage 3. mic-recovery (round 2, 2dd055e0) and video-starts-like-a-camera (round 3, 2d0091ff) are green and wait for ship; each green MSP is merged up the stack. hearing-and-ring is green again at round 3 (32ff2edc): its input panel rows and drop-down choices are now one named node each on Android, fixing a split that hid their names there. button-consistency is in round 3 at 4c71a629 (hearing-and-ring merged): round 2's blockers are fixed with receipts (no Semantics wrapper around a Pressable, guarded by no_semantics_around_pressable_test; settings text field focuses from its padding; keyboard-only meadow cards keep the basic cursor) and its advisory pass-through hover wrappers are gone; its round 3 suite is clean (5464 app, 178 relay), its code reviewer found nothing, and its validator is judging the one carried blocker (the text field's small tap target). The Android rerun names the input panel rows, drop-down choices and Meadow tabs; the Settings segmented choices are unproven because the lab cannot read that page on main either. On Android the input panel rows now carry their current value in the value field rather than the name, as main's Settings rows do; whether TalkBack reads it is unverified. Round 2's diagnoses and selecting checks are in review/round-2 and review/checks/button-r2. android_dump_rules_test fails now and then under machine load and is not a finding. Smoke: Windows is unproven while the owner's PC is offline on Tailscale; the Android camera-off notice passes. The Mac repro app is built in harness/repro-tree from 32ff2edc; its built-in microphone run waits on two macOS system dialogs (privacy and app-launch checks) only the owner can answer.

## Next step

When the suite lands, dispatch button-consistency's round 3 code reviewer (and security reviewer only if the fixes touch a trust boundary), then findings (add a U finding for any control the Android rerun shows unnamed here and named on main), candidates, validator, record and verdict. Read the Mac runs once the owner answers the dialogs, then ship.

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
