# Note Composer — Phase 5: the photo toolbar and the footer

Date: 2026-09-22. Base: `main` @ `156b1ef`, with phases 0 to 2 merged (#150 to #156).
Parent: `docs/specs/2026-09-22-note-composer-inline-photos.md`, whose rulings C1 to C12 bind this
document. Where this document and a parent disagree, **this document wins**; §8 lists every such place.

This document is the authority for phase 5. The owner moved it ahead of phases 3 and 4 after running the
phase 2 experiment on macOS.

---

## 0. Why

The owner ran the wrapped composer and reported that the bottom of the panel is wasted: the writing
surface stops about three quarters of the way down and everything below it is a rail of thumbnails and a
row of photo controls that the picture itself has made redundant. The photo is now visible in the text,
so a second picture of the same note has nothing left to say.

Phase 5 takes the rail and the options sheet out, puts each photo's controls on a small toolbar that
appears over the selected photo, and gives the panel the design's footer: one Add memory button and the
Markdown hints. The writing surface takes back the height.

---

## 1. What the composer is after this phase

Top to bottom, inside the panel:

1. **Header.** Close, the title and date, Save. Unchanged.
2. **Format bar.** Bold, italic, heading, list, quote, link, undo. Unchanged.
3. **Writing surface.** The note, with photos drawn in place and text wrapping beside them. Taller by
   the height the rail used to take (§7).
4. **Footer.** Add memory on the left, the Markdown hints on the right (§4).

Nothing else. The photo rail, the photo options sheet and the caption sheet are gone (§6).

A selected photo carries a floating toolbar over it (§2). A caption is typed under the photo itself
(§3). Removing a photo from the toolbar offers Undo in a floating toast (§5).

---

## 2. The toolbar

**When it shows.** Exactly while one photo is selected, which C4 already defines: a click on the picture,
the caret moved onto its line, or a selection covering it. It hides on Esc, on a click outside it and the
photo, and when the selection leaves the photo line.

**What it holds,** left to right, in one dark rounded bar:

| Group | Controls |
|---|---|
| Size | `S` `M` `L` `Full`, the current one marked |
| Placement | Two glyph buttons, a picture with text lines beside it, one per side, the current one marked. Hidden when `canFloatAt` says the measure cannot float, exactly as the rail hid it. Dimmed and inert at Full size. Centre joins this group in phase 3 |
| Caption | One button. It opens the in-place caption editor (§3) |
| Remove | A trash glyph. It removes the photo line and shows the Undo toast (§5) |
| More | A `…` button opening a row of three glyphs, an arrow up, an arrow down and a swap, each disabled when the edit cannot apply |

The toolbar carries no preview panel. The owner ruled on 2026-09-22, after seeing it on macOS, that a
picture of the placement is unnecessary beside the placement buttons, whose own glyphs show a picture
with text beside it, as the design's do. `PhotoPlacementDiagram` stays in the codebase for the reader,
and nothing in the composer draws it. What is lost with it: the editor's column runs to 45 em and the
reader's to 35 em, so a photo can float here and stack there, and nothing now says so.

A photo at Full size takes no side. Its placement buttons stay in the bar, dimmed and inert, as the
design dims them.

**How it looks.** The design's bar, to its own numbers: a `#2A241D` surface at 5pt padding with an 11pt
radius, controls 28pt square with 7pt of side padding and 2pt between them, labels in 11pt semibold on
`#E9DCC6`, the marked one on the accent, and a 1pt rule 17pt tall between the groups. The owner chose
this over the taller bar with 48pt targets on 2026-09-22: a mouse does not need 48pt, and the phone pass
gives touch its own size.

**Where it sits.** Centred over the top edge of the photo, `photoToolbarGap` above it. When there is not
enough room above, it flips below the photo. It never leaves the writing surface, horizontally or
vertically: it is clamped to the surface's edges, so a photo at the bottom of the view keeps its whole
toolbar on screen rather than having it cut off. It is not shown at all while the photo's band is
scrolled out of the writing surface.

**Keyboard and screen readers.** Every control is focusable and operable with Enter or Space. Tab from
the selected photo enters the toolbar and walks it left to right; Esc anywhere in the toolbar deselects
the photo and returns focus to the writing surface. Every control carries a semantics label naming what
it does to this photo, and the marked size and placement report as selected.

**Where it lives.** `lib/features/capture/text/editor/photo_toolbar.dart`, drawn by the in-place editor
into the same canvas that draws the figures, so it moves with the photo as the note scrolls.

---

## 3. The caption, edited in place

The Caption button turns the caption line under the photo into a text field, focused, holding the current
caption. Enter or a click outside commits it through `setPhotoCaption`; Esc cancels and leaves the note
untouched. An empty commit removes the caption. The field carries the caption's own style, so the text
does not move when it commits.

`showPhotoCaptionSheet` and its sheet are deleted (§6). `sanitizePhotoCaption` stays: the in-place editor
runs every commit through it.

---

## 4. The footer

One row floating over the foot of the writing surface, inside the panel's horizontal padding, on a
translucent blurred veil so the note reads through it. The note's own page keeps a bottom padding the
height of the footer, so the last line always clears it. The owner ruled this on 2026-09-22: the design's
own footer is a plain row under a fixed-height surface, and that is what left the panel with a dead band.

- **Add memory.** The design's button: its word, a camera glyph, an accent fill and the sticker shadow
  the Save button carries. It picks photos, stores them and inserts their
  lines at the caret, exactly as the rail's Add photo tile did, including its busy label and its two
  failure messages. It is focusable, operable with Enter, and returns focus to the writing surface when
  the pick finishes. It never disappears on a short screen (fix-wave W3 and C12).
- **Markdown hints.** A dimmed line reading `# title  - list  1. steps  > quote`, the markers darker than
  the words, right aligned, as the design writes them. On a short screen, or when the panel is too narrow
  to hold both, the hints drop and Add memory stays.

No mode switch. The design's Photos Inline / Scrapbook toggle is not built (C1).

`lib/features/capture/text/composer_footer.dart` holds it. `TextComposerSheet` takes the photo importer
instead of a rail builder, and both composers pass `importNotePhotos`.

---

## 5. Removing a photo

The toolbar's trash removes the whole photo line through `removePhotoLine` and shows a floating toast
reading `Photo removed` with an `Undo` action. Undo restores the note byte for byte, including the
photo's caption and placement, and puts the caret back where it was.

The toast is the composer's: it is dismissed when the composer closes, so its Undo can never outlive the
note it belongs to. `showTransientToast` grows an optional `action` for this, carried by the existing
`ToastAction` the `Toast` widget already renders.

Backspace and Delete on a selected photo keep C6's behaviour and show no toast.

---

## 6. What is deleted, and where its tests go

| Deleted | What replaces it |
|---|---|
| `lib/features/notes/photos/photo_rail.dart`, less `importNotePhotos` and the pick messages, which move to the footer | The footer's Add memory and the photo drawn in place |
| `lib/features/notes/photos/photo_options_sheet.dart` | The toolbar |
| `lib/features/notes/photos/photo_caption_sheet.dart` | The in-place caption |
| The `photoRail` slot on `TextComposerSheet` and `ComposerRailSlot` | `onAddPhoto` and the footer |

Every test of a deleted file is either rewritten against its replacement or removed with the feature.
The pull request lists which, one line per test. These must be rewritten rather than removed, because
each pins a behaviour the composer still owes:

- the Add photo tile picks, stores and inserts at the caret;
- a refused pick and a storage failure are both reported and leave the note alone;
- the tile is reachable with Tab, operable with Enter, and hands focus back to the writing surface;
- Add photo survives a short screen;
- Size and Side rewrite only the selected photo, and Side is hidden where the measure cannot float;
- Move up, Move down and Replace keep the caption and the placement;
- Caption writes the alt slot;
- Remove offers Undo and Undo restores the line byte for byte;
- the mini-diagram is driven by the same `planFloat` the reader calls, re-plans when the photo resolves,
  and stacks a photo whose next block is not a paragraph;
- no drag or reorder API exists anywhere in the photo controls.

The rail's caret-following highlight and its thumbnail-tap-to-caret go with the rail: the photo is now in
the text, so both are answered by clicking the picture.

---

## 7. The writing surface takes the height

C8's writing-surface rule becomes: **the writing surface takes every point the panel has left** once the
header and the format bar are laid out. The panel fills the window less a margin, which is dropped
entirely on a window too short to spare it. The panel width rule and the 45 em column are unchanged.

Geometry tests pin the panel against the window at 800, 1200 and 1600, pin that the footer's bottom sits
at the surface's bottom, and pin that the note scrolls under the footer rather than stopping above it.

---

## 8. What this amends

| Parent rule | Now |
|---|---|
| C8: the writing surface is 55% of the available height, clamped 440 to 760 | It takes the height the panel has left, and the panel fills the window less a margin (§7) |
| C4: the toolbar carries the reader-prediction diagram | No preview panel; the placement glyphs carry it (§2) |
| C4: the toolbar carries left, centre and right | Left and right until phase 3 lands centre (§2) |
| `u8`: the photo rail, the options sheet, the caption sheet | Deleted (§6) |
| Phase order: 3, then 4, then 5 | 5 first, by the owner's call on 2026-09-22 |

---

## 9. The Steps

Each Step names its write-set and the tests that prove it. Every test is written first and seen failing.

### S1 — The footer

Build `ComposerFooter`; give `TextComposerSheet` an `onAddPhoto` importer in place of `photoRail`; wire
both composers. Move the rail's pick messages and busy label across, keeping their strings.

- Write-set: `lib/features/capture/text/composer_footer.dart`,
  `lib/features/capture/text/text_composer_sheet.dart`, `lib/features/capture/text/text_composer.dart`,
  `lib/features/day_detail/day_detail_edit_note.dart`,
  `test/features/capture/text/composer_footer_test.dart`.
- Acceptance: `composer_footer_test.dart`, `Add memory picks, stores and inserts the photo line at the
  caret`; `a refused pick is reported and leaves the note alone`; `Add memory keeps its place on a short
  screen`.

### S2 — The toolbar

Build `PhotoToolbar` and draw it from the in-place editor over the selected photo, with the size,
placement, caption, remove and more controls, the reader-prediction hint, the flip, the clamp, the hide
on scroll-out, and the keyboard contract.

- Write-set: `lib/features/capture/text/editor/photo_toolbar.dart`,
  `lib/features/capture/text/editor/in_place_photo_editor.dart`,
  `lib/features/capture/text/editor/editor.dart`,
  `test/features/capture/text/editor/photo_toolbar_test.dart`.
- Acceptance: `photo_toolbar_test.dart`, `it shows only while a photo is selected`; `Size and Side
  rewrite only the selected photo`; `it flips below the photo when there is no room above`; `it stays
  inside the writing surface and hides when the photo scrolls away`; `Tab walks its controls and Esc
  returns to the writing surface`.

### S3 — The caption in place

Turn the caption under a selected photo into a field driven by the toolbar's Caption button.

- Write-set: `lib/features/capture/text/editor/photo_caption_field.dart`,
  `lib/features/capture/text/editor/in_place_photo_editor.dart`,
  `test/features/capture/text/editor/photo_caption_field_test.dart`.
- Acceptance: `photo_caption_field_test.dart`, `Caption opens a field under the photo and commits into
  the alt slot`; `Esc cancels a caption edit and leaves the note untouched`.
- After S2.

### S4 — Remove with Undo

Grow `showTransientToast` an action, and wire the toolbar's trash to it.

- Write-set: `lib/design/feedback/toast.dart`,
  `lib/features/capture/text/editor/photo_toolbar.dart`,
  `lib/features/capture/text/editor/in_place_photo_editor.dart`,
  `test/design/feedback/toast_test.dart`,
  `test/features/capture/text/editor/photo_remove_undo_test.dart`.
- Acceptance: `photo_remove_undo_test.dart`, `the trash removes the photo and offers Undo`; `Undo
  restores the line byte for byte`; `the toast goes when the composer closes`.
- After S2.

### S5 — Delete the rail, the options sheet and the caption sheet

Delete the three files, the rail slot and their tests, rewriting the behaviours §6 lists against the
footer and the toolbar. List every test moved or removed in the pull request.

- Write-set: `lib/features/notes/photos/photo_rail.dart`,
  `lib/features/notes/photos/photo_options_sheet.dart`,
  `lib/features/notes/photos/photo_caption_sheet.dart`, `lib/features/notes/notes.dart`,
  `lib/features/capture/text/text_composer_sheet.dart`,
  `test/features/notes/photos/photo_rail_test.dart`,
  `test/features/notes/photos/photo_options_sheet_test.dart`,
  `test/features/capture/text/text_composer_short_screen_test.dart`,
  `test/features/capture/core/text_composer_test.dart`,
  `test/features/day_detail/day_detail_edit_note_test.dart`.
- Acceptance: `text_composer_test.dart`, `the composer carries no photo rail`; `photo_toolbar_test.dart`,
  `the mini-diagram predicts the reader, not the editor`.
- After S1, S2, S3, S4.

### S6 — The surface takes the height

Apply §7 and pin it.

- Write-set: `lib/features/capture/text/text_composer_sheet.dart`,
  `test/features/capture/text/text_composer_geometry_test.dart`.
- Acceptance: `text_composer_geometry_test.dart`, `the writing surface follows the window at 68 percent`;
  `the composer leaves no dead band under its footer`.
- After S5.

---

## 10. Out of scope

- Centre placement, the pick placeholder and the add-photo toast: phases 3 and 4.
- The scrapbook treatment (C10), free placement (C1), new inline formats (C12).
- Anything under `test/features/entry_cards/playback/`.
