Status: accepted
Date: 2026-07-29
Thread: prototype-design-alignment

## Context
Cluster C's execution closed when PR #84 merged (`48a7a74`), leaving two knowingly-incomplete MSPs: C5's 6px thumbnail caption (blocked on OQ-6) and three of C7's four poster-chrome rows (blocked structurally, evidenced in decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md). That record recommends three re-scoped shapes: the hatch into a small `media_placeholders.dart` MSP, the badge into an N3 MSP on `video_transport.dart`, and the chip only after a product ruling on its anchor. The next move was therefore a choice between re-scoping those rows now and cutting the Cluster D slice.

## Decision
The three C7 rows are DEFERRED to the §5.4 macOS visual pass, not re-scoped now. Cluster D (right rail, D1 -> D2/D3/D4) is cut and executed first, as direct `implementer` waves per decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md.

## Consequences
- The sequencing argument is the whole argument: §5.4 already owes a ruling on whether C7's missing badge and chip are acceptable at rest. Re-scoping the chip before that pass would lock the anchor decision the pass exists to make, and the chip is the row that explicitly needs a product ruling. The hatch and badge MSPs are cheap and unblocked, but splitting the three rows across two moments would spend the pass's context twice.
- §5.4 now carries FOUR rulings, not three: C1's flame cusp at (9,8), C5's tilt scatter, C7's badge/chip anchors, and the chip's tokenless ground `#2A241D`.
- Cluster D is independent of every deferred item — the right rail shares no file with `video_body.dart`, `video_transport.dart` or `media_placeholders.dart`.
- Rejected: cutting the hatch and badge MSPs now and holding only the chip. Rejected: running §5.4 before any further implementation, which idles the one cluster that is unblocked.
- Deferral is not cancellation. If §5.4 rules the missing chrome unacceptable, the three re-scoped MSPs land ahead of Cluster E.
