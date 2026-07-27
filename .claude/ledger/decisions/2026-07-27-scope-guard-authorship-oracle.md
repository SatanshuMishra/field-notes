Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
A1's plan review did not converge after 3 iterations on one HIGH finding, parking A1 and blocking A2/A4/A5. The plan's scope guard (`.mitosis/a1-token-ladder.plan.md:727-745`) used `MSP_BASE="$(git merge-base main HEAD)"` as the authorship oracle for "did this MSP modify that path", then prescribed an autonomous `git checkout "$MSP_BASE" -- <path>` revert for anything outside `fileScope`. `git diff base..HEAD` attributes EVERY commit on the branch to the MSP. Run live, it already returned four committed non-A1 paths — this session's ledger commit `ddf351e`, including a write-once decision record.

## Decision
Adopt the reviewer's fix, and treat it as the standing pattern for every mitosis plan scope guard in this repo: (1) anchor authorship to a SHA captured with `git rev-parse HEAD` BEFORE the MSP's first edit, never `merge-base main HEAD` and never a fixed `HEAD~N` offset; (2) state the expected diff as the MSP's fileScope paths PLUS whatever the branch already carried at that SHA; (3) never prescribe `git checkout -- <path>` as an autonomous step — gate it behind explicit human confirmation.

## Consequences
- A plan is only safe to execute in a shared tree if its guard distinguishes "this MSP's commits" from "commits the branch already carried". `merge-base` cannot make that distinction; a captured SHA can.
- Part (3) is the global rule on unconfirmed destructive git operations reaching into generated plans, not a new constraint.
- The guard is correct as written in a clean per-MSP worktree cut from main; it fails only in a shared tree. A1's plan explicitly claimed to hold in ANY tree, so the claim, not just the command, had to change.
