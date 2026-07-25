Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
A denied explicit slot claim was a silent no-op while the transport still announced `'Play video'` and
reported `enabled: true`. The user tapped and nothing happened, with no feedback of any kind. Review named
the defect but not the remedy.

## Decision
A `Semantics(liveRegion: true)` busy notice rendered in the card, plus a `hint` on the transport, with the
transport left enabled so the retry stays reachable. Not `SemanticsService.announce`: it is `@Deprecated` as
of Flutter 3.35, so using it would cost the clean `flutter analyze`, and the SDK's own guidance prefers
implicit `Semantics` because Android deprecated announcement events for forcing TalkBack to flush its
speech queue.

## Consequences
The denial bit is set only when a denial arrives with `evictUnpinned` rights — the marker that already
distinguishes user-driven from passive acquisition — and is sticky across `_enterWaiting` so a later passive
denial cannot silently erase a visible signal. A visible notice was chosen over a semantics-only fix because
the latter leaves sighted users with an identically-looking dead button. The notice never routes to
`CorruptMediaPlaceholder`; all four receipts assert its absence. Two existing tests that codified an
enabled-but-dead toggle were rewritten to assert the announced refusal instead.
