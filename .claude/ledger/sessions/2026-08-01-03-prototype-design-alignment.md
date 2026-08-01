# Session 2026-08-01-03 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed an EIGHTH ledger drift: `origin/main` had advanced to `0dcad5d` (#94, the session-24 ledger handoff) after the last wrap-up, so the recorded `cfa04c7` was stale as a cut point. Corrected in the thread file and PROJECT.md before presenting. The user then directed: complete Cluster D, fix all issues, ship to completion.

## What shipped

**Cluster D is CLOSED. 20 of the parent spec's 39 MSPs are on main.** `origin/main` is `9769bba`.

**D4 re-landed — PR #95, merged as `9769bba`.** Branch cut from `0dcad5d`, `git cherry-pick e29362d` applied with zero conflicts (5 files, +91/-50). The shared-file risk was checked, not assumed: D3's `_allCaptureRoutes()` helper survives at `today_screen_test.dart:17` and `:63`, and D4's only edit to that file is the single retarget at `:107`.

**D2 re-landed WITH its tap-to-Calendar — PR #96, merged as `7aabf4b`.** `46705d3` (chrome only) cherry-picked, then the acceptance criterion the prior session had left unimplemented was built. Recorded at `decisions/2026-08-01-d2-shell-destination-promoted-to-riverpod.md`. `_AppShellState._selected` was a private `setState` field no descendant could reach; it is promoted to `@Riverpod(keepAlive: true) class ShellNavigation` in **`lib/state/shell_navigation.dart`**, NOT in `lib/app/shell/`. That placement shrinks the widening of the slice's closed `lib/app/shell/**` fence to **exactly one file, `app_shell.dart`**, and avoids a features-to-app import cycle. N25 honoured: `button: true` and `onTap` sit on the OUTER `Semantics`, outside `ExcludeSemantics`.

**The macOS visual pass PASSED again on merged main**, user-confirmed, now covering D2's week grid and D4's memory card. Thread completion criterion 4 stays MET and extends to everything Cluster D shipped.

**Cluster D cleanup completed** (see "Tried and failed" for what was deliberately NOT touched).

## Tried and failed

- **The first D2 provider was written as plain `@riverpod`, which is autoDispose BY DEFAULT in Riverpod 3.** The new tap test went red: the tap fired, the notifier set `calendar`, then the instance was discarded because nothing watched it, so the next read returned a fresh `today`. Diagnosed from the log (no hit-test warning, no exception — the state simply did not survive), fixed with `keepAlive: true`, green on re-run. This was a REAL defect, not a test artefact: in the app any moment with no watcher would have reset the destination. The test is therefore a genuine receipt — red before the fix, green after.
- **`pr-create` rejected the D2 `--why` value** for exceeding the 200-character cap. The tool names the constraint but not which value; shortening the one long field cleared it. Every free-text field is capped at 200, the title at 72.
- A first `git switch main` was refused because uncommitted ledger edits would be overwritten; `git switch -c <handoff-branch> origin/main` carried them cleanly instead.

## Verification

- D4 `fullValidationCmd`: `flutter analyze` -> `No issues found!`, exit 0; `flutter test` -> `00:24 +904: All tests passed!`, exit 0. **904 predicted from the diff BEFORE running** (903 baseline + one new `shortDateLabel` case; every other change a retarget); matched exactly.
- D2 `fullValidationCmd`: analyze clean; `00:25 +904: All tests passed!`, exit 0. Predicted 904 before running (903 baseline + one new tap case; the chrome commit adds no cases); matched exactly.
- D2 first run: `00:25 +903 -1: Some tests failed.` — the single failure was the new tap test, every other test green, proving the shell promotion broke nothing on its own.
- All pre-existing shell tests pass UNMODIFIED, and they transitively prove `AppShell` reads the new provider (each nav test now routes through it), so the new receipt asserts only the cell-to-provider link. No behaviour is double-asserted.
- `gh pr view 95 / 96` — both MERGED, both `base=main`, verified after creation and again after merge.
- Content-on-main proof before any branch deletion: `lib/state/shell_navigation.dart` present, `shortDateLabel` present in `today_date.dart`, `shellNavigationProvider` present in `this_week_garden.dart`, all read from `origin/main`.
- NOT run: `flutter test integration_test/` in any form this session; no golden test; no re-review of D4's code (it carried its original review; this session verified fence, shared-file survival and count instead).

## Running state
none. All background validation shells completed with exit 0 and were read. Scratchpad used: `/private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/92feeb27-3559-4ea4-9ad9-e361d8eb6ee4/scratchpad/` (validate-d4.sh, d4-validate.log, d2-validate.log) — disposable.

## Deferred + open

1. **NEXT ACTION: cut the Cluster E slice** (flower art, E1-E4) from the parent spec, following the Cluster D slice as the template. Clusters E-H all still need slices. E has an in-cluster chain (E2/E3 depend on E1; E4 on E1+E2+E3), so it executes as direct `implementer` waves, one PR per MSP, never mitosis.
2. **Every MSP PR targets `--base main`.** Cluster D's stranding cost two recovery sessions; the rule is now recorded and binding for E-H.
3. **Cleanup deliberately NOT done:** the Cluster A/B/C, poster-first and legacy `.fireplace-worktrees` checkouts and their branches, plus the four stashes, were left untouched. `decisions/2026-07-20-keep-stale-worktrees.md` says keep them and never propose removal, and the user's "clean up any completed worktree branches" was read as scoped to the work just finished, not as revoking their own standing directive. If they want the wider batch, it needs an explicit list and confirmation.
4. Standing and unchanged: OQ-3 and OQ-6 open (OQ-6 blocks a C5 target value); C7's badge/chip anchors and the chip's tokenless `#2A241D` still unsettled (never shipped, so no visual pass can rule on them); the `--force-with-lease` rule still absent from every settings file; `receipts.yml` unpinned third-party action (chip `task_e10f4f7e`); A2/A4 blast radius never walked; five A3 dialogs never opened.

## Pick up here
`origin/main` is `9769bba` with all of Cluster D landed and its worktrees and branches removed. Nothing is stranded and nothing is half-shipped for the first time since Cluster C. Start by cutting the Cluster E slice.

## Demoted from PROJECT.md (cap enforcement)

PROJECT.md was at its 80-line cap. One spent index line was demoted to make room for this session's decision record. The file remains on disk, unchanged, and is still valid history — it is simply no longer load-bearing, because Cluster D is closed and both of its pre-dispatch fence resolutions shipped and merged (D3's `labelStyle` in #93, D4's repurposed title in #95). The displaced text:

- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — pre-dispatch recon caught TWO Cluster D MSPs carrying the exact defect that cost C5 its caption and C7 three rows: a target value whose anchor is unreachable inside the MSP's fence. Both resolved in the slice instead of discovered by an implementer. D4's serif title has no data field (`OnThisDayMemory` carries only `day`/`yearsAgo`; the prototype's "The garden last summer" is hardcoded filler at `Field Notes.dc.html:176`), so D4 REPURPOSES the existing preview snippet as the title — same data, prototype form, no domain change, and OQ-6 is not answered as a side effect. D3's 12px label is unreachable because `StickerButton` hardcodes `buttonSans` 15px at `sticker_button.dart:62-66`, so D3 adds an OPTIONAL `labelStyle` param, default unchanged, as a declared one-file fence widening — mirroring C6's optional `headline` slot, with every other consumer's tests required to pass unmodified. Rejected: editing the hardcoded style (silently restyles four unscoped consumers) and duplicating the geometry into a rail-only widget (the primitive-forking move already rejected for C7). Both resolutions are RECEIPTED — the rule C's §0 resolution 6 broke. **This record is the direct precedent D2's one-file shell widening follows.**
