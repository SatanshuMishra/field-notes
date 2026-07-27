---
thread: video-card-playback-controls
status: done
updated: 2026-07-26
priority: high
completion_criteria:
  - "[x] A video card shows a real preview frame before playback, never the red corrupt placeholder, human-confirmed on macOS hardware"
  - "[x] A played video can be replayed, paused, scrubbed and muted from the card, human-confirmed"
  - "[x] Red placeholder appears only on genuine media failure, never for an absent poster"
  - "[x] EntryVideoPlayer reaches parity with EntryAudioPlayer (seek, positionStream, duration, completed)"
  - "[x] Video controller init is gated so a day of video entries cannot exhaust the device decoder ceiling"
  - "[x] _markUnavailable distinguishes retryable decoder unavailability from genuine corruption, with a retry path"
  - "[x] Hover-reveal overlay behaves per spec on macOS pointer AND Android touch, with the macOS path covered by a test that overrides defaultTargetPlatform"
  - "[x] Every control meets the 48x48 logical-px tap-target floor and is keyboard reachable with a Semantics label"
  - "[x] Red-before-green receipt exists for each of the two reported defects"
next_step: "-"
branch: chore/ledger-handoff-session-07 (UNMERGED to main 096b3c3 — merge before resuming any thread)
---

## Closure
Closed 2026-07-26: the video entry card shows a real preview frame and a full working control surface on
a capped, retryable decoder architecture — all nine criteria verified against main (096b3c3) by a
per-criterion evidence audit and confirmed by the user's manual macOS run.

## Status
DONE. Three MSPs shipped — #41 (macOS capture thumbnail), #44 (poster-first decode gate), #47 (day-detail
feed virtualization, Option B) — and the user's 2026-07-26 macOS run confirmed them, retiring the
merged-but-unconfirmed hazard. Session 03 delivered the MSP 4 explainer, recorded MSP 4 as not
authorized, and passed the DoD gate on verified `path:line` evidence, replacing the "appear met" hedge.

## Active Goal
Achieved: give the video entry card a real preview frame and a working control surface on the voice
card's architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
None — terminal. Reopening creates a NEW thread referencing this one. Next session opens a FRESH thread;
first merge `chore/ledger-handoff-session-07` to main or it starts from a ledger still showing this paused.

## Open Risks
Carried into closure by acceptance, not oversight — none blocked the criteria:
- MSP 3 was never validated locally: `fullValidationCmd` was NOT run against the PR head. The manual
  hardware pass covers user-visible behavior, not the automated suite.
- Play/pause + mute keyboard reachability rests on code inspection (`FocusableActionDetector` +
  `Semantics`), not a `sendKeyEvent` test; the scrubber and retry button do have runtime key assertions.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); `video_body.dart`
  is ~700 lines, its controller-extraction seam where both CRITICALs lived.
- Squash merges strand unpushed commits: always diff main against the branch tip before deleting a branch.
- Spec line pointers are WORKING-TREE-relative on this branch (it carries the amendment, main does not);
  read them from the working tree, never via `git show main:`.

## Key Decisions
- decisions/2026-07-26-msp4-today-virtualization-not-authorized.md — MSP 4 not authorized; thread closes without it
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
- MSP 4 (Today virtualization) — permanently out of this thread; see its decision record.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — the 4-MSP spec; 3 of 4 shipped
- that spec at :112, :128-131, :133, :135, :152, :159 — the whole MSP 4 answer; read only these lines
- lib/features/entry_cards/cards/video_body.dart — the card; playback/video_slots.dart — the capped LRU
- lib/features/day_detail/day_detail_panel.dart — MSP 3 shipped here; lib/features/today/ was MSP 4's target
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-26-03-video-card-playback-controls.md — MSP 4 explainer delivered; DoD audit; thread CLOSED
- sessions/2026-07-26-02-video-card-playback-controls.md — MSP 3 SHIPPED (PR #47); hardware-confirmed
- sessions/2026-07-26-01-video-card-playback-controls.md — MSP 3 plan fixed, Option B ruled, spec amended
