Status: accepted
Date: 2026-07-29
Thread: prototype-design-alignment

## Context
C7 was specified as four target rows (hatch, container radius, play badge, duration chip) on `video_body.dart` alone. Three are unreachable inside that fence, each proven rather than argued. The hatch swap the slice's §0 resolution 6 mandates was actually made and reds `video_body_test.dart:400`, which asserts `find.byType(NeutralMediaPlaceholder)` and is one of N24's eight untouchable files; closing it needs `media_placeholders.dart`, outside the fence. The badge and chip anchors are physically occupied: `canAutoHideVideoControls` requires `isPlaying`, so at rest the overlay is visible, putting the 56px `VideoTransport` dead centre where the 44px badge goes and the full-width opaque `VideoControlBar` across the bottom strip where the chip goes.

## Decision
C7 ships ONLY its container-radius row (PR #84) and is closed as knowingly incomplete. The other three rows are deferred, not skipped. The root cause is that OQ-7 resolution (a) — keep the 200px player envelope, adopt the 130px poster chrome — is internally contradictory: the prototype tile is a poster with no controls, the app tile is a player whose transport and control bar already own the exact two anchors the badge and chip need.

## Consequences
- The prototype badge IS the app's transport. N3 already licenses moving its size, fill and border to prototype values — in `video_transport.dart`, which C7's fence forbids. Re-scope the badge as an N3 MSP with a 44px circle inside a >=48px target.
- The hatch is a two-line change once fenced correctly: `CrossHatchVariant.video` is already byte-exact (`hatchDark` `#D9C9AE` / `hatchMid` `#E2D3BA`, 6px/12px, 45deg). It needs a small `media_placeholders.dart` MSP so `NeutralMediaPlaceholder` can carry a variant. Pass NO colour overrides — `hatchColor` alpha-blends at 0.5 and would corrupt the exact pair.
- The chip needs a product ruling on its anchor before any dispatch; the prototype's bottom-8/right-9 is inside the control bar.
- Rejected: stacking a second identical-geometry hatch over the placeholder, or parking a 0x0 instance as its child, to satisfy the finder without the fence — both are test-shaped code. Rejected: forking `VideoTransport`'s whole contract into `video_body.dart`, which duplicates an N3-protected control in two places.
- Confirms the standing rule that a red in an N24 file is fixed in the implementation or the MSP stops. Here it correctly stopped the MSP.
