Status: accepted
Date: 2026-08-01
Thread: prototype-design-alignment

## Context
Cluster D executed as a dedicated workflow: D1 alone, then D2/D3/D4 in parallel worktrees branched off D1's tip. To keep each review diff scoped to its own MSP, D2/D3/D4 opened as stacked PRs with `--base msp-cluster-d/d1-rail-container`. D1 (#88) squash-merged to main as `dbbc7a4`. Merging #89 and #90 then merged them into D1's BRANCH, not main, leaving D3 and D4 live only on a branch whose content main already carries in squashed form under a different SHA.

## Decision
An MSP PR's `--base` is ALWAYS `main`. A downstream MSP that depends on an upstream one waits for the upstream to merge, then rebases `--onto main`, revalidates on the new base, and only then opens its PR with `--base main`. Stacked PRs based on another MSP branch are prohibited for the rest of this spec.

## Consequences
- Costs the scoped-diff benefit stacking was chosen for: a downstream PR opened before its upstream merges would show both diffs. Waiting is the price, and it is smaller than the recovery this cost.
- Recovering D3 and D4 requires a fresh branch cut from `dbbc7a4`. A direct PR from `msp-cluster-d/d1-rail-container` into main would DELETE `docs/specs/2026-07-29-prototype-alignment-cluster-d.md` (-617 lines) because the branch predates the slice's merge.
- Binds clusters E-H, where every remaining cluster has an in-cluster chain per decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md, so this topology would otherwise recur four more times.
- Rejected: keeping stacking and retargeting each PR's base to main after the upstream merges. GitHub retargets automatically only when the base branch is DELETED, and this project keeps `msp-cluster-*` branches by standing directive, so the retarget would have to be manual per PR and would silently not happen.
