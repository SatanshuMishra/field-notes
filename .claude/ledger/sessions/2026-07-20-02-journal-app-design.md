# Session 2026-07-20-02 — journal-app-design

## Where it started
Resumed the paused thread at 20/31 with the reminders relaunch fully staged but unlaunched. User said "Go".

## What shipped
- **reminders MERGED — 21/31.** Ran the staged relaunch as `wf_00757aaa-c12` (human-gated, 34 agents, 0 errors,
  9.1h, 1.67M subagent tokens). PR #21 squash-merged as `d01a23b` after explicit user consent.
- **Manifest reuse confirmed live.** No Decompose agent spawned; the first agent was the read-only reconcile
  stage. `.mitosis/run.json` stayed byte-identical (18258 bytes, mtime Jul 19 23:53). The symlink/fold defect
  did not recur. 20 units skipped by the live merged-PR reconcile; only reminders built, resuming at
  plan-review off the rewritten plan and completing all 7 tasks with per-task TDD evidence.
- **The pubspec union procedure was NOT needed.** The branch was cut from a fully reconciled main, so GitHub
  reported MERGEABLE/CLEAN. Last session's reconciliation is what bought that.
- **Three decision records written:** ci-gates-are-hollow-for-dart, reminders-day2-prearm-followup,
  keep-stale-worktrees.
- **origin remote repointed** to `https://github.com/SatanshuMishra/field-notes.git` (was still the old
  `fireplace.git`, working only via a 301). Supersedes the "repoint was denied" note in
  decisions/2026-07-10-mitosis-run-contract.md.
- **batch-tooling primed for batch 3** (delegated to mechanical-editor): MERGED bumped 18 -> 21 in both
  `trim_manifest.py` and `verify_manifest.js`; `BATCH` emptied to `[]`. NOTE: `.mitosis/` is gitignored, so
  this fix exists ONLY on this machine and is not recoverable from the repo.
- **Ledger renamed to Field Notes.** User correction: the project is field-notes, never "fireplace" — every
  fireplace on disk is a legacy path. Also stored as a memory at
  `~/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/memory/project-is-named-field-notes.md`.

## Tried and failed
- **Both CI checks are hollow — neither runs a Dart test.** `receipts` = 15s ubuntu + setup-node, no Flutter
  toolchain. D6 logged `dependents not computed (no supported import grapher for this stack (detected:
  unknown))`, so `d6Pass: true` is vacuous and has been for all 21 merged MSPs. Caught by inspecting the run
  log rather than trusting the green check. Local validation is now the standing pre-merge gate.
- **The plan's own instruction was violated and it shipped anyway.** `macos/Flutter/GeneratedPluginRegistrant.swift`
  was in the diff despite the plan ordering it reverted as generated noise. Content is byte-identical to what
  `flutter pub get` regenerates, so it was harmless — but it is now a SECOND systemic conflict file alongside
  `pubspec.yaml`, because capture-photo/voice/video all add plugins and will all rewrite it.
- **Worktree cleanup was proposed and declined.** User keeps all ~24 for manual testing post-deploy. Recorded
  so it is not raised again.

## Verification
- `gh pr view 21` — `state=MERGED mergedAt=2026-07-20T16:34:23Z`; `gh pr list --state open` -> 0; merged -> 21.
- Local `fullValidationCmd` at PR head `78bdb6b` in the integration worktree — `flutter analyze` "No issues
  found! (ran in 1.6s)"; `flutter test` `00:12 +405: All tests passed!`; `test/features/reminders`
  `00:00 +23: All tests passed!` (matches the plan's expected 23, incl. the serialize/supersede concurrency
  cases). Exit code 0.
- `git rev-list --left-right --count origin/main...main` -> `0  0`; tree clean; `main` at `db3dfbe`.
- `grep -c coreLibraryDesugaring android/app/build.gradle.kts` -> 1 (desugaring config on main). NEVER
  COMPILED — no Android SDK on this machine; file-content assertion is the only receipt.
- batch-tooling re-verified independently of the subagent's claim: `python3 ast.parse` OK, `node --check` OK,
  21 ids in each MERGED collection, `BATCH` empty.
- `git remote -v` -> field-notes.git; `git push` -> "Everything up-to-date" with no redirect warning.

## Running state
- none. Workflow wf_00757aaa-c12 completed; background shell btadf1vrf completed (exit 0); subagent
  aa26556565db7b267 (mechanical-editor) returned. No shells, no workflows, no agents.

## Deferred + open
- **Batch 3 is the next run.** 10 unbuilt dependents: capture-photo, capture-voice, capture-video,
  today-screen, day-detail, garden-screen, settings-screen (+3). Plus the reminders day-2 pre-arm follow-up.
  Fill `BATCH` in trim_manifest.py, trim from the pristine backup, then launch with the 2026-07-11-03 block.
- All three capture-* MSPs add pub deps AND regenerate the macOS plugin registrant — serial merges with
  regeneration for BOTH files, never hand-resolve.
- The engine still never persists plan-review findings; `.mitosis/<msp>.plan.review.json` remains the
  suggested small engine fix.
- 3 files still carry the symlink guard defect (task chip task_ecab775c), incl. a hook that FAILS OPEN. The
  7-CLI fix remains UNCOMMITTED in /Users/satanshumishra/Documents/DevLabs/.windful-ocean.
- run.json still under-records ship deltas for core-providers/capture-core/entry-cards/reminders. Inert; do
  not hand-edit the base line.

## Pick up here
Plan batch 3: choose its MSPs from the 10 remaining dependents, fill `BATCH` in
.mitosis/batch-tooling/trim_manifest.py, trim from the pristine backup, run the three pre-flight checks, then
launch the 2026-07-11-03 block with `mergePolicy: "human-gated"`. Merge each green PR only after running
fullValidationCmd locally against its head worktree — CI cannot tell you the code works.
