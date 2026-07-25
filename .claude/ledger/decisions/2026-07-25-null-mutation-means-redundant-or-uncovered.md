Status: accepted
Date: 2026-07-25
Thread: video-card-playback-controls

## Context
Twice in one session a mutation reverted a condition and the suite stayed green. The symptom is identical
and the correct response is opposite, so treating "mutation reds nothing" as one signal is wrong half the time.

## Decision
Determine which of two things is true before acting. If the behaviour is ALREADY pinned by another receipt,
the condition is redundant — collapse it. If no receipt covers it, the condition is uncovered — keep it and
write the missing receipt. Never accept the green as evidence either way.

## Consequences
The voice card's `_preparedMediaId` was redundant (the reordering it guarded was already pinned by the twin
receipt) and was collapsed. The overlay's `_hidden` latch-clear looked identical but was uncovered: derivation
handles the STOP transitions, while only the latch-clear handles RESUME, where `canAutoHide` returns true
against a still-latched `_hidden` and the controls vanish instantly. Its receipt must be driven by playback
state alone — a gesture-driven one masks the defect, since pointer paths clear `_hidden` via `onPointerDown`.
Four vacuous or unpinned receipts have now been caught by mutation on this branch and none by reading.
