# Session 2026-07-26-02 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. The brief's step 1 was already done by the human: PR #46 (session-07
handoff, carrying the spec's Phase 2 Option B amendment) had merged at 06:50 as origin/main 397a5db.
Strand-check clean. The user's "Go" authorized the documented next step: ff local main, dispatch MSP 3.

## What shipped
- MSP 3 (day-detail-feed-virtualization) SHIPPED: PR #47, squashed to main as 096b3c3
  `feat(day-detail): virtualize the day-detail feed with a bounded shrink-wrapping list`.
  2 files, +63 -18: lib/features/day_detail/day_detail_panel.dart + its widget test.
- Verified at main, not just claimed: `shrinkWrap: true` (:142) with itemCount (:144) / itemBuilder
  (:153), and the outer `SingleChildScrollView` is GONE. Option B shipped exactly as ruled.
- Local main fast-forwarded twice: 1f77653 -> 397a5db (pre-dispatch), then -> 096b3c3 (post-merge).
- HUMAN HARDWARE CONFIRMATION obtained this session: the user ran manual testing and reported
  everything working as expected. This is the macOS run four thread criteria demanded and that had
  never happened across the whole thread. The thread's "merged-but-unconfirmed" hazard is now retired.

## Tried and failed
- Mitosis run 1 (wf_df4928ad-d4d) PARKED at stage `branch`, 603k subagent tokens, zero work done.
  Cause was pure infrastructure: the Bash safety classifier (claude-sonnet-5[1m]) was down, so every
  `git fetch` / `git branch -f` was refused ~10 times, including with the sandbox explicitly disabled.
  The agent reported honestly rather than guessing. The follow-up park-checkpoint write then hit the
  weekly usage limit, so NO park record ever persisted to .mitosis/run.json.
- Resume-by-runId was considered and REJECTED: the branch agent COMPLETED (returning a failure report),
  so the harness would replay that cached failure verbatim. A fresh relaunch was the only retry path.
- Mitosis run 2 (wf_5fafad3b-e35, 1.11M subagent tokens) reached `ship` and reported overallStatus
  `failed` — a STALE verdict. It reflects CI red at poll time; receipts and D6 both passed and only
  `pr-title-lint` failed. The user retitled and merged, which the engine never saw.

## Verification
- `gh pr view 47 --json state,mergedAt,title` — state MERGED, mergedAt 2026-07-26T23:07:48Z, and the
  title had been human-corrected to Conventional Commits before merge.
- `gh run view 30224493779 --json jobs` — receipts=success, pr-title-lint=failure. Only the lint.
- `git diff --stat 397a5db origin/main` — 2 files, +63 -18, exactly the declared fileScope.
- `git diff --stat origin/main 21d3e41` — EMPTY. Nothing stranded by the squash (the standing check
  from decisions/2026-07-25-verify-squash-against-remote-tip.md).
- `git show main:lib/features/day_detail/day_detail_panel.dart | grep shrinkWrap` — confirmed at main.
  NOTE: an earlier grep of the working tree read the OLD file, because the repo is checked out on
  chore/ledger-handoff-session-07, not main. Always `git show main:<path>` here, never a bare grep.
- Pre-relaunch integrity check of the run-1 artifacts (the safety classifier was down when the
  parallelize agent's work was reviewed, so its output was NOT trusted blind): the graph was one task
  scoped to the two in-scope files, and the re-authored plan pinned `shrinkWrap: true` as mandatory,
  citing the Option B decision record and spec :110. Only then was run 2 dispatched.

## Running state
- none. Both workflows completed; no background shells.

## Deferred + open
- NEXT SESSION'S ASSIGNMENT (user's explicit ask): explain what MSP 4 / Phase 3 Today-feed
  virtualization IS and why it was NOT authorized despite being planned in the spec. Everything
  needed is in the spec — read ONLY these lines, do not re-derive:
  - `:112` Phase 3 header, literally "(CONDITIONAL — do not execute on prediction)"
  - `:128-131` the two authorization preconditions: a post-Phase-1 profile on real hardware showing a
    scroll/widget-count problem still worth solving, AND review by the spec owner. Explicitly must not
    execute on prediction.
  - `:135` the load-bearing reason: virtualization does NOT make "only visible cards decode" true —
    Flutter's ~250px cacheExtent keeps ~3-4 of the ~500px cards alive anyway, already under the 6-slot
    cap. Phase 1 (poster-first) was the root fix; Phase 3 is scroll optimization layered on top.
  - `:159` + `:110` shrinkWrap stays REJECTED for the Today feed: it has no bounded ancestor, so MSP 3's
    Option B trick does NOT transfer. Phase 3 needs a genuine sliver conversion — a bigger, riskier diff.
  - `:133` orthogonal risk: there is NO pagination beneath either feed (EntriesDao, entries_dao.dart:70-90
    streams every row). Pagination may beat virtualization; whoever executes Phase 3 must record that
    choice explicitly rather than silently picking one.
  - `:137-138` acceptance criteria if it is ever authorized; `:152` its fileScope
    (lib/features/today/today_screen.dart, today_layout.dart, possibly entries_dao.dart).
- MSP 3 was never validated locally: `fullValidationCmd` was NOT run against the PR head. The receipts
  job claimed success including the G9 full suite, but decisions/2026-07-20-ci-gates-are-hollow-for-dart.md
  says never to accept that as Dart evidence. That record predates the current receipts.config.json,
  which now does carry real flutter commands — so the record may be STALE. Unresolved either way; the
  user's manual pass covers user-visible behavior, not the automated suite.
- pr-title-lint will fail on EVERY future mitosis PR in this repo (promoted to a PROJECT.md constraint).
- Sibling thread post-ship-hardening still paused: integration-test junk blob, export ZIP extensions.
- Voice cards remain unswept twins; video_body.dart controller extraction still out of scope.

## Pick up here
Answer the MSP 4 question from the spec line pointers above — it is an explainer, not an execution
task, and Phase 3 remains unauthorized until a profile is taken and reviewed. Do not dispatch mitosis.

## Demoted from PROJECT.md (80-line cap)
Demoted verbatim to make room for the pr-title-lint constraint. Historical; both SHAs are stale (main
is now 096b3c3):
- `Flutter 3.44.6; Phase 0 skeleton + 3 OFL fonts committed. 26 squash-merges + ledger commits on
  origin/main (main = ca2e6f0).`
