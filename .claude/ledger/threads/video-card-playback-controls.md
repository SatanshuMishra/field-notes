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
next_step: TEACHING PASS, not implementation. Explain the 6-slot concurrent video decoder cap from first principles to a reader with minimal domain understanding. Full brief in Next Step below.
branch: fix/video-card-preview-and-controls
---

## Status
PUBLISHED. PR #38 OPEN and MERGEABLE against `main` (54 files, +7348/-267); 38 commits ahead of
`origin/main` (`5cb5bad`), analyze clean, 856 green, re-verified at HEAD before the push. All nine criteria
are met IN CODE; NOTHING is hardware-confirmed, still the only real gate.

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
TEACHING pass, explain do not implement. The user wants a SECOND LOOK at the 6-slot concurrent video
decoder cap, from the ground up, assuming MINIMAL domain knowledge. Cover: what a decoder IS (the bounded
hardware/OS unit turning compressed H.264 bytes into displayable frames) and why a device has only ~8-16;
why field-notes hits that ceiling (Today and day-detail feeds are non-lazy `Column`s with no
virtualization, so every video card on a day initialises eagerly); what `VideoSlots` does (hard-capped LRU,
cap 6, pin-while-playing, acquire/release/touch, eviction rights as an explicit argument); how one card
moves through it; what a card past the cap renders (neutral placeholder + announced refusal, never red).
Then the second look: is 6 right, and what would move it. Read the five cap decisions below, but VERIFY
every claim against `video_slots.dart` — ledger is hints, code is truth. Default to explaining in chat;
offer `/report` only if the user wants it rendered. Do NOT reopen review on `video_body.dart`.

## Open Risks
- Receipts were green and structurally BLIND for a whole round (single card at `cap: 1`), hiding two
  CRITICALs; four vacuous receipts were caught by mutation and NONE by reading. Mutation-check every
  load-bearing receipt. The new responsive sizing is likewise UNRECEIPTED — the 360px harness lands on the
  200px floor, so 856-green says nothing about it.
- CI runs NO Dart tests. Green checks on PR #38 are vacuous; local `flutter test` plus a human hardware run is the only real gate.
- First-frame-after-`initialize()` on macOS is UNVERIFIED, now more conspicuous in a taller box. If blank, fill poster slot 2 via `CameraVideoRecorder._captureThumbnail`. Cover-crop on portrait source unmeasured.
- Two Flutter test traps, found only by running: `setUp`/`tearDown` CANNOT restore `debugDefaultTargetPlatformOverride` (use `TargetPlatformVariant` via `variant:`), and `find.bySemanticsLabel` reads a STALE cache (use `find.semantics.byLabel`).
- Voice cards remain unswept twins (uncapped eager init, no retry, 40x40 tap target); a fourth was fixed, assume more. `video_body.dart` is 672 lines; the controller-extraction seam is where both CRITICALs lived.

## Key Decisions
- the first five are required reading for the next step; the rest of this thread's are in PROJECT.md's index
- decisions/2026-07-24-video-decoder-slot-cap-and-structural-retry.md — capped LRU, structural failure class
- decisions/2026-07-24-eager-init-decoder-ceiling.md — why eager init needs gating at all
- decisions/2026-07-24-non-evicting-acquire-for-passive-mount.md — passive acquisition never evicts
- decisions/2026-07-24-playback-recovery-counts-as-interactive.md — recovery re-acquires WITH eviction rights
- decisions/2026-07-24-restart-retains-its-decoder-slot.md — `_restart` never releases its slot
- decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md — 21:9 from width, floor, cover fill
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
- Viewport/visibility detection; controller extraction from `video_body.dart`; touch double-tap seek;
  scrubber hover-thickening. Capture-time macOS thumbnail is a fallback only.

## Pointers
- https://github.com/SatanshuMishra/field-notes/pull/38 — the open PR; body carries the hardware checklist
- lib/features/entry_cards/playback/ — video_slots.dart (capped LRU registry, SUBJECT OF THE NEXT STEP),
  video_slots_provider.dart, video_player_impl.dart (`videoStateFromValue`, cover-fill surface)
- lib/features/entry_cards/cards/ — video_body.dart (phase machine), video_controls_overlay.dart,
  video_control_bar.dart, video_scrubber.dart, video_transport.dart, voice_body.dart (mirrored architecture)
- test/features/entry_cards/ — support/video_card_harness.dart (multi-card slot accounting);
  cards/video_body_test.dart + media/media_image_test.dart (defect receipts, never weaken them).
  Sibling thread: .claude/ledger/threads/post-ship-hardening.md, still paused

## Recent Sessions
- sessions/2026-07-25-02-video-card-playback-controls.md — responsive 21:9 preview + cover fill; PR #38 opened
- sessions/2026-07-25-01-video-card-playback-controls.md — eleven review fixes, a voice twin swept, overlay built
