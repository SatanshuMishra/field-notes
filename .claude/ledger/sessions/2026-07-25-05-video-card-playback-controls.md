# Session 2026-07-25-05 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. The Resumption Brief hit a divergence again: the thread's Next Step opened
with "Merge PR #40", but #40 was already MERGED as `4e39884` and no PRs were open. The user said "Go", so
the session ran the documented sequence — fast-forward local `main`, then dispatch mitosis for MSPs 1-3.

## What shipped
- Ledger correction retiring the stale PR #40 gate — `e979380`, on branch `chore/ledger-handoff-session-05`.
- `decisions/2026-07-25-source-prefix-is-a-bare-token.md` — `ee44023`.
- Local `main` fast-forwarded `5cb5bad -> 4e39884`, satisfying the pre-relaunch reconciliation record.
- Mitosis run `wf_de373384-5d7`: 50 agents, 3,845,347 subagent tokens, 1097 tool calls, ~100 minutes.
  One MSP reached a PR; two parked. `overallStatus: failed`, `shipped: []`.
- MSP 1 (macos-capture-thumbnail) -> PR #41, awaiting the HUMAN's merge. Branch
  `msp/macos-capture-thumbnail-integration` at `95c245e`, 8 commits ahead of `main`, 4 task branches.

## The finding that mattered
`sourcePrefix: "msp/"` — copied verbatim from the session-04 handoff — is NOT a legal engine input. The
first dispatch died in 12ms at stage `input` with zero agents spawned and nothing created. The engine
composes the branch itself (`mitosis.js:422`, `:4131`) and validates against `REF_TOKEN_PATTERN` (`:2550`),
which requires every `/`-separated segment to start alphanumeric; a trailing slash leaves an empty final
segment. Pass the bare token `msp`. Full reasoning in the decision record above.

## Tried and failed
- **MSP 2 (poster-first-decode-gate) PARKED at `execute`.** task-2 exhausted its two-lens review with a
  HIGH finding: "Spec deviation: a fifth, unrequested edit to `lib/features/entry_cards/cards/video_body.dart:88-96`".
  The spec fenced MSP 2 to `video_body.dart` as its only `lib/` file and enumerated the intended edits. The
  engine's diagnosis string is TRUNCATED AT THE SOURCE — the full issue list was never emitted to the run
  result. Recover it from the task-2 worktree, not from the report:
  `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-poster-first/msp/poster-first-decode-gate/task-task-2`.
  The engine offered undo `git branch -D msp/poster-first-decode-gate-integration`. NOT RUN — branch
  deletion needs explicit authorization and that branch holds the only copy of the work.
- **MSP 3 (day-detail-feed-virtualization) PARKED at `plan-review`**, no convergence after 3 iterations.
  Never reached implementation; no `msp/day-detail-feed-virtualization*` branch exists. Plan to edit:
  `.mitosis/day-detail-feed-virtualization.plan.md`.
- **First local validation measured the WRONG TREE and looked green.** `git worktree add` failed
  ("already used by worktree at .../msp/macos-capture-thumbnail/integration"), the chained `cd` failed with
  it, and with no `set -e` the analyze+test then ran in the main repo checkout on the ledger branch. It
  printed "All tests passed!" — a true statement about `main`, and no evidence at all about PR #41. Re-run
  with `set -e` plus an explicit `TREE:`/`HEAD:` echo so the tree under test is visible, not assumed.

## Verification
- `gh pr view 40` / `git log origin/main` — #40 MERGED as `4e39884`; contradicted the thread's Next Step.
- `git diff --stat origin/main cc235fb` — EMPTY. The #40 squash stranded nothing, unlike #38 and #39.
- `git rev-parse main origin/main` — identical (`4e39884`) before dispatch.
- `grep -n sourcePrefix mitosis.js` + `REF_TOKEN_PATTERN` at `:2550` — read the validator rather than
  guessing at the rejection.
- PR #41 head, real tree, `95c245e`: `flutter analyze` clean; `flutter test` **861 passed**. `main` at the
  same moment: **856 passed**. The +5 delta is MSP 1's new coverage. This is the only real gate — both
  GitHub checks (`receiptsPass`, `d6Pass`) are vacuous here per 2026-07-20-ci-gates-are-hollow-for-dart.
- `git log -1 msp/day-detail-integration` — 2026-07-20 `bf4c449`, NOT an ancestor of `main`. The feared id
  collision is MOOT: this run named MSP 3 `day-detail-feed-virtualization`, a distinct ref.

## Running state
- none. All three background shells completed; the workflow returned. Note that a Workflow run is
  resumable only WITHIN its originating session, so `wf_de373384-5d7` cannot be resumed from a fresh
  session — a relaunch re-decomposes and reconciles already-merged MSPs from the remote.

## Deferred + open
- PR #41 open, locally validated green, awaiting the human's merge (`gh pr merge` is hook-blocked).
- Branch `chore/ledger-handoff-session-05` carries this ledger; its PR is opened at the end of this handoff.
- MSP 2 park: decide salvage-vs-discard after reading the full findings in the task-2 worktree.
- MSP 3 park: edit `.mitosis/day-detail-feed-virtualization.plan.md`, then relaunch.
- The macOS hardware run is STILL unperformed. Four of the nine criteria demand it by name.
- Flutter drift: PROJECT.md records 3.44.6; this machine runs 3.44.8. Not load-bearing, not yet corrected.

## Pick up here
PR #41 is the only merge-ready artifact and it is human-gated. Merge it, then fast-forward local `main`
again before any relaunch — the engine cuts worktrees from the bare LOCAL ref.

The two parks are independent and neither is a resume: each needs a human decision first. MSP 2 needs the
truncated review findings read out of its task-2 worktree before deciding whether the fifth edit is
salvageable or the branch is discarded. MSP 3 needs its plan edited against the adversarial findings. A
relaunch after either edit is a fresh dispatch — and it MUST pass `sourcePrefix: "msp"`, no slash.

## Demoted from PROJECT.md (80-line cap)
Index line removed to make room for the new 2026-07-25 record. The decision FILE remains on disk and loads
on demand; it belongs to the completed 31/31 build era:
- `decisions/2026-07-12-direct-ship-built-msps.md` — ship the 3 already-built foundations via main-thread
  push+PR+squash-merge rather than a mitosis relaunch; engine reserved for building the unbuilt dependents
  (Option B). Historical: 31/31 shipped on 2026-07-21.
