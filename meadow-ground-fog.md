# meadow-ground-fog: Turn the meadow's mist pockets into low ground fog that keeps flowers visible
Status: active
Updated: 2026-10-24T00:11:38.081Z
Next ids: c5 D1 R3 S1

## Goal

The Meadow's "Mist in the hollow" mist pockets stop hiding the flowers they sit over, at night, dawn and midday, while the drifting mist and the synced fireflies keep the meadow's feel; mist appears only for a stretch that was actually heavy.

## Done when

- [ ] c1 Combined mist-pocket peak opacity is capped per time of day and blooms stay readable at night, dawn and noon in owner-approved lab screenshots with meadowKeyProvider pinned
- [ ] c2 No mist pockets or heaviest-stretch landmark when the heaviest window's mean valence is zero or above, and no butterfly brightest-stretch bias when the brightest window's mean is zero or below
- [ ] c3 No frame-time regression on the Note10+ floor check
- [ ] c4 Pull requests opened through the pipeline, never merged

## Where things stand

Full lane, interphase feature pathway (standard size), slug meadow-ground-fog. Lighthouse readiness has nothing open; receipts.config.json is already committed. The interphase intent round (Q1 goal, Q2 why, Q3 success, Q4 look reference) is waiting for the owner's answer.

## Next step

Save the owner's intent answers as I1 to I4 in docs/specs/meadow-ground-fog.decisions.md, then build prototype-based mock-ups of the fog options (a copy of docs/prototype in the scratchpad, rendered in the built-in browser at night, dawn and noon) and ask the first frontier round with them.

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
