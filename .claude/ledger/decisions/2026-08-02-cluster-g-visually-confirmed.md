Status: accepted
Date: 2026-08-02
Thread: prototype-design-alignment

## Context
Cluster G's eight MSPs merged as stack 121 with all nine PRs carrying a not-verified line for the
visual pass. G8 additionally shipped a KNOWN degradation: `camera_macos` implements no pause in
either its Dart or Swift layer, so video pause is unreachable on macOS.

## Decision
The user merged the stack and ran the macOS pass over Cluster G. It PASSED — composer shell, note
paper surface, chooser bottom sheet, voice stage, dark video viewport. Criterion 4 is MET for
Clusters A-G. The degraded macOS pause path reads acceptably and is ACCEPTED as shipped: G8's pause
criterion is met on Android only, and that asymmetry stands.

## Consequences
- Patching the vendored `camera_macos` for pause support is a separate MSP, not a G8 defect.
  Rejected: widening G8's fence into `third_party/` mid-cluster.
- NOT closed by a visual pass: #119's undeclared `SettingsSelect` Flexible/ellipsis ride-along and
  #120's failed-save re-arm hole (timer half pre-existing on main; frozen readout new).
