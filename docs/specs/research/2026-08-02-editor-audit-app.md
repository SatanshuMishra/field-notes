# Audit — app note capture and storage (rich markdown editor prerequisite)

Date: 2026-08-02. Read-only audit. Feeds the combined rich-editor + OQ-6 spec.

## Headline

If the note body stays ONE linear string of markdown source, **nothing structural breaks and no schema
change is required**. `Entries.textContent` is already an unconstrained nullable `TextColumn`
(`lib/data/database/tables.dart:23`); markdown is convention inside that string, not a type change.
What breaks is presentation only: **zero markdown parsing exists anywhere in `lib/` today**, so raw
`#`, `*`, `-`, `>` would render literally at every plain-`Text` site.

Two separable changes follow: persistence (free, no migration) and rendering (real work).

## Storage and write path

- `Entries.textContent` — `TextColumn get textContent => text().nullable()();` at `lib/data/database/tables.dart:23`
- Capture: `TextComposerSheet._handleSaveTap` (`lib/features/capture/text/text_composer_sheet.dart:184-191`)
  -> `TextComposerConnector._persist` builds `TextCaptureRequest(date:, text:)` at
  `lib/features/capture/text/text_composer.dart:104` (`photos:` omitted, defaults to `const <CaptureMedia>[]`
  per `lib/domain/services/capture_service.dart:55-60`)
  -> `JournalCaptureService.capture` -> `_resolveText` trims (`lib/features/capture/core/journal_capture_service.dart:96-102`)
  -> `DriftJournalRepository.createEntry` (`lib/data/journal/drift_journal_repository.dart:112-133`)
  -> `EntriesDao.insertEntry` (`lib/data/journal/entries_dao.dart:14-26`)
- Edit: `EditNoteConnector._save` (`lib/features/day_detail/day_detail_edit_note.dart:49-62`)
  -> `updateEntryText` (interface `lib/domain/repositories/journal_repository.dart:29-32`,
  impl `lib/data/journal/drift_journal_repository.dart:142-150`)
  -> `EntriesDao.updateText` (`lib/data/journal/entries_dao.dart:48-56`)

Both paths write a plain `String`.

## Markdown handling today: NONE

Exhaustive grep of `lib/` and `pubspec.yaml` for `markdown|flutter_markdown|richtext|TextSpan\(` returns
zero hits. No markdown or rich-text package among the 20 dependencies. The only markdown in the repo is
`docs/prototype/project/md-scrapbook.js` (prototype-only) and spec prose that repeatedly defers the
engine (`docs/specs/2026-07-26-prototype-design-alignment.md:1959`,
`docs/specs/2026-08-02-inline-photo-notes.md:1175`).

## The composer as built

`lib/features/capture/text/text_composer_sheet.dart:293-304` — a raw **`EditableText`**, not a
`TextField`/`TextFormField`, inside a `Stack` with an `IgnorePointer`-wrapped placeholder `Text`.

- Plain `TextEditingController`, constructed in `initState` from `widget.initialText` (`:66`, `:75`)
- `keyboardType: TextInputType.multiline`, `minLines: null`, `maxLines: null`, `expands: true` (`:300-303`)
- NO `inputFormatters`, NO `maxLength`, NO `autofocus`, NO undo controller, NO `Actions`/`Shortcuts`
- No autosave or draft persistence — in-memory until Save; discarded on cancel/dispose
- Placeholder is exactly `'Start writing…'` (`:45`), styled `TypographyTokens.composerPlaceholderSerif`,
  per OQ-5's truthful-placeholder resolution (`docs/specs/2026-07-26-prototype-design-alignment.md:1554`)

## The read path — one renderer, not several

`NoteBody` (`lib/features/entry_cards/cards/note_body.dart:5-25`) renders
`Text(text, style: TypographyTokens.bodySerif, softWrap: true, overflow: TextOverflow.clip)`, with an
`'Empty note'` italic affordance for blank text.

**Exactly one production call site**: `EntryCard._body()` case `EntryType.text` at
`lib/features/entry_cards/entry_card.dart:136`. `EntryCard` is used by `DayDetailEntryTile`
(`lib/features/day_detail/day_detail_entry_tile.dart:29-38`) and `today_entry_feed.dart:109` — Today and
Day Detail share the identical widget tree. There is no second renderer to keep in sync.

Two derived-text preview sites consume `entry.textContent` raw, bypassing `NoteBody`, and would leak
markdown punctuation unless given a plain-text extraction step:

- `firstTextPreview` — `lib/features/today/today_memory.dart:57-73`, feeds `on_this_day_card.dart:83-87`
- `_previewFor` / `_searchTextFor` — `lib/features/search/search_day_view.dart:63-98`

## Tests

| Test | Risk from a rich-render change |
|---|---|
| `test/features/entry_cards/cards/note_body_test.dart` (39 lines) | HIGH — `find.text(...)` literal matching; span-based rendering likely breaks it |
| `test/features/entry_cards/entry_card_test.dart` (175 lines) | HIGH — `find.text('hello world')`, same literal-match risk |
| `test/features/capture/core/text_composer_test.dart` (139 lines) | MEDIUM — drives real `EditableText` via `tester.enterText` |
| `test/features/day_detail/day_detail_edit_note_test.dart`, `search_day_view_test.dart`, `today_memory_test.dart` | edit path and preview derivations |
| `test/design/goldens/` | NONE — only cross_hatch, flower, nav_icon, sticker_button, sticker_card; no golden renders note text or the composer |

## Undo/redo, shortcuts, platform branching

None in the composer (grep for `undo|redo|Shortcuts\(|CallbackAction` under `lib/features/capture`
returns zero). Platform branching exists only for camera/photo
(`lib/features/capture/platform/camera_video_recorder.dart:30`,
`lib/features/capture/photo/image_picker_photo_picker.dart:45`), never for text entry.

## Migration surface

`lib/data/database/app_database.dart:17` — `int get schemaVersion => 1`.
`onUpgrade` (`:25-32`) unconditionally throws `StateError`. Pinned by
`test/data/database/app_database_test.dart:27-31` and `:98-127` (a `_FutureSchemaDatabase` subclass
forcing `schemaVersion => 2` to prove the refusal fires and data survives).

**Markdown source text requires zero schema change.** Independently corroborated by the sibling spec's
own R1 constraint at `docs/specs/2026-08-02-inline-photo-notes.md:50-56`, citing the same lines.

## Files a rich-editor change must touch

- `lib/features/entry_cards/cards/note_body.dart` — the sole production renderer
- `lib/features/today/today_memory.dart`, `lib/features/search/search_day_view.dart` — preview extraction
- `lib/features/capture/text/text_composer_sheet.dart` — the `EditableText` surface and its controller
- `pubspec.yaml` — no markdown dependency exists today
- The four test files above

## Files it must NOT touch

- `lib/data/database/tables.dart`, `lib/data/database/app_database.dart` — no schema change, stays version 1
- `lib/domain/models/entry.dart`, `lib/domain/services/capture_service.dart`, `lib/domain/repositories/journal_repository.dart` — already `String?`/`String`
- `lib/data/journal/entries_dao.dart`, `lib/data/journal/drift_journal_repository.dart`, `lib/features/capture/core/journal_capture_service.dart` — substrate-agnostic
- `lib/features/data/journal_export_service.dart` — exports `textContent` verbatim (`:129`); markdown round-trips unchanged
- `test/design/goldens/` — no golden renders note text

## The contended seam (load-bearing for sequencing)

The existing inline-photo spec already specifies a `PhotoAnchorTextEditingController`
(`docs/specs/2026-08-02-inline-photo-notes.md:176`, mechanism at `:172-190`). The rich editor needs a
custom controller at the same seam. **These must be ONE controller, not two.** This is the concrete
reason the editor work has to precede OQ-6 rather than run beside it.
