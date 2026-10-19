# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T03:10:09.249Z
Next ids: c5 D1 R2 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Interphase bug pathway grounding, before the interview. Causes found: (a) macOS AVAudioEngine stops itself on an IO unit configuration change ("iounit configuration changed > stopping the engine", 8 ms after the first take's engine start) and record_macos 2.1.1 never restarts it or reports it, so LiveAudioCapture saves the take with 0.063 s of sound; (b) vendored camera_macos replies "started" to startRecording before AVCaptureMovieFileOutput begins (no didStartRecordingTo), and Dart begins writing sound on that reply, so both later takes hold about 1.0 s more sound than picture. Both causes have a reproduction that fails on main. The interview's intent round (goal, why, success, four-part split, access to this Mac's camera and microphone) is with the owner; the button inventory for the hover sweep is still running.

## Next step

Wait for the owner's answers to the interview's intent round (goal, why, success, split, and access to this Mac's camera and microphone), write them to docs/specs/mac-video-audio-and-recorder-ui.decisions.md, then ask the frontier round using the button inventory from the Explore agent.

## Decisions in force

## Open risks

- R1 The lab macOS guest has no microphone or camera, so the silent take and the lag can only be proven end to end on real Mac hardware. Bears on c1.

## Settled, do not reopen

## Where the details live

- Spec folder: docs/specs/mac-video-audio-and-recorder-ui.* (decisions, record, guard).
- Owner's evidence takes: the three 2026-10-18 .mp4 blobs under the app container's Documents/media/blobs (52/, 17/, 92/).
- Mac recorder: lib/features/capture/platform/camera_video_recorder.dart; sound capture lib/features/capture/audio/live_audio_capture.dart; native join macos/Runner/LiveAudioBridge.swift; camera plugin third_party/camera_macos.
