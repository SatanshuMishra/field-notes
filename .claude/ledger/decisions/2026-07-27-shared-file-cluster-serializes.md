Status: accepted
Date: 2026-07-27
Thread: prototype-design-alignment

## Context
Cluster A's five MSPs owned mostly disjoint files, so its slice never had to reason about two MSPs editing one file. Cluster B is the opposite: B1, B2, B3 and B4 ALL edit `lib/app/shell/sidebar_shell.dart`, and B3 and B4 both branch off B2 into that same widget. Mitosis fans MSPs into isolated worktrees; a dependency graph that models only declared deps would let two independent rewrites of one rail widget be authored from the same base and textually merged.

## Decision
When a cluster's MSPs share a file, the shared file is a HARD dependency edge, declared in the slice itself — not left to the engine's graph to infer. The Cluster B slice states the chain `B1 -> B2 -> {B3, B4}` and requires that whichever of B3/B4 reaches integration second rebases onto the first and re-verifies, never merging from a stale base.

## Consequences
- Every future slice (C–H) must compute the file-overlap matrix across its own MSPs before dispatch and carry a SERIALIZATION section when overlap exists. Cluster C (C1–C7 on the Today column) and D (D1–D4 on the right rail) are the next likely candidates.
- Costs parallelism inside the cluster: B is effectively a chain, so its wall-clock is the sum of four MSPs, not the max. Accepted — a silent textual merge of two rail rewrites is the more expensive failure (Quality over Speed).
- Rejected: relying on the engine's conflict detection at merge time. It catches overlapping HUNKS, not two coherent-but-incompatible rewrites of the same widget, which is the actual risk here.
- Related: `2026-07-27-cluster-a-scoped-spec.md` (slices are how a run is scoped) and `2026-07-27-source-prefix-is-run-distinct.md` (each cluster takes its own prefix).
