# The meadow keeps E1's shared stroke

Date: 2026-08-01
Status: accepted

E1's change to the shared `_stroke(d)` is ACCEPTED AS SHIPPED. No spec amendment, no
second stroke path, no revert of the meadow to `Palette.ink`. The question E1 declared
rather than silently chose is now closed by the user in favour of the shipped state.

Rationale: there is exactly ONE shared `_stroke(d)` and E1's mandate was precisely that it
stop hardcoding `Palette.ink`. Composition is preserved literally — every garden plant kept
its stem, leaf and centre at `height*0.42` with byte-identical geometry; only outline hue
and weight moved (at d=44: chrysanthemum 1.5 -> 0.8, spider lily 1.5 -> 1.8). The meadow's
outline colour was never named as a preserve item, so forking a shared painter to hold a
value nothing declared trades a real cost (two stroke paths to keep in step forever) for an
undeclared benefit.

Rejected: amending the spec and adding a second stroke path in
`lib/features/garden/paint/meadow_painter.dart`.

This rules on the MECHANISM, not on the pixels. The section 5.4 macOS visual pass on the
flower art is still owed and may still report a defect; if it does, that is a new finding
against the shipped art, not a reopening of this record.
