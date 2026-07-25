Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls
Supplements: 2026-07-24-video-decoder-slot-cap-and-structural-retry.md

## Context
`acquire` evicts the LRU unpinned holder and denies only when every holder is pinned. Review found two consequences of giving passive card mount that power: a wake/evict STAMPEDE (one `release` makes every waiting card after the first evict a healthy holder, which re-enters `waiting` and repeats — on a 20-video day one failed load cascades into ~14 player create/dispose cycles), and first-paint inversion (all cards mount before any eviction, so the LAST `cap` cards keep slots while the on-screen top cards go neutral).

## Decision
Eviction rights are no longer implicit. Passive acquisition — initial mount, the slot-freed wake-up, and
the resolver re-prepare — acquires WITHOUT eviction rights and accepts denial into `waiting`. Only
user-driven acquisition may evict. This reverses a deferral recorded in the thread earlier the same day:
the stampede is a live pathology, not the UX nicety the deferral assumed, and one change fixes the
inversion for free.

## Consequences
First paint wins the slots in document order, which is what criterion 1 needs, and a release wakes waiters
without churning healthy cards. Viewport-aware allocation stays deferred and remains a clean later
addition. Refined by 2026-07-24-playback-recovery-counts-as-interactive.md. Mechanism detail:
sessions/2026-07-24-10-video-card-playback-controls.md.
