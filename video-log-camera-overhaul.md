# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-08T23:38:45.844Z
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

The owner approved the intent and told the run to work unattended. The spec, record and Steps are written and passed every scripted check; its one independent review returned nine issues, which are being fixed once. The glossary terms and two decision records are written. Nothing is built.

## Next step

The drive entered plan and runs it next.

## Decisions in force

- D2 repair: plan fail: park: plan: run.zsh exited with code 3: exit 3: refused to start; repair: With five --pr-why lines, pr_facts._problem joins them into one problem line (547 chars, over the 500-char limit). The five whys are now shortened so the joined line is 484 characters. Line count and positions stay the same, and every intent point is kept.
- D3 hand-off: build the overhaul as two pull requests that share no files: Two pull requests that share no files: camera-engine holds the vendored Android plugin and the Mac plugin, and recorder-screen holds the camera start path, the fill, the transitions and the fading controls; built unattended and opened for the owner to merge.
- D4 repair: plan fail: correct: Mitosis adds the MSP name to the PR title, so 'feat(video): make the video log one calm continuous moment (camera-engine)' came to 74 characters, over the 72 limit; the shorter subject 'make the video log calm and continuous' fits even with the longest MSP name, recorder-screen (69 characters).

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
