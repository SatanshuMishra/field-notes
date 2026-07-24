# share_plus 13.x is unreachable while file_picker is on stable

Status: accepted
Date: 2026-07-24

`share_plus` cannot go past 12.x. The entire 13.x line needs `win32 ^6`; `file_picker 11.0.2`
(current stable) needs `win32 ^5.9.0`. Disjoint constraints.

The trap: `pub outdated` reports share_plus `Resolvable 13.3.0`, which looks actionable. `--show-all`
reveals that resolution also requires `file_picker 12.0.0-beta.7` — a PRERELEASE — on the export/save
path. Rejected: Quality over currency. Do not retry until file_picker ships stable on win32 ^6.

Corrects an earlier scoping claim that share_plus 13.x was "low risk, only a win32 minimums bump" —
that read the changelog but not the solver. LESSON: for any MAJOR bump trust `pub get` resolution
over changelog reasoning, and check `--show-all` before believing `Resolvable`.

Also hard-blocked, do not retry: `build_runner` 2.15.2 and `drift_dev` 2.34.5. `riverpod_generator`
pins `analyzer: ^12.0.0` and `drift_dev` pins `<13.0.0`; latest analyzer is 14.1.0. Needs an upstream
release. `Resolvable == Current` in `pub outdated` is the authoritative "do not bother" signal.
Landed on chore/package-upgrade: patch sweep (48a4fb8), camera 0.12.0+2 (b4331fa).
