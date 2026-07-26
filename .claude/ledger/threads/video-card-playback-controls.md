---
thread: video-card-playback-controls
status: paused
updated: 2026-07-25
priority: high
completion_criteria:
  - A video card shows a real preview frame before playback, never the red corrupt placeholder, human-confirmed on macOS hardware
  - A played video can be replayed, paused, scrubbed and muted from the card, human-confirmed
  - Red placeholder appears only on genuine media failure, never for an absent poster
  - EntryVideoPlayer reaches parity with EntryAudioPlayer (seek, positionStream, duration, completed)
  - Video controller init is gated so a day of video entries cannot exhaust the device decoder ceiling
  - _markUnavailable distinguishes retryable decoder unavailability from genuine corruption, with a retry path
  - Hover-reveal overlay behaves per spec on macOS pointer AND Android touch, with the macOS path covered by a test that overrides defaultTargetPlatform
  - Every control meets the 48x48 logical-px tap-target floor and is keyboard reachable with a Semantics label
  - Red-before-green receipt exists for each of the two reported defects
next_step: Salvage MSP 2 in a fresh session — ratify the didUpdateWidget gate as a spec amendment, execute plan Task 3, validate, ship. Then restart MSP 3 from the spec. Separately, the macOS hardware run is still unperformed and is the only thing that can close this thread.
branch: main (post-merge ledger on chore/ledger-handoff-session-05b)
---

## Status
All nine criteria are met IN CODE by PR #38 (`da0a487`); the macOS hardware run STILL HAS NOT HAPPENED and
four criteria name it, so the DoD gate refuses `done`. Poster-first spec: MSP 1 SHIPPED — PR #41 MERGED as
`a31130f`, strand-checked clean via the SCOPED diff (see session 05 addendum 2). MSP 2 parked with a
SALVAGE verdict; MSP 3 parked, restart from spec. Ledger PR #42 MERGED as `cae77ee`; local main matches.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
PRs #41 and #42 are MERGED and local `main` sits at `cae77ee` — no PR gate remains. THE next action is the
MSP 2 salvage, in a fresh session. MSP 2's task branches were cut from `4e39884` (pre-#41 main); file
scopes are disjoint by spec design (capture vs entry_cards), so bringing them onto current main should be
conflict-free — verify, don't assume. Any relaunch passes `sourcePrefix: "msp"`:
- MSP 2: SALVAGE (findings read in session 05's addendum — the park is a governance deadlock, the code is
  reviewer-validated and 42 receipts green at `3a7bd7f`). Ratify the didUpdateWidget gate as a spec
  amendment, run plan Task 3 (".mitosis/poster-first-decode-gate.plan.md:513", closes the MEDIUM), merge.
- MSP 3: restart from the spec — no code exists; its plan failed review 3x for a small change.

## Open Risks
- Merged-but-unconfirmed is the live hazard: `da0a487` ships on `main`, yet the hardware run four criteria
  demand by name has never happened. CI runs NO Dart tests, so green checks are vacuous — local
  `fullValidationCmd` against the real head is the only gate that means anything.
- Verifying the WRONG TREE is a demonstrated failure: a failed `git worktree add` + missing `set -e` gave a
  green suite describing `main`, not the branch. Echo `TREE:`/`HEAD:` in validation commands and read them.
- NEVER run MSP 2's engine-proposed undo (`git branch -D msp/poster-first-decode-gate-integration`): the
  final reviewer itself says "do NOT silently revert" — the fifth edit closes a real Today-feed bypass.
- The Phase-1a `takePicture` format trap, the MSP-2 mutation-check mandate, the unreceipted responsive band
  and the missing `EntriesDao` pagination are all carried in full in the spec — read it, not this line.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); `video_body.dart` is
  672 lines, its controller-extraction seam where both CRITICALs lived.
- Squash merges stranded commits TWICE on 2026-07-25 (#38, #39); #40 was clean. Verify `git diff --stat origin/main <remote-tip>` before deleting any merged branch.

## Key Decisions
- decisions/2026-07-25-source-prefix-is-a-bare-token.md — pass `msp`; the engine adds the slash
- decisions/2026-07-25-poster-first-supersedes-eager-decode.md — poster-first root fix; cap stays 6 global
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU + structural failure class; its "macOS writes no thumbnail" premise is OVERTURNED by the record above
- decisions/2026-07-25-msp-branch-prefix-not-per-type.md — one batch prefix, semantic types on commits
- decisions/2026-07-25-verify-squash-against-remote-tip.md — diff main vs tip before deleting a branch
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- The four 2026-07-24 slot-lifecycle records are indexed in PROJECT.md; load on demand.
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
  Controller extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening.
- Any thumbnail backfill or file-based frame extractor: all current data is temporary and will be purged
  before release (user-confirmed 2026-07-25). Editing the vendored `third_party/camera_macos` source.
- MSP 4 (Today virtualization) stays unauthorized, conditional on a post-Phase-1 profile.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — the 4-MSP spec
- https://github.com/SatanshuMishra/field-notes/pull/41 — MSP 1, MERGED as `a31130f` 2026-07-26T05:33Z
- .mitosis/poster-first-decode-gate.plan.md — MSP 2's plan; Task 3 (:513) is the undispatched re-arm task
- lib/features/entry_cards/playback/ + cards/video_body.dart (MSP 2's only lib/ file); lib/features/capture/platform/camera_video_recorder.dart is MSP 1's
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-25-05-video-card-playback-controls.md — mitosis run: MSP 1 to PR #41, MSPs 2+3 parked
- sessions/2026-07-25-04-video-card-playback-controls.md — #38 merge found, squash gap repaired, PR #39
