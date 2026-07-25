Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls
Supplements: 2026-07-24-non-evicting-acquire-for-passive-mount.md

## Context
Review found `_restart` releasing its slot and re-acquiring across the `await resolve()` gap, so a sibling's
freed-slot microtask could demote a card that was already ready. The review offered two remedies:
re-acquire before releasing, or pass `evictUnpinned` when the card held a slot.

## Decision
Neither as written. `_restart` never releases: it bumps the generation and tears down the player only, and
`_attemptLoad` reuses the still-held token, touching it so LRU position matches a fresh acquire. Literal
re-acquire-before-release is impossible — the card's own token still occupies the registry, a second
`acquire` is denied at cap, and `VideoSlots` has no swap API.

## Consequences
`evictUnpinned` was rejected because it reverses the record above, which names the resolver re-prepare as
passive. It also fails on its own terms: the released slot is taken by a waking sibling on an earlier
microtask, so the restarting card would evict a third, innocent holder — roughly `cap` extra create/dispose
cycles on a bulk resolver swap. Retention keeps `none` rights, so it is strictly less evicting than before.
New hazard introduced and guarded: a re-prepare ending `unavailable` would strand a slot, so
`_markUnavailable` releases. Both the core behaviour and the leak guard are mutation-verified, each
reddening exactly its own receipt.
