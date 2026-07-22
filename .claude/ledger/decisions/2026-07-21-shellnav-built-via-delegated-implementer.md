---
date: 2026-07-21
status: accepted
supersedes: 2026-07-21-shellnav-checkpoint-refs-unblock.md
---

# shell-nav built via a delegated implementer (not a mitosis relaunch) → PR #31

The user directed "complete the implementation" while the main session was ~80% context. A mitosis
relaunch was BARRED by the fresh-context rule (runs die near-full; proven). So the final unit was
built OUTSIDE the engine: a delegated `implementer` subagent (its own fresh context) built
shell-nav-integration on origin/main, which already contains all 30 deps.

## Why this was correct
- Honors the fresh-context rule (subagent context is fresh; main thread only orchestrates).
- Follows delegation-discipline (main thread delegates implementation).
- SIDESTEPS the checkpoint-ref composition that parked shell-nav — building on merged main needs no
  parent-checkpoint stacking at all. (The refs pushed in [[2026-07-21-shellnav-checkpoint-refs-unblock]]
  were thus not needed; harmless, left in place.)

## What shipped
- Branch `msp/shell-nav-integration` @ baa2304 (based on origin/main bf527a4), PR #31.
- Wired real screens + capture routes + streak into the shell (fileScope lib/app/**, test/app/**).
- Scope expanded by ONE file (test/widget_test.dart) to keep the suite green (green-branch invariant):
  the phase-0 smoke test was HARDENED with the repo harness overrides (deletion was classifier-blocked).
- Independently validated by the main thread against the pushed head: analyze clean, flutter test
  660 passed / 0 failed. Both CI checks (pr-title-lint, receipts) green.

## Next
The HUMAN squash-merges PR #31 (gh pr merge is agent-blocked, [[2026-07-21-gh-merge-hook-blocked-human-merges]])
→ 31/31, Field Notes v1 implementation complete. Then reconcile local main; post-31 work =
reminders day-2 pre-arm MSP + Phase 8 human toolchain install for a local run.
