# Prototype alignment — five open questions resolved

Status: accepted (2026-07-27)
Spec: `docs/specs/2026-07-26-prototype-design-alignment.md`

Five of the seven open questions in the alignment spec were resolved by the product owner. All five took the recommended option.

| OQ | Resolution | Consequence |
|---|---|---|
| OQ-1 sync footer copy | (a) prototype's two-line treatment, truthful strings | B4 unblocked. `Stored locally` / `on this device only` |
| OQ-2 streak longest value | (b) keep the number | C1 unblocked, becomes a pure restyle |
| OQ-4 desktop `Capture` button | (a) remove it | D3 promoted to final; three test files change with it |
| OQ-5 markdown placeholder | (b) truthful copy in the prototype's treatment | G2 unblocked. `Start writing…` only |
| OQ-7 video entry card | (a) keep the app envelope, adopt hatch/badge/chip | New MSP C7; rejects the prototype's 130px height |

Rationale shared by OQ-1 and OQ-5: the prototype describes capabilities the app does not have (remote sync, a markdown engine). Adopting its treatment is alignment; adopting its strings would ship a false claim. The pattern generalises — take the prototype's form, not its promises.

OQ-2 and OQ-7 are both cases where a faithful prototype value would delete something real: a longest-streak number the prototype never modelled, and a playback envelope that exists because the prototype never modelled playback. Design fidelity loses to capability.

OQ-4 is the one place an app-only element is deliberately dropped. Recorded so it is never mistaken for an accidental regression. Reachability was verified before accepting: the chooser survives via `app_shell.dart:30-32` -> `bottom_bar_shell.dart:116`, and `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof.

Still open, touching no MSP: OQ-3 (entry-card Edit/Delete placement) and OQ-6 (photo attachment model, entangled with `PhotoTray` being dead UI).
