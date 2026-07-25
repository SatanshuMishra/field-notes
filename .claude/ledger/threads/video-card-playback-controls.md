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
next_step: Merge PR #40 (the session-04 ledger, stranded by the #39 squash), fast-forward local main, then retry the mitosis dispatch that a classifier outage blocked. Separately, the human macOS hardware run is still unperformed and is the only thing that can close this thread.
branch: main (was fix/video-card-preview-and-controls, merged 2026-07-25)
---

## Status
PR #38 MERGED to `main` as `da0a487` on 2026-07-25 (squash), so every seam this thread built now ships.
All nine criteria are met IN CODE; the macOS hardware run STILL HAS NOT HAPPENED — the merge was a human
action but not that one, and four criteria name it, so the DoD gate refuses `done`. Session 04 landed the
spec + repaired ledger on PR #39 (green, UNMERGED) and recovered two files the #38 squash dropped, then hit
a classifier outage that blocked the mitosis dispatch before it started. No production code since #38.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
PR #39 is MERGED (`8bef597`), so the spec is on `main`. Merge PR #40 first — it carries the session-04
ledger the #39 squash stranded — then fast-forward LOCAL `main` (the engine cuts worktrees from the local
ref). Then retry the mitosis dispatch: spec
`docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md`, `baseBranch: main`,
`sourcePrefix: msp/`, verify+build seeds verbatim from `receipts.config.json`, fresh `worktreeRoot` outside
the repo, `fixLoopMax: 2`, MSPs 1-3 only. SEPARATELY and independently, the macOS hardware check is still
unrun and is the ONLY thing that can close this thread: `flutter run -d macos`, never the raw binary — confirm
a real preview frame not the red placeholder; hover reveals controls and 3s idle hides them while playing;
pause/resume shows them again for the full delay; replay, scrub and mute work; a day past the cap degrades to
neutral with an announced refusal, not red.

## Open Risks
- Merged-but-unconfirmed is the live hazard: `da0a487` ships on `main`, yet the hardware run four criteria
  demand by name has never happened. The merge retired the branch blocker WITHOUT retiring the evidence gap,
  and a merged PR reads as "done" to anyone who did not write this line. CI runs NO Dart tests, so its green
  is vacuous; local `flutter test` plus the hardware run is the only gate.
- The Phase-1a `takePicture` format trap, the MSP-2 mutation-check mandate, the unreceipted responsive band and the missing `EntriesDao` pagination are all carried in full in the spec — read it, not this line.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); `video_body.dart` is 672 lines, its controller-extraction seam where both CRITICALs lived.
- GitHub squash merges stranded post-snapshot commits TWICE on 2026-07-25 (#38, then #39 on the very commit documenting it). Verify `git diff --stat origin/main <remote-tip>` before deleting any merged branch.

## Key Decisions
- decisions/2026-07-25-poster-first-supersedes-eager-decode.md — poster-first root fix; cap stays 6 global
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU, structural failure class; its "macOS writes no thumbnail" premise is now OVERTURNED by the record above
- decisions/2026-07-25-msp-branch-prefix-not-per-type.md — msp/ for branches, semantic types on commits
- decisions/2026-07-25-verify-squash-against-remote-tip.md — diff main vs branch tip before deleting a branch
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- The four 2026-07-24 slot-lifecycle records (eager-init ceiling, non-evicting acquire, recovery-is-interactive, restart-retains-slot) are indexed in PROJECT.md; load on demand.
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
  Controller extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening.
- Any thumbnail backfill or file-based frame extractor: all current data is temporary and will be purged
  before release (user-confirmed 2026-07-25). Editing the vendored `third_party/camera_macos` source.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — THE NEXT WORK, 4 MSPs
- https://github.com/SatanshuMishra/field-notes/pull/38 — MERGED 2026-07-25 as da0a487; body carries the hardware checklist that is still unrun
- https://github.com/SatanshuMishra/field-notes/pull/39 — spec + repaired ledger; green, MERGEABLE, unmerged. Merge before dispatching mitosis.
- lib/features/entry_cards/playback/ — video_slots.dart (capped LRU registry), video_slots_provider.dart,
  video_player_impl.dart; cards/ — video_body.dart (phase machine; MSP 2's only lib/ file),
  video_controls_overlay.dart, video_control_bar.dart, video_scrubber.dart, voice_body.dart (mirrored)
- lib/features/capture/platform/camera_video_recorder.dart — MSP 1's file; the macOS/Android asymmetry.
  test/features/entry_cards/support/video_card_harness.dart — slot accounting, reused by MSP 2
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-25-04-video-card-playback-controls.md — #38 merge found, squash gap repaired, PR #39, mitosis blocked
- sessions/2026-07-25-03-video-card-playback-controls.md — teaching pass, premise overturned, spec written
- sessions/2026-07-25-02-video-card-playback-controls.md — responsive 21:9 preview + cover fill; PR #38 opened
