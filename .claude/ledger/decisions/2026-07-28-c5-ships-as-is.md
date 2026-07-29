Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
C5 was validated and opened as PR #82 (head `183b6b5`, 904 passed / 0 failed, analyze clean) carrying two unresolved items. First, the slice's C5 table mandates a 6px monospace thumbnail caption, but `EntryPhoto` (`lib/domain/models/`) has no label field, so shipping the caption means inventing domain data and thereby answering OQ-6 as a side effect of a styling MSP. Second, the slice's mechanism ("alternating by entry id parity: odd -0.5deg, even +0.4deg") is implemented exactly, but `Entry.id` is a ULID, so parity scatters pseudo-randomly rather than the strict left-right-left the acceptance criterion describes.

## Decision
C5 ships as-is on both counts. The caption stays UNSHIPPED and OQ-6 stays OPEN, to be answered deliberately rather than settled by a styling MSP. The tilt stays on id parity and is judged at the §5.4 macOS visual pass, not from the spec text.

## Consequences
- C5 is knowingly incomplete against its own target table; `Type.monoThumbSans` stays unconsumed. This is a recorded gap, not an oversight — the thread's completion criterion still requires OQ-6 to be answered or explicitly closed.
- The tilt question is deferred, not settled. §5.4 must rule on whether scatter reads as hand-placed (keep) or as noise (switch to feed-index parity). Strict alternation needs a feed index passed into `EntryCard`, which is outside C5's file fence and would need its own MSP.
- §5.4's macOS pass now carries two cluster-wide rulings: C1's flame cusp at (9,8) and C5's tilt.
- Rejected: binding the caption to a derivable value (index, filename) for visual parity. It would set a de facto answer to OQ-6 that is hard to walk back.
