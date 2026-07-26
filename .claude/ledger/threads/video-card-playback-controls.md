---
thread: video-card-playback-controls
status: paused
updated: 2026-07-26
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
next_step: Restart MSP 3 from the spec — edit .mitosis/day-detail-feed-virtualization.plan.md against the adversarial findings, reconcile local main, relaunch mitosis with sourcePrefix "msp". Then the macOS hardware run, the only thing that can close this thread.
branch: main (ledger on chore/ledger-handoff-session-06)
---

## Status
All nine criteria met IN CODE. Poster-first spec: MSP 1 SHIPPED (PR #41, a31130f) and MSP 2 SHIPPED
(PR #44, db59bbd — salvage complete: didUpdateWidget gate ratified as a spec amendment, plan Task 3
executed, 868 tests green at the real head 1cfd36e). MSP 3 not started. The macOS hardware run four
criteria name has still never happened, so the DoD gate refuses done.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
Restart MSP 3 (day-detail-feed-virtualization) from the spec: no code exists; its plan failed review 3x.
Edit .mitosis/day-detail-feed-virtualization.plan.md against the adversarial findings, fast-forward local
main first (engine cuts worktrees from the bare LOCAL ref), dispatch mitosis with sourcePrefix "msp"
(bare token, no slash). After MSP 3: the macOS hardware run closes the thread; MSP 4 stays unauthorized
pending a post-Phase-1 profile.

## Open Risks
- Merged-but-unconfirmed remains the live hazard: poster-first is fully on main, yet no human has run the
  app on macOS hardware. CI runs NO Dart tests; only local fullValidationCmd at an echoed TREE:/HEAD: counts.
- Squash merges strand unpushed commits: hit again this session (PR #43 vs local a912055; recovered by
  cherry-pick). Push the ledger branch right after every ledger commit; scope strand-check diffs to the
  branch's own file class once multiple merges have landed.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); video_body.dart is
  ~700 lines, its controller-extraction seam where both CRITICALs lived.
- The missing EntriesDao pagination and the unreceipted responsive band are carried in the spec — read it.

## Key Decisions
- decisions/2026-07-25-didupdatewidget-gate-ratified-as-amendment.md — gate covers BOTH passive entry points; Task 3 form supersedes staysGated
- decisions/2026-07-25-poster-first-supersedes-eager-decode.md — poster-first root fix; cap stays 6 global
- decisions/2026-07-25-source-prefix-is-a-bare-token.md — pass `msp`; the engine adds the slash
- decisions/2026-07-25-verify-squash-against-remote-tip.md — diff main vs tip before deleting a branch
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU + structural failure class
- The four 2026-07-24 slot-lifecycle records are indexed in PROJECT.md; load on demand.
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
  Controller extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening.
- Any thumbnail backfill or file-based frame extractor: current data is temporary, purged before release.
  Editing the vendored `third_party/camera_macos` source.
- MSP 4 (Today virtualization) stays unauthorized, conditional on a post-Phase-1 profile.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — the 4-MSP spec (Phase 1b now carries the ratified amendment)
- .mitosis/day-detail-feed-virtualization.plan.md — MSP 3's plan, needs editing before relaunch
- lib/features/entry_cards/cards/video_body.dart — the gate + _deferDecodeUntilIntent live here
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-25-06-video-card-playback-controls.md — MSP 2 salvage: ratified, Task 3, PR #44 merged
- sessions/2026-07-25-05-video-card-playback-controls.md — mitosis run: MSP 1 to PR #41, MSPs 2+3 parked
