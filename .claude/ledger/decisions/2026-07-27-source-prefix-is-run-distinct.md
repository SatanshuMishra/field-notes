---
decision: source-prefix-is-run-distinct
date: 2026-07-27
status: accepted
supersedes: 2026-07-25-source-prefix-is-a-bare-token.md
---

`sourcePrefix` is a BARE token with NO trailing slash — the engine composes `${sourcePrefix}/${msp.id}-integration` itself (`mitosis.js:420`) and `REF_TOKEN_PATTERN` (`:2548`) rejects `msp/`. That rule stands unchanged.

Added: the token is RUN-DISTINCT, not the literal `msp` every run. This repo carries 241 refs under `msp/` from prior runs, several with remote counterparts. The engine reuses rather than fails on an existing branch: it checks `rev-parse --verify --quiet ${branch}` and, when the branch exists with no worktree attached, runs `git worktree add ${wt} ${branch}` WITHOUT `-b` (`:1012-1013`). A decomposer-slugified id that collides — `design-tokens` or `sticker-widget-kit` were both live near-misses for Cluster A's A1 and A4 — therefore builds silently on a months-old branch and ships its commits in the PR.

Deleting the stale refs is the wrong fix: 37 worktrees are attached to them and `decisions/2026-07-20-keep-stale-worktrees.md` keeps them on purpose.

This run uses `msp-cluster-a`. Each later cluster takes its own token. Consistent with `decisions/2026-07-25-msp-branch-prefix-not-per-type.md` (one prefix per run = batch identity); supersedes only the literal token in `decisions/2026-07-27-prototype-alignment-run-contract.md`, never its other terms.
