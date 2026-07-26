# didUpdateWidget gate ratified as a Phase 1b spec amendment

Status: accepted (2026-07-25, user directive "Go" on the salvage brief)

MSP 2's round-3 park was a governance deadlock: the reviewer confirmed the fifth,
unrequested edit to `video_body.dart` (the `staysGated` branch in `didUpdateWidget`)
closes a REAL bypass — `today_entry_feed.dart:56-57` swaps `_PendingMediaResolver`
for the real resolver after first paint, so every poster card on Today re-enters
decode via `didUpdateWidget -> _restart`, ungated — but only a human may ratify
scope, and `fixLoopMax` cannot converge on that.

RATIFIED: Phase 1b's gate covers ALL passive entry points into decode (`initState`
AND `didUpdateWidget`), not `initState` alone. Only explicit user intent
(`_onTransportTap`, `_onRetryPressed`) may acquire a decoder slot on a
poster-bearing card. The interim `staysGated` form is superseded by plan Task 3
(`.mitosis/poster-first-decode-gate.plan.md:513`): a pure `_hasCapturedPoster`
check routing to `_deferDecodeUntilIntent()`, which also RELEASES any held slot —
closing the reviewer's MEDIUM (`_needsMediaResolution` as an intent proxy).
Spec amended in place (Phase 1b) on the MSP 2 branch; amendment rides its PR.
