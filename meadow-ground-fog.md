# meadow-ground-fog: Turn the meadow's mist pockets into low ground fog that keeps flowers visible
Status: parked
Updated: 2026-10-24T06:20:43.555Z
Next ids: c5 D3 R5 S1

## Goal

The Meadow's "Mist in the hollow" mist pockets stop hiding the flowers they sit over, at night, dawn and midday, while the drifting mist and the synced fireflies keep the meadow's feel; mist appears only for a stretch that was actually heavy.

## Done when

- [x] c1 Combined mist-pocket peak opacity is capped per time of day and blooms stay readable at night, dawn and noon in owner-approved lab screenshots with meadowKeyProvider pinned evidence: the owner approved the mist's look as shipped in release 1.4.1 on their own install ("the mist looks right"), with no peak raised; the per-time-of-day cap is fogP times MeadowWindow.mistStrength, and the lab screenshots with meadowKeyProvider pinned are in the lighthouse run-1 evidence
- [x] c2 No mist pockets or heaviest-stretch landmark when the heaviest window's mean valence is zero or above, and no butterfly brightest-stretch bias when the brightest window's mean is zero or below evidence: criterion 5.1's three tests (meadow_year_test sign gates, meadow_landmarks_test both cards) pass in the round 1 full suite at 91683e62, and the conformance audit judged 5.1 MET
- [x] c3 No frame-time regression on the Note10+ floor check evidence: Note10+ floor check, Meadow at midnight with the pinned meadow and a heavy stretch drawing mist, 3 runs of 30 s per build in balanced order with the GPU at full speed: median frame time 18.54 ms at 4f9aa3a6 vs 18.58 ms at 19b691c3 (+0.04), 95th percentile 21.34 vs 21.17 ms (-0.17), both within the 0.5 ms limit; results in ~/.mitosis/field-notes/meadow-fog-floor/floor.log
- [x] c4 Pull requests opened through the pipeline, never merged evidence: SatanshuMishra/field-notes#335 opened ready for review through the pipeline (mitosis title and body, GitHub MCP), base feat/meadow-ground-fog, assigned to the owner, not merged

## Where things stand

The change is in release 1.4.1 (tag v1.4.1 on 19b691c3, changelog in SatanshuMishra/field-notes#337), published on GitHub with its installers and update feed, with the Google Play upload running. Only c1 stays open: the owner's approval of the mist's look, which in the lab VM is a faint low haze at noon and midnight; each time of day's peak may rise by up to 0.15. Windows was never run (winpc offline).

## Next step

Nothing left: the thread closes as done.

## Decisions in force

## Open risks


## Settled, do not reopen

## Where the details live

- Cause traced 2026-10-23: 5 overlapping pockets in lib/features/garden/scene/meadow_plants.dart _pockets, drawn in lib/features/garden/render/meadow_stage_painter.dart _paintPocket at 0.92*fogP (lib/features/garden/scene/meadow_palette.dart:220); heaviest/brightest in lib/features/garden/model/meadow_year.dart pick extremes regardless of sign
- Run report: ~/.mitosis/fireplace/reports/meadow-ground-fog.json (stage times, waits, lead time); the run's findings ledger is ~/.mitosis/fireplace/findings.jsonl
- Glossary terms Heaviest stretch, Brightest stretch and Mist in GLOSSARY.md; the mist strength rule is MeadowWindow.mistStrength in lib/features/garden/model/meadow_year.dart
- Earlier meadow decisions: docs/specs/meadow.md (item 7 gates mist and butterflies on 6 mood days in 16) and docs/specs/meadow.decisions.md
- Prototype mist reference: docs/prototype/Meadow Scene.dc.html (pockets, --fogP)
- Mock-up kit: scratchpad mock/ (patched prototype copy taking URL params v=before|a|b, h hour, y year, pm/pd/pn peaks; headless Chrome renders; stack.py builds the comparison strips)
- Pull requests: SatanshuMishra/field-notes#335 (the change, with its review notes) and #336 (the integration, listing what lighthouse verified and what stayed unproven)
