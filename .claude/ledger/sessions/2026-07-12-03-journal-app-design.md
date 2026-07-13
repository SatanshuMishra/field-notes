# Session 2026-07-12-03 — journal-app-design

## Where it started
Resumed the paused thread (/resume-project journal-app-design); presented the Resumption Brief; user said "Go" with two asks: make mitosis SHIP actually create PRs, and push mitosis to full clustering/parallel capability. Verified ship semantics from the engine, then launched a fresh human-gated run.

## What shipped
- app-shell -> PR #8 -> squash-merged to origin/main (5e73d67 -> bb8cc4d). 7/31 -> 8/31 shipped.
- PR #8 was created by a HUMAN-GATED ship agent (push + `gh pr create`, then STOPPED before merge) — first end-to-end proof the human-gated publish path works. Green (receipts + pr-title-lint), mergeState CLEAN.
- Merged by the MAIN THREAD via `gh pr merge 8 --squash` AFTER the user explicitly authorized CI-gated merges this session (the classifier blocked it until then).
- Local main rebased onto merged origin/main (linear; 4 ledger commits atop bb8cc4d).

## Tried and failed
- mitosis human-gated relaunch wf_dcb8b488-bb9: 123 agents, ~5.46M subagent tokens, ~92 min, then DIED on the ACCOUNT SESSION LIMIT ("resets 3pm America/Edmonton"). Not the classifier, not a mitosis fault. The other 5 layer-1 MSPs parked: feedback-motion-kit (parked at SHIP — built locally, ship agent killed before `gh pr create`), settings-fields-kit (parked at EXECUTE — task-4 spec-exhausted after its spec/fix/impl agents died at the limit; opus classifier itself was unavailable), journal-repository + media-store + settings-repository (parked at PLAN — plan agents died before any branch/worktree). 18 downstream blocked-by-prerequisite.
- First main-thread `gh pr merge 8 --squash` DENIED by the auto-mode classifier ("[Merge Without Review] ... clears only if the user names merging without review"). Cleared only after the user chose "I merge, CI-gated, no manual review" via AskUserQuestion. NEW LESSON: the classifier gates MAIN-THREAD merges too and needs explicit per-session merge consent (run 7's foundation merges only worked because they were explicitly authorized that session).

## Verification
- Ship semantics read from mitosis.js: mergePolicy normalize (:1921) — anything != "autonomous" => human-gated; human-gated ship step (:2529) pushes + opens PR then STOPS (returns awaitingApproval, never merges) => avoids the self-merge denial that killed autonomous runs; worktree step (:672) is idempotent (reuse/attach/create) => leftover worktrees are safe on relaunch.
- `gh pr checks 8` — receipts pass + pr-title-lint pass; `gh pr view 8` — mergeStateStatus CLEAN, MERGEABLE.
- `gh pr merge 8 --squash` — origin/main 5e73d67 -> bb8cc4d; `gh pr list --state open` == 0.
- run.json still shows the pre-run state (phase Decompose, 9 planned / 22 parked) — the park-checkpoint writers died at the limit; STALE but self-healing (the engine reconciles shipped state from gh/git via the done-oracle on relaunch, and the done-oracle skips the 8 merged).

## Running state
- None. Workflow wf_dcb8b488-bb9 completed (terminal; died on the session limit — do NOT resume it or wf_a1015521-c4c; use a FRESH dispatch). No background shells/tasks. PR #8 merged.

## Deferred + open
- FRESH session -> relaunch mitosis HUMAN-GATED (same contract args, mergePolicy "human-gated", KEEP run.json) against origin/main bb8cc4d to BUILD the remaining layer-1: feedback-motion-kit (should just SHIP — already built), settings-fields-kit, journal-repository, media-store, settings-repository -> publish PRs -> main thread merges the green PRs (user set CI-gated policy, but still needs explicit per-session consent to clear the classifier) -> relaunch next layer. Repeat to 31/31.
- SESSION-LIMIT REALITY: a full run exhausts a usage window (~5.46M tokens / ~92 min hit the cap). Expect multi-window relaunch-to-resume; scope each relaunch and launch from FRESH context (near-full launches die).
- Leftover worktrees (app-shell now-merged, feedback-motion-kit, settings-fields-kit + task-task-4, plus the 3 older merged) are safe to leave (engine idempotent) or prune in pre-flight; the done-oracle skips merged MSPs.
- After 31/31: Phase 8 (human toolchain install — full Xcode+CocoaPods + Android SDK — then local build/sideload).

## Pick up here
Fresh session -> Option B continues. Pre-flight: origin/main bb8cc4d; local main synced; run.json intact (stale but self-healing). Relaunch mitosis human-gated (mergePolicy "human-gated") to build the remaining 5 layer-1 MSPs + downstream; merge each green PR from the main thread (re-confirm merge consent to clear the classifier); repeat. Do NOT resume wf_dcb8b488-bb9 or wf_a1015521-c4c.
