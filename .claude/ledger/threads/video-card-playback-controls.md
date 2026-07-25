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
next_step: PR #38 is MERGED (da0a487) — the branch blocker is gone. What remains here is the human macOS hardware run (`flutter run -d macos`, never the raw binary), which merging did NOT perform and which four criteria demand by their own text. Spec execution is a SEPARATE fresh session via mitosis, branching from main.
branch: main (was fix/video-card-preview-and-controls, merged 2026-07-25)
---

## Status
PR #38 MERGED to `main` as `da0a487` on 2026-07-25 (squash), so every seam this thread built now ships.
All nine criteria are met IN CODE; the macOS hardware run STILL HAS NOT HAPPENED — the merge was a human
action but not that one, and four criteria name it, so the DoD gate refuses `done`. Session 03 changed no
production code: it overturned the eager-decode premise and wrote a four-MSP spec.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
Run the macOS hardware check — the last gate on this thread's criteria, and nothing here substitutes for it.
`flutter run -d macos`, never the raw binary. Confirm: a real preview frame, not the red placeholder; hover
reveals the controls and 3s idle hides them while playing; pause/resume shows them again for the full delay;
replay, scrub and mute work; a day past the cap degrades to neutral with an announced refusal, not red.
SEPARATELY, execute `docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md` via
`mitosis` in a FRESH session off `main` — it no longer waits on anything here. MSP 4 stays NOT authorized.

## Open Risks
- Merged-but-unconfirmed is the live hazard: `da0a487` ships on `main`, yet the hardware run four criteria
  demand by name has never happened. The merge retired the branch blocker WITHOUT retiring the evidence gap,
  and a merged PR reads as "done" to anyone who did not write this line. CI runs NO Dart tests, so its green
  is vacuous; local `flutter test` plus the hardware run is the only gate.
- Verified trap for the spec's Phase 1a: the native dispatcher IGNORES the per-call `takePicture` format
  argument, and `PictureFormat.jpeg` silently yields TIFF (only `.jpg` maps correctly). Format must be set
  on the `CameraMacOSView(...)` in `openSession`, not at the call site.
- Receipts here have been green-and-BLIND before (single card at `cap: 1` hid two CRITICALs); the spec
  mandates a mutation check on MSP 2. The responsive band is unreceipted — the 360px harness hits the floor.
- No pagination in the query layer (`entries_dao.dart:70-90`, no `.limit`) — orthogonal, unmitigated, and possibly a better answer than slivers for a huge day.
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); `video_body.dart` is 672 lines, its controller-extraction seam where both CRITICALs lived.

## Key Decisions
- decisions/2026-07-25-poster-first-supersedes-eager-decode.md — poster-first root fix; cap stays 6 global
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU, structural failure class; its "macOS writes no thumbnail" premise is now OVERTURNED by the record above
- decisions/2026-07-24-eager-init-decoder-ceiling.md — why eager init needed gating at all
- decisions/2026-07-24-non-evicting-acquire-for-passive-mount.md — passive acquisition never evicts
- decisions/2026-07-24-playback-recovery-counts-as-interactive.md — recovery re-acquires WITH eviction rights
- decisions/2026-07-24-restart-retains-its-decoder-slot.md — `_restart` never releases its slot
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
  Controller extraction from `video_body.dart`; touch double-tap seek; scrubber hover-thickening.
- Any thumbnail backfill or file-based frame extractor: all current data is temporary and will be purged
  before release (user-confirmed 2026-07-25). Editing the vendored `third_party/camera_macos` source.

## Pointers
- docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md — THE NEXT WORK, 4 MSPs
- https://github.com/SatanshuMishra/field-notes/pull/38 — MERGED 2026-07-25 as da0a487; body carries the hardware checklist that is still unrun
- lib/features/entry_cards/playback/ — video_slots.dart (capped LRU registry), video_slots_provider.dart,
  video_player_impl.dart; cards/ — video_body.dart (phase machine; MSP 2's only lib/ file),
  video_controls_overlay.dart, video_control_bar.dart, video_scrubber.dart, voice_body.dart (mirrored)
- lib/features/capture/platform/camera_video_recorder.dart — MSP 1's file; the macOS/Android asymmetry.
  test/features/entry_cards/support/video_card_harness.dart — slot accounting, reused by MSP 2
- Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-25-03-video-card-playback-controls.md — teaching pass, premise overturned, spec written
- sessions/2026-07-25-02-video-card-playback-controls.md — responsive 21:9 preview + cover fill; PR #38 opened
- sessions/2026-07-25-01-video-card-playback-controls.md — eleven review fixes, a voice twin swept, overlay built
