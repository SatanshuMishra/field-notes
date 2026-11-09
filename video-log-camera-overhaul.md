# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-09T03:33:06.839Z
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

fix/video-camera-engine and feat/video-recorder-screen are committed locally from main at 6683a4e4, built with fanout on the owner's instruction to disregard the pipeline. A scratch merge of both runs as a profile build on the owner's test phone, a Note10+ with serial RF8MA2NA3ZM, which the owner may be handling at the same time. The recorder branch now asks for the camera before the microphone, shows the access screen when the camera is refused, and shadows the status words over the picture. On that phone the preview equals the saved frame at scale 1.00, a take starts about 80 ms after the countdown, and the controls fade in and out without a cut. Nothing is pushed. The token-free watcher is stopped and parked.

## Next step

Confirm the refusal screen and the status shadow on the phone, restore its settings, rerun the recorder branch's full suite, remove the scratch merge, then open the two pull requests for the owner to merge.

## Decisions in force

- D3 hand-off: build the overhaul as two pull requests that share no files: Two pull requests that share no files: camera-engine holds the vendored Android plugin and the Mac plugin, and recorder-screen holds the camera start path, the fill, the transitions and the fading controls; built unattended and opened for the owner to merge.

## Open risks

- R1 The Mac flash cause is a lead that only the owner's Mac can confirm; if another cause exists the effects still vanish. Bears on c4.
- R2 On a Note10+ Field Notes equals Samsung's 1x with Samsung's stabiliser off and is wider than Samsung's default, which crops for its stabiliser; the S24 Ultra is unmeasured and Samsung's private processing may leave a difference in look. Bears on c3.
- R3 The blurred live fill holds the Note10+ within one 30 fps step but has never run on a real texture on macOS or Windows. Bears on c5.
- R4 The start delay on macOS and Windows has not been timed on real hardware. Bears on c2.

## Settled, do not reopen

## Where the details live

- Spec record: docs/specs/video-log-camera-overhaul.record.json holds seams, criteria and Steps.
- Decisions: docs/specs/video-log-camera-overhaul.decisions.md holds the owner's binding answers.
- Spec: docs/specs/video-log-camera-overhaul.md holds the problem, intent, design, assumptions, risks and test seams.
- Steps: docs/specs/video-log-camera-overhaul.items.json holds the build tasks.
- Watcher: ~/.mitosis/drive_watcher.py holds its code.
- Build: ~/.mitosis/fireplace/video-log-camera-overhaul/fanout holds the items, worker rules, prompt template, worker script, run state and worktrees.
