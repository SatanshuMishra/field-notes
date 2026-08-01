Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment

## Context
D3 finished at 903 against a 904 baseline by deleting `testWidgets('the primary button opens the chooser and runs the chosen route')` from `test/features/today/today_capture_buttons_test.dart`. The thread flagged it as an unreconciled coverage loss touching the chooser preserve item, blocking the re-land. D3 removes the rail's generic Capture button so every row opens its route directly, which makes the deleted test's chooser hop unreachable from this surface.

## Decision
The deletion is CORRECT and 903 is the new baseline. Every behaviour the deleted test covered is still asserted: the title at `today_capture_buttons_test.dart:41`, direct route invocation with the date at `:47-50` (pre-existing, not added by D3), the sheet rendering at `test/features/capture/core/capture_chooser_test.dart:56`, `openCapture` running the registered route with the given date at `capture_chooser_test.dart:143`, and reachability at `test/app/app_capture_integration_test.dart:29`. The chooser is not orphaned in production — `lib/app/shell/app_shell.dart:34-35` still wires it as the shell's capture affordance. D3 additionally pins the removal positively via `find.text('Capture'), findsNothing` at `today_capture_buttons_test.dart:42`.

## Consequences
- This is testing.md's placement rule, not a weakening: the deleted case was a higher-layer duplicate of `capture_chooser_test.dart:143` reached through a button D3 deletes by design. The retargeting decision's bar on deleting sibling assertions governs assertions pinning SURVIVING behaviour; this one pinned a removed affordance.
- Baseline for every subsequent MSP is 903, not 904. D4's admitted +1 short-date case therefore predicts 904, not 905.
- D3's rewrite of `integration_test/capture_ui_flow_test.dart` follows from the same removal and is mechanical (`_openChooserAndPick` -> `_pickCaptureRow`); it is verified by execution, separately.
- Rejected: retargeting the deleted case to tap the direct row. `:47-50` already asserts exactly that, so the retarget would have been a duplicate.
