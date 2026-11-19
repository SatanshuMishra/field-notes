# peony-opening-animation: Opening animation: a planted peony the wind takes apart before Today fades in
Status: active
Updated: 2026-11-19T09:56:01.115Z
Next ids: c6 D2 R1 S1

## Goal

Replace the instant cold-start jump to Today with a short opening animation: a planted peony whose petals and leaves blow away in the wind, then a smooth fade into the Today page, so the app feels smoother when it opens.

## Done when

- [x] c1 The owner has picked one of the prototyped versions evidence: Owner picked B (Ink sketch) on 2026-11-19 and asked for its drawing, Mac wind and a blow-away title to be reworked and built; round two at https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 preselects the mix being built: Flower first + Curls + Signed beneath
- [ ] c2 Opening the app fresh plays the picked animation and fades smoothly into Today (or wherever the app opens), with Today built underneath and ready when it shows
- [ ] c3 Returning to the app from the background and the very first launch with onboarding play no animation
- [ ] c4 A tap, click or any key skips to Today within a quarter of a second, and with reduce motion on the peony shows still before a short crossfade
- [ ] c5 Android's launch screen and the Mac window open on the paper colour, so no white flash appears before the peony

## Where things stand

The pipeline drive holds the run on feat/peony-opening-animation (run home ~/.mitosis/fireplace/peony-opening-animation): mitosis builds the 5 Steps, then reviewers judge and it opens the pull request. Criterion 5.15 (real-device launch and smoothness) stays unproven for the VM lab.

## Next step

Wait for the pipeline drive to rest; when it does, relay its next sentence and pull request links, then park the thread for the owner's merge.

## Decisions in force

- D1 hand-off: build the opening through the standard-lane pipeline drive: Hand the spec to the pipeline drive; the owner merges the resulting pull request.

## Open risks

## Settled, do not reopen

## Where the details live

- Prototype page: https://claude.ai/artifact/Q71f1M1joThu2rWHkUC6k6 holds the four versions, their timings and the shared defaults
- Round two: https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 is the reference engine for the build (visible-arc pen schedule, blob washes, plant-unit curl ribbons, title write and blow-away, timings); local source in the session scratchpad peony-opening/peony-ink.html
- Build spec: docs/specs/peony-opening-animation.md with its .record.json, .items.json, .decisions.md and .mock/ frames; glossary term Opening in GLOSSARY.md and docs/adr/0012-decide-the-opening-once-per-program-start-at-the-entry-point.md
- Run facts: ~/.mitosis/fireplace/peony-opening-animation/facts.json
- Peony art: lib/design/flowers/garden_plant_geometry.dart (peonyPlantParts) and lib/design/flowers/petal_art.dart (drift petal)
- App root and start-up wait: lib/app/app.dart; similar splash: lib/features/updates/ui/update_restart_splash.dart
- Android launch screen: android/app/src/main/res/drawable/launch_background.xml and values/styles.xml
