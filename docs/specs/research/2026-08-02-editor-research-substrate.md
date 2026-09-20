# Research — single-TextField markdown-as-source substrate limits

Date: 2026-08-02. External research (Flutter framework source, api.flutter.dev, flutter/flutter tracker).
Feeds the combined rich-editor + OQ-6 spec. THE DECISIVE DOCUMENT of the four.

## BLUF

**Yes, with exact and non-negotiable caveats.** A single `TextField` driven by a custom
`TextEditingController.buildTextSpan` CAN deliver live rich rendering of headings, bold/italic/underline/
inline code, bullet lists, ordered lists and quotes. Mixed styling within one paragraph is core Flutter
and is not fragile.

Four things are NOT achievable as stated:

1. Markdown markers (`# `, `**`) can be **visually hidden but never removed from the character stream**.
2. **Text cannot wrap around an inline `WidgetSpan`.** Hard framework limit.
3. **Tap-to-toggle inside the span tree throws an assertion on iOS.**
4. Quote bars / hanging indents need a **second hand-synced layout pass** — the exact "complex but
   fragile" shape to avoid, so it must be budgeted as real ongoing cost, not a detail.

## Feature feasibility

| Feature | Feasible? | Mechanism | Risk |
|---|---|---|---|
| Heading size/weight | Yes | `buildTextSpan` styles the line's run larger/bolder; markers kept, styled near-invisible | Low — headings own a full line, no same-line size hazard |
| Bold / italic / underline / inline code | Yes | Per-run `TextSpan` style within one paragraph — core `RichText` | Low |
| Hiding `**` / backtick markers | Partial | Near-zero size, transparent, negative letter-spacing — **never delete** | Medium — markers still occupy caret stops, still selectable/copyable/voiced |
| Bullet / ordered markers | Yes | Literal `- ` / `1. ` stay in string, styled, or line-start `WidgetSpan` | Low-Med — renumbering is an editing-transform problem, not rendering |
| Quote bar spanning wrapped lines | Yes, not free | `CustomPaint` overlay via `TextPainter.computeLineMetrics()` | **HIGH** — hand-maintained second layout pass; drifts on resize, a11y text-scale, scroll |
| Checkbox to-do (visual) | Yes | Small `WidgetSpan` or glyph sized to one line | Medium |
| Checkbox to-do (**tappable in text**) | **NO on iOS** | `TextSpan.recognizer` | **HARD BLOCK** — #187598 |
| Inline photo (U+FFFC `WidgetSpan`) | Yes, narrowly | `WidgetSpan` sized to one line | Med-High — several open caret bugs |
| **Text wrapping around inline photo** | **NO** | n/a | **HARD LIMIT** — #82595 |
| Type-to-transform (`# `, Enter continues list) | Yes | `TextInputFormatter` / `Actions`+`Shortcuts` | **HIGH** — must gate on `composing.isCollapsed` |
| Undo/redo (typing) | Yes, free | `UndoHistory` / `UndoHistoryController` | Low for pure typing; **HIGH** once programmatic mutation layers on |
| Undo/redo (macOS system Cmd+Z) | **`[unverified]`** | no macOS equivalent of iOS PR #98294 found | must be manually tested |
| Selection toolbar | Yes | `EditableText.contextMenuBuilder` + `AdaptiveTextSelectionToolbar` | Medium — genuine iOS/macOS widget divergence |

## The crux: buildTextSpan must match controller.text exactly

Signature: `TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing})`
— [api.flutter.dev](https://api.flutter.dev/flutter/widgets/TextEditingController/buildTextSpan.html).

The dartdoc states no length rule in prose; it is enforced structurally. `RenderEditable` computes the
caret via `TextPainter.getOffsetForCaret(TextPosition(offset: selection.start...))`, treating
`selection.baseOffset`/`extentOffset` — defined against raw `controller.text` — as direct string indices
into the same text the `TextPainter` laid out (`packages/flutter/lib/src/rendering/editable.dart`).

Decisive, from a Flutter text-input maintainer on [#159171](https://github.com/flutter/flutter/issues/159171):

> "the `TextInputPlugin` in the engine is unaware of this override and the result of `buildTextSpan`...
> only aware of the raw text value you set on the controller... We haven't yet implemented a way for the
> engine to be aware of `WidgetSpan`s and their concrete lengths." — Renzo-Olivares

**Conclusion `[High confidence — source + maintainer statement + independent corroboration]`:** the plain
text returned from `buildTextSpan` must match `controller.text` character for character. Restyle a `#`
into near-invisibility; never delete it. Deleting desyncs caret, arrow-key navigation and hit testing.

## WidgetSpan in editable text — partially-supported, open edges

| Issue | State | Shows |
|---|---|---|
| [#82595](https://github.com/flutter/flutter/issues/82595) | **OPEN since 2021**, P3 | `WidgetSpan` in a TextField is an unbreakable block; cannot participate in line-wrap/reflow. **The standing hard limit.** |
| [#159171](https://github.com/flutter/flutter/issues/159171) | OPEN, P2, found 3.24/3.27 | Nested focusable widget in a `WidgetSpan`: arrows/delete corrupt child content on macOS/Windows. Engine unaware of span length. |
| [#187598](https://github.com/flutter/flutter/issues/187598) | OPEN, P2, **reproduced on 3.44.1** | `TapGestureRecognizer` in `buildTextSpan` throws `'readOnly && !obscureText'` assertion on iOS. Works on web. |
| [#90355](https://github.com/flutter/flutter/issues/90355) | OPEN, P3 | Oversized `WidgetSpan`s clip and mis-hit-test — TextField height is line-count x line-height |
| [#96147](https://github.com/flutter/flutter/issues/96147) | OPEN | `WidgetSpan` on the first line positions incorrectly |
| [#107432](https://github.com/flutter/flutter/issues/107432) | OPEN | Caret lands at wrong x-offset after typing near a `WidgetSpan` |
| [#126497](https://github.com/flutter/flutter/issues/126497) | OPEN | Wrong cursor location via `paragraph.getBoxesForRange` |
| [#63863](https://github.com/flutter/flutter/issues/63863) | OPEN since 2020 | `WidgetSpan` in a `buildTextSpan` override throws `dimensions != null` in some configs |
| #161213, #153005, #150864, #128305, #131669 | CLOSED 2022-2024 | The team HAS been incrementally hardening this path |

Safe zone: small, non-interactive, single-line-height, non-tappable content. That fits an inline photo
token; it does not fit a tappable checkbox or an embedded input.

## Type-to-transform

Mechanism: `TextInputFormatter.formatEditUpdate`, via `TextField.inputFormatters`. Official docs carry an
explicit warning, verbatim:

> "Text modification should only be applied when text is being committed by the IME and not on text under
> composition (i.e., only when `TextEditingValue.composing` is collapsed)."
> — [TextInputFormatter docs](https://api.flutter.dev/flutter/services/TextInputFormatter-class.html)

Mutating during active composing (CJK input, iOS predictive text/autocorrect) corrupts the IME session.
"Enter continues a list" goes through `Actions`/`Shortcuts` or a post-edit listener; the same gate applies.
`[High confidence — explicit official warning]`

## Undo/redo

Free for typing via `UndoHistory`/`UndoHistoryController`; Cmd+Z bound automatically.

- iOS system undo needed a dedicated framework change — [PR #98294](https://github.com/flutter/flutter/pull/98294),
  merged 2023-03-08. The author's own words: "I don't love this approach, since it feels a little bit
  hacky and requires a breaking change to the `TextInputClient` interface."
- **macOS system undo parity: `[unverified]`.** No macOS `NSUndoManager` equivalent PR/issue found. Must be
  manually tested before the spec assumes parity.
- [#130881](https://github.com/flutter/flutter/issues/130881) OPEN — "Undo/Redo history disappears on
  Japanese keyboard" — the built-in stack already desyncs from IME state with **no custom code involved**.
  Layering programmatic mutation on top compounds it.

## Selection toolbar

`EditableText.contextMenuBuilder` (Flutter 3.7.0+, replacing deprecated `toolbarOptions`/`selectionControls`
— [migration guide](https://docs.flutter.dev/release/breaking-changes/context-menus)). Build from
`editableTextState.contextMenuButtonItems`, return
`AdaptiveTextSelectionToolbar.buttonItems(anchors: editableTextState.contextMenuAnchors, ...)`.

Platform divergence is real: `CupertinoTextSelectionToolbar` (iOS) vs `CupertinoDesktopTextSelectionToolbar`
(macOS). Must be validated on both. Anchor position derives from the same span/selection geometry, so any
upstream caret fragility propagates into toolbar placement.

## HARD LIMITS — for the spec, stated plainly

1. **No text-wrap-around-inline-object.** A `WidgetSpan` is always an unbreakable block matching line
   height. Body text cannot flow down its side. [#82595](https://github.com/flutter/flutter/issues/82595),
   open since 2021.
2. **No per-block layout.** Quote bars, code backgrounds, hanging indents tracking wrapped lines have no
   native primitive — hand-built `computeLineMetrics()` overlay, recomputed on every edit/resize/font-scale.
3. **Markers hidden, never deleted.** "The `#` is simply gone" WYSIWYG is not achievable. Closest is
   "present but nearly invisible" — still a caret stop, still selectable/copyable, still voiced by
   accessibility unless separately suppressed.
4. **No tap-to-toggle in the span tree on iOS.** Tappable checkboxes must be separately hit-tested overlays.
5. **No nested focusable widgets in a `WidgetSpan`.**
6. **`WidgetSpan` sizing constrained to the line's computed height** or it clips and mis-hit-tests.

## Pre-mortem — what fails first

1. **Type-to-transform x undo/redo x IME composing.** The only part doing repeated programmatic mutation of
   a live buffer during typing, and every piece is separately documented as fragile. Expect it in the first
   CJK/autocorrect QA pass, not months later.
2. **WidgetSpan caret/line-boundary edge cases** — backspace-at-photo, arrow-across-photo, oversized clipping
   map onto four still-open issues.
3. **Block-decoration geometry drift** — the `computeLineMetrics` overlay desyncs on resize, a11y scaling or
   mid-scroll. Looks fine at rest in manual QA; shows up after ship.
4. **iOS vs macOS toolbar divergence**, caught late if iOS is the daily test target.
5. **Accessibility of hidden markers** — VoiceOver voices near-invisible `#`/`**` unless semantics are
   suppressed. Never surfaces in visual QA. Lowest detection probability, highest severity.

**What would change these findings:** a release making the engine aware of `WidgetSpan` concrete length
(the #159171 root cause), a close on #82595 with real inline wrap, or a documented macOS `NSUndoManager`
integration. Re-check against the SDK actually shipped.

## CONSEQUENCE FOR OQ-6 — must be resolved in the spec

**Float-with-wrap is impossible inside an `EditableText`, at the framework level.** This corroborates and
sharpens the earlier OQ-6 finding that Flutter has no text-exclusion API.

The distinction the spec must draw: OQ-6's decision already says **write mode is plain editable text**. So
the float and wrap can only ever live in the **read/display view** (`NoteBody`, which is a `Text`, not an
`EditableText`) and in arrange mode — never in the editor itself. A custom paragraph layout with an
exclusion box remains conceivable there, which is what the P0 spike was designed to test. Inside the
editor, the photo can only be an inline block token that occupies its own line.

This is not a contradiction of the OQ-6 decision, but it is a significant sharpening of it, and the P1-P5
ladder in `docs/specs/2026-08-02-inline-photo-notes.md` must be re-read against it before implementation.
