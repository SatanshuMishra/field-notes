# Video card preview is width-driven at 21:9 and cover-filled

Date: 2026-07-25
Status: accepted
Thread: video-card-playback-controls

The preview never grew vertically because `_videoHeight = 200` was a flat constant, and the
video was letterboxed because `buildSurface()` applied NO `BoxFit` at all — a bare
`AspectRatio(natural)` under a `Center` that RELAXED the tight `StackFit.expand` constraints,
exposing the cross-hatch layer beneath. The poster path already used `BoxFit.cover`, so the two
paths disagreed and the preview JUMPED the moment playback started. That mismatch was latent and
unreported; the fill request fixed it as a side effect.

Chosen: `ConstrainedBox(minHeight: 200) -> AspectRatio(21/9)`, plus `FittedBox(fit: cover)` over a
ratio-carrying `SizedBox(width: ratio, height: 1)` in `video_player_impl.dart`.

Ratio rationale — the source videos are themselves ~16:9. A 16:9 box would be 675px tall at the
user's ~1200px card width (one card fills the viewport); a 3:1 box would crop ~40% off a 16:9
source and cut off faces. 21:9 crops ~24% and reads cinematic. Heights: 400 -> 200 (floor),
640 -> 274, 1200 -> 514, 2000 -> 857. `_videoAspectRatio` is a single named constant so the
hardware run can retune it without touching receipts, the same affordance `hideAfter` gives the
overlay.

Rejected: a `maxHeight` cap — it reinstates exactly the flat-height behavior the user complained
about, just at a larger number. The `minHeight: 200` FLOOR is kept because a pure ratio makes the
preview SHORTER than today on narrow windows.

Cover input is the plugin-guarded `controller.value.aspectRatio`, not `controller.value.size`.
The plugin already returns 1.0 for degenerate sizes, so `Size.zero` never reaches a division; a
local `isFinite && > 0` check closes the NaN/infinity leaks the plugin's `<= 0` guard lets through.
A literal `height: 1` keeps the FittedBox source strictly positive on both axes. Raster quality is
unaffected — the surface is a `Texture` layer composited at device resolution, not rasterized at
the child's logical size.

CAVEAT: the suite stayed green at 856 because the widget harness is 360px wide, which lands
exactly on the 200px floor — identical geometry to before. The entire responsive band is
UNRECEIPTED. Styling is exempt under the test admission gate, but the green proves nothing about
this change; the hardware run is the only real evidence. This is the same green-and-blind shape
the thread already hit once.
