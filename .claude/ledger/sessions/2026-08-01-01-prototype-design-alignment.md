# Session 2026-08-01-01 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed a SIXTH ledger drift: PR #86 had merged `e70bf25`+`41e0da8` as one squash (`5866470`) while the thread still recorded `docs/cluster-d-slice` as unmerged. Corrected in the thread file before presenting. The user then approved a single directive: dispatch a dedicated small dynamic workflow to fully implement and ship Cluster D.

## What shipped

Workflow `wf_3612bd05-fb8` (12 agents, 1,695,987 subagent tokens, 525 tool uses, 91 min, 0 agent errors). Script persisted at `/Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/c536666b-d3db-483a-8168-a3bd62c820e6/workflows/scripts/cluster-d-ship-wf_3612bd05-fb8.js`; per-agent returns in the sibling `subagents/workflows/wf_3612bd05-fb8/journal.jsonl`.

| MSP | PR | Merged into | State |
|---|---|---|---|
| Cluster D slice (617 lines) | #87 | **main** | landed |
| D1 rail container | #88 | **main** (`dbbc7a4`) | landed |
| D3 capture rail | #89 | `msp-cluster-d/d1-rail-container` | STRANDED, not on main |
| D4 on this day card | #90 | `msp-cluster-d/d1-rail-container` | STRANDED, not on main |
| D2 week garden | #91 | — | OPEN, incomplete, mis-titled |

`origin/main` is `dbbc7a4`. The Cluster D slice is written and landed: `docs/specs/2026-07-29-prototype-alignment-cluster-d.md`.

Workflow shape, for reuse: phase 1 `technical-writer` composes the slice -> `solution-architect` adversarially critiques it against a 7-boolean checklist -> `implementer` applies corrections and opens the PR. Phase 2 D1 alone (implement -> review -> conditional fix), hard-gated so a red D1 aborts the run. Phase 3 `pipeline` over D2/D3/D4, each in its own worktree stacked on D1's tip, implement -> review -> conditional fix with no barrier between stages. The whole verified recon was embedded verbatim in every prompt so no agent re-ran it.

The slice critic returned REVISE with 4 blocking defects, all fixed before landing; all 7 checklist booleans ended true (receipted resolutions, N24 enumerated inline, retargeting rule carried, baseline 904, wave graph D1 -> rest, test collisions fixed, stale claims corrected).

## Tried and failed

- **D2's tap-to-Calendar could not be implemented inside the fence.** It is the one genuinely new behaviour in all of Cluster D and D2's stated acceptance criterion. Every route to it requires editing `lib/app/shell/**` (`app_shell.dart` + `shell_content.dart`), which the slice's own §0 named traps and §6.2 explicitly close ("No change to `lib/app/shell/**`"). The implementer refused to widen the fence unilaterally and shipped chrome only, flagging the choice as UNRATIFIED and owing a decisions record. That refusal was correct discipline; the criterion is simply unmet.
- **The stacked-PR topology backfired.** D2/D3/D4 were opened with `--base msp-cluster-d/d1-rail-container` so each diff would show only its own change. Merging #89 and #90 merged them into that branch, not main — after D1 had already squash-merged to main under a different SHA (`dbbc7a4` vs the branch's `932b10e`). Their code is live only on `msp-cluster-d/d1-rail-container`.
- **A naive PR from that branch to main would DELETE the slice.** The branch was cut from `origin/main` at `5866470`, before #87 landed, so `git diff origin/main origin/msp-cluster-d/d1-rail-container` shows `docs/specs/2026-07-29-prototype-alignment-cluster-d.md` at -617 lines. Do not open that PR.
- **D3's reviewer returned ACCEPT on a suite that had dropped below baseline.** D3 finished at 903 against a baseline of 904 and a predicted 904. The review prompt explicitly called an unexplained count delta HIGH; it was not caught. Cause found this session: D3 deleted `testWidgets('the primary button opens the chooser and runs the chosen route', ...)` from `test/features/today/today_capture_buttons_test.dart`. Plausibly legitimate — D3 removes the desktop capture button — but it touches the chooser preserve item and was never reconciled.
- **D3 rewrote an integration test it never ran.** `integration_test/capture_ui_flow_test.dart`: helper `_openChooserAndPick` became `_pickCaptureRow`, the chooser-sheet assertion and `find.descendant` scoping were deleted, four call sites renamed. `flutter test` only covers `test/`, so none of it executed.

## Verification

All merge-state claims were verified against git and `gh` in the main thread, not taken from agent reports.

- `gh pr view 87..91 --json state,baseRefName` — #87 MERGED base=main; #88 MERGED base=main; #89 MERGED base=`msp-cluster-d/d1-rail-container`; #90 MERGED base=`msp-cluster-d/d1-rail-container`; #91 OPEN base=`msp-cluster-d/d1-rail-container`.
- `git log --oneline -6 origin/main` — `dbbc7a4` (#88) on top of `d7604aa` (#87) on `5866470`. Expected D3/D4 present; observed absent.
- `git cat-file -e origin/main:lib/design/icons/capture_icons.dart` — NOT on main. Same path on `origin/msp-cluster-d/d1-rail-container` — present. D3 confirmed stranded.
- `git diff --stat origin/main origin/msp-cluster-d/d1-rail-container` — 12 files; includes the slice at -617 (the deletion trap above), `capture_icons.dart` +104, `today_date.dart` +9 and `today_date_test.dart` +9 (D4's short-date formatter).
- `git diff --stat msp-cluster-d/d1-rail-container...msp-cluster-d/d2-week-garden-grid` — ONE file, `this_week_garden.dart`, +168/-34. Grep of that diff for `onTap|GestureDetector|InkWell|Navigator|calendar|Calendar` returned ZERO hits. D2's missing tap target confirmed independently of the agent's report.
- `git diff msp-cluster-d/d1-rail-container...msp-cluster-d/d3-capture-rail-buttons -- test/` grepped for removed test blocks — one deletion, named above.
- Reported final counts: D1 904, D2 904, D3 903, D4 905. Baseline 904. Only D4's delta (+1, its additive short-date case) matches the slice's test admission.
- NOT run this session: `fullValidationCmd` in the main thread, any `flutter` invocation, the four `integration_test/` flows, any macOS render pass.

## Running state
none. The workflow completed; all 12 agents returned. No background shells, no open worktree locks. Worktrees created and left in place under `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-d/`: `d1-rail-container`, `d2-week-garden-grid`, `d3-capture-rail-buttons`, `d4-on-this-day-card`.

## Deferred + open

Recovery work, in dependency order:

1. **Re-land D3 and D4 on main.** Cut a fresh branch from `origin/main` (`dbbc7a4`, which already has the slice and D1), bring D3's and D4's changes across — cherry-pick `7958366` and `e29362d`, or rebuild from the file list in the diff above — run `fullValidationCmd` on the new base, and open fresh PRs with `--base main`. Never PR `msp-cluster-d/d1-rail-container` into main.
2. **Reconcile D3's 903.** Decide whether deleting the chooser test is correct now that the desktop capture button is gone, or whether the chooser preserve item needs it retargeted rather than removed. `bottom_bar_shell_test.dart:52` was confirmed unmodified, so phone reachability still has its standing proof.
3. **Run the rewritten `integration_test/capture_ui_flow_test.dart`** before D3 merges — `flutter test integration_test/` or a device run. This is also the first execution of any of the four `integration_test/` flows (§5.3 gate 3), which have never been run; triage failures there before blaming D3.
4. **Rule on D2.** Either declare a fence widening into `lib/app/shell/**` with a decisions record, promote the shell destination through Riverpod so the rail can navigate without touching the shell, or drop the acceptance criterion. Until then D2 ships chrome only and Cluster D's single new test stays unwritten. This is a product/architecture ruling, not an implementer's call.
5. **Replace PR #91.** Its title claims "and a tap target" which the branch does not ship, and the title seeds the squash commit subject. Post-creation title edits are hook-denied, so close #91 and reopen via `pr-create --supersedes https://github.com/SatanshuMishra/field-notes/pull/91`. Then rebase it onto main like D3/D4.
6. **`today_screen_test.dart` is shared by D3 and D4** (D3 at the `:89` region, D4 at `:91`). Whichever merges second rebases onto the first and re-validates.

Standing, unchanged: §5.4's macOS visual pass owes FOUR rulings (C1's flame cusp at (9,8), C5's tilt scatter, C7's badge/chip anchors, the chip's tokenless ground `#2A241D`) and is now the only check that can confirm Clusters C and D; `--force-with-lease` rule still unwritten and unproven; OQ-3 and OQ-6 open; `receipts.yml` unpinned third-party action (chip `task_e10f4f7e`); A2/A4 blast radius never walked; five A3 dialogs never opened; orphan branches now eleven plus three stale stashes, one confirmed batch removal owed.

## Demoted from PROJECT.md (cap enforcement)

The two C7 index lines were merged into one to free a line for this session's decision record. Both files remain on disk and both are still pointed at. The displaced text:

- decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md — C7 ships ONLY its container-radius row (PR #84); its hatch, play badge and duration chip are structurally blocked and re-scoped out, each proven rather than argued. The hatch swap the slice's §0 resolution 6 mandates was actually made and reds `video_body_test.dart:400` (an N24 file asserting `find.byType(NeutralMediaPlaceholder)`); closing it needs `media_placeholders.dart`, outside C7's fence. The badge and chip anchors are physically occupied — `canAutoHideVideoControls` requires `isPlaying`, so at rest the 56px `VideoTransport` sits dead centre where the 44px badge goes and the full-width opaque `VideoControlBar` covers the bottom strip where the chip goes. Root cause: OQ-7 resolution (a) is internally contradictory — the prototype tile is a POSTER with no controls, the app tile is a PLAYER already owning both anchors. Re-scope the badge as an N3 MSP on `video_transport.dart` (N3 already licenses its size/fill/border), the hatch as a small `media_placeholders.dart` MSP (pass NO colour overrides — `CrossHatchVariant.video` is already byte-exact and `hatchColor` alpha-blends at 0.5), and take a product ruling on the chip's anchor. Rejected: stacking a second hatch or parking a 0x0 instance to satisfy the finder, and forking `VideoTransport`'s contract into `video_body.dart`

## Pick up here
`origin/main` is `dbbc7a4` with the slice and D1 landed. Start at item 1: re-land D3 and D4 on main from a branch cut off `dbbc7a4`, never by PRing `msp-cluster-d/d1-rail-container` into main (it would delete the slice). Item 4, the D2 fence ruling, is the one that needs the user rather than an agent.
