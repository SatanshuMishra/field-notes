# Combined camera-lifecycle + dependency-upgrade into one PR

Status: accepted
Date: 2026-07-24

## Decision
`fix/macos-camera-lifecycle` and `chore/package-upgrade` ship as ONE branch
(`fix/macos-camera-lifecycle-and-deps`, PR #34), not two sequential PRs. Merge order was
moot: the two diffs share zero files and both merged `--no-ff` with zero conflicts.

## Why
User directed a single testable build. One branch means one hardware-test pass instead of two,
and the human is the only one who can observe the menu-bar camera indicator.

## The risk that justified re-verification
A clean textual merge does NOT clear a semantic interaction: the sweep bumps `camera` to 0.12.0+2
while the camera branch patches the vendored `camera_macos` Swift plugin. Re-verified from scratch
on the merged result — 704 unit + 4 macOS integration passing, analyze clean, macOS debug build OK.

## Non-derivable finding
`camera` 0.12.0+2 CANNOT register a competing macOS camera plugin: its pubspec declares
android/ios/web only (no `macos:` key), and `camera_avfoundation` 0.10.2 ships no `macos/` dir.
Confirmed at four layers (pubspec, pub cache, Podfile.lock, built app Frameworks/).
`GeneratedPluginRegistrant.swift` sha is identical before and after a regenerating build.
This retires the per-bump registrant guard as a manual worry for the macOS camera path.
