# petal-drift-idle-redraw: Stop the drifting petals redrawing every page at 60 fps
Status: active
Updated: 2026-11-11T06:10:38.161Z
Next ids: c1 D2 R2 S1

## Goal

Once today has a bloom, the drifting petals keep the whole app redrawing at the display rate on every page, costing the raster thread 67 to 71% CPU on the Note 10+ while idle; make the petals cheap on every device in a way the owner approves, keeping the journal look.

## Done when

## Where things stand

Full lane, unattended (owner: "Work autonomously. Complete the task."). The spec is handed off with the reviewer's four fixes: rests of five to six gusts, an immediate gust after a mid-gust flower change, one shared wide-or-phone rule with a fresh gust on a set change (criterion C4.4), and one shared per-petal draw. MSP petal-gusts is open as PR #381 (mitosis/petal-gusts into FEATURE branch fix/petal-drift-idle-redraw, base b7ccaea2), assigned to the owner; the drive is in awaiting-merge and watches its CI. Round 1 was green; advisories C1 (ADR rest wording) and C2 (flights carry their petal) are fixed and pushed as 1f7290f6, with all 18 petal tests passing, and the branch's ADR and glossary now match the checkout. The tree guard's only difference at hand-off was the README agent's worktree, recorded in D1. The owner's separate README request is open as PR #380 (README and 21 screenshots, no lab or personal setup, checks green); the 1.9.0 release notes should not need it. The owner asked to tag and release once the fix is merged into main: release 1.9.0, covering PRs #370 to #379 and this fix, notes drafted. Criterion 5.6 is being measured: a profile build of the fixed branch (labmain id) is building in a scratch worktree, then five idle minutes each on Today, Calendar and Settings after picking today's mood (the phone is on Nov 11, so yesterday's Grateful bloom no longer counts). After that, the 1.9.0 changelog pull request opens.

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
- Note 10+ still holds the probe build (labmain id, petals off) with the Grateful bloom set; reinstall main for any before measurement and the fixed build for the after measurement
- Night sky precedent: lib/features/capture/core/night_sky.dart twinkles on an 83 ms timer and launches comets 60 to 180 s apart
- Run home: ~/.mitosis/fireplace/petal-drift-idle-redraw/ (run.zsh, CHARTER.md, worker rules); mitosis run dir ~/.mitosis/runs/fireplace/petal-drift-idle-redraw
- Release process: a release/X-Y-Z-changelog PR adds the CHANGELOG.md section, then a vX.Y.Z tag on main triggers .github/workflows/release.yml, which builds and publishes the GitHub release
- MSP worktree: ~/.mitosis/runs/fireplace/petal-drift-idle-redraw/trees/petal-gusts (branch mitosis/petal-gusts)
