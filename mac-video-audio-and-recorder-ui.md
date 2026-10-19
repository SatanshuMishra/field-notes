# mac-video-audio-and-recorder-ui: Mac video recording audio: missing first take, audio lag, recorder UI consistency
Status: active
Updated: 2026-10-19T03:07:03.647Z
Next ids: c5 D1 R1 S1

## Goal

Video logs on macOS record audio on every take, including the first of a session, with audio and video in sync; the camera picker matches the voice input picker, every recorder and modal button has a proper hover shape, hover state and accessibility, and the video recorder shows a subtle live audio level.

## Done when

- [ ] c1 The first video recording after app launch on macOS contains audio
- [ ] c2 Audio and video in a macOS video recording stay in sync for the whole take
- [ ] c3 The camera selector drop-down matches the voice input drop-down and every recorder button has a matching hover shape, hover state and accessible label
- [ ] c4 The video recorder shows a subtle live audio level indicator that does not cover the video

## Where things stand

Interphase bug pathway grounding, before the interview. Causes found: (a) macOS AVAudioEngine stops itself on an IO unit configuration change ("iounit configuration changed > stopping the engine", 8 ms after the first take's engine start) and record_macos 2.1.1 never restarts it or reports it, so LiveAudioCapture saves the take with 0.063 s of sound; (b) vendored camera_macos replies "started" to startRecording before AVCaptureMovieFileOutput begins (no didStartRecordingTo), and Dart begins writing sound on that reply, so both later takes hold about 1.0 s more sound than picture. The lab macOS guest has no microphone and no camera.

## Next step

Write the deterministic Dart reproduction of (a) and (b), then ask the owner the interview round, including access to a real Mac camera and microphone for reproduction.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Spec folder: docs/specs/mac-video-audio-and-recorder-ui.* (decisions, record, guard).
- Owner's evidence takes: the three 2026-10-18 .mp4 blobs under the app container's Documents/media/blobs (52/, 17/, 92/).
- Mac recorder: lib/features/capture/platform/camera_video_recorder.dart; sound capture lib/features/capture/audio/live_audio_capture.dart; native join macos/Runner/LiveAudioBridge.swift; camera plugin third_party/camera_macos.
