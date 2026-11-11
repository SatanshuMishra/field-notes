# petal-drift-idle-redraw: Stop the drifting petals redrawing every page at 60 fps
Status: active
Updated: 2026-11-11T05:07:27.177Z
Next ids: c1 D2 R1 S1

## Goal

Once today has a bloom, the drifting petals keep the whole app redrawing at the display rate on every page, costing the raster thread 67 to 71% CPU on the Note 10+ while idle; make the petals cheap on every device in a way the owner approves, keeping the journal look.

## Done when

## Where things stand

Full lane, interphase bug pathway, unattended after the intent round (owner: "Work autonomously. Complete the task."). The spec reviewer found four issues, all being fixed: rests become five to six gusts (four to five lets a wide window reach 27%), a flower changed mid-gust gets a new gust at once, the wide-or-narrow rule and the per-petal draw become shared functions, and a set change mid-gust starts a fresh gust. A background agent is separately writing the owner's README-with-screenshots pull request; it shares no files with this fix. The glossary terms (petal gust, petal rest) and ADR 0010 are written, and the tree guard verified clean. The FEATURE branch fix/petal-drift-idle-redraw is pushed at b7ccaea2, and the run home holds feature.json, CHARTER.md, run.zsh, worker scripts, worker-rules.base.txt, do-not-flag.md and graph.json. Design: over the app, petals fall in gusts (PetalRhythm.gusts) with rests of four to five gust lengths; onboarding stays steady. The owner asked to tag and release once the fix is merged into main; the release would be 1.9.0, covering PRs #370 to #379 and this fix.

## Next step

Fix what the spec reviewer reports, re-render and re-check, set the record to handed-off and delete the guard; then pipeline guarantees, the hand-off decision, copy items.json, pipeline prevent into worker-rules.txt, plan-only and the drive.

## Decisions in force

- D1 hand-off: build the petal gusts spec unattended: Build now: run the mitosis plan and build for petal-gusts, then review, validate, fix and open the pull request without asking, never merging.

## Open risks

## Settled, do not reopen

## Where the details live

- Code: lib/design/motion/petal_drift.dart (ticker, painter), hosted in lib/app/shell/app_shell.dart and lib/features/onboarding/onboarding_frame.dart
- Baseline on the Note 10+, main f454ef02 profile build: no bloom 0 idle frames; with a bloom Today, Calendar and Settings each 60 fps, raster thread 67 to 71% CPU (scratchpad dp/load script)
- Spec files: docs/specs/petal-drift-idle-redraw.md (spec), .decisions.md (intent and decisions), .record.json (interview record), .items.json (Steps), .repro.dart (draft failing test, red on main at 100% of five minutes), .guard.json (tree guard)
- Note 10+ still holds the probe build (labmain id, petals off) with the Grateful bloom set; reinstall main for any before measurement and the fixed build for the after measurement
- Night sky precedent: lib/features/capture/core/night_sky.dart twinkles on an 83 ms timer and launches comets 60 to 180 s apart
- Run home: ~/.mitosis/fireplace/petal-drift-idle-redraw/ (run.zsh, CHARTER.md, worker rules); mitosis run dir ~/.mitosis/runs/fireplace/petal-drift-idle-redraw
- Release process: a release/X-Y-Z-changelog PR adds the CHANGELOG.md section, then a vX.Y.Z tag on main triggers .github/workflows/release.yml, which builds and publishes the GitHub release
