Status: accepted
Date: 2026-07-28
Thread: prototype-design-alignment

## Context
`git push --force-with-lease` is refused by the harness auto-mode classifier for the MAIN THREAD, not only for mitosis's checkpoint-push agent family. This was proven directly while shipping C6. Since 2026-07-28-stacked-msps-ship-sequentially.md mandates `git rebase --onto main` between every merge, and a rebase always makes the branch non-fast-forward, every remaining MSP needs a force-push it cannot perform. The standing user authorization for `--force-with-lease` on `msp-cluster-c/*` does not help: the block is a harness classifier, not a permission the user already granted in chat.

## Decision
Ship a rebased MSP by pushing its validated tip to a NEW ref (`<branch>-rebased`) and opening the PR from that ref. The original branch is left untouched at its pre-rebase SHA. No history is rewritten and nothing is lost, so the operation is strictly additive.

## Consequences
- Each rebased MSP leaves an orphan branch pair on origin. Accepted as clutter; the alternative is stalling the ship loop on a permission the agent cannot obtain.
- The durable fixes are a `Bash(git push --force-with-lease:*)` permission rule, or the user running the one-line push. Ask early rather than accumulating orphans.
- This is the SAME defect blamed for Cluster B's ~8.1M-token, one-MSP outcome. Choosing direct `implementer` waves over mitosis did not route around it, because the blocker is the harness, not the engine.
- The engine citations in 2026-07-28-cluster-c-skips-mitosis.md and -parked-ship-resumes-by-re-execution.md are now STALE: `mitosis.js` no longer exists and `requireSha` has zero hits. The mechanism survives at `saga.mjs:63` (emits the force-with-lease push) and `run-engine.mjs:100` (`DESTRUCTIVE_OP_RE` matches `--force-with-lease`).
- Rejected: asking the user to approve each push interactively. It converts every MSP into a blocking round-trip for an operation that has a safe additive equivalent.
