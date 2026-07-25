Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
The card now eagerly inits its player in `initState` per 2026-07-24-video-card-eager-player-and-controls,
which missed that the feeds are non-lazy `Column`s (`today_entry_feed.dart:57`, `day_detail_panel.dart:143`):
every card is alive at once, nothing is released on scroll, and concurrent hardware decoders are bounded
per process (~8-16 H.264). Past the ceiling `initialize()` throws, the catch calls `_markUnavailable()`,
and the card renders the RED placeholder this branch exists to remove.

## Decision
Gating video controller init is IN SCOPE for the video-card-playback-controls thread, sequenced BEFORE
the hover-reveal overlay. `_markUnavailable()` must also split retryable decoder unavailability from
genuine corruption and offer a retry.

## Consequences
Qualifies, does not supersede: eager init stays (it removed the one-way latch and is why the tree never
swaps); only WHEN it fires changes — visibility or first interaction, not build. Ordering it first avoids
rewriting overlay state around a changed trigger. A parallel session was rejected: same surfaces.
