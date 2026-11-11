# petal-drift-idle-redraw: Stop the drifting petals redrawing every page at 60 fps
Status: active
Updated: 2026-11-11T06:35:46.244Z
Next ids: c1 D2 R2 S1

## Goal

Once today has a bloom, the drifting petals keep the whole app redrawing at the display rate on every page, costing the raster thread 67 to 71% CPU on the Note 10+ while idle; make the petals cheap on every device in a way the owner approves, keeping the journal look.

## Done when

## Where things stand

Full lane, unattended (owner: "Work autonomously. Complete the task."). MSP petal-gusts is open as PR #381 (mitosis/petal-gusts into FEATURE branch fix/petal-drift-idle-redraw, base b7ccaea2) at 1f7290f6, assigned to the owner, bound in the app, CI green; round 1 review was green and both advisories are fixed. The drive is in awaiting-merge. Criterion 5.6 passed on the Note 10+ (Today 12.4% of 60 fps frames and 8.5% raster CPU, Calendar 18.8% and 13.8%, Settings 12.2% and 8.2%, posted on #381), and gusts recur on device. The owner's README request is open as PR #380. The 1.9.0 release notes are open as PR #382 against main, assigned, to merge after the FEATURE pull request; once both are on main, tag v1.9.0 on main and confirm the release workflow publishes.

## Next step

The drive entered awaiting-merge: pull requests are ready to merge; it resumes on pipeline drive event --name merged.

## Decisions in force

- D1 hand-off: build the petal gusts spec unattended: Build now: run the mitosis plan and build for petal-gusts, then review, validate, fix and open the pull request without asking, never merging.

## Open risks


## Settled, do not reopen

## Where the details live

- Code: lib/design/motion/petal_drift.dart (ticker, painter), hosted in lib/app/shell/app_shell.dart and lib/features/onboarding/onboarding_frame.dart
- Baseline on the Note 10+, main f454ef02 profile build: no bloom 0 idle frames; with a bloom Today, Calendar and Settings each 60 fps, raster thread 67 to 71% CPU (scratchpad dp/load script)
- Spec files: docs/specs/petal-drift-idle-redraw.md (spec), .decisions.md (intent and decisions), .record.json (interview record, handed-off), .items.json (Steps), .repro.dart (draft failing test, red on main at 100% of five minutes)
- Glossary terms petal gust and petal rest in GLOSSARY.md; ADR docs/adr/0010-drift-petals-over-the-app-in-gusts.md (uncommitted in the checkout until commit-records puts them on the MSP)
- Draft 1.9.0 release notes: scratchpad petal/changelog-1.9.0.md
- Note 10+ holds the probe build (labmain id, petals off) until the fixed build replaces it; scratchpad dp/build_fixed.sh builds the fixed APK from origin/mitosis/petal-gusts in dp/petal-fixed, and dp/measure_idle.py measures one page for five minutes (frames from SurfaceFlinger, raster thread CPU from /proc ticks)
- Night sky precedent: lib/features/capture/core/night_sky.dart twinkles on an 83 ms timer and launches comets 60 to 180 s apart
- Run home: ~/.mitosis/fireplace/petal-drift-idle-redraw/ (run.zsh, CHARTER.md, worker rules); mitosis run dir ~/.mitosis/runs/fireplace/petal-drift-idle-redraw
- Release process: a release/X-Y-Z-changelog PR adds the CHANGELOG.md section, then a vX.Y.Z tag on main triggers .github/workflows/release.yml, which builds and publishes the GitHub release
- MSP worktree: ~/.mitosis/runs/fireplace/petal-drift-idle-redraw/trees/petal-gusts (branch mitosis/petal-gusts)
