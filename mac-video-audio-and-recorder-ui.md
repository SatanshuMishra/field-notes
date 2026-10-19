# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T04:17:47.847Z
Next ids: c5 D2 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Interphase bug pathway grounding, before the interview. Causes found: (a) macOS AVAudioEngine stops itself on an IO unit configuration change ("iounit configuration changed > stopping the engine", 8 ms after the first take's engine start) and record_macos 2.1.1 never restarts it or reports it, so LiveAudioCapture saves the take with 0.063 s of sound; (b) vendored camera_macos replies "started" to startRecording before AVCaptureMovieFileOutput begins (no didStartRecordingTo), and Dart begins writing sound on that reply, so both later takes hold about 1.0 s more sound than picture. Both causes have a reproduction that fails on main. Intent round approved (I1-I5). A throwaway repro app (bundle dev.satanshumishra.fieldNotes.repro) on this Mac's built-in mic reproduced the lag on real hardware: two 8 s takes held 7.99 s of sound against 7.07 s and 7.00 s of picture; neither went silent and no engine stop was logged. With the HS80 connected later, the silent take reproduced on real hardware: a take reopened the mic 1 s after the previous one closed it, as the headset began leaving HFP; the headset flipped tsco, tacl, tsco and the engine logged "stopping the engine" 0.75 s in, saving 0.685 s of sound under 7.0 s of picture. One other run hung forever in recorder.start after "Error setting device on iounit, err = 'nope'". All 9 headset takes held about 1.05 s more sound than picture. Round 2 answered: start blocked with a can't-hear-you notice, normal-camera behaviour (mic opens with the preview), ring indicator, app-wide sweep, Windows and Android in scope.

## Next step

Write the seams, criteria and Steps to the record (the app-wide tap-target inventory is being gathered by an Explore agent), check it with check_record --complete, then hold the read-back with AskUserQuestion.

## Decisions in force

- D1 Interphase hand-off: build the approved spec as four pull requests: Hand off to mitosis: MSPs mic-recovery, video-starts-like-a-camera, hearing-and-ring and button-consistency on a fix FEATURE branch cut from origin/main 9eb6c237; ADRs 0005 and 0006 and the glossary term Hearing ship with the first pull request.

## Open risks

- R1 The lab macOS guest has no microphone or camera, so the silent take and the lag can only be proven end to end on real Mac hardware. Bears on c1.

## Settled, do not reopen

## Where the details live

- Spec folder: docs/specs/mac-video-audio-and-recorder-ui.* (decisions, record, guard, and the reproduction tests in .repro.dart, destined for test/features/capture/video/mac_video_sound_repro_test.dart).
- Owner's evidence takes: the three 2026-10-18 .mp4 blobs under the app container's Documents/media/blobs (52/, 17/, 92/).
- Mac recorder: lib/features/capture/platform/camera_video_recorder.dart; sound capture lib/features/capture/audio/live_audio_capture.dart; native join macos/Runner/LiveAudioBridge.swift; camera plugin third_party/camera_macos.
