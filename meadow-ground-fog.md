# meadow-ground-fog: Turn the meadow's mist pockets into low ground fog that keeps flowers visible
Status: active
Updated: 2026-10-24T02:48:11.200Z
Next ids: c5 D2 R5 S1

## Goal

The Meadow's "Mist in the hollow" mist pockets stop hiding the flowers they sit over, at night, dawn and midday, while the drifting mist and the synced fireflies keep the meadow's feel; mist appears only for a stretch that was actually heavy.

## Done when

- [ ] c1 Combined mist-pocket peak opacity is capped per time of day and blooms stay readable at night, dawn and noon in owner-approved lab screenshots with meadowKeyProvider pinned
- [x] c2 No mist pockets or heaviest-stretch landmark when the heaviest window's mean valence is zero or above, and no butterfly brightest-stretch bias when the brightest window's mean is zero or below evidence: criterion 5.1's three tests (meadow_year_test sign gates, meadow_landmarks_test both cards) pass in the round 1 full suite at 91683e62, and the conformance audit judged 5.1 MET
- [ ] c3 No frame-time regression on the Note10+ floor check
- [ ] c4 Pull requests opened through the pipeline, never merged

## Where things stand

Full lane, MSP meadow-ground-fog on FEATURE branch feat/meadow-ground-fog (cut from main at 4f9aa3a6). The run is autonomous to the pull request. MSP meadow-ground-fog is committed on mitosis/meadow-ground-fog at 91683e62 in worktree ~/.mitosis/runs/fireplace/meadow-ground-fog/trees/meadow-ground-fog. Review round 1 is under way: the full suite passes at the head (5488 app and 178 package tests, analysis clean, review/round-1/meadow-ground-fog.suite.txt); the conformance audit found nothing (review/round-1/conformance-auditor.json); code-reviewer found C1 MEDIUM and C2 LOW (review/round-1/code-reviewer.json); the Windows smoke run is stopped with no screenshots because winpc went offline after its builds (the lab copies were released), so Windows is unproven until winpc returns; the macOS smoke run is running as a headless claude -p session (review/round-1/smoke-macos.session.log) reusing the smoke worktrees and harness in smoke/. Spec criterion 5.4 is unproven until the lab review; the Note10+ is not connected.

## Next step

When the Windows smoke run reports (it was told to start a fresh windows instance), dispatch the macOS smoke run, then Android; then collect review/round-1/meadow-ground-fog.findings.json from code-reviewer.json (C1, C2), conformance-auditor.json (empty) and any broken smoke paths, and run pipeline candidates and the validator.

## Decisions in force

- D1 Interphase hand-off: build the approved spec as one MSP of three Steps: Build now from the handed-off spec, one MSP meadow-ground-fog, one pull request; criterion 5.4 stays unproven until the lab review.

## Open risks

- R1 The app's mist is an exact port of the prototype's (same 5 pockets, geometry and fogP), and the earlier meadow spec made the prototype the look reference; this change departs from it on purpose (intent Q4).
- R3 Round 1 code-review finding C1 (MEDIUM, not yet validated): the sign gates compare the floating-point window mean with exactly 0, so a window whose valences cancel (happy, happy, tired, tired, sad, anxious gives -9.25e-18) still counts as heaviest; this undercuts c2's evidence until fixed. Bears on c2.
- R4 The lab releases every instance this session holds whenever a turn ends, which killed two Windows lab instances mid-run; smoke runs therefore go to a headless claude -p session that holds its own instance.

## Settled, do not reopen

## Where the details live

- Cause traced 2026-10-23: 5 overlapping pockets in lib/features/garden/scene/meadow_plants.dart _pockets, drawn in lib/features/garden/render/meadow_stage_painter.dart _paintPocket at 0.92*fogP (lib/features/garden/scene/meadow_palette.dart:220); heaviest/brightest in lib/features/garden/model/meadow_year.dart pick extremes regardless of sign
- Run home: ~/.mitosis/fireplace/meadow-ground-fog/ (CHARTER.md, worker-rules.txt, dispatch.zsh, run.zsh, suite.zsh, smoke-brief.md, rounds.md, items.json, graph.json, build-1.out, review/); mitosis run dir ~/.mitosis/runs/fireplace/meadow-ground-fog; accept.zsh copied to ~/.mitosis/fireplace/, whose findings.jsonl and do-not-flag.md link to the field-notes copies
- Interphase files: docs/specs/meadow-ground-fog.md (spec), .decisions.md, .record.json, .items.json; glossary terms Heaviest stretch, Brightest stretch and Mist in GLOSSARY.md (uncommitted, ship with the pull request)
- Earlier meadow decisions: docs/specs/meadow.md (item 7 gates mist and butterflies on 6 mood days in 16) and docs/specs/meadow.decisions.md
- Prototype mist reference: docs/prototype/Meadow Scene.dc.html (pockets, --fogP)
- Mock-up kit: scratchpad mock/ (patched prototype copy taking URL params v=before|a|b, h hour, y year, pm/pd/pn peaks; headless Chrome renders; stack.py builds the comparison strips)
