Status: accepted
Date: 2026-07-11
Thread: journal-app-design

## Context
Mitosis run 7 (wf_f16b0bef-2bf) ran to completion (73 agents, ~2.4h): platform-permissions published fresh, but design-tokens/drift-database/mood-catalog parked at ship because their run-5 remote branches were STALE (old base d3726e0, no ec7b959) and the required `git push --force-with-lease` was DENIED for the delegated subagent. 27 dependents blocked behind them.

## Decision
User authorized the force-push. Main thread ran `git push --force-with-lease` (lease-anchored to the stale SHAs) for the 3 diverged branches -> all 4 foundation PRs (#1-4) on fresh heads. CI went GREEN for the first time (receipts fix ec7b959 confirmed working). User chose AUTONOMOUS merge policy. Main thread squash-merged all 4 foundation PRs -> origin/main advanced ec7b959 -> ef3e8c6. FOUNDATIONS SHIPPED (4/31).

## Consequences
- Next relaunch MUST pass `mergePolicy: "autonomous"` (mitosis.js:2054 reads input.mergePolicy; only exact "autonomous" enables self-merge, else human-gated).
- Merged foundations are fast-skipped by the ship done-oracle (`gh pr view <branch>` MERGED -> skip; mitosis.js:2538) -> no rebuild/force-push/denial for them.
- 27 dependents publish via first-time `git push -u` (fast-forward, no force) and autonomous squash-merges each green PR (mitosis.js:2528).
- RESIDUAL RISK: the permission classifier may also gate the agent's `gh pr merge --squash`. If ship agents park at merge, fall back to main-thread manual merge per green PR + relaunch.
- Force-push is now a non-issue going forward (no more stale run-5 branches); only recurs if a relaunch dies after publish-before-merge, leaving a lingering published-unmerged dependent.
