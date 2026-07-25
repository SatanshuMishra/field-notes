Status: accepted
Date: 2026-07-24
Thread: video-card-playback-controls

## Context
The overlay's auto-hide sits in tension with WCAG SC 1.4.13's Persistent clause. The spec cited
w3c/wcag#2007 as an open issue on 1.4.13; that issue is open but concerns SC 2.4.7 Focus Visible. Both
criteria are in play and the spec's numbers do not match.

## Decision
Keep the approved YouTube model: controls auto-hide after 3s idle even while the pointer rests inside the
card. The conservative alternative — add `&& !pointerInside` so hiding begins only after the pointer leaves,
which is fully 1.4.13-clean on desktop — was priced at one predicate term and one changed receipt, put to
the user, and declined.

## Consequences
Accepted residual, documented rather than papered over: a sighted mouse user who leaves the pointer
motionless inside the video for 3s loses the controls before the trigger is removed, which under a strict
1.4.13 reading is a violation. Any pointer movement restores them instantly with no dismiss step. Three
mitigations are mandatory and carry the compliance argument: focus-within suspends auto-hide entirely
(the direct SC 2.4.7 answer, so a focus ring can never be timed out), `ExcludeFocus` is forbidden so hidden
controls stay Tab-reachable, and `accessibleNavigation` disables the timeout outright for assistive-tech
users. Each has its own receipt and mutation.
