# Session 2026-07-20-03 — journal-app-design

## Where it started
Resumed paused thread at 21/31 to plan batch 3. User then reframed the goal: complete the ENTIRE app in AS
FEW mitosis flows as possible, questioning why runs were scoped to 1-2 MSPs. This session pivoted from
"another small batch" to staging ONE final all-remaining-units run.

## What shipped
- **batch 3 launched + landed (partial): 23/31.** Ran wf_319dceb2-804 (human-gated, 102 agents, 0 errors,
  7.1M tokens, 5.7h). garden-screen (#22) and day-detail (#23) shipped and were merged BY THE USER (confirmed
  by the user; both also validated locally green — see Verification). today-screen and settings-screen PARKED
  at plan-review (3 non-converging iterations each). Manifest reuse fired; no Decompose.
- **Engine behavior verified (code-read, codebase-analyst).** The engine does FRONTIER-TRAIN BUILD-AHEAD: a
  dependent builds against its parents' checkpoint tips once they are `built`, WITHHOLDS its own PR until
  every parent is merged (`done`), and an in-run poll loop (6 cycles x <=300s, budget RESETS on each detected
  merge) watches `gh` for the merges — so if PRs are merged promptly, the whole app finishes in ONE run;
  otherwise it degrades to a cheap resume-relaunch. Never builds broken. Decision:
  decisions/2026-07-20-one-run-completion-frontier-train.md (line citations inside).
- **Plan-file overwrite rule verified.** A unit parked at plan-review resumes via a READ-ONLY probe
  (skipPlan=true) that preserves hand edits, then re-reviews. A FRESH unit (no park) RE-AUTHORS the plan,
  overwriting edits. Therefore today-screen/settings-screen MUST keep park state to preserve fixes.
- **FINAL 31-unit run.json STAGED and fold-verified.** .mitosis/run.json now = full 31-msp single-line base
  + 2 park deltas (today-screen, settings-screen @ plan-review). Path (ii) per the analyst. All 8 remaining
  units present: capture-photo/voice/video, today-screen, settings-screen, calendar-screen, search-screen,
  shell-nav-integration. today/settings parked@plan-review; the 5 pure-build units planned; shell-nav
  parked@null (propagation from its parked deps -> engine runs full fresh pipeline, functionally = planned).
  Added the missing feedback-motion-kit edge to settings-screen.dependsOn (resolves settings finding 2).
- **batch-tooling updated:** MERGED=23 (added garden-screen, day-detail), BATCH=8 (the remaining units),
  KEEP=31. Preserved park deltas saved at .mitosis/batch-tooling/parks/today-settings-parks.jsonl.
- **Plan-review findings recovered from the journal** (engine never persists them) and dispatched to two
  background implementer agents to FIX the two parked plans (status at session end: see Running state).
- **Two decision records written:** batch-3-scoping (superseded in spirit by the one-run decision but kept
  for the audit trail), one-run-completion-frontier-train.

## Tried and failed
- **My batch-3 scoping rationale was WRONG and the user caught it.** I excluded the 3 capture-* MSPs citing
  pubspec.yaml + GeneratedPluginRegistrant.swift contention. That is a MERGE-time constraint (each builds in
  its own worktree), not a build-time one — it required serial MERGES (which happen anyway), NOT a separate
  batch. The 1-2-MSP batching was an expired debugging control from the fold-defect era, not an engine limit.
- **The fold PROPAGATES parked status transitively through dependsOn.** A stale park delta for a MERGED unit
  (entry-cards, in the pristine backup) parked its dependents day-detail -> calendar/search -> shell-nav in
  the folded output. Fixed by dropping the stale entry-cards park delta from run.json; only today/settings
  parks remain (plus the unavoidable shell-nav@null propagation, which is benign).
- **CI still hollow for Dart** (unchanged): local fullValidationCmd remains the only real pre-merge gate.

## Verification
- `gh pr list --state merged` -> 23; `--state open` -> 0. main reconciled to `3b4f08f` then origin merges;
  `git rev-list --left-right --count origin/main...main` -> `0 0`.
- garden-screen: PR #22 MERGED by user; local `flutter analyze` clean + `flutter test` 444/444 at f207b90.
- day-detail: PR #23 head bf4c449 — local analyze clean + `flutter test` 476/476; scoped day_detail 32/32.
- `git branch -f msp/day-detail-integration` security warning INVESTIGATED = false alarm: earliest reflog
  entry is "branch: Created from origin/main" (no prior tip discarded). Same as batch 2 — confirmed twice.
- Final run.json fold: `fold-run-log.mjs` -> 31 msps, base parses as one line, logicalRunId `5385f00d` and
  specContentHash `ecebde3c...` unchanged, no dangling deps, parked = today-screen@plan-review,
  settings-screen@plan-review, shell-nav-integration@null. Pristine backup md5 `a7ca0a4f...` UNCHANGED.
- Symlink guard fix: 7/7 CLIs carry the realpath idiom AND are committed in .windful-ocean (only
  run-engine.mjs is dirty). fold CLI smoke test: 27567 bytes stdout, exit 0 (not a no-op).

## Running state
- Two background implementer agents editing the parked plans (dispatched ~end of session):
  - today-screen plan fix — SendMessage to `a059043b1cc896362`. Edits .mitosis/today-screen.plan.md
    (Self-Review S4 DAG rewrite + Task 4 repo-wide .g.dart guard + delete _labelFor).
  - settings-screen plan fix — SendMessage to `a79fdcd76a6f37334`. Edits .mitosis/settings-screen.plan.md
    (add `import 'package:flutter_riverpod/misc.dart';` to 6 test blocks + fix RED prose + acknowledge
    feedback-motion-kit).
  If still running at next session start, wait for completion or re-dispatch; then VERIFY the edits landed
  before launch. No shells, no workflows. wf_319dceb2-804 completed.

## Deferred + open
- **The final run has NOT been launched.** Everything is staged. Next session LAUNCHES it.
- Residual: adversarial plan-review may re-park with NEW findings even after the fixes; that is the one spot
  next session might need a fix-and-relaunch cycle. The blocking findings (today §4 DAG; settings Override
  import) are concrete and addressed; convergence is likely but not guaranteed.
- capture-* serial-merge discipline still applies: each of the 3 adds pub deps AND regenerates
  macos/Flutter/GeneratedPluginRegistrant.swift — merge one-at-a-time with `flutter pub get` regeneration.
- `.mitosis/` is gitignored: the staged run.json + batch-tooling exist ONLY on this machine.
- 3 files still carry the symlink guard defect (task chip task_ecab775c); the 7-CLI fix is committed but
  run-engine.mjs is dirty-uncommitted in .windful-ocean.

## Pick up here
Verify the two plan-fix agents' edits landed in .mitosis/{today-screen,settings-screen}.plan.md (re-dispatch
if incomplete). Run the three pre-flights (guard 7/7, fold CLI stdout non-empty on the staged run.json, main
0/0). Then launch the ONE final run with the verbatim 2026-07-11-03 block (mergePolicy "human-gated"). As
green PRs land, run fullValidationCmd locally against each head worktree and MERGE PROMPTLY (within the poll
window) so shell-nav-integration ships in the same run; capture-* merged one-at-a-time with regeneration.
Goal: 31/31 in one flow (worst case one cheap relaunch resume for shell-nav).
