# Video card: hover-reveal control overlay — implementation spec

Branch: `fix/video-card-preview-and-controls` (cut from main @ 5cb5bad)
Decision record: `.claude/ledger/decisions/2026-07-24-video-card-eager-player-and-controls.md`

Models YouTube's interaction model, chosen by the user over an always-visible bar. Behaviour and
timing are copied; visual styling is ours (`Shapes.outline` ink borders, `CustomPainter` glyphs,
`Palette` tokens — never Material widgets).

## Honest sourcing note

YouTube's auto-hide timeout is NOT published by Google anywhere. Third-party claims spread across
2-4s. Video.js documents its own default at 2s. **The 3s below is our design choice, not a copied
fact.** Do not let a future reader mistake it for a spec value. Same for progress-bar pixel
heights — no authoritative YouTube value exists.

## State machine

Five states. Only `playing` ever runs the hide timer.

| State | Overlay | Hide timer | Enter | Leave |
|---|---|---|---|---|
| `hidden` | absent (opacity 0) | — | timeout elapses while playing | any activity -> `visibleIdle` |
| `visibleActive` | shown | SUSPENDED | pointer moving, pointer over control bar, scrubbing, menu open, keyboard focus inside controls | activity ends -> `visibleIdle` |
| `visibleIdle` | shown | counting (3s) | activity stops, pointer still inside | elapses AND playing -> `hidden` |
| `paused` | shown | NONE | pause | play -> re-arm timer |
| `ended` | shown + replay | NONE | `isCompleted` | replay -> playing |

Rules that are easy to get wrong:
- Paused NEVER auto-hides. Controls persist indefinitely. (Strong multi-source agreement on
  YouTube desktop; whole browser extensions exist because of it.)
- Ended NEVER auto-hides. No autoplay-next in this app — a journal has no "next video".
- Anything that suspends the timer must CANCEL it, not merely pause it; re-arm on activity end.

## Platform split

One widget tree. The gesture layer is shared; only the hover layer is additive.

`MouseRegion` callbacks never fire on touch — they are inert, not an error. So wrap
unconditionally; it drives reveal on macOS and is a silent no-op on Android.

| Behaviour | macOS (pointer) | Android (touch) |
|---|---|---|
| Reveal | pointer enter / move (no click needed) | tap when hidden |
| Tap/click on surface | ALWAYS toggles play/pause | reveals only when hidden; toggles ONLY via the explicit button |
| Seek gesture | none (keyboard) | double-tap left/right third, +/-10s, accumulating on repeat |
| Progress bar | thin at rest, thickens + shows handle on hover | always at touch-legible height, handle always present |
| Min target | comfortable click size | 48x48 logical px floor |

This is a genuine divergence, not an oversight: a single unconditional "tap = toggle" handler is
wrong. Gate it on controls-visibility, and branch the interaction model on
`defaultTargetPlatform`.

**Test footgun:** `defaultTargetPlatform` reports `TargetPlatform.android` in ALL widget tests
regardless of host. Any test asserting the pointer model MUST set
`debugDefaultTargetPlatformOverride` and reset it in `tearDown`. Without this the macOS path is
silently untested.

## Controls

Play/pause toggle, scrub bar with seek, elapsed/total readout, mute. No fullscreen, no speed, no
captions, no quality — a journal card needs none of them.

- Replay: `play()` alone suffices. video_player 2.13.0 seeks to zero internally when
  `position == duration`. Do NOT hand-roll a seek-then-play for replay.
- Mute: no mute API exists. `setVolume(0.0)`, restoring a remembered prior value to unmute.
- Completion: no callback exists. `addListener` + `value.isCompleted` (available since 2.7.2).
- `AnimatedOpacity` for the fade, driven by a single cancellable `Timer?`. Note its documented
  cost: it paints the child into an intermediate buffer, which matters here because the
  cel-shaded painting is already paint-heavy. Measure before assuming it is free.

## Accessibility (non-negotiable)

- Keyboard focus inside the controls counts as activity and SUSPENDS the hide timer. A focus ring
  must never vanish while it holds focus.
- Every control reachable by keyboard, with a `Semantics` label. Follow the existing
  `Semantics(button: true, enabled: ..., label: 'Play video')` idiom already in the card.
- 48x48 logical px minimum tap target satisfies WCAG 2.5.8 AA (24px) and 2.5.5 AAA (44px) plus
  Android's own 48dp convention in one number. Visible glyph may be smaller inside invisible
  padding.
- Worth knowing: auto-hiding controls sit in real tension with WCAG SC 1.4.13's "Persistent"
  clause, and W3C's own working group has an OPEN, unresolved issue on exactly this
  (w3c/wcag#2007). We are not solving a solved problem. Keyboard-focus-suspends-hide is the
  community mitigation, not ratified guidance.

## Poster slot

Resolve in order, per the decision record:
1. captured thumbnail if `thumbnailMediaId != null`
2. else the initialized-but-paused first frame
3. else the NEUTRAL placeholder

RED (`CorruptMediaPlaceholder`) is reserved strictly for genuine failure. A missing poster is not
a failure. This is the actual defect-1 fix — `MediaImage` currently conflates the two.

## Receipts required

Red before green, asserting the user-visible symptom:
1. A video entry with `thumbnailMediaId == null` does NOT render the danger/red placeholder.
2. After completion the card still exposes a working replay affordance.
3. Pointer model: hover reveals, 3s inactivity hides while playing.
4. Paused and ended states do NOT auto-hide.
5. Touch model (default platform in tests): tap-when-hidden reveals without toggling playback.

Then on real hardware via `flutter run -d macos`, never the raw binary.

## Open risk carried from the decision record

First-frame-after-`initialize()` on macOS is Medium confidence, unverified on this hardware. The
poster slot absorbs either outcome. If the frame is blank, fill slot 2 with a captured thumbnail
(mirror `CameraVideoRecorder._captureThumbnail`, absent from the macOS recorder) rather than
redesigning the card.
