# Note Editor and Scrapbook Photos — Implementation Spec

Date: 2026-09-20. Base: `origin/main` @ `509df95`. Status: **ready to dispatch**.

Dispatch contract: `docs/specs/items/2026-09-20-note-feature.fanout.json`, batched by wave under
`docs/specs/items/waves/`. This document is the human-readable authority; the JSON is what runs.

Supersedes everything in `docs/specs/archive/` — those are non-binding history and must not be read.

Derived from two verified research passes, both committed:

- `docs/specs/research/2026-09-20-terrain-survey.md` — 15 agents, 7 areas, every load-bearing claim adversarially verified
- `docs/specs/research/2026-09-20-design-panel.md` — 6 independent designs, 3 judge lenses, 1 synthesis, 3 stress tests

---

## 1. What this builds

The app's "Write a Note" feature is one plain-text field. It becomes a live Markdown editor with
photos placed in the text, where body text wraps around a photo when the column is wide enough.

**The whole design in one line: a note is ONE Markdown string, and a photo is ONE LINE inside it.**

```
![alt text](photo/7f3ac91b2d4e "right medium")
```

Everything falls out of that choice:

| Problem | How it disappears |
|---|---|
| Photo position drifts as text is edited | Typing above a photo moves it, because it moves every line. Zero code. |
| Undo must cover placement | Placement *is* text, and undo already covers text. |
| Cut/paste must carry photos | It does. The region is a string. |
| Draft, clipboard, export, search need the photo | All four are the same one string. |
| A deleted photo orphans a database row | There is no row. There is a line. |

Word's most-complained-about behaviour — anchor drift — is not mitigated here. It is unrepresentable.

---

## 2. The owner's rulings — settled, not open

These were answered on 2026-09-20 and are binding on every unit.

| # | Ruling | What it eliminated |
|---|---|---|
| R1 | Text wraps around a photo **only in the read view**. The editor may show a photo as a block. | A hand-built text layout engine. No Flutter code in existence wraps live. |
| R2 | A photo anchors to **a position in the text**, never a page coordinate. | The coordinate-reflow problem. Photos move with their paragraph. |
| R3 | Existing notes are **disposable test data**. Delete them. | The entire no-migration constraint. |
| R4 | **One canonical reading width** across every surface. | An undefined WYSIWYG. Today a note renders at 760/716/520pt in three places. |

**On R3, a finding rather than a use.** The schema was freed and the design went looking for a
reason to change it and did not find one. `entries.text_content` already holds the whole note.
`schemaVersion` stays 1 and the throwing `onUpgrade` stays exactly as it is. No unit migrates.

---

## 3. Architecture

### 3.1 Storage

`entries.text_content` holds CommonMark source and is the only authority for body **and** placement.

The photo reference is a **12-hex prefix** of the SHA-256, not the full digest, so the whole line is
38 characters — half a line at a 72-character measure, which a dim mono run can genuinely style as a
chip. A full digest would put 80+ literal characters per photo in the editor forever. `media_blobs.id`
keeps the full digest, so content-addressing and dedup are untouched. Insert-time uniqueness extends
the prefix in 4-character steps; resolution is a prefix match against the TEXT primary key.

`entry_photos` survives unchanged in shape and changes meaning: it becomes a **derived reachability
index**, rebuilt transactionally from the source on every save. It is not an authority.

Drafts are **files**, not rows: `<appDocuments>/drafts/<entryId|session>.md`, temp-file-then-rename.
Not the settings KV table, which delete-all does not clear and GC cannot see.

### 3.2 One grammar, two renderers

The single most important structural fact, and it is not obvious:

> **The editor may not delete a Markdown marker. The read view must.**

`buildTextSpan`'s output must match `controller.text` character for character — enforced structurally,
because `RenderEditable` indexes selection offsets straight into the text the `TextPainter` laid out.
The contract is **undocumented**; api.flutter.dev says only *"Builds TextSpan from current editing
value."* It holds by construction here, and an assert is what keeps it true through two years of edits.

`NoteDocument` has no controller and no caret, so nothing constrains its span tree to the source. It
deletes the `#` outright. One parser, two consumers, so what is bold while typing can never disagree
with what is bold when reading.

**Markers stay visible and dimmed rather than hidden.** That one constraint removes an entire class of
caret bug, because there is no inline object in the editable at all.

### 3.3 The responsive rule — one clamp, one comparison

No breakpoints. No window-size classes. No `TargetPlatform` branch.

```
em      = MediaQuery.textScalerOf(context).scale(noteBody.fontSize)
measure = min(constraints.maxWidth, 35 * em)
cap     = measure - gutter - 19.4 * em
photoW  = min(sizeEm * em, cap)              // shrink before demote
FLOAT iff size != full && nextBlockIsParagraph && photoW >= 8.5 * em
else BLOCK, width = measure * {S 0.55, M 0.75, L 0.92, Full 1.0}, centred
```

`scale(fontSize)`, never `scale(1) * fontSize` — Android 14+ font scaling is non-linear, and four of
the six candidate designs got this wrong at exactly the accessibility sizes where the gate matters.

**Worked, against real geometry:**

| Device | Measure | Result |
|---|---|---|
| 390pt Android phone | 320pt = 20 em | BLOCK — photo centred, text above and below |
| 430pt phone | 360pt = 22.5 em | BLOCK |
| macOS 1280 | 560pt | Medium floats at 192pt, band 352pt = 45 CPL |
| macOS narrowing | 560 → 462 | Medium holds 192pt, then shrinks 192 → 136, then blocks |
| Tablet 768 | pins at 560 | identical to desktop |

The owner's worked example — photo right on desktop, text above and below on a phone — falls out of
the clamp rather than being a phone special case.

**Scale invariance.** Because every term is in em, float geometry is identical at every text scale.
At 1.5x on a 1280 window the measure is 840pt and Medium still floats at 45 CPL. The accessibility
case needs no separate rule and does not lose the feature.

### 3.4 The float, and its one fallback

`PhotoWrapBlock` splits a paragraph inside one `LayoutBuilder`: a `TextPainter` at the band width,
`computeLineMetrics`, find the last line fitting beside the photo, `getLineBoundary` to snap the cut to
a line **start**, then `sliceInlineSpan` and emit a Row of photo plus head with the tail below.

**Float scope rule, the single most important constraint:** a float wraps the **next paragraph block
only**. If the next block is a heading, a list, another photo or the end of the note, the photo stacks.
Two floats therefore cannot interact, `clear` is structural rather than implemented, and the
`TextPainter` measures one paragraph rather than the note.

**`StackedPhoto` is the single return value for every failure** — column too narrow, size full, next
block not a paragraph, missing dimensions, corrupt blob, unparseable token, aspect past the clamp, or
the render budget disabling floats. One path, exercised by every phone on every note forever, so it is
proven in production long before a slow desktop ever needs it.

### 3.5 Dependencies: none

Zero packages added. Zero schema change. No drift or drift_dev bump.

`float_column` was **measured, not assumed** — probe tests confirmed it genuinely slices (228/360 at a
360pt column) and confirmed that the "crash-free selection" claim marketed against it targets
`flutter_html`, not `float_column`, which has zero open issues and two `RenderParagraph`s at 82k
characters. It is rejected because a one-photo, block-anchored, unjustified, LTR placement model is
precisely its restricted case, where a ~40-line hand-rolled slice produces identical geometry with free
selection — and its ~3,000 extra lines buy `clear`, stacked floats, RTL and justified text, every one
of which this design structurally excludes. The price would be bus-factor 1 under a core UX pillar.

`hyper_render`, `super_editor`, `package:markdown`, `flutter_quill`, `appflowy_editor` and five others
are rejected with measured reasons recorded in the design panel research document, so the next engineer
does not re-litigate it in four months.

---

## 4. What this gives up — stated plainly

- Wrap while typing. The editor shows a photo as a dim chip with the real image in the rail below. R1 sanctions it, and no Flutter code in existence does otherwise, but it is still two pictures of one note.
- **Floats on phones, permanently.** The gate needs a 462pt measure and a 430pt phone gives 360pt. No Android phone in portrait will float a photo at any size. That is the honest consequence of the only sourced typographic floor that exists.
- Literal scrapbook physics: no free (x, y), no rotation of the layout box, no overlap, no z-order. Tilt, paper frame and shadow are paint inside a reserved axis-aligned box.
- Multiple interacting floats, CSS `clear`, and a float spanning more than one paragraph.
- Justified text, permanently. It is the sole reason the mature package needs a hidden trailing word and a custom selection delegate.
- Arbitrary photo width. Four states, not a continuous drag — a user who builds an 88% float that demotes everywhere learns nothing from it.
- Drag, entirely. Placement is the caret plus tap controls. Deliberate under WCAG 2.2 SC 2.5.7 and to avoid racing the scroll recogniser.
- CommonMark conformance. A documented journaling subset: no tables, footnotes, task lists, nested lists, reference links, setext headings or HTML blocks.
- Hidden Markdown markers. Syntax stays visible and de-emphasised — a legibility trade taken to delete an entire class of caret bug.
- RTL. Sides are stored as left/right and resolved in one place, so RTL is a later addition. The app has no localisation delegates to test against today.
- Automatic disk reclamation. Orphan blobs accumulate until the user taps Reclaim space — the deliberate price of never sweeping bytes out from under a typo.
- Full-length notes in the Today feed. Cards preview; the whole note reads in day detail.

---

## 5. The units

Ten units. Each is one branch, one PR, independently revertible, and **each must leave note capture
working on its own merge commit.**

| Unit | Wave | Title | Risk | Files | After |
|---|---|---|---|---|---|
| `u1` | 1 | Canonical measure, reading type, responsive chrome | medium | 18 | — |
| `u3` | 2 | Drafts, non-dismissible composer, and one write path | high | 36 | `u1` |
| `u4` | 2 | Markdown parser and read renderer, text only | medium | 20 | `u1` |
| `u2` | 3 | Lazy sliver feed, bounded preview, and a full-note read surface | medium | 17 | `u1` |
| `u5` | 3 | Live Markdown editing and a formatting toolbar | high | 14 | `u4` |
| `u6` | 4 | The Android measurement on a real mid-tier device | low | 6 | `u5` |
| `u7` | 4 | Photo substrate | high | 54 | `u3` |
| `u8` | 5 | Photos in notes, stacked everywhere, with the photo rail | high | 27 | `u7`, `u5` |
| `u10` | 6 | Segment note editor, conditional on U6 | high | 16 | `u6` |
| `u9` | 6 | The float | high | 14 | `u8` |

### `u1` — Canonical measure, reading type, responsive chrome

**Wave 1 · risk medium · complex/design · after: nothing**

Introduce a NoteColumn widget clamping content to min(available, 35 em) and centring it, applied inside NoteBody so it reaches every read surface. Add a noteBody typography token (serif 16 / height 1.6) shared by composer and reader. Raise DayDetailPanel maxWidth 520 -> 640 and raise or remove its maxHeight 520. Change composerPanelWidth 760 -> 640 with page padding tuned so the composer text column is exactly 560. Wrap the Today feed card in the same NoteColumn. Wire the existing textScaleProvider (currently zero production consumers) into MaterialApp.builder as a MediaQuery override composing that factor with the ambient OS scaler. The composer reads MediaQuery.viewInsets for the keyboard and the hard SizedBox(height:440) becomes Flexible.
STRESS FIX (was fatal): the composer page paddings (_pageTopPadding 44 / _pageBottomPadding 120) must become height-responsive or move inside the scrollable, or a 360x640 Android phone with the keyboard up is left an unusable two-line porthole.
Add contentMinSize to the macOS window so it cannot be dragged below the usable column.
em is ALWAYS MediaQuery.textScalerOf(context).scale(fontSize), never scale(1) * fontSize: Android 14+ font scaling is non-linear and the two are not equal at exactly the accessibility sizes that matter.

**Acceptance.** At default text scale a note's text column measures exactly 560 logical pixels on every surface wide enough to supply it (Today feed card, day-detail tile, and the composer editor inside the 640pt panel) and clamps to the available width below that, with the full `flutter test` suite green including a new 844x390 composer test at viewInsets.bottom = 200 that renders a non-zero-height editor with no overflow.

**Files: 18 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/app/app.dart` — MaterialApp gains a builder that reads textScaleProvider (0.9/1.0/1.15) and installs a MediaQuery override whose textScaler composes that factor with the ambient OS scaler, giving the dead in-app text-size setting its fi
- `lib/design/tokens/typography.dart` — Add the noteBody token (fontFamily serif, fontSize 16, height 1.6, Palette.ink) plus the italic/placeholder companions the reader's 'Empty note' affordance and the composer hint need; composerBodySerif/composerPlaceholde
- `lib/design/widgets/note_column.dart` — NEW. The NoteColumn widget: a LayoutBuilder computing em = MediaQuery.textScalerOf(context).scale(TypographyTokens.noteBody.fontSize) (never scale(1) * fontSize), clamping its child to min(constraints.maxWidth, 35 * em) 
- `lib/design/widgets/widgets.dart` — Add one line: export 'note_column.dart'; alongside the existing four exports.
- `lib/features/capture/core/composer_shell.dart` — composerPanelWidth 760 -> 640 (line 9), and the centred panel gains EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom) so the keyboard no longer covers 44.8% of the writing area.
- `lib/features/capture/text/text_composer_sheet.dart` — _pageHorizontalPadding 54 -> 38 so the editor column is exactly 560 inside the 640 panel less its 2pt border each side; _pageTopPadding 44 / _pageBottomPadding 120 become height-responsive (or move inside the scrollable)
- `lib/features/day_detail/day_detail_panel.dart` — Constructor defaults at lines 30-31: maxWidth 520 -> 640, and maxHeight 520 raised or removed (the ConstrainedBox at :79-82) so the full note is not read through a ~340pt porthole.
- `lib/features/entry_cards/cards/note_body.dart` — Wrap the returned Text in NoteColumn so the clamp reaches every read surface through the single production call site, and switch TypographyTokens.bodySerif / bodySerifItalic to the new noteBody tokens.
- `lib/features/today/today_entry_feed.dart` — Wrap the feed card (the EntryCard built by TodayEntryTile, or each child of the Column at lines 72-81) in the same NoteColumn so the card itself stops running 149 CPL at a 1280pt window; adds the design/widgets barrel im
- `macos/Runner/MainFlutterWindow.swift` — Set self.contentMinSize in awakeFromNib so the window cannot be dragged below the width the shell is designed for; the file sets only the existing frame today and MainMenu.xib declares zero contentMinSize entries.
- `test/app/app_text_scale_test.dart` — NEW. Pumps FieldNotesApp with a settings override at each TextSize and asserts MediaQuery.textScalerOf below the builder reflects the provider factor composed with the ambient scaler.
- `test/design/tokens/tokens_test.dart` — Add assertions for the noteBody token (family == TypographyTokens.serif, fontSize 16, height 1.6) in the existing 'scale styles reference the declared families' group.
- `test/design/widgets/note_column_test.dart` — NEW. Asserts NoteColumn pins at 35 em when the parent is wider, takes the parent width when narrower, centres its child, and tracks MediaQuery.textScalerOf rather than the raw token.
- `test/features/capture/text/text_composer_geometry_test.dart` — NEW. Asserts the composer's editable text column measures exactly 560 at the 640 panel, and the stress case the design names explicitly: 844x390 with viewInsets.bottom = 200 renders with no RenderFlex overflow and a non-
- `test/features/day_detail/day_detail_panel_test.dart` — Assert the panel's BoxConstraints are the new maxWidth 640 and the new maxHeight policy.
- `test/features/entry_cards/cards/note_body_test.dart` — Existing harness pins the child at SizedBox(width: 360); add a wide-parent case asserting the rendered text column clamps to 560, and update the fontFamily/size expectations to the noteBody token.
- `test/features/today/today_entry_feed_test.dart` — Add a todayDesktopSurface (1000x780) case asserting the feed card's note column is clamped and centred rather than filling the pane.
- `test/native/macos_window_min_size_test.dart` — NEW. Reads macos/Runner/MainFlutterWindow.swift as text and asserts a contentMinSize is declared with a non-zero width, matching the existing test/native/ convention of asserting native config from the file's source.

</details>

### `u3` — Drafts, non-dismissible composer, and one write path

**Wave 2 · risk high · complex/feature · after: `u1`**

A file-backed draft at <appDocuments>/drafts/<entryId|session>.md holding the raw source, written on a 400ms idle debounce and flushed on AppLifecycleState.inactive/paused, using temp-file-then-rename. NOT the settings KV table, which delete-all does not clear and GC cannot see.
Set barrierDismissible:false on BOTH composer routes with a dirty-check confirm on close. Inline 'Draft restored - Discard' chip on restore, never a modal.
STRESS FIX: wrap both connectors in PopScope(canPop:false, onPopInvokedWithResult:) routed through the same dirty check, or the Android system back button and back-edge swipe still destroy the work.
STRESS FIX: Discard must DELETE the draft file in the same action, and a new-note draft must be keyed by a session id minted when the composer opens, not by date, or an abandoned draft silently returns to a later blank composer.
Introduce NoteWriter.save({entryId?, date, source}) as the single write path performing normalise, write entry, reindex entry_photos and delete draft in one drift transaction, with the create path's existing 20s timeout. This closes the create/edit asymmetry where EditNoteConnector bypasses CaptureService entirely, so trim normalisation and blank validation are create-only today.

**Acceptance.** Typing in either composer writes the raw source to <appDocuments>/drafts/<entryId|sessionUlid>.md within 400ms of idle and on AppLifecycleState.inactive/paused; a barrier tap, the Android system back button, a back-edge swipe and the X button all route through one dirty-check confirm whose Discard deletes that file; reopening restores the source behind an inline chip; and both Save paths call NoteWriter.save, which normalises, writes the entry, replaces the entry's entry_photos rows in one drift transaction under a 20s timeout, and then deletes the draft.

**Files: 36 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/data/drafts/draft_paths.dart` — New: draftsSubdir = 'drafts' constant, draft key validation (ULID-shaped only, no separators or traversal) and relPathForDraft(key) -> 'drafts/<key>.md'; mirrors blob_paths.dart and is the single import U7 needs to add t
- `lib/data/drafts/filesystem_draft_store.dart` — New FilesystemDraftStore implementing DraftStore over a Directory root, copying FilesystemMediaStore._atomicWrite's temp-file-then-rename (.tmp sibling dir, best-effort cleanup on FileSystemException) so a killed write l
- `lib/data/journal/drift_journal_repository.dart` — Implements saveNote inside a single _db.transaction: ensureDay-or-reuse for the date, insert or updateText on entries, then EntryPhotosDao.replacePhotos for the entry.
- `lib/data/journal/entry_photos_dao.dart` — Adds replacePhotos({entryId, mediaIds, now}) that clears the entry's existing rows and reinserts in sort order, so entry_photos is a derived index rewritten per save.
- `lib/domain/repositories/journal_repository.dart` — Interface gains saveNote({String? entryId, required String date, required String source, required List<String> photoMediaIds}) returning Entry, the one transactional note write path.
- `lib/domain/services/draft_store.dart` — New abstract interface class DraftStore {read/write/delete(key)} plus a DraftWriteException, sitting beside media_store.dart which it mirrors exactly.
- `lib/domain/services/note_writer.dart` — New abstract interface class NoteWriter with save({String? entryId, required String date, required String source, List<String> photoMediaIds}) plus NoteSaveResult and NoteWriteException, following capture_service.dart's 
- `lib/features/capture/core/capture.dart` — Barrel gains exports for note_writer.dart, journal_note_writer.dart, note_draft_controller.dart, composer_guard.dart and draft_restored_chip.dart.
- `lib/features/capture/core/capture_providers.dart` — Adds noteWriterProvider (FutureProvider<NoteWriter>) composing journalRepositoryProvider and draftStoreProvider, alongside the existing captureServiceProvider.
- `lib/features/capture/core/composer_guard.dart` — New single widget wrapping both connectors in PopScope(canPop: false, onPopInvokedWithResult:) routed through the same dirty check as the X button, plus the Keep editing / Discard confirm dialog (StickerCard + StickerBut
- `lib/features/capture/core/draft_restored_chip.dart` — New inline 'Draft restored · Discard' chip widget rendered in the composer body, never a modal; kept out of text_composer_sheet.dart to limit overlap with U1/U5.
- `lib/features/capture/core/journal_note_writer.dart` — New JournalNoteWriter implements NoteWriter: trims/normalises source, rejects blank with the existing blankTextMessage, calls the new repository saveNote (entry write + entry_photos replace in one drift transaction), the
- `lib/features/capture/core/note_draft_controller.dart` — New ChangeNotifier/WidgetsBindingObserver that owns the draft key, a 400ms idle debounce Timer on TextEditingController changes, flush() on AppLifecycleState.inactive/paused, restore() on attach, discard() that deletes t
- `lib/features/capture/text/text_composer.dart` — showTextComposer becomes barrierDismissible: false and TextComposerConnector mints a session ULID via newId() on initState as the draft key, wires NoteDraftController and ComposerGuard, and switches _persist from capture
- `lib/features/capture/text/text_composer_sheet.dart` — Gains constructor parameters for the restored-draft notice and its discard callback plus a controller hand-off so NoteDraftController can observe the TextEditingController, and renders DraftRestoredChip above the writing
- `lib/features/day_detail/day_detail_edit_note.dart` — showEditNote becomes barrierDismissible: false and gains a required date argument; EditNoteConnector stops calling journalRepositoryProvider.updateEntryText directly, keys its draft by entry.id, wires NoteDraftController
- `lib/features/day_detail/day_detail_panel.dart` — _edit passes widget.date into the new required date argument of showEditNote.
- `lib/state/draft_provider.dart` — New keepAlive riverpod providers draftRootProvider (Directory at <appDocuments>/drafts) and draftStoreProvider, copying media_provider.dart's getApplicationDocumentsDirectory + p.join shape.
- `lib/state/draft_provider.g.dart` — New riverpod_generator output for draft_provider.dart, produced by build_runner and checked in as the other .g.dart files are.
- `lib/state/state.dart` — Barrel gains export 'draft_provider.dart'.
- `test/data/drafts/draft_paths_test.dart` — New: relPathForDraft shape and draft-key validation cases.
- `test/data/drafts/filesystem_draft_store_test.dart` — New: round-trip write/read/delete, temp-file-then-rename leaves the previous draft on a failed write, key validation rejects traversal, missing draft reads as null.
- `test/data/journal/drift_journal_repository_test.dart` — Adds saveNote coverage: creates on null entryId, updates on a supplied one, and entry plus entry_photos land or roll back together.
- `test/data/journal/entry_photos_dao_test.dart` — Adds replacePhotos coverage: existing rows cleared, new rows inserted in sort order.
- `test/design/feedback/dialog_host_test.dart` — showEditNote call site updated for the required date argument.
- `test/features/capture/core/capture_test_support.dart` — Gains a FakeNoteWriter and an in-memory FakeDraftStore beside the existing FakeCaptureService/FailingJournalRepository.
- `test/features/capture/core/composer_guard_test.dart` — New: a simulated Android system back pop on a dirty composer is blocked and shows the confirm; Discard deletes the draft and pops; Keep editing leaves the route and the file; a clean composer pops straight through.
- `test/features/capture/core/journal_note_writer_test.dart` — New: create and edit both land through saveNote, blank source is rejected, the draft file is gone after a successful save, and a repository failure leaves the draft intact.
- `test/features/capture/core/note_draft_controller_test.dart` — New: no write before 400ms of idle, one write after, flush on AppLifecycleState.inactive and paused, restore returns the stored source, discard deletes the file.
- `test/features/capture/core/text_composer_test.dart` — Overrides noteWriterProvider instead of captureServiceProvider, and adds coverage that a barrier tap no longer dismisses the composer.
- `test/features/capture/text/text_composer_save_hang_test.dart` — Constructs TextComposerConnector with the noteWriterProvider override; the hanging service becomes a hanging NoteWriter.
- `test/features/capture/text/text_composer_timeout_dedupe_test.dart` — Same substitution: the slow counting CaptureService becomes a slow counting NoteWriter so the 20s timeout dedupe assertion still holds on the new path.
- `test/features/day_detail/day_detail_edit_note_test.dart` — Asserts the edit save goes through NoteWriter rather than updateEntryText, passes the new date argument, and covers restore-chip and back-button discard.
- `test/features/day_detail/day_detail_panel_test.dart` — Edit-opens-editor test updated for the date argument threaded through showEditNote.
- `test/features/day_detail/support/day_detail_harness.dart` — FakeJournalRepository records saveNote calls alongside textUpdates, and the harness exposes a draft store override.
- `test/state/draft_provider_test.dart` — New: draftRootProvider resolves under the overridden documents directory and draftStoreProvider yields a usable store, mirroring media_provider_test.dart.

</details>

### `u4` — Markdown parser and read renderer, text only

**Wave 2 · risk medium · complex/feature · after: `u1`**

parseNote(String) -> List<NoteBlock>: a hand-rolled line classifier plus a single-pass inline tokenizer over a closed set - Paragraph, Heading 1-3, Bullet, Number, Quote, Code, Divider, Photo; inline bold, italic, code, strike, link. Every block carries a sourceRange. Hand-rolled rather than package:markdown for one concrete reason: the SAME parser drives the editor's live styling and needs source offsets for every run, which package:markdown's AST does not expose. One grammar, two consumers, so what is bold while typing can never disagree with what is bold when reading.
Also ship plainTextOf(source) as the shared plain projection, and sliceInlineSpan(InlineSpan, int) -> (InlineSpan, InlineSpan?), a pure recursive walk splitting a span tree at a plain-text offset and re-parenting each ancestor's style down both sides.
NoteDocument, a Column of block widgets under ONE SelectionArea, replaces NoteBody's single Text.
Wire plainTextOf into the search haystack, the search preview and the On-This-Day preview, or Markdown syntax and photo references leak into search results and memory cards.
STRESS FIX (performance): memoize parseNote on source identity. buildTextSpan is called on every rebuild, not on every text change.
STRESS FIX: a Column of blocks under SelectionArea concatenates block text with no line breaks on copy. Inject paragraph breaks at block boundaries.
Losslessness proof: a property test over a fuzz corpus asserting concat(source[b.range]) == source, and head.toPlainText() + tail.toPlainText() == root.toPlainText() for sliceInlineSpan.
note_body_test.dart asserts a single Text found by literal string with a fontFamily; it will red and must be retargeted to pin the SAME behaviour through the new surface.

**Acceptance.** `flutter test` is green with: parseNote round-tripping every fuzz-corpus source (`concat(source[b.sourceRange]) == source`) and returning the identical memoized list on a repeat call with the same source; sliceInlineSpan satisfying `head.toPlainText() + tail.toPlainText() == root.toPlainText()` over that corpus; NoteBody rendering a Markdown note as a NoteDocument of per-block widgets under exactly one SelectionArea whose cross-block copied selection preserves the block break; and the search haystack, the search preview and the On-This-Day preview containing no Markdown markers for a note whose source has them.

**Files: 20 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/domain/notes/note_block.dart` — NEW. The closed block model (Paragraph, Heading1-3, Bullet, Number, Quote, Code, Divider, Photo), the inline node model (bold, italic, code, strike, link, plain), and the SourceRange type every block and inline run carri
- `lib/domain/notes/note_parser.dart` — NEW. parseNote(String) -> List<NoteBlock>: hand-rolled line classifier plus single-pass inline tokenizer emitting sourceRanges, total and crash-free on malformed input, with the STRESS FIX memoization on source identity 
- `lib/domain/notes/note_plain_text.dart` — NEW. plainTextOf(String) -> String, the shared plain projection over parseNote's blocks; defines the Photo block's projection as its alt/caption text so a photo-first note does not project to empty.
- `lib/domain/notes/notes.dart` — NEW. Sub-barrel exporting note_block.dart, note_parser.dart and note_plain_text.dart, matching the lib/domain/settings/settings.dart and lib/domain/mood/mood.dart convention.
- `lib/features/entry_cards/cards/note_body.dart` — Replace the single Text (currently Text(text, style: TypographyTokens.bodySerif)) with NoteDocument; keep the existing 'Empty note' blank-text affordance and the existing NoteBody({required this.text}) signature so entry
- `lib/features/entry_cards/entry_cards.dart` — Add exports for the new notes/ files (note_document.dart, note_block_widgets.dart, note_inline_span.dart, inline_span_slice.dart) alongside the existing cards/note_body.dart export.
- `lib/features/entry_cards/notes/inline_span_slice.dart` — NEW. sliceInlineSpan(InlineSpan, int) -> (InlineSpan, InlineSpan?): pure recursive walk accumulating plain-text length, splitting the straddling leaf and re-parenting each ancestor's style down both sides; delivered here
- `lib/features/entry_cards/notes/note_block_widgets.dart` — NEW. The boring per-block widgets NoteDocument composes — paragraph, heading 1-3, bullet, numbered item, blockquote, code block, divider — styled from design tokens; the Photo block renders as a stacked placeholder stub 
- `lib/features/entry_cards/notes/note_document.dart` — NEW. NoteDocument widget: parses the source and renders a Column of per-block widgets under exactly ONE SelectionArea, including the STRESS FIX for block-boundary copy (Flutter concatenates child plain text with no separ
- `lib/features/entry_cards/notes/note_inline_span.dart` — NEW. Pure builder turning a block's inline node list into an InlineSpan against a base TextStyle (read-side styling only; the editor's length-preserving visible-marker styling is U5's).
- `lib/features/search/search_day_view.dart` — _searchTextFor (:83, the haystack) projects each entry's textContent through plainTextOf before lowercasing and joining, and _previewFor/_firstLine (:63-72) is retargeted to the first block with non-empty projected text 
- `lib/features/today/today_memory.dart` — firstTextPreview (:63) collapses plainTextOf(entry.textContent) rather than the raw source before the whitespace-run collapse and the 90-character truncation, so On-This-Day memory cards show prose rather than Markdown.
- `test/domain/notes/note_fuzz_corpus.dart` — NEW. Shared deterministic fuzz corpus of note sources (sibling support file, matching test/data/journal/journal_test_db.dart and test/app/app_harness.dart), drawn on by both the parser losslessness property test and the 
- `test/domain/notes/note_parser_test.dart` — NEW. Block classification across the whole closed set, inline tokenizing, total/crash-free behaviour on malformed input, the losslessness property test concat(source[b.sourceRange]) == source over the fuzz corpus, and a 
- `test/domain/notes/note_plain_text_test.dart` — NEW. plainTextOf strips every marker in the closed set, projects a Photo block to its alt/caption, and leaves plain prose byte-identical.
- `test/features/entry_cards/cards/note_body_test.dart` — RETARGET (goes red on this unit): :25-29 finds the note by literal string and :34-36 casts a single Text and asserts style.fontFamily == TypographyTokens.serif — both fail against a span renderer; re-express the same two
- `test/features/entry_cards/notes/inline_span_slice_test.dart` — NEW. Property test head.toPlainText() + tail.toPlainText() == root.toPlainText() over the fuzz corpus, plus explicit cases for a split inside a styled leaf and at a nested-span boundary proving ancestor styles are re-par
- `test/features/entry_cards/notes/note_document_test.dart` — NEW. Asserts one SelectionArea for the whole document, one widget per block in source order, and the STRESS FIX: a selection spanning two blocks copies with the block boundary preserved rather than run together.
- `test/features/search/search_day_view_test.dart` — Add cases proving the haystack matches a query against the prose of a Markdown note but not its syntax, and that the preview of a note whose first line is a heading or a photo line is the projected prose; existing plain-
- `test/features/today/today_memory_test.dart` — Add a firstTextPreview case over a Markdown note asserting the preview carries no markers and truncates on projected length, not source length.

</details>

### `u2` — Lazy sliver feed, bounded preview, and a full-note read surface

**Wave 3 · risk medium · complex/feature · after: `u1`**

STRESS FIX (was fatal): TodayEntryFeed cannot simply become a ListView.builder. It sits inside a Column inside a SingleChildScrollView, where ListView.builder throws on unbounded height and shrinkWrap builds every child anyway while discarding cacheExtent. Convert TodayScreen to a CustomScrollView in BOTH layout branches: header, mood banner and feed eyebrow as SliverToBoxAdapter, the feed as SliverList.builder, cacheExtent on the CustomScrollView.
EntryCard gains a preview flag: in the feed it renders roughly the first 1200 characters plus the first photo with a fade and a Read more affordance; in the full-note surface it renders everything.
STRESS FIX (was fatal): there is currently NO full-note read surface. Day detail builds the SAME EntryCard inside a 520x520 box, so a long note can be read nowhere in the app. Day detail's tile passes preview:false, and EntryCard gains an onTap that opens that entry's day detail scrolled to it.

**Acceptance.** TodayScreen builds a CustomScrollView with a non-zero cacheExtent in BOTH the stacked and withRail branches whose entry feed is a SliverList.builder (a 50-entry day builds only the entries near the viewport, and no "Vertical viewport was given unbounded height" is thrown), EntryCard with preview:true renders at most ~1200 characters of note text plus only the first photo behind a fade with a Read more control while preview:false renders the whole note and every photo, day detail's tile passes preview:false, and tapping a feed card opens that entry's day detail with the tapped entry scrolled into view.

**Files: 17 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/features/day_detail/day_detail_entry_tile.dart` — Pass `preview: false` explicitly to EntryCard so day detail is the full-note read surface and stays so even if the EntryCard default is later flipped; no onTap is supplied because this IS the destination.
- `lib/features/day_detail/day_detail_panel.dart` — Add an optional `String? focusEntryId`; replace the `shrinkWrap: true` ListView.separated at :141 (which builds every child and discards cacheExtent) with a bounded, genuinely lazy ListView.separated/CustomScrollView dri
- `lib/features/day_detail/show_day_detail.dart` — showDayDetail gains an optional named `String? focusEntryId` forwarded to DayDetailPanel; the isCaptureDateKey guard, barrier and transition are unchanged. The parameter must stay OPTIONAL so the function remains assigna
- `lib/features/entry_cards/cards/note_preview.dart` — NEW, alongside the existing cards/note_body.dart and cards/photo_strip.dart. Holds `notePreviewCharLimit` (1200), a pure `notePreviewOf(String source, {int limit})` returning the truncated text plus a wasTruncated flag, 
- `lib/features/entry_cards/cards/photo_strip.dart` — InlinePhotoStrip gains an optional `int? maxVisible` applied AFTER the existing non-mutating sortOrder sort, so preview cards show only the first photo; the default (null) keeps today's render-all behaviour.
- `lib/features/entry_cards/entry_card.dart` — Add `final bool preview` (default false, so every existing call site keeps full rendering) and `final VoidCallback? onTap`; wrap the StickerCard in a GestureDetector/InkWell when onTap is non-null; _body() routes EntryTy
- `lib/features/entry_cards/entry_cards.dart` — Add `export 'cards/note_preview.dart';` to the barrel, keeping the existing alphabetical ordering (it lands between note_body.dart and photo_strip.dart).
- `lib/features/today/today_entry_feed.dart` — TodayEntryFeed stops returning a Column and becomes sliver-producing: SliverList.builder over entries with ValueKey<String>(entry.id) and findChildIndexCallback, and SliverToBoxAdapter for the error / empty-state / not-y
- `lib/features/today/today_screen.dart` — Replace the shared `main` Column + SingleChildScrollView in both TodayLayout.stacked and TodayLayout.withRail branches with a CustomScrollView carrying an explicit cacheExtent, whose slivers are SliverPadding(EdgeInsets.
- `test/features/day_detail/day_detail_entry_tile_test.dart` — Assert the tile hands EntryCard preview:false, so a long note renders in full in day detail.
- `test/features/day_detail/day_detail_panel_test.dart` — Add coverage that a long note renders in full (not truncated) and that opening with focusEntryId scrolls that entry into view; existing heading/mood/count/add-note/edit/delete cases must keep passing against the de-shrin
- `test/features/day_detail/show_day_detail_test.dart` — Add a case that showDayDetail forwards focusEntryId to DayDetailPanel and that omitting it preserves today's behaviour.
- `test/features/entry_cards/cards/note_preview_test.dart` — NEW, mirroring test/features/entry_cards/cards/note_body_test.dart. Covers notePreviewOf at, below and above the 1200-char limit, that Read more is absent for short notes and present for truncated ones, and that the fade
- `test/features/entry_cards/cards/photo_strip_test.dart` — Add a case that maxVisible:1 renders one MediaImage and that it is the lowest-sortOrder photo, and that the default still renders all photos in sortOrder.
- `test/features/entry_cards/entry_card_test.dart` — Add cases for preview:true (NotePreview rendered, long text truncated, Read more present, exactly one MediaImage in the strip) versus preview:false (NoteBody rendered, full text, all photos) and for onTap firing; the exi
- `test/features/today/today_entry_feed_test.dart` — Every `pumpToday(tester, const TodayEntryFeed(date: ...))` must host the now-sliver feed inside a CustomScrollView; add coverage that a long entry list builds only near-viewport children (lazy) and that a card tap routes
- `test/features/today/today_screen_test.dart` — Add assertions that both TodayLayout.stacked and TodayLayout.withRail build a CustomScrollView with a non-zero cacheExtent and pump without a viewport-unbounded-height exception; existing greeting/date/mood/feed text exp

</details>

### `u5` — Live Markdown editing and a formatting toolbar

**Wave 3 · risk high · complex/feature · after: `u4`**

Define a NoteEditor interface with SingleFieldNoteEditor as the default implementation from the day it lands, so the fallback is a boolean rather than a rewrite.
Replace the raw EditableText with a TextField, which restores selection handles, the copy/paste toolbar, the magnifier and painted selection - all absent today because neither selectionControls nor contextMenuBuilder is passed, so Flutter disposes the selection overlay.
Drive it with MarkdownStyleController extends TextEditingController overriding buildTextSpan, LENGTH-PRESERVING BY CONSTRUCTION: markers stay VISIBLE and de-emphasised rather than hidden. No WidgetSpan, no sentinel character, no zero-size run, no TextSpan.recognizer. That single constraint removes an entire class of caret bug.
Four framework defences, all mandatory: (1) assert inside buildTextSpan that the built span's plain-text length equals the value's text length - the framework raises nothing when this breaks and every caret offset past the break is then silently wrong; (2) a test that FAILS THE BUILD if 'recognizer:' appears under the editor directory; (3) spellCheckConfiguration null and stylusHandwritingEnabled false, with the reason recorded, because EditableTextState.buildTextSpan short-circuits past the controller override in both states and styling silently vanishes; (4) the IME composing underline reapplied by hand over value.composing, because overriding buildTextSpan drops it.
A liveStyleLimit of 6000 characters past which buildTextSpan returns one plain span. NO text truncation anywhere - never a LengthLimitingTextInputFormatter in an app whose job is capturing text.
STRESS FIX: this is meant to be a feature-rich Markdown editor and no formatting affordance was specified at all. Add a compact format bar - bold, italic, heading, list, quote, link - above the keyboard on compact screens and in the composer header on desktop, each toggling markers at the selection.
STRESS FIX: add an explicit Undo control. Flutter's UndoHistory is bound to keyboard shortcuts and Android has no Ctrl-Z, so every 'undo restores it' claim in this design is desktop-only without it.

**Acceptance.** `flutter analyze` and `flutter test` pass with the composer's writing surface a `TextField` behind a `NoteEditor` seam whose default `SingleFieldNoteEditor` + `MarkdownStyleController` asserts `span.toPlainText().length == value.text.length` on every `buildTextSpan`, keeps markers visible and dimmed, returns one plain span above 6000 characters, never truncates, and sits under a format bar whose bold/italic/heading/list/quote/link and Undo controls each mutate or restore `controller.text` on tap — including a new test that fails the build when `recognizer:` appears anywhere under `lib/features/capture/text/editor/`.

**Files: 14 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/design/icons/format_icons.dart` — NEW. `FormatGlyph` enum and `CustomPainter`-based glyphs for bold, italic, heading, list, quote, link and undo, following the existing `CaptureIcon`/`CaptureIconPainter` 24-unit viewBox + stroke idiom. Painted glyphs rat
- `lib/features/capture/core/capture.dart` — Add `export '../text/editor/editor.dart';` alongside the existing text_composer exports so the editor module is reachable through the capture barrel like every other capture submodule.
- `lib/features/capture/text/editor/editor.dart` — NEW. Barrel re-exporting the five editor files, matching the repo's per-module barrel convention (capture.dart, photo.dart, video.dart, voice.dart, widgets.dart, tokens.dart).
- `lib/features/capture/text/editor/format_actions.dart` — NEW. Pure `TextEditingValue -> TextEditingValue` marker toggles for bold, italic, heading, bullet list, quote and link — inline wrap/unwrap at the selection and line-prefix add/remove over the selected lines — each retur
- `lib/features/capture/text/editor/format_bar.dart` — NEW. The compact format bar widget (bold, italic, heading, list, quote, link) plus the explicit Undo control bound to the `UndoHistoryController` via `ValueListenableBuilder<UndoHistoryValue>` for enablement — the Androi
- `lib/features/capture/text/editor/markdown_style_controller.dart` — NEW. `MarkdownStyleController extends TextEditingController` overriding `buildTextSpan`, length-preserving by construction: no WidgetSpan, no sentinel, no zero-size run, no `TextSpan.recognizer`; markers stay visible at 
- `lib/features/capture/text/editor/note_editor.dart` — NEW. Declares the `NoteEditor` seam: an abstract interface (controller + focus node + undo controller + scroll controller + style/hint config) that both implementations satisfy, plus the single selection point that retur
- `lib/features/capture/text/editor/single_field_note_editor.dart` — NEW. The day-one default implementation: one `TextField` replacing the raw `EditableText`, passing `selectionControls`/`contextMenuBuilder` (restoring handles, copy/paste toolbar, magnifier and painted selection), `magni
- `lib/features/capture/text/text_composer_sheet.dart` — Replace the raw `EditableText` at :293-304 with the `NoteEditor` seam, construct the `MarkdownStyleController`, `UndoHistoryController` and focus node in `initState` and dispose them, and mount the `FormatBar` — in the c
- `test/features/capture/text/editor/format_actions_test.dart` — NEW. Table-driven unit tests for each toggle over collapsed, single-word, multi-word and multi-line selections, in both apply and un-apply directions, asserting the resulting text and selection offsets.
- `test/features/capture/text/editor/format_bar_test.dart` — NEW. Widget tests that each bar control changes the buffer at the selection, that the Undo control restores the previous value without any keyboard shortcut, and that a bar tap does not steal focus or collapse the select
- `test/features/capture/text/editor/markdown_style_controller_test.dart` — NEW. Asserts the length-preserving invariant over a fuzz corpus of marker-bearing sources, that markers are styled rather than removed, that a >6000-character value returns a single plain span, that nothing is ever trunc
- `test/features/capture/text/editor/no_recognizer_test.dart` — NEW. Reads every `.dart` file under `lib/features/capture/text/editor/` from disk (following the `pubspec_fonts_test.dart` / `android_manifest_permissions_test.dart` static-inspection convention) and fails if `recognizer
- `test/features/capture/text/editor/single_field_note_editor_test.dart` — NEW. Asserts the mounted `EditableText` has non-null `selectionControls` and `contextMenuBuilder` (so the selection overlay is not disposed), a non-null `selectionColor` after a long-press selection, `spellCheckConfigura

</details>

### `u6` — The Android measurement on a real mid-tier device

**Wave 4 · risk low · complex/design · after: `u5`**

This unit produces NUMBERS and a short written finding, not a feature. Every performance figure behind this design is desktop Apple Silicon under flutter_test. The single biggest risk is keystroke cost in a long live-styled buffer on a mid-tier Android phone, where the plausible multiplier spans 5x to 15x - the difference between a fine editor and a broken one.
Measure and record exactly five numbers: (1) keystroke cost in a 20k-character live-styled buffer; (2) keystroke cost in a 60k-character buffer with live styling OFF; (3) first-layout cost for one wrapped paragraph; (4) first-layout cost for a 10,000-word note document containing eight photos; (5) a scroll frame over a feed of preview cards.
Deliver a re-runnable benchmark harness plus a committed results document.
This unit GATES whether U10 is ever built, and it runs immediately after the editor and before any photo work because this is the last point at which a bad result can still change the design cheaply.
NOTE: this machine has no Android SDK. The harness must be runnable by a human on their own device, and the deliverable includes the instructions to do so.

**Acceptance.** Running `scripts/android-bench.sh` against a connected physical mid-tier Android phone executes `integration_test/note_perf_bench_test.dart` in profile mode via `test_driver/perf_driver.dart` and emits all five measurements to `build/note_perf_bench.json`, and `docs/specs/research/2026-09-20-android-measurement.md` records those five figures with device model, Android version, Flutter version and build mode, states each against its desktop flutter_test baseline, and ends with an explicit PROCEED-WITHOUT-U10 or BUILD-U10 verdict.

**Files: 6 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `docs/specs/research/2026-09-20-android-measurement.md` — NEW. The committed deliverable: the runbook (device class required, profile-mode requirement, exact command, what to do if adb is missing), the five recorded numbers with percentiles and the desktop flutter_test baseline
- `integration_test/fixtures/long_note_fixtures.dart` — NEW. Deterministic fixture generators: a 20k-char Markdown source, a 60k-char source, one wrapped paragraph, a 10,000-word source carrying eight `![alt](photo/<prefix> "...")` lines, and an N-entry seeded feed. Also seed
- `integration_test/note_perf_bench_test.dart` — NEW. The single on-device entry point. Five `testWidgets` cases producing the five numbers: (1) keystroke cost in a 20k-char live-styled buffer, (2) keystroke cost in a 60k-char buffer with live styling off, (3) first-la
- `integration_test/support/bench_recorder.dart` — NEW. Shared timing plumbing: warmup-and-discard, per-sample Stopwatch collection, p50/p90/p99/max reduction, and the reportData envelope carrying device model, Android release, Flutter version, build mode and git SHA so 
- `scripts/android-bench.sh` — NEW. The one command a human runs: asserts a physical Android device via `adb devices`, captures `ro.product.model`/`ro.build.version.release` into `--dart-define`s, invokes `flutter drive --driver=test_driver/perf_drive
- `test_driver/perf_driver.dart` — NEW top-level directory (standard Flutter layout, currently absent; verified `test_driver/` does not exist). Calls `integrationDriver(responseDataCallback: ...)` from `package:integration_test/integration_test_driver.dar

</details>

### `u7` — Photo substrate

**Wave 4 · risk high · complex/feature · after: `u3`**

Read intrinsic dimensions at pick time via ui.ImageDescriptor.encoded (header-only, no full decode) and pass them through the existing CaptureFile -> MediaStore.putFile path into the existing media_blobs width/height columns, which are NULL for every photo ever stored. That read doubles as a deliberate HEIC canary: an undecodable photo fails loudly at the picker where the user is already waiting, rather than silently at read time as a correctly-shaped hole.
STRESS FIX: do NOT pass maxWidth/maxHeight/imageQuality to pickMultiImage. Those make image_picker decode and re-encode on the platform side before Dart sees a byte, and re-encoded output is not byte-stable across OS versions - which breaks content-addressed dedup and defeats the canary. Pick the original, read dimensions and orientation, then downscale in Dart with a deterministic codec before hashing.
Introduce the 12-hex-prefix photo reference with insert-time uniqueness extension in 4-character steps, and a resolver using a prefix match against the media_blobs TEXT primary key. media_blobs.id keeps the full digest, so content-addressing and dedup are untouched.
Reindex entry_photos from the source on every save; it becomes a derived reachability index, not an authority.
Add the drafts directory as a garbage-collection root. Add a MANUAL 'Reclaim space' action in Settings. GC must NEVER run automatically: the photo reference lives in text the user can hand-edit, and an automatic sweep would take the bytes before the user can fix a typo. That is silent permanent data loss in a local-first journal.
STRESS FIX (would otherwise render every photo twice): remove the InlinePhotoStrip mount from EntryCard IN THIS UNIT - the same one that starts populating entry_photos.
STRESS FIX (performance): give the media resolver a synchronous in-memory memo; it currently builds a cross-isolate SQL future inside build(). Pass cacheWidth on every note image, quantised to 64px buckets so a continuous resize does not decode the same photo dozens of times.

**Acceptance.** Picking a photo writes a media_blobs row whose width and height are non-null and whose stored bytes are byte-identical across repeated picks of the same source file (with an undecodable header throwing at the picker instead), a 12-hex prefix of that row's id resolves to exactly one blob through a memoized resolver that issues one store call per id rather than one per build, EntryCard no longer mounts InlinePhotoStrip anywhere, every note-photo Image.file carries a 64px-quantised cacheWidth, entry_photos can be replaced wholesale for an entry from a list of mediaIds, a blob referenced only from the drafts directory survives collectGarbage, and the Settings Data section's manual "Reclaim space" button is the only code path in lib/ that calls collectGarbage.

**Files: 54 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/data/journal/drift_journal_repository.dart` — Implements replacePhotosForEntry by delegating to the DAO inside a drift transaction, minting ids with the existing _newId()/clock.
- `lib/data/journal/entry_photos_dao.dart` — Adds replacePhotosForEntry(entryId, mediaIds, now): deletes the entry's existing rows and reinserts in first-appearance order inside the caller's transaction - the reindex primitive.
- `lib/data/media/blob_prefix.dart` — NEW - pure prefix math: 12-hex default length, 4-char extension steps, prefix validation, and the [prefix, prefixSuccessor) range bounds used instead of LIKE so SQLite plans a SEARCH on the TEXT primary key.
- `lib/data/media/filesystem_media_store.dart` — Implements blobByPrefix/uniquePrefixFor via the range predicate from blob_prefix.dart, and passes the drafts root through to MediaGarbageCollector in collectGarbage().
- `lib/data/media/media_gc.dart` — MediaGarbageCollector takes an optional drafts Directory and adds every photo reference found in <drafts>/*.md (prefix-resolved to full digests) to the reachable set before sweeping.
- `lib/domain/repositories/journal_repository.dart` — JournalRepository interface gains replacePhotosForEntry({entryId, mediaIds}).
- `lib/domain/services/media_store.dart` — MediaStore interface gains prefix lookup (blobByPrefix) and insert-time uniqueness extension (uniquePrefixFor); collectGarbage's contract is documented as manual-only.
- `lib/features/capture/photo/image_picker_photo_picker.dart` — pickMultiImage()/pickImage() keep taking NO maxWidth/maxHeight/imageQuality; photoCaptureFromXFile becomes async and routes each XFile through the intrinsics read (HEIC canary, throws PhotoPickException on undecodable he
- `lib/features/capture/photo/photo.dart` — Barrel gains exports for photo_intrinsics.dart and photo_downscale.dart.
- `lib/features/capture/photo/photo_downscale.dart` — NEW - deterministic dart:ui downscale to the 2048 long-edge target (instantiateImageCodec with targetWidth/targetHeight + toByteData PNG/raw re-encode), applied to the original bytes BEFORE the store hashes them so ident
- `lib/features/capture/photo/photo_intrinsics.dart` — NEW - header-only intrinsic width/height/orientation read via ui.ImageDescriptor.encoded from an ImmutableBuffer, plus the typed failure that makes an undecodable photo fail loudly at the picker.
- `lib/features/day_detail/day_detail_entry_tile.dart` — DayDetailEntryTile stops watching photosForEntryProvider and stops passing `photos:` to EntryCard.
- `lib/features/entry_cards/cards/photo_strip.dart` — DELETE - InlinePhotoStrip has no remaining consumer; entry_photos is now a derived GC index with no render surface.
- `lib/features/entry_cards/entry_card.dart` — Removes the `if (photos.isNotEmpty) InlinePhotoStrip(...)` mount and the now-dead `photos` field, plus the cards/photo_strip.dart import - the stress fix that stops every photo rendering twice once entry_photos starts re
- `lib/features/entry_cards/entry_cards.dart` — Barrel drops the cards/photo_strip.dart export and gains media/decode_target.dart.
- `lib/features/entry_cards/media/decode_target.dart` — NEW - converts a logical box width plus devicePixelRatio into a cacheWidth quantised up to 64px buckets, so a continuous resize collapses to one or two ImageCache entries.
- `lib/features/entry_cards/media/media_image.dart` — Reads the resolver's sync memo first (no placeholder frame on a cache hit) and passes cacheWidth/cacheHeight to Image.file, quantised through decode_target.dart.
- `lib/features/entry_cards/media/media_resolver.dart` — MediaResolver gains a synchronous accessor for an already-resolved entry; MediaStoreResolver accepts a 12-hex prefix or full digest, resolves through blobByPrefix, and memoizes ResolvedMedia in an in-memory map so resolv
- `lib/features/settings/journal_data_controller.dart` — Takes the MediaStore and implements reclaimSpace() by calling collectGarbage(), reporting the number of blobs reclaimed or a typed failure.
- `lib/features/settings/sections/data_section.dart` — Adds a 'Reclaim space' SettingsFieldRow with its own in-flight guard and feedback, wired to reclaimSpace() - the ONLY caller of GC anywhere in the app.
- `lib/features/settings/settings_data_controller.dart` — SettingsDataController interface gains reclaimSpace() returning DataActionResult.
- `lib/features/settings/settings_providers.dart` — settingsDataControllerProvider passes the already-awaited mediaStore into JournalDataController.
- `lib/features/settings/settings_providers.g.dart` — Regenerated source hash for settingsDataControllerProvider.
- `lib/features/today/today_entry_feed.dart` — TodayEntryTile stops watching photosForEntryProvider and stops passing `photos:` to EntryCard; _PendingMediaResolver implements the new sync-memo member of MediaResolver.
- `lib/state/media_provider.dart` — Adds a keepAlive draftsRoot provider (<appDocuments>/drafts) and threads it into FilesystemMediaStore so GC can treat drafts as a reachability root.
- `lib/state/media_provider.g.dart` — Regenerated by build_runner for the new draftsRoot provider and the changed mediaStore provider source hash.
- `test/app/support/app_shell_harness.dart` — FakeJournalRepository gains replacePhotosForEntry.
- `test/data/journal/drift_journal_repository_test.dart` — Covers the repository-level replacePhotosForEntry wrapper.
- `test/data/journal/entry_photos_dao_test.dart` — Covers replacePhotosForEntry: idempotent re-run, sortOrder = first-appearance order, rows for removed mediaIds gone.
- `test/data/media/blob_prefix_test.dart` — NEW - prefix length/step/validation and range-successor math, including the all-f carry case.
- `test/data/media/filesystem_media_store_test.dart` — Adds coverage for blobByPrefix (exactly-one-match, zero-match, ambiguous) and for uniquePrefixFor extending in 4-char steps against a colliding neighbour.
- `test/data/media/media_gc_test.dart` — Adds a case proving a blob referenced only by a file in the drafts directory survives collectGarbage, and that GC is never invoked implicitly.
- `test/features/capture/core/capture_test_support.dart` — FailingJournalRepository gains replacePhotosForEntry; FailingMediaStore gains blobByPrefix/uniquePrefixFor.
- `test/features/capture/core/journal_capture_verify_ondisk_test.dart` — _CountingMediaStore gains blobByPrefix/uniquePrefixFor.
- `test/features/capture/photo/image_picker_photo_picker_test.dart` — Updated for the async photoCaptureFromXFile and for the assertion that pickMultiImage is called with no downscale arguments.
- `test/features/capture/photo/photo_downscale_test.dart` — NEW - proves the downscale is byte-stable across repeated runs for the same input and that a sub-target image is passed through untouched.
- `test/features/capture/photo/photo_intrinsics_test.dart` — NEW - proves header-only dimensions come back for a real fixture and that an undecodable/corrupt header throws at pick time (the HEIC canary).
- `test/features/day_detail/day_detail_entry_tile_test.dart` — Removes both InlinePhotoStrip expectations.
- `test/features/day_detail/support/day_detail_harness.dart` — FakeMediaResolver gains the sync-memo member, FakeMediaStore gains the prefix methods, FakeJournalRepository gains replacePhotosForEntry.
- `test/features/entry_cards/cards/photo_strip_test.dart` — DELETE - follows the widget.
- `test/features/entry_cards/cards/video_body_poster_gate_test.dart` — _GatedMediaResolver gains the sync-memo member.
- `test/features/entry_cards/entry_card_test.dart` — Removes the InlinePhotoStrip expectation and the `photos:` argument; asserts no photo strip is rendered for a text entry.
- `test/features/entry_cards/media/decode_target_test.dart` — NEW - 64px bucket quantisation across a continuous width sweep and across device pixel ratios.
- `test/features/entry_cards/media/media_image_test.dart` — Asserts cacheWidth is set and quantised, and that a memo hit renders the image without a neutral placeholder frame.
- `test/features/entry_cards/media/media_resolver_test.dart` — Covers prefix resolution and that a second resolve for the same id issues no further store call and is available synchronously.
- `test/features/entry_cards/support/entry_cards_harness.dart` — FakeMediaResolver gains the sync-memo member; FakeMediaStore gains blobByPrefix/uniquePrefixFor.
- `test/features/mood/support/mood_harness.dart` — FakeJournalRepository gains replacePhotosForEntry.
- `test/features/search/search_screen_test.dart` — _FakeResolver gains the sync-memo member.
- `test/features/settings/journal_data_controller_test.dart` — Covers reclaimSpace success and failure mapping to DataActionSucceeded/DataActionFailed.
- `test/features/settings/sections/data_section_test.dart` — Covers the Reclaim space row: label present, tap calls reclaimSpace exactly once, feedback surfaced, button disabled while in flight.
- `test/features/settings/support/settings_harness.dart` — FakeSettingsDataController gains reclaimSpace and records invocations.
- `test/features/today/support/today_harness.dart` — StubMediaResolver gains the sync-memo member.
- `test/features/today/today_entry_feed_test.dart` — Drops the InlinePhotoStrip expectations and the photosForEntryProvider overrides; _AvailableVideoResolver gains the sync-memo member.
- `test/features/today/today_providers_test.dart` — _StubJournalRepository gains replacePhotosForEntry.

</details>

### `u8` — Photos in notes, stacked everywhere, with the photo rail

**Wave 5 · risk high · complex/feature · after: `u7`, `u5`**

The photo line renders as a block image on every surface. A PhotoRail under the writing surface shows thumbnails, highlights the one whose source line contains the caret, and carries tap-only controls: Side, Size, Move up, Move down, Replace, Remove, Caption. NO DRAG ANYWHERE - deliberate under WCAG 2.2 SC 2.5.7 and to avoid racing Android's scroll recogniser. A live mini-diagram driven by the same planFloat the renderer calls, so the preview cannot drift from real behaviour.
STRESS FIX (was fatal): the full rail needs roughly 528dp at 48dp targets and does not fit a 360dp phone. On compact width the rail is THUMBNAILS ONLY, and tapping a thumbnail opens a photo options sheet carrying Side/Size/Move/Replace/Remove/Caption.
STRESS FIX (was fatal): block width must be a FRACTION of the measure (Small 0.55, Medium 0.75, Large 0.92, Full 1.0), not an em value clamped to 0.82 of the measure. Under the em rule Small, Medium and Large all collapse to an identical 262pt on every phone, making three of the six controls invisible. Hide the Side control entirely whenever the current measure cannot float, rather than showing a dead toggle.
STRESS FIX: specify an always-present 'Add photo' tile as the first cell of the rail plus a keyboard-accessible control, or a blank note has no discoverable way to add a photo at all.
STRESS FIX: name the caption slot - the alt text doubles as the caption, so it serves screen readers and portable renderers too.
STRESS FIX: Remove emits an inline 'Photo removed - Undo' toast using the app's existing toast widget, since Android has no Ctrl-Z.

**Acceptance.** A note whose source contains a photo line renders that photo as a centred block image sized at its size's fraction of the measure (Small 0.55 / Medium 0.75 / Large 0.92 / Full 1.0, four visibly distinct widths at a 320pt phone measure) on the Today card, in day detail and in the full-note read view with no duplicate photo strip beneath it, while the composer shows a PhotoRail whose first cell is an always-present keyboard-reachable Add photo tile, whose thumbnail highlight follows the caret's source line, which exposes Side/Size/Move up/Move down/Replace/Remove/Caption as tap targets of at least 48dp at composer width and as a photo options sheet when the rail is compact, hides Side entirely whenever planFloat reports the current measure cannot float, shows a mini-diagram driven by that same planFloat, and whose Remove emits an inline 'Photo removed · Undo' toast that restores the removed line byte-for-byte — with no drag gesture recogniser anywhere in the unit.

**Files: 27 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `lib/design/feedback/toast.dart` — Add an optional trailing-action slot to the light Toast variant so it can carry a tappable 'Undo' next to 'Photo removed', which the overlay helper and the dark variant do not support today.
- `lib/features/capture/text/text_composer.dart` — TextComposerConnector supplies the PhotoRail (picker + media resolver + source/selection plumbing) into the new sheet slot on the create-note route.
- `lib/features/capture/text/text_composer_sheet.dart` — Mount an injected photo-rail slot beneath the writing surface (new optional widget/builder param defaulting to null so existing prop-only tests keep passing), expose the controller's source text and selection to it, and 
- `lib/features/day_detail/day_detail_edit_note.dart` — EditNoteConnector supplies the same PhotoRail into the sheet slot so the edit-note route gets photos too.
- `lib/features/entry_cards/entry_card.dart` — Stop mounting InlinePhotoStrip for EntryType.text (line 70-71) now that a note's photos render inline from the source, so a note no longer shows every photo twice; voice/video entries keep the strip.
- `lib/features/notes/model/photo_placement.dart` — NEW: PhotoSide {left,right} and PhotoSize {small,medium,large,full} with the STRESS-FIXED block-width fractions of the measure (0.55 / 0.75 / 0.92 / 1.0), the title-slot attribute grammar ("right medium") parse+format, a
- `lib/features/notes/notes.dart` — NEW barrel for the notes feature (matching calendar.dart / today.dart / entry_cards.dart); U8 adds exports for photo_placement, note_photo_plan, note_photo_block, photo_line_edits, photo_rail and the two sheets.
- `lib/features/notes/notes_providers.dart` — NEW: the composer-side FutureProvider<MediaResolver> the rail thumbnails resolve through, following the day_detail_providers.dart / today_providers.dart per-feature resolver pattern.
- `lib/features/notes/photos/photo_caption_sheet.dart` — NEW: the modal caption editor that writes the alt slot (alt doubles as caption), kept out of the composer so no second EditableText ever mounts beside the writing surface.
- `lib/features/notes/photos/photo_line_edits.dart` — NEW: pure source-string transforms — insertPhotoLineAtCaret, setSide, setSize, setCaption, moveUp, moveDown, replaceReference, removePhotoLine (returning the removed line text and its offset for Undo) — plus photoLineInd
- `lib/features/notes/photos/photo_options_sheet.dart` — NEW: the compact-width modal sheet opened by tapping a rail thumbnail, carrying Side/Size/Move up/Move down/Replace/Remove/Caption at >=48dp plus the mini-diagram, following the showGeneralDialog + DialogHost + sheet-wid
- `lib/features/notes/photos/photo_placement_diagram.dart` — NEW: the live mini-diagram plus its sentence ('Right · Medium — on this screen, text sits above and below'), rendered from the same PhotoPlan the renderer consumes so it cannot drift from real behaviour; shown in the rai
- `lib/features/notes/photos/photo_rail.dart` — NEW: PhotoRail — the horizontal thumbnail strip under the writing surface, with an always-present 'Add photo' tile as the first cell (focusable/traversable so it is keyboard-reachable), caret-following highlight, the ful
- `lib/features/notes/render/note_document.dart` — U4 creates this text-only block renderer; U8 replaces its Photo-block case with StackedPhoto so the photo line paints as a real block image on the feed card, in day detail and in the full-note read view.
- `lib/features/notes/render/note_photo_block.dart` — NEW: StackedPhoto — the centred block image widget driven by the plan, with the mediaId-hash tilt painted inside the reserved box, paper frame/shadow, caption below, cacheWidth from device pixels, and the broken-photo ch
- `lib/features/notes/render/note_photo_plan.dart` — NEW: planFloat(measure, em, side, size, aspect) -> PhotoPlan plus canFloatAt(measure); in U8 it always returns isStacked with width = fraction*measure (never an em value clamped to 0.82) and photoH = min(w/aspect, 1.6*w)
- `test/design/feedback/toast_test.dart` — Cover the new trailing-action slot on the light Toast.
- `test/features/capture/core/text_composer_test.dart` — Add the provider overrides the connector-driven cases now need once TextComposerConnector builds a rail that resolves media.
- `test/features/day_detail/day_detail_edit_note_test.dart` — Same provider overrides for the edit-note route now that EditNoteConnector builds a rail.
- `test/features/day_detail/day_detail_entry_tile_test.dart` — Update the two strip assertions at lines 123 and 141, both built on EntryType.text entries.
- `test/features/entry_cards/entry_card_test.dart` — Update the 'renders the inline photo strip when photos are attached' case (lines 41-56) which asserts InlinePhotoStrip for an EntryType.text entry.
- `test/features/notes/photos/photo_line_edits_test.dart` — NEW: round-trip and caret-preservation tests for every line transform, including that removePhotoLine returns a line which, reinserted at its offset, reproduces the source byte-for-byte.
- `test/features/notes/photos/photo_options_sheet_test.dart` — NEW: tapping a thumbnail at compact width opens the sheet with all seven controls at >=48dp, and the Side control is absent when the measure cannot float.
- `test/features/notes/photos/photo_rail_test.dart` — NEW: Add-photo tile present on a blank note, highlight follows the caret, Remove shows the 'Photo removed · Undo' toast and Undo restores the line, rail renders thumbnails-only at 360dp and the full control row at compos
- `test/features/notes/render/note_photo_plan_test.dart` — NEW: the fraction table — Small/Medium/Large/Full produce four distinct widths at a 320pt phone measure (the defect the em rule caused), plus the 1.6x height clamp.
- `test/features/notes/support/notes_harness.dart` — NEW shared pump harness + fake resolver/picker for the notes widget tests, following test/features/*/support/*_harness.dart.
- `test/features/today/today_entry_feed_test.dart` — Update the InlinePhotoStrip expectation at line 112, which uses text entries.

</details>

### `u10` — Segment note editor, conditional on U6

**Wave 6 · risk high · complex/feature · after: `u6`**

CONDITIONAL. Build ONLY if U6's measurement shows the single buffer is unusable on a mid-tier phone.
The second NoteEditor implementation. partitionSource(src) returns parts whose join is byte-exact with the source; text parts become TextFields and photo lines become real photo cards, so keystroke cost scales with the focused segment rather than the document.
Requires hand-built cross-boundary plumbing: Backspace-merge at offset 0, arrow traversal via getPositionForOffset at the caret x, and focus handoff. Two of three judge lenses named this the worst-propertied subsystem anyone proposed - stateful, in the path of every keystroke at a boundary, unverifiable by golden image, and it costs cross-segment drag-selection in a writing app.
Storage, parser, read renderer, wrap, drafts, photos and GC are untouched by it. That is the entire point of the NoteEditor seam.

**Acceptance.** Flipping the NoteEditor seam to SegmentNoteEditor leaves the joined source byte-identical to what SingleFieldNoteEditor produces for the same key sequence — proven by the partitionSource join-equality property test, the cross-boundary Backspace/arrow/focus-handoff widget tests, and a green run of the five existing composer, edit-note and capture-UI-flow suites with their finders retargeted.

**Files: 16 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `integration_test/capture_ui_flow_test.dart` — EDIT — same retarget at :82; the surrounding find.byType(TextComposerSheet) assertions at :78 and :91 are unaffected.
- `lib/features/capture/editor/note_editor.dart` — EDIT of the seam U5 creates — register SegmentNoteEditor as the second implementation and switch which one the composer builds, keyed off U6's measured character threshold rather than a hardcoded literal. This is the who
- `lib/features/capture/editor/note_source_parts.dart` — NEW — the NoteSourcePart model (text part vs photo-line part, each carrying its source range) and the pure partitionSource(String) whose parts join byte-exact back to the input.
- `lib/features/capture/editor/photo_segment_card.dart` — NEW — the in-flow card a photo-line part renders as instead of a dim chip: resolves the 12-hex prefix through U7's resolver, paints the real image with a quantized cacheWidth, and routes its controls into U8's photo opti
- `lib/features/capture/editor/segment_caret.dart` — NEW — the pure cross-boundary caret rules kept out of the widget so they are testable: which two parts a Backspace at offset 0 merges and where the caret lands in the joined string, the Delete-at-end mirror, and the neig
- `lib/features/capture/editor/segment_note_editor.dart` — NEW — SegmentNoteEditor implementing the U5 NoteEditor interface: holds the per-part TextEditingController/FocusNode lists, rebuilds them from partitionSource when the source changes externally, re-joins the parts into o
- `lib/features/capture/text/text_composer_sheet.dart` — CONDITIONAL EDIT — the writing surface stops being one scrolling editable: the sheet's existing ScrollController/RawScrollbar (:252-262) must drive an outer scroll view over the segment column, and the empty-state placeh
- `test/features/capture/core/text_composer_test.dart` — EDIT — find.byType(EditableText) now matches one editable per text segment; retarget the four call sites at :58, :78, :105 and the controller cast at :113 onto a keyed first segment.
- `test/features/capture/editor/editor_test_support.dart` — NEW (or extended, if U5 already created it) — the pump helper for the segment editor, matching the sibling convention of capture_test_support.dart / photo_test_support.dart / video_test_support.dart.
- `test/features/capture/editor/note_source_parts_test.dart` — NEW — the losslessness property: partitionSource(src) parts join byte-exact over a fuzz corpus covering photo line first, last, adjacent pairs, mid-paragraph, CRLF, no trailing newline and empty source.
- `test/features/capture/editor/photo_segment_card_test.dart` — NEW — the card renders the resolved image in flow and each control rewrites exactly one source line, leaving the rest of the joined string untouched.
- `test/features/capture/editor/segment_caret_test.dart` — NEW — table test over the merge and traversal offset rules, one row per (part layout, caret offset, key) with the expected joined-source offset.
- `test/features/capture/editor/segment_note_editor_test.dart` — NEW — widget tests for the hand-built plumbing: Backspace at offset 0 merges into the previous part with the caret at the seam, arrow up/down lands at the same x in the neighbour, focus handoff across a photo card, and t
- `test/features/capture/text/text_composer_save_hang_test.dart` — EDIT — same retarget of the single find.byType(EditableText) enterText at :76.
- `test/features/capture/text/text_composer_timeout_dedupe_test.dart` — EDIT — same retarget of the single find.byType(EditableText) enterText at :100.
- `test/features/day_detail/day_detail_edit_note_test.dart` — EDIT — same retarget at :70 and :108; this is the edit route's copy of the same finder.

</details>

### `u9` — The float

**Wave 6 · risk high · complex/feature · after: `u8`**

planFloat(measure, em, sizeEm, side, aspect) implementing one clamp and one comparison. em = textScaler.scale(fontSize); measure = min(maxWidth, 35 em); gutter = 1 em; cap = measure - gutter - 19.4 em; photoW = min(sizeEm * em, cap) so the photo SHRINKS BEFORE IT DEMOTES; FLOAT iff size != full and the next block is a paragraph and photoW >= 8.5 em; else stacked. photoH = min(photoW / aspect, 1.6 * photoW) so a portrait photo cannot become a wall.
Sizes are in em, not fractions of the measure: with a fraction, a narrowing window makes the SMALL size demote before the medium one, because the fraction term drops below the minimum-photo gate while the cap has not yet bitten.
PhotoWrapBlock performs the split inside one LayoutBuilder: a TextPainter over the paragraph span at the band width, computeLineMetrics, find the last line fitting beside the photo, getLineBoundary to snap the cut to a line START (never a word boundary - a mid-line cut is the only way this looks broken), then sliceInlineSpan and emit a Row of photo plus head with the tail below.
FLOAT SCOPE RULE, the single most important constraint: a float wraps the NEXT PARAGRAPH BLOCK ONLY. If the next block is a heading, a list, another photo or the end of the note, the photo stacks. Two floats therefore cannot interact, clear is structural rather than implemented, and the TextPainter measures one paragraph rather than the note.
ONE FALLBACK: StackedPhoto is the single return value for every failure - column too narrow, size full, next block not a paragraph, missing or unreadable dimensions, corrupt blob, unparseable token, aspect past the clamp, or the render budget disabling floats. One path, exercised by every phone on every note forever, so it is proven in production long before a slow desktop needs it.
Tilt, paper frame and shadow are paint INSIDE the reserved axis-aligned box, with the plan reserving w + h*sin|theta| so the wrap contour never becomes non-rectangular.
STRESS FIX (performance): cache the split offset per (span identity, text scaler, band bucket) with one line of hysteresis, or a continuous desktop window resize re-splits and re-shapes the paragraph every frame.
STRESS FIX: either make the block width at the demote boundary continuous with the float width it replaces, or stop claiming there is no jump and state the step plainly in the decision table.
Ships with a decision table across widths and text scales, plus goldens.

**Acceptance.** With `flutter test` green, a Photo block whose side is left or right and whose next block is a Paragraph renders as a Row of the photo beside a head slice cut at a line boundary with the tail below exactly when `planFloat` returns a non-stacked plan, every other input (size full, next block not a paragraph, `photoW < 8.5 em`, missing aspect, corrupt blob, `floatEnabled == false`) returns `StackedPhoto`, and both the ~360-row `planFloat` decision table and the twelve width-by-text-scale goldens pass.

**Files: 14 edited.** Full per-file notes are in the dispatch JSON.

<details><summary>File list</summary>

- `.github/workflows/goldens.yml` — EDIT. The paths filter is currently lib/design/**, test/design/goldens/**, assets/fonts/**, pubspec.yaml, .github/workflows/goldens.yml. Add lib/features/notes/** so the golden job actually fires when the float geometry 
- `lib/features/notes/model/float_plan.dart` — NEW. The FloatPlan value type and the pure planFloat(measure, em, sizeEm, side, aspect) function: em = textScaler.scale(fontSize), measure = min(maxWidth, 35 em), gutter = 1 em, cap = measure - gutter - 19.4 em, photoW =
- `lib/features/notes/model/float_split_cache.dart` — NEW. The performance stress fix: a bounded cache of the split offset keyed by (paragraph span identity, text scaler, quantized band bucket) with one line of hysteresis, so a continuous desktop window resize relayouts the
- `lib/features/notes/model/note_render_budget.dart` — NEW. NoteRenderBudget with floatEnabled plus its inherited lookup and enabled-by-default; the kill switch that routes every float to StackedPhoto without touching planFloat's arithmetic. Deliberately a plain InheritedWid
- `lib/features/notes/notes.dart` — EDIT (barrel, created by U4). Adds exports for float_plan.dart, note_render_budget.dart, float_split_cache.dart and photo_wrap_block.dart, matching the per-feature barrel convention of lib/features/entry_cards/entry_card
- `lib/features/notes/widgets/note_document.dart` — EDIT (created by U4, extended by U8). The photo-block branch changes from always-StackedPhoto to: if side is left/right and the NEXT block is a Paragraph, emit PhotoWrapBlock for the pair and consume the paragraph; other
- `lib/features/notes/widgets/photo_wrap_block.dart` — NEW. PhotoWrapBlock: one LayoutBuilder, a State-owned TextPainter that is reused and disposed (never allocated-and-abandoned per frame), layout at plan.band, computeLineMetrics, lastIndexWhere(baseline + descent <= plan.
- `lib/features/notes/widgets/stacked_photo.dart` — EDIT (created by U8). The demote-discontinuity stress fix: StackedPhoto takes the float width it is replacing at the demote boundary so the block starts at that width and grows as the measure falls, instead of jumping fr
- `test/design/goldens/images/note_float_*.png` — NEW. The twelve captured PNGs, named note_float_<case>.png, resolved relative to the test file's directory per cluster-H R4.
- `test/design/goldens/note_float_golden_test.dart` — NEW. The ~12 goldens across widths and text scales (float left, float right, demote boundary either side, tilt reserved, 9:16 aspect clamp, 0.9/1.0/1.15/1.5 scales), tagged @Tags(['golden']), using pinGoldenSurface + gol
- `test/features/notes/model/float_plan_table_test.dart` — NEW. The ~360-row pure-function decision table over (measure width x text scale x size x side x next-block-kind) asserting FloatPlan field-for-field with no render tree — the acceptance artifact for the responsive rule, 
- `test/features/notes/model/float_split_cache_test.dart` — NEW. Cache hit on an unchanged (span, scaler, band bucket) key; recompute only when the new band would move the split across a line boundary; hysteresis proven by walking a band width back and forth across a bucket edge 
- `test/features/notes/support/note_harness.dart` — EDIT or NEW depending on U4/U8 (likely created by them, mirroring test/features/entry_cards/support/entry_cards_harness.dart). Adds the float fixtures: pump a NoteDocument at an exact width and textScaler with a fake med
- `test/features/notes/widgets/photo_wrap_block_test.dart` — NEW. Widget tests: the cut is always a line start; head + tail plain text equals the paragraph's plain text; inline bold/italic survive the slice; Row crossAxisAlignment is start; every fallback input returns StackedPhot

</details>

---

## 6. Execution: six waves, not one fan-out

**This feature is inherently mostly sequential, and pretending otherwise would be wrong.**

The planner was run over all ten units at once and fused nine of them into a single MSP of 173 files —
one unreviewable PR — and produced a scheduling cycle. That is not a mis-cut on my part; it is the
shape of the work. Only 29 of 179 files are contended, but they are the four surfaces the feature is
about:

| Contended surface | Units touching it |
|---|---|
| `lib/features/capture/text/text_composer_sheet.dart` | u1, u3, u5, u8, u10 |
| `lib/features/today/today_entry_feed.dart` | u1, u2, u7 |
| `lib/features/day_detail/day_detail_panel.dart` | u1, u2, u3 |
| `lib/features/entry_cards/entry_card.dart` | u2, u7, u8 |

The feature *is* "change how notes are written and displayed", and there are exactly four places notes
are written and displayed. Extracting barrels and test scaffolding into a spine frees only one unit.

So the plan is **waves**: file-disjoint within a wave, a human merge between waves. Each wave is one
`fanout --exec` run against the previous wave's merged result.

| Wave | Units | Parallel? | Gate before the next wave |
|---|---|---|---|
| 1 | `u1` | solo | human review + merge |
| 2 | `u3`, `u4` | yes | human review + merge |
| 3 | `u2`, `u5` | yes | human review + merge |
| 4 | `u6`, `u7` | yes | human review + merge |
| 5 | `u8` | solo | human review + merge |
| 6 | `u10`, `u9` | yes | human review + merge |

**Wave 4 carries the decision point.** `u6` measures the editor on real Android hardware and its
numbers decide whether `u10` is ever built. Everything before it stands alone: if the measurement is
bad, five useful units have already landed and the photo work re-plans against a known number rather
than a hope.

### Coupling verdict (mandatory, rendered before dispatch)

The planner returned **zero `coupling_review` pairs in every wave**. That is a real result, not a
skipped step: within each wave no two units touch the same risk surface, so no soft-coupling signal
fires. The file-disjointness that defines the waves is doing the work the verdict would otherwise
adjudicate. Each wave is re-planned before dispatch and any pair that appears gets an explicit ruling,
defaulting to serialise.

### Risk markers and tiering

`--risk-markers database,journal,media` — the data layer, where a mistake is unrecoverable. Every unit
tiers `top`, because every unit is marked `complex` and `cheap` requires *both* mechanical and
low-blast-radius. That is honest: none of this is mechanical.

---

## 7. Verification

**`fullValidationCmd` is the only gate, run locally in the foreground and read.** No GitHub check runs
a Dart test in this repo, so CI is never evidence.

**Never `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes
into the real journal container. Name a single file.

**Measure the baseline on your own branch.** It has gone stale three times on this project.

**The manual pass is owed by a human on macOS** — no agent runs this app; `flutter run -d macos` needs
a TTY and the standalone binary renders a black window. Android measurement in `u6` needs a real
device; this machine has no Android SDK.

**`gh pr create` and `gh pr merge` are denied.** PRs go through the `pr-create` tool; every merge is a
human action. Fanout stops at the draft PR by design.

---

## 8. Out of scope

- Any database migration, in any unit, for any reason. `schemaVersion` stays 1.
- Any new package dependency.
- Wrap-while-typing (R1).
- Free (x, y) photo placement (R2).
- RTL, tables, footnotes, task lists, nested lists, reference links, HTML blocks.
- Sync. The settings screen ships a disabled sync section; if notes ever sync, the note format becomes a wire format and a merge unit. Nothing here designs for that, and it should be reconsidered before sync ships.
- Voice and video entries. Their composers are untouched.

---

## 9. Honest residue

**The biggest risk is keystroke cost on a real mid-tier Android phone in a long, live-styled buffer.**
It is the only number in this design with no measured analogue anywhere, every figure in the research
is desktop Apple Silicon under `flutter_test`, and the plausible multiplier spans 5x to 15x — the
difference between a fine editor and a broken one. `u6` exists to retire it, and `NoteEditor` is an
interface with two implementations from `u5` so the failure is a flag flip plus a build, not a rewrite.

**The thing the flag flips to is itself the worst-propertied subsystem anyone proposed.** `u10`'s
cross-boundary Backspace-merge, arrow traversal and focus handoff are hand-built, stateful, in the path
of every keystroke at a boundary, unverifiable by golden image, and cost cross-segment drag-selection.
If `u6` comes back bad, the cost rises by a genuinely hard unit and the editor loses a capability it
has today. That is not solved here and is not pretended to be.

**The 19.4 em residual is a measured Newsreader constant** and must be re-measured if the body family
changes. The 8.5 em minimum photo width and the 21.8 em comfort target are labelled judgements, not
arithmetic — no study covers a band beside a float, and dressing a judgement as a number is how the
previous attempt at this spec failed review.
