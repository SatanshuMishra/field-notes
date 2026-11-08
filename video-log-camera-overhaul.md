# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-08T22:27:24.606Z
Next ids: c7 D1 R1 S1

## Goal

Make the video log feel seamless on Android, macOS and Windows: smooth ready, countdown and recording states with a button that reflects each, no visible lag before recording starts, a preview that matches the native camera's field of view and quality, macOS Control Center effects that stay on, a preview that fills the window without hiding what is recorded, and controls that fade away while recording.

## Done when

- [ ] c1 Ready, countdown and recording transition smoothly and the record button visibly differs in each state
- [ ] c2 The pause between countdown and recording is explained and removed or hidden
- [ ] c3 The Field Notes preview shows the same field of view as the native camera at 1x and is not visibly worse in quality
- [ ] c4 macOS Control Center effects that are on before the recorder opens stay on after it opens
- [ ] c5 The preview fills the window with nothing recorded hidden from the user
- [ ] c6 Non-essential controls fade out smoothly during recording and return when needed

## Where things stand

Not started.

## Next step

Read lib/features/capture/video and lib/features/capture/immersive, find the root cause of each reported symptom, then run the lighthouse readiness gate and the interphase interview.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live
