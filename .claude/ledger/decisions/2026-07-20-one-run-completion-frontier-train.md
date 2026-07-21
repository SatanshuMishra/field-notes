Status: accepted
Date: 2026-07-20
Thread: journal-app-design

## Context
Question raised by the user: mitosis works through ALL MSPs even while blocking MSPs are under review, so
why were runs scoped to 1-2 MSPs, and can we complete the ENTIRE app in as few flows as possible? The prior
batching (batch 1 = 4 leaves, batch 2 = 3, batch 3 = 4 screens) was NOT an engine limit. It was a debugging
control inherited from the 2026-07-16 fold-defect era, when tight scope was needed to diagnose a silent
re-decompose. That rationale expired once manifest reuse was proven working (batches 2 and 3, twice). The
batch-3 exclusion of the 3 capture-* MSPs on "pubspec + GeneratedPluginRegistrant contention" grounds was a
reasoning error: that contention is a MERGE-time constraint (each MSP builds in its own worktree; the
conflict only appears when the second PR merges), not a BUILD-time one. It required serial MERGES, which
happen anyway, not a separate batch.

## Decision
Complete the app in ONE human-gated mitosis run carrying ALL remaining units, with the human merging green
PRs PROMPTLY as they land. Fall back to at most one cheap resume-relaunch only if the merge poll budget is
exhausted.

Engine behavior is code-verified (codebase-analyst against mitosis.js, high confidence):
- FRONTIER-TRAIN BUILD-AHEAD. A dependent U whose parents are built-but-unmerged builds speculatively
  against the parents' durable checkpoint tips (`builtInRun` map), and WITHHOLDS opening its own PR until
  every parent reaches `done` (merged). mitosis.js:4362, :4467-4472 (frontier-train compose + PR-open
  deferral). isBuildable gates on parents being `built`/`awaiting`/`done`, not merged (mitosis.js:1892-1911).
- IN-RUN MERGE POLL. The run polls `gh` for parent merges: MERGE_POLL_MAX_CYCLES=6, WAIT=300s, INTERVAL=30s
  (mitosis.js:4567-4569), and RESETS the budget on ANY detected merge (`pollsUsed = 0`, mitosis.js:2032,
  :2044). onMerged marks the parent `done` and releases its lease, unblocking dependents (mitosis.js:4661).
- SAME-RUN COMPLETION. Once all parents reach `done`, the frontier-built dependent redispatches, restacks
  onto origin/main (now containing the merges), and opens its PR — same run (mitosis.js:4163-4168).
- BOUNDED DEGRADE. If merges lag past the poll budget, U parks with diagnosis "approve + merge the
  prerequisite PR, then relaunch" (mitosis.js:3278, applied :4697/:4705). This is NOT a rebuild — the durable
  checkpoint lets the relaunch restack-and-ship directly (mitosis.js:2935-2975).
- NO CORRECTNESS RISK. U never builds against a main lacking its deps; it builds against the parents' real
  checkpointed work. Verdict (a) WAIT/build-ahead, not (c) build-broken.

Therefore the human's merge latency, not batch size, is the only real serializer. shell-nav-integration
(depends on all 7 other remaining units) is the tail: it ships last in the same run once its 7 parents are
merged, or in a cheap relaunch resume.

## Consequences
- FINAL RUN COMPOSITION: all 8 remaining units in one human-gated run — capture-photo, capture-voice,
  capture-video, today-screen, settings-screen, calendar-screen, search-screen, shell-nav-integration.
- HARD PREREQUISITE: the two parked plans (today-screen, settings-screen) must be edited to address the
  recovered plan-review findings BEFORE the run, or they re-park and their dependents (shell-nav-integration)
  cannot complete, forcing extra flows. Findings recovered from the wf_319dceb2-804 journal and recorded in
  the handoff. This is the ONE reasoning-heavy prerequisite; everything after is mechanical.
- MERGE ORDER at contention files: the 3 capture-* PRs each add pub deps and regenerate
  macos/Flutter/GeneratedPluginRegistrant.swift, so merge them ONE-AT-A-TIME with `flutter pub get`
  regeneration between; never hand-resolve. All other PRs are file-disjoint.
- MERGE DISCIPLINE keeps it to one flow: watch for awaiting-approval PRs and merge each within roughly the
  poll window (~5 min/cycle, budget resets per merge) after local fullValidationCmd passes.
- MANIFEST RECIPE for the all-units run is being verified (plan-file overwrite behavior + whether to
  trim-from-pristine vs. preserve park deltas). Pending the analyst answer; recorded in the handoff.
