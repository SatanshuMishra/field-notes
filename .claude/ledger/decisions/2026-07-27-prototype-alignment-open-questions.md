Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
The alignment spec (`docs/specs/2026-07-26-prototype-design-alignment.md`) closed with seven open questions blocking named MSPs. Five were put to the product owner.

## Decision
All five resolved to the recommended option: OQ-1 (a) sync footer keeps the prototype's two-line treatment with truthful strings; OQ-2 (b) the streak card keeps its `longest` number; OQ-4 (a) the desktop `Capture` button is removed; OQ-5 (b) the note placeholder ships truthful copy; OQ-7 (a) the video entry card keeps the app's 21:9/200px envelope and adopts only the hatch, badge and chip.

## Consequences
- B4, C1, G2 unblocked; D3 promoted from interim to final; **new MSP C7** authored for OQ-7.
- Governing rule, from OQ-1 and OQ-5: adopt the prototype's FORM, never its PROMISES. Both describe capabilities the app lacks (remote sync, a markdown engine), so shipping their strings would state something false.
- OQ-2 and OQ-7 subordinate design fidelity to capability — a faithful value would have deleted a real longest-streak number and a playback envelope the prototype never had to model. The prototype's 130px card height stays rejected; it clips the control bar.
- OQ-4 is the one app-only element deliberately DROPPED, recorded so it is never mistaken for an accidental regression. Reachability verified before accepting: the chooser survives via `app_shell.dart:30-32` -> `bottom_bar_shell.dart:116`, with `test/app/shell/bottom_bar_shell_test.dart:52` as the standing proof. Three other test files go red with the button and change in D3.
- Rejected: adopting prototype copy verbatim (OQ-1c, OQ-5a); dropping the streak number (OQ-2a); demoting rather than removing the Capture button (OQ-4b/c); the 130px card at rest expanding on play (OQ-7b), for the mid-interaction layout jump.
- Still open, touching no MSP: OQ-3 (entry-card Edit/Delete placement) and OQ-6 (photo attachment model, entangled with `PhotoTray` being dead UI).
- Full session detail: sessions/2026-07-27-01-prototype-design-alignment.md
