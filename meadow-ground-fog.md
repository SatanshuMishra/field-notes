# meadow-ground-fog: Turn the meadow's mist pockets into low ground fog that keeps flowers visible
Status: active
Updated: 2026-10-24T00:31:41.928Z
Next ids: c5 D1 R3 S1

## Goal

The Meadow's "Mist in the hollow" mist pockets stop hiding the flowers they sit over, at night, dawn and midday, while the drifting mist and the synced fireflies keep the meadow's feel; mist appears only for a stretch that was actually heavy.

## Done when

- [ ] c1 Combined mist-pocket peak opacity is capped per time of day and blooms stay readable at night, dawn and noon in owner-approved lab screenshots with meadowKeyProvider pinned
- [ ] c2 No mist pockets or heaviest-stretch landmark when the heaviest window's mean valence is zero or above, and no butterfly brightest-stretch bias when the brightest window's mean is zero or below
- [ ] c3 No frame-time regression on the Note10+ floor check
- [ ] c4 Pull requests opened through the pipeline, never merged

## Where things stand

Full lane, interphase feature pathway (standard size), slug meadow-ground-fog. Lighthouse readiness has nothing open; receipts.config.json is already committed. Intent I1 to I4 and round 1 are saved in the decisions file (shape B, peaks night 0.9 / dawn 0.85 / noon 0.7, strength 60% to 100% by stretch mean, sign gates, four seams, ±0.15 lab tuning). The four seams are in the record and the meadow glossary terms are written. Round 2 (Q1 one pull request, Q2 painter pass rules: at most 0.5 mist cover at bloom heads and densest point within 0.05 of peak × strength, Q3 Note10+ rule: median and p95 over 3 runs of 30 s at most 0.5 ms worse than main) is waiting for the owner's answer.

## Next step

Save the round 2 answers to the decisions file, then write criteria 5.1 to 5.4 and Steps year-gates, mist-shape (after nothing) and mist-strength (after mist-shape) to the record, run check_record.py --complete, and hold the read-back.

## Decisions in force

## Open risks

- R1 The app's mist is an exact port of the prototype's (same 5 pockets, geometry and fogP), and the earlier meadow spec made the prototype the look reference; this change departs from it on purpose (intent Q4).
- R2 Existing tests pin today's behaviour and will change: meadow_year_test expects brightest == heaviest for one window; meadow_plants_test expects pocket.y < meanY and a height/width of 0.2 to 0.28; meadow_palette_test pins fogP values.

## Settled, do not reopen

## Where the details live

- Cause traced 2026-10-23: 5 overlapping pockets in lib/features/garden/scene/meadow_plants.dart _pockets, drawn in lib/features/garden/render/meadow_stage_painter.dart _paintPocket at 0.92*fogP (lib/features/garden/scene/meadow_palette.dart:220); heaviest/brightest in lib/features/garden/model/meadow_year.dart pick extremes regardless of sign
- Run home: ~/.mitosis/fireplace/meadow-ground-fog/
- Interphase files: docs/specs/meadow-ground-fog.decisions.md, .record.json, .guard.json (guard snapshot)
- Earlier meadow decisions: docs/specs/meadow.md (item 7 gates mist and butterflies on 6 mood days in 16) and docs/specs/meadow.decisions.md
- Prototype mist reference: docs/prototype/Meadow Scene.dc.html (pockets, --fogP)
- Mock-up kit: scratchpad mock/ (patched prototype copy taking URL params v=before|a|b, h hour, y year, pm/pd/pn peaks; headless Chrome renders; stack.py builds the comparison strips)
