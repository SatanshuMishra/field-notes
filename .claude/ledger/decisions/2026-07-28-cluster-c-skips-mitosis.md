Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
Cluster B cost ~8.1M subagent tokens across three mitosis dispatches and shipped one MSP; all three failed on infrastructure, never work quality. The root cause is unfixed: `mitosis.js:4586` authorizes an unconfirmed `--force-with-lease`, the harness classifier blocks that agent family, and `builtSha` is therefore null run-wide (`:4598`), parking every unit that reaches the `requireSha: true` frontier path (`:4306`). B1 shipped only by having no unmerged parent. Cluster C has three MSPs — C3, C5, C7 — with unmerged in-cluster parents, which is exactly that shape.

## Decision
Cluster C is executed by direct `implementer` dispatches in the slice's three waves, orchestrated from the main thread. Mitosis is NOT dispatched for this cluster. One PR per MSP through the centralized `pr-create` tool, `fullValidationCmd` locally against each head before merge, `git rebase --onto main` plus revalidation between merges.

## Consequences
- Verification is unchanged and no weaker: the same local gate that proved every Cluster B MSP, plus the 106-case playback suite green before and after C7.
- The parallel-safety net moves from the engine's graph to the slice's declared file-overlap matrix, which is why that matrix is computed and written into §0 rather than inferred.
- The slice was still landed on `main` first, so a later mitosis run remains possible without re-cutting it.
- This does not retire mitosis. It is scoped to a cluster whose dependency shape triggers the known defect; a cluster with no in-cluster chain is unaffected.
- Rejected: dispatching mitosis and recovering the strand afterwards. That is the Cluster B experience, and 2026-07-28-recover-stranded-checkpoints-over-redispatch.md is explicit that recovery is the response to an accident, never a plan.
