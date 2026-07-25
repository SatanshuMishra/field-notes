# Video card: eager player, poster slot, hover-reveal controls

Status: accepted
Date: 2026-07-24

## Context

Hardware test of PR #35 (merged, 5cb5bad) confirmed playback works but surfaced two
pre-existing video-card defects, invisible before because nothing played at all:

1. Every video card renders the RED crosshatch placeholder instead of a preview.
2. After playback the card is a static, non-interactive frame — no replay, scrub, pause, mute.

## Root causes (verified, not inferred)

Defect 1 is three stacked faults:
- `CameraMacosVideoRecorder.stop()` builds `VideoRecording` with no `thumbnail:` argument
  (camera_video_recorder.dart:345); its non-macOS sibling captures one via `takePicture()`
  (:77, :98). Every macOS video therefore persists `thumbnailMediaId: null`.
- `MediaImage` maps a null id to `_corrupt()` (media_image.dart:43) — the RED
  `CorruptMediaPlaceholder`. "Never had a poster" is rendered identically to "file is broken."
- Existing rows already carry null, so fixing capture alone cannot heal them.

Defect 2 is an architectural dead end:
- `EntryVideoPlayer` lacks `seek()`, `positionStream`, `duration`; `VideoPlaybackState` has no
  `completed` member. `EntryAudioPlayer` has all four — the voice card works because of it.
- `_VideoBodyState._surfaceReady` latches true and returns a bare `VideoPlayer` with zero chrome
  (video_body.dart:114-118); `_started` permanently nulls the only play affordance (:123).
  One-way door, no path back.

## Decision

Rebuild the video card on the voice card's proven architecture rather than patching the latch:
eager prepare in `initState`, never swap the widget tree, card always owns its controls.

- POSTER IS A SLOT, resolved in order: captured thumbnail if present, else the
  initialized-but-paused first frame, else the NEUTRAL placeholder. Red is reserved strictly for
  genuine failure (`_unavailable`).
- Bring `EntryVideoPlayer` to parity with `EntryAudioPlayer` (seek, position stream, duration,
  `completed` state mapped from `VideoPlayerValue.isCompleted`).
- Control surface: hover-reveal overlay modelled on YouTube's interaction model, serving macOS
  pointer and Android touch from one codebase. User-chosen over an always-visible bar.

## Rejected alternatives

- Native poster extraction (AVAssetImageGenerator + MediaMetadataRetriever) cached to the blob
  store: best at feed scale, but needs native code on two platforms plus a second blob migration
  weeks after PR #35's. Rejected as disproportionate; revisit only if eager init proves too costly.
- Third-party thumbnail packages: `video_thumbnail` and `flutter_video_thumbnail` have NO macOS
  support. `flutter_video_thumbnail_plus` claims it but its public repo lags the published archive
  and ships no macos/ source — provenance gap. `video_compress` has real macOS support but is a
  whole compression engine for a thumbnail need, unpublished for 17 months.
- Capture-time thumbnail alone: fixes new videos only, leaves existing rows red forever.

## Load-bearing API facts (video_player 2.13.0, pinned)

- `play()` alone replays: it seeks to zero internally when `position == duration`. No app-side
  seek needed for replay — only for scrubbing.
- `isCompleted` exists (added 2.7.2). Detection is `addListener` + `value.isCompleted`; there is
  no dedicated completion callback.
- No mute API. `setVolume(0.0)` is the idiom; restore a remembered value to unmute.
- The package ships NO control bar. Only `VideoProgressIndicator` (with `allowScrubbing`) and
  `VideoScrubber`. All play/pause/volume chrome is app-owned.

## Open risk

First-frame-after-`initialize()` on macOS is documented to work and the known black-first-frame
bug is iOS-labelled, but this is Medium confidence and unverified on this hardware. The poster
slot design deliberately absorbs either outcome — if the frame is blank, a captured thumbnail or
native poster fills the same slot with no card redesign.
