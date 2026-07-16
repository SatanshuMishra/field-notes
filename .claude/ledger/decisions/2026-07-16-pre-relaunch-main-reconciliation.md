Status: accepted
Date: 2026-07-16
Thread: journal-app-design

## Context
Merging a PR advances origin/main only; local main keeps its unpushed ledger commits and DIVERGES (shared ancestor, no descendant relationship). Prior sessions reconciled local main by habit. Code inspection this session established WHY it is mandatory: mitosis.js creates worktrees with `git worktree add [-b <branch>] <wt> <baseBranch>` (:946, :1114) where baseBranch is the bare string "main" — git resolves that to the LOCAL branch, not origin/main. The done-oracle reads origin (`gh pr list --state merged --base main`, :2855), so it correctly skips merged MSPs, but the worktree base comes from local main.

## Decision
Before every mitosis relaunch, reconcile local main onto origin/main (`git rebase origin/main`, replaying unpushed ledger commits) and assert `git merge-base --is-ancestor <origin/main sha> HEAD` passes. A relaunch is forbidden while local main lacks a merged dependency.

## Consequences
Guarantees downstream MSP worktrees are cut from a base containing every merged dependency, regardless of whether the engine resolves local or origin main. Skipping it risks a silently-wrong multi-hour run where dependents build against a base missing their prerequisite. Rejected alternative: `git reset --hard origin/main` — discards the unpushed ledger commits; rebase preserves them. The rebase is non-destructive (unpushed local commits only, no force-push).
