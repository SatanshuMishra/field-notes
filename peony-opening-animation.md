# peony-opening-animation: Opening animation: a planted peony the wind takes apart before Today fades in
Status: active
Updated: 2026-11-19T10:58:58.674Z
Next ids: c6 D3 R2 S2

## Goal

Replace the instant cold-start jump to Today with a short opening animation: a planted peony whose petals and leaves blow away in the wind, then a smooth fade into the Today page, so the app feels smoother when it opens.

## Done when

- [x] c1 The owner has picked one of the prototyped versions evidence: Owner picked B (Ink sketch) on 2026-11-19 and asked for its drawing, Mac wind and a blow-away title to be reworked and built; the owner then skipped the title for now and asked for a slower drawing; round two at https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 now preselects the mix being built: Flower first + Curls, no title, the pen at two thirds of its round-two speed
- [ ] c2 Opening the app fresh plays the picked animation and fades smoothly into Today (or wherever the app opens), with Today built underneath and ready when it shows
- [ ] c3 Returning to the app from the background and the very first launch with onboarding play no animation
- [ ] c4 A tap, click or any key skips to Today within a quarter of a second, and with reduce motion on the peony shows still before a short crossfade
- [ ] c5 Android's launch screen and the Mac window open on the paper colour, so no white flash appears before the peony

## Where things stand

The pipeline drive holds the run on feat/peony-opening (run home ~/.mitosis/fireplace/peony-opening): mitosis builds the 5 Steps, then reviewers judge and it opens the pull request. The stopped first run's pushed branch feat/peony-opening-animation and run home ~/.mitosis/fireplace/peony-opening-animation remain until the owner says to clean them up. The first run, with the title and the faster pen, is stopped; its pushed branch feat/peony-opening-animation and run home ~/.mitosis/fireplace/peony-opening-animation remain.

## Next step

The drive entered review and runs it next.

## Decisions in force

- D2 hand-off: build the retimed, title-free opening as a new standard-lane drive under slug peony-opening: Start a new standard-lane drive under slug peony-opening from docs/specs/peony-opening.md; the owner merges the resulting pull request. The stopped run's branch and run home stay until the owner says to clean them up.

## Open risks

- R1 Spec criterion 5.14 is unproven by the build: the launch flash, real-renderer smoothness and platform screen readers are seen only on VM lab devices after the build. Bears on c5.

## Settled, do not reopen

- S1 A pipeline run whose drive has started cannot be amended or set up again; a spec change after that needs a new slug and run home.

## Where the details live

- Prototype page: https://claude.ai/artifact/Q71f1M1joThu2rWHkUC6k6 holds the four versions, their timings and the shared defaults
- Round two: https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 is the reference engine for the build (visible-arc pen schedule, blob washes, plant-unit curl ribbons, slower pen timings)
- Build spec: docs/specs/peony-opening.md with its .record.json, .items.json, .decisions.md and .mock/ frames and prototype copy; glossary term Opening in GLOSSARY.md and docs/adr/0012-decide-the-opening-once-per-program-start-at-the-entry-point.md
- Run facts: ~/.mitosis/fireplace/peony-opening/facts.json
- Peony art: lib/design/flowers/garden_plant_geometry.dart (peonyPlantParts) and lib/design/flowers/petal_art.dart (drift petal)
- App root and start-up wait: lib/app/app.dart; similar splash: lib/features/updates/ui/update_restart_splash.dart
- Android launch screen: android/app/src/main/res/drawable/launch_background.xml and values/styles.xml
