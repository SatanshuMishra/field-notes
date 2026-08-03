Status: accepted
Date: 2026-08-02
Thread: prototype-design-alignment

## Context
OQ-6 asked which photo-attachment model ships. The user rejected both the tray (no connection between text and image) and, after research, the prototype's free canvas. Five audits established: the prototype does NOT wrap text (`.ms-layer` is `pointer-events:none` absolute overlay, z 10+ over `.ms-editor` z 2; zero `float`/`shape-outside`/`clip-path` in 1742+502 lines); its engine caps nothing (`md-scrapbook.js:457`) and its save path DISCARDS all geometry (`getHTML()` returns only `editor.innerHTML`) and wipes `entry.photos` on edit-save; Flutter has NO text-exclusion API at any layer (dart:ui, TextPainter, RenderEditable, Skia SkParagraph) with flutter/flutter#50171 open since 2019; and editable wrap is structurally impossible (RenderEditable holds ONE TextPainter over ONE linear string).

## Decision
Ship the **inline anchored float** model, cap 8. The photo is anchored at a position in the note's text (not at a pixel), floated left or right, with text wrapping beside and below it. The exclusion rectangle is the axis-aligned bounding box of (rotated card UNION both tape strips), so no glyph can touch any ink. Manipulation (move anchor, flip side, resize, rotate) lives in a separate **arrange mode**; write mode is plain editable text. The anchor is a U+FFFC sentinel in the note text, Nth sentinel binding to Nth `entry_photos` row by `sortOrder`.

## Consequences
- **No schema migration.** The anchor lives in the text, so the existing `entry_photos` table carries this unchanged. This REMOVES the session's critical risk: `schemaVersion` is 1 and `onUpgrade` unconditionally throws (`app_database.dart:20-37`, pinned by `app_database_test.dart:97-128`); a wrong first migration bricks every existing journal.
- C5's blocked 6px caption DISSOLVES — a caption becomes the line of text under the photo. `EntryPhoto.label` is never needed. Extends decisions/2026-07-28-c5-ships-as-is.md.
- Cap 8 confirmed free: the prototype's 3 is a save-time truncation, not a constraint; `photo_tray.dart:9` already declares `defaultMaxPhotos = 8`.
- Rejected: the free canvas (obstructs by design, has NO narrative connection, needs the risky migration, and never persisted in the prototype); the bottom grid (the user's stated objection — no connection); editable wrap (needs framework surgery); a WebView text layer (platform-view layering fights draggable Flutter widgets above it).
- This is a NEW SUBSYSTEM, not a restyle. Parent spec 6.1 excludes free-manipulation photo cards; that exclusion stands and is not contradicted, because the adopted model is not the prototype's. Routed to its own spec and thread `inline-photo-notes`.
