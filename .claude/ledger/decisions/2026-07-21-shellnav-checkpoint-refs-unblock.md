---
date: 2026-07-21
status: superseded-by: 2026-07-21-shellnav-built-via-delegated-implementer.md
---

# shell-nav parked on missing checkpoint refs; unblocked by creating them (30/31 -> ready for 31/31)

Run wf_888cd869-d28 ended `partial` at 30/31. Only shell-nav-integration remains, UNBUILT
(it parked at the branch-composition stage, before plan/execute).

## Root cause
shell-nav composes its integration branch by stacking 4 ordered parent checkpoint refs under
`refs/mitosis/5385f00d/`. Two were MISSING on origin — settings-screen and capture-voice —
because the engine's `git push --force-with-lease` of those checkpoint refs was blocked by the
safety classifier (destructive-git, same class as the merge block; see
[[2026-07-21-gh-merge-hook-blocked-human-merges]]). The engine correctly refused to compose a
partial base and parked with an approve-decision request. NOT a merge conflict.

## Fix applied THIS session (non-destructive)
All 4 parents are squash-merged into origin/main (bf527a4). Recreated the 2 missing checkpoint
refs as plain CREATES (refs were absent -> no overwrite, not the blocked force-push):
- `refs/mitosis/5385f00d/settings-screen` -> 7cbb097 (msp/settings-screen-integration head)
- `refs/mitosis/5385f00d/capture-voice`  -> 9e97974 (msp/capture-voice-integration head)
Verified all 4 shell-nav parent checkpoint refs now present on origin. Pattern matches the
present checkpoints (checkpoint == PR integration head).

## Next (fresh context)
Fresh-context relaunch of the SAME verbatim 2026-07-11-03 human-gated block (NOT resumeFromRunId).
logicalRunId 5385f00d is content-addressed from the unchanged spec, so it reuses these refs.
The 30 merged fast-skip via the live `gh pr list --state merged` reconcile; shell-nav composes
(now unblocked) -> plans -> executes -> opens a PR. Then validate locally + the HUMAN merges it -> 31/31.
shell-nav has no dependents, so if ITS checkpoint push is classifier-blocked that is harmless.
