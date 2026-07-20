# Session 2026-07-20-01 — journal-app-design

## Where it started
Resumed the paused thread at 20/31 with reminders parked at plan-review. User directed: commit/push/merge all
completed MSPs with main, then proceed as recommended with the remaining implementation.

## What shipped
- **Main reconciled and pushed.** No MSPs needed merging — `gh pr list` showed 20 merged, 0 open. The real work
  was reconciliation: rebased 18 local ledger-only commits onto origin/main, pushed `146751e..153e7eb`.
  Local main now 0 ahead / 0 behind, tree clean.
- **All three pre-flight checks GREEN.** Guard fix present (7/7 CLIs carry `realpathSync`); fold CLI returns
  18206 bytes, logicalRunId 5385f00d, 21 msps; main reconciled.
- **Relaunch proven SAFE before launching.** 17 of 21 msps fold to `status='planned'` despite being merged,
  which looked like a relaunch would rebuild 17 shipped MSPs. It will not: skip/build is decided by a LIVE
  `gh pr list --state merged` reconcile (mitosis.js:3491), matched via `branchToMspId` (recovery.mjs:14-22),
  and the skip fires at the TOP of `runUnit()` (mitosis.js:4081-4086) before any resume state is read. Stale
  `status` fields are inert. entry-cards' stale `resumePoint.stage='execute'` is dead data — it is skipped,
  not resumed. Manifest reuse confirmed: recorded `specContentHash` matches a fresh shasum of the spec.
- **The lost plan-review findings were RECOVERED.** The engine never persists review output to disk — the park
  record only references findings it does not store. All 3 iterations recovered from
  `~/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/43fad5be-4a41-4f3d-82d2-0433f90d985a/subagents/workflows/wf_1a14ffc9-038/journal.jsonl`
  (review agents a91e88a4bc11bef4c, a3813bc6f990ace4c, a4a9aea165ab33143).
- **Orchestrator ruling: reminders' fileScope expanded by exactly one file** — `android/app/build.gradle.kts`.
  See decisions/2026-07-20-reminders-android-desugaring-scope.md.
- **.mitosis/reminders.plan.md rewritten against the surviving findings** (now 1372 lines, 7 tasks). New Task 2
  (Enable Android core-library desugaring) with the complete resulting Gradle file; Task 4/5 rewritten for the
  single-flight `Future<void>? _ready` latch and a serialized last-wins `ReminderCoordinator.sync`; gate count
  21 -> 23 tests.

## Tried and failed
- **`flutter build apk` is IMPOSSIBLE here — no Android SDK on this machine.** `flutter doctor` reports
  "Unable to locate Android SDK"; ANDROID_HOME/ANDROID_SDK_ROOT unset; nothing at ~/Library/Android/sdk,
  ~/Android/Sdk, /usr/local/share/android-sdk, /opt/homebrew/share/android-sdk. This is consistent with the
  known Phase 8 human toolchain task, not a new anomaly.
- **The review's severity framing was wrong and was corrected.** It called the desugaring gap "a regression to
  a currently-buildable target"; Android is not buildable here at all. The accurate claim now in the plan: the
  repo's Android config is wrong for any toolchain-equipped machine, the fix is correct and ships, and it is
  unverifiable by execution in this environment.
- **`receipts.config.json` will NOT gain an Android build** — it would fail instantly for lack of an SDK and
  break every gate for every MSP. File-content assertion is the strongest verification available here.
- **The run was NOT launched.** Context reached 80% as the plan landed; per the project's own fresh-context
  discipline (session 2026-07-11-03 held Run 8 back at ~72%), launching a ~3h/75-agent run at low context
  risks stranding it mid-flight before the union-merge. User chose hand-off over launching.
- A cwd drift into `.mitosis/` from an earlier `cd` made two ledger pointers appear missing. False alarm —
  both files exist. Use absolute paths.

## Verification
- `git rev-list --left-right --count origin/main...HEAD` -> `0  0`; `git status --porcelain` -> clean.
- `gh pr list --state open` -> EMPTY; `--state merged` -> 20.
- `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs .mitosis/run.json` -> exit 0, 18206 bytes,
  21 msps, reminders `resumePoint.stage == "plan-review"`.
- `grep -rn "desugar\|multiDex\|coreLibrary" android/` -> NO hits (gap confirmed real).
- `grep -rn "build apk\|build appbundle\|gradlew" .github/workflows/ receipts.config.json` -> NO hits
  (CI genuinely cannot catch it).
- AGP 9.0.1 (android/settings.gradle.kts) and Gradle 9.1.0 — both ABOVE the plugin's 8.11.1 floor, so no
  version bump is needed; only the config is missing.
- No MSP declares `android/app/build.gradle.kts` — platform-permissions owns only AndroidManifest.xml and the
  macOS plist/entitlements. Zero collision for the scope grant.
- Engine read: `fileScope` from run.json reaches an agent ONLY via `planGroundTruthSeed` (mitosis.js:4189),
  inside the fresh-Plan branch that a `skipPlan` resume does not execute. `planReviewPrompt` (:3131) instructs
  the reviewer to "Read the plan at: ${planPath}" — disk is read fresh each iteration, no cache. The hard
  scope fence exists only for `isolation:'scope-fence'`, and Parallelize hardcodes `'worktree'` (:4266, :4327).

## Running state
- none. All subagents completed: codebase-analyst aa114ca66534e2d51 (engine semantics), general-purpose
  a18f3509082cae14e (findings recovery), implementer a22f2412d66e0ae4c (plan rewrite). No shells, no workflows.

## Deferred + open
- **LAUNCH NOT DONE — this is the next action.** Launch block is in sessions/2026-07-11-03 lines 38-62, with
  ONE change: `mergePolicy: "human-gated"` (NOT "autonomous", per decisions/2026-07-12-human-gated-merge-policy.md).
- 16 stale worktrees from merged MSPs remain on disk (user chose to leave them). They are for units the engine
  skips before any worktree is read, so they cannot affect a reminders-only run. Cleanup is destructive and
  needs explicit consent; do it between runs, never mid-run.
- run.json under-records reality: no `ship` deltas were ever appended for core-providers/capture-core/entry-cards
  though all are merged. Safe to append after the next run for self-consistency. Do NOT hand-edit the base line
  before a launch — it must stay valid single-line JSON or all 21 units silently full-re-decompose.
- `.mitosis/batch-tooling/` MERGED set is still 18; must become 20 before batch 3, or trim_manifest.py fires
  `FATAL: dependsOn -> removed id` on any new MSP depending on capture-core/entry-cards. verify_manifest.js
  currently MISREPORTS those two as "will BUILD" — do not trust its preview over the live engine.
- The engine never persists plan-review findings. If `~/.claude/projects` is pruned, parked findings are lost.
  A small high-value engine change would be writing `reviewOutcome.value` to `.mitosis/<msp>.plan.review.json`.
- 3 files still carry the symlink guard defect (task chip task_ecab775c), incl. hooks/block-inline-engine.mjs
  which FAILS OPEN. The 7-CLI fix remains UNCOMMITTED in the .windful-ocean working tree.
- Batch 3 candidates after reminders: capture-photo, capture-voice, capture-video, today-screen, day-detail,
  garden-screen, settings-screen. All three recorders add pub deps -> serial union merges.

## Pick up here
Everything is staged and verified; the launch is a single Workflow call. Re-run the fold pre-flight (it is
cheap and it is the only check that catches a silent no-op), confirm main is still 0/0, then launch with the
2026-07-11-03 block using `mergePolicy: "human-gated"`. reminders resumes at plan-review and re-reads the
edited plan from disk. On a green PR, apply the pubspec union procedure (main now carries just_audio +
video_player; reminders adds flutter_local_notifications + timezone), then merge from the main thread to reach 21/31.
