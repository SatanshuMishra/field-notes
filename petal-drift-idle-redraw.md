# petal-drift-idle-redraw: Stop the drifting petals redrawing every page at 60 fps
Status: active
Updated: 2026-11-11T04:47:57.385Z
Next ids: c1 D1 R1 S1

## Goal

Once today has a bloom, the drifting petals keep the whole app redrawing at the display rate on every page, costing the raster thread 67 to 71% CPU on the Note 10+ while idle; make the petals cheap on every device in a way the owner approves, keeping the journal look.

## Done when

## Where things stand

Full lane, interphase bug pathway, unattended after the intent round (owner: "Work autonomously. Complete the task."). Intent I1 to I4 are in the decisions file. Cause confirmed: PetalDrift's ticker runs every vsync while a flower is set, and each petal frame re-renders the whole page on Impeller; a probe with the ticker never started drew 0 idle frames with a bloom on Today, Calendar and Settings. The draft failing test (docs/specs/petal-drift-idle-redraw.repro.dart) fails on main with the idle app asking for frames on 100% of five minutes. Main is at b7ccaea2 with the 1.8.0 follow-ups merged; the guard snapshot was retaken there. The design being specified: over the app, petals fall in gusts with rests of four to five gust lengths; onboarding stays steady.

## Next step

Measure the probe build (builds/field-notes-probe-no-ticker.apk, labmain id) on the Note 10+ with today's bloom, record the result in the spec, then take the owner's intent answers into the decisions file and ask the first frontier round (drift pattern, step-down, onboarding scope, seams, pre-mortem).

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Code: lib/design/motion/petal_drift.dart (ticker, painter), hosted in lib/app/shell/app_shell.dart and lib/features/onboarding/onboarding_frame.dart
- Baseline on the Note 10+, main f454ef02 profile build: no bloom 0 idle frames; with a bloom Today, Calendar and Settings each 60 fps, raster thread 67 to 71% CPU (scratchpad dp/load script)
- Spec files: docs/specs/petal-drift-idle-redraw.decisions.md (intent and decisions), .record.json (interview record), .guard.json (tree guard)
- Probe worktree: /var/folders/tz/b798spt96sjfyy924nf0cw4c0000gn/T/interphase-probe-rioxpwew (remove with interphase probe.py remove)
- Night sky precedent on origin/feat/night-sky: lib/features/capture/core/night_sky.dart twinkles on an 83 ms timer and launches comets 60 to 180 s apart
