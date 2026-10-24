# meadow-ground-fog: Turn the meadow's mist pockets into low ground fog that keeps flowers visible
Status: active
Updated: 2026-10-24T03:52:29.486Z
Next ids: c5 D3 R5 S1

## Goal

The Meadow's "Mist in the hollow" mist pockets stop hiding the flowers they sit over, at night, dawn and midday, while the drifting mist and the synced fireflies keep the meadow's feel; mist appears only for a stretch that was actually heavy.

## Done when

- [ ] c1 Combined mist-pocket peak opacity is capped per time of day and blooms stay readable at night, dawn and noon in owner-approved lab screenshots with meadowKeyProvider pinned
- [x] c2 No mist pockets or heaviest-stretch landmark when the heaviest window's mean valence is zero or above, and no butterfly brightest-stretch bias when the brightest window's mean is zero or below evidence: criterion 5.1's three tests (meadow_year_test sign gates, meadow_landmarks_test both cards) pass in the round 1 full suite at 91683e62, and the conformance audit judged 5.1 MET
- [ ] c3 No frame-time regression on the Note10+ floor check
- [ ] c4 Pull requests opened through the pipeline, never merged

## Where things stand

Full lane, MSP meadow-ground-fog on FEATURE branch feat/meadow-ground-fog (cut from main at 4f9aa3a6); the run is autonomous to the pull request. Review is green at b9583f85 (round 2: no findings, C1 fixed, suite and slow checks pass), and mitosis/meadow-ground-fog carries the glossary commit f85ab835 on top. The mitosis ship run is in progress (output in ship.out). Unproven: Windows smoke (winpc offline), the Android landmarks path, spec criterion 5.4 (the owner's lab review), and the Note10+ check (not connected).

## Next step

Run SHIP=1 ~/.mitosis/fireplace/meadow-ground-fog/run.zsh --resume --proven-head meadow-ground-fog=b9583f8597060e3d7c3309da018b0a7bbd662cc3, then open the pull request from mitosis's title, body, branch and base, assign it to the owner and post review/meadow-ground-fog.comment.md.

Needs: D2.

## Decisions in force

- D1 Interphase hand-off: build the approved spec as one MSP of three Steps: Build now from the handed-off spec, one MSP meadow-ground-fog, one pull request; criterion 5.4 stays unproven until the lab review.
- D2 Ship boundary: open the MSP pull request from the green head: Ship now from proven head b9583f85, listing the Windows smoke, the Android landmarks path, criterion 5.4 and the Note10+ check as unproven in the report.

## Open risks

- R1 The app's mist is an exact port of the prototype's (same 5 pockets, geometry and fogP), and the earlier meadow spec made the prototype the look reference; this change departs from it on purpose (intent Q4).
- R4 The lab releases every instance this session holds whenever a turn ends, which killed two Windows lab instances mid-run; smoke runs therefore go to a headless claude -p session that holds its own instance.

## Settled, do not reopen

## Where the details live

- Cause traced 2026-10-23: 5 overlapping pockets in lib/features/garden/scene/meadow_plants.dart _pockets, drawn in lib/features/garden/render/meadow_stage_painter.dart _paintPocket at 0.92*fogP (lib/features/garden/scene/meadow_palette.dart:220); heaviest/brightest in lib/features/garden/model/meadow_year.dart pick extremes regardless of sign
- Run home: ~/.mitosis/fireplace/meadow-ground-fog/ (CHARTER.md, worker-rules.txt, dispatch.zsh, run.zsh, suite.zsh, smoke-brief.md, rounds.md, items.json, graph.json, build-1.out, review/); mitosis run dir ~/.mitosis/runs/fireplace/meadow-ground-fog; accept.zsh copied to ~/.mitosis/fireplace/, whose findings.jsonl and do-not-flag.md link to the field-notes copies
- Interphase files: docs/specs/meadow-ground-fog.md (spec), .decisions.md, .record.json, .items.json; glossary terms Heaviest stretch, Brightest stretch and Mist in GLOSSARY.md
- Earlier meadow decisions: docs/specs/meadow.md (item 7 gates mist and butterflies on 6 mood days in 16) and docs/specs/meadow.decisions.md
- Prototype mist reference: docs/prototype/Meadow Scene.dc.html (pockets, --fogP)
- Mock-up kit: scratchpad mock/ (patched prototype copy taking URL params v=before|a|b, h hour, y year, pm/pd/pn peaks; headless Chrome renders; stack.py builds the comparison strips)
- Review records: review/round-<n>/meadow-ground-fog.md (each round's findings and outcomes), review/meadow-ground-fog.comment.md (the pull request comment)
