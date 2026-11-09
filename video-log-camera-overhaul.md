# video-log-camera-overhaul: Video log and camera overhaul: transitions, lag, zoom, Mac effects, full-bleed layout, fading controls
Status: active
Updated: 2026-11-09T08:14:48.323Z
Next ids: c7 D6 R5 S1

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

The overhaul is merged into main and tagged v1.6.0, the release job's Android build is blocked by a GitHub outage on its Gradle and Kotlin downloads and re-runs once both work, and the run's worktrees, branches and folders are removed. With stabilisation off on the owner's test phone, a Note10+, the preview equals the saved frame at scale 1.00, a take starts about 80 ms after the countdown, the controls fade without a cut, and a refused camera shows the access screen with the camera closed and no microphone prompt. Stabilisation is on in main and has not run on a phone. No real macOS or Windows camera has run it, so every criterion stays open. The token-free watcher is stopped and parked.

## Next step

Confirm the v1.6.0 release job published its files. The owner checks stabilisation on a phone, the Mac effects, and the macOS and Windows cameras on real hardware.

## Decisions in force

- D3 hand-off: build the overhaul as two pull requests that share no files: Two pull requests that share no files: camera-engine holds the vendored Android plugin and the Mac plugin, and recorder-screen holds the camera start path, the fill, the transitions and the fading controls; built unattended and opened for the owner to merge.
- D5 keep video stabilisation on: The owner chose stabilisation on and waived a Note10+ test of it.

## Open risks

- R1 The Mac flash cause is a lead that only the owner's Mac can confirm; if another cause exists the effects still vanish. Bears on c4.
- R2 Field Notes with stabilisation on has never been measured against Samsung's default Video view, and Android guarantees that mode on the recording only, so preview and saved frame may differ. The S24 Ultra is unmeasured and Samsung's private processing may leave a difference in look. Bears on c3 and c5.
- R3 The blurred live fill holds the Note10+ within one 30 fps step but has never run on a real texture on macOS or Windows. Bears on c5.
- R4 The start delay on macOS and Windows has not been timed on real hardware. Bears on c2.

## Settled, do not reopen

## Where the details live

- Archive: ~/.mitosis/fireplace/archive/video-log-camera-overhaul holds the spec, decisions, record, Steps, worker rules and build logs.
- Watcher: ~/.mitosis/drive_watcher.py holds its code.
- Release job: GitHub Actions run 42578901902 builds and publishes v1.6.0.
- Release retry: release-retry.sh in the session scratchpad re-runs that job's failed builds once its Gradle and Kotlin downloads work.
