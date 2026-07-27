# Session 2026-07-27-06 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The brief confirmed A1 (PR #53) and A3 (PR #51) merged, A2/A4/A5 parked at stage `none` as "blocked by a parked prerequisite" that A1's merge had cleared, and local `main` already equal to `origin/main`. One drift surfaced: the session-05 ledger commit `31e14e0` was pushed to `chore/ledger-handoff-session-10` but had NO PR and never merged. User directed "Go. Think hard."

## What shipped
- **CLUSTER A IS COMPLETE. All five MSPs are on main.** `main` advanced `22ba7fe -> 74477e7 (A4, #54) -> d58602d (A5, #55) -> 81039f3 (A2, #56)`.
  - A4 sticker primitives — PR #54, merged 23:14:38Z, `74477e7`. `lib/design/widgets/sticker_button.dart`, `sticker_card.dart` + both tests.
  - A5 cross-hatch geometry — PR #55, merged 23:15:17Z, `d58602d`. `lib/design/widgets/cross_hatch_placeholder.dart` + its test.
  - A2 typography roles — PR #56, merged 23:18:49Z, `81039f3`. `lib/design/tokens/typography.dart`, 7 lib retarget sites, `test/design/tokens/tokens_test.dart`.
  - A1 and A3 were replayed by the ship-stage done-oracle against their already-merged PRs — no re-plan, no re-implement.
- Run `wf_0f8cd32e-818` returned `partial`: 64 agents, 64 done, 0 errors, 4,392,647 subagent tokens, 1,120 tool calls, 6,040,581 ms (101 min).
- `.claude/ledger/decisions/2026-07-27-ship-stage-ci-wait-portability.md`.
- The session-05 ledger commit `31e14e0` was carried forward by cherry-pick onto current main as `a2fbfc2` (a rebase would have required a force-push of a pushed branch).

## Tried and failed
- **`partial` overstates the damage.** All three new MSPs parked at `ship`, and every park was `pr-title-lint` ONLY. On all three, job `receipts` was green including both `shaheershoaib/receipts/enforcer@main` and the D6 cluster-boundary step. Zero code or boundary failures across the run.
- **A SECURITY WARNING on the a5 agent was a FALSE POSITIVE.** The harness flagged `git branch -f msp-cluster-a/a5-cross-hatch-geometry-integration origin/main` as force-moving an existing ref and discarding commits. `git reflog show` on that branch returns three entries, the oldest being `@{2}: branch: Created from origin/main` — the `-f` CREATED the branch, which had no prior history; `@{1}` and `@{0}` are the two task merges that built the MSP. Nothing was discarded. Verify a destruction claim against the reflog before acting on it.
- **The a2 agent asserted PRs #54 and #55 "were merged by a human anyway."** No human input had reached the conversation, so the claim was treated as unverified and checked against `gh pr list`: both were genuinely MERGED, out-of-band on GitHub while the workflow was still running. The claim was true, but it was only knowable by checking.
- **Deliberately did NOT inject the scope-guard pattern into the spec.** `decisions/2026-07-27-scope-guard-authorship-oracle.md` calls the captured-SHA guard the standing pattern, and the mitosis arg contract has no free-form constraints field, so the spec was the only injection point. Editing it would have changed `specContentHash` (`2e3d414c...`), which binds the resume record per `decisions/2026-07-27-cluster-a-scoped-spec.md`, orphaning `.mitosis/run.json` and forcing a full re-decompose that would have lost the a1/a3 merged-PR short-circuit. The guard is documented as correct in a clean per-MSP worktree cut from main, and A2/A4/A5 had no pre-existing branches under the prefix, so the hazard could not bite. No MSP parked at plan-review this run.
- **`timeout` is absent on darwin and three agents have now hit it** (a3 in session 05, a2 and a5 this session). The engine's prescribed CI wait `timeout 1800 ...` exits 127 instantly with an empty conclusion. Every agent caught it via the exit code and re-ran a bounded `until` poll, but an agent that did not check would report a completed wait and read a non-terminal CI conclusion. Recorded as a decision.

## Verification
- `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs .mitosis/run.json` (pre-dispatch) — reconstructed a1 -> `ship`, a3 -> `ship`, a2/a4/a5 -> `null`; spec/baseBranch/sourcePrefix in the journal matched the dispatch args. This drove the dispatch, not the ledger note.
- `git fetch origin main:main` then `git rev-list --left-right --count main...origin/main` — `0 0` immediately before dispatch (the engine cuts worktrees from the LOCAL ref).
- `gh pr diff 54|55|56 --name-only` — each returned EXACTLY its declared `fileScope` (4, 2 and 9 paths). The scope guard held on all three.
- `git grep -n eyebrowAccent main -- lib/ test/` (run while #56 was still open) — 9 hits, ALL 9 inside A2's 9-file fileScope. A4 and A5 introduced no new consumer, so A2's removal of the token could not strand a dangling reference on the advanced base.
- `git reflog show msp-cluster-a/a5-cross-hatch-geometry-integration` — `@{2}` is `branch: Created from origin/main`; the security warning is a false positive.
- `gh pr list --state all` — #51, #53, #54, #55, #56 all MERGED; timestamps 19:23:05Z / 21:06:11Z / 23:14:38Z / 23:15:17Z / 23:18:49Z.
- `git log --oneline -4 origin/main` — tip `81039f3 mitosis: a2-typography-roles (#56)`.
- **No Dart suite was run by the main thread this session.** Per `decisions/2026-07-20-ci-gates-are-hollow-for-dart.md` a green `receipts` check is NOT evidence a Dart test ran. **All five Cluster A MSPs are unvalidated locally.**

## Running state
none — workflow `wf_0f8cd32e-818` terminal (`partial`). No background shells.

## Deferred + open
- **Run `fullValidationCmd` against main at `81039f3`.** This is now the single highest-value open item: five MSPs, zero local validation. The repo-root working tree is the wrong surface while a ledger branch is checked out; use a worktree pinned to `81039f3`.
- **Human pass over Calendar, Garden, Search, Day Detail and Settings.** A2 retuned `captionSans` to w400 (33 consumers), `bodySerif` 16 -> 13.5 (9 consumers) and `displaySerif` to w500/1.0; A4 stripped the shadow from 20 secondary `StickerButton` sites. No later MSP revisits those screens.
- **`pr-title-lint` needs a durable fix, not per-PR retitling.** The lint arrived in `7e47cd3`, which predates the first mitosis merge, so it has failed EVERY mitosis PR; main's history now carries five non-conventional squash messages (#51, #53, #54, #55, #56). Two candidate fixes: add `mitosis` to the allowed type alternation in `.github/workflows/receipts.yml:26-30`, or change the engine's title template. Neither was chosen this session.
- **A1/A4/A5 were never validated against each other's merged state.** Each PR's CI computed against base `22ba7fe`; A4 and A5 merged 39 seconds apart and A2 four minutes later. File scopes do not overlap, but no run tested the combined tree.
- Cluster A is 5 of the parent spec's 39 MSPs. Clusters B-H each need their own execution slice cut from `docs/specs/2026-07-26-prototype-design-alignment.md`.
- **The A1 plan fix still lives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** Not committed, not committable; `.mitosis/` does not survive a fresh clone or new worktree.
- OQ-3 and OQ-6 remain open; neither touches Cluster A.
- **WIP:** `post-ship-hardening` remains paused and unrelated. Surfaced for disposition, not auto-closed.
- Demoted from PROJECT.md for cap enforcement (file remains on disk, content unchanged): the engine-era pointer line (2026-07-19-next-round plan, sessions 2026-07-19-02 / 2026-07-16-02 / 2026-07-11-03) — folded into the adjacent demoted-pointers line.

## Pick up here
Cluster A is done shipping and needs proving. Run `fullValidationCmd` against `81039f3` from a worktree pinned to that SHA, then hardware-confirm the five dialogs (A3) and the token/typography/sticker surfaces (A1/A2/A4/A5) on macOS. Decide the `pr-title-lint` durable fix before cutting the Cluster B slice, so the next run does not park all of its MSPs for the same reason.
