# Session 2026-07-12-02 — journal-app-design

## Where it started
Resumed the paused thread (/resume-project journal-app-design); presented the Resumption Brief; user said "Go". Launched a fresh HUMAN-GATED mitosis run (wf_a1015521-c4c). It was killed on process exit before publishing anything. User challenged relaunching a multi-hour engine for code that was already built ("the work was done in the previous Workflow; just the PR failed"). Verified, agreed, pivoted to a direct main-thread ship.

## What shipped
- 3 second-layer foundations MERGED to origin/main via MAIN-THREAD push + PR + squash (no engine):
  - domain-models -> PR #5 -> squash d538920
  - flower-svg-set -> PR #6 -> squash 29b3849
  - sticker-widget-kit -> PR #7 -> squash 5e73d67
- origin/main advanced ef3e8c6 -> 5e73d67. 4/31 -> 7/31 shipped. Zero open PRs.
- decisions/2026-07-12-direct-ship-built-msps.md — direct main-thread ship of already-built MSPs (supersedes the "relaunch mitosis to ship the 3" plan; human-gated policy still governs Option B builds).
- Local main reconciled to origin/main by rebasing the local ledger commits on top (linear).

## Tried and failed
- Human-gated mitosis relaunch wf_a1015521-c4c: killed when the Claude Code process exited before publishing. Left no completion record; published nothing (0 open PRs, no new remote branches). The multi-hour engine relaunch was the wrong tool for already-built branches — this is the core lesson of the session.

## Verification
- Per-branch local verify (CI does NOT run flutter): `flutter pub get && dart run build_runner build && flutter test` — 81 / 59 / 65 passed, all "All tests passed!", worktrees clean (generated outputs gitignored).
- `gh pr checks {5,6,7}` — receipts SUCCESS + pr-title-lint SUCCESS on all three; mergeState CLEAN.
- `gh pr merge {5,6,7} --squash` — origin/main == 5e73d67; `gh pr list --state open` == [].
- Key finding: mitosis.js ship step (:2523-2569) injects NO receipt/claim/downgrade metadata — it only fetch->rebase-if-needed->push->pr create->watch->merge. So a direct push == mitosis's push; the receipts enforcer is satisfied by branch content (source + colocated tests), proven green on #5/#6/#7.
- All 3 branches were based on ef3e8c6 (clean fast-forward publish, no force); #6/#7 rebased onto origin/main after #5 merged (clean, disjoint file sets).

## Running state
- None. mitosis run wf_a1015521-c4c was killed on process exit (not resumable; do NOT resume it). No background shells or tasks live.

## Deferred + open
- OPTION B (fresh session): relaunch mitosis HUMAN-GATED to BUILD the ~24 unbuilt dependents against origin/main 5e73d67 — this is where the engine is genuinely needed (writing new code, not shipping built code). Merge each green PR from the main thread (authorized pattern), relaunch next layer, until 31/31.
- The 3 merged worktrees (.fireplace-worktrees/msp/{domain-models,flower-svg-set,sticker-widget-kit}/integration) are now STALE leftovers — safe to `git worktree remove` in Option B pre-flight (their PRs are MERGED; done-oracle skips them via `gh pr view`).
- After 31/31: Phase 8 (human toolchain install — full Xcode+CocoaPods + Android SDK — then local build/sideload).

## Pick up here
Fresh session -> Option B. Pre-flight (origin/main 5e73d67; local main synced; run.json intact; optionally prune the 3 merged worktrees). Relaunch mitosis with mergePolicy "human-gated" to build the next dependency layer; merge each green PR via `gh pr merge --squash`; repeat. Do NOT resume run wf_a1015521-c4c.
