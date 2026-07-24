# Combined camera-lifecycle + dependency-upgrade into one PR

Status: accepted
Date: 2026-07-24

## Decision
`fix/macos-camera-lifecycle` and `chore/package-upgrade` ship as ONE branch
(`fix/macos-camera-lifecycle-and-deps`, PR #34), not two sequential PRs. Merge order was moot:
the diffs share zero files and both merged `--no-ff` cleanly. Rationale: one hardware-test pass
instead of two, and the human is the only one who can observe the menu-bar camera indicator.

## Risk that justified re-verification
A clean textual merge does NOT clear a semantic interaction — the sweep bumps `camera` to 0.12.0+2
while the other branch patches the vendored `camera_macos` Swift plugin. Re-verified on the merged
result: analyze clean, 704 unit + 4 macOS integration passing, macOS debug build OK.

## Non-derivable finding
`camera` 0.12.0+2 CANNOT register a competing macOS camera plugin: its pubspec declares
android/ios/web only (no `macos:` key) and `camera_avfoundation` 0.10.2 ships no `macos/` dir.
Confirmed at 4 layers (pubspec, pub cache, Podfile.lock, built app Frameworks/); registrant sha
identical before/after a regenerating build. Retires the per-bump registrant guard for macOS camera.
