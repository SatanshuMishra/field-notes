Status: accepted
Date: 2026-07-25
Thread: video-card-playback-controls

## Context
Video cards decode eagerly in `initState` only to show a still frame, and the non-lazy `Column` feeds mount
every card at once. The eager design rested on one premise — "the macOS recorder writes no thumbnail"
(2026-07-24-video-decoder-slot-cap-and-structural-retry) — which is FALSE: the vendored plugin's
`CameraMacOSController.takePicture()` reads the live sample buffer, fed during recording by an
`AVCaptureVideoDataOutput` beside the movie output (`CameraMacosPlugin.swift:516,526,1028`).

## Decision
Ship poster-first: write a thumbnail at macOS capture, then gate decoder acquisition on user intent, keyed
strictly on `thumbnailMediaId != null` and NEVER on `defaultTargetPlatform`, so Android inherits it free.
Virtualization staged after — Day-detail cheaply, Today only if a post-Phase-1 profile demands it.

## Consequences
At-rest decoders drop 6 -> 0, playback 1. The bug was misallocation (cap consumed in MOUNT order, not
VIEWPORT order), never exhaustion — `LruVideoSlots` already bounded it at 6, so the cap stays 6 global and
the per-platform 6/3 split recommended earlier the SAME session is rejected. Six further rejections sit in the Rejected Alternatives section of docs/superpowers/specs/2026-07-25-video-poster-first-and-feed-virtualization.md. Blocked on PR #38 merging.
