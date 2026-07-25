Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
A denied explicit slot claim was a silent no-op while the transport still announced `'Play video'` and
reported `enabled: true`. The user tapped and nothing happened, with no feedback. Review named the defect
but not the remedy.

## Decision
A `Semantics(liveRegion: true)` busy notice in the card plus a `hint` on the transport, transport left
enabled so retry stays reachable. NOT `SemanticsService.announce`: deprecated as of Flutter 3.35, so it would
break the clean analyze, and the SDK prefers implicit Semantics because Android deprecated announcement
events for forcing TalkBack to flush its speech queue.

## Consequences
The denial bit is set only when a denial arrives with `evictUnpinned` rights — the marker already
distinguishing user-driven from passive acquisition — and is sticky across `_enterWaiting` so a later passive
denial cannot erase a visible signal. A visible notice beat a semantics-only fix, which would leave sighted
users with a dead-looking button. Never routes to red; two enabled-but-dead-toggle tests now assert refusal.
