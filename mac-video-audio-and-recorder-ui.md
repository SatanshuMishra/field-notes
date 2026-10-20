# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: parked
Updated: 2026-10-20T01:16:01.941Z
Next ids: c5 D4 R3 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [x] c1 The first video recording after app launch on macOS contains audio evidence: mac_video_sound_repro_test ('a take whose microphone goes quiet after its first chunk keeps sound for the whole picture') passes on main 4f9aa3a6, shipped in v1.4.0; a first take on real Mac hardware after launch is unproven (R1)
- [x] c2 Audio and video in a macOS video recording stay in sync for the whole take evidence: clap take 9 on the MacBook camera and built-in microphone (harness/runs/clap-9-measure.txt): four claps across a 12.9 s take, sound trailing the picture by 40 to 55 ms each time with no drift, picture and sound lengths 3 ms apart, within spec 5.9; video-starts-like-a-camera green at round 5 (ddba45cc, suite 5421 app and 178 relay tests pass); the HS80 headset path is unproven
- [x] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label evidence: camera_picker_dropdown_test, anchored_dropdown_hover_test, recorder_sheet_hover_cursor_test, pressable_test and the per-area hover sweep tests pass in the full suite at button-consistency 4c71a629 (5464 app tests), review green at round 3, and the Android lab read names the input panel rows, drop-down choices and Meadow tabs
- [x] c4 The video recorder shows a subtle live audio level indicator that does not cover the video evidence: video_sound_ring_test ('the video recorder shows the sound ring while its microphone hears') and recorder_input_ring_test pass in the full suite at hearing-and-ring 32ff2edc, review green at round 3

## Where things stand

The owner merged the FEATURE pull request SatanshuMishra/field-notes#333 into main (73447bb5) with U1 unresolved. Clean-up is stopped: `pipeline clean` removed the run's local branches, then crashed refusing to delete the legacy symlink ~/.mitosis/runs/fireplace/mac-video-audio-and-recorder-ui, leaving the run folder, three worktrees and the five docs/specs/mac-video-audio-and-recorder-ui.* files. U1: a Windows-lab voice take with a 12 s microphone stall saves about 1.3 s short by the lab driver's lagging clock, even with a clock-paced fake; the fake's own stamps show the saved speech complete and the stall overfilled, and on this Mac every probe saves the full length. U2 (the sound ring outside the button and over the Android picture, spec 5.8) is fixed on FEATURE and passed on the Android phone. The suite passed (flaky only). The camera picker is unreachable on Android (the sidebar layout is chosen by desktop platform, not width). Unproven: the HS80 mode-switch path (the original failure), the Windows and Android mirror of the native-timestamp alignment (Q11), the Settings segmented Android read (unreadable on main too), and whether TalkBack reads the Android input rows' value field.

## Next step

Delete only the symlink ~/.mitosis/runs/fireplace/mac-video-audio-and-recorder-ui (not its target), run pipeline clean --repo <root> --slug mac-video-audio-and-recorder-ui again, then close the thread when it keeps nothing.

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
- review/checks/ in the run home: the diagnoses' selecting checks and repro tests; stall-probes/ holds the passing stalled-take probes and take-start-in-source.py, which aligns a saved lab take with the fake's speech source.
- Integration worktree ~/.mitosis/runs/field-notes/mac-video-audio-and-recorder-ui/integration on fix/mac-video-audio-and-recorder-ui.
- lighthouse/run-1/work/windows-stall-diagnostic.brief.md in the run home: the Windows stall diagnostic brief.
- lighthouse/run-2/work/android-paths.brief.md in the run home: the Android brief for run 2, to dispatch once the Windows lab is released.
- review/integration.assumptions.txt in the run home: assumptions the Integration fixes made.
- suite-tree/ and suite-hearing/ in the run home: detached worktrees for review suites away from mitosis's live worktrees, one per concurrent run.
