# Session 2026-07-25-04 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. The Resumption Brief hit a divergence immediately: the thread's single
blocking premise — PR #38 open and gating all four MSPs — was false. It had been merged. The user said
"Go", then chose to execute the spec via `mitosis` over running the hardware check first.

## What shipped
- PR #39 (https://github.com/SatanshuMishra/field-notes/pull/39), branch `docs/poster-first-spec` off
  `main`: the four-MSP spec, the session-03 log, the poster-first decision record, and the corrected
  ledger. Both checks green, MERGEABLE, still OPEN.
- Recovery of two ledger files the PR #38 squash silently dropped (see below).
- Thread spine and PROJECT.md rewritten from "PR #38 open, gates all four MSPs" to the merged reality,
  explicitly preserving that merging did NOT perform the hardware run.
- Spec front matter: Status flipped to AUTHORIZED (MSPs 1-3 only), Precondition 1 rewritten from "PR #38
  must land" to "SATISFIED, merged as da0a487". Agents would otherwise read the spec and refuse to start.
  This edit is UNCOMMITTED — see Running state.
- decisions/2026-07-25-msp-branch-prefix-not-per-type.md
- decisions/2026-07-25-verify-squash-against-remote-tip.md

## The finding that mattered
PR #38 squash-merged at 13:37 MDT, but the remote branch tip `3a24ff6` was committed at 13:49 — twelve
minutes LATER. GitHub squashed the older state, so `3a24ff6` never reached `main`. Two casualties:
`sessions/2026-07-25-02-video-card-playback-controls.md` dropped entirely, and
`decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md` reverted to its pre-cap 39-line
form — whose 20-line replacement demotes detail INTO the session log that was also dropped. `main` was
left holding an over-cap decision record pointing at a file that did not exist. Both restored from
`3a24ff6`. The detection command is `git diff --stat origin/main 3a24ff6`; nothing in the GitHub UI or
`gh pr view` surfaces this.

## Tried and failed
- **Mitosis dispatch BLOCKED, two attempts.** The `claude-sonnet-5` classifier that gates auto-mode
  permissions went unavailable, so the harness could not approve `Workflow` (or write-class `Bash`). The
  failure landed BEFORE dispatch: no worktrees created, no branches, no agents spawned, nothing to clean
  up. A retry is a clean first attempt, not a resume.
- `git commit` / `git push` of the spec authorization edit blocked by the same outage. Read-only Bash and
  Write/Edit kept working throughout.
- **Considered producing the macOS hardware evidence directly and rejected it.** `flutter devices` shows
  `macOS (desktop) • macos • darwin-arm64` and `macos/Runner.xcworkspace` is present, so the app builds —
  but `scratchpad/vm_screenshot.dart` no longer exists in the repo, `screencapture` is TCC-blocked per the
  project's own record, and hover-reveal / 3s auto-hide / scrub / mute are interactive behaviors stills
  capture poorly. A screenshot I take is not "human-confirmed" regardless, so it could not close the gate.
- The initial cherry-pick of `57a568a` onto `main` conflicted in both ledger files. Resolved by taking the
  newer side wholesale (`git checkout --theirs`) rather than hand-merging — the HEAD side carried
  duplicated Key Decisions lines that a manual merge would have preserved.

## Verification
- `gh pr view 38` — state MERGED, mergeCommit `da0a487`, mergedBy SatanshuMishra, mergedAt
  2026-07-25T19:37:56Z. This is what contradicted the ledger.
- `git log -1 --date=iso-strict 3a24ff6` — 2026-07-25T13:49:20-06:00 vs merge at 13:37:56. Confirmed the
  twelve-minute gap as the mechanism rather than assuming it.
- `git diff --stat origin/main 3a24ff6` — 4 files `main` lacked; drove the recovery.
- `git diff HEAD 3a24ff6` post-recovery — every remaining delta accounted for as either a deliberate
  correction or newer session-03 content. Nothing unexplained.
- `wc -l` — thread file 80, PROJECT.md 80, restored decision record 20. All at cap, none over.
- `grep -rn '<<<<<<<|>>>>>>>' .claude/ledger/ docs/` — zero conflict markers.
- `gh pr view 39` — receipts SUCCESS, pr-title-lint SUCCESS, MERGEABLE, OPEN.
- No `flutter analyze` / `flutter test`: zero Dart changed this session, docs and ledger only.

## Running state
- none. Mitosis never dispatched; no background shells, no subagents.
- Working tree is on branch `docs/poster-first-spec` with ONE uncommitted edit: the spec Status and
  Precondition 1 rewrite. Commit it with `chore` or fold it into PR #39 once the classifier recovers.

## Deferred + open
- PR #39 open, green, unmerged. Merging it puts the spec on `main`, which the mitosis retry wants.
- The spec authorization edit is uncommitted (blocked, not forgotten).
- The macOS hardware run is still unperformed. Four of the nine criteria demand it by name, so this thread
  cannot reach `done` no matter what the spec work produces.
- MSP 4 (Today virtualization) remains unauthorized, conditional on a post-Phase-1 profile.
- `post-ship-hardening` sibling thread untouched, still paused.

## Pick up here
PR #39 is MERGED as `8bef597`, so the spec IS on `main` and every mitosis worktree can read it at a
repo-relative path. The scratchpad copy used this session lives at a session-scoped path that will NOT exist
in a fresh session; do not reuse it.

Merge PR #40 FIRST — it carries this very session log and both new decision records, which the #39 squash
stranded (the hazard recurred on the commit documenting it; see below). Merging is the HUMAN's action: per
`decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md`, `gh pr merge` and the REST merge endpoint are
hook-blocked for all callers including the main thread. After merging, verify with
`git diff --stat origin/main origin/chore/ledger-handoff-session-04` before deleting the branch.

Then dispatch mitosis with: spec
`docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md`, `baseBranch: main`,
`sourcePrefix: msp/`, verify and build seeds lifted verbatim from `receipts.config.json`, a fresh
`worktreeRoot` outside the repo, `fixLoopMax: 2`. MSPs 1-3 only.

TWO PRE-FLIGHT CONSTRAINTS, both from prior hard-won records, neither optional:
- `decisions/2026-07-16-pre-relaunch-main-reconciliation.md` — reconcile local `main` onto `origin/main`
  BEFORE dispatching. The engine cuts worktrees from the bare LOCAL `main` ref, so local `main` must already
  contain PR #39. Merging on GitHub is not enough; fetch and fast-forward local `main` first.
- `decisions/2026-07-20-ci-gates-are-hollow-for-dart.md` — neither GitHub check runs a Dart test. Run
  `fullValidationCmd` locally against each PR head worktree before every merge; never accept a green check
  as evidence.

## Demoted from PROJECT.md (80-line cap)

Index lines removed to make room for the two new 2026-07-25 records. Both decision FILES remain on disk and
load on demand; only their index lines were dropped, and both belong to the completed 31/31 build era:

- `decisions/2026-07-21-shellnav-built-via-delegated-implementer.md` — shell-nav BUILT via a delegated
  implementer on origin/main (fresh-context rule barred a mitosis relaunch; also sidesteps the checkpoint
  composition); PR #31 open + independently validated (660 tests, CI green), awaiting the HUMAN's final
  merge -> 31/31. Historical: 31/31 shipped.
- `decisions/2026-07-20-batch-3-scoping.md` — batch-3 four-screen scope; the capture-* "contention"
  reasoning was a merge-time vs build-time error the user corrected (superseded in spirit by the one-run
  decision).
