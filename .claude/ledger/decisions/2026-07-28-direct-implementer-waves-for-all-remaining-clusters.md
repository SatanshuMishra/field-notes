Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
Asked to dispatch mitosis for the remaining MSPs. Mitosis has no legal target. Every remaining cluster has an in-cluster dependency chain — the exact shape 2026-07-28-cluster-c-skips-mitosis.md excludes it from — verified against the parent spec's own `Depends on` lines: D2/D3/D4 all depend on D1; E2/E3 on E1 and E4 on E1+E2+E3; F2 on F1, F3 on F1+F2, F4 on F1; G2/G5/G7 on G1, G3 on G2, G6 on G5, G8 on G6+G7. H1 is a single MSP, which that decision's own corollary calls not mitosis-shaped. No execution slice exists for D-H (only A, B and C are in docs/specs/), and the run contract requires the slice landed on base before dispatch. Cluster C's remainder is unavailable too: C5 and C6 already exist as built branches, and 2026-07-28-recover-stranded-checkpoints-over-redispatch.md forbids re-dispatching to re-implement existing work.

## Decision
The whole remaining spec (Clusters C through H) executes as direct `implementer` waves orchestrated from the main thread, one PR per MSP through `pr-create`, with `fullValidationCmd` locally against each head. Mitosis is not dispatched for this spec again unless its defect is fixed first.

## Consequences
- The decision's carve-out — "a cluster with no in-cluster chain is unaffected" — applies to ZERO remaining clusters. That carve-out is now spent, not merely unused.
- Extends 2026-07-28-cluster-c-skips-mitosis.md from one cluster to the whole spec. It does not supersede it; the root-cause analysis there still stands.
- Cost: no engine-managed parallelism for ~24 remaining MSPs. Accepted by the user over the alternatives.
- Rejected: cutting a Cluster D slice and dispatching anyway, accepting parks and recovering stranded checkpoints afterwards — recovery is an accident response, never a plan.
- Rejected for now, but the real unlock: repairing the `saga.mjs` / `run-engine.mjs` force-with-lease collision before dispatching, which would free the 21 D-H MSPs.
