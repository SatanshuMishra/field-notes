# Session 2026-08-02-01 — prototype-design-alignment

## Where it started
Resumed on `origin/main` `a6cdcc2` with 28 of 39 MSPs landed and Cluster F closed but visually
unconfirmed. The user confirmed the combined E+F visual pass, ordered the Cluster A-F worktree
disposal, and directed a dedicated small dynamic workflow to implement and ship Cluster G as a
stack that completes without stopping for blocking merges.

## What shipped
- **CLUSTER G CLOSED: all 8 MSPs merged.** `origin/main` is now `dd74688`. Stack 121 shipped as
  nine PRs #112 (slice) -> #113 g1 -> #114 g2 -> #115 g3 -> #116 g4 -> #117 g5 -> #118 g6 ->
  #119 g7 -> #120 g8, all merged by the user in one top-down cascade. H1 (goldens) is the only
  MSP left in the whole spec.
- docs/specs/2026-08-02-prototype-alignment-cluster-g.md — the Cluster G slice, **1833 lines, 59
  primitive resolutions R1-R59, 28 rows deleted as already-satisfied**. Nearly triple Cluster F's
  resolution count; the largest slice cut so far.
- **Cluster A-F disposal executed**: 17 worktrees removed, the 5 `.fireplace-worktrees-cluster-*`
  roots deleted, 47 branches deleted (`msp-cluster-{a,b,c,f}/*` + `docs/cluster-{d,d-2,f}-slice`).
  Explicitly KEPT per the user's scoping: the legacy `.fireplace-worktrees` (24) and
  `-poster-first` (4), the four stashes, and the 22 `chore/ledger-handoff-session-*` branches.
- Workflow: 14 agents, 0 errors, ~2.9h, 855 tool calls, 2.56M subagent tokens. Run
  `wf_7a51c1c8-2af`; script at
  /Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/ba7803b8-b90f-4352-96e6-a6d3d77e561c/workflows/scripts/cluster-g-capture-composers-wf_7a51c1c8-2af.js

## What the recon and slice caught
- **G8's video pause DOES NOT EXIST on macOS.** `camera_macos` implements no pause in either its
  Dart or Swift layer. Shipped as a `supportsPause` capability degradation rather than a fence
  widening into `third_party/`; the pause criterion is met on Android only. The user's visual pass
  ruled the degraded path acceptable.
- **One dependency edge the orchestrator's chain lacked: G6 -> G7** (`toast.dart`'s variant plus
  the shared close glyph). The ship order already satisfied it since G7 sits above G6, but the
  file-overlap matrix, not the spec's `Depends on` lines, is what found it.
- 28 already-satisfied rows deleted — the Cluster E/F collapse pattern at much larger scale.
- G5's spec gap on the idle button row resolved (row deleted, the close X ships in G5). The
  `bookclose` cue at prototype `:1377`/`:1394`/`:1395` was recorded and deliberately NOT adopted.
- G7's fake/impl path corrected to `capture/platform/`.

## Tried and failed
- My dispatch named the base as `a6cdcc2`; `origin/main` was actually `dd63025` (PR #111, the
  session-26 ledger handoff, merged mid-flight). The slice agent caught it and verified
  `git diff a6cdcc2 dd63025 -- lib/ test/` is empty, so the code bases were identical and nothing
  was built on a wrong tree. NEXT TIME: re-read `origin/main` at dispatch time, not from the
  thread's `branch:` line, which goes stale the moment a ledger PR merges.
- The two-dot `git diff origin/main <branch>` I first used to prove branches were safe to delete
  was MISLEADING — it counts main's newer work as "deletions", so every old branch looked like it
  carried thousands of unmerged lines. Three-dot is also wrong under squash-merge (the merge base
  predates the squash). The decisive evidence was the merged-PR record via `gh pr list --state merged`.

## Verification
- Baseline measured first-hand on `main` before the cluster: 910 passed / 0 failed, analyze clean.
- Reviewer measured the stack tip `cf4242f` first-hand: **918 passed / 0 failed, analyze clean**.
  Predicted 918 before running. **Prediction matched observation exactly**, as in Cluster F.
- **N24 proven, not asserted**: `git diff origin/main...msp-cluster-g/g8 --
  test/features/entry_cards/playback/ test/playback/` is EMPTY. Re-run independently by the
  orchestrator. Note the real path is `test/features/entry_cards/playback/video_slots_test.dart`;
  `test/playback/` does not exist.
- Preserve items walked to concrete post-cluster locations: N11 (`voice_body.dart:287` keeps
  `ValueKey('voice-play-toggle')`, `:264-268` keeps the two-valued readout, `:254` keeps the wave
  animating while playing), N12 (picker re-homed at `video_recorder_sheet.dart:272`, not deleted;
  `camera_picker.dart:39-40` keeps its Material wrapper), N13 (phase machine six -> seven states,
  nudges and the 30:00 cap hint rendering as dark toasts).
- Squash integrity per decisions/2026-07-25-verify-squash-against-remote-tip.md:
  `git diff --stat origin/main origin/msp-cluster-g/g8 -- lib/ test/` is EMPTY after the merges.
- Stack read back live before and after merge: `GET /stacks/121` -> nine PRs, then `open=false`
  with all nine `closed`.
- macOS visual pass over Cluster G: PASSED (the user ran it; no agent can run the app).

## Running state
none

## Deferred + open, in order
1. **H1 (goldens)** — the last MSP in the spec. Depends on A4, A5, B3, E2, E3, all merged, so it is
   unblocked. Read parent spec lines 1854-1888: it needs `test/flutter_test_config.dart` loading the
   three vendored variable fonts, and the implementer MUST first confirm which side of Flutter's
   font-weight-variation breaking change the installed toolchain sits on before capturing any golden
   containing text. Currently unverified.
2. OQ-3 and OQ-6 still unanswered; **OQ-6 still blocks a C5 target value**. These plus H1 are the
   only things standing between this thread and `done`.
3. C7's badge/chip anchors and the chip's tokenless `#2A241D` — never shipped, so no visual pass
   can rule on them. Survive Cluster G untouched.
4. Two risks recorded at ship time that a visual pass does NOT close: #119's undeclared
   `SettingsSelect` `Flexible`/ellipsis ride-along, and #120's failed-save re-arm hole (the timer
   half pre-existed on `main`; the frozen readout is new).
5. Branch disposal owed for the Cluster G set: local `msp-cluster-g/g1..g8`, `docs/cluster-g-slice`,
   `chore/ledger-handoff-session-27`, plus the standing kept set (legacy worktrees, poster-first,
   four stashes, 22 ledger-handoff branches). One confirmed batch with an explicit list, never
   silently.
6. Patching `camera_macos` for real pause support is its own MSP if ever wanted — not a G8 defect.
7. PR #117's squashed subject carries a stray `(#110)` from an earlier title. Cosmetic only.

## Demoted from PROJECT.md and the thread spine (cap enforcement; all files unchanged on disk)
- decisions/2026-07-27-scope-guard-authorship-oracle.md — a plan's scope guard anchors authorship to
  a SHA captured with `git rev-parse HEAD` BEFORE the MSP's first edit, never `merge-base main HEAD`
  and never a fixed `HEAD~N`; never prescribe `git checkout -- <path>` as an autonomous step.
- decisions/2026-07-27-ship-stage-ci-wait-portability.md — darwin ships no `timeout` binary, so the
  engine's `timeout 1800 gh run watch` exits 127 instantly; use an iteration-bounded `until` loop
  and ALWAYS check the exit code before treating a wait as completed.
- Thread spine risks demoted: the `defaultTargetPlatform`-forced-to-ANDROID note (now proven twice,
  and G4's desktop branch is the standing example); the `pr-create` 200-char/72-char/ASCII caps; the
  "long commands run FOREGROUND inside a subagent" note; the `soundServiceProvider` two-override
  requirement; the Workflow `args`-as-JSON-value note. All five held true again this session.

## Pick up here
Cluster G is merged and visually confirmed on `dd74688`; nothing is mid-flight and no PR is open.
H1 (goldens) is the only MSP left in the spec — start by confirming the installed Flutter
toolchain's font-weight-variation behaviour, since every text-bearing golden depends on it. OQ-3
and OQ-6 must be answered or explicitly closed before this thread can go `done`.
