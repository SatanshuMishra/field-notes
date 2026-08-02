Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment

## Context
F4's slice prose (R10) said a FAILED mood write produces no sound cue. F4's own control-flow
block in the same slice, and prototype `:1348` where the confirm and no-existing-mood branches
converge, both play the `pencil` cue BEFORE the write. The slice contradicted itself, and the
contradiction is observable only on the write-failure path.

## Decision
The cue fires BEFORE the write, per the control-flow block and the prototype: a failed write plays the cue and shows no toast. R10's prose is the defective half.

## Consequences
Only the DIALOG is gated on an existing mood; cue and toast fire on every successful write
through either branch. N20 intact — the cue routes through `GatedSoundService`, so it respects
the Sound effects setting and swallows playback errors, and the inline error string on a failed
write survives. Cheap to reverse (a statement reorder in one method; no test asserts the ordering)
if the audible-cue-then-silent-failure reads wrong on hardware. Rejected: R10's prose, which splits
the branches and contradicts the prototype the spec exists to match.
