Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment
Supersedes: decisions/2026-08-01-msp-prs-target-main-never-another-msp-branch.md

## Context
The superseded record banned stacked PRs after Cluster D stranded D3/D4, and rejected stacking on the grounds that "GitHub retargets automatically only when the base branch is DELETED". That rationale described the legacy 2020 PR-retargeting behaviour, not GitHub's native Stacked Pull Requests feature (public preview 2026-07-30), which tracks a stack as a first-class server object and performs a server-side cascading rebase on merge. The user directed the correction and supplied the docs.

## Decision
Cluster E ships as ONE native GitHub stack: E1 base `main`, E2 base `msp-cluster-e/e1`, E3 base `msp-cluster-e/e2`, E4 base `msp-cluster-e/e3`. Base-chaining alone is NOT a stack — verified: plain `gh pr create --base` yields an ordinary chained PR with no cascade. After the PRs exist, they are linked via `POST /repos/SatanshuMishra/field-notes/stacks` with `pull_requests` ordered bottom-to-top (extend with `/stacks/{n}/add`). GraphQL is read-only for stacks; `gh stack` is an extension (`github/gh-stack`) and is NOT installed — REST only. The Cluster E slice ships as its own independent docs PR against `main`, outside the stack.

## Consequences
- Restores the scoped-diff benefit: each PR shows only its own layer. Unblocks implementing all four MSPs in one pass instead of one merge-gated session per MSP.
- Merge order is bottom-up and structurally enforced: merging a mid-stack PR merges every unmerged PR below it in the same operation; a mid-stack PR cannot merge in isolation.
- OPEN RISK, unverified: whether the stack cascade requires the merged head branch to be deleted. Docs do not settle it. Mitigation: allow branch deletion on merge for `msp-cluster-e/*` (Cluster D already deleted its `msp-cluster-d/*` branches, so the keep-branches directive does not cover new MSP branches), and after each merge confirm the next PR's base retargeted to `main` via `gh pr view <n> --json baseRefName` BEFORE merging it.
- `gh pr merge` is denied globally, so every merge stays a human action. Verified live: `gh api repos/SatanshuMishra/field-notes/stacks` returns 200 `[]`, so the feature is enabled on this private personal repo.
- Rejected: installing the `gh stack` extension (adds a dependency for what two REST calls do), and waiting for each merge before opening the next PR (the superseded rule, which costs one session per MSP).
