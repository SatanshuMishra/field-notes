# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-08T23:08:49.309Z
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

The owner approved the intent and told the run to work unattended. The spec, record and Steps are written and pass every scripted check; its one independent review is running. Nothing is built.

## Next step

Apply the spec review's findings, re-render, hand off, then start the drive for the two pull requests (camera-engine, then recorder-screen stacked on it).

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Spec record: docs/specs/video-log-camera-overhaul.record.json holds seams, criteria and Steps.
- Decisions: docs/specs/video-log-camera-overhaul.decisions.md holds the owner's binding answers.
- Spec: docs/specs/video-log-camera-overhaul.md holds the problem, intent, design, assumptions, risks and test seams.
- Steps: docs/specs/video-log-camera-overhaul.items.json holds the build tasks.
