Status: accepted
Date: 2026-08-02
Thread: prototype-design-alignment

## Context
H1's determinism requirement 2 makes a pinned-OS, pinned-SDK golden CI job non-optional, but
`receipts.yml` runs ubuntu-latest and executes no Dart test, while every gate here is macOS. R12.

## Decision
Add `.github/workflows/goldens.yml`: `macos-latest`, Flutter pinned to the exact string `3.44.8`,
`flutter test --tags golden`, failure artifacts uploaded, a `paths:` filter. `receipts.yml` untouched.

## Consequences
- macOS is FORCED, not preferred: the comparator is exact-pixel at zero tolerance and macOS/Linux
  differ in Skia rasterization and font hinting, so byte-identical PNGs are unachievable.
- COST: macOS runners bill at 10x, ~60-120 billable minutes per run; the `paths:` filter is the only
  thing keeping it off unrelated PRs.
- Rejected a percentage-tolerance comparator in all variants — a tolerance loose enough to absorb
  cross-OS font rendering also absorbs the one-pixel shadow regression this exists to catch.
- CI IS STILL NOT EVIDENCE, and the job HAS NEVER EXECUTED. Four defects: sessions/2026-08-02-02.
