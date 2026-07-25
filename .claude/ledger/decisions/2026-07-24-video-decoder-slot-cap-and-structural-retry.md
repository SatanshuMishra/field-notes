Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
Eager per-card `initialize()` in non-lazy feeds can exhaust the bounded decoder pool and render the RED
placeholder this branch exists to remove (per 2026-07-24-eager-init-decoder-ceiling).

## Decision
A hard-capped LRU slot registry (`VideoSlots`, cap 6, pin-while-playing, slot-freed notification) gates
`_prepare()`; the `initState` trigger is UNCHANGED so the overlay builds on a stable trigger. Failures are
classified STRUCTURALLY, never diagnostically: cap-denied = `waiting` (no error raised); missing or
zero-length file = red with zero retries; anything else = 2 bounded retries behind an 8s load timeout.
Viewport gating DEFERRED; slivers and interaction gating REJECTED.

## Consequences
Retryability is UNREADABLE from the error: macOS never reads `error.code` (FVPVideoPlayer.m:380-401), Android passes `details: null` (ExoPlayerEventListener.java:131-137), and `initialize()` has no timeout (video_player.dart:698) so exhaustion may STALL rather than throw — never string-match a localized message.
Interaction gating cannot meet criterion 1: the macOS recorder writes no thumbnail (camera_video_recorder.dart:345 vs :77). Cap 6 is OUR design choice, not a platform fact [unverified].
Beyond-cap cards show neutral, never red. Voice stays uncapped (noted twin). Controls-enabled can now go true -> false, which the overlay must absorb by forcing the always-visible state.
Full source-verified detail: sessions/2026-07-24-10-video-card-playback-controls.md.
