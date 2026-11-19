# peony-opening-animation: Opening animation: a planted peony the wind takes apart before Today fades in
Status: active
Updated: 2026-11-19T08:14:26.366Z
Next ids: c6 D1 R1 S1

## Goal

Replace the instant cold-start jump to Today with a short opening animation: a planted peony whose petals and leaves blow away in the wind, then a smooth fade into the Today page, so the app feels smoother when it opens.

## Done when

- [ ] c1 The owner has picked one of the prototyped versions
- [ ] c2 Opening the app fresh plays the picked animation and fades smoothly into Today (or wherever the app opens), with Today built underneath and ready when it shows
- [ ] c3 Returning to the app from the background and the very first launch with onboarding play no animation
- [ ] c4 A tap, click or any key skips to Today within a quarter of a second, and with reduce motion on the peony shows still before a short crossfade
- [ ] c5 Android's launch screen and the Mac window open on the paper colour, so no white flash appears before the peony

## Where things stand

Not started.

## Next step

Wait for the owner to pick a version (A Gust, B Ink sketch, C Linger or D Quick breeze) on the prototype page, then build the picked version in Flutter through the standard lane with one review round and open a pull request.

## Decisions in force

## Open risks

## Settled, do not reopen

## Where the details live

- Prototype page: https://claude.ai/artifact/Q71f1M1joThu2rWHkUC6k6 holds the four versions, their timings and the shared defaults
- Peony art: lib/design/flowers/garden_plant_geometry.dart (peonyPlantParts) and lib/design/flowers/petal_art.dart (drift petal)
- App root and start-up wait: lib/app/app.dart; similar splash: lib/features/updates/ui/update_restart_splash.dart
- Android launch screen: android/app/src/main/res/drawable/launch_background.xml and values/styles.xml
