# Note Composer — Inline Photos

Date: 2026-09-22. Base: the stack ending at `fix/floating-toasts` (#152), above `main` @ `79ad901`.
Parent specs: `docs/specs/2026-09-20-note-editor-and-scrapbook-photos.md` and
`docs/specs/2026-09-21-note-fix-wave.md`. Design source: the Claude Design project "Personal journaling
app prototype", files `Field Notes.dc.html` and `md-scrapbook.js` (online revision of 2026-09-22; the
copy under `docs/prototype/` predates it).

This document is the authority for rebuilding the note composer. Where it and a parent spec disagree,
**this document wins**; §3 lists every such place.

---

## 0. Why

The owner ran the composer on macOS and found it hard to use:

- It is too narrow on a wide window and does not resize with the window.
- There is no flow. The photo controls are always on screen, even with no photo selected.
- A photo does not preview. The editor shows a dim line of Markdown; the picture is only a thumbnail in
  a rail under the text.
- The decorative sprig is drawn on top of the Save button instead of behind it.

The online design answers each of these with an Inline photo model: a photo is a block inside the text,
and its controls appear only while it is selected. The design also offers a Scrapbook model, with photos
on a free layer above the text. The owner chose Inline and deferred Scrapbook (logbook decision
`01M342CECPS9J8M6XM823D157H`).

---

## 1. Rulings

These bind every phase below.

### C1 — Inline. Free placement is deferred.

A photo is anchored to its line of the note, exactly as today. R2 of the parent spec stands. Free
placement at page coordinates, and the drag, rotate and resize handles that go with it, are out of scope.
If they return, they return as a new placement type that keeps existing notes valid.

### C2 — The editor shows the photo in place, and the text wraps beside it.

The photo is drawn at its size and side, and the paragraph that follows it flows beside it exactly as the
reader flows it: the lines that start above the photo's bottom are held to the narrower column, and the
rest of the note runs the full width below the photo. A photo the reader would stack is stacked here too,
with the text continuing below it.

The owner reversed this ruling and the parent spec's R1 on 2026-09-22, after running the phase 2
experiment: "The text does NOT wrap around the photo." The editor reaches the wrap the way the reader
does, by splitting the paragraph at a line boundary, except that it cannot split the text into separate
widgets and so forces the same break inside the one field. Section 3 records what that costs.

### C3 — The note stays one string, and the editor stays one text field.

`entries.text_content` remains the only authority. A photo is still the line
`![caption](photo/<ref> "side size")`. The in-place photo is drawn over that line; the line's characters
stay in the text field's buffer, so selection across a photo, copy, paste, undo and IME input keep their
current behaviour. If the phase 2 experiment fails, the fallback is the parent spec's `u10` segment
editor, and this ruling is revisited.

### C4 — Photo controls are contextual.

Controls for a photo appear only while that photo is selected. A photo is selected when the text
selection touches its line: a click on the picture, the caret moved onto its line, or a selection that
covers it. Esc, or a click anywhere outside the photo and its controls, deselects.

In the finished composer (phase 5) the controls are a dark toolbar above the selected photo: S, M, L and
Full; left, centre and right; Caption; delete; and a "…" menu holding Move up, Move down and Replace. The
toolbar flips below the photo when there is no room above, stays inside the panel horizontally, and hides
while the photo is scrolled out of view.

### C5 — Placements are left, centre and right.

Left means text on the right in the reader, and right the reverse. **Centre means a block on its own
line, with no text beside it.** Full forces centre. Centre is a new placement word in the photo line's
title; no data migration.

### C6 — Removing a photo.

With a photo selected, Backspace or Delete removes its whole line. Backspace at the start of the line
after a photo, or Delete at the end of the line before it, first selects the photo; a second press
removes it. A removal from the toolbar shows a floating "Photo removed · Undo" toast owned by the open
composer, so its Undo cannot outlive the note.

### C7 — Adding a photo.

The photo goes in at the caret. It replaces an empty line, or starts a new line after the caret's line,
and the composer guarantees a text line after it. It arrives selected, and a floating toast says
"Photo added — tap it to size & place it". While the photo is being picked and processed, a placeholder
block holds its place.

### C8 — The panel and the writing column follow the window.

- **Panel width:** 60% of the window width, never below 640pt and never above 1000pt, and never wider
  than the window. Phones stay full-width.
- **Writing surface height:** 55% of the height available to the panel, never below 440pt and never
  above 760pt, and never more than the space left once the rest of the composer is laid out.
- **Writing column:** the panel's inner width less the page margins, never above 45 em. The reader keeps
  its 35 em measure; the placement diagram keeps predicting the reader at 35 em.

These apply to the new-note and edit-note composers only. The voice and video composers keep their
640pt panel.

### C9 — The sprig is behind the header.

The decorative sprig is painted beneath the composer's content, so the Save button and the header sit
on top of it.

### C10 — One look for photos: the picture itself.

In the editor and the reader, a photo shows as the picture, filling the space it is given, with its
slight tilt and its shadow and nothing else. The white mount and its outline are gone: the owner ruled on
2026-09-22 that they were not the scrapbook look and only took space from the picture.

A real scrapbook treatment, with tape, randomised tilt and per-photo customisation, is a later
exploration. It is not phase 3 and it is not scheduled. The reader's figure (`NotePhotoFigure`) stays the
one place it is drawn, so the editor and the reader can never drift apart.

### C11 — Sizes keep today's rules.

Floated photos keep their text-relative (em) sizes, which keep the text beside them readable at every
width. Blocks keep their fractions of the column. The design's flat percentages are not adopted unless
the owner reopens this.

### C12 — What stays.

Markdown markers stay visible and dimmed while typing. Undo and Add photo never disappear on a short
screen (fix-wave W3). No new inline formats; the design's underline, monospace and highlight are out of
scope.

---

## 2. Phases

Each phase ships as its own pull request, stacked on the one before.

| # | Phase | Depends on |
|---|---|---|
| 0 | This document | — |
| 1 | Quick fixes: sprig, responsive panel, contextual rail controls | 0 |
| 2 | Experiment: a photo drawn in place inside the single text field | 1 |
| 3 | Reader: centre placement | 0 |
| 4 | Editor: photos in place, productised from phase 2 | 2 passes, 3 |
| 5 | Toolbar, in-place caption, rail and options sheet removed, footer | 4 |
| 6 | Phone pass, desktop text toolbar, benchmark, audit | 5 |

### Phase 1 — Quick fixes

- The sprig paints beneath the composer's content (C9).
- The new-note and edit-note panels, and the writing column inside them, follow C8.
- The rail shows its placement controls only while a photo is selected (C4). This is interim; the rail
  goes in phase 5.

**Acceptance.** Geometry tests pin the panel, the writing surface and the column at 900, 1280 and 1920pt
windows and on a phone; a test proves the Save button paints above the sprig; a test proves the rail
shows no placement controls until a photo is selected; `flutter analyze` and the full suite are green.

### Phase 2 — The experiment

The experiment answers one question: can the single text field show a photo in place, well enough to
build on? It ships as a draft for the owner to try in the macOS app, not for merge.

**How it works.** For each photo line, the editor:

1. styles the line's characters transparent and tiny, with a line height equal to the photo's drawn
   height and even leading, so the line becomes an empty band of exactly that height;
2. draws the reader's `NotePhotoFigure` into that band, positioned while painting from the text field's
   own layout, so the photo moves in the same frame as the text through typing, scrolling and resizing;
3. sizes and places the figure with `planFloat` at the writing column: a photo that would float in the
   reader is drawn at its float width against its side; any other photo at its block width, centred;
4. holds each line that runs beside a floated photo to the reader's narrower column, and clears the
   photo's height before the next block, so the paragraph wraps beside the picture (C2).

**Behaviour it must show.**

- A click on a picture selects that photo. A selected photo has an accent ring and no caret.
- Typing with a photo selected starts a new line after the photo; Enter does the same.
- C6's Backspace and Delete rules.
- The left and right arrows cross a photo in one step.
- An edit whose selection covers part of a photo line takes the whole line with it, so the Markdown is
  never left half-deleted.
- It works past the 6,000-character limit where live styling stops today.
- The rail keeps working.

**Go / no-go.** Go needs all five:

1. The band lays out at the figure's height, with no stray caret or selection marks inside it.
2. The figure matches the band to within half a point through scrolling, resizing and text scale from
   1.0 to 2.0.
3. It still works past the 6,000-character live-style limit.
4. Select-all and copy produce the saved text exactly; undo and IME composition behave as today.
5. Typing latency on a long note with several photos is no worse than today.

Checks 1 to 4 and 6 are widget tests. Check 5 and the overall feel are the owner's, in the macOS app. On no-go,
phase 4 builds the `u10` segment editor instead.

### Phases 3 to 6

Specified in outline here and in full when phase 2 reports.

- **Phase 3.** Centre placement (C5) in the parser, validity rules, reader, feed preview and float
  planner. The scrapbook look is out of this phase (C10).
- **Phase 4.** Phase 2 productised: the pick placeholder and the add-photo toast (C7).
- **Phase 5.** The toolbar (C4), the caption edited in place, the composer-owned Undo toast (C6), the
  rail and the options sheet removed, and the design's footer: Add memory and the Markdown hints, with no
  mode switch. Each rail and options-sheet test is either rewritten against its toolbar equivalent or
  removed with the feature, and the phase's pull request lists which.
- **Phase 6.** A phone pass with the keyboard up in both orientations; a floating text toolbar on desktop
  with the existing formats; the desktop benchmark re-run; a conformance audit against this document; the
  owner's check on macOS. Android stays deferred.

---

## 3. What this amends

| Parent rule | Amended by | Now |
|---|---|---|
| `u1`: the composer's text column is exactly 560 in a 640 panel | C8 | The panel and column follow the window; 560 in 640 holds only at the minimum |
| `u8`: the photo rail, its always-on controls, the options sheet, the 48dp rail controls | C4, phase 5 | A contextual toolbar with a keyboard and screen-reader contract |
| `u8`: the editor shows a photo as a dim line with the image in the rail | C2, C3 | The photo drawn in place |
| Placement is left or right | C5 | Left, centre or right |
| Fix-wave W3: the rail's slim Add tile on short screens | Phase 5 | Add memory in the footer, kept on short screens |
| R1: text wraps beside a photo only in the reader | C2 | The editor wraps too, by forcing the reader's line breaks inside the one field |
| `u8`: the controller builds no placeholder span | C2 | Empty placeholder boxes are allowed as spacers, and nothing else may go inside one |

R2 and R3 of the parent spec are unchanged. R4 was already amended for the Today feed; this document
amends it for the composer (C8). R1 is amended above.

**What the wrap costs.** The editor holds a line to the narrow column by giving the line's own break
character an invisible box that fills the rest of the line, and it indents a line beside a photo on the
left by giving that break character a box as wide as the photo. Three consequences follow, and each is
pinned by a test:

- The drawn text is no longer character-for-character the saved text. It is the same length, and every
  character it replaces is a space or a line break, so every caret offset still lands where it did. The
  saved note, copy and select-all are untouched.
- A placeholder may hold nothing but an empty box. A gesture recognizer on a span still fails the build:
  `RenderEditable` asserts on one in an editable field off macOS. A field nested in a placeholder is the
  reproduction of flutter/flutter#159171 and stays out.
- Beside a photo on the left, the framework would draw the caret at the far left of the indented line,
  behind the picture. The composer draws that caret itself, at the end of the line the typing goes to.

---

## 4. Out of scope

- Scrapbook free placement, and its drag, rotate and resize handles (C1).
- The scrapbook treatment: tape, randomised tilt, per-photo customisation (C10).
- New inline formats: underline, monospace, highlight (C12).
- Android device checks and the `u10` decision, which the owner deferred.
