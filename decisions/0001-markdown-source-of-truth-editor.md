---
Status: accepted
Date: 2026-08-03T06:07:32.355Z
Thread-Id: 01KZ33PK4E5RN3G6MD458S2N5D
---

# 0001. Build the rich note editor on markdown source of truth, no editor package

## Context

The Capture Note composer must become a live rich markdown editor, and that work must precede OQ-6's inline anchored photos. Four audits established the binding facts. Entries.textContent is already an unconstrained nullable TextColumn (tables.dart:23), so markdown SOURCE needs no schema change — decisive, because schemaVersion is 1 and onUpgrade unconditionally throws. The app has exactly ONE note renderer (NoteBody, note_body.dart:5-25, single call site entry_card.dart:136) serving both Today and Day Detail. The prototype's editor is REAL and bounds the feature set to 12 items with no nested lists, links or undo/redo. All three WYSIWYG packages store a STRUCTURED document rather than markdown, so each would transcode markdown in and out on every save of a journal entry, putting a silent-corruption risk on a user's writing. The rich editor and OQ-6's PhotoAnchorTextEditingController contend for the same controller seam and must be ONE controller, which is the concrete reason the editor precedes OQ-6.

## Options

- Markdown source of truth: one EditableText, raw markdown in the buffer, custom TextEditingController.buildTextSpan renders it styled live, no package
- super_editor: best architecture, AttributedText inline placeholder spans natively serve the photo anchor, first-party markdown codec, MIT
- flutter_quill: real stable semver releases, largest community, MIT, documented block embeds
- appflowy_editor: best-tested first-party markdown codec, built-in shortcuts matching the exact feature list
- re_editor: lightest dependency footprint, plain-text storage
- flutter_markdown / flutter_markdown_plus

## Outcome

ADOPTED the markdown-source-of-truth editor: one EditableText, buffer stays raw markdown, a custom TextEditingController.buildTextSpan renders it styled live, no editor package. Zero migration, zero transcode, zero round-trip corruption risk, and it is the same controller seam OQ-6 needs. REJECTED: super_editor, because it has cut no stable release in years and adopting it means pinning a 0.3.0-dev.NN prerelease with no semver contract — the direct opposite of the ROBUST mandate. REJECTED flutter_quill, because its maintainers explicitly recommend Delta JSON over markdown storage, its markdown round-trip runs through a third-party package flagged unverified-uploader, and it ships ZERO built-in markdown shortcuts so all six get hand-rolled regardless. REJECTED appflowy_editor on AGPL-3.0 plus the least-confirmed inline-embed support of the three, against a stated disqualifying criterion. REJECTED re_editor and flutter_markdown outright: one is a code editor with syntax highlighting, the other cannot edit at all. THREE BINDING CAVEATS, not negotiable: markdown markers are HIDDEN never deleted, because buildTextSpan must match controller.text character for character (maintainer-confirmed on flutter#159171); a tappable to-do checkbox cannot live in the span tree on iOS (flutter#187598, reproduced on 3.44.1, adjacent to the pinned 3.44.8) and needs a hit-tested overlay; quote bars need a hand-synced computeLineMetrics overlay, which is the one genuinely fragile piece and must be budgeted or cut. CONSEQUENCE FOR OQ-6: text cannot wrap around an inline object inside an EditableText (flutter#82595, open since 2021), so float-and-wrap can ONLY live in the read view (NoteBody, a Text) and arrange mode, never in the editor; inside the editor a photo is an inline block token on its own line. This sharpens rather than contradicts OQ-6's existing write-mode-is-plain-text decision, and the P0-P5 ladder must be re-read against it. Status is PROPOSED — the user has not ratified it.
