---
thread: video-card-playback-controls
status: paused
updated: 2026-07-24
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
next_step: Gate video controller construction/load on visibility or first interaction (and/or move the feeds to lazy slivers), capping concurrently initialized players, and split retryable decoder failure from genuine corruption so the card can retry instead of latching red.
branch: fix/video-card-preview-and-controls
---

## Status
Both reported defects FIXED IN CODE and receipted; nothing human-confirmed on hardware. Seven commits,
19 files, +1894/-183; analyze clean, 764 tests green, the three red-before/green-after receipts green
and never weakened. Four of nine criteria met (parity, receipts, absent-poster handling, 48px+keyboard
on the video card).

## Active Goal
Give the video entry card a real preview frame and a working control surface on the voice card's
architecture, without a resource ceiling that reinstates the red placeholder.

## Next Step
Decoder gating FIRST, before the overlay: it is a correctness ceiling that reintroduces the very defect
this branch removes, and it changes when `_prepare()` fires, which the overlay would otherwise have to
be rewritten around. Then the overlay against spec receipts 3-5. Only then the human hardware test.

## Open Risks
- `isCompleted` in video_player 2.13.0 is `position == duration`, set by `seekTo` as well as by natural
  end, so `isPlaying && isCompleted` is legal live state. Completion MUST test `isCompleted && !isPlaying`.
  Backwards, it silently removes the pause control mid-playback; it happened once this session and the
  unit test had enshrined the wrong behavior.
- First-frame-after-`initialize()` on macOS is UNVERIFIED. The neutral base absorbs a blank frame; if
  blank, fill poster slot 2 via `CameraVideoRecorder._captureThumbnail` rather than redesigning.
- CI runs NO Dart tests. Local validation plus a human hardware test is the only real gate.
- `defaultTargetPlatform` reports `android` in ALL widget tests; without `debugDefaultTargetPlatformOverride`
  the macOS pointer path is silently untested.
- Desktop and mobile conflict on first-tap semantics (desktop click always toggles, mobile tap only
  reveals): one unconditional tap handler is wrong. `AnimatedOpacity` buffers its child and the
  cel-shaded painting is already paint-heavy, so measure the fade. Auto-hide conflicts with WCAG SC
  1.4.13's Persistent clause (w3c/wcag#2007 open); keyboard-focus-suspends-hide is community
  mitigation, not ratified guidance.
- Non-null-but-unresolvable `thumbnailMediaId` still renders red over a playable video (unreachable
  today). Readout contrast ~2.9:1 (`Palette.muted` on `Palette.cardWarm`), under WCAG 1.4.3, pre-existing.

## Key Decisions
- decisions/2026-07-24-eager-init-decoder-ceiling.md — decoder gating is IN scope, sequenced before the
  overlay; qualifies but does not supersede the eager-player decision
- decisions/2026-07-24-video-card-eager-player-and-controls.md — rebuild on the voice card's architecture
  (eager init, never swap the tree, poster as fallback slot, red only for real failure) + hover-reveal
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the human merges each PR
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run no Dart test

## Out of Scope
- All v2 sync/server work; iOS; new v1 features. Fullscreen, playback speed, captions, quality controls.
- Capture-time macOS thumbnail: fallback only, if the eager first frame proves blank on hardware.
- The voice card's 40x40 tap target (twin defect, unswept, tracked here not fixed).

## Pointers
- .claude/ledger/plans/2026-07-24-video-card-controls-spec.md — state machine, platform split, a11y
  floors, receipts list; receipts 3-5 are the unbuilt overlay work
- lib/features/entry_cards/cards/ — video_body.dart (rebuilt card), video_control_bar.dart +
  video_scrubber.dart (control surface), voice_body.dart (the architecture mirrored)
- lib/features/entry_cards/playback/video_player_impl.dart — `videoStateFromValue`, load-bearing mapping
- lib/features/entry_cards/media/media_image.dart — absent id now neutral, not red
- lib/features/today/today_entry_feed.dart:57, lib/features/day_detail/day_detail_panel.dart:143 —
  the non-lazy Columns behind the decoder ceiling
- test/features/entry_cards/ — the three defect receipts plus the scrubber/mute/readout suite
- .claude/ledger/threads/post-ship-hardening.md — sibling thread, still paused

## Recent Sessions
- sessions/2026-07-24-09-video-card-playback-controls.md — both defects fixed in code and receipted
