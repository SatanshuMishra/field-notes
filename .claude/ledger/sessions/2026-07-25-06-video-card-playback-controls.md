# Session 2026-07-25-06 — video-card-playback-controls

## Where it started
Resumed on the explicit slug to salvage the parked MSP 2 (governance deadlock: the reviewer demanded a
human ratify the fifth edit). The user's "Go" on the brief granted the ratification.

## What shipped
- Ratification: decisions/2026-07-25-didupdatewidget-gate-ratified-as-amendment.md (ledger) plus a spec
  amendment in Phase 1b of docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md
  (commit e441093, rode the MSP 2 PR).
- Plan Task 3 (.mitosis/poster-first-decode-gate.plan.md:513) executed by a delegated implementer in the
  task-2 worktree: didUpdateWidget's interim staysGated branch replaced by the plan's pure
  _hasCapturedPoster check routing to _deferDecodeUntilIntent(), which also RELEASES the held slot —
  closing the review's MEDIUM (_needsMediaResolution as intent proxy). Commit af425c8. TDD held: the
  plan's exact predicted RED observed first; all three mutation checks observed RED and restored.
- Merges: task-2 -> integration (5bee65f), then main (#41+#42) -> integration (1cfd36e). Conflict-free,
  as the disjoint-scope design predicted.
- MSP 2 SHIPPED: PR #44 merged as db59bbd. MSP 1 had shipped as a31130f (PR #41). 2 of 3 MSPs done.
- PR #43 merged as 22c2097 (the session-05b ledger branch at e005d57).

## Tried and failed
- The session-05b ledger branch was merged (PR #43) at e005d57, stranding the local ratification commit
  a912055 — the pushed head predated it. Caught by inspection, not lost; cherry-picked onto
  chore/ledger-handoff-session-06 (97b48c3) from post-merge main. Lesson: push the ledger branch
  immediately after every ledger commit, or the next squash strands it.

## Verification
- Step 2 RED: "Expected: an object with length of <1> / Actual: [two FakeEntryVideoPlayer]" — exact plan shape.
- Mutations: gate removed -> RED; _releaseSlot() dropped -> RED on the released-slot probe; restored -> +7 green.
- Integration head 1cfd36e, TREE/HEAD echoed: flutter analyze "No issues found!"; flutter test "+868: All tests passed!" (exit 0).
- Strand checks: `git diff --stat origin/main 1cfd36e -- lib test docs third_party` EMPTY (all #44 landed).
- `gh pr view 43/44` — both MERGED; origin/main = db59bbd.

## Running state
- none. All background tasks completed; no subagents running.

## Deferred + open
- MSP 3 (day-detail-feed-virtualization): no code exists; restart from the spec. Edit
  .mitosis/day-detail-feed-virtualization.plan.md against the adversarial findings, reconcile local main
  first, relaunch mitosis with sourcePrefix "msp" (bare token).
- The macOS hardware run — four thread criteria name it; the only thing that can close the thread.
- MSP 2's merged branches/worktrees under .fireplace-worktrees-poster-first remain on disk (kept by policy).
- Voice cards remain unswept twins; video_body.dart controller extraction still out of scope.
- Sibling thread post-ship-hardening still paused (integration-test junk blob; export ZIP extensions).

## Pick up here
Restart MSP 3 from the spec (plan edit -> fresh mitosis dispatch), then schedule the macOS hardware run.
MSP 4 (Today virtualization) stays unauthorized pending a post-Phase-1 profile.

## Demoted from PROJECT.md (80-line cap)
Index line removed to make room for the 2026-07-25 ratification record. The decision FILE
remains on disk and loads on demand; historical now that 31/31 shipped and merge policy is
governed by 2026-07-12-human-gated-merge-policy.md:
- `decisions/2026-07-11-foundations-shipped-autonomous-policy.md` — force-push authorized;
  4 foundation PRs merged (origin/main ef3e8c6, 4/31 shipped); autonomous-for-27 part
  SUPERSEDED by 2026-07-12-human-gated-merge-policy.md
