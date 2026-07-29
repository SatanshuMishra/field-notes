Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
Run 1 parked B2 at `ship` on an "ambiguous frontier state": no `builtSha` was recorded, because it is sourced from the checkpoint-push agent's return (`mitosis.js:4598`) and that agent family was blocked by the harness safety classifier for authorizing an unconfirmed `git push --force-with-lease` (`:4586`). The manifest records `"sha":null` for all four units; B1 shipped anyway only because it had no unmerged parent and skipped the `requireSha: true` frontier path (`:4306`). The user then approved shipping B2's tip as-is.

## Decision
A mitosis unit parked at `ship` is resumed by RE-EXECUTION, not by restoring its durable checkpoint. Budget a park at `ship` as a full re-run of that MSP.

## Consequences
- Reading `mitosis.js:4298` (built-resume passes no `expectedSha`, so `:4284`'s guard is falsy) predicts a cheap restore-and-ship. That prediction was made this session and was WRONG — run 2 re-entered `execute` and rebuilt B2 from scratch.
- The engine exposes NO approve input (`{spec, repoRoot, baseBranch, sourcePrefix, verify, build, models, worktreeRoot, fixLoopMax, retry}`), so a human "approve this tip" cannot be expressed to it. The approval could only be attempted as a re-dispatch, and did not take effect: B2's approved artifact `97d91a8` remains unshipped and unvalidated by any Dart run.
- Do NOT wipe `.mitosis/run.json` to force a clean run: shipped-state folding requires the unit to exist in the prior manifest (`:3696`), so a blank manifest re-executes already-merged MSPs into duplicate PRs. Rotate `worktreeRoot` instead, or cut a new slice spec (new path -> new `logicalRunId` -> clean manifest).
