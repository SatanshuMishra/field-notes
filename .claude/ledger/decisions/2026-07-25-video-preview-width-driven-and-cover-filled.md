Status: accepted
Date: 2026-07-25
Thread: video-card-playback-controls

## Context
The preview never grew vertically (`_videoHeight = 200` was flat) and the video was letterboxed because
`buildSurface()` applied NO `BoxFit` — a bare `AspectRatio` under a `Center` that RELAXED the tight
`StackFit.expand` constraints, exposing the cross-hatch. The poster already used cover, so the two
disagreed and the preview JUMPED at playback start — a latent, unreported mismatch.

## Decision
Size the box from its own WIDTH at 21:9 with a 200px floor and no cap (`ConstrainedBox(minHeight) ->
AspectRatio`), and cover-fill the surface via `FittedBox(fit: cover)` over a ratio-carrying unit `SizedBox`.

## Consequences
Heights: 400 -> 200 (floor), 1200 -> 514, 2000 -> 857. `_videoAspectRatio` is one constant so hardware can
retune it without touching receipts. REJECTED: a `maxHeight` cap (reinstates the flat height, just larger);
16:9 (675px at the user's width, one card fills the viewport); 3:1 (crops ~40% off a 16:9 source, cutting
off faces). The FLOOR stays because a pure ratio makes the preview SHORTER than today on narrow windows.
CAVEAT: 856 stayed green only because the 360px harness lands on the floor, so the responsive band is UNRECEIPTED. Proof, height table and probes: sessions/2026-07-25-02-video-card-playback-controls.md.
