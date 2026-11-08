# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-08T23:27:53.121Z
Next ids: c7 D2 R5 S1

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

The owner approved the intent and told the run to work unattended. The spec, record and Steps are written and passed every scripted check; its one independent review returned nine issues, which are being fixed once. The glossary terms and two decision records are written. Nothing is built.

## Next step

Follow the unattended drive with pipeline drive status --repo /Users/satanshumishra/Documents/DevLabs/fireplace --slug video-log-camera-overhaul until it pauses at awaiting-merge, then report the two pull requests, every assumption and the unproven criteria 5.8, 5.9, 5.11 and 5.17.

Needs: D1.

## Decisions in force

- D1 hand-off: build the video log and camera overhaul as two stacked pull requests: Build the spec as two stacked pull requests, camera-engine then recorder-screen, unattended, opening them for the owner to merge.

## Open risks

- R1 The Mac flash cause is a lead that only the owner's Mac can confirm; if another cause exists the effects still vanish. Bears on c4.
- R2 Whether stabilisation off closes the remaining zoom on the S24 Ultra, and whether CameraX 1.0 equals Samsung's 1x, is unverified until the phone is held beside its own camera; Samsung's private processing may leave a difference in look. Bears on c3.
- R3 The blurred live fill has an unmeasured GPU cost and has never run on a real texture on macOS or Windows. Bears on c5.
- R4 The start delay on macOS and Windows has not been timed on real hardware. Bears on c2.

## Settled, do not reopen

## Where the details live

- Spec record: docs/specs/video-log-camera-overhaul.record.json holds seams, criteria and Steps.
- Decisions: docs/specs/video-log-camera-overhaul.decisions.md holds the owner's binding answers.
- Spec: docs/specs/video-log-camera-overhaul.md holds the problem, intent, design, assumptions, risks and test seams.
- Steps: docs/specs/video-log-camera-overhaul.items.json holds the build tasks.
