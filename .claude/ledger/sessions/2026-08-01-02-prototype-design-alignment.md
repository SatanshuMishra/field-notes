# Session 2026-08-01-02 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed a SEVENTH ledger drift, in two parts: `origin/main` had advanced to `98ceec1` (#92, the session-23 ledger handoff, merged after the last wrap-up), and PR #91 was MERGED into `msp-cluster-d/d1-rail-container` at `46705d3`, not OPEN as recorded — so D2 was stranded too, making it three stranded MSPs rather than two. Both corrected in the thread file before presenting. The user then approved the recovery plan as briefed.

## What shipped

**D3 is re-landed on main.** PR #93 merged as `cfa04c7`. Branch `msp-cluster-d/d3-capture-rail-relanded` was cut from `98ceec1` and `git cherry-pick 7958366` applied with zero conflicts (6 files, +179/-61). `--base main`, verified after creation.

**The 903 is ruled correct and is the new baseline** — `decisions/2026-08-01-d3-chooser-test-deletion-is-correct.md`. D3 deleted `testWidgets('the primary button opens the chooser and runs the chosen route')` from `today_capture_buttons_test.dart`, which the thread had flagged as an unreconciled coverage loss blocking the re-land. It is not a regression: every behaviour that test covered survives elsewhere (title at `today_capture_buttons_test.dart:41`; direct route invocation with the date at `:47-50`, pre-existing and NOT added by D3; sheet rendering at `capture_chooser_test.dart:56`; `openCapture` running the route with the date at `capture_chooser_test.dart:143`; reachability at `app_capture_integration_test.dart:29`). The chooser is not orphaned in production — `lib/app/shell/app_shell.dart:34-35` still wires it as the shell's capture affordance. The slice's own §0 line 147 had ALREADY pre-declared that `today_screen_test.dart:89`'s `find.text('Capture'), findsOneWidget` must change because D3 removes that button; D3's retarget strengthens it to `findsNothing` plus three positive row assertions.

**The four §5.3 gate-3 integration flows ran for the first time ever, and passed.** Only `integration_test/capture_ui_flow_test.dart` was run, deliberately never the directory, because `integration_test/capture_save_persist_test.dart` is the known writer into the real journal container (the `post-ship-hardening` thread's open bug).

**The §5.4 macOS visual pass PASSED** — recorded at `decisions/2026-08-01-macos-visual-pass-confirmed.md`. The user ran main at `cfa04c7` and confirmed everything renders as expected. This closes thread completion criterion 4.

**Worktree cleanup.** `.fireplace-worktrees-cluster-d/d1-rail-container` and `/d3-capture-rail-buttons` removed (both MSPs fully on main). `d2-week-garden-grid` and `d4-on-this-day-card` KEPT — that work is unfinished. No branch was deleted; `msp-cluster-d/d1-rail-container` still holds the only copies of D4's `e29362d` and D2's `46705d3`, both re-verified reachable after the removal.

## Tried and failed

- **A dispatched validation subagent returned twice without results.** It backgrounded the gate and returned narrating that it was waiting; resumed via SendMessage with an explicit "do not return until you have real numbers" instruction, and it returned a second time still empty. Its detached shell was then swept with the task teardown, leaving no log. The gate was re-run directly from the main thread instead. Lesson: for a single long command whose only useful output is the final state, run it backgrounded from the main thread rather than wrapping it in an agent.
- **`flutter run -d macos` launched detached via `nohup` does not stay up.** It built and synced (`Syncing files to device macOS`, VM service came up) then logged `Failed to foreground app; open returned 1` and `Lost connection to device.` `flutter run` is interactive and needs a TTY it can foreground into. The user ran it themselves in a terminal. Do not try to launch the app detached again; hand the user the command.
- Deliberately NOT attempted: opening the built `.app` bundle as a fallback, per `decisions/2026-07-22-black-window-standalone-binary.md`.

## Verification

- `flutter analyze` — `No issues found! (ran in 2.7s)`, exit 0.
- `flutter test` — `00:25 +903: All tests passed!`, exit 0. Predicted 903 from the diff BEFORE running; matched exactly.
- `flutter test integration_test/capture_ui_flow_test.dart -d macos` — `+4: All tests passed!`, exit 0. All four flows (note, voice, video, camera-switch) green on first-ever execution.
- Fence audit: D3's 6 files map exactly onto its declared rows in the slice (`:82`, `:85`, `:86`, `:90`, `:91`, `:94`). No out-of-fence edit. `lib/features/capture/**` untouched, as §271 requires. `bottom_bar_shell_test.dart:52` absent from the diff.
- `sticker_button.dart` diff is exactly §0 resolution 5: additive `this.labelStyle`, defaults `null`, `(labelStyle ?? TypographyTokens.buttonSans)`. Other 24 call sites unchanged.
- `gh pr view 93` — MERGED, base=main, mergeCommit `cfa04c7d3bc`. `git cat-file -e HEAD:lib/design/icons/capture_icons.dart` present on main; the slice still present at 617 lines (the deletion trap avoided).
- `git cat-file -e e29362d` and `46705d3` — both still reachable after worktree removal.
- NOT run: `flutter test integration_test/` as a directory (deliberate), any golden test, any re-review of D3's code (it carried last session's ACCEPT; this session audited fence, coverage and execution instead — which is where that review actually failed).

## Running state
none. Validation, integration and the app launch all completed or died; no background shells, no worktree locks. Scratchpad used this session: `/private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/21edfb0e-a595-40df-adf4-69509c1968f6/scratchpad/` (validate.sh, integ.sh, runapp.sh and their logs) — disposable.

## Deferred + open

1. **D4 is now UNBLOCKED and is the next action.** Cut a branch from `cfa04c7`, `git cherry-pick e29362d`, run `fullValidationCmd`, open with `--base main`. **Predict 904** (903 baseline + D4's one admitted short-date case) — NOT 905, which assumed the old 904 baseline. The rebase must preserve the `_allCaptureRoutes()` helper D3 added to the shared `today_screen_test.dart`, and D3 also switched that file's registry override off `CaptureRouteRegistry.empty` because rows only render for registered types.
2. **D2 still owes the user's ruling** — widen the fence into `lib/app/shell/**`, promote the shell destination through Riverpod, or drop the tap-to-Calendar criterion. Never an implementer's call. D2's worktree head is `1aa0f15 fix(week-garden): drop the unreachable cal...`, which differs from the `46705d3` that merged; reconcile which is authoritative before re-landing.
3. **D2's re-land needs a fresh PR anyway**, which incidentally fixes #91's mis-titled subject — it never reached main, so no close-and-supersede is needed.
4. Standing and unchanged: OQ-3 and OQ-6 open (OQ-6 blocks a C5 target value); `--force-with-lease` rule still unwritten; `receipts.yml` unpinned third-party action (chip `task_e10f4f7e`); A2/A4 blast radius never walked; five A3 dialogs never opened; orphan branches and three stale stashes still owed a confirmed batch removal (this session's cleanup covered worktrees only, not branches or stashes).

## Pick up here
`origin/main` is `cfa04c7` with the slice, D1 and D3 landed; 18 of 39 MSPs are on main. Start with item 1, D4 — it is unblocked, fully specified, and predicts 904. Item 2, the D2 fence ruling, is the one that needs the user rather than an agent.

## Demoted from PROJECT.md (cap enforcement)

PROJECT.md was at its 80-line cap. Two spent mitosis-era decision index lines were demoted to make room for this session's two records. Both files remain on disk, unchanged, and are still valid history — they are simply no longer load-bearing, because mitosis is excluded for the whole remaining spec (decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md) and Cluster C is closed. The displaced text:

- decisions/2026-07-28-cluster-c-skips-mitosis.md — Cluster C is executed by direct `implementer` dispatches in the slice's three waves, NOT by mitosis. Root cause is unfixed: `mitosis.js:4586` authorizes an unconfirmed `--force-with-lease`, the harness classifier blocks that agent family, `builtSha` is null run-wide (`:4598`), and every unit reaching the `requireSha: true` frontier (`:4306`) parks. Cluster B cost ~8.1M subagent tokens across three dispatches to ship one MSP; B1 shipped only by having no unmerged parent. C3, C5 and C7 all have unmerged in-cluster parents — the same shape. Verification is unchanged (local `fullValidationCmd` per head, 106 playback tests green around C7); parallel-safety moves from the engine's graph to the slice's declared file-overlap matrix. The slice was still landed on main first, so a later mitosis run needs no re-cut. Scoped to this cluster, not a retirement of mitosis
- decisions/2026-07-28-recover-stranded-checkpoints-over-redispatch.md — when a mitosis run strands finished work on a durable checkpoint ref, RECOVER the artifact, validate it locally with `fullValidationCmd`, and ship it as an ordinary PR; never re-dispatch mitosis to re-implement work that already exists. Three Cluster B runs cost ~8.1M tokens and shipped one MSP, all three failing on infrastructure, never work quality — while `refs/mitosis/55d6da7a/b3-nav-states-icons` at `54fd9ef` held B2 AND B3 complete and rebased onto post-B1 `main`. Check two things first: a later MSP's checkpoint may be a SUPERSET of an earlier one, and the newest checkpoint in the chain is the mergeable tip (`9a53222` is an ancestor of `54fd9ef`; the older `97d91a8` predates the B1 squash-merge and is not). Read individual commits out of the chain for per-MSP PRs. Corollary: a single remaining MSP is not mitosis-shaped — it goes to one `implementer` dispatch
