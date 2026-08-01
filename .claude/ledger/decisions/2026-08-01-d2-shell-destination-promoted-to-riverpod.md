# D2 ships its tap-to-Calendar by promoting the shell destination to Riverpod

Date: 2026-08-01
Status: accepted

D2's stated acceptance criterion — "Tapping any day opens the Calendar" (slice `:1607`) — is IMPLEMENTED, not dropped. The user directed "complete the D Cluster, fix all issues and ship to completion"; dropping an acceptance criterion is a scope reduction only the user may authorize, and they authorized the opposite.

Mechanism: `_AppShellState._selected` was a private `setState` field with no provider, so no descendant could reach it. It is promoted to `@riverpod class ShellNavigation` in **`lib/state/shell_navigation.dart`** — the shared provider layer every feature already imports — NOT into `lib/app/shell/`. That placement is the whole point: it shrinks the widening of the slice's closed `lib/app/shell/**` fence to **exactly one file, `app_shell.dart`**, and avoids a features-to-app import cycle (`this_week_garden.dart` depends on `lib/state`, as features already do; only the narrow `ShellDestination` type import points at `lib/app/shell/`).

This is the same declared-one-file-widening shape as D3's optional `labelStyle` and C6's optional `headline` slot (decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md): additive, behaviour-preserving for every existing consumer, with all pre-existing shell tests required to pass UNMODIFIED. They do — and they now transitively prove `AppShell` reads the provider, so the new tap receipt asserts only the cell-to-provider link and no behaviour is double-asserted.

N25 honoured: `button: true` and `onTap` sit on the OUTER `Semantics`, never inside `ExcludeSemantics`.

Rejected: prop-drilling a callback from `AppShell` through `today_screen.dart` / `today_layout.dart` / `today_right_rail.dart` (touches MORE files, three of them D1-owned, to avoid touching one); `Navigator.push` of `CalendarScreen` (a pushed route is not the shell destination the criterion names, and it strands the nav rail's selected state); and dropping the criterion, which would have shipped Cluster D knowingly incomplete for the second time.
