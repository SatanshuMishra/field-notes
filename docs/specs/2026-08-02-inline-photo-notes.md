# Inline Anchored Photo Notes — Implementation Spec (P0–P5)

Thread: `.claude/ledger/threads/inline-photo-notes.md`
Binding decision: `.claude/ledger/decisions/2026-08-02-oq6-inline-anchored-photo-model.md`
Phases: **P0, P1, P2, P3, P4, P5** — six phases, six PRs, six branches
Base: `origin/main` at **`712c978`**
Structural template: `docs/specs/2026-08-02-prototype-alignment-cluster-g.md`
Citation sources: `docs/prototype/project/md-scrapbook.js` (the photo card, **look only**), `docs/prototype/project/Field Notes.dc.html` (the picking affordance), and the app's own source at `712c978`

---

## 0. What this document is, and why it exists

This is the **implementation spec for one new subsystem**, not a slice of the prototype-alignment spec. The adopted model is not the prototype's model, so the parent spec's §6.1 exclusion of free-manipulation photo cards stands and is not contradicted (`decisions/2026-08-02-oq6-inline-anchored-photo-model.md`, Consequences).

It takes the **structure** of the Cluster G run spec — the document the ledger names "THE template for any future slice" — and none of its content. Every §0 resolution below is decided here so that no implementer meets one mid-flight. That discipline exists because this project's own history says it must: the C5 caption and three C7 ladder rows were lost precisely because an implementer met an unreachable anchor and made a judgement call instead of stopping (`decisions/2026-07-28-c5-ships-as-is.md`, `decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md`).

**The model is DECIDED and is not re-derived here.** A photo is anchored to a POSITION IN THE NOTE TEXT, floated left or right, with text wrapping beside it and continuing below. The anchor is a U+FFFC sentinel in the note text; the Nth sentinel binds to the Nth `entry_photos` row by `sortOrder`. The exclusion rectangle is the axis-aligned bounding box of (card rotated by theta) UNION (both tape strips). Manipulation lives in a separate arrange mode; write mode is always plain editable text. Cap 8.

### The headline recon result, stated up front

**Seven facts, every one re-read from the source at `712c978` while composing this document. Five of them change what a phase must do.**

1. **The binding decision record is NOT on `main`.** `git show origin/main:.claude/ledger/decisions/2026-08-02-oq6-inline-anchored-photo-model.md` does not resolve; neither does `threads/inline-photo-notes.md`, `sessions/2026-08-02-03-prototype-design-alignment.md`, or `decisions/2026-08-02-h1-splits-by-font-risk.md`. All four live only on `chore/ledger-handoff-session-29` (`82c034e`). **An implementer branching from `main` cannot read the model.** Until that ledger PR merges, every dispatch must carry the decision record's text inline or name the branch. This is a dispatch hazard, not a code defect (R0).
2. **`entry_photos` has no `sortOrder` update path, and P2 needs one.** `EntryPhotosDao` exposes `insertPhoto`, `activePhotosForEntry`, `watchActivePhotosForEntry` and `softDelete` — nothing else (`lib/data/journal/entry_photos_dao.dart:10-51`). Deleting a sentinel in write mode must unanchor *that* photo, which means re-writing `sortOrder`. **That is an UPDATE on an existing `IntColumn`, structurally identical to `softDelete` at `:44-51`, and it is NOT a migration** (R12).
3. **Side, size and rotation have nowhere to live, and the answer is not a column.** `EntryPhotos` carries `id, entryId, mediaId, sortOrder, createdAt, updatedAt, deletedAt` (`lib/data/database/tables.dart:36-47`) and nothing else. P4's flip/resize and P5's rotation are per-photo state the anchor cannot carry. The resolution is the existing generic `Settings` key/value table, with named cleanup obligations (R21). **A migration is forbidden and a packed `sortOrder` is forbidden** (R22).
4. **The float does NOT need a custom `RenderBox`.** `LayoutBuilder` + a disposed-in-place `TextPainter` split + a `Stack` of two `Text` widgets expresses it completely, keeping `Text`'s own selection, semantics and text scaling (R15). The custom render object is rejected.
5. **flutter/flutter#159171 is narrower than the ledger states.** Verified open, titled *"TextField as WidgetSpan mixes parent TextField initial text when delete or arrow keys used"* — [flutter/flutter#159171](https://github.com/flutter/flutter/issues/159171). Its reproduction requires a **nested `TextField` inside the `WidgetSpan`**. A non-focusable, `IgnorePointer`-wrapped chip cannot reproduce it. P2 still proves the three traversal behaviours by measurement, because nothing in this repo covers `WidgetSpan` caret handling (R9, R10).
6. **U+FFFC is not an arbitrary choice — it is Flutter's own placeholder character.** `PlaceholderSpan.placeholderCodeUnit = 0xFFFC` (`/opt/homebrew/share/flutter/packages/flutter/lib/src/painting/placeholder_span.dart:51`), written into the plain text by `PlaceholderSpan.computeToPlainText` at `:73`. A `WidgetSpan` substituted for a literal U+FFFC round-trips through `toPlainText()` to the byte-identical string, so caret offsets are preserved 1:1 with zero mapping layer (R8).
7. **`PhotoTray` is dead UI with six live tests.** `photo_tray.dart:9` declares `defaultMaxPhotos = 8`; `photo_tray_test.dart` holds six passing cases including the cap. Nothing in `lib/` imports the widget, its barrel `photo.dart:5`, or `photoPickerProvider`. Mounting it is the smallest possible P1 and converts six dead tests into live coverage (R5).

---

### PRIMITIVE RESOLUTIONS — decided at spec time, not left to the implementer

**Twenty-eight decisions.** Each states the problem, the chosen resolution, and what was rejected and why. Per `decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md`, every resolution names the receipt that would red if it is wrong — none is reasoned into place.

#### Cross-cutting

**R0 — The dispatch for every phase carries the decision record inline, or names `chore/ledger-handoff-session-29`.**

*Problem.* `origin/main` at `712c978` does not contain `decisions/2026-08-02-oq6-inline-anchored-photo-model.md`, `threads/inline-photo-notes.md`, or `sessions/2026-08-02-03-prototype-design-alignment.md`. Verified: `ls .claude/ledger/decisions/` on a worktree at `712c978` ends at `2026-08-01-msp-prs-target-main-never-another-msp-branch.md`. `git branch -a --contains 82c034e` returns `chore/ledger-handoff-session-29` alone.

*Resolution.* Until the ledger handoff merges, a dispatch either (a) quotes the Decision and Consequences paragraphs of the OQ-6 record verbatim, or (b) instructs the implementer to read them via `git show chore/ledger-handoff-session-29:<path>`. **This spec is the durable copy**: everything a phase needs is reproduced below, so an implementer who can read only this file is not blocked.

*Receipt.* `git show origin/main:.claude/ledger/decisions/2026-08-02-oq6-inline-anchored-photo-model.md` exits non-zero at `712c978`.

---

**R1 — NO DATABASE MIGRATION, IN ANY PHASE. If a phase appears to need one, STOP AND REPORT.**

`schemaVersion` is `1` (`lib/data/database/app_database.dart:17`) and `onUpgrade` unconditionally throws a `StateError` (`:25-32`). There is no `drift_schemas/`, no migration harness, and no successful-upgrade test — only the refusal path is pinned, by `test/data/database/app_database_test.dart`. A wrong first migration makes every existing journal unopenable.

`entry_photos` carries this model **unchanged**. The only persistence surfaces this ladder adds are (a) an UPDATE of the existing `sortOrder` column (R12) and (b) rows in the existing `Settings` key/value table (R21). Neither alters a schema.

*Receipt.* Any `.sql` file, any `schemaVersion` edit, or any `MigrationStrategy` change in a diff is out of bounds on sight.

---

**R2 — NEVER `flutter test integration_test/` as a directory. NEVER `git switch main`.**

`integration_test/capture_save_persist_test.dart` writes into the real journal container. Name a single file if one is needed. `git switch main` has aborted twice on this repo over uncommitted ledger edits; use `git switch -c <branch> <base-ref>`.

---

**R3 — CI IS NOT EVIDENCE. The only gate is `fullValidationCmd`, run locally, in the foreground, and read.**

No GitHub check runs a Dart test in this repo (`decisions/2026-07-20-ci-gates-are-hollow-for-dart.md`). Verbatim, from `receipts.config.json`:

```
export PATH="/opt/homebrew/bin:$PATH" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

`W These options have been removed and were ignored: --delete-conflicting-outputs` is expected and is not a failure. Never background it: a subagent's background shells are swept at teardown, and two earlier attempts on this project were lost that way.

---

#### P0 — the feasibility spike

**R4 — P0's geometry and split code lives in the TEST TREE and is PROMOTED to `lib/design/layout/` by P3. P0 touches zero files under `lib/`.**

*Problem.* The thread mandates P0 as TEST-ONLY with zero files under `lib/`, yet P3 needs the identical math in product code. Copy-paste between the two is the drift this project has already been bitten by.

*Resolution.* P0 creates two source files **in the test tree**, written as pure Dart with no widget dependencies:

| P0 path (test tree) | P3 path (product) |
|---|---|
| `test/features/entry_cards/photo/inline_photo_geometry.dart` | `lib/design/layout/inline_photo_geometry.dart` |
| `test/features/entry_cards/photo/inline_photo_float_layout.dart` | `lib/design/layout/inline_photo_float_layout.dart` |

**P3 MOVES both files** (`git mv`, byte-identical content plus the import-path edits), adds `lib/design/layout/layout.dart` as the barrel — matching the one-barrel-per-subdirectory convention Cluster G's R10 established for `lib/design/art/` — and retargets P0's spike test to import through the barrel. After P3 the **owner is `lib/design/layout/`** and no test-tree copy exists.

*Rejected: P0 writing straight into `lib/`.* It breaks the thread's own TEST-ONLY constraint, which exists so that a red P0 costs one revert of zero product code.
*Rejected: two independent implementations.* That is exactly the drift the promotion avoids.

*Receipt.* After P3, `ls test/features/entry_cards/photo/inline_photo_geometry.dart` must fail.

---

#### P1 — wiring photos into the note composer

**R5 — P1 MOUNTS `PhotoTray` unchanged. It does not author a picker.**

*Problem.* The note composer has no picking affordance of any kind. `TextComposerConnector._persist` builds `TextCaptureRequest(date: widget.date, text: text)` at `text_composer.dart:104` and omits `photos:` entirely, even though the parameter exists with a default (`capture_service.dart:59`).

*Resolution.* P1 mounts the shipped `PhotoTray` (`lib/features/capture/photo/photo_tray.dart:11`) inside `TextComposerSheet`'s body, in the footer row the prototype puts the button in (`Field Notes.dc.html:470`). It is passed `libraryLabel: 'Add memory'` — the prototype's own label (`:471`, `:772`) — and its `cameraLabel` default is left alone. `maxPhotos` is left at its declared `defaultMaxPhotos = 8` (`photo_tray.dart:9`), which is the decision record's cap, already correct, already tested at `photo_tray_test.dart:123`.

On macOS, `ImagePickerPhotoPicker.supportsCamera` is `Platform.isAndroid || Platform.isIOS` (`image_picker_photo_picker.dart:44`), so the desktop composer renders exactly **one** button. That is what the prototype draws.

*This is not a contradiction of the OQ-6 decision.* The tray is rejected as a **display** model — a grid at the bottom with no narrative connection. It is retained as the **input** affordance. Display in P1 is `InlinePhotoStrip`; display from P2 is the anchored card.

*Rejected: authoring a coral "Add memory" pill in P1.* P1's entire risk budget is spent wiring a `photos:` path that has never executed in production; adding a new widget in the same PR doubles the surface for zero behavioural gain. The prototype's pill chrome is preserved verbatim in §6.1 so it cannot be lost.
*Rejected: restyling `PhotoTray` in P1.* Styling is exempt from the admission gate and belongs to a cosmetic pass, not to the phase that makes the feature reachable.

*Receipt.* `photo_tray_test.dart`'s six cases must pass **unmodified**; they become live coverage the moment the widget is mounted.

---

**R6 — The picker is HIDDEN on the edit path, and that is load-bearing, not cosmetic.**

*Problem.* `TextComposerSheet` is shared by two connectors. `TextComposerConnector` writes through `CaptureService.capture` (`text_composer.dart:100-107`), which attaches photos at `journal_capture_service.dart:68-85`. `EditNoteConnector` writes through `JournalRepository.updateEntryText` (`day_detail_edit_note.dart:58-61`), whose signature is `{required String id, required String textContent}` (`lib/domain/repositories/journal_repository.dart:29-32`) — **there is no photo write path on the edit route at all.** A picker mounted unconditionally would let a user pick eight photos on the edit path and silently discard every one on save.

*Resolution.* `TextComposerSheet` gains `ValueChanged<List<CaptureMedia>>? onPhotosChanged`, defaulting to `null`. The tray renders **only when it is non-null**. `TextComposerConnector` passes a handler; `EditNoteConnector` passes nothing.

*Rejected: a `bool showsPhotoPicker` flag.* A nullable callback makes the invalid state — a visible picker with nowhere to send its output — unrepresentable.
*Rejected: adding a photo write path to `updateEntryText` in P1.* That is a domain change on the app's only note-mutation path, in a phase whose job is reachability. Attaching photos to an existing entry is deferred (§6.1).

*Receipt.* A new case asserting `find.byType(PhotoTray)` is `findsNothing` under `EditNoteConnector`.

---

**R7 — The unmatched-sentinel STRIPPER ships in P1, not P2. This is what makes a P2 revert safe.**

*Problem, and it is the thread's own stated risk.* If the stripper shipped in P2, reverting P2 would leave notes whose text contains U+FFFC being rendered by a `NoteBody` that knows nothing about it — a literal OBJECT REPLACEMENT CHARACTER, which most fonts render as `.notdef` tofu. That is "stray replacement characters in users' notes", precisely the outcome the thread forbids.

*Resolution.* **P1** ships `lib/features/entry_cards/cards/photo_anchors.dart`:

```dart
const int photoAnchorSentinel = 0xFFFC;

String stripPhotoAnchors(String text);
List<int> photoAnchorOffsets(String text);
int photoAnchorCount(String text);
```

`stripPhotoAnchors` removes every U+FFFC code unit and collapses a resulting doubled space to one. `NoteBody.build` applies it to `text` before both the blank check and the render, so the empty-note affordance still fires for a note that is nothing but anchors.

`photoAnchorSentinel` is declared as `PlaceholderSpan.placeholderCodeUnit`'s value and is the **only** place the constant appears; no literal `'￼'` may occur anywhere else in `lib/`.

**P1 is justified on its own terms, independent of P2**: a user can paste U+FFFC today and `NoteBody` will render tofu. P1 is the first phase in which a note's text and its photos are related at all, so it is the correct home.

*Receipt.* A P1 case pumping `NoteBody(text: 'a￼b')` and asserting the rendered string is `'ab'`.

---

#### P2 — inline anchoring via the U+FFFC sentinel

**R8 — The sentinel encoding, stated exactly once, here.**

- **Character.** U+FFFC OBJECT REPLACEMENT CHARACTER, a single UTF-16 code unit outside the surrogate range. `String.indexOf`, `codeUnitAt` and integer offsets are exact; no rune iteration is required and none may be used.
- **Binding.** Scan the note text from index 0 by UTF-16 code unit. The **Nth** U+FFFC (0-based) binds to the **Nth** element of `activePhotosForEntry(entryId)`, which is already `deletedAt IS NULL` and already `ORDER BY sort_order ASC` (`entry_photos_dao.dart:30-35`). The `sortOrder` values need not be dense and need not start at zero; only their **ascending order** is load-bearing. `InlinePhotoStrip` already sorts by the same key (`photo_strip.dart:31`).
- **Cardinality.** `sentinelCount` and `photos.length` are independent. Neither is constrained by the other at rest.
- **Excess sentinels** (`index >= photos.length`): **STRIPPED from the rendered output.** Not rendered as a glyph, not rendered as a box, not rendered as a placeholder. The surrounding text closes up. This is `stripPhotoAnchors` applied to the tail (R7).
- **Excess photos** (`index >= sentinelCount`): rendered **below the note text** by the existing `InlinePhotoStrip` (`photo_strip.dart:14`) — the P1 rendering, unchanged. Nothing is ever hidden.
- **Normalisation on write.** The composer strips every sentinel at index `>= photos.length` from the text **before** the `capture`/`updateEntryText` call, so the database never stores an orphan.
- **Whitespace.** A sentinel is a character, not a block. It may sit mid-word. The render path does not insert or remove whitespace around it beyond `stripPhotoAnchors`' single-space collapse.

*Why U+FFFC and nothing else.* `PlaceholderSpan.placeholderCodeUnit = 0xFFFC` (`placeholder_span.dart:51`) is the character Flutter itself writes into plain text for every `WidgetSpan` (`:73`). Substituting a `WidgetSpan` for a literal U+FFFC in `buildTextSpan` produces a span tree whose `toPlainText()` is **byte-identical** to `value.text`. Caret offsets, selection offsets and `TextEditingValue` composing ranges therefore need no mapping layer at all. Any other sentinel (a private-use codepoint, a marker string) would require one.

---

**R9 — Write mode renders each sentinel as a NON-FOCUSABLE `WidgetSpan` chip, wrapped in `IgnorePointer`. This is what puts flutter/flutter#159171 structurally out of reach.**

*Problem.* [flutter/flutter#159171](https://github.com/flutter/flutter/issues/159171) is **open**, titled *"TextField as WidgetSpan mixes parent TextField initial text when delete or arrow keys used"*. Its reproduction is a **`TextField` nested inside a `WidgetSpan`** of a parent `TextField`'s custom controller; delete and arrow keys then replace the child field's text with the parent's initial value, on Windows, macOS, Android and iOS with a hardware keyboard.

*Resolution.* `TextComposerSheet` overrides `TextEditingController.buildTextSpan` on a new `PhotoAnchorTextEditingController`. Each U+FFFC in `value.text` becomes:

```dart
WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: IgnorePointer(child: AnchorChip(index: n)),
)
```

`AnchorChip` is a `StatelessWidget` returning a `SizedBox` + `DecoratedBox` + `Text`. It contains **no `Focus`, no `FocusNode`, no `GestureDetector`, no editable, and no `Semantics(textField: true)`**. It cannot reproduce #159171 because the defect requires a nested editable.

*Declared fallback, so no implementer invents one.* If the three proofs at R10 fail on either platform, P2 falls back to **plain `TextSpan` styling**: the sentinel is emitted as a `TextSpan(text: '￼', style: TextStyle(color: Palette.coral, background: <coral12 Paint>))` with no placeholder at all, accepting whatever glyph the platform font resolves for U+FFFC. That path is #159171-free by construction and costs only visual polish. **The fallback is taken by measurement, never by preference.**

*Rejected: rendering the anchored card itself inside the editor.* Editable text that wraps is structurally impossible in Flutter (`RenderEditable` holds one `TextPainter` over one linear string) and is out of scope by the decision record.
*Rejected: a `TextField`-bearing or tappable chip.* That is #159171's exact reproduction.

---

**R10 — #159171 is PROVEN SURVIVABLE by six measured cases, and `debugDefaultTargetPlatformOverride` is mandatory in every one.**

*Problem.* Under `flutter test`, `defaultTargetPlatform` is forced to `android` by an assert in the Flutter SDK's `_platform_io.dart` keyed on `FLUTTER_TEST` — the environmental fact Cluster G's R25 established. A test that does not override it proves nothing about macOS or iOS, which are the two platforms #159171 names for hardware-keyboard input.

*Resolution.* P2 ships `test/features/capture/text/anchor_chip_traversal_test.dart` with three behaviours, each run under `TargetPlatform.macOS` and `TargetPlatform.iOS` via `debugDefaultTargetPlatformOverride` set in `setUp` and cleared in `tearDown`. Six cases. Each pumps `TextComposerSheet` with `initialText: 'ab￼cd'` and one photo.

| # | Behaviour | Setup | Assertion |
|---|---|---|---|
| 1 | **Arrow-key traversal** | selection collapsed at offset 2 (immediately before the sentinel); `sendKeyEvent(LogicalKeyboardKey.arrowRight)` | `controller.selection` is collapsed at **3**; `controller.text` is `'ab￼cd'` unchanged, compared by `==` on the whole string |
| 2 | **Backspace at the boundary** | selection collapsed at offset 3 (immediately after the sentinel); `sendKeyEvent(LogicalKeyboardKey.backspace)` | `controller.text == 'abcd'`; `photoAnchorCount` is 0; the previously-anchored photo appears in `InlinePhotoStrip` on the next render |
| 3 | **Select-through** | selection collapsed at 2; `shift`+`arrowRight` twice, then `sendKeyEvent` for the character `x` | after the two shift-arrows `controller.selection` is `TextSelection(baseOffset: 2, extentOffset: 4)` and `controller.text` is unchanged; after typing, `controller.text == 'abxd'` — exactly the two selected code units replaced |

**The measurement is the gate.** If any of the six fails, R9's declared fallback is taken in the same PR and the six cases are re-run against it. A phase that ships without reading these six results has not run the gate.

*A green here does NOT license a nested editable in a `WidgetSpan` later.* The proof is scoped to the non-focusable chip.

---

**R11 — Anchor bookkeeping is a live prefix/suffix delta on the controller, never a diff at save time.**

*Problem.* U+FFFC characters are indistinguishable from one another. If the user deletes the **middle** sentinel of three and the binding is recomputed at save time by counting alone, the surviving sentinels re-index to 0 and 1, and photo 1 silently takes photo 0's place while photo 2 becomes the unanchored tail. The wrong image moves. That is a correctness defect, not a polish gap.

*Resolution.* `PhotoAnchorTextEditingController` holds `List<String> _anchoredPhotoIds` in document order and maintains it on every `TextEditingValue` change. Because a plain-text editor produces a single contiguous replacement per change, the delta is recoverable in O(n) with no diff library:

1. Scan the common prefix of `oldText` and `newText` to get `start`.
2. Scan the common suffix (stopping at `start`) to get `oldEnd` and `newEnd`.
3. An anchor whose offset is `< start` is unchanged.
4. An anchor whose offset is in `[start, oldEnd)` is **removed** — the photo it named becomes unanchored.
5. An anchor whose offset is `>= oldEnd` shifts by `newEnd - oldEnd`.
6. A newly-inserted U+FFFC within `[start, newEnd)` claims the first photo not currently in `_anchoredPhotoIds`, in `sortOrder` order.

*Rejected: recomputing the binding by count at save time.* It moves the wrong image, as above.
*Rejected: a Myers diff at save time.* Hundreds of lines to recover information the controller already had for free.
*Rejected: encoding the photo id in the text next to the sentinel.* It pollutes the user's own words and breaks "write mode is plain editable text".

*Receipt.* R10 case 2 — backspacing the only sentinel must unanchor **that** photo — plus a P2 case that deletes the middle of three and asserts photos 0 and 2 stay anchored.

---

**R12 — P2 adds `updateSortOrder` to the DAO, the repository and its interface. It is an UPDATE on an existing column and is NOT a migration.**

*Problem.* R11's step 4 leaves the surviving anchors bound to the right photos only if the persisted `sortOrder` values are rewritten to match the new document order. `EntryPhotosDao` has no such method (`entry_photos_dao.dart:10-51`).

*Resolution.* Three additive edits, none of them a schema change:

```dart
Future<int> updateSortOrder({
  required String id,
  required int sortOrder,
  required int updatedAt,
});
```

- `EntryPhotosDao` — the body is `(_db.update(_db.entryPhotos)..where((t) => t.id.equals(id))).write(EntryPhotosCompanion(sortOrder: Value(sortOrder), updatedAt: Value(updatedAt)))`, the identical shape as `softDelete` at `:44-51`. `deletedAt` is **never** written.
- `DriftJournalRepository.reorderPhotos({required String entryId, required List<String> photoIdsInOrder})` — wraps the whole rewrite in `_db.transaction`, the pattern already used at `drift_journal_repository.dart:32`, `:63`, `:82`.
- `JournalRepository` gains `reorderPhotos` as an interface member.

`sortOrder` carries **no unique index** — the only unique index in the schema is `days_date_active` (`tables.dart:3-6`) — so a transient duplicate mid-transaction cannot violate a constraint. The transaction is for atomicity, not for uniqueness.

**`JournalRepository` is an `abstract interface class` (`journal_repository.dart:3`). Growing it does not red the suite; it breaks the BUILD.** Every implementer must gain the member. The known implementers are `DriftJournalRepository` and `FailingJournalRepository` (`test/features/capture/core/capture_test_support.dart:23`), the latter of which forwards via `noSuchMethod` at `:81` and therefore may need nothing — **verify by compiling, not by reading.** Updating a test fake to satisfy an interface is in-fence maintenance: it changes no assertion, adds no case and removes none.

*Rejected: deferring `reorderPhotos` to P4.* P2 is the phase that lets a user delete a sentinel; shipping the delete without the reorder ships the wrong-image defect.

*Receipt.* A repository case asserting `updateSortOrder` writes `sortOrder` and leaves `deletedAt` null.

---

**R13 — The card's look, resolved to Flutter values. `md-scrapbook.js` is authoritative for the LOOK ONLY.**

The prototype's cards are opaque `#fff` overlays inside a `pointer-events:none` absolute layer that occludes text; its geometry never persisted, and every card is a hatch div containing the word "photo" with no real image. **None of that behaviour is adopted.** These values are.

| Value | Prototype | Flutter |
|---|---|---|
| card width x height | `:334-335` `w: opt.w \|\| 210`, `h: opt.h \|\| 168` | aspect ratio **exactly 1.25 (5:4)**; width is derived (R14) |
| frame surface | `:363` `background:#fff` | `Palette.photoFramePaper` = `Color(0xFFFFFFFF)` — **new token** |
| frame padding | `:363` `padding:8px` | `EdgeInsets.all(8)` at the reference width, scaled by `s` (R16) |
| corners | `:363` carries **no** `border-radius` | `BorderRadius.zero`. The `polaroid` branch at `:381` has `border-radius:12px`; that branch is **not** the adopted style |
| frame shadow | `:363` `0 12px 26px -10px rgba(40,30,18,.55)` | `Shadows.photoFrame` = `BoxShadow(color: Color(0x8C281E12), offset: Offset(0, 12), blurRadius: 26, spreadRadius: -10)` — **new token** |
| tape A | `:365` `top:-11; left:16; width:56; height:22; rotate(-8deg)` | see R16 |
| tape B | `:366` `top:-9; right:18; width:52; height:22; rotate(7deg)` | see R16 |
| tape surface | `:365-366` `rgba(217,201,166,.82)` via `_alpha('#d9c9a6', .82)` (`:492-497`) | `Palette.photoTape` = `Color(0xD1D9C9A6)` — **new token**. `0.82 x 255 = 209.1 -> 0xD1`; `#d9c9a6 = (217,201,166)` |
| tape shadow | `:365-366` `0 1px 3px rgba(0,0,0,.14)` | `Shadows.photoTape` = `BoxShadow(color: Color(0x24000000), offset: Offset(0, 1), blurRadius: 3)` — **new token**. `0.14 x 255 = 35.7 -> 0x24` |
| default tilt | `:336` `Math.random() * 8 - 4` — a **±4deg** range | deterministic, never random (R17) |

The CSS-to-Flutter shadow convention is 1:1 on all four numbers, established by `Shadows.panelLift` (`lib/design/tokens/shadows.dart:105-112`) mapping `0 44px 96px -30px rgba(30,20,10,.72)` to `offset: Offset(0, 44), blurRadius: 96, spreadRadius: -30`. Do not re-derive a sigma.

**The image itself is `MediaImage`** (`lib/features/entry_cards/media/media_image.dart:9`), already carrying the resolver, the missing-media placeholder and the optional foreground border. The prototype's `.ms-fill` hatch (`:135`) is **not** adopted; the app's own `CrossHatchPlaceholder` already covers that case through `MediaImage`.

---

**R14 — Card width is a fraction of the text column, clamped in logical pixels. `210` is the CEILING, not the size.**

*Problem.* `210` is a fixed pixel width in a 760px composer whose page padding is 54 per side (`text_composer_sheet.dart:30`), i.e. `210/652 = 0.322` of the text column. The entry card on Today is far narrower — `note_body_test.dart:15` pumps at 360. A hardcoded 210 would occupy 58% of a Today card and leave no room to float.

*Resolution.*

```
widthFraction default 0.32
width = clamp(widthFraction * columnWidth, 96.0, 210.0)
height = width / 1.25
```

`210` is the prototype's own width and is the ceiling. `96` is the floor below which a 5:4 photo is not legible; below it the float degrades to a full-width block (R19). P4's resize clamps `widthFraction` to `[0.20, 0.60]` **before** the pixel clamp is applied.

---

**R15 — The float is `LayoutBuilder` + `Stack` + two `Text` widgets. NO custom `RenderBox`.**

*Problem.* Flutter has no text-exclusion API at any layer — verified in `ParagraphBuilder`, `TextPainter`, `RenderParagraph`, `RenderEditable` and Skia's `SkParagraph`, with [flutter/flutter#50171](https://github.com/flutter/flutter/issues/50171) (*"Need a line/word breaker for custom text rendering"*) **open** since 2020 and explicitly naming "wrapping text around exclusion paths" as the unserved use case. The obvious response is a custom `RenderBox` that paints its own paragraphs.

*Resolution.* The two-paragraph split (R18) needs `TextPainter` only to compute **one integer** — the split offset — and two heights. Everything else is ordinary widgets:

```
LayoutBuilder
  SizedBox(height: blockHeight)
    Stack
      Positioned(top: 0, left|right: 0, child: InlinePhotoCard)
      Positioned(top: 0, left: besideX, width: besideWidth, child: Text(before))
      Positioned(top: belowY, left: 0, right: 0, child: Text(after))
```

This keeps `Text`'s own selection, semantics, `textScaler` handling and accessibility for free. A custom render object would have to re-implement all four.

**Every `TextPainter` created by the split is `dispose()`d in the same function, and the split returns plain data — offsets and doubles — never a live painter.** Flutter 3.44 asserts on leaked painters in debug; a leak reds the whole file with a stack trace naming the binding, not the widget.

*Rejected: a `MultiChildRenderObjectWidget`.* Re-implements selection and semantics for no gain.
*Rejected: `CustomPaint` painting the paragraphs directly.* Loses selection and semantics outright.

---

**R16 — Tape geometry SCALES with the card. The prototype's constants are pinned to a 210-wide card and are wrong at any other size.**

*Problem.* `left:16`, `width:56`, `top:-11` are absolute pixels against a 210-wide card. At the 96px floor (R14) a 56px tape is 58% of the card's width and the two strips overlap in the middle. No implementer would find this by reading `:365`.

*Resolution.* Define `s = width / 210.0` and scale **every** tape constant by `s`, including the frame padding. At `s = 1` the values are the prototype's exactly. The rotations do not scale.

```
tapeA: left 16s, top -11s, width 56s, height 22s, rotate -8deg about its own centre
tapeB: right 18s, top -9s, width 52s, height 22s, rotate +7deg about its own centre
frame padding: 8s
```

*Receipt.* A P0 case asserting the pre-gutter hull at `s = 0.5` is exactly half the size of the hull at `s = 1`, about the card centre.

---

**R17 — The decorative tilt is DETERMINISTIC from the photo id. `Math.random()` at `:336` is not adopted.**

*Problem.* A random tilt changes on every rebuild, which makes the layout non-deterministic, the exclusion rect non-deterministic and every test flaky.

*Resolution.* `photoTiltDegrees(String entryPhotoId)` sums the id's code units and maps the sum into `[-4.0, +4.0]` in 0.5deg steps:

```
index = codeUnitSum % 17
degrees = -4.0 + index * 0.5
```

Seventeen values, covering `:336`'s `Math.random() * 8 - 4` range exactly. This is the app's own precedent: `EntryCard._tiltDegrees` sums `entry.id.codeUnits` and branches on parity (`lib/features/entry_cards/entry_card.dart:77-81`), rendered through `StickerCard`'s `Transform.rotate` at `lib/design/widgets/sticker_card.dart:44-47`.

**CORRECTION to the ledger.** `sessions/2026-08-02-03` and the dispatch cite `lib/features/entry_cards/sticker_card.dart:44-49` for the tilt precedent. That path does not exist. The hash lives at `entry_card.dart:77-81` and the rotation at `lib/design/widgets/sticker_card.dart:44-47`. The substance of the finding — the only tilt precedent is a static `Transform.rotate` from a hash of the entry id, and there is **zero** gesture-to-persisted-transform precedent anywhere in `lib/` — is confirmed.

P5 overrides this default with a user value; absent a stored value, `photoTiltDegrees` is what renders.

---

**R18 — The exclusion rectangle and the two-paragraph split, specified completely.**

**File after P3:** `lib/design/layout/inline_photo_geometry.dart` and `lib/design/layout/inline_photo_float_layout.dart` (R4). Both are pure Dart over `dart:ui` types.

**Sign convention, and it is a trap.** CSS `rotate(+7deg)` and Flutter `Transform.rotate(angle: 7 * pi / 180)` are **the same direction** — clockwise on screen, because both spaces have y pointing down. Convert with `degrees * pi / 180` and no sign flip. A sign error here is invisible at small angles and wrong at ±15.

**Rotation helper**, screen coordinates, y down, positive clockwise:

```dart
Offset rotateAbout(Offset p, Offset c, double radians) => Offset(
      c.dx + (p.dx - c.dx) * math.cos(radians) - (p.dy - c.dy) * math.sin(radians),
      c.dy + (p.dx - c.dx) * math.sin(radians) + (p.dy - c.dy) * math.cos(radians),
    );
```

**The twelve hull points**, in card-local coordinates with the frame's top-left at the origin, `w` the frame width, `h = w / 1.25`, `s = w / 210`:

| Source | Untransformed corners | Rotated about | By |
|---|---|---|---|
| frame | `(0,0) (w,0) (w,h) (0,h)` | — | — |
| tape A | `(16s,-11s) (72s,-11s) (72s,11s) (16s,11s)` | `(44s, 0)` | `-8deg` |
| tape B | `(w-70s,-9s) (w-18s,-9s) (w-18s,13s) (w-70s,13s)` | `(w-44s, 2s)` | `+7deg` |

Tape centres follow CSS's default `transform-origin: 50% 50%`. Tape B's left edge is `w - 18s - 52s = w - 70s` because `:366` positions it by `right`.

**The exclusion rect:**

```dart
Rect inlinePhotoExclusion({
  required double width,
  required double tiltDegrees,
  double gutter = kInlinePhotoGutter,
}) {
  final List<Offset> hull = <Offset>[ ...twelve points... ];
  final Offset centre = Offset(width / 2, width / 1.25 / 2);
  final double theta = tiltDegrees * math.pi / 180;
  final Iterable<Offset> spun =
      hull.map((Offset p) => rotateAbout(p, centre, theta));
  return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(gutter);
}
```

- `kInlinePhotoGutter = 10`. Not invented: it is `photo_strip.dart:9`'s shipped `_separatorGap = 10`, the app's existing photo-to-content gap. Reusing it keeps one spacing value for one relationship.
- **The drop shadows are NOT in the hull.** `Shadows.photoFrame` extends 26px below the card and `Shadows.photoTape` 3px around each strip. A shadow is not ink; a glyph under a soft translucent shadow reads correctly, and inflating the box by 26px would push text a quarter of a card away for nothing. Stated so no implementer adds it.
- The returned rect's origin is card-local. The caller translates it into the text column: for a **right** float, `left = columnWidth - rect.width`; for a **left** float, `left = 0`. `top` is always 0 — the card's top aligns with the top of the block that contains its anchor.

**The split:**

```dart
class InlinePhotoSplit {
  final int splitOffset;
  final double besideWidth;
  final double besideHeight;
  final double belowTop;
  final double blockHeight;
  final bool degradedToBlock;
}

InlinePhotoSplit splitForFloat({
  required String text,
  required TextStyle style,
  required double columnWidth,
  required Rect exclusion,
  required TextDirection direction,
  required TextScaler scaler,
});
```

1. `besideWidth = columnWidth - exclusion.width`.
2. If `besideWidth < kMinBesideWidth` (**72.0**), return `degradedToBlock: true, splitOffset: 0` — the caller renders the P2 full-width block instead (R19).
3. Probe: one `TextPainter` over the whole text at `maxWidth: besideWidth`; read `computeLineMetrics()`.
4. `LineMetrics` exposes `hardBreak, ascent, descent, unscaledAscent, height, width, left, baseline, lineNumber` and nothing else. A line's **top** is `baseline - ascent`. Find the first line whose top is `>= exclusion.bottom`; call it `L`.
5. If no such line exists, the whole text fits beside the card: `splitOffset = text.length`, `belowTop = blockHeight`, `blockHeight = max(exclusion.bottom, probe.height)`.
6. Otherwise `splitOffset = probe.getLineBoundary(probe.getPositionForOffset(Offset(0, topOf(L) + 0.5))).start`. `getPositionForOffset` maps a point to a text position (`text_painter.dart:1706`); `getLineBoundary` snaps it to that visual line's range (`:1742`). The snap is what guarantees the split lands on a break opportunity and never mid-word.
7. Paragraph A is `text.substring(0, splitOffset)` at `besideWidth`. Paragraph B is `text.substring(splitOffset)` with its **leading whitespace run trimmed** — the break consumed it — laid out at `columnWidth`.
8. `belowTop = max(exclusion.bottom, besideHeight)`; `blockHeight = belowTop + belowHeight`.
9. Every `TextPainter` opened in this function is `dispose()`d before it returns.

**The contract P0 asserts, and P3 re-asserts against product code:** for every `TextBox` in paragraph A's `getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: splitOffset))`, translated into block coordinates, `box.toRect().overlaps(exclusion)` is **false**; likewise for every box of paragraph B translated by `(0, belowTop)`. That is the literal reading of "no glyph touches any ink".

**Edge cases, all resolved:**

| Case | Behaviour |
|---|---|
| `besideWidth < 72` | degrade to the full-width block; no throw, no overflow |
| text shorter than the card | the block still reserves `exclusion.bottom` of height so the next anchor cannot overlap |
| two adjacent sentinels | the second card's block begins at the first block's `blockHeight`; cards stack, never overlap |
| a sentinel as the first character | paragraph A is empty; `besideHeight` is 0; `belowTop = exclusion.bottom` |
| `TextDirection.rtl` | the API takes the direction and mirrors the side, but the app is LTR-only today (`test/design/widgets/widget_harness.dart:5` hardcodes it). RTL is out of scope (§6.1) and must not be baked wrong |

---

**R19 — P2 renders a FULL-WIDTH BLOCK. The float is P3's and nothing in P2 may anticipate it.**

The thread is explicit: P2 ships "tape-framed cards at their place in the text, full-width block, decorative tilt only". P2's block is the card centred in the column at `min(210, columnWidth)` wide, with the text above it and below it, and **no** exclusion math at all. `inline_photo_geometry.dart` stays in the test tree until P3 promotes it (R4).

This is also the permanent degrade path: R18 step 2 and every P3+ failure mode falls back to exactly this rendering.

---

**R20 — `NoteBody` grows; it does not fork. Split the file if it crosses 200 lines.**

`NoteBody` is 25 lines today (`lib/features/entry_cards/cards/note_body.dart`), takes only `text`, and is selected by `EntryCard._body()` at `entry_card.dart:136`. P2 grows its constructor to `NoteBody({required this.text, this.photos = const <EntryPhoto>[], this.resolver})` and renders anchored cards inline when both are present. `EntryCard` stops passing `photos` to `InlinePhotoStrip` for the **anchored** subset and keeps passing the unanchored tail (R8).

The tape-framed card itself is a new file, `lib/features/entry_cards/cards/inline_photo_card.dart`, so `NoteBody` stays small. If `note_body.dart` crosses 200 lines the block-assembly loop moves to `lib/features/entry_cards/cards/inline_photo_blocks.dart` in the same PR — the project's own file-size rule (200-400 typical, 800 max).

*Rejected: a second `InlinePhotoNoteBody` widget beside `NoteBody`.* Two renderers for one thing is the duplication `photo_strip.dart` already avoids.

*Receipt.* `note_body_test.dart`'s two existing cases must pass **unmodified**.

---

#### P4 — arrange mode

**R21 — Side, size and rotation persist as JSON in the EXISTING `Settings` table, behind a typed facade. This is the only migration-free home.**

*Problem.* `EntryPhotos` has seven columns and none of them can hold a side, a width or an angle (`tables.dart:36-47`). R1 forbids adding one.

*Resolution.* `lib/data/journal/inline_photo_layout_store.dart` wraps the shipped `Settings` key/value table (`tables.dart:64-70`), which already stores five app settings through `insertOnConflictUpdate` (`lib/data/settings/drift_settings_repository.dart:49-51`).

- **Key:** `inline_photo_layout:<entryPhotoId>`. The prefix is a named constant beside `SettingsKeys` (`lib/data/settings/settings_keys.dart`), never a literal.
- **Value:** compact JSON, `{"side":"left","widthFraction":0.42,"rotationDeg":-3.5}`. Every field is optional; an absent field means "use the derived default" (R14, R17, and P3's parity rule).
- **Absent key:** the derived defaults, exactly. Reverting P4 or P5 therefore needs no data cleanup — the keys simply stop being read.
- **P4 writes `side` and `widthFraction`. P5 adds `rotationDeg`.** A P4-era value is forward-compatible without a version field because every field is optional.

**Three cleanup obligations, all in P4's fence, none optional:**

1. `JournalDeleteAllService.deleteAll` deletes matching `Settings` rows inside its existing transaction (`lib/features/data/journal_delete_all_service.dart:22-31`), which today deletes photos, entries, days and blobs and **touches `Settings` not at all**.
2. `DriftJournalRepository.softDeletePhoto` (`drift_journal_repository.dart:189-191`) deletes the photo's layout key.
3. `MediaGc` sweeps layout keys whose `entryPhotoId` no longer resolves, alongside its existing hard-delete of soft-deleted photo rows (`lib/data/media/media_gc.dart:139-144`).

**One declared consequence.** `JournalExportService` exports the whole `Settings` table verbatim as `'settings': {key: value}` (`lib/features/data/journal_export_service.dart:37`, `:44`). Layout keys therefore appear in every export. That is acceptable — they are the user's own layout — but it is a payload-shape change and is declared here rather than discovered.

*Rejected: a schema migration.* R1. It is the landmine this entire model exists to avoid.
*Rejected: packing flags into `sortOrder`.* `sortOrder` is an `IntColumn` with no unique index, so `index * 1000 + flags` would "work" and would corrupt the one field the anchor binding depends on. Recorded as rejected so no implementer invents it.
*Rejected: no persistence at all.* It fails the thread's completion criterion that a photo "survives a save/reopen/edit round-trip, which the prototype never did".

---

**R22 — The write-mode / arrange-mode boundary: ONE tree at a time, never both.**

*Problem.* The user's literal ask — text that wraps, is editable, and is freely positioned — is internally unsatisfiable in Flutter. `RenderEditable` holds one `final TextPainter` over one linear `TextEditingValue`; fragmenting it breaks caret, selection, IME composing and semantics with no primitive to stitch them back (session finding 4). The renegotiated model is the mode split, and the split only works if the two modes never coexist.

*Resolution.*

| | Write mode | Arrange mode |
|---|---|---|
| Body widget | `EditableText` (plain, `expands: true`) | the read-only float renderer + handles |
| Photo rendering | a non-focusable `WidgetSpan` chip per sentinel (R9) | the tape-framed card, floated, with drag/flip/resize handles |
| Text wrapping around a card | **never** — structurally impossible, out of scope | yes, via R18 |
| Text editing | yes | **never** |
| Entered by | tapping into the text; the composer's initial state | the editor losing focus (the thread's "tapping out of the text") |
| Source of truth | `PhotoAnchorTextEditingController` | the same controller |

**Neither mode mounts the other's tree.** The composer body is a single `if (focusNode.hasFocus) ... else ...`. Arrange mode mutates the text only by moving one sentinel — a single-code-unit delete plus a single-code-unit insert issued as one `TextEditingValue` replacement, so R11's delta rule sees exactly one contiguous change.

*Receipt.* A P4 case asserting `find.byType(EditableText)` is `findsNothing` in arrange mode and the handle key is `findsNothing` in write mode.

---

**R23 — The reflow throttle and the layout cache, specified as numbers.**

*Problem.* `TextPainter.layout()` is shaping-dominated with no incremental relayout API. [flutter/flutter#92173](https://github.com/flutter/flutter/issues/92173) (*"paragraph.layout() seems very expensive"*) and [flutter/flutter#132421](https://github.com/flutter/flutter/issues/132421) (*"Calling layout on TextPainter for conditional layouts can be slow"*) are **both open**, the latter reporting cumulative slowdown from repeated `layout()` calls. A naive arrange-mode drag calls `layout()` on every pointer event.

*Resolution — six rules, all measurable:*

1. **Quantise the drag to the ANCHOR INDEX, not to the pixel.** The model anchors to a text position, so a drag that does not cross a candidate insertion point changes nothing about the layout. During a drag the card follows the pointer in an `Overlay`; the text reflows **only** when the resolved insertion index changes. A slow drag across one paragraph costs a handful of relayouts, not hundreds. This falls out of the model and is the single largest win.
2. **At most one relayout per frame.** Pointer handlers set a dirty flag and `markNeedsBuild`; they never call `layout()` directly. Two pointer events in one frame produce one relayout.
3. **At most two `TextPainter.layout()` calls per relayout** — the probe and paragraph B. Paragraph A reuses the probe's painter, which is already laid out at `besideWidth`. **Never one painter per line.**
4. **Memoise the split.** Key: `(text, columnWidth, exclusion, style, textScaler, direction)` — all six, by value. A hit returns the cached `InlinePhotoSplit` with zero `layout()` calls. Cache size **8**, one per anchored photo (the model's cap), LRU, cleared on any text change.
5. **A left/right FLIP costs zero relayouts.** The exclusion box of a symmetric card has the same width on either side, so `besideWidth` is unchanged and the cached split is still valid. A flip is a repaint and a `Positioned` change, nothing more. State it so no implementer invalidates the cache on side.
6. **Quantise RESIZE to 8 logical pixels of width.** Aspect is locked, so height follows. A full drag across the `[96, 210]` range costs at most 15 relayouts instead of one per pointer event.

**One hard ceiling.** Above **4000 characters** of note text, arrange-mode live reflow is disabled: the card follows the pointer as a ghost and the text reflows **once**, on drop. 4000 characters is roughly 60 lines at the composer's 19/38 metrics — well past any note this app's own fixtures contain, and past the point where a per-frame full-paragraph shape is affordable on the slowest supported device.

*Receipt.* A P4 case asserting the cache returns the identical `InlinePhotoSplit` instance for an unchanged key.

---

#### P5 — user-controlled rotation

**R24 — Rotation is clamped to ±15.0deg and quantised to 0.5deg.**

The thread says "clamped to ~+/-15deg so the box cannot balloon"; the exact numbers are pinned here. `rotationDeg` is clamped to `[-15.0, 15.0]` and rounded to the nearest 0.5, giving 61 values. The quantisation is what makes R23's cache hit on a rotation drag instead of missing on every pointer event.

At ±15 with a 210-wide card the hull's AABB grows by roughly 24% in each axis over the untilted box. That is the cost the clamp buys down; it is why the clamp exists and why it is not a preference.

---

**R25 — P5 changes the exclusion input, not the exclusion algorithm.**

`inlinePhotoExclusion` already takes `tiltDegrees` and already rotates all twelve hull points (R18). P5 supplies a **stored** angle where P2/P3 supplied `photoTiltDegrees`'s derived one. **No geometry code changes.** P5 ships the handle, the clamp, the persistence field and the four receipts — nothing else.

*This is why P5 is last.* Dropping it loses the handle and nothing beneath it: P2 already shipped the tilt, and P3's exclusion is already rotation-aware because it must be.

---

#### Verification and process

**R26 — Every phase predicts its test-count delta BEFORE running `fullValidationCmd`, and reports the number it actually read.**

The baseline recorded in the ledger has gone stale three times. §5.3 carries the per-phase prediction. A mismatch that cannot be explained is a defect, not a rounding error.

---

**R27 — Every phase is ONE PR through the `pr-create` tool. `gh pr create`, `gh pr edit`, `gh api` POSTs to the pulls endpoint, and every GraphQL/MCP PR-write are denied globally. `gh pr merge` is denied; every merge is a human action.**

```
node /Users/satanshumishra/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create \
  --repo SatanshuMishra/field-notes --head <branch> --base <base> \
  --title "<type>(inline-photo): <lowercase imperative summary>" \
  --origin machine --provenance "agent=<label> model=<model>" \
  --why "..." --what "..." --verified "..." --not-verified "..."
```

Scope `inline-photo` is 12 characters, inside the 16-character class. Title max 72, lowercase summary, no trailing period. **The honesty rule is absolute**: never write `--verified` for a check whose output was not read, for any reason including a zero exit code. A check not run is `--not-verified "<thing> - not run"`; a result not read is `--not-verified "<thing> - result not read"`.

---

**R28 — No agent runs this app. The visual pass is owed by a human on macOS.**

`flutter run -d macos` needs a TTY, and the standalone binary renders a black window (`decisions/2026-07-22-black-window-standalone-binary.md`). Do not launch the app detached and do not fall back to the raw `.app` bundle. If a visual check is genuinely required, say so and hand the command back. §5.5 carries the per-phase checklist.

---

### TOKEN LEDGER — the four values this ladder adds

All four ship in **P2**, the first phase that draws a card. P0 is test-only and adds none; it uses literals in the test tree.

| Token | Value | Source | Verified absent |
|---|---|---|---|
| `Palette.photoFramePaper` | `Color(0xFFFFFFFF)` | `md-scrapbook.js:363` `background:#fff` | `palette.dart` has no pure-white surface token; `onAccent` (`:51`) is `#FFFFFF` but is named for a role and is consumed by five call sites as a foreground |
| `Palette.photoTape` | `Color(0xD1D9C9A6)` | `:365`, `:366` `rgba(217,201,166,.82)` | no `d9c9a6` anywhere in `lib/` |
| `Shadows.photoFrame` | `BoxShadow(color: Color(0x8C281E12), offset: Offset(0, 12), blurRadius: 26, spreadRadius: -10)` | `:363` | `shadows.dart` has no `0/12/26/-10` entry |
| `Shadows.photoTape` | `BoxShadow(color: Color(0x24000000), offset: Offset(0, 1), blurRadius: 3)` | `:365`, `:366` | `shadows.dart` has no pure-black shadow |

`Shapes` gains nothing: the card's corners are square (`BorderRadius.zero`), which needs no token. Token assertions join existing cases in `test/design/tokens/tokens_test.dart` and add **zero** test cases, per Cluster A's rule.

`kInlinePhotoGutter = 10` and `kMinBesideWidth = 72` are **layout constants, not tokens**. They live in `lib/design/layout/inline_photo_geometry.dart` and never enter `Shapes`.

---

### HARD SCOPE FENCE

This ladder ships **exactly six phases: P0 through P5.** No others.

| File | Owning phase(s) | New? |
|---|---|---|
| `test/features/entry_cards/photo/inline_photo_geometry.dart` | P0 (created), P3 (moved out) | **new**, then deleted by P3 |
| `test/features/entry_cards/photo/inline_photo_float_layout.dart` | P0 (created), P3 (moved out) | **new**, then deleted by P3 |
| `test/features/entry_cards/photo/inline_photo_float_spike_test.dart` | P0, P3 (imports retargeted) | **new** |
| `lib/features/entry_cards/cards/photo_anchors.dart` | P1, P2 | **new** |
| `lib/features/entry_cards/cards/note_body.dart` | P1, P2 | no |
| `lib/features/capture/text/text_composer_sheet.dart` | P1, P2, P4 | no |
| `lib/features/capture/text/text_composer.dart` | P1, P2 | no |
| `lib/features/day_detail/day_detail_edit_note.dart` | P1 (R6, one argument omitted) | no |
| `test/features/capture/photo/photo_tray_test.dart` | **nobody — READ ONLY** | no |
| `lib/features/capture/text/photo_anchor_controller.dart` | P2, P4 | **new** |
| `lib/features/capture/text/anchor_chip.dart` | P2 | **new** |
| `lib/features/entry_cards/cards/inline_photo_card.dart` | P2, P3, P5 | **new** |
| `lib/data/journal/entry_photos_dao.dart` | P2 | no — one additive method (R12) |
| `lib/data/journal/drift_journal_repository.dart` | P2, P4 | no — additive |
| `lib/domain/repositories/journal_repository.dart` | P2 | no — **declared interface growth** (R12) |
| `test/features/capture/core/capture_test_support.dart` | P2 | no (**declared, bounded**: interface members only) |
| `lib/design/tokens/palette.dart` | P2 | no — additive only |
| `lib/design/tokens/shadows.dart` | P2 | no — additive only |
| `test/design/tokens/tokens_test.dart` | P2 | no — extended, never rewritten |
| `lib/design/layout/inline_photo_geometry.dart` | P3 (from P0), P5 | **new** |
| `lib/design/layout/inline_photo_float_layout.dart` | P3 (from P0) | **new** |
| `lib/design/layout/layout.dart` | P3 | **new** (barrel) |
| `lib/features/entry_cards/entry_card.dart` | P2 | no — the unanchored-tail split |
| `lib/features/capture/text/note_arrange_mode.dart` | P4, P5 | **new** |
| `lib/data/journal/inline_photo_layout_store.dart` | P4, P5 | **new** |
| `lib/data/settings/settings_keys.dart` | P4 | no — one prefix constant |
| `lib/features/data/journal_delete_all_service.dart` | P4 | no — **declared widening** (R21 cleanup 1) |
| `lib/data/media/media_gc.dart` | P4 | no — **declared widening** (R21 cleanup 3) |

**Six declared widenings.** Each is bounded, and each carries the standard obligation that every other consumer's tests pass **unmodified**:

1. **P1 gains `day_detail_edit_note.dart`** (R6) — one omitted argument, so the picker cannot appear where there is no write path.
2. **P2 gains `journal_repository.dart`** (R12) — an `abstract interface class` grows one member. This is a **build break**, not a test failure.
3. **P2 gains `capture_test_support.dart`** — the interface member on a fake. It changes no assertion and adds no case.
4. **P2 gains `entry_card.dart`** — the anchored/unanchored split, so `InlinePhotoStrip` receives only the tail.
5. **P4 gains `journal_delete_all_service.dart` and `media_gc.dart`** (R21) — layout-key cleanup. Without both, delete-all leaves rows behind.
6. **P4 gains `settings_keys.dart`** — one prefix constant beside the existing five.

**Named traps — each is a file a reasonable implementer might otherwise edit, and each is out of bounds:**

- `lib/data/database/app_database.dart` — **NEVER.** R1. `schemaVersion` and `onUpgrade` are untouchable in every phase.
- `lib/data/database/tables.dart` — **NEVER.** Adding a column is a migration.
- `lib/design/widgets/sticker_card.dart` — 16 call sites in `lib/`, plus A4's contract and `sticker_card_test.dart`. The photo card composes its own `DecoratedBox`; it is **not** a `StickerCard` (square corners, a white surface and a soft shadow are all unreachable through its API). Cluster G's R1 is the precedent.
- `lib/features/capture/photo/photo_tray.dart` and `photo_thumbnail.dart` — **READ ONLY in every phase.** P1 mounts the tray; it does not edit it (R5). `photo_tray_test.dart`'s six cases must pass byte-identical.
- `lib/features/entry_cards/cards/photo_strip.dart` — **READ ONLY.** `InlinePhotoStrip` is the unanchored-tail renderer and the permanent degrade target. Changing it changes what a revert lands on.
- `lib/features/entry_cards/playback/**` and `cards/video_*`, `cards/voice_*` — N24's protected suite. Untouched by path disjointness; if a diff reaches one, the fence is breached.
- `lib/features/capture/voice/**`, `lib/features/capture/video/**` — no phase opens them. `CaptureRequest.photos` exists on `VoiceCaptureRequest` (`capture_service.dart:73`) and `VideoCaptureRequest` (`:89`); wiring either is a different spec (§6.1).
- `third_party/**` — not in any fence.
- `lib/domain/models/entry_photo.dart` — **no new field.** `EntryPhoto.label` is explicitly never needed (OQ-6 record, Consequences).

If decomposition suggests a unit outside P0–P5, that is a signal this spec should be re-cut — **not** a licence to widen the run. **Stop and report.**

---

### DEPENDENCY CHAIN, BRANCHES, and SHIP ORDER

```
P0  (test-only spike)   root, and the GATE on P3
P1  (composer wiring)   root
 |-- P2 -> P1
      |-- P3 -> P2  AND  P0-green
           |-- P4 -> P3
                |-- P5 -> P4
```

**P0 and P1 are independent roots.** P0 shares no file with any other phase and touches zero files under `lib/`. It is ordered first because it is a **gate**, not because P1 needs it.

| Phase | Branch | Base | PR title |
|---|---|---|---|
| P0 | `inline-photo/p0-spike` | `main` | `test(inline-photo): prove the tape-framed float reserves its exclusion box` |
| P1 | `inline-photo/p1-wire` | `main` | `feat(inline-photo): reach photos from the note composer` |
| P2 | `inline-photo/p2-anchor` | `inline-photo/p1-wire` | `feat(inline-photo): anchor photos in the note text` |
| P3 | `inline-photo/p3-float` | `inline-photo/p2-anchor` | `feat(inline-photo): float anchored photos beside the text` |
| P4 | `inline-photo/p4-arrange` | `inline-photo/p3-float` | `feat(inline-photo): add arrange mode for anchored photos` |
| P5 | `inline-photo/p5-rotate` | `inline-photo/p4-arrange` | `feat(inline-photo): let the reader rotate an anchored photo` |

Every branch is cut with `git switch -c <branch> <base-ref>` (R2). The `inline-photo/` prefix is per-run, not per-type, per `decisions/2026-07-25-msp-branch-prefix-not-per-type.md`.

**P1 through P5 ship as ONE native GitHub stack** per `decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md`: base-chaining alone is not a stack; after the PRs exist they are linked via `POST /repos/SatanshuMishra/field-notes/stacks` with `pull_requests` ordered bottom-to-top. **P0 is a standalone PR against `main`, outside the stack.**

**The gate discipline, and it is the reason the stack is opened in two waves:**

1. Open P0 and merge it (human-gated). **Read its result.**
2. Open P1 and P2 as the first two rungs of the stack.
3. **Open P3, P4 and P5 only after P0 is green.** If P0 is red, the float model is formally abandoned, P3/P4/P5 are never opened, and the feature ships at P2 — which already delivers the narrative connection the model exists for. **Say that out loud before starting P3.**

The repo squash-merges, so once a phase lands, `main` holds its content under a SHA absent from the next branch's history. **Each phase rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. Never carry a green from one base to another** (`decisions/2026-07-25-verify-squash-against-remote-tip.md`).

---

### THE STANDING INVARIANT — note capture works at EVERY commit

Capture is the app's reason to exist, and every phase in this ladder touches the note path. Four receipts hold the chain and must be green on every branch, at every commit:

1. `test/features/capture/core/text_composer_test.dart` — the composer takes text and saves; an empty save does not write.
2. `test/features/capture/core/text_composer_save_hang_test.dart` and `text_composer_timeout_dedupe_test.dart` — the hang and timeout paths.
3. `test/features/day_detail/day_detail_edit_note_test.dart` — the edit path still confirms, still writes, still returns its `bool?`.
4. `test/features/entry_cards/entry_card_test.dart`, `today_entry_feed_test.dart`, `day_detail_entry_tile_test.dart` — photos still render.

Per phase:

- **P0** touches zero files under `lib/`. If anything about the app changes, P0 is wrong.
- **P1** adds a picker and a `photos:` argument. **Saving a note with no photo must be byte-identical to today.** The edit path must show no picker (R6).
- **P2** adds a character class to the note text. **A note with no sentinel must render exactly as it does today**, and a note whose text contains a stray U+FFFC must render without it (R7).
- **P3** changes how an anchored note is laid out. A note with no photos never reaches the float path.
- **P4** adds a mode. **Write mode must be untouched** — the same `EditableText`, the same controller, the same save contract (R22).
- **P5** adds a handle. Dropping it loses the handle and nothing else (R25).

**A phase that ships a composer which cannot open, cannot save, or loses a note violates the green-branch invariant regardless of test results.** No agent can run this app; the manual pass in §5.5 is load-bearing and is owed by a human.

---

### REVERT LADDER — what a revert of each phase alone degrades to

Each phase is one squash-merged PR, revertible on its own. This table is the contract; it is what makes the risk-ordered ladder worth its cost.

| Reverting | Degrades to | Data left behind | Is it safe? |
|---|---|---|---|
| **P5** | P4's arrange mode without a rotation handle; the tilt is `photoTiltDegrees`'s derived value again (R17) | `rotationDeg` keys in `Settings`, unread. Optional field, so a P4-era reader ignores them (R21) | **yes**, no cleanup |
| **P4** | P3's static float. Side is index parity again; width is the 0.32 default; no handles, no arrange mode | `inline_photo_layout:*` keys, unread. The three cleanup hooks revert with it, so keys accumulate slowly on delete-all — a leak of bytes in an existing table, never a correctness fault | **yes**, no cleanup |
| **P3** | P2's full-width block. Every anchored photo renders centred in the column at its authored position; no text wraps beside it | none — P3 persists nothing | **yes** |
| **P2** | **P1's bottom strip**, and this is the case the thread names. The anchor stays in the text, but **P1's `stripPhotoAnchors` removes every sentinel from the render** (R7), so the user sees clean prose and every photo in `InlinePhotoStrip` below it. **No stray replacement characters.** `sortOrder` values written by `reorderPhotos` remain valid — they are still an ascending order and `InlinePhotoStrip` sorts by exactly that key (`photo_strip.dart:31`) | U+FFFC in `entries.text_content`; `sortOrder` values possibly rewritten | **yes — and only because R7 put the stripper in P1** |
| **P1** | Today's app. Photos become unreachable again; the tray returns to dead UI. `entry_photos` rows written under P1 keep rendering through `InlinePhotoStrip`, which shipped in PR #27 and is untouched | `entry_photos` rows and their blobs, all still reachable by the existing GC and export | **yes** |
| **P0** | Nothing. Zero files under `lib/` | none | **yes** |

**The one asymmetry to know.** Reverting P2 while P4 or P5 is still merged would leave arrange mode reading anchors that no longer render. **Reverts must go top-down**, exactly as the stack merges bottom-up. A revert of P2 obliges a revert of P3, P4 and P5 first.

---

## 1. BLUF

A photo cannot be attached to a note at all today. `CaptureRequest.photos` exists on all three request variants (`capture_service.dart:59`, `:73`, `:89`); the attach loop, the blob store, the GC and the export are all real and all tested — and **zero production UI populates any of it**. `PhotoTray` shipped in PR #27 and was never mounted; nothing imports the widget, its barrel or its provider. All three composers omit `photos:`, the note composer at `text_composer.dart:104`.

This ladder makes a photo reachable, then puts it where the story puts it.

**P0** proves, in the test tree with zero product code, that a tape-framed card tilted by theta and floated into a paragraph of real text reserves a box no glyph enters. A red kills the float model for the price of one revert and truncates the ladder at P2. **P1** mounts the shipped tray in the note composer, passes `photos:` on `TextCaptureRequest`, renders through the existing `InlinePhotoStrip`, and ships the sentinel stripper that makes every later revert safe. **P2** anchors each photo at a position in the note text with a U+FFFC sentinel, draws it as a tape-framed card in a full-width block, and proves on macOS and iOS that the caret still traverses, backspaces and selects through it. **P3** floats the card left or right and wraps the text beside it and below it, using the exclusion box P0 proved. **P4** adds arrange mode — drag the anchor through the story, flip the side, resize — with a throttle and a cache sized to the model. **P5** adds a rotation handle, clamped so the box cannot balloon.

**No phase migrates the database.** The anchor lives in the text; the reorder is an UPDATE on an existing column; side, size and rotation live in the `Settings` table the app already ships.

**Aligned means**: a photo sits where the writer put it, the words go around it, neither obstructs the other, and every one of the six phases can be reverted alone without breaking the ones beneath it.

---

## 2. Non-negotiables

Constraints, not suggestions. Every phase that touches the named files inherits them.

| # | Constraint | Verified citation | Binds |
|---|---|---|---|
| **M1** | **No schema migration, ever.** `schemaVersion` is 1 and `onUpgrade` unconditionally throws | `lib/data/database/app_database.dart:17`, `:25-32`; pinned by `test/data/database/app_database_test.dart` | **every phase**; R1 |
| **M2** | **`EntryPhoto` gains no field.** No `label`, no `x`, no `y`, no `rotation` | `lib/domain/models/entry_photo.dart:1-20`; OQ-6 record, Consequences | **every phase**; R21 |
| **M3** | **Write mode is plain editable text, always.** Editable text that wraps is structurally impossible and is out of scope | session finding 4; `RenderEditable` holds one `TextPainter` | **P2, P4**; R22 |
| **M4** | **The anchor is a position in the text, never an (x, y).** Arbitrary pixel positioning is rejected | OQ-6 record, Decision | **every phase** |
| **M5** | **Cap 8.** Already declared and already tested | `photo_tray.dart:9` `defaultMaxPhotos = 8`; `photo_tray_test.dart:123` | **P1**; R5 |
| **M6** | **`InlinePhotoStrip` is the permanent degrade target and is READ ONLY.** Every failure mode and every revert lands on it | `lib/features/entry_cards/cards/photo_strip.dart:14`, sorted by `sortOrder` at `:31` | **P1–P5**; R8, R19 |
| **M7** | **The empty-save guard stays text-only for now.** The prototype's predicate is text-empty **and** no photos (`md-scrapbook.js` host at `:1386`); the app's is `text.trim().isEmpty` (`text_composer_sheet.dart:186`) | `decisions/2026-07-28-c5-ships-as-is.md`; Cluster G R18 | **P1** — see §6.1 |
| **M8** | **`ValueKey`s and Semantics labels are a public contract.** `composerCloseKey` (`text_composer_sheet.dart:9`), `editNoteConfirmSaveKey` (`day_detail_edit_note.dart:20`) and every key in the protected playback suite may not be renamed | N24 | **every phase** |
| **M9** | **`sortOrder` means order and nothing else.** No packed flags, no sentinel values | `tables.dart:40`; R21 rejected list | **P2, P4** |
| **M10** | **No new dependency of any kind.** `image_picker` is already in `pubspec.yaml`; nothing else is needed | `pubspec.yaml` | **every phase** |

---

## 3. Findings this ladder implements

The five findings that produced the model, reproduced from `sessions/2026-08-02-03-prototype-design-alignment.md` with each anchor re-verified at `712c978`, plus the seven this document adds.

| # | Finding | Consequence for this ladder |
|---|---|---|
| 1 | **The prototype does not wrap text.** `.ms-layer` is `position:absolute;inset:0;pointer-events:none` at z 10+ over `.ms-editor` at z 2; a grep for `float\|shape-outside\|clip-path\|shape-margin\|exclusion` across all three prototype files returns one unrelated hit. Cards are opaque `#fff` (`md-scrapbook.js:363`) and fully occlude text | `md-scrapbook.js` is authoritative for the **look only**. Every behaviour in this spec is authored here |
| 2 | **The prototype's drag never persisted.** `getHTML()` returns only `editor.innerHTML`; per-card state is a DOM expando `el._st = {x,y,w,h,rot,cap}` (`:334-337`, applied at `:387-393`) with no storage API anywhere. There is no real image — every card is a hatch div containing the word "photo" (`:135-136`, `:369`) | Persistence is entirely this ladder's invention. R8, R12 and R21 are the whole of it |
| 3 | **Flutter has no text-exclusion API at any layer.** [flutter/flutter#50171](https://github.com/flutter/flutter/issues/50171) open, and its own text names "wrapping text around exclusion paths" as unserved | The split is hand-rolled from `TextPainter` primitives. R18 |
| 4 | **Editable wrap is structurally impossible.** One `TextPainter`, one linear string, integer offsets | The write/arrange split. R22, M3 |
| 5 | **The migration landmine.** No `drift_schemas/`, no harness, no successful-upgrade test — only the refusal is pinned | M1, R1, R21 |
| 6 | **NEW: the binding decision record is not on `main`** | R0 |
| 7 | **NEW: `entry_photos` has no `sortOrder` update path** — insert and soft-delete only (`entry_photos_dao.dart:10-51`) | R12 |
| 8 | **NEW: side, size and rotation have no column and may not get one** | R21 |
| 9 | **NEW: #159171 requires a nested `TextField` inside the `WidgetSpan`** — narrower than the ledger states | R9, R10 |
| 10 | **NEW: U+FFFC is Flutter's own placeholder character** (`placeholder_span.dart:51`, `:73`), so a `WidgetSpan` substitution round-trips byte-identically | R8 |
| 11 | **NEW: the float needs no custom `RenderBox`** | R15 |
| 12 | **NEW: tape geometry is pinned to a 210-wide card and must scale** | R16 |

**Corrections to the ledger, found by reading code:**

- **`sticker_card.dart:44-49` is the wrong anchor for the tilt precedent.** The path is `lib/design/widgets/sticker_card.dart` (`Transform.rotate` at `:44-47`) and the hash is `lib/features/entry_cards/entry_card.dart:77-81`. The substance holds (R17).
- **`Field Notes.dc.html:470` is a flex wrapper; the `addPhoto` button is `:471` (desktop) and `:772` (phone), and its label is `Add memory`.** The session corrected the anchor but did not capture the values; they are in §6.1 so they cannot be lost a sixth time.
- **`entry_photos` "has no update path" is precise and load-bearing.** `EntryPhotosDao.softDelete` (`:44-51`) is an UPDATE, but it writes only `deletedAt` and `updatedAt`. There is no path that writes `sortOrder` after insert (R12).

---

## 4. Phase decomposition

**The governing invariant**: merging any phase must leave note capture working on its merge commit, proven by a **measured** `fullValidationCmd` on that branch, never inherited.

---

### P0 — Feasibility spike. TEST-ONLY, zero files under `lib/`

**Branch**: `inline-photo/p0-spike` — base `main`
**Outcome**: a verdict. The float model either reserves a box no glyph enters, or it does not and the ladder truncates at P2.
**Depends on**: nothing. **Gates**: P3.

**Files** (all new, all under `test/`):
- `test/features/entry_cards/photo/inline_photo_geometry.dart`
- `test/features/entry_cards/photo/inline_photo_float_layout.dart`
- `test/features/entry_cards/photo/inline_photo_float_spike_test.dart`

**FENCE — files P0 must NOT touch**: **every file under `lib/`, without exception.** Every file under `test/` outside `test/features/entry_cards/photo/`. No token. No golden. No dependency. No `pubspec.yaml`. If P0's diff contains a single line under `lib/`, it is out of bounds — stop and report.

**Binding resolutions**: R4 (test-tree home, promoted by P3), R13 (the look), R14 (width), R16 (tape scaling), R17 (deterministic tilt), R18 (the geometry and the split, in full).

**Acceptance criteria, as testable assertions:**

1. `inlinePhotoExclusion(width: 210, tiltDegrees: 0, gutter: 0)` returns a `Rect` that **contains** every one of the twelve hull points of R18's table, within 1e-9.
2. That same rect's `top` is **negative** — the tape strips overhang the frame — and its `height` exceeds `168`.
3. `inlinePhotoExclusion(width: 210, tiltDegrees: 15)` and `(… -15)` each strictly contain the `tiltDegrees: 0` rect, and each contains all twelve of its own rotated hull points.
4. The pre-gutter hull at `width: 105` is **exactly half** the size of the hull at `width: 210`, about the card centre — the tape scales (R16).
5. For a 600-character real paragraph at the composer's own metrics, with the card floated **right**: no `TextBox` of paragraph A or of paragraph B, translated into block coordinates, `overlaps` the exclusion rect.
6. The same, floated **left**.
7. `splitForFloat` with `besideWidth < 72` returns `degradedToBlock: true` and `splitOffset: 0`, and throws nothing.

**Tests it adds**: `inline_photo_float_spike_test.dart`, **7 cases**, one per criterion.

*Admission-gate justification.* Every case defines a **public contract** of two new pure functions with no existing coverage anywhere in the repo, asserting values returned through that public surface. Criteria 5 and 6 are the feasibility verdict itself — the reason the phase exists. None is a change-detector: they assert relationships (containment, non-overlap, scaling), not literal pixel values copied from output.

**Must not regress**: nothing. P0 changes no behaviour. `flutter analyze` stays clean and the existing suite is untouched.

**Predicted delta**: **+7** → 951.

**A revert of P0 alone degrades to**: nothing. Zero files under `lib/`, zero behaviour.

**If P0 is RED**: the float model is formally abandoned. P3, P4 and P5 are never opened. The feature ships at P2, which already delivers the narrative connection the model exists for. **Say this out loud before starting P3.**

---

### P1 — Wire photo capture into the note composer

**Branch**: `inline-photo/p1-wire` — base `main`
**Outcome**: a photo is reachable from the note composer for the first time, and renders on the entry card through the existing strip.
**Depends on**: nothing.

**Files**:
- `lib/features/entry_cards/cards/photo_anchors.dart` — **new** (R7)
- `lib/features/entry_cards/cards/note_body.dart` — applies `stripPhotoAnchors`
- `lib/features/capture/text/text_composer_sheet.dart` — mounts the tray behind `onPhotosChanged` (R5, R6)
- `lib/features/capture/text/text_composer.dart` — passes `photos:` on `TextCaptureRequest` (`:104`)
- `lib/features/day_detail/day_detail_edit_note.dart` — omits `onPhotosChanged` (R6)

**FENCE — files P1 must NOT touch**: `lib/features/capture/photo/**` (the tray is mounted, never edited — R5); `test/features/capture/photo/photo_tray_test.dart` (its six cases must pass byte-identical); `lib/features/entry_cards/cards/photo_strip.dart`; `lib/data/**`; `lib/domain/**`; `lib/design/tokens/**` (P1 adds no token); every voice and video file; `pubspec.yaml`.

**Binding resolutions**: R5 (mount, don't author), R6 (the picker is hidden on the edit path), R7 (the stripper ships here).

**Target values**: `libraryLabel: 'Add memory'` — the prototype's own label at `Field Notes.dc.html:471` and `:772`. Everything else on `PhotoTray` keeps its declared default, including `maxPhotos: defaultMaxPhotos` = 8.

**Acceptance criteria, as testable assertions:**

1. Picking a photo in the note composer and saving results in a `TextCaptureRequest` whose `photos` has length 1 — asserted against `FakeCaptureService.requests` (`capture_test_support.dart`).
2. Saving a note with **no** photo produces a `TextCaptureRequest` whose `photos` is empty, and the save path is otherwise byte-identical to today.
3. `find.byType(PhotoTray)` is `findsNothing` when `EditNoteConnector` is pumped.
4. `NoteBody(text: 'a￼b')` renders the string `'ab'`; `find.text('a￼b')` is `findsNothing`.
5. `NoteBody(text: '￼')` renders the `Empty note` affordance — the strip happens before the blank check.
6. All six `photo_tray_test.dart` cases pass unmodified.

**Tests it adds**: **3 cases**.
- `test/features/capture/text/text_composer_photos_test.dart` — criterion 1 (behaviour: a request field that has never been populated by any UI) and criterion 3 (behaviour: a gate protecting a write path that does not exist).
- `test/features/entry_cards/cards/note_body_test.dart` — one case added for criteria 4 and 5 (behaviour, observable through the rendered widget).

*Admission-gate justification.* Criterion 1 is a new behaviour with no existing coverage — no test in the repo asserts a populated `photos` list from a composer, because no UI has ever produced one. Criterion 3 is a gate whose absence silently discards user data. Criteria 4/5 are the revert-safety contract, asserted at the lowest layer that can express them (the widget, not the pure function — one behaviour, one home). Criterion 2 is covered by `text_composer_test.dart` unmodified and adds no case. Criterion 6 adds no case by definition.

**Must not regress**: the empty-save guard still refuses to write (`text_composer_sheet.dart:184-191`); `showTextComposer` still returns `Future<String?>` and `showEditNote` still returns `Future<bool?>` (`day_detail_edit_note.dart:146`); `barrierDismissible: true` still works on the note composer (`text_composer.dart:135`); `editNoteFailedMessage` stays reachable (N23); the `composerCloseKey` is unchanged (M8).

**Predicted delta**: **+3** → 954.

**A revert of P1 alone degrades to**: today's app. Photos are unreachable again and the tray returns to dead UI. Any `entry_photos` row already written keeps rendering through `InlinePhotoStrip`, which P1 never touched; its blobs stay reachable by the existing GC and export.

---

### P2 — Inline anchoring via the U+FFFC sentinel

**Branch**: `inline-photo/p2-anchor` — base `inline-photo/p1-wire`
**Outcome**: a photo renders as a tape-framed card at its authored place in the note text, in a full-width block, and survives a save/reopen/edit round-trip — which the prototype never did.
**Depends on**: P1.

**Files**:
- `lib/features/capture/text/photo_anchor_controller.dart` — **new** (R9, R11)
- `lib/features/capture/text/anchor_chip.dart` — **new** (R9)
- `lib/features/entry_cards/cards/inline_photo_card.dart` — **new** (R13)
- `lib/features/entry_cards/cards/photo_anchors.dart` — grows `photoAnchorOffsets`, the binding helper
- `lib/features/entry_cards/cards/note_body.dart` — renders anchored blocks (R20)
- `lib/features/entry_cards/entry_card.dart` — splits anchored from unanchored (R8)
- `lib/features/capture/text/text_composer_sheet.dart` — uses the anchor controller
- `lib/features/capture/text/text_composer.dart` — normalises before the write (R8)
- `lib/data/journal/entry_photos_dao.dart`, `lib/data/journal/drift_journal_repository.dart`, `lib/domain/repositories/journal_repository.dart` — `updateSortOrder` / `reorderPhotos` (R12)
- `test/features/capture/core/capture_test_support.dart` — the interface member, if the compiler demands it
- `lib/design/tokens/palette.dart`, `lib/design/tokens/shadows.dart`, `test/design/tokens/tokens_test.dart` — four token values

**FENCE — files P2 must NOT touch**: `lib/data/database/**` (M1 — a column is a migration); `lib/domain/models/entry_photo.dart` (M2); `lib/features/entry_cards/cards/photo_strip.dart` (M6); `lib/features/capture/photo/**`; `lib/design/widgets/sticker_card.dart` (the card composes its own decoration); `lib/design/layout/**` (does not exist until P3); every voice and video file; `third_party/**`.

**Binding resolutions**: R8 (the encoding, in full), R9 (the non-focusable chip), R10 (the six proofs), R11 (the live delta), R12 (`updateSortOrder`), R13 (the look), R14 (width), R16 (tape scaling), R17 (deterministic tilt), R19 (**full-width block only — no float**), R20 (`NoteBody` grows).

**Acceptance criteria, as testable assertions:**

1. A note with two photos and the text `'before￼middle￼after'` renders **two** `InlinePhotoCard`s; the first carries the `mediaId` of the photo with the lower `sortOrder`.
2. A note with **two** sentinels and **one** photo renders one card, and the second sentinel does not appear in any rendered string.
3. A note with **one** sentinel and **three** photos renders one card and one `InlinePhotoStrip` carrying the other two.
4. `find.byType(InlinePhotoStrip)` is `findsNothing` when every photo is anchored.
5. R10's six traversal cases pass on `TargetPlatform.macOS` **and** `TargetPlatform.iOS`.
6. Deleting the middle sentinel of three leaves photos 0 and 2 anchored, in that order, and persists a `sortOrder` for each that preserves it.
7. `updateSortOrder` writes `sortOrder` and `updatedAt` and leaves `deletedAt` null.
8. A note saved with sentinels, reopened in the composer, and saved again unchanged produces byte-identical `textContent`.
9. `Palette.photoFramePaper`, `Palette.photoTape`, `Shadows.photoFrame` and `Shadows.photoTape` hold the values in the token ledger.

**Tests it adds**: **11 cases**.
- `test/features/capture/text/anchor_chip_traversal_test.dart` — **6** (R10's matrix).
- `test/features/entry_cards/cards/note_body_anchors_test.dart` — **3** (criteria 2, 3, 4 — the strip and degrade contracts).
- `test/features/capture/text/photo_anchor_controller_test.dart` — **1** (criterion 6 — the delta rule; criterion 1 is covered by the same pump).
- `test/data/journal/entry_photos_dao_test.dart` — **1** (criterion 7 — the repository contract).
- Criterion 9 joins existing cases in `tokens_test.dart` and adds **0**.

*Admission-gate justification.* The six traversal cases are the phase's stated risk gate and assert observable editor behaviour (caret offset, text content) through the public widget surface; nothing in the repo covers `WidgetSpan` caret handling. The three render cases are new behaviours — sentinel-to-photo binding, excess-sentinel stripping, excess-photo fallback — with no existing coverage; each asserts what is rendered, not how. The controller case is the correctness fix R11 exists for. The DAO case is a new public repository contract. Criterion 8 is covered by criterion 6's round-trip and adds no case. Criterion 9 is a token contract, which by Cluster A's rule extends existing cases.

**Must not regress**: a note with **no** sentinel renders exactly as today (`note_body_test.dart`'s two cases pass unmodified); `photo_strip_test.dart` passes unmodified; the empty-save guard, both composer return contracts and `barrierDismissible` all hold; `entry_card_test.dart`, `today_entry_feed_test.dart` and `day_detail_entry_tile_test.dart` pass unmodified for the unanchored case.

**Predicted delta**: **+11** → 965.

**Two failure categories that are NOT test-count movements**: growing `JournalRepository` without updating every implementer is a **build break** and produces a total of **zero**, not a reduced count (R12). A leaked `TextPainter` reds a whole file with a binding stack trace (R15).

**A revert of P2 alone degrades to**: **P1's bottom strip.** The sentinels stay in the stored text but P1's `stripPhotoAnchors` removes every one from the render, so the user sees clean prose with every photo in `InlinePhotoStrip` below it. `sortOrder` values rewritten by `reorderPhotos` remain a valid ascending order and `InlinePhotoStrip` sorts by exactly that key. **This is the whole reason R7 put the stripper in P1.**

---

### P3 — Float left/right, static

**Branch**: `inline-photo/p3-float` — base `inline-photo/p2-anchor`
**Outcome**: the text wraps beside the card and continues below it. The single biggest lift in the ladder.
**Depends on**: P2, **and a green P0**.

**Files**:
- `lib/design/layout/inline_photo_geometry.dart` — **new**, `git mv` from the test tree (R4)
- `lib/design/layout/inline_photo_float_layout.dart` — **new**, same
- `lib/design/layout/layout.dart` — **new** barrel
- `test/features/entry_cards/photo/inline_photo_float_spike_test.dart` — imports retargeted through the barrel
- `lib/features/entry_cards/cards/note_body.dart` — the float path
- `lib/features/entry_cards/cards/inline_photo_card.dart` — the side-aware mount

**FENCE — files P3 must NOT touch**: everything in P2's fence, plus `lib/data/**` and `lib/domain/**` (P3 persists nothing); `lib/features/capture/**` (write mode is unchanged); `lib/design/tokens/**` (P3 adds no token).

**Binding resolutions**: R4 (the promotion, and the test-tree copies are **deleted**), R14 (width), R15 (`LayoutBuilder` + `Stack` + two `Text`s, **no custom `RenderBox`**), R16, R18 (the exclusion and the split, in full).

**Target values**: side is **derived**, not stored — `anchorIndex.isEven ? left : right`, the app's own parity precedent (`entry_card.dart:80`). A per-photo toggle is P4's. `widthFraction` is the 0.32 default (R14).

**Acceptance criteria, as testable assertions:**

1. Right float: for a real paragraph and one anchored photo, **no glyph box** of either rendered paragraph overlaps the exclusion rect. Asserted the same way P0 asserts it, now against `NoteBody`'s own layout.
2. Left float: the same.
3. Anchor index 0 floats left, index 1 floats right — parity.
4. Text **continues below** the card: for a paragraph long enough to overflow the exclusion height, paragraph B is non-empty and its top is `>= exclusion.bottom`.
5. A column narrower than `exclusion.width + 72` degrades to P2's full-width block and throws nothing.
6. `ls test/features/entry_cards/photo/inline_photo_geometry.dart` fails — the test-tree copy is gone.

**Tests it adds**: **5 cases** in `test/features/entry_cards/cards/note_body_float_test.dart` — criteria 1, 2, 3, 4, 5.

*Admission-gate justification.* Each is a new layout behaviour with no existing coverage, asserted through the rendered widget rather than through the pure function P0 already covers — P0's cases pin the algorithm, these pin the wiring, and they are not duplicates because a correct algorithm wired to the wrong width fails only here. Criterion 6 is a fence check, not a test, and adds no case.

**Must not regress**: P0's seven cases pass **unmodified** after the `git mv` and the import retarget — a moved file with byte-identical content is the receipt that the promotion was faithful. A note with no photos never enters the float path. `photo_strip_test.dart` and `note_body_test.dart` pass unmodified.

**Predicted delta**: **+5** → 970.

**A revert of P3 alone degrades to**: P2's full-width block. Every anchored photo still renders at its authored position, centred in the column; no text wraps beside it. **P3 persists nothing, so there is no data to clean up.** The `lib/design/layout/` files vanish with the revert, which is why P0's spike test must be reverted in the same commit — it imports them.

---

### P4 — Arrange mode

**Branch**: `inline-photo/p4-arrange` — base `inline-photo/p3-float`
**Outcome**: handles appear when the editor loses focus. Drag the anchor through the story, flip the side, resize. Write mode is untouched.
**Depends on**: P3. **Fully greenfield** — there is zero gesture-to-persisted-transform precedent anywhere in `lib/`.

**Files**:
- `lib/features/capture/text/note_arrange_mode.dart` — **new**
- `lib/data/journal/inline_photo_layout_store.dart` — **new** (R21)
- `lib/data/settings/settings_keys.dart` — one prefix constant
- `lib/features/capture/text/text_composer_sheet.dart` — the mode switch (R22)
- `lib/features/capture/text/photo_anchor_controller.dart` — anchor moves
- `lib/design/layout/inline_photo_float_layout.dart` — the memo cache (R23)
- `lib/features/entry_cards/cards/inline_photo_card.dart` — stored side and width
- `lib/data/journal/drift_journal_repository.dart` — layout-key deletion on soft delete
- `lib/features/data/journal_delete_all_service.dart` — layout-key cleanup (R21)
- `lib/data/media/media_gc.dart` — orphan-key sweep (R21)

**FENCE — files P4 must NOT touch**: `lib/data/database/**` (M1); `lib/domain/models/entry_photo.dart` (M2); `lib/features/entry_cards/cards/photo_strip.dart` (M6); `lib/features/capture/photo/**`; `lib/features/data/journal_export_service.dart` (the payload change is a consequence of R21, not an edit — the service already exports the whole `Settings` table at `:37`); every voice and video file; `lib/features/entry_cards/playback/**`.

**Binding resolutions**: R21 (the `Settings` sidecar and its three cleanup obligations), R22 (the mode boundary), R23 (the throttle and the cache, as numbers), R14 (the resize clamp).

**Target values**: `widthFraction` clamped to `[0.20, 0.60]`, then the pixel clamp `[96, 210]` (R14). Resize quantised to **8 logical px** of width, aspect locked at 1.25. Live reflow disabled above **4000 characters** (R23).

**Acceptance criteria, as testable assertions:**

1. Dragging an anchor from index i to index j rewrites the text so that exactly one U+FFFC moves and every other code unit is unchanged.
2. Flipping the side writes `{"side":...}` under `inline_photo_layout:<id>` and the flipped side survives a reopen.
3. Resize is aspect-locked and clamped: a drag past the bounds yields `widthFraction` in `[0.20, 0.60]` and a rendered width in `[96, 210]`.
4. Arrange mode mounts **no** `EditableText`; write mode mounts **no** arrange handle.
5. `deleteAll` removes every `inline_photo_layout:*` row.
6. `softDeletePhoto` removes that photo's layout key.
7. The split cache returns the **identical** `InlinePhotoSplit` instance for an unchanged key, and a changed `columnWidth` misses.

**Tests it adds**: **7 cases**.
- `test/features/capture/text/note_arrange_mode_test.dart` — criteria 1, 2, 3, 4.
- `test/features/data/journal_delete_all_service_test.dart` — criterion 5 (added to the existing file).
- `test/data/journal/inline_photo_layout_store_test.dart` — criterion 6.
- `test/design/layout/inline_photo_float_layout_test.dart` — criterion 7.

*Admission-gate justification.* Criteria 1–4 are new user-facing behaviours in a mode that does not exist, asserted through the widget surface. Criteria 5 and 6 are data-integrity behaviours: without them a delete-all leaves rows behind, which is the failure the deny-case discipline exists to catch. Criterion 7 is the perf contract R23 specifies in numbers; a cache with no receipt is a claim, not a mechanism. Criterion 3's clamp is a behaviour, not a styling value — a bad clamp lets a photo consume the whole column.

**Must not regress**: **write mode is byte-identical** — the same `EditableText` configuration (`text_composer_sheet.dart:293-304`), the same controller, the same `expands: true`, the same save contract. `text_composer_test.dart`, `text_composer_save_hang_test.dart` and `text_composer_timeout_dedupe_test.dart` pass unmodified. `journal_export_service` tests pass unmodified (it exports the table generically). `media_gc` tests pass unmodified for every existing sweep.

**Predicted delta**: **+7** → 977.

**A revert of P4 alone degrades to**: P3's static float. Side returns to index parity, width to 0.32, and there are no handles and no arrange mode. `inline_photo_layout:*` rows remain in `Settings`, unread; the three cleanup hooks revert with the phase, so keys accumulate slowly on delete-all. **That is a leak of bytes in an existing table, never a correctness fault** — nothing reads them and nothing depends on them. Re-landing P4 re-adopts them intact.

---

### P5 — User-controlled rotation

**Branch**: `inline-photo/p5-rotate` — base `inline-photo/p4-arrange`
**Outcome**: a rotation handle, clamped so the exclusion box cannot balloon.
**Depends on**: P4. **Last, because dropping it loses nothing else** — P2 already shipped the tilt.

**Files**:
- `lib/features/capture/text/note_arrange_mode.dart` — the handle
- `lib/data/journal/inline_photo_layout_store.dart` — the `rotationDeg` field
- `lib/features/entry_cards/cards/inline_photo_card.dart` — the stored angle
- `lib/design/layout/inline_photo_geometry.dart` — **read only in spirit**: R25 says the algorithm does not change. If P5's diff changes the hull math, it is wrong

**FENCE — files P5 must NOT touch**: everything in P4's fence, plus `lib/features/capture/text/photo_anchor_controller.dart` (rotation is not an anchor concern), `lib/features/entry_cards/cards/note_body.dart` (the block assembly is unchanged), `lib/design/tokens/**`.

**Binding resolutions**: R24 (±15.0deg, quantised to 0.5), R25 (the exclusion **input** changes, not the algorithm).

**Acceptance criteria, as testable assertions:**

1. A rotation set in arrange mode survives a save and a reopen.
2. A drag past the bounds yields `rotationDeg` in `[-15.0, 15.0]`, quantised to 0.5.
3. `inlinePhotoExclusion(width: w, tiltDegrees: 15)` strictly contains `(width: w, tiltDegrees: 0)`, and contains all twelve of its own rotated hull points.
4. At `tiltDegrees: 15` and at `-15`, **no glyph box** of either rendered paragraph overlaps the exclusion rect.

**Tests it adds**: **4 cases** — criteria 1 and 2 in `note_arrange_mode_test.dart` (added to the existing file), criteria 3 and 4 in `note_body_float_test.dart` (added to the existing file).

*Admission-gate justification.* Criteria 1 and 2 are new persisted behaviour with no existing coverage. Criterion 3 is the rotation-aware exclusion contract at the extreme the clamp exists to bound. Criterion 4 is the "no glyph touches any ink" guarantee at the worst case — the only angle at which it can plausibly fail, and therefore the only one worth a case beyond P3's.

**Must not regress**: P0's seven cases and P3's five pass **unmodified** — R25 means no geometry code changed, so a red in either is the signal that it did. A photo with no stored `rotationDeg` renders at `photoTiltDegrees`'s derived angle, exactly as under P2.

**Predicted delta**: **+4** → 981.

**A revert of P5 alone degrades to**: P4's arrange mode with no rotation handle. The tilt falls back to `photoTiltDegrees`. `rotationDeg` keys remain in `Settings`, and because every field of the layout JSON is optional a P4-era reader ignores them without error. **No cleanup, no migration, no data loss.**

---

## 5. Verification strategy

### 5.1 What the repo actually has

The automated safety net for this ladder is the existing widget suite. For these surfaces it is eleven files:

| Area | Files | What they actually pin |
|---|---|---|
| Note composer | `test/features/capture/core/text_composer_test.dart`, `text_composer_timeout_dedupe_test.dart`, `text_composer_save_hang_test.dart`, `test/repro/capture_save_hang_repro_test.dart` | Save flow, dedupe, hang behaviour, in-flight labels |
| Edit path | `test/features/day_detail/day_detail_edit_note_test.dart`, `day_detail_entry_tile_test.dart` | The confirm, the `bool?` contract, the photo strip's presence |
| Note render | `test/features/entry_cards/cards/note_body_test.dart`, `cards/photo_strip_test.dart`, `entry_card_test.dart` | Serif style, the empty affordance, `sortOrder` ordering, the strip's presence |
| Photo picker | `test/features/capture/photo/photo_tray_test.dart`, `photo_thumbnail_test.dart`, `image_picker_photo_picker_test.dart` | Add, remove, cap 8, camera availability, error copy |
| Feed | `test/features/today/today_entry_feed_test.dart` | Two strips for two photo-bearing entries |
| Goldens | `test/design/goldens/**` | Cluster H's five families. **This ladder adds none** (§6.2) |

**Almost none of them asserts a colour, a padding, a width or a layout arrangement.** They assert labels, types and counts. That is why §5.5's manual pass is the only real fidelity check, and why §5.6's register is short — this ladder is almost entirely additive and breaks very few existing assertions.

### 5.2 The testing rule that governs this ladder

Per the project's test admission gate, a **styling, layout or copy change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract, with no existing coverage, asserting observable behaviour through a public surface.

| Phase | Cases | Why they qualify |
|---|---|---|
| P0 | 7 | Public contract of two new pure functions, plus the feasibility verdict itself. Zero existing coverage |
| P1 | 3 | A request field no UI has ever populated; a gate protecting a non-existent write path; the revert-safety render contract |
| P2 | 11 | The #159171 risk gate (6), the binding and degrade contracts (3), the delta-rule correctness fix (1), a new repository contract (1) |
| P3 | 5 | New layout behaviours, asserted through the rendered widget |
| P4 | 7 | A mode that does not exist (4), two data-integrity deny cases (2), the perf contract (1) |
| P5 | 4 | New persisted behaviour (2) and the exclusion guarantee at the clamped extreme (2) |

**No golden test and no per-widget geometry test.** Both would be change-detectors on values this document already pins.

### 5.3 Baseline and per-phase test-count prediction

**MEASURED first-hand while composing this spec**, on `inline-photo/spec` cut from `origin/main` at `712c978`, with `git diff origin/main -- lib/ test/` empty, in the foreground:

> `flutter analyze` -> **`No issues found! (ran in 2.7s)`**
> `flutter test` -> **`00:27 +944: All tests passed!`** — **944 passing, 0 failing.**

This figure was measured, not inherited. The recorded figure has been stale three times on this project; **measure it again on your own base.**

| Phase | Delta | Expected total | Reason |
|---|---|---|---|
| P0 | **+7** | **951** | Seven spike cases. Zero product code, so nothing else can move |
| P1 | **+3** | **954** | Two composer cases, one `NoteBody` case. Six tray cases become live but were already counted |
| P2 | **+11** | **965** | Six traversal, three render, one controller, one DAO. Four token assertions add none |
| P3 | **+5** | **970** | Five float cases. The `git mv` moves seven cases without changing the count |
| P4 | **+7** | **977** | Four arrange, two cleanup, one cache |
| P5 | **+4** | **981** | Two persistence, two exclusion |

**Ladder close: 981.** A result above the prediction means a behaviour was split into more cases than the acceptance criteria name — report it rather than absorbing it. A result below **944** at any point means a case was lost, which is the failure this discipline exists to catch.

**Two categories of failure that are NOT test-count movements:**

1. **Build breaks.** Growing `JournalRepository` (R12) without updating every implementer produces a compile error and a total of **zero**, not a reduced count.
2. **Leaked `TextPainter`s.** Flutter 3.44 asserts on them in debug; the failure names the binding, not the widget (R15).

### 5.4 The standing regression gate

Before any phase merges:

1. `flutter analyze` clean.
2. The four receipts in §0's STANDING INVARIANT pass.
3. The protected playback suite runs **unmodified** and passes (N24). Exposure here is **zero** by path disjointness — no phase opens `lib/features/entry_cards/playback/**` or `cards/video_*` / `cards/voice_*`. A diff in that suite is itself the signal that the fence has been breached.
4. **Never `flutter test integration_test/` as a directory** (R2). `integration_test/capture_ui_flow_test.dart` is nameable and is run by name in P1 and P2, because it holds note-composer label assertions that `fullValidationCmd` never reaches — `fullValidationCmd` runs `flutter test` over the `test/` tree only.
5. Diff-scoped verification during the work; `fullValidationCmd` at the phase boundary and pre-push, in the **foreground**, with an explicit long timeout (R3).

**CI is not evidence.** `receiptsPass` and `d6Pass` are never acceptable as proof.

### 5.5 Manual spot-check — REQUIRED, and OWED BY A HUMAN

**No agent can run this app** (R28). The pass is per-phase, on macOS via `flutter run -d macos`.

- **After P0:** nothing. P0 changes no product code. If the app looks different, P0 is out of bounds.
- **After P1:** the note composer shows one `Add memory` button below the writing surface (macOS has no camera path). Pick a photo, save, and confirm it appears in the strip under the note on Today and in Day Detail. Open **Edit note** on that entry and confirm **there is no picker**. Save the edit and confirm the photo is still there.
- **After P2:** type a note, insert a photo, and confirm a tape-framed white card with two tape strips appears **at that point in the text**, square-cornered, slightly tilted, with the text above and below it. Arrow across the chip in the editor, backspace it, and undo by re-inserting — confirm the caret never jumps and no text is duplicated. **This is the manual half of R10 and it is the highest-value check in the ladder.** Save, reopen, and confirm the card is in the same place.
- **After P3:** the same note now has the text running **beside** the card and continuing below it. Confirm no letter touches the white frame or either tape strip, at the top-left and top-right of the card where the tape overhangs. Narrow the window until the column is too tight and confirm the card falls back to a full-width block rather than overflowing.
- **After P4:** tap out of the text — handles appear. Drag the card through the paragraph and confirm the text reflows without stutter and the card lands between words, not mid-word. Flip the side. Resize to both clamps. Tap back into the text and confirm the editor is exactly as it was. Delete all data and confirm a fresh journal opens clean.
- **After P5:** rotate the card to both clamps and confirm the text opens up around the tilted corners rather than colliding with them.

### 5.6 Red-test register — every predicted retarget, declared in advance

Per `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, a phase may retarget an existing assertion that pins a rendering it is mandated to change. **This ladder is almost entirely additive and the register is correspondingly short.**

| Phase | File | What could break | Retarget |
|---|---|---|---|
| P1 | `test/features/capture/core/text_composer_test.dart` | Nothing predicted. The tray is added below the writing surface and no case asserts the composer's child count | none — if it reds, the mount is in the wrong place |
| P2 | `test/features/capture/core/capture_test_support.dart` | `FailingJournalRepository` may not satisfy the grown interface. It forwards via `noSuchMethod` at `:86`, so it may need nothing | **declared, bounded**: add the member if and only if the compiler demands it. No assertion changes (R12) |
| P2 | `test/features/entry_cards/entry_card_test.dart:55` | Asserts `find.byType(InlinePhotoStrip)` is `findsOneWidget` for a photo-bearing entry. Its fixture's text has **no** sentinel, so every photo stays unanchored and the strip still renders | **verified NOT red** — do not "fix" it |
| P2 | `test/features/today/today_entry_feed_test.dart:112`, `test/features/day_detail/day_detail_entry_tile_test.dart:123`, `:141` | Same shape, same reason | **verified NOT red** |
| P3 | `test/features/entry_cards/photo/inline_photo_float_spike_test.dart` | Import paths change when the source files move to `lib/design/layout/` (R4) | import-only edit; **every assertion is byte-identical** |

**Verified NOT red — do not touch:** `photo_tray_test.dart` (all six), `photo_strip_test.dart`, `note_body_test.dart`'s two existing cases, `photo_thumbnail_test.dart`, `image_picker_photo_picker_test.dart`, `day_detail_edit_note_test.dart`, and every file in the protected playback suite.

### 5.7 Plan scope-guard rule

Every plan produced from this spec anchors its scope guard to a SHA captured with `git rev-parse HEAD` **before the phase's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the phase — and do not use a fixed `HEAD~N`. State the expected diff as the phase's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation (`decisions/2026-07-27-scope-guard-authorship-oracle.md`).

---

## 6. Out of scope

### 6.1 Deferred to a later spec — with its values preserved so it cannot be lost

- **The prototype's `Add memory` pill.** P1 mounts `PhotoTray`'s existing `StickerButton` chrome (R5). The prototype's affordance, preserved verbatim so the sixth lost value does not happen here:
  - **Desktop, `Field Notes.dc.html:471`** — `display:flex; align-items:center; gap:7px; background:#c76a54; color:#fff; border:1.5px solid #4a3b2e; border-radius:11px; padding:8px 13px; box-shadow:1.5px 1.5px 0 #4a3b2e; cursor:pointer`, a 16x16 icon span, label `600 12px 'Instrument Sans'` reading **`Add memory`**. Its container is `:470` — `display:flex; align-items:center; gap:10px; margin-top:10px`.
  - **Phone, `Field Notes.dc.html:772`** — the same, at `gap:6px; border-radius:10px; padding:7px 11px`, a 15x15 icon and `600 11px`. Its container `:771` is `display:flex; align-items:center; gap:9px; padding:9px 14px 14px; border-top:1px dashed rgba(74,59,46,.2); background:#fbf3e4`.
  - Every value maps to a shipped token: `Palette.coral` (`palette.dart:33`), `Palette.onAccent` (`:51`), `Shapes.outline` (`shapes.dart:25-27`), `Shapes.radiusSm` 11 (`:12`), `Shapes.radiusCell` 10 (`:11`), `Shadows.control` (`shadows.dart:33-40`), `TypographyTokens.captureLabelSans`. **No new token is required for this restyle.**
- **Attaching a photo to an EXISTING entry.** `updateEntryText` takes text and nothing else (`journal_repository.dart:29-32`); the edit path has no photo write. R6 hides the picker there rather than inventing one. Adding it is a domain change and gets its own spec.
- **Photos on voice and video entries.** `VoiceCaptureRequest.photos` (`capture_service.dart:73`) and `VideoCaptureRequest.photos` (`:89`) both exist and are both unpopulated. Wiring them is a different spec; no phase here opens either composer.
- **The empty-save guard's `&& photos.isEmpty` clause.** The prototype's predicate is text-empty **and** no photos; the app's is text-only (`text_composer_sheet.dart:186`). Once P1 lands the tray, the clause becomes reachable and is a one-line change — but it changes a shipped guard's behaviour and belongs to a phase that owns the guard, not to P1 (M7).
- **RTL.** `splitForFloat` takes a `TextDirection` and mirrors the side so the API is not baked wrong, but the app is LTR-only today (`test/design/widgets/widget_harness.dart:5`) and no phase here tests RTL.
- **The markdown editor engine.** Live block styles, the floating selection toolbar and the footer legend (`Field Notes.dc.html:472`) are their own subsystem, already routed to their own spec by the parent's §6.1.
- **A caption.** The decision record **dissolves** it: a caption becomes the line of text under the photo. `EntryPhoto.label` is never needed (M2), and the prototype's `.ms-cap` (`md-scrapbook.js:144`, `:376-378`) is not adopted.
- **The `polaroid` and `plain` photo styles** (`md-scrapbook.js:377-383`). Only `tape` is adopted.

### 6.2 Explicitly not a task

- **No database migration, in any phase, for any reason** (M1, R1). If a phase appears to need one, **STOP and report** — do not write one.
- **No new field on `EntryPhoto` or `EntryPhotos`** (M2).
- **No packed `sortOrder`** (M9, R21's rejected list).
- **No edit to `lib/features/capture/photo/**`.** The tray is mounted, never modified (R5).
- **No edit to `lib/features/entry_cards/cards/photo_strip.dart`.** It is the permanent degrade target (M6).
- **No edit to `lib/design/widgets/sticker_card.dart`**, including adding a `border` or `clipBehavior` parameter. 16 call sites plus A4's contract. Cluster G's R1 is the precedent.
- **No custom `RenderBox` for the float** (R15).
- **No nested editable inside a `WidgetSpan`** (R9). That is #159171's exact reproduction.
- **No golden test and no per-widget geometry test.** Change-detectors on values this document already pins.
- **No new dependency of any kind** (M10).
- **No `flutter run` by an implementing agent** (R28). Visual confirmation is a human step on macOS hardware.
- **No `gh pr create`, `gh pr edit`, `gh api` POST to the pulls endpoint, or any GraphQL/MCP PR-write** (R27). **No merge of any kind** — every merge is a human action.
- **No deletion or weakening of the protected playback suite** under any circumstances (N24).

### 6.3 Open questions

**None blocks a phase.** Two are recorded so they are answered deliberately rather than by side effect:

1. **Does the layout sidecar belong in `Settings` permanently?** R21 resolves it for this ladder because it is the only migration-free home and because it degrades perfectly. If the app ever gains a migration harness — with a successful-upgrade test and a rollback proven on a copy of a real journal, which the thread's own completion criterion demands — moving the three fields to columns becomes a legitimate MSP. It is not one today.
2. **Should the composer preview the float?** Under the decided model the author sees plain text with chips in write mode and the float only after saving, until P4's arrange mode closes the gap. That is a direct consequence of M3 and is not a defect; if it proves unacceptable in the P2 manual pass, the answer is to bring arrange mode forward, never to attempt an editable wrap.

**OQ-3** (entry-card Edit/Delete placement) belongs to the `prototype-design-alignment` thread and touches no phase here.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Every source line this document cites was re-opened from the repository at `712c978` while composing it.** The prototype: `md-scrapbook.js:133-146` (the photo layer's CSS), `:334-337` (the state object and the ±4 random tilt), `:340-356` (the card element), `:362-384` (all three frame styles), `:387-393` (`_applyPhoto`), `:492-497` (`_alpha`); `Field Notes.dc.html:469-473` and `:771-773` (both `Add memory` buttons and their containers). The app: `app_database.dart:9-37`, `tables.dart:36-70`, `entry_photos_dao.dart:1-52`, `drift_journal_repository.dart:165-191`, `journal_repository.dart:29-58`, `entry_photo.dart:1-20`, `capture_service.dart:43-110`, `journal_capture_service.dart:40-88`, `text_composer.dart:100-147`, `text_composer_sheet.dart:1-333`, `day_detail_edit_note.dart:1-181`, `photo_tray.dart:1-30`, `photo_picker.dart`, `image_picker_photo_picker.dart:44`, `photo_strip.dart:1-63`, `note_body.dart`, `entry_card.dart:31-81`, `sticker_card.dart:1-49`, `media_image.dart:9-30`, `media_resolver.dart`, `journal_delete_all_service.dart:22-45`, `journal_export_service.dart:35-44`, `media_gc.dart:43-53`, `:130-144`, `settings_keys.dart`, `drift_settings_repository.dart:49-51`, `palette.dart`, `shapes.dart`, `shadows.dart:105-112`, `capture_test_support.dart`, `photo_tray_test.dart`, `note_body_test.dart`, `photo_strip_test.dart`, `golden_harness.dart`, `widget_harness.dart:5`. The framework, at Flutter 3.44.8 / Dart 3.12.2: `placeholder_span.dart:51`, `:73`; `text_painter.dart:1221`, `:1658`, `:1706`, `:1742`, `:1786`; `sky_engine/lib/ui/text.dart`'s `LineMetrics` field list.

**Four external issues were independently fetched and their state read while composing this document**, not inherited from the ledger:

| Issue | Title, quoted | State |
|---|---|---|
| [flutter/flutter#159171](https://github.com/flutter/flutter/issues/159171) | *"TextField as WidgetSpan mixes parent TextField initial text when delete or arrow keys used"* | **open** |
| [flutter/flutter#50171](https://github.com/flutter/flutter/issues/50171) | *"Need a line/word breaker for custom text rendering"* | **open** |
| [flutter/flutter#92173](https://github.com/flutter/flutter/issues/92173) | *"paragraph.layout() seems very expensive"* | **open** |
| [flutter/flutter#132421](https://github.com/flutter/flutter/issues/132421) | *"Calling layout on TextPainter for conditional layouts can be slow"* | **open** |

**#159171 is narrower than the ledger records it, and that narrowing is load-bearing.** The reported defect requires a `TextField` nested inside a `WidgetSpan` of a parent `TextField`. R9's non-focusable chip cannot reproduce it. R10 measures anyway, because a narrower issue is not the same as no risk.

**Four kinds of defect this document exists to prevent, in descending order of danger:**

1. **A value that is unreachable without a schema change.** Side, size and rotation have no column and may not get one (R21). This is the class that would have bricked every existing journal.
2. **A capability the app does not have in any form.** No `sortOrder` update path (R12); no text-exclusion API at any layer (R18); no gesture-to-persisted-transform precedent anywhere in `lib/` (P4); no layout-key cleanup in delete-all or GC (R21).
3. **A fence defect — the file that owns the value is not the file the phase names.** P0's math must live under `test/` and P3's must live under `lib/` (R4); the picker must be gated at `day_detail_edit_note.dart`, which is not a P1 file by any obvious reading (R6).
4. **Citation drift.** `sticker_card.dart:44-49` does not exist; `Field Notes.dc.html:470` is a wrapper, not the button; the ledger's summary of #159171 is broader than the issue.

**Rule for implementers:** re-open every cited line — in the prototype, in the app's own source, and in the Flutter SDK — before adopting any value, and **open the widget or the DAO the value has to pass through before assuming it can hold it.** If you meet an anchor that does not resolve, or a target the code has no way to express, **stop and report. Do not make the call yourself** — that is exactly how the C5 caption and three C7 ladder rows were lost.
