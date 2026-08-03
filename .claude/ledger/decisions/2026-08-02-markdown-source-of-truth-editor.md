Status: proposed
Date: 2026-08-02
Thread: inline-photo-notes

## Context
The note composer must become a live rich markdown editor, and this must precede OQ-6. Four audits ran
(docs/specs/research/2026-08-02-editor-*.md). Binding facts: `Entries.textContent` is already an
unconstrained nullable TextColumn (tables.dart:23) so markdown SOURCE needs no migration; the app has ONE
note renderer (`NoteBody`, note_body.dart:5-25, single call site entry_card.dart:136); the prototype's
editor is REAL and bounds the feature set to 12 items; all three WYSIWYG packages store a STRUCTURED
document, not markdown, so each would transcode on every save of a journal entry.

## Decision
Ship a **markdown-source-of-truth editor**: one `EditableText`, the buffer stays raw markdown, a custom
`TextEditingController.buildTextSpan` renders it styled live. No editor package. This is the SAME
controller seam OQ-6 needs (`PhotoAnchorTextEditingController`, inline-photo spec:176) — they must be one
controller, which is why the editor precedes OQ-6.

## Consequences
- Zero migration, zero transcode, zero round-trip corruption risk on a journal. Export round-trips verbatim.
- Rejected: super_editor (no stable release in years, dev prerelease only); flutter_quill (maintainers push
  Delta over markdown, MD round-trip via an "unverified uploader" package, ZERO built-in shortcuts so the
  hand-roll happens anyway); appflowy_editor (AGPL-3.0, inline-embed unconfirmed); re_editor and
  flutter_markdown (not WYSIWYG editors at all).
- THREE caveats are binding, not negotiable: markdown markers are HIDDEN, never deleted from the buffer
  (buildTextSpan must match `controller.text` char-for-char); a tappable to-do checkbox cannot live in the
  span tree on iOS (flutter#187598, repro'd on 3.44.1); quote bars need a hand-synced
  `computeLineMetrics` overlay — budget it or cut quote bars.
- **Text cannot wrap around an inline object inside an EditableText** (flutter#82595, open since 2021).
  OQ-6's float+wrap can therefore ONLY live in the read view (`NoteBody`, a `Text`) and arrange mode —
  never in the editor. This sharpens, and does not contradict, the OQ-6 decision's "write mode is plain
  editable text". The P0-P5 ladder must be re-read against it.
- Top predicted failure: type-to-transform x undo/redo x IME composing. Gate every mutation on
  `composing.isCollapsed`.
