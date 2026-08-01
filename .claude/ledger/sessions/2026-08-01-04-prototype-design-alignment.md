# Session 2026-08-01-04 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed a NINTH ledger drift, benign: `origin/main` had advanced to `1ceb287` (#97, the session-25 ledger handoff) after wrap-up, so the recorded `9769bba` was stale as a tip. Corrected before presenting. The user then directed a dedicated small dynamic workflow to fully implement and ship Cluster E.

## What shipped

**CLUSTER E IS CLOSED. 24 of the parent spec's 39 MSPs are on main.** `origin/main` is `93de164`. Five PRs merged: #98 slice, #99 E1, #100 E2, #101 E3, #102 E4.

**Cluster E shipped as a NATIVE GITHUB STACK — stack 103**, the first on this project. The user overrode `decisions/2026-08-01-msp-prs-target-main-never-another-msp-branch.md` and then corrected the mechanism to GitHub's native feature, supplying the docs. Recorded at `decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md`; the old record is marked superseded and its PROJECT.md index line replaced.

**The crux, researched before dispatch: base-chaining alone is NOT a stack.** Plain `gh pr create --base <parent>` yields an ordinary chained PR with no cascade — the exact shape that stranded Cluster D. A stack is a first-class server object, created by `POST /repos/<repo>/stacks` with `pull_requests` ordered bottom-to-top. GraphQL is read-only for stacks. `gh stack` is an extension (`github/gh-stack`) and was deliberately NOT installed; REST only.

**The slice, PR #98, 1236 lines** at `docs/specs/2026-08-01-prototype-alignment-cluster-e.md`, carrying **22 PRIMITIVE RESOLUTIONS** settled at slice time rather than left to implementers. The recon that fed it caught the C5/C7 defect class before it reached anyone: **R13 collapsed E4's size ladder from eight rows to two** — six were out of fence, already at target, or both.

**Three spec/ledger errors the recon corrected, all of which had been circulating as fact:**
- **R17: `resolveGardenMotionProfile` DOES NOT EXIST.** The real symbol is `resolveGardenMotion` at `lib/features/garden/garden_motion.dart:5-13`. Preserve item N21 had fused the enum name onto the function name; all four anchors corrected.
- **R20: the N24 untouchable-file paths name two directories that do not exist.** The real paths are under `test/features/entry_cards/`, not `test/cards/`. Cluster E had zero exposure either way.
- **R16: the parent spec's nine garden viewBox heights are only eight reachable**; 206 belongs solely to the out-of-scope `_thistle`.

**The baseline was wrong and is now measured, not inferred: `origin/main` carries 905 tests, not 904.** All three implementers independently flagged it; one proved it by stashing its diff and running the suite on the otherwise-identical tree. The 904 figure predates #95 and #96. Cluster E's branch head is **907** (905 + E1's two new `flower_spec_test.dart` cases).

**Cleanup done, scoped to Cluster E.** Six branches deleted local and remote: `msp-cluster-e/e1-e4`, `docs/cluster-e-slice`, `chore/ledger-handoff-session-25`. Cluster E used NO worktrees by design (a branch chain in a single tree, since all four MSPs rewrite the same two files, so there was no parallelism to isolate). The Cluster A/B/C, poster-first and legacy worktrees plus the four stashes were left untouched per `decisions/2026-07-20-keep-stale-worktrees.md` — same scoping the previous session applied.

## Tried and failed

- **`git switch main` aborted on uncommitted ledger edits, again** — the identical trap as session 03. Same fix: `git switch -c chore/ledger-handoff-session-26 origin/main` carried them cleanly. This is now twice; treat it as the default move, not a fallback.
- **A first branch-cleanup check compared against the LOCAL `main` ref, which was 9 commits behind**, producing misleading "unmerged" counts (e1=5, e4=11). Re-run against `origin/main` it was e1=1, e4=7 — pure squash-merge SHA divergence. Always compare against `origin/main`, never the local ref.
- The workflow's own `msps`/`reviews` fields were nested one level deeper in the task output than assumed; the first extraction returned nulls. The journal and `result` key held the real values.

## Verification

- **The ship agent refused to inherit validation.** It re-ran the project's `fullValidationCmd` itself, in the foreground, on all four branches rather than write a `--verified` line from another agent's report: `flutter analyze` -> "No issues found!" and `flutter test` -> **907 passed on e1, e2, e3 and e4**. Every `--verified` line in every PR is first-hand.
- Test-count prediction matched actual on all four branches (907 predicted, 907 observed), once the 905 baseline replaced the stated 904.
- **THE BRANCH-DELETION RISK IS RESOLVED EMPIRICALLY, AND THE ANSWER IS NO.** `decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md` flagged as unverified whether the stack cascade requires the merged head branch to be deleted; GitHub's docs do not settle it. Observed here: #100/#101/#102 were opened with bases `e1`/`e2`/`e3` and all merged with `base=main`, while `origin/msp-cluster-e/*` still existed at merge time. **The cascade retargeted without any branch deletion.** This holds for clusters F-H.
- Content-on-main proof before any branch deletion: `garden_plant_painter.dart`, `garden_plant_spec.dart`, `garden_plant_geometry.dart`, `bloom_part_painter.dart` and the slice all present on `origin/main`; `_straightStem` confirmed GONE from `flower_painter.dart` (E4's cleanup landed); `git diff origin/main msp-cluster-e/e4 -- lib/ test/` empty.
- Reviews returned 4 (E1), 5 (E2+E3 combined), 3 (E4) findings, fixed where blocking.
- **NOT RUN: the section 5.4 manual macOS visual pass.** No agent can run the app. Every Cluster E PR carries an explicit `--not-verified` line saying so. Cluster E is FLOWER ART — this is the least-confirmed cluster yet shipped.
- NOT RUN: any integration test, any golden test.

## Running state
none. The workflow (`wymyuge6e`, run `wf_eb294751-03c`) completed: 12 agents, 0 errors, ~2.1h, 1.82M subagent tokens. Transcript: `/Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/28b87007-5f73-47af-a06f-cf9208fc4f4c/subagents/workflows/wf_eb294751-03c/journal.jsonl`. Slice copy: `/private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/28b87007-5f73-47af-a06f-cf9208fc4f4c/scratchpad/cluster-e-slice.md` (disposable; the slice is on main).

## Deferred + open

1. **NEXT ACTION: run the macOS visual pass on Cluster E's flower art.** Four MSPs of pure art shipped with zero visual confirmation. Command is `flutter run -d macos`, handed to the user — never detached, never the raw binary.
2. **AN UNRESOLVED DESIGN QUESTION E1 DECLARED RATHER THAN SILENTLY CHOSE.** The meadow's stroke COLOUR and WIDTH changed. There is exactly one shared `_stroke(d)`, and E1's mandate was that it stop hardcoding `Palette.ink`; `meadow_painter.dart` shares that painter, so the change cannot be scoped to the compact path without a second stroke path the slice does not authorise. Composition IS preserved literally: every garden plant kept its stem, leaf, centre at `height*0.42` and byte-identical geometry. Only outline hue and weight moved (at d=44: chrysanthemum 1.5 -> 0.8, spider lily 1.5 -> 1.8). If the user wants the meadow on `Palette.ink`, that is a spec amendment plus a second stroke path.
3. **Then cut the Cluster F slice** (mood picker, F1-F4) using the Cluster E slice as the template — it is the stronger template now, because its PRIMITIVE RESOLUTIONS section is what kept four MSPs from meeting an unreachable anchor. Clusters F, G (G1-G8) and H (H1) all still need slices.
4. **Stacked PRs are now the proven pattern.** F-H ship the same way: open with `--base` the branch below, then link via `POST /repos/SatanshuMishra/field-notes/stacks`. Merge bottom-up; a mid-stack merge takes everything below it in one operation. `gh pr merge` is denied, so every merge stays a human action.
5. E4 declared THREE fence widenings, all inside `lib/design/flowers/` and referenced by nothing outside it: new `bloom_part_painter.dart` (shared render loop, to avoid the garden set importing the compact set's file), new `garden_plant_geometry.dart` (`garden_plant_spec.dart` had reached 1046 lines against the project's 800 ceiling), and one token in `flower_bloom.dart` (deleting the `headless` param necessarily touches its only call site).
6. Standing and unchanged: OQ-3 and OQ-6 open (OQ-6 blocks a C5 target value); C7's badge/chip anchors and the chip's tokenless `#2A241D` still unsettled (never shipped, so no visual pass can rule on them); the `--force-with-lease` rule still absent from every settings file; `receipts.yml` unpinned third-party action; A2/A4 blast radius never walked; five A3 dialogs never opened; the Cluster A/B/C, poster-first and legacy worktrees plus four stashes still owe a confirmed batch removal with an explicit list.

## Pick up here
`origin/main` is `93de164` with all of Cluster E landed and every Cluster E branch removed. Nothing is stranded and nothing is half-shipped. Start with the macOS visual pass on the flower art, and settle the meadow-stroke question in item 2 before cutting Cluster F.

## Demoted from PROJECT.md (cap enforcement)

PROJECT.md hit its 80-line cap when this session's decision index line was added. One SPENT index line was demoted to make room. The file remains on disk, unchanged, and is still valid history — it is simply no longer load-bearing: Cluster D is closed, and the 903/904 baseline it establishes has been SUPERSEDED by this session's direct measurement of 905 on main. The displaced text:

- decisions/2026-08-01-d3-chooser-test-deletion-is-correct.md — D3 finishing at 903 against a 904 baseline is CORRECT, not a coverage regression, and 903 is the new baseline. It deleted a chooser-hop test whose button D3 removes by design; every behaviour that test covered survives (title at today_capture_buttons_test.dart:41, direct route invocation with the date at :47-50 pre-existing, sheet rendering at capture_chooser_test.dart:56, openCapture running the route at capture_chooser_test.dart:143, reachability at app_capture_integration_test.dart:29), the chooser is still wired in production at app_shell.dart:34-35, and the slice pre-declared the change at its own line 147. D4 therefore predicts 904, not 905. Rejected: retargeting the deleted case to tap the direct row, which :47-50 already asserts
