Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment

## Context
E1 changed the ONE shared `_stroke(d)` and declared the consequence rather than silently
choosing: the meadow's outline hue and weight moved with every other plant's.

## Decision
Accepted as shipped. No revert to `Palette.ink`, no spec amendment, no second stroke path.

## Consequences
E1's mandate was precisely that the stroke stop hardcoding `Palette.ink`. Composition is
preserved literally — every garden plant kept its stem, leaf and centre at `height*0.42` with
byte-identical geometry; only outline hue and weight moved (at d=44: chrysanthemum 1.5 -> 0.8,
spider lily 1.5 -> 1.8). The meadow's outline colour was never a declared preserve item, so
forking a shared painter to hold an undeclared value costs two stroke paths kept in step forever
and buys nothing. Rejected: the amendment plus a second path in `meadow_painter.dart`.
This rules on the MECHANISM, not the pixels. The section 5.4 macOS visual pass on the flower
art is still owed; a defect it reports is a new finding, not a reopening of this record.
