Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls
Supplements: 2026-07-24-non-evicting-acquire-for-passive-mount.md

## Context
Review found `_restart` releasing its slot and re-acquiring across the `await resolve()` gap, so a sibling's
freed-slot microtask could demote an already-ready card. Two remedies were offered: re-acquire before
releasing, or pass `evictUnpinned` when the card held a slot.

## Decision
Neither. `_restart` never releases: it bumps the generation and tears down the player only, and `_attemptLoad`
reuses the still-held token, touching it so LRU position matches a fresh acquire.

## Consequences
Re-acquire-before-release is impossible — the card's own token still occupies the registry, so a second
`acquire` is denied at cap, and `VideoSlots` has no swap API. `evictUnpinned` was rejected because it reverses
the record above (which names the resolver re-prepare as passive) and fails on its own terms: the freed slot
goes to a waking sibling first, so the restarting card would evict a third, innocent holder. Retention keeps
`none` rights, strictly less evicting. Guarded + mutation-verified: a re-prepare ending `unavailable` releases.
