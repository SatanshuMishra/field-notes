# Session 2026-07-25-02 — video-card-playback-controls

## Where it started
Resumed on the explicit slug. Verification against code found ledger drift immediately: the thread spine
said "28 commits ahead" and carried a stale self-contradicting paragraph ("Six of nine criteria met in
code") directly beneath a line claiming all nine. Actual was 35. Corrected before any work. The user then
gave the follow-up that the previous session was told to wait for.

## What shipped
Three commits, `d421adb..e086f46`, then the branch's FIRST publish and PR #38.

- `d421adb` — the spine drift correction.
- `8fe882f` — the reported follow-up, two files. `video_body.dart`: `_videoHeight = 200` replaced by
  `_videoAspectRatio = 21/9` + `_videoMinHeight = 200`, applied through a new `_previewBox()` helper wrapping
  `ConstrainedBox(minHeight) -> AspectRatio`. The `Center` around `buildSurface()` removed so the tight
  `StackFit.expand` constraints actually reach the surface. `video_player_impl.dart`: `buildSurface()` now
  returns `FittedBox(fit: cover, clipBehavior: hardEdge)` over a ratio-carrying `SizedBox(width: ratio,
  height: 1)` instead of a bare `AspectRatio`.
- `e086f46` — decision record + PROJECT.md index + spine next_step.
- PR #38 — https://github.com/SatanshuMishra/field-notes/pull/38, base `main`, OPEN, MERGEABLE, 54 files,
  +7348/-267. The branch had NO upstream and had never been pushed; `git push -u` was its first publish.

## Tried and failed
- **The codebase-analyst's map was incomplete and the implementer caught it.** The map named two
  `_videoHeight` uses (the `SizedBox` and `CorruptMediaPlaceholder`); there were FOUR. It missed
  `NeutralMediaPlaceholder(height: _videoHeight)` and `MediaImage(height: _videoHeight)`. Both were inert —
  non-positioned children of a `StackFit.expand` Stack already receive tight constraints — but leaving a
  stale 200 inside a 514px box would have been a lie in code, so both were dropped. Treat analyst maps as
  strong hints, not exhaustive inventories; grep the constant yourself before deleting it.
- **The implementer reported the working tree dirty "contrary to the snapshot."** Correct observation,
  correctly attributed: it was the orchestrator's own spine-drift fix, made ~14 minutes before its first
  edit. No conflict. Worth noting that mid-session orchestrator ledger edits will read as anomalies to
  fenced subagents; say so in the dispatch next time.
- **The green suite is blind to this change and that was verified, not assumed.** 856 stayed green because
  the widget harness is 360px wide (`test/features/entry_cards/support/entry_cards_harness.dart:13`), which
  lands exactly on the 200px floor — geometry identical to before. The entire responsive band above ~450px
  card width has zero coverage. Styling is exempt under the test admission gate, so no receipt was added,
  but the green must not be cited as evidence for this change.
- **Three ratio alternatives rejected.** A `maxHeight` cap reinstates precisely the flat-height behaviour
  the user complained about, just at a larger number. 16:9 matches the source but yields 675px at the user's
  ~1200px card width (one card fills the viewport). 3:1 crops ~40% off a 16:9 source and cuts off faces.
  21:9 crops ~24%. The `minHeight: 200` FLOOR was kept because a pure ratio makes the preview SHORTER than
  today on narrow windows.
- **Slicing the PR was rejected.** The overlay depends on the slot registry, which depends on the
  `EntryVideoPlayer` parity work; each slice would land on `main` in a state that violates the green-branch
  invariant. Recorded in the PR body with a suggested reading order instead.
- No hardware verification was attempted. Nothing in this session is confirmed on real macOS.

## Verification
- `flutter analyze` — expected `No issues found!`; observed clean twice, once after the implementer returned
  and once again at HEAD immediately before the push.
- `flutter test` — expected the 856 baseline; observed `856 passing` twice, both times re-run by the
  orchestrator independently rather than inherited from the subagent's claim.
- Diff inspected directly against the implementer's reported diff — byte-for-byte match, no drift.
- `git diff -U0 -- lib/ | grep -E '//|/\*'` — no comments added, invariant held.
- Reachability of the flagged `entry_card.dart:102` inconsistency checked before deciding to skip it:
  `todayVideoPlayerFactory` returns a NON-nullable `EntryVideoPlayerFactory`
  (`lib/features/today/today_providers.dart:39`) and `day_detail_entry_tile.dart:34` passes a const function,
  so the null-factory branch is unreachable in production.
- Pre-push state: 38 ahead / 0 behind `origin/main` (`5cb5bad`), clean tree, no pre-existing PR.
- Post-create: `gh pr view 38 --json` returned `state: OPEN`, `mergeable: MERGEABLE`, `baseRefName: main`.

## Running state
- none. No subagents in flight, nothing backgrounded, working tree clean.

## Deferred + open
- **THE HARDWARE RUN REMAINS THE ONLY REAL GATE.** Unchanged from session 01. Four of the nine completion
  criteria say "human-confirmed on macOS hardware" in their own text, so the DoD gate still refuses `done`.
- `lib/features/entry_cards/entry_card.dart:102` still hardcodes `CorruptMediaPlaceholder(height: 200)` for
  the null-factory branch, so it will not track the new width-driven sizing. Verified unreachable in
  production (see Verification); left alone deliberately rather than widening the diff.
- Cover-crop severity on portrait source video is unmeasured. A 9:16 clip in a 21:9 box becomes a narrow
  horizontal band. `_videoAspectRatio` is a single named constant precisely so the hardware run can retune
  it without touching receipts — the same affordance `hideAfter` gives the overlay.
- At 2000px card width the preview is 857px tall. Deliberate: there is no maximum cap.
- Everything inherited from sessions 09/10/01 is still open: controller extraction from `video_body.dart`
  (672 lines), voice-card twins (uncapped eager init, no retry affordance, 40x40 tap target), viewport
  gating, `AnimatedOpacity` cost unmeasured, readout contrast ~2.9:1, and the whole `post-ship-hardening`
  sibling thread (integration tests writing into the real container, export-ZIP extensions unconfirmed).

## Pick up here
The user has asked for a TEACHING pass, not implementation work: a second look at the 6-slot concurrent
video decoder cap, explained from the ground up for a reader with MINIMAL domain understanding. Full brief
in the thread's Next Step. This is deliberately kept inside this thread rather than opened as a new one —
the cap was decided here, and a "second look" may revise it.

## Demoted from decisions/2026-07-25-video-preview-width-driven-and-cover-filled.md (20-line cap)

Measured heights from a throwaway probe run outside the repo (nothing written under `test/`):
width 200 -> 200x200 (the exact wider-than-tall crossover), 360 -> 200, 400 -> 200 (floor), 640 -> 274.29,
1200 -> 514.29, 2000 -> 857.14. With `StickerCard`'s 16px horizontal padding
(`lib/design/widgets/sticker_card.dart:9`) the crossover corresponds to ~232px of card outer width, and
`macos/Runner/MainFlutterWindow.swift` sets no minimum window size — so below that the box is taller than
wide. Flagged as the one honest edge; not reachable at any realistic window size.

Why the cover input is the plugin-guarded `aspectRatio` and not `controller.value.size`: the plugin already
returns `1.0` when `!isInitialized || size.width == 0 || size.height == 0`, and again when the quotient is
`<= 0`, so `Size.zero` never reaches the division. That guard still leaks two values, since `NaN <= 0` and
`+inf <= 0` are both false; the local `reported.isFinite && reported > 0` check closes exactly those. A
literal `height: 1` keeps the FittedBox source strictly positive on both axes, so `RenderFittedBox`'s
`destination.width / source.width` can never be `0/0`. Raster quality is unaffected by the 1-unit-tall
child: `.file(...)` defaults to `VideoViewType.textureView`, which maps to a `Texture` layer composited by
the GPU at device resolution, not rasterized at the child's logical size.

FittedBox cover behaviour probed directly at 640x274.29 for ratios 1.78 / 0.5625 / 1.0 / 2.35: uniform
`scaleX == scaleY` in every case (no distortion), box filled edge-to-edge including portrait 9:16,
`takeException()` null. No cross-hatch can show through.
