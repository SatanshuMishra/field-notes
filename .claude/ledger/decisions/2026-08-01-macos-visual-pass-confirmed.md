Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment

## Context
The parent spec's §5.4 macOS visual pass had been owed since Cluster C and was the only check able to confirm Clusters C and D, which no automated gate covers. It was recorded as owing four rulings: C1's flame cusp at (9,8), C5's tilt scatter, C7's badge and chip anchors, and the chip's tokenless ground `#2A241D`. The user ran main at `cfa04c7` (slice + D1 + D3 landed) via `flutter run -d macos` and confirmed everything renders as expected.

## Decision
The §5.4 macOS visual pass PASSES on `cfa04c7` with no defects reported. Thread completion criterion 4 — the Today screen, right rail, nav rail, flower set, mood picker and capture surfaces human-confirmed against the prototype on macOS hardware — is MET for everything shipped to date, which covers C1's flame cusp and C5's tilt scatter.

## Consequences
- Clusters A, B, C and the landed part of D (D1, D3) are visually confirmed. Later MSPs still need their own pass; this ratifies the current tree, not future work.
- C7's badge and chip anchors are NOT settled by this pass and remain open. They were never shipped — `decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md` proves them structurally blocked, so there is nothing on screen to rule on. The same holds for the chip's `#2A241D` ground, which is a token-layer question, not a rendering one.
- C5's known-incomplete 6px caption (`decisions/2026-07-28-c5-ships-as-is.md`) is unaffected; OQ-6 still blocks that target value.
- The visual pass is cheap to re-run and is now the standing confirmation step after each cluster lands.
