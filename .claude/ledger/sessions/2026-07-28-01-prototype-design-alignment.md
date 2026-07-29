# Session 2026-07-28-01 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief flagged one stale claim: the thread said "nothing is needed before the dispatch", but a fetch showed `origin/main` at `73919a1` (PR #61, the session-08 ledger handoff) one commit ahead of local `main` at `b4c5634`. Reconciled first. User directed "Go. Think hard."

## What shipped
- **B1 `b1-panel-gradient-chrome`** — PR #62 `feat(window-chrome): paint panel wash and window title bar`, MERGED 2026-07-28T19:35:55Z. `main` is now `9a53222`. This is the ONLY MSP shipped across three dispatches.
- Local `main` reconciled twice: `b4c5634 -> 73919a1` before run 1, `73919a1 -> 9a53222` after #62 merged.
- Serena activated for this repo for the first time (project auto-named `fireplace` from the directory).
- `decisions/2026-07-28-mitosis-requires-serena-activation.md`, `decisions/2026-07-28-parked-ship-resumes-by-re-execution.md`.

Three mitosis dispatches on `docs/specs/2026-07-27-prototype-alignment-cluster-b.md`, all with `baseBranch` main and `sourcePrefix` `msp-cluster-b`:

| Run | Workflow id | Agents | Tokens | Wall | Outcome |
|---|---|---|---|---|---|
| 1 | `wf_8e873bff-4f1` | 88 | 6.51M | 17.8h | B1 shipped; B2 parked at `ship`; B3/B4 blocked |
| 2 | `wf_2a155c53-317` | 11 | 0.82M | 42m | B2 re-executed and halted at `execute`; nothing shipped |
| 3 | `wf_8567a217-c50` | 11 | 0.72M | 24m | B2 halted at `execute` on a stale-branch collision; nothing shipped |

**Run 3 completed after the hand-off was written.** It did NOT block on Serena — the blocking agent reported: `BLOCKED on workspace setup. No files changed, no commits, no mutations — the failed 'git worktree add' left nothing on disk. THE COLLISION: All three convergence branches in the dispatch instructions fail against actual repo state.` The task branch `msp-cluster-b/b2-rail-geometry-lockup/task-task-1` survived runs 1-2, so the worktree could not be created. **Cause: `sourcePrefix` was deliberately held at `msp-cluster-b` for manifest continuity while only `worktreeRoot` was rotated — which discards exactly the collision protection decisions/2026-07-27-source-prefix-is-run-distinct.md exists to provide.** The manifest-continuity reasoning was sound in isolation and wrong overall: a new slice spec gets a clean manifest AND a fresh prefix, satisfying both concerns. Serena's contribution is now untested — run 3 never reached semantic discovery.

## Tried and failed
- **Run 1 parked B2 on an "ambiguous frontier state"** — no `builtSha` was recorded when the unit was marked built, so the engine refused to ship an unverified frontier tip (`mitosis.js:4288`). Root cause found: `builtSha` comes from the checkpoint-push agent's return value (`:4598`), and that agent family was blocked by the harness safety classifier for authorizing an unconfirmed `git push --force-with-lease` fallback (`:4586`). The JSONL manifest shows `"sha":null` for ALL FOUR units including B1 — B1 shipped only because it had no unmerged parent and never took the strict `requireSha: true` frontier path (`:4306`).
- **My built-resume prediction was WRONG, and it cost a run.** I read `mitosis.js:4298` (the persisted built-resume path passes no `expectedSha`, so `:4284`'s guard is falsy) and predicted run 2 would restore B2 from its durable checkpoint and ship it. It did not. The engine re-entered `execute` and rebuilt B2 from scratch. **A park at `ship` is not cheap to resume — treat it as a full re-execute when budgeting.**
- **Run 2 halted with task-1 `BLOCKED`**, reason in the journal: `BLOCKED: needed=serena-activate_project (LSP call hierarchy unavailable — Serena reports 'No active project' and no activation tool is exposed) task=semantic discovery`. The implementer correctly refused to guess rather than silently producing work.
- **Run 2 raised a security warning** — `[branch:b2-rail-geometry-lockup]` ran `git reset --hard origin/main` on the b2 integration worktree without a visible clean-status check or authorization naming that target. Checked for damage and found none (see Verification); it hit a disposable integration worktree, not durable state.
- **Serena activation is only a PARTIAL fix and is unverified.** `activate_project` succeeded but reported `Programming languages: .` — empty. No language backend was detected for this Dart/Flutter repo, and `get_current_config` lists only `chinook-project` as a pre-existing project. Activation clears the literal `No active project` error; whether Dart semantic discovery now works is UNKNOWN. If run 3 blocks the same way, the fix is to stop requiring Serena semantic discovery on this repo, not to re-activate.
- **The user's "approve the tip as-is" instruction never took effect.** The engine exposes no approve input — its parser accepts only `{spec, repoRoot, baseBranch, sourcePrefix, verify, build, models, worktreeRoot, fixLoopMax, retry}` — so the only way to act on the approval was a re-dispatch, and the re-dispatch re-executed instead of shipping the approved tip. B2's approved artifact `97d91a8` is still unshipped.

## Verification
- `gh pr view 62` — **MERGED** 2026-07-28T19:35:55Z, mergedBy SatanshuMishra. Checks: `receipts` SUCCESS, `pr-title-lint` **SUCCESS**. The standing prediction that Cluster B would park red at `pr-title-lint` did NOT materialise.
- `git ls-remote origin 'refs/mitosis/55d6da7a/*'` after run 2 — all three durable checkpoints intact and unmoved: `b1 749ed67`, `b2 97d91a8`, `b3 54fd9ef`. B4 has NO checkpoint ref (its push was the classifier-blocked one).
- `git diff --stat 9a53222 97d91a8` — B2's approved work is `+21/-5` in `lib/app/shell/sidebar_shell.dart` only, inside the slice's 7-file fence. Content matches B2's spec: rail `248 -> 216`, padding `all(16) -> symmetric(v:22, h:16)`, `DashedDivider` given `thickness: 1.0` + `Palette.ink22` at the call site, peony bloom + two-line wordmark lockup.
- `git rev-parse main` / `origin/main` — both `9a53222` after the run-2 reset warning; working tree carried only the ledger edit. No durable loss.
- `.mitosis/run.json` is **JSONL** — 7 records, one JSON object per line. `JSON.parse` on the whole file throws at line 2. Backed up to `.mitosis/run.json.cluster-a.bak` before run 1.
- **NOT VERIFIED: no Dart ran this session.** `flutter analyze` and `flutter test` were never invoked. `fullValidationCmd` was not run against #62 before it merged, nor against `97d91a8`. Neither GitHub check runs a Dart test.

## Running state
- **Mitosis run 3 `wf_8567a217-c50` is IN FLIGHT at hand-off** (task id `w3tqro9pm`), dispatched deliberately to continue into the next session. Inputs: spec = the Cluster B slice, `baseBranch` main, `sourcePrefix` `msp-cluster-b`, `worktreeRoot` = `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-b-r3` (fresh; runs 1-2 used `.fireplace-worktrees-cluster-b`), `fixLoopMax` 2. Transcript: `/Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/841e88ee-e240-4322-af1e-5acd23701554/subagents/workflows/wf_8567a217-c50/journal.jsonl`. Read its outcome with `/workflows`, or fold `.mitosis/run.json`. To stop it: `TaskStop` on `w3tqro9pm`.

## Deferred + open
- **`sourcePrefix` and the manifest were deliberately NOT rotated for run 3**, against the usual run-distinct rule. Wiping `.mitosis/run.json` for a genuinely blank run would drop B1 from the shipped set (`mitosis.js:3696` folds shipped ids only for units already in the manifest) and re-execute already-merged work into a duplicate PR. Only `worktreeRoot` was rotated. A truly fresh run needs a NEW SLICE covering B2-B4 only — new spec path means a new `logicalRunId` and a clean manifest — which must be committed and landed on main before dispatch.
- **The checkpoint-push classifier block will recur on clusters C-H** until `mitosis.js:4586` stops authorizing an unconfirmed `--force-with-lease` fallback. It is an engine prompt defect; the block itself was correct.
- **B4 has no durable checkpoint** and its relaunch behavior is unpredictable — it may re-plan from scratch or park asking for a valid checkpoint ref.
- `.mitosis/run.json` being JSONL means the pretty-print warning in `decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md` does NOT describe this format. Do not "fix" a multi-line run.json.
- Standing and unchanged: `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` with the workflow token (chip `task_e10f4f7e`); A2/A4's app-wide blast radius never walked; the five A3 dialogs never separately opened; the A1 plan fix survives only in gitignored `.mitosis/a1-token-ladder.plan.md`; OQ-3 and OQ-6 open; the slice's ~40 inherited citations unverified beyond three spot-checks; CI is not evidence.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.

## Pick up here
Read run 3's outcome first — it was in flight at hand-off and is the only thing that can have changed. If it shipped B2-B4, validate each PR head locally with `fullValidationCmd` before merging (CI runs no Dart test) and Cluster C is next. If it blocked on Serena again, the fix is to stop requiring Serena semantic discovery on this Dart repo rather than re-activating. If it parked anywhere else, prefer cutting a fresh B2-B4 slice over a fourth re-dispatch of the same manifest — three runs have now cost ~7.4M subagent tokens for one shipped MSP.
