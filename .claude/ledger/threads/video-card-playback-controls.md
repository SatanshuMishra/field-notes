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
next_step: EXPLAINER ONLY — explain what MSP 4 / Phase 3 (Today-feed virtualization) is and why it was never authorized despite being planned in the spec. Read the spec line pointers assembled in sessions/2026-07-26-02-video-card-playback-controls.md. Do NOT dispatch mitosis.
branch: main (096b3c3)
---

## Status
ALL THREE AUTHORIZED MSPs SHIPPED: #41 (macOS capture thumbnail), #44 (poster-first decode gate), #47
(day-detail feed virtualization, main 096b3c3, Option B verified AT main). The macOS hardware run finally
happened this session — the user ran manual testing and reported everything working as expected, retiring
the thread's long-standing merged-but-unconfirmed hazard. All nine criteria now appear met, but the thread
stays PAUSED, not done, by the user's explicit choice: they want MSP 4 explained before any closure.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
EXPLAINER, NOT EXECUTION. Explain what MSP 4 / Phase 3 (Today-feed virtualization) is and why it was never
authorized even though the spec plans it. Do NOT dispatch mitosis: Phase 3 is unauthorized until a
post-Phase-1 profile is taken AND reviewed by the spec owner. The answer is already assembled as spec line
pointers in sessions/2026-07-26-02-video-card-playback-controls.md — read those ~8 spec lines, not the
whole file. Short form: Phase 1 removed the decoder pressure that motivated Phase 3; cacheExtent means
virtualization never made "only visible cards decode" true; and shrinkWrap cannot be reused there.

## Open Risks
- MSP 3 was never validated locally: fullValidationCmd was NOT run against the PR head. receipts claimed
  the G9 suite green, but decisions/2026-07-20-ci-gates-are-hollow-for-dart.md forbids trusting CI for
  Dart — though that record predates the current receipts.config.json and may itself be stale. Unresolved.
- Squash merges strand unpushed commits: always diff main against the branch tip before deleting a branch.
- The repo is checked out on chore/ledger-handoff-session-07, NOT main, so grepping the working tree reads
  PRE-MERGE files. Use `git show main:<path>`. This produced one false negative this session.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); video_body.dart is
  ~700 lines, its controller-extraction seam where both CRITICALs lived.
- The missing EntriesDao pagination and the unreceipted responsive band are carried in the spec — read it.

## Key Decisions
- decisions/2026-07-26-day-detail-shrinkwrap-option-b.md — MSP 3 ships shrinkWrap shrink-to-fit; spec rejection scoped to unbounded positions
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
- that spec at :112, :128-131, :133, :135, :152, :159 — the whole MSP 4 answer; read only these lines
- lib/features/day_detail/day_detail_panel.dart — MSP 3 shipped here; lib/features/today/ is MSP 4's target
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-26-02-video-card-playback-controls.md — MSP 3 SHIPPED (PR #47); hardware-confirmed
- sessions/2026-07-26-01-video-card-playback-controls.md — MSP 3 plan fixed, Option B ruled, spec amended
