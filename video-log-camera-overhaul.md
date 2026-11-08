# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-08T22:34:59.188Z
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

Interview is at the intent round, awaiting the owner's answers; outside research on Android cropping, macOS effects and recorder design is running. Nothing is built. Android's pause is confirmed as CameraX binding VideoCapture at record start; the extra zoom is about 1.6x, of which 1.33x is 16:9 against the 4:3 Photo view and the rest is unverified stabilisation crop; the Mac effects lead is two unused preview layers created on the running session, unproven without the owner's Mac.

## Next step

Save the owner's answers to the intent round in docs/specs/video-log-camera-overhaul.decisions.md, then ask the first frontier round with mock-ups of the recorder states and layout options.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live
