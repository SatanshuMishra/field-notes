# petal-drift-idle-redraw: Stop the drifting petals redrawing every page at 60 fps
Status: active
Updated: 2026-11-11T04:55:37.827Z
Next ids: c1 D1 R1 S1

## Goal

Once today has a bloom, the drifting petals keep the whole app redrawing at the display rate on every page, costing the raster thread 67 to 71% CPU on the Note 10+ while idle; make the petals cheap on every device in a way the owner approves, keeping the journal look.

## Done when

## Where things stand

Full lane, interphase bug pathway, unattended after the intent round (owner: "Work autonomously. Complete the task."). The spec, record and items file are written and pass check_spec and check_items; the single spec-reviewer pass is running. Design: over the app, petals fall in gusts (PetalRhythm.gusts) with rests of four to five gust lengths; onboarding stays steady. The owner asked to tag and release once the fix is resolved, which means after they merge it into main.

## Next step

Fix what the spec reviewer reports, re-render and re-check, then hand off (glossary entry for petal gust, tree guard verify, status handed-off) and start pipeline stage 2 (feature branch, run home, mitosis build of the petal-gusts Step).

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Code: lib/design/motion/petal_drift.dart (ticker, painter), hosted in lib/app/shell/app_shell.dart and lib/features/onboarding/onboarding_frame.dart
- Baseline on the Note 10+, main f454ef02 profile build: no bloom 0 idle frames; with a bloom Today, Calendar and Settings each 60 fps, raster thread 67 to 71% CPU (scratchpad dp/load script)
- Spec files: docs/specs/petal-drift-idle-redraw.md (spec), .decisions.md (intent and decisions), .record.json (interview record), .items.json (Steps), .repro.dart (draft failing test, red on main at 100% of five minutes), .guard.json (tree guard)
- Note 10+ still holds the probe build (labmain id, petals off) with the Grateful bloom set; reinstall main for any before measurement and the fixed build for the after measurement
- Night sky precedent: lib/features/capture/core/night_sky.dart twinkles on an 83 ms timer and launches comets 60 to 180 s apart
