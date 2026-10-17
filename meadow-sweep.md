# meadow-sweep: Meadow sweep: device check, water-sparkle regression and sharpening hitch
Status: done
Updated: 2026-10-17T05:49:35.162Z
Next ids: c7 D4 R4 S2

## Goal

The Meadow quality and performance sweep shipped in PRs #258, #259 and #260 (spec docs/specs/meadow-quality-performance.md). Finish it by meeting the spec's device criteria 10.14 to 10.20 on the Note 10+ and the Mac: first the noon regression the 2026-10-03 device check traced to the layer-free water sparkles, then the hitch while the sharp scene fades in, then the owner's look judgments.

## Done when

- [x] c1 A meadow with 366 flowers stays smooth on Android and macOS without changing its look or feel evidence: On merged main (d0cd3b7a, PR #261), Meadow shell benchmark, seed pinned, 10 s per case. Note 10+ (GPU thermal_pwrlevel 0, two runs alternating with the pre-fix build): noon 61.9 to 62.0 fps, raster p90 14.0 to 14.1 ms (619 to 620 frames; the pre-fix build ran 36.1 to 36.4 fps, p90 29.5 to 29.7 ms); midnight and unfocused keep-moving 61.8 to 62.0 fps. Owner's MacBook Pro (Mac16,8, 120 Hz, run in the background with approval, two runs alternating with the pre-sweep build): main noon 123.5 to 123.6 fps and midnight 123.5 fps at raster p50 3.5 to 3.6 ms, against pre-sweep 123.1 to 124.8 fps at 3.5 to 3.7 ms. Lab Mac VM: noon 59.7 to 61.9 fps at 2.2 to 3.0 ms (pre-fix 7 to 7.6 fps). Look: phone screenshots of the fix against the pre-fix build match within 2/255 at noon and exactly at midnight; live noon frames show the full glint trail; the owner judged the s100 build's look good on both platforms. Not observed: full screen and the study view were not benchmarked.
- [~] c2 No frame over 33 ms while the sharp scene bakes and fades in on the Note 10+ (spec 10.14) struck: struck in the old ledger
- [x] c3 Water sparkles and the night overlay look as they did before the off-screen layers were removed (spec 10.20) evidence: 2026-10-03 on the Note 10+ (SM-N975W, Impeller OpenGL ES), deterministic shot harness with the Meadow seed pinned to 20280229, reduced motion, sky clock fixed, wave-1 build ecc8675f (layered water sparkles and night overlay) against main a13cd6e4 (layer-free), scene area 0,201 to 1080,1913 px. Repeat launches of each build are identical (max 0). Noon: mean 0.002/255, 0.04% of pixels over 2, max 12. Midnight: mean 0.010/255, 0.04% over 2, max 14. A 20x amplified difference map shows only one faint water oval at noon, and at midnight a one-pixel line along the night overlay's ridge edge plus 1 to 2/255 gradient banding arcs. Judged by eye in side-by-side crops: no visible change. Not observed: animated sparkles in motion (the harness holds the scene still).
- [x] c4 The phone's header and bottom bar glass look as before, and the owner accepts the grouped dock glass (spec 10.16) evidence: Note 10+ screenshots, seed pinned, wave-1 build (separate blurs) against main: the Today page is pixel-identical; the Meadow header and bottom bar differ only along anti-aliased edges (max 9 to 15/255, at most 2% of pixels); the dock buttons differ by a mean of 0.6 to 1.8/255, invisible side by side. The fix in PR #261 leaves the glass identical to the pre-fix build. The owner looked at the s100 build on the Note 10+ and the Mac and said: "I tested the look previously. the s100 blur version looked good."
- [x] c5 The owner compares scene scale 1.0, 0.85 and 0.75 on the Note 10+ and the Mac and chooses whether either platform steps down (spec 10.17) evidence: The owner compared seeded side-by-side builds (pre-sweep, 100%, 85%, 75%) on the Note 10+ and the Mac on 2026-10-03 and said: "The `s100` version is acceptable on both macOS and Android." Both scene-scale constants stay at 1.0; recorded in docs/specs/meadow-quality-performance.decisions.md and decision 01M42MNJJ2DT2X5GHWYFEASCRD.
- [x] c6 Heat and memory over 10 minutes are reported against the pre-sweep build and the owner judges them (spec 10.18) evidence: Heat runs on merged main d0cd3b7a, reported in spec section 15. Note 10+: 300 s rest at 28.5 C, 600 s noon to 36.5 C at 59.8 fps, 600 s unfocused keep-moving to 41.2 C at 59.7 fps, Android thermal status 0, GPU cap level 2 at the end with no frame-rate loss, PSS 246 to 252 MB, scene images 271 MB. Owner's MacBook Pro: 600 s noon at 111 fps and 600 s unfocused at 116 fps, thermal state nominal to fair with no pmset warning, app RSS under 178 MB, scene images 123 MB, two unexplained stalls (2.2 s, 0.85 s). Against pre-sweep on the phone: 34.5 to 41.1 C over 600 s noon at 46 fps. The owner judged the results: "Heat verdict is acceptable."

## Where things stand

Converted from the old ledger.

## Next step

Ask the owner to judge the heat and memory results (criterion 6; spec 10.18, results in docs/specs/meadow-quality-performance.md section 15 under "After the fix merged"). Then decide with the owner how to take on the sharpening hitch (criterion 2): on the Note 10+ the sharp bake congests the raster thread for 1.2 to 1.4 s, with 29 to 38 frames over 33 ms and the longest 134 to 183 ms; the Mac showed a 247 ms sharpening frame once. Start from MeadowStage's quick-then-sharp bake and the 300 ms opacity crossfade in lib/features/garden/scene/meadow_stage.dart, honouring the decision to pace builds by GPU feedback rather than numbers tuned to one phone.

## Decisions in force

- D1 Keep the Meadow scene at 100% scale on both macOS and Android: The owner said "The `s100` version is acceptable on both macOS and Android." meadowSceneScaleAndroid and meadowSceneScaleMacos stay at 1.0; no code change. Recorded in the sweep decisions file.
- D2 Keep the glints and draw all water marks in one masked pass: One masked pass. The owner said "1ms cost is fine" and asked for the change to be built directly, without a new spec or mitosis run. Criterion 10.8 is amended from no saveLayer to exactly one, for the water marks. Built on branch fix/meadow-water-marks-one-pass (b4454b3d), PR #261.
- D3 Defer the Meadow sharpening hitch as not important: Deferred. The owner said "Skip the Sharpening hitch. It's not important. Record it as such so that I may return to investigate it in the future if I want to." Criterion 2 is struck from this thread; a deferred, low-priority thread carries the evidence and a starting point.

## Open risks

- R1 While the sharp scene bakes and crossfades (2.1 to 2.6 s on the Note 10+) nearly every frame exceeds 33 ms; the longest was 134 to 180 ms in normal runs. The breakdown shows raster-thread congestion behind the sharp bakes (build 5 to 15 ms, raster 20 to 90 ms, the rest waiting), with the 300 ms opacity crossfade at the end. Bears on c2.
- R2 After about 50 minutes of continuous Meadow load the Note 10+ caps its GPU (thermal_pwrlevel 2 of 0 to 4 at a 44 to 45 C battery, AP 47.6 C) while Android's thermal status still reads 0; two probes run then were 2.3 times slower, matching the lowest GPU level. Benchmarks taken on a warm phone are invalid unless thermal_pwrlevel reads 0. Bears on c6.
- R3 In the 22-minute heat run on the owner's MacBook Pro (main d0cd3b7a, 120 Hz), the Meadow averaged 111 fps at noon and 116 fps unfocused, but logged one 2.2 s stall at noon and one 0.85 s stall unfocused, and its slowest 1% of frames rose to 16 to 17 ms against 6.5 ms in 10-second runs. No display, lock or power event was logged; macOS thermal state reached fair, with no warning. Cause unknown; not seen in short runs. Bears on c6.

## Settled, do not reopen

- S1 Out of scope: The hitch while the sharp scene bakes and fades in (spec 10.14): deferred by the owner on 2026-10-04 as not important (decision 01M42SN6TB0QAG1RKRVTDFS4NR); carried by the deferred thread meadow-sharpening-hitch.

## Where the details live

- Sweep spec (git-ignored, main checkout only): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow-quality-performance.md
- Sweep decisions (binding): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow-quality-performance.decisions.md
- Sweep record: /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow-quality-performance.record.json
- Device-check kit: build.zsh, phone_run.zsh, scratch benches, probe apps, results: /Users/satanshumishra/.mitosis/field-notes/meadow-sweep/device/
- Mitosis run template for the sweep: /Users/satanshumishra/.mitosis/field-notes/meadow-sweep/
- Old ledger record: thread 01M42HJ47R06WVESJRZSXMQP1K in refs/logbook/archive/ledger
