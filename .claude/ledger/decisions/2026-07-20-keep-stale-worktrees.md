Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
Roughly 24 worktrees have accumulated under `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees` from merged MSPs and their per-task branches. Prior sessions repeatedly logged them as stale leftovers pending a destructive cleanup, and re-proposed that cleanup each session.

## Decision
Keep them indefinitely, by user directive. They are wanted for manual testing once the app is built and deployed: each is a ready-to-run checkout pinned at a known-good MSP state, which makes it cheap to reproduce or bisect a hand-found issue against the exact tree that shipped it. Cleanup is not pending, not deferred, and must never be proposed again as housekeeping.

## Consequences
All prior ledger entries listing worktree cleanup as an open item are void. They cost only disk and cannot affect a mitosis run: the engine skips already-merged units at the top of `runUnit()`, before any worktree is read — confirmed live on run wf_00757aaa-c12, where 20 units were skipped with ~24 worktrees present. The `.fireplace-worktrees` root keeps its legacy name because `worktreeRoot` is hardcoded in the launch contract; renaming it would break every future launch for no benefit.
