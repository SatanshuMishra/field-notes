# Session 2026-07-27-05 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief exposed two drifts: PR #52 had merged the thread's branch `chore/ledger-handoff-session-09` into main as `60dad72` (making that branch stale), and local main was one commit behind origin/main — load-bearing, because the engine cuts worktrees from the LOCAL ref. User directed "Approved. Go. Think hard."

## What shipped
- **A1 SHIPPED AND MERGED.** PR #53, merge commit `22ba7fe` on main. `lib/design/tokens/palette.dart`, `shapes.dart`, `shadows.dart` and `test/design/tokens/tokens_test.dart` carry the ink/coral alpha ladder, the radius ladder and the hard-shadow scale. Second MSP of this spec to land. A2, A4 and A5 are now unblocked.
- **A3 confirmed shipped without rework.** The engine's ship-stage done-oracle queried `gh pr view` for `msp-cluster-a/a3-dialog-material-host-integration`, found PR #51 MERGED, and returned `{merged: true}` without re-planning or re-implementing.
- **The A1 plan scope-guard fix**, in `.mitosis/a1-token-ladder.plan.md` (gitignored, local-only, NOT committed). Applied at four sites, not the one the ledger named — see "Tried and failed".
- `.claude/ledger/decisions/2026-07-27-mitosis-resume-contract.md`.

## Tried and failed
- **The ledger said "three changes, one step". The defect was in four places.** `decisions/2026-07-27-scope-guard-authorship-oracle.md` names Task 4 Step 4, but `MSP_BASE="$(git merge-base main HEAD)"` was re-derived in Step 5 as well, and "Revert that file to the MSP base" appeared as an autonomous instruction in Steps 1 and 3. Fixing only the named step would have left the identical defect one step later and very likely re-parked the plan. Final shape: a new Task 1 Step 0 captures `git rev-parse HEAD` into gitignored `.mitosis/a1-msp-base.sha` before the first edit; Steps 4 and 5 read that file and refuse to fall back to `merge-base`; every revert is gated behind explicit human confirmation; Step 5's restore now edits the file directly, since `git checkout` there would discard A1's own legitimate additive work.
- **First dispatch rejected at input validation in 24ms** — `missing or empty required fields: worktreeRoot`. Zero agents, zero tokens. Recovered the value `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a` from A3's existing worktree path.
- **A false alarm about reusing `sourcePrefix: msp-cluster-a`.** Four branches already lived under it, one (`msp-cluster-a/a3-dialog-material-host-integration`) checked out in a live worktree, which looked like the branch-reuse hazard of `decisions/2026-07-27-source-prefix-is-run-distinct.md`. Folding the run journal showed A3 resumes at `ship` and never cuts a worktree, so no collision was possible. The prefix was correctly kept. Investigating before dispatching was what avoided a needless new prefix and an A3 re-run.
- **A1 parked at `ship` on `pr-title-lint`** — title `mitosis: a1-token-ladder` fails the Conventional Commits grep. Identical to PR #51 and already ruled non-blocking in `decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md`. The substantive gates passed. The user merged #53 manually WITHOUT retitling, so main's history now carries a second non-conventional squash message.
- **One agent blocked by the safety classifier**: `[checkpoint-push:a1-token-ladder]` was instructed to fall back to `git push --force-with-lease`, matching the deny-listed `git push --force:*`. Blocked correctly. A1's push succeeded as a normal first-time push with no force; nothing was lost.

## Verification
- Anchor mechanism proved in a throwaway git repo before trusting it: with a pre-existing branch commit in place, the captured SHA returned only the MSP's own path, where `merge-base` would have swept in the prior commit.
- `gh pr diff 53 --name-only` — expected A1's four fileScope paths; observed exactly those four, on a branch that carried prior commits. **The scope guard held under the exact condition that broke it before.**
- `gh pr checks 53` — `receipts` pass (enforcer + D6 cluster-boundary tests), `pr-title-lint` fail. Only the metadata check was red.
- `gh pr view 53` — MERGED 2026-07-27T21:06:11Z, merge commit `22ba7fe`, base main.
- `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs .mitosis/run.json` (pre-dispatch) — a1 parked@plan-review, a3 parked@ship, a2/a4/a5 parked@none. This drove the dispatch args.
- `git fetch origin main:main` then `git rev-list --left-right --count main...origin/main` — `0 0` both before dispatch and after the #53 merge.
- `git ls-tree -r --name-only origin/main -- lib/design/tokens/` — the three token files present on main.
- **No Dart suite was run by the main thread this session.** Per `decisions/2026-07-20-ci-gates-are-hollow-for-dart.md`, the green `receipts` check is NOT evidence a Dart test ran. **A1 and A3 are both unvalidated locally on main.**

## Running state
none — workflow `wf_1543a2d6-49e` returned terminal (`partial`, 24 agents, 23 done, 1 blocked by the safety classifier, 1,396,674 subagent tokens, 4,858,567 ms).

## Deferred + open
- **Re-dispatch to run A2, A4 and A5.** They parked as "blocked by a parked prerequisite" and never planned. A1's merge clears that. Same args as this session's successful dispatch, including `worktreeRoot`.
- **A1 and A3 are unvalidated locally on main.** Run `fullValidationCmd` against main and hardware-confirm the five dialogs (completion criterion 4).
- **The A1 plan fix lives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** It is not committed and cannot be; the engine itself warns `.mitosis/` does not survive a fresh clone, new worktree, or CI workspace. If that file is lost, the fix is lost.
- A2 and A4 still carry app-wide blast radius and need a human pass over Calendar, Garden, Search, Day Detail and Settings.
- OQ-3 and OQ-6 remain open; neither touches Cluster A.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md for cap enforcement (file remains on disk, content unchanged): `decisions/2026-07-19-symlink-guard-defect.md` — all 7 `~/.claude/lib/superpowers-parallel` CLIs were symlinked and the guard failed to catch it; a resolved tooling defect.

## Pick up here
Re-dispatch mitosis to run A2, A4 and A5, now that A1 is on main. Fold `.mitosis/run.json` first and confirm the reconstructed stages before trusting this note. Confirm local `main` equals `origin/main` before dispatching. Args: spec `docs/specs/2026-07-27-prototype-alignment-cluster-a.md`, `baseBranch` main, `sourcePrefix` `msp-cluster-a`, `worktreeRoot` `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a`, plus `verify` from `receipts.config.json`. Expect A2/A4/A5 to park at `ship` on `pr-title-lint` exactly as A1 and A3 did.
