---
thread: prototype-design-alignment
status: paused
updated: 2026-08-01
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Cut a branch from `origin/main` (`dbbc7a4`) and re-land D3 and D4 on main — cherry-pick `7958366` and `e29362d` from `msp-cluster-d/d1-rail-container`, run fullValidationCmd, open two PRs with `--base main`. NEVER PR that branch into main; it would delete the slice (-617 lines).
branch: `origin/main` `dbbc7a4` (slice #87 + D1 #88 landed). Stranded work lives on `msp-cluster-d/d1-rail-container`.
---

## Status
**Cluster D is HALF-LANDED — 17 of the parent spec's 39 MSPs are on main** (A1-A5, B1-B4, C1-C7, D1). The Cluster D slice is written and landed (`docs/specs/2026-07-29-prototype-alignment-cluster-d.md`, 617 lines). D3 (#89) and D4 (#90) are complete and reviewed-ACCEPT but were merged into D1's BRANCH instead of main, so they are stranded. D2 (#91) is open, shipped chrome only, and is mis-titled. Mitosis stays excluded for the whole remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Re-land D3 and D4 on main from a branch cut off `dbbc7a4`, then resolve D2. Full ordered recovery list is in sessions/2026-08-01-01-prototype-design-alignment.md's "Deferred + open".

## Open Risks
- **Never PR `msp-cluster-d/d1-rail-container` into main.** It was cut before the slice merged, so the diff deletes `docs/specs/2026-07-29-prototype-alignment-cluster-d.md` at -617 lines. Re-land D3/D4 by cherry-pick onto a branch from `dbbc7a4` instead.
- **D2 owes a ruling that only the user can give.** Its tap-to-Calendar — the ONE genuinely new behaviour in Cluster D and its stated acceptance criterion — is unimplemented because every route needs `lib/app/shell/**`, which the slice's own §0 and §6.2 close. The implementer refused to widen the fence unilaterally and flagged the deferral UNRATIFIED. Options: declare the widening, promote the shell destination through Riverpod, or drop the criterion.
- **PR #91's title claims a tap target the branch does not ship.** The title seeds the squash subject and post-creation edits are hook-denied, so #91 must be closed and reopened via `pr-create --supersedes`.
- **D3 finished at 903 against a 904 baseline and its reviewer still returned ACCEPT.** It deleted `testWidgets('the primary button opens the chooser and runs the chosen route')` from `today_capture_buttons_test.dart`. Reconcile before merging. `bottom_bar_shell_test.dart:52` was confirmed unmodified, so phone reachability keeps its proof.
- **D3 rewrote `integration_test/capture_ui_flow_test.dart` and never ran it** — `flutter test` covers only `test/`. Running it is also the first-ever execution of the four §5.3 gate-3 flows; triage there before blaming D3.
- **`today_screen_test.dart` is shared by D3 and D4.** Whichever merges second rebases onto the first and revalidates.
- **The ledger's branch/merge state has now been wrong SIX times.** On resume, always re-check `gh pr view` and `git log origin/main` before acting.
- **Predict the expected test count from the diff BEFORE running `fullValidationCmd`.** Baseline is **904**. Reported: D1 904, D2 904, D3 903, D4 905 (only D4's +1 is admitted by the slice).
- **N24's eight untouchable files**: `playback/video_slots_test.dart` (29), and under `cards/`: `video_body_lifecycle_test.dart` (20), `video_controls_overlay_test.dart` (18), `video_body_test.dart` (16), `video_body_slots_test.dart` (11), `video_body_poster_gate_test.dart` (7), `video_body_attempt_identity_test.dart` (4), `video_scrubber_test.dart` (1). Cluster D touched none.
- **§5.4's macOS visual pass owes FOUR rulings**: C1's flame cusp at (9,8), C5's tilt scatter, C7's badge/chip anchors, and the chip's tokenless ground `#2A241D`. It is the only check that can confirm Clusters C and D.
- **`git push --force-with-lease` is classifier-blocked for the MAIN THREAD** and the granted rule is still absent from every settings file. Workaround remains a new `-rebased` ref.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Describe copy in prose in PR fields, never quote it.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- **Orphan branches now number eleven**, plus three stale stashes; the four `.fireplace-worktrees-cluster-d/` worktrees are also left in place. One explicitly confirmed batch removal still owed.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b/c` checkouts and their `msp-cluster-*` branches are KEPT by standing directive. Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- C4's restyled Edit/Delete are only observable in Day Detail (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- OQ-3 and OQ-6 unanswered. **OQ-6 blocks a C5 target value**; D4's title was deliberately resolved WITHOUT answering it.

## Key Decisions
- decisions/2026-08-01-msp-prs-target-main-never-another-msp-branch.md — an MSP PR's base is ALWAYS main; downstream MSPs wait, rebase `--onto main`, revalidate, then open
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — D4 repurposes the preview as its serif title; D3 gets an optional `labelStyle` param on `StickerButton` as a declared one-file fence widening
- decisions/2026-07-29-c7-rows-wait-on-the-visual-pass.md — C7's three blocked rows deferred to §5.4, Cluster D cut first; see also -c7-poster-chrome-blocked-by-protected-anchors.md for why they are blocked
- decisions/2026-07-28-c5-ships-as-is.md — C5 shipped knowingly incomplete on its 6px caption
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — every remaining cluster has an in-cluster chain, so mitosis is excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it must change; N24 stays carved out
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — rebase `--onto main` after each merge, revalidate on the new base
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height, its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.

## Pointers
- docs/specs/2026-07-29-prototype-alignment-cluster-d.md — **the Cluster D slice, landed on main.** The binding contract for D1-D4
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. Clusters E-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source. D1-D4's citations verified clean, zero errors
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is 904 passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-01-01-prototype-design-alignment.md — **Cluster D slice + D1 landed; D3/D4 stranded on D1's branch; D2 incomplete. Full recovery list lives here**
- sessions/2026-07-29-02-prototype-design-alignment.md — Cluster C closed; C7 rows deferred; Cluster D recon (do not re-run)
- sessions/2026-07-29-01- / 2026-07-28-07- through -01-prototype-design-alignment.md
