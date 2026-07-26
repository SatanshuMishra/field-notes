# Session 2026-07-26-01 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. Brief verified clean (main == origin/main == 1f77653, session-06 ledger
merged as PR #45). The user's "Go" authorized the documented next step: restart MSP 3
(day-detail-feed-virtualization) from the spec.

## What shipped
- MSP 3's round-3 adversarial findings recovered from the mitosis workflow journal
  (~/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/ea4e3b3f-.../subagents/workflows/
  wf_de373384-5d7/journal.jsonl, line 43). Rounds 1-2 were already fixed in the on-disk plan; round 3 held
  two live findings: MEDIUM — the plan's case against Option B rested on an unverified scroll-wobble claim;
  LOW — "loading/empty/error branches unaffected" overclaimed (their constraint changes bounded).
- The wobble claim VERIFIED FALSE against the Flutter source before editing: RenderShrinkWrappingViewport
  clamps via constraints.constrainHeight(_shrinkWrapExtent) (viewport.dart:2116-2119); both content-size
  cases (past the ~744px cache window: estimate >> slot, clamps constant; inside it: every child laid out,
  extent exact) give a scroll-stable height. Both findings fixed in
  .mitosis/day-detail-feed-virtualization.plan.md.
- Step 0 ruling obtained PRE-DISPATCH from the spec owner (AskUserQuestion), verbatim "Option B:
  shrink-to-fit" — avoiding the MSP 2 governance-deadlock park (a worker cannot reach a human mid-run).
  Recorded at decision time: decisions/2026-07-26-day-detail-shrinkwrap-option-b.md, indexed in PROJECT.md.
- Spec amended (docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md): Phase 2
  Amendment ratifies shrinkWrap for the bounded Day-detail panel; the blanket rejection at the Phase 3
  forbidden-shortcuts and Rejected-alternatives entries is scoped to unbounded positions (Today feed keeps it).
- Plan re-planned for Option B: Step 0 marked RESOLVED with the verbatim ruling; the Global Constraints
  shrinkWrap bullet inverted (MUST NOT -> MUST appear); shrinkWrap: true added to Step 5's code; the
  "fix, measured" bullet and Step 6 re-scoped (Option A measured 3 tiles; do not tune to an exact count);
  report-back item 4 rewritten. Recorded Decision 4 (padding: EdgeInsets.zero) unchanged — BoxScrollView
  injects the safe-area SliverPadding regardless of shrinkWrap.
- Pre-relaunch reconciliation confirmed: git fetch; main == origin/main == 1f77653; nothing stranded.

## Tried and failed
- none

## Verification
- sed viewport.dart:2104-2190 — read the clamp and _attemptLayout directly; confirmed the round-3
  reviewer's citations (constrainHeight at :2117, infinite-branch at :2153-2158) before retracting the claim.
- git fetch && git rev-parse main origin/main — both 1f77653.
- grep of the edited plan for "MUST NOT|Option A|Option B|BLOCKING|shrinkWrap" — no leftover Option A
  defaults; Step 0 resolved; Step 5 carries shrinkWrap: true.

## Running state
- none

## Deferred + open
- HARD ORDERING CONSTRAINT: the spec amendment and this ledger ride branch chore/ledger-handoff-session-07;
  the engine cuts worker worktrees from the bare LOCAL main ref, so the amendment MUST be merged and local
  main fast-forwarded BEFORE dispatching mitosis, or plan-review re-rejects against the unamended spec :154.
- Dispatch: mitosis for MSP 3 only, sourcePrefix "msp" (bare token, no slash), fresh session.
- The macOS hardware run — four thread criteria name it; the only closer for this thread.
- MSP 4 (Today virtualization) stays unauthorized pending a post-Phase-1 profile.
- Sibling thread post-ship-hardening still paused (integration-test junk blob; export ZIP extensions).
- Voice cards remain unswept twins; video_body.dart controller extraction still out of scope.

## Pick up here
Merge the session-07 handoff PR (carries the spec amendment), fast-forward local main, then dispatch
mitosis for MSP 3 with sourcePrefix "msp". After MSP 3 ships: schedule the macOS hardware run.

## Demoted from PROJECT.md (80-line cap)
Index line removed to make room for the 2026-07-26 Option B ruling record. The decision FILE remains on
disk and loads on demand; its constraint also survives verbatim in PROJECT.md Constraints ("Binary assets
must be human-provided + committed"):
- `decisions/2026-07-10-fonts-vendored-human-provided.md` — vendored OFL fonts, human-provided
  (downloads blocked)
