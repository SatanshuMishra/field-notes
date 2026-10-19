# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: parked
Updated: 2026-10-19T23:29:37.451Z
Next ids: c5 D4 R3 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [x] c2 Audio and video in a macOS video recording stay in sync for the whole take evidence: clap take 9 on the MacBook camera and built-in microphone (harness/runs/clap-9-measure.txt): four claps across a 12.9 s take, sound trailing the picture by 40 to 55 ms each time with no drift, picture and sound lengths 3 ms apart, within spec 5.9; video-starts-like-a-camera green at round 5 (ddba45cc, suite 5421 app and 178 relay tests pass); the HS80 headset path is unproven
- [x] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label evidence: camera_picker_dropdown_test, anchored_dropdown_hover_test, recorder_sheet_hover_cursor_test, pressable_test and the per-area hover sweep tests pass in the full suite at button-consistency 4c71a629 (5464 app tests), review green at round 3, and the Android lab read names the input panel rows, drop-down choices and Meadow tabs
- [x] c4 The video recorder shows a subtle live audio level indicator that does not cover the video evidence: video_sound_ring_test ('the video recorder shows the sound ring while its microphone hears') and recorder_input_ring_test pass in the full suite at hearing-and-ring 32ff2edc, review green at round 3

## Where things stand

The owner merged #329 to #332 into the FEATURE branch fix/mac-video-audio-and-recorder-ui. Lighthouse run 1 (core 9eb6c237, FEATURE 9304737b, profile now recording the vendored record_macos) gave verdict failures: suite passed (flaky only), and two paths failed, recorded as integration round 1 findings U1 and U2 (verdict diagnose, kind failing test). U1: on the Windows lab a voice take whose microphone stalls saves 3 to 4 s short (spec 5.1); on this Mac the capture logic, real voice chain, the lab's fake platform and a loaded UI thread all save the full length, so the lab fake skipping timer ticks is suspected. The diagnosis (fixable, verdict loop) traces U1 to the lab fake under-delivering when Dart skips missed periodic ticks, so U1 is retested with a clock-paced fake and no app change. U2 (the sound ring painting outside the 48 dp button and over the Android camera picture, spec 5.8) is fixed on the integration worktree's FEATURE branch: the ring draws in the band between the 40 dp face and the button edge; the receipt failed before and passes after, the selecting check lists nothing, test/features/capture and test/design pass 1146. Android camera picker is unproven (no picker in the phone layout). Unproven: the HS80 mode-switch path (the original failure), the Windows and Android mirror of the native-timestamp alignment (Q11), the Settings segmented Android read (unreadable on main too), and whether TalkBack reads the Android input rows' value field.

## Next step

Finish lighthouse run 2 (lighthouse/run-2, FEATURE ef4508c2, --previous lighthouse/run-1, profile unchanged): the suite and the Windows voice paths (U1 with a clock-paced fake) are running; then drive U2 and the camera picker on the Android lab (the tablet's wide layout holds the picker), write findings.json and run lighthouse verdict; on green, lighthouse opens the FEATURE pull request.

Needs: R1.

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
- review/checks/ in the run home: the diagnoses' selecting checks and repro tests; stall-probes/ holds the passing stalled-take probes.
- Integration worktree ~/.mitosis/runs/field-notes/mac-video-audio-and-recorder-ui/integration on fix/mac-video-audio-and-recorder-ui.
- lighthouse/run-1/work/windows-stall-diagnostic.brief.md in the run home: the Windows stall diagnostic brief.
- lighthouse/run-2/work/android-paths.brief.md in the run home: the Android brief for run 2, to dispatch once the Windows lab is released.
- review/integration.assumptions.txt in the run home: assumptions the Integration fixes made.
- suite-tree/ and suite-hearing/ in the run home: detached worktrees for review suites away from mitosis's live worktrees, one per concurrent run.
