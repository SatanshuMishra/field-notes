# meadow-sharpening-hitch: Meadow sharpening hitch (deferred, low priority)
Status: blocked: Deferred by the owner on 2026-10-04 as not important (decision 01M42SN6TB0QAG1RKRVTDFS4NR); start only if the owner asks.
Updated: 2026-10-17T05:49:35.162Z
Next ids: c2 D1 R1 S1

## Goal

Optional follow-up the owner deferred on 2026-10-04 as not important: remove the stutter in the first 1.2 to 1.4 s after the Meadow opens, while the sharp scene bakes and fades in over the quick scene (spec docs/specs/meadow-quality-performance.md criterion 10.14: no frame over 33 ms). Pick it up only if the owner asks.

## Done when

- [ ] c1 No frame over 33 ms while the sharp scene bakes and fades in on the Note 10+ (spec 10.14)

## Where things stand

Converted from the old ledger.

## Next step

If the owner asks to investigate: start from MeadowStage's quick-then-sharp bake and its 300 ms opacity crossfade in lib/features/garden/scene/meadow_stage.dart. Measure with the device-pass shell benchmark built from ~/.mitosis/field-notes/meadow-sweep/device/scratch/meadow_shell_heat_test.dart, which prints MEADOW-SHARPEN-TIME and a build/raster breakdown of every frame over 33 ms, on a Note 10+ whose GPU thermal_pwrlevel reads 0. Baseline on main d0cd3b7a: 29 to 38 frames over 33 ms, longest 134 to 183 ms; Mac 247 ms once.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Sweep spec, criterion 10.14 and section 15 results (git-ignored, main checkout only): /Users/satanshumishra/Documents/DevLabs/fireplace/docs/specs/meadow-quality-performance.md
- Device-check kit: build.zsh, phone_run.zsh, scratch benches and results: /Users/satanshumishra/.mitosis/field-notes/meadow-sweep/device/
- Old ledger record: thread 01M42SNTH3RTM1Z8APW9G2V6Y4 in refs/logbook/archive/ledger
