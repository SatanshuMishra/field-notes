Status: accepted
Date: 2026-07-11
Thread: journal-app-design

## Context
Mitosis run 5 proved the engine but all 4 PRs went CI-red: `.github/workflows/receipts.yml` ran `npm ci` on a Flutter repo with no lockfile, aborting before the receipts enforcer + D6. A code read of mitosis.js established how a relaunch treats the already-built-but-unmerged PRs.

## Decision
Fix = delete the `npm ci` step (kept setup-node; d6-check.cjs is Node-builtins-only, enforcer is self-contained). Landed as ec7b959 on origin/main. Relaunch strategy: rebuild the 4 onto their existing PR numbers (open PRs are NOT reuse-skippable — only MERGED PRs skip via runUnit:2378).

## Consequences
- Pre-flight before EVERY relaunch: remove any stale worktrees (branch-prep `git branch -f` @mitosis.js:2492 fails on a branch checked out in a worktree); KEEP `.mitosis/run.json` (evaluateManifestReuse @1041 keeps 31 MSP ids stable so PR-reuse lookup matches — deleting it risks duplicate PRs); leave remote branches/PRs alone.
- A full run exceeds one Claude usage window; expect multiple relaunch-to-resume cycles (run 6 died on the usage limit at ~18min).
- Rejected: hand-merging the 4 PRs to force true reuse — bypasses mitosis's serialized bottom-up + D6 safety; not worth it since the 4 are cheap foundation rebuilds.
- Open: human-gated (default) vs autonomous merge policy — undecided.
