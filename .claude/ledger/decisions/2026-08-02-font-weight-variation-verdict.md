Status: accepted
Date: 2026-08-02
Thread: prototype-design-alignment

## Context
H1 could not capture a text-bearing golden until it was known which side of Flutter's
font-weight-variation breaking change the installed toolchain sat on. It blocked the last MSP.

## Decision
Flutter 3.44.8 sits on the POST-change side: `TextStyle.fontWeight` DOES drive a variable font's
`wght` axis. Proven empirically, corroborated by docs. Text-bearing goldens are safe to capture.

## Consequences
- Proven by a w100-w900 sweep, not a two-point compare: each family plateaus at its OWN fvar range
  (Instrument Sans 400-700, Newsreader 200-800, Caveat 400-700), which synthetic bold cannot make.
- **Weights outside a family's fvar range are silent no-ops** — w100-w300 are identical to w400 in
  Instrument Sans and Caveat, so a test distinguishing them passes while asserting nothing.
- `pubspec.yaml:22`'s `sdk: ^3.12.2` is the DART constraint and does NOT pin Flutter; H1 added
  `environment: flutter: '>=3.41.0'`. A downgrade below 3.41 or an fvar shift silently invalidates
  every text-bearing golden. Full evidence: sessions/2026-08-02-02.
