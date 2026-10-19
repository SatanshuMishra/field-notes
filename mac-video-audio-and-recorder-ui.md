# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T14:10:56.402Z
Next ids: c5 D4 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [x] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label evidence: camera_picker_dropdown_test, anchored_dropdown_hover_test, recorder_sheet_hover_cursor_test, pressable_test and the per-area hover sweep tests pass in the full suite at button-consistency 4c71a629 (5464 app tests), review green at round 3, and the Android lab read names the input panel rows, drop-down choices and Meadow tabs
- [x] c4 The video recorder shows a subtle live audio level indicator that does not cover the video evidence: video_sound_ring_test ('the video recorder shows the sound ring while its microphone hears') and recorder_input_ring_test pass in the full suite at hearing-and-ring 32ff2edc, review green at round 3

## Where things stand

Shipped: four stacked pull requests are open and assigned to the owner, ready for review: #329 mic-recovery (base fix/mac-video-audio-and-recorder-ui), #330 video-starts-like-a-camera, #331 hearing-and-ring, #332 button-consistency, each based on the one before. Unproven: the Windows smoke (owner's PC offline on Tailscale), the Settings segmented Android read (the lab cannot read that page on main either), and the real-Mac check of c1 and c2, whose built-in microphone run in harness/ waits on two macOS system dialogs only the owner can answer. On Android the input panel rows carry their current value in the value field rather than the name, as main's Settings rows do; whether TalkBack reads it is unverified.

## Next step

Run SHIP=1 run.zsh --resume with the three proven heads, open the four pull requests in stack order through the GitHub MCP, assign them, post each saved review comment, then park the thread for Integration.

Needs: D2, D3, R1.

## Decisions in force

- D2 Interphase hand-off (re-cut): build four stacked pull requests with no file shared across them: Re-cut the Steps. MSPs mic-recovery, video-starts-like-a-camera, hearing-and-ring and button-consistency on fix/mac-video-audio-and-recorder-ui cut from origin/main 9eb6c237, stacked in that order, 23 Steps; recorded as an I4 assumption in the spec. ADRs 0005 and 0006 and the glossary term Hearing ship with the first pull request.
- D3 Ship boundary: open the four stacked pull requests now: Ship now: mitosis ships with proven heads for video-starts-like-a-camera 2d0091ff, hearing-and-ring 32ff2edc and button-consistency 4c71a629; mic-recovery is gated again at 8a3162bd, its glossary and decision-record commit; the unproven checks go in the final report.

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
