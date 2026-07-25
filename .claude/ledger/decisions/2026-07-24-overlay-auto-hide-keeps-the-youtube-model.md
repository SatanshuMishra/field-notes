Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
The overlay's auto-hide sits in tension with WCAG SC 1.4.13's Persistent clause. The spec cited w3c/wcag#2007
as an open issue on 1.4.13; that issue is open but concerns SC 2.4.7 Focus Visible. Both criteria are in play
and the spec's numbers do not match.

## Decision
Keep the approved YouTube model: controls auto-hide after 3s idle even while the pointer rests inside the
card. The conservative alternative — `&& !pointerInside`, so hiding begins only after the pointer leaves,
fully 1.4.13-clean on desktop — was priced at one predicate term and one changed receipt, put to the user,
and declined.

## Consequences
Accepted residual: a sighted mouse user who leaves the pointer motionless for 3s loses the controls before
the trigger is removed, a violation under a strict 1.4.13 reading. Any movement restores them instantly.
Three mandatory mitigations carry the compliance argument, each with a receipt and mutation: focus-within
suspends auto-hide (the SC 2.4.7 answer), `ExcludeFocus` is forbidden, `accessibleNavigation` kills timeouts.
