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
  - Hover-reveal overlay behaves per spec on macOS pointer AND Android touch, with the macOS path covered by a test that overrides defaultTargetPlatform
  - Every control meets the 48x48 logical-px tap-target floor and is keyboard reachable with a Semantics label
  - Red-before-green receipt exists for each of the two reported defects
next_step: Write the red receipt tests from the spec's Receipts section, starting with the two that are fully design-independent (a null-thumbnail entry must not render the danger placeholder; a completed video must still expose a working replay affordance).
branch: fix/video-card-preview-and-controls
---

## Status
Investigation and design COMPLETE, no implementation started. Both defects root-caused and verified
against source; architecture decided and recorded; full hover-reveal spec written. Branch cut clean
from main @ 5cb5bad. Successor to post-ship-hardening for this specific line of work, created so the
umbrella thread does not absorb it the way journal-app-design did.

## Active Goal
Give the video entry card a real preview frame and a working hover-reveal control surface, rebuilt
on the voice card's proven architecture.

## Next Step
Write the red receipts first. The two design-independent ones can be written immediately: a video
entry with `thumbnailMediaId == null` must NOT render the danger/red placeholder, and a completed
video must still expose a working replay affordance. Both fail against current HEAD. Then interface
parity on `EntryVideoPlayer`, then the card rebuild, then the overlay.

## Open Risks
- First-frame-after-`initialize()` on macOS is Medium confidence and UNVERIFIED on this hardware.
  The poster slot is designed to absorb either outcome; if the frame is blank, fill slot 2 with a
  captured thumbnail rather than redesigning the card.
- `defaultTargetPlatform` reports `TargetPlatform.android` in ALL widget tests regardless of host.
  Without `debugDefaultTargetPlatformOverride` the macOS pointer path is silently untested.
- Desktop and mobile genuinely conflict on first-tap semantics: desktop click always toggles
  playback, mobile tap only reveals. A single unconditional tap handler is wrong.
- `AnimatedOpacity` paints its child into an intermediate buffer. The cel-shaded painting is already
  paint-heavy; measure rather than assume the fade is free.
- Auto-hiding controls sit in real tension with WCAG SC 1.4.13's Persistent clause, and W3C's own
  working group has an open unresolved issue on exactly this (w3c/wcag#2007). Keyboard-focus-
  suspends-hide is the community mitigation, not ratified guidance.
- CI runs NO Dart tests. Local validation plus human hardware test is the only real gate.

## Key Decisions
- decisions/2026-07-24-video-card-eager-player-and-controls.md — rebuild on the voice card's
  architecture (eager init, never swap the tree, poster as a fallback slot, red reserved for real
  failure) + hover-reveal controls; native poster extraction and a second blob migration rejected
- decisions/2026-07-22-black-window-standalone-binary.md — always `flutter run -d macos`, never the
  raw binary
- decisions/2026-07-21-gh-merge-hook-blocked-human-merges.md — the human merges each PR
- decisions/2026-07-20-ci-gates-are-hollow-for-dart.md — GitHub checks run no Dart test

## Out of Scope
- All v2 sync/server work; iOS; new v1 features.
- Fullscreen, playback speed, captions and quality controls — a journal card needs none of them.
- Capture-time macOS thumbnail: fallback only, implemented solely if the eager first frame proves
  blank on hardware.

## Pointers
- .claude/ledger/plans/2026-07-24-video-card-controls-spec.md — READ FIRST; state machine, platform
  split, accessibility floors, receipts list
- lib/features/entry_cards/cards/video_body.dart — the one-way latch to fix (:114-118, :123)
- lib/features/entry_cards/cards/voice_body.dart — the working architecture to mirror
- lib/features/entry_cards/playback/video_playback.dart — interface missing seek/position/completed
- lib/features/entry_cards/playback/audio_playback.dart — the parity target
- lib/features/entry_cards/playback/video_player_impl.dart — video_player 2.13.0 wrapper
- lib/features/entry_cards/media/media_image.dart — :43 conflates absent poster with corrupt file
- lib/features/capture/platform/camera_video_recorder.dart — :345 macOS path omits thumbnail; :77/:98
  is the working non-macOS capture to mirror if needed
- lib/design/tokens/ — Palette, Shapes.outline, TypographyTokens; no .claude/design/ exists
- test/features/entry_cards/support/entry_cards_harness.dart — FakeMediaResolver/FakeVideoPlayer
- .claude/ledger/threads/post-ship-hardening.md — sibling thread, still paused

## Recent Sessions
- sessions/2026-07-24-08-post-ship-hardening.md — defects root-caused, design decided, spec written
