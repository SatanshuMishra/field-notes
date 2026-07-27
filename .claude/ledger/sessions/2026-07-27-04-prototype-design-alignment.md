# Session 2026-07-27-04 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed drift: the thread's blocking next step ("merge PR #50") was already done — PR #50 had squash-merged as `74d7706` after the last wrap-up. The user directed "Go. Think hard." The task was the Cluster A mitosis dispatch.

## What shipped
- **A3 SHIPPED AND MERGED.** PR #51, merge commit `55d8ffc` on main. `lib/design/feedback/dialog_host.dart` and `test/design/feedback/dialog_host_test.dart` are on main. First MSP of the prototype-alignment spec to land; nothing in `lib/` had moved before this session.
- `.claude/ledger/decisions/2026-07-27-source-prefix-is-run-distinct.md` — the prefix is bare AND run-distinct. Supersedes `2026-07-25-source-prefix-is-a-bare-token.md` (Status line changed there; content untouched).
- `.claude/ledger/decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md` — observed, not assumed: #51 merged RED.
- `.claude/ledger/decisions/2026-07-27-scope-guard-authorship-oracle.md` — ratifies the A1 reviewer's prescribed fix.
- Ledger reconciliation commit `ddf351e` on `chore/ledger-handoff-session-09`.

## The dispatch
Run `wf_e96d3f94-e03` (task `wts7rugua`): 31 agents, 2,516,630 subagent tokens, 658 tool uses, 42,056s (~11.7h). `overallStatus: failed`, `shipped: []`.

| MSP | Stage | Outcome |
|---|---|---|
| a3-dialog-material-host | ship | PR #51, receipts+D6 SUCCESS, pr-title-lint FAILURE — merged anyway |
| a1-token-ladder | plan-review | PARKED, no convergence after 3 iterations, 1 HIGH unresolved |
| a2-typography-roles | blocked | never planned — blocked by A1 |
| a4-sticker-primitives | blocked | never planned — blocked by A1 |
| a5-cross-hatch-geometry | blocked | never planned — blocked by A1 |

**The unresolved A1 finding (regression-risk, HIGH).** Plan Task 4 Step 4 (`.mitosis/a1-token-ladder.plan.md:727-745`) uses `MSP_BASE="$(git merge-base main HEAD)"` as the authorship oracle for "did this MSP modify that path", then prescribes an autonomous destructive revert `git checkout "$MSP_BASE" -- <path>` for anything outside `fileScope`. `git diff base..HEAD` attributes EVERY commit on the branch to the MSP. The reviewer ran the plan's exact command in the live tree and it returned four committed non-A1 paths before A1 wrote anything — the four files of this session's own ledger commit `ddf351e`, including the write-once decision record. A literal executor would `git checkout` over committed ledger content and would read the resulting 8-path diff as an A1 scope violation. The finding holds independent of that commit: any pre-existing branch commit trips it. It is also an unconfirmed destructive git operation, which the global rules forbid prescribing autonomously.

Prescribed fix (three parts, all in Task 4 Step 4): anchor authorship to a SHA captured with `git rev-parse HEAD` before Task 1's first edit, not `merge-base main HEAD`; restate the expected diff as "A1's four fileScope paths PLUS whatever the branch already carried at that SHA"; gate any `git checkout -- <path>` behind explicit human confirmation instead of prescribing it as an autonomous step.

A3's own review converged on iteration 3 (`verdict: approve`, one low regression-risk note about `captureHarness` building a `MaterialApp` with no `theme:`, so those suites do not resolve app typography).

## Tried and failed
- **Assumed `sourcePrefix: msp` was still safe.** It was not. 241 refs already live under `msp/`, and the engine REUSES an existing branch rather than failing — `git worktree add ${wt} ${branch}` without `-b` when the branch exists (`mitosis.js:1012-1013`). `msp/design-tokens-integration` and `msp/sticker-widget-kit-integration` were live near-misses for A1 and A4, both with remote counterparts. Deleting the stale refs was rejected (37 worktrees are attached; `decisions/2026-07-20-keep-stale-worktrees.md`). Resolved by user ruling to `msp-cluster-a`.
- **Expected a PR retitle to re-fire CI.** It does not. The lint reads `PR_TITLE: ${{ github.event.pull_request.title }}` (`.github/workflows/receipts.yml:27`) and the workflow triggers on bare `on: pull_request`, whose default types are opened/synchronize/reopened — no `edited`. A `gh run rerun` replays the stale payload. Moot in practice: the check is not merge-blocking.
- **Engine sub-agent hit a macOS gap.** Its CI watch script used `timeout`, absent on macOS (exit 127, empty conclusion); it recovered with an iteration-bounded poll. Recorded because it will recur in the ship stage.

## Verification
- `gh pr view 50 --json state` — expected OPEN per the ledger; observed MERGED (`74d7706`). Ledger drift, corrected.
- `git fetch origin main:main` twice — local main was 2 behind before dispatch, 1 behind after the #51 merge; both fast-forwards, `0 0` against origin/main after each. Load-bearing: the engine cuts worktrees from the bare LOCAL main ref.
- `git diff origin/main HEAD --stat` on `chore/ledger-handoff-session-08` — expected empty (the squash-divergence check from session 03); observed empty, so the branch was fully merged and safe to leave.
- `git branch -a --list '*msp/*' | wc -l` — 241. Collision probes for `token|ladder|typograph|dialog|sticker|hatch|material|primitive` returned `msp/design-tokens-*` and `msp/sticker-widget-kit-*`.
- `sed -n '3295,3320p' mitosis.js` — confirmed the input parser reads only `{spec, repoRoot, baseBranch, sourcePrefix, verify, build, models, fixLoopMax, worktreeRoot, retry}`; `verify` consumes only `scopedCheckCmd`/`fullValidationCmd` (`:3552-3553`, `:4362`).
- `sed -n '3405,3450p' mitosis.js` — `decideConfig` returns `adoptConfig: true, writeConfig: false` when a receipts config is present, so the `build` seed is inert here and cannot overwrite `receipts.config.json`.
- `gh pr view 51 --json state,mergeCommit` — MERGED, `55d8ffc`. `git ls-tree -r --name-only origin/main -- lib/design/feedback/ test/design/feedback/` — `dialog_host.dart` and `dialog_host_test.dart` both present on main.
- No Dart suite was run by the main thread this session. A3's own verification ran inside the engine; per `decisions/2026-07-20-ci-gates-are-hollow-for-dart.md` the green `receipts` check on #51 is NOT evidence a Dart test ran. **A3 is unvalidated locally on main.**

## Running state
none — workflow `wf_e96d3f94-e03` returned terminal (`completed`, 31/31 agents done, 0 errors).

## Deferred + open
- **The A1 plan fix and re-dispatch.** User directed: apply the reviewer's fix, then re-dispatch in a FRESH session. Relaunch with `Workflow({scriptPath: "/Users/satanshumishra/.claude/workflows/mitosis.js", resumeFromRunId: "wf_e96d3f94-e03", args: <same args>})` — A3's completed agents replay from cache; only the edited plan-review call and everything after it run live. Same-session-only caveat on resume applies: if the cache is unavailable in a new session, dispatch fresh with the same args (`sourcePrefix` stays `msp-cluster-a`).
- **A3 unvalidated on main.** Run `fullValidationCmd` against main before trusting it, and hardware-confirm the dialogs (completion criterion 4).
- **A3's merged squash message is `mitosis: a3-dialog-material-host`** — non-conventional, now permanent in main's history. Retitle future PRs for hygiene only; it does not gate the merge.
- OQ-3 (entry-card Edit/Delete placement) and OQ-6 (photo attachment model) remain open; neither touches Cluster A.
- **WIP:** two non-terminal threads — `post-ship-hardening` (paused, unrelated) and `prototype-design-alignment` (paused). Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md for cap enforcement (files remain on disk, content unchanged): `decisions/2026-07-24-share-plus-13-blocked-by-file-picker.md` (share_plus 13.x needs win32 ^6 vs file_picker 11.0.2's ^5.9.0, and a PRERELEASE file_picker; build_runner/drift_dev pinned by riverpod_generator's analyzer ^12 ceiling) and `decisions/2026-07-24-macos-videorotationangle-crash.md` (the macOS 26 crash was the `AVCaptureConnection.videoRotationAngle` setter; fixed and shipped in PR #33, `a714961`).

## Pick up here
Edit `.mitosis/a1-token-ladder.plan.md` Task 4 Step 4 per `decisions/2026-07-27-scope-guard-authorship-oracle.md` — three changes, all in that one step. Then re-dispatch mitosis. A3 is already on main, so the run should ship A1, then A2/A4/A5. Before dispatching, confirm local `main` equals `origin/main` (the engine cuts worktrees from the local ref) and keep `sourcePrefix` at `msp-cluster-a`.
