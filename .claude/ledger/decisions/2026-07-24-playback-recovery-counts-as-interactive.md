Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls
Supplements: 2026-07-24-non-evicting-acquire-for-passive-mount.md

## Context
That record says "only explicit user interaction acquires WITH eviction rights." Read literally it puts
mid-playback error recovery in the passive class, which is how it was first implemented. Review flagged
the record as contradicting the shipped code, so the ambiguity is settled here rather than left for a
future reader to "correct" back.

## Decision
`_recoverFromPlaybackError` re-acquires WITH eviction rights. A card mid-playback is the direct
continuation of an explicit user action, so recovery is user-driven, not passive. The passive class is
initial mount, the slot-freed wake-up, and the resolver re-prepare.

## Consequences
Without rights, a transient decoder error on the video being WATCHED drops it to neutral while cards the
user is not watching keep their decoders. The stampede that motivated non-evicting passive acquire does not
transfer: a mid-playback error is singular and already bounded by the retry budget and reset-on-`ready`. Mutation-verified — reverting the single rights argument reds exactly its receipt and nothing else.
