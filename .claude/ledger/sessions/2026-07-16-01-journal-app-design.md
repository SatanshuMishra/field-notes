# Session 2026-07-16-01 — journal-app-design

(Session spanned 2026-07-15 evening into 2026-07-16 00:20 MDT.)

## Where it started
Resumed the paused thread (/resume-project journal-app-design) at 13/31 merged, origin/main 6339c6f, with PR #14 core-providers published-but-unmerged. User approved the merge, then directed three mitosis relaunch attempts.

## What shipped
- MERGED PR #14 core-providers (squash, merge commit 66a12a46) -> origin/main 6339c6f -> 66a12a46. **14/31 SHIPPED.** Remote branch deleted; local branch deletion failed (worktree holds it) — cosmetic only.
- Reconciled local main: rebased 7 unpushed ledger `chore:` commits onto origin/main -> HEAD b359ddc, which now CONTAINS core-providers. Clean rebase (ledger-only files vs code).
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md written (verified-from-code invariant).

## Tried and failed
Three mitosis launches, ALL dead. Do NOT resume any of them.
- **wf_f28d7d12-1cd** (task wzobiehru), launched ~15:27 MDT Jul 15. Spawned its decompose agent; transcript froze at 15:28:56 and the run died during a ~3h idle gap (launching process exited). 0 published. Diagnosed via: transcript mtime 3h stale + no engine process + TaskOutput "no task found". Force-stopped.
- **wf_bfb12095-952** (task wguyt43ig), launched ~18:33 MDT Jul 15. Ran 7378415ms (~2.05h); 86 agents (52 done, 34 errored); 4.32M subagent tokens; overallStatus "partial". Reconcile worked correctly (detected relaunch logicalRunId 5385f00d, reused 31 MSPs, skipped fresh Decompose, fast-skipped all 14 merged). Then **hit the account session limit ("resets 11:30pm America/Edmonton")**, which cascaded ~all remaining work into parking. **0 PRs published.**
- **wf_1245a178-eaf** (task w7k6kdj9x), launched 00:14 MDT Jul 16 — a mistake: fired at ~83% context, the exact condition that kills runs. STOPPED cleanly via TaskStop within a minute (reconcile phase, nothing published, no work lost).

## Parked state from wf_bfb12095-952 (17 parked == all 17 remaining MSPs)
- **STRUCTURAL (1) — entry-cards**, halted at merge: add/add conflict on `test/features/entry_cards/support/entry_cards_harness.dart`, created INDEPENDENTLY by both `task-media-resolver-harness` (merged in-run, commit de79f13, 137-line version) and `task-note-body`. A task-graph ownership defect — **deterministic, will re-park every relaunch until the entry-cards plan assigns that file to exactly one task.** Blocks 5: today-screen, day-detail, calendar-screen, search-screen, shell-nav-integration.
- **SESSION-LIMIT casualties (7)** — expected to build cleanly on a fresh window: sound-effects (execute), mood-picker (parallelize), garden-screen (branch), streak-service (execute; journaled-dates-provider qual-exhausted), capture-core (execute; capture-kinds + capture-service qual-exhausted; blocks 8), reminders (plan), data-management (plan).
- **Transitively blocked (9):** capture-photo, capture-voice, capture-video, today-screen, day-detail, calendar-screen, search-screen, settings-screen, shell-nav-integration.
- Durable park checkpoints did NOT persist (written=null — the limit killed those writes too). Only 2 stale checkpoint refs exist (journal-repository, media-store; both already merged). So the next relaunch reconciles from gh/git and REBUILDS parked MSPs fresh from plan — idempotent, but no partial reuse.
- The safety classifier (claude-opus-4-8) was UNAVAILABLE when reviewing `parallelize:garden-screen` and `sec:streak-service` — that subagent work is unverified; re-review if those artifacts are reused.

## Verification
- `gh pr view 14 --json state,mergeCommit` — MERGED, 66a12a46. `git rev-parse origin/main` — 66a12a46 (was 6339c6f).
- `git merge-base --is-ancestor 66a12a46 HEAD` — exit 0 after rebase (local main contains core-providers).
- `grep -n "mergePolicy" mitosis.js` — engine reads input.mergePolicy at :2811; MERGE_POLICY_HUMAN_GATED at :2642. Ledger contract confirmed against current code (line numbers shifted from the old :2529 note; file updated Jul 15).
- `gh pr list --state open` — EMPTY at session end (authoritative; result.shipped's 14 entries were all done-oracle fast-skips, confirming the known misleading-summary lesson).
- `TaskStop w7k6kdj9x` — success. `git status --porcelain` — clean.

## Running state
- None. All three runs dead/stopped. No background tasks or shells.

## Deferred + open
- entry-cards harness-ownership fix (structural; see above) — needed before the screens layer can ship.
- Usage window reset at 11:30pm MDT Jul 15; a fresh window was available at handoff (00:20 MDT Jul 16) and is unused.
- ~90 leftover local msp/* branches + ~16 worktrees. Safe (engine branch-prep does observe-then-converge). No cleanup required.
- Phase 8 local launch still needs the human toolchain install (full Xcode+CocoaPods, Android SDK).

## Pick up here (fresh session)
1. Verify: `gh pr list --state open` (expect empty); `git rev-parse origin/main` (expect 66a12a46).
2. Relaunch mitosis human-gated (KEEP run.json) from a CLEAN context using the contract in sessions/2026-07-11-03 with mergePolicy "human-gated". Expect the 7 session-limit MSPs to build + publish; expect entry-cards to re-park on its add/add conflict.
3. VERIFY published PRs via `gh pr list --state open`, NOT result.shipped. Merge each green PR from the main thread under explicit per-batch consent.
4. Fix entry-cards harness ownership before the screens layer. Do NOT resume wf_f28d7d12-1cd / wf_bfb12095-952 / wf_1245a178-eaf or any prior run id.
