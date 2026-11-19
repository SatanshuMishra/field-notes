# peony-opening-animation: Opening animation: a planted peony the wind takes apart before Today fades in
Status: parked
Updated: 2026-11-19T22:59:29.809Z
Next ids: c6 D3 R3 S2

## Goal

Replace the instant cold-start jump to Today with a short opening animation: a planted peony whose petals and leaves blow away in the wind, then a smooth fade into the Today page, so the app feels smoother when it opens.

## Done when

- [x] c1 The owner has picked one of the prototyped versions evidence: Owner picked B (Ink sketch) on 2026-11-19 and asked for its drawing, Mac wind and a blow-away title to be reworked and built; the owner then skipped the title for now and asked for a slower drawing; round two at https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 now preselects the mix being built: Flower first + Curls, no title, the pen at two thirds of its round-two speed
- [x] c2 Opening the app fresh plays the picked animation and fades smoothly into Today (or wherever the app opens), with Today built underneath and ready when it shows evidence: VM lab on the CI release builds of the merged tree (run 44603032735): a fresh start on Windows, macOS and Android, light and dark, plays the pen drawing, three wind curls and blow-away, and Today fades in ready about 2.6 to 2.9 s after the first frame; on Android a tap mid-drawing fades into Today about 0.3 s after the touch, and with animations off the still drawing crossfades in about 0.3 s; frames kept in ~/VMLab/evidence/fireplace/peony-opening; smoothness judged on VM renderers only
- [x] c3 Returning to the app from the background and the very first launch with onboarding play no animation evidence: on main via #393: test/app/opening_start_test.dart decides the opening once per program start at the entry point and skips it when onboarding shows; all 42 spec checks pass on the merged tree
- [x] c4 A tap, click or any key skips to Today within a quarter of a second, and with reduce motion on the peony shows still before a short crossfade evidence: on main via #393: test/features/opening/opening_cover_test.dart and its clock-step and decision-arrival tests pass for tap, click and key skips within 0.25 s and the reduce-motion still drawing then 0.3 s crossfade
- [x] c5 Android's launch screen and the Mac window open on the paper colour, so no white flash appears before the peony evidence: VM lab: the Android splash and launch window and the macOS window open on the light and dark paper with no white frame in any recording (Android screenrecord and macOS screencapture keep every changed frame); frames kept in ~/VMLab/evidence/fireplace/peony-opening

## Where things stand

The opening is on main through pull request #393, its pipeline run is cleaned up, and the VM lab pass is done: every criterion holds, and the one defect found is the Windows white window in R2. The version was not bumped: pubspec holds 1.0.0 while releases are tagged v1.9.1. The owner chose to keep the stopped first run for now: its branch feat/peony-opening-animation equals main, and its only built work, the native-paper Step at 3d7d59c1 in its worktree, was rebuilt by the new run.

## Next step

The work is done and the thread can close once the owner decides whether to fix R2, the Windows white window, as a separate change; if yes, give the runner window a paper-coloured background or keep it hidden until Flutter has drawn, then recheck in the VM lab with the high-priority capture.

Needs: R2.

## Decisions in force

- D2 hand-off: build the retimed, title-free opening as a new standard-lane drive under slug peony-opening: Start a new standard-lane drive under slug peony-opening from docs/specs/peony-opening.md; the owner merges the resulting pull request. The stopped run's branch and run home stay until the owner says to clean them up.

## Open risks

- R2 On Windows the window intermittently fades in pure white before its first paper frame: 3 of 5 lab launches, 0.4 s on the first launch after install and 0.15 s on a dark start; the runner shows the window on the first-frame callback with no window background (windows/runner/win32_window.cpp hbrBackground 0), and it is unconfirmed on real GPU hardware

## Settled, do not reopen

- S1 A pipeline run whose drive has started cannot be amended or set up again; a spec change after that needs a new slug and run home.

## Where the details live

- Prototype page: https://claude.ai/artifact/Q71f1M1joThu2rWHkUC6k6 holds the four versions, their timings and the shared defaults
- Round two: https://claude.ai/artifact/KMyaKfwrCB2XcdPisHSpU7 is the reference engine for the build (visible-arc pen schedule, blob washes, plant-unit curl ribbons, slower pen timings)
- Build spec: docs/specs/peony-opening.md with its .record.json, .items.json, .decisions.md and .mock/ frames and prototype copy; glossary term Opening in GLOSSARY.md and docs/adr/0012-decide-the-opening-once-per-program-start-at-the-entry-point.md
- Peony art: lib/design/flowers/garden_plant_geometry.dart (peonyPlantParts) and lib/design/flowers/petal_art.dart (drift petal)
- App root and start-up wait: lib/app/app.dart; similar splash: lib/features/updates/ui/update_restart_splash.dart
- Android launch screen: android/app/src/main/res/drawable/launch_background.xml and values/styles.xml
- Lab evidence: ~/VMLab/evidence/fireplace/peony-opening holds the proof frames for each platform and the two Windows white-window frames
- Windows window start-up: windows/runner/flutter_window.cpp shows the window on the first-frame callback; windows/runner/win32_window.cpp registers the window class with no background
