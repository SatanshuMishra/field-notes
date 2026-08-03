## Where it started
Resumed prototype-design-alignment for OQ-3, but the user set OQ-3 aside and added a CRITICAL new scope item: the Capture Note editor must become a FULLY functional rich markdown editor (rich display, live MD syntax for #, -, 1., >, [], bold/italic/underline/code), and those changes MUST PRECEDE OQ-6. Mandate given verbatim: "ROBUST + SIMPLE. I do NOT want a complex but fragile implementation."

## Prior workflow: stopped, partially salvaged
The P0-P5 implementation workflow (run wf_7dff01ef-9da) was killed when the app was quit. Salvage verified from its journal: the spec-author agent COMPLETED and committed docs/specs/2026-08-02-inline-photo-notes.md (1228 lines) at 5ba0624 on inline-photo/spec, pushed. The spec-critic was mid-flight and never hardened it. NO PRs opened, NO implementation branches created, nothing orphaned. That spec is now an INPUT, not a finished artifact — the editor requirement lands underneath it.

## What shipped this session
Four parallel audits, all committed at 7ac77ff on inline-photo/spec under docs/specs/research/:
- 2026-08-02-editor-audit-prototype.md (codebase-analyst)
- 2026-08-02-editor-audit-app.md (codebase-analyst)
- 2026-08-02-editor-research-packages.md (researcher)
- 2026-08-02-editor-research-substrate.md (researcher) — THE DECISIVE ONE
Plus .claude/ledger/decisions/2026-08-02-markdown-source-of-truth-editor.md, Status: PROPOSED (not ratified).
NO production code changed. NO PRs opened.

## The findings that drove the architecture
1. THE PROTOTYPE'S EDITOR IS REAL, unlike its photo layer. Genuine contenteditable block editor, all five toolbar controls wired, all five MD shortcuts transform-on-type, list continuation on Enter, backspace demotion, Cmd+B/I/U. It bounds the feature set to exactly 12 items. NO nested lists, NO links, NO undo/redo exist to copy.
2. THERE IS NO TITLE FIELD in the prototype. The large serif "title" is just a block the user turned into h1 by typing "# ". One editable region.
3. THE PROTOTYPE NEVER RENDERS RICH TEXT OUTSIDE EDIT MODE. Day detail renders {{ e.text }} flattened; e.html is stored and never displayed. A Flutter reader that renders formatting is MORE correct than the prototype, not a faithful port.
4. THE PROTOTYPE DESTROYS PHOTOS ON RE-EDIT — reopening drops the cards, re-saving writes n.photos = undefined, deleting records. A real bug. Must be named an explicit non-goal.
5. ZERO MIGRATION CONFIRMED. Entries.textContent is already an unconstrained nullable TextColumn (tables.dart:23); markdown source is just a string. Export round-trips it verbatim.
6. ONE RENDERER ONLY. NoteBody (note_body.dart:5-25), single production call site entry_card.dart:136, serving both Today and Day Detail. No second surface to keep in sync. Two preview derivations (today_memory.dart:57-73, search_day_view.dart:63-98) would leak raw syntax.
7. NO PACKAGE IS A CLEAN FIT. All three WYSIWYG editors store a structured document, not markdown, so each would transcode on every save of a journal entry — silent corruption risk. super_editor: no stable release in years. flutter_quill: maintainers push Delta over markdown, ZERO built-in shortcuts. appflowy_editor: AGPL-3.0 plus unconfirmed inline embed. re_editor and flutter_markdown: not WYSIWYG editors at all.
8. buildTextSpan MUST MATCH controller.text CHARACTER FOR CHARACTER. Confirmed in rendering source and by a Flutter text-input maintainer on #159171. Markers can be hidden, never deleted.
9. TEXT CANNOT WRAP AROUND AN INLINE OBJECT INSIDE AN EditableText — flutter/flutter#82595, OPEN SINCE 2021.

## Tried and rejected
- All four editor packages, each on a named constraint (see the decision record).
- The assumption that the prototype editor was a demo shell like its photo layer — disproven; it is real and is a valid feature-set reference.

## Verification
No code changed, so no fullValidationCmd run. Baseline on main is still 944 and MUST be re-measured, never inherited, by the first phase that writes code. All four audit documents carry path:line or URL citations; the spec family's five historical wrong-anchor incidents were called out in every audit prompt.

## Running state
None. All four agents completed. Working tree clean but for untracked .serena/. Branch inline-photo/spec at 7ac77ff, pushed.
