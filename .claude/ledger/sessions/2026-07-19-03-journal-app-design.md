# Session 2026-07-19-03 — journal-app-design

## Where it started
Resumed the paused thread at 18/31 with batch 2 fully staged and verified GO. The user directed
"Go" — launch batch 2 as the first major action per plans/2026-07-19-next-round.md Stage F3.

## What shipped
- **20/31 merged.** origin/main 326686a -> 81ee64b (#19 capture-core) -> 146751e (#20 entry-cards).
  `gh pr list --state open` EMPTY; `gh pr list --state merged` = 20.
  - #19 capture-core: 21 files, +1874/-0, 6 of 6 plan tasks, receipts + pr-title-lint green.
  - #20 entry-cards: 29 files, +2009/-0, receipts + pr-title-lint green. Stayed CLEAN after #19
    merged, as predicted (capture-core adds no pub deps).
- **FIRST LAUNCH KILLED, root-caused, and fixed — the session's main work.** See
  decisions/2026-07-19-symlink-guard-defect.md. All 7 CLIs under
  ~/.claude/lib/superpowers-parallel/ were SILENT NO-OPS (exit 0, zero bytes) because
  `~/.claude/lib` is a symlink and the guard `import.meta.url === \`file://${process.argv[1]}\``
  compares a realpath to a literal path. Fixed in all 7 with the realpath idiom
  (`pathToFileURL(realpathSync(process.argv[1])).href`). Files edited under
  /Users/satanshumishra/Documents/DevLabs/.windful-ocean/.claude/lib/superpowers-parallel/.
- **Relaunched (wf_1a14ffc9-038) and it behaved exactly as designed:** reuse fired, no Decompose,
  entry-cards skipped Plan and resumed at execute off the fixed .mitosis/entry-cards.plan.md.
- Ledger: decision record + PROJECT.md index line written mid-session (decision-time capture).

## Tried and failed
- **First launch wf_3e5d19af-086 — killed ~1 minute in, ZERO damage.** Not a mitosis defect: the
  Jul-18 refactor (commit 2ea2a0b) moved the manifest fold out of the engine into the broken CLI.
  Chain: empty stdout -> manifestRaw="" -> `parseRunManifest` returns null (recovery.mjs:72-73) ->
  isRelaunch false (mitosis.js:3561) -> fresh Decompose (mitosis.js:3647). The
  "not reusable — decomposing fresh" log is gated on isRelaunch and NEVER FIRES.
- **The plan's Stage G1 log assertion could NOT have caught this** — the engine logs nothing on that
  path. Only an out-of-band pre-flight of the CLI's actual stdout caught it. This is the single most
  important lesson of the session.
- **reminders PARKED at plan-review** — adversarial review did not converge after 3 iterations.
  Batch 2 therefore lands 20/31, not 21/31.
- One monitor false positive: an "ABORT-CHECK decompose-stage" alert fired on the word "decompose"
  appearing as boilerplate inside capture-core's *planning* prompt. Monitor regex was re-anchored on
  the stage role. No real abort condition ever tripped.

## Verification
- Pre-flight (the catch): `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs <run.json>` ->
  exit 0, **0 bytes**. Via its realpath -> 17127 bytes of valid JSON. No-arg probe of all 7 CLIs ->
  all `exit=0 bytes=0` (RED).
- Post-fix: all 7 exit non-zero with usage (GREEN). Fold -> 21 msps, logicalRunId 5385f00d,
  entry-cards resumePoint.stage == "execute", byte-identical via symlink and realpath.
  Import-safety harness: 14 dynamic imports across both path roots, 0 stray stdout/exit — the
  import-only consumers (route-planner, wave-planner, generate-run-script) do NOT execute main().
  Lib test suite: **829 pass / 0 fail**.
- Post-kill damage check: run.json still 2 lines, entry-cards plan present, no batch-2
  worktrees/branches, `git status --porcelain` clean.
- Relaunch G1: reconcile returned `manifestFound:true` with the real manifest; stages observed were
  reconcile -> prepare probe -> plan-artifact probe (entry-cards, "resumed run skips the Plan
  stage") -> parallelize+route; capture-core got a legitimate fresh Plan. No Decompose agent.
- **Both run failures investigated and cleared, not assumed:**
  - `[branch:capture-core]` SECURITY WARNING (`git branch -f` may discard commits): FALSE ALARM.
    `git reflog show msp/capture-core-integration` -> oldest entry `@{6} 326686a branch: Created
    from origin/main`, then 6 monotonic task merges. The branch did not exist (Stage F1 deleted it),
    so the -f WAS the creation and there was nothing to discard. origin/main is an ancestor.
  - `[checkpoint-push:capture-core]` force-with-lease: BLOCKED by the classifier, never executed;
    the ordinary push succeeded.
- entry-cards harness fix held: `entry_cards_harness.dart` added by exactly one commit (Task 2's);
  zero `entry_cards_harness` references in note_body_test; local `noteBodyHarness` present.
- Merges: `gh pr merge 19 --squash` -> MERGED; #20 re-checked MERGEABLE/CLEAN against the new main;
  `gh pr merge 20 --squash` -> MERGED.

## Running state
- none. Workflow wf_1a14ffc9-038 completed (75 agents, ~3.4h). Both monitors stopped. Resumable if
  needed: codebase-analyst a0e315cd957ab0675 (engine fold-path map), implementer a2ed7d38e88c093ff
  (the 7-CLI guard fix).

## Deferred + open
- **UNCOMMITTED: the 7-CLI guard fix is in the .windful-ocean working tree, deliberately not
  committed** (it is the user's global config repo — their call). Absolute path:
  /Users/satanshumishra/Documents/DevLabs/.windful-ocean/.claude/lib/superpowers-parallel/.
  If that tree is reverted or reset, EVERY future mitosis launch silently full-re-decomposes again.
- **3 more files carry the same defect** (swept, not fixed) — task chip task_ecab775c filed:
  .claude/hooks/block-inline-engine.mjs:36 (a BLOCKING hook, so it FAILS OPEN — the
  inline-engine/deep-research guard has not been running),
  .claude/skills/impeccable/scripts/critique-storage.mjs:229,
  .claude/skills/impeccable/scripts/cleanup-deprecated.mjs:270.
- **reminders**: parked at plan-review. Edit .mitosis/reminders.plan.md to address the adversarial
  review findings, then relaunch on the SAME run.json (do not re-trim mid-batch); it resumes at
  plan-review before Parallelize. Its pubspec adds (flutter_local_notifications + timezone) mean the
  union procedure still applies when it eventually merges onto a main that now has just_audio +
  video_player from entry-cards.
- Batch 3 candidates at 20/31: capture-photo, capture-voice, capture-video, today-screen, day-detail,
  garden-screen, settings-screen (+ reminders). Split 3-4 max per window; all three capture recorders
  add pub deps -> serial union merges.
- Local main is 15 ahead of the pre-merge origin/main and now BEHIND by the 2 new squashes —
  Stage B reconcile is mandatory before the next relaunch.

## Pick up here
Fresh session: `/resume-project journal-app-design`. Before ANY relaunch: (1) confirm the
.windful-ocean guard fix is still in the working tree, (2) run the fold pre-flight and assert
non-empty output with the expected msp count, (3) reconcile local main onto origin/main. Then fix
.mitosis/reminders.plan.md against its review findings and relaunch to land 21/31.
