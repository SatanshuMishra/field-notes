# Recover stranded MSP artifacts from durable checkpoints; do not re-dispatch mitosis

Date: 2026-07-28
Status: accepted
Thread: prototype-design-alignment

**Decision.** When a mitosis run strands finished MSP work on a durable checkpoint ref, recover that artifact, validate it locally with `fullValidationCmd`, and ship it as an ordinary PR. Do not re-dispatch mitosis to re-implement work that already exists.

**Why.** Three dispatches on the Cluster B slice cost ~8.1M subagent tokens and shipped one MSP. All three failures were infrastructure — a classifier-blocked checkpoint push nulling `builtSha`, then a stale-branch collision — never work quality. `refs/mitosis/55d6da7a/b3-nav-states-icons` at `54fd9ef` held B2 **and** B3 complete, rebased onto post-B1 `main`, 170 insertions across 3 in-fence files. Two MSPs recovered for the cost of two local validation runs.

**Two facts that made recovery cheap, worth checking first next time.**
- A later MSP's checkpoint may be a **superset** of an earlier one. B3's branch carried B2's commits re-created on a main base, so `54fd9ef` shipped both.
- The engine rebases integration branches onto the merged base. `9a53222` is an ancestor of `54fd9ef`, so the checkpoint merged cleanly; the older `97d91a8` predates the B1 squash-merge and does not. Prefer the newest checkpoint in the chain as the ship tip, and read individual commits out of it for per-MSP PRs (`f6aae95` is B2's tip on a main base, content-identical to the approved `97d91a8`).

**Corollary.** A single remaining MSP is not mitosis-shaped — the skill exists for work that splits into more than one shippable unit. B4 goes to one `implementer` dispatch, not a fourth run.

**Supersedes nothing.** `2026-07-28-parked-ship-resumes-by-re-execution.md` stands: a park at `ship` still resumes by full re-execution. This decision is why you should not pay for that.
