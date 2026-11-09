# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-09T01:07:33.498Z
Next ids: c7 D5 R5 S1

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

Fanout is building from main at 6683a4e4 on the owner's instruction to disregard the pipeline. Camera-engine is committed locally on fanout/msp-0; recorder-screen is still building on fanout/msp-1. Nothing is reviewed or pushed. The token-free watcher is stopped and parked, so this build has no stall detection.

## Next step

When fanout finishes, read each agent's return, run the full tests, review both diffs, add GLOSSARY.md and ADRs 0008 and 0009 to the first branch, then open the pull requests for the owner to merge.

## Decisions in force

- D3 hand-off: build the overhaul as two pull requests that share no files: Two pull requests that share no files: camera-engine holds the vendored Android plugin and the Mac plugin, and recorder-screen holds the camera start path, the fill, the transitions and the fading controls; built unattended and opened for the owner to merge.

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
- Watcher: ~/.mitosis/drive_watcher.py holds its code.
- Build: ~/.mitosis/fireplace/video-log-camera-overhaul/fanout holds the items, worker rules, prompt template, worker script, run state and worktrees.
