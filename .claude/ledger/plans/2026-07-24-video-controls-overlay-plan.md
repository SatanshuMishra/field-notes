# Hover-reveal control overlay — implementation plan

Supersedes nothing; extends `.claude/ledger/plans/2026-07-24-video-card-controls-spec.md` with the executable
detail and the corrections that pass found. Where this file and the spec disagree, this file wins; where this
file and the code disagree, the code wins.

## Architecture

New file `lib/features/entry_cards/cards/video_controls_overlay.dart`. The overlay takes `transport` and
`controlBar` as `Widget` slots, so it imports none of the control files and has zero signature coupling to
them. Rejected: an overlay that imports `VideoTransport`/`VideoControlBar` and mirrors their parameter list.

Public surface:

    enum VideoControlModel { pointer, touch }
    VideoControlModel resolveVideoControlModel(TargetPlatform platform)
    bool canAutoHideVideoControls({controlsEnabled, isPlaying, focusWithin, accessibleNavigation})
    bool videoControlsVisible({canAutoHide, hidden})
    const Duration kVideoControlsHideDelay = Duration(seconds: 3)
    class VideoControlsOverlay extends StatefulWidget   // controlsEnabled, isPlaying, onToggle,
                                                        // transport, controlBar, hideAfter, model

The three pure functions mirror the existing `resolveTodayLayout(TargetPlatform)` precedent in
`lib/features/today/today_layout.dart`, unit-tested with no widget tree.

Internal tree, each wrapper load-bearing:

    MouseRegion(onEnter/onHover/onExit)
      Listener(onPointerDown/onPointerMove)
        GestureDetector(key: videoSurfaceTapKey, behavior: opaque, onTap: _onSurfaceTap)
          Focus(canRequestFocus: false, skipTraversal: true, onFocusChange: _onFocusWithin)
            AnimatedOpacity(opacity: _visible ? 1 : 0, duration: Motion.fade, curve: Motion.fadeCurve)
              IgnorePointer(ignoring: !_visible)
                Stack(fit: StackFit.expand)
                  Center(child: transport)
                  Positioned(left/right/bottom: _controlInset, child: controlBar)

`IgnorePointer` is mandatory: opacity zero still hit-tests, so without it an invisible mute toggle stays
clickable. `ExcludeFocus` is forbidden: hidden controls must stay Tab-reachable or a keyboard user can never
reveal them. `AnimatedOpacity` drops the subtree from semantics at alpha 0, which is what makes the receipts
assertable through semantics rather than widget internals.

Seam: `_VideoBodyState._layers` in `video_body.dart`. Replace the final two entries (the `Center(transport)`
and the `Positioned(controlBar)`) with one `VideoControlsOverlay`. Move `_controlInset` into the new file.
Wire `onToggle: _ready || _canClaimSlot ? _onTransportTap : null`, identical to the existing
`VideoTransport.onTap` guard, so surface click and button share one path and inherit the denial signal.

## Visibility state machine

Stored: `bool _hidden`, `Timer? _hideTimer`, `bool _focusWithin`, `bool _pointerInside`.

    canAutoHide = controlsEnabled && isPlaying && !focusWithin && !accessibleNavigation
    visible     = !canAutoHide || !hidden

Visibility is DERIVED, never latched. This is the whole correctness argument (see Obligation below).
`accessibleNavigation` comes from `MediaQuery.maybeOf(context)`.

activity := `_hidden = false; _hideTimer?.cancel(); if (canAutoHide) _hideTimer = Timer(hideAfter, _onElapsed);`

| Trigger | Effect |
|---|---|
| `MouseRegion.onEnter` / `onHover` | `_pointerInside = true`; activity |
| `MouseRegion.onExit` | `_pointerInside = false`; activity (re-arms, does not hide immediately) |
| `Listener.onPointerDown` / `onPointerMove` | activity (touch taps and scrubber drags) |
| `Focus.onFocusChange(true)` | `_focusWithin = true`; timer cancelled, `_hidden` cleared |
| `Focus.onFocusChange(false)` | `_focusWithin = false`; activity |
| timer elapses | `if (canAutoHide) setState(_hidden = true)`; `_hideTimer = null` |
| `didUpdateWidget` | `_sync()` |
| `dispose` | `_hideTimer?.cancel()` — mandatory |

There is only ever one live `Timer`, always cancelled before re-arming.

## The controls-enabled true -> false obligation

The thread records this as a new obligation. It is already subsumed: every path that drops `_ready` routes
through `_teardownPlayer`, which resets `_state`, so `isPlaying` falls in the same rebuild. Therefore the
obligation is satisfied for free IF AND ONLY IF visibility is derived rather than latched. A latched design
produces the exact failure the thread feared — a neutral placeholder with a transparent, uninteractable
transport and no route back to a decoder slot.

Consequence: no widget test can discriminate `controlsEnabled` from `isPlaying`. That coverage MUST be the
pure-function unit test. Do not write a widget receipt claiming to prove it. Keep `controlsEnabled` as a real
input anyway, as defence against a future reordering inside `_teardownPlayer`.

No reachable path evicts a playing card (`_syncPin` pins on playing, and the LRU victim scan skips pinned
holders). The true->false-while-hidden routes are playback/stream-error recovery and the registry's
drain-on-dispose.

## Platform split

`resolveVideoControlModel` = `platform == TargetPlatform.macOS ? pointer : touch`. Scope is macOS + Android;
do not enumerate platforms that cannot be tested.

| Behaviour | pointer (macOS) | touch (Android) |
|---|---|---|
| Reveal | hover, no click needed | surface tap while hidden |
| Surface tap, hidden | toggles play/pause | reveals only, playback untouched |
| Surface tap, visible | toggles play/pause | hides while playing, else no-op |
| Surface tap, not playing | invokes `onToggle` | no-op, the poster affordance is never dismissible |
| Hide trigger | 3s idle while playing | 3s idle while playing |

The divergence lives in exactly one method, `_onSurfaceTap`.

## Auto-hide policy (user decision, 2026-07-24)

Approved: keep the YouTube model. Controls auto-hide after 3s idle even while the pointer rests inside the
card. The conservative alternative (add `&& !pointerInside`, so hiding begins only after the pointer leaves)
was priced at one term and one receipt and was declined. See
`decisions/2026-07-24-overlay-auto-hide-keeps-the-youtube-model.md` for the accepted residual.

## Receipts

New file `test/features/entry_cards/cards/video_controls_overlay_test.dart`.

Harness additions (additive, default-preserving): `videoSurfaceTapKey`, a `useTargetPlatform(TargetPlatform)`
helper wrapping `debugDefaultTargetPlatformOverride` in setUp/tearDown, `videoSurfacePoint(tester, i)`, and an
optional `MediaQueryData data` parameter on `cardHarness`. The tearDown is mandatory: `flutter_test` throws if
`debugDefaultTargetPlatformOverride` is non-null at test end. Set the override explicitly for touch receipts
too, so intent survives a default change.

Anti-vacuity rule for every hide receipt: assert the VISIBLE precondition before asserting the hidden
postcondition. A bare `findsNothing` passes when the card never reached ready.

Vocabulary: revealed := `find.bySemanticsLabel('Pause video'|'Play video')` finds one (inside
`tester.ensureSemantics()` in try/finally). hidden := same finder finds nothing after
`pump(Motion.fade + 1ms)`. non-interactive := tapping the mute toggle's location does not change
`volumeCalls`. Never `pumpAndSettle` — it advances in 100ms steps and will fire the 3s timer behind you.

- **3 — pointer: hover reveals, 3s idle hides while playing.** macOS override. Mouse gesture moves onto the
  card (revealed), advance `kVideoControlsHideDelay` + fade (hidden AND non-interactive), move again
  (revealed). Mutation: delete `onHover:` from the `MouseRegion` — only assert C may red.
- **4a/4b — paused and ended never auto-hide.** Start from receipt 3's hidden state. Emit paused (revealed),
  advance the delay (still revealed). Repeat for completed; additionally tap transport and assert
  `playCalls == 1` and `seekCalls == [Duration.zero]`, matching the untouchable replay receipt. Green on
  arrival: falsification is the mutation — delete `&& isPlaying` from `canAutoHideVideoControls`; 4a and 4b
  must red and nothing else.
- **4c — controls-enabled true -> false while hidden.** Reach hidden, assert it, then
  `emitStateError(StateError('decoder lost'))`. Assert no `CorruptMediaPlaceholder` and that `'Play video'`
  is findable immediately, then still findable after another full delay (proves the timer was cancelled).
  Mutation: change `videoControlsVisible` to `=> !hidden`; only 4c may red.
- **5 — touch: tap-when-hidden reveals without toggling.** Android override. Tap a point 20px inside the top
  left, clear of the transport and control bar. Assert `pauseCalls == 0`, `playCalls` unchanged, revealed.
- **5b — the divergence discriminator.** macOS override, identical setup and tap point, assert
  `pauseCalls == 1`. Without 5b, an implementation whose surface tap never toggles on any platform passes 5.
  Prefer a real mouse gesture sequence over `tapAt`.
- **6 — keyboard focus suspends the hide timer.** Reach revealed, focus the scrub bar, advance the delay,
  assert still revealed. Mutation: drop `&& !focusWithin`.
- **7 — assistive tech disables the timeout.** `accessibleNavigation: true`, playing, advance the delay,
  assert still revealed. Mutation: drop `&& !accessibleNavigation`.
- **Pure-function unit test** (the only place `controlsEnabled` is discriminated from `isPlaying`): the four
  false rows, the one true row, and both `resolveVideoControlModel` rows.

## Ordered steps

0. Pre-flight: re-read `_layers`, `_ready`, `_isPlaying`, `_canClaimSlot`, `_onTransportTap`, and the shape of
   the landed denial signal. Note drift before writing.
1. Pure functions as stubs throwing `UnimplementedError`; write the unit test; red; implement; green.
2. Create `VideoControlsOverlay` with visibility hard-wired true — no timer, no `MouseRegion`, no tap handler.
   Wire the seam. Move `_controlInset`. **Full existing suite must stay green.** Do not proceed if anything
   reds; this isolates "wrapping broke something" from "hiding is wrong".
3. Timer, `_hidden`, `AnimatedOpacity`, `IgnorePointer`, `Listener`, touch branch. Receipt 5 red-first.
4. `MouseRegion` and pointer branch. Receipts 3 and 5b red-first.
5. Focus sentinel and `accessibleNavigation`; the `cardHarness` parameter. Receipts 6 and 7.
6. Receipts 4a/4b/4c; run the three named mutations and record that each reds exactly its own receipt.
7. Confirm `dispose()` cancels the timer. Blob-hash `video_body_test.dart` and `media_image_test.dart`
   against HEAD to prove the audit trail is intact.
8. `flutter analyze` clean; full suite reconciled against the 838 baseline; `wc -l` both card files.
9. Hand to the human for `flutter run -d macos`, never the raw binary.

Steps 4a/4b/4c cannot be red-first — the predicate that makes 3 and 5 pass already satisfies them. Naming the
mutation is the honest form of the gate; crippling the implementation to manufacture red is theatre.

## Spec corrections this plan carries

- The spec says "do NOT hand-roll a seek-then-play for replay". `_play` does exactly that and the untouchable
  receipt asserts `seekCalls == [Duration.zero]`. Code and receipt win; do not "fix" it.
- The spec's `ended` state implies a distinct replay affordance. None exists and none is needed —
  `VideoTransport` paints play whenever `!isPlaying` and `_play` handles the seek.
- Touch double-tap left/right thirds for +/-10s: out of scope. Absent from `completion_criteria`, and a
  `DoubleTapGestureRecognizer` would delay single-tap resolution and make tap-to-reveal feel laggy.
- Scrubber hover-thickening on desktop: do not implement. Cosmetic, would touch a file with a protected
  receipt asserting a 48px height.
- The spec's five-state machine collapses to visible/hidden plus a suspension predicate; `visibleActive` and
  `visibleIdle` differ only in whether the timer is armed.
- The spec cites w3c/wcag#2007 as an open issue on SC 1.4.13. That issue is open but concerns SC 2.4.7 Focus
  Visible. Both criteria are in play; the numbers in the spec do not match.
- The spec's `AnimatedOpacity` cost warning is overstated for the steady states: paint returns early at alpha
  0 and the visible subtree becomes its own repaint boundary. Cost is confined to the transition. Do not
  pre-optimise; watch it on hardware.

## Open risks

- Nothing on this branch is hardware-confirmed. The overlay is the first piece whose entire value is felt at
  the pointer, so `flutter run -d macos` is not a formality.
- `AnimatedOpacity` on real macOS is unmeasured; six visible cards means six extra layers. [unverified]
- The 3s delay is a design choice, not a platform fact. Expose it as `hideAfter` so hardware can retune it
  without touching receipts.
- `video_body.dart` is 674 lines. The controller-extraction seam remains deferred.
- The voice card's 40x40 toggle stays below the 48 floor and gains no overlay. Out of scope, unchanged.
