# Note Editor and Scrapbook Photos — Fix Wave

Date: 2026-09-21. Base: `main` @ `748aec7`. Parent spec:
`docs/specs/2026-09-20-note-editor-and-scrapbook-photos.md`.

Dispatch contract: `docs/specs/items/2026-09-21-note-fix-wave.items.json`, run by mitosis 0.2.0 through
its `--items` pathway. Every Worker also receives `docs/specs/2026-09-21-note-fix-wave.charter.md`.
This document is the human-readable authority for the wave. Where it and the parent spec disagree,
**this document wins**; the rulings in §2 say exactly where and why.

---

## 0. Why this wave exists

Nine of the parent spec's ten units merged (#129–#138). A conformance audit of `main` @ `748aec7`
found the architecture sound and every cross-cutting rule met, but the implementation **not complete**:
seven behavioural defects, two acceptance items no unit delivered, a benchmark that measures
placeholders instead of photos, a CI path filter that skips the float's goldens, and one missing guard
test. Four of the defects are protected by tests that were rewritten to assert the wrong behaviour.

Every finding below was re-verified against the code before this document was written. Two audit
findings did not survive that check and are recorded in §2 as dropped, with the evidence.

When this wave merges, the parent spec is complete except for the three items only a person can do:
the Android benchmark on a real phone, the `u10` decision that follows from it, and seeing the feature
run on macOS and Android (§6).

---

## 1. The findings

| # | Finding | Evidence | Step |
|---|---|---|---|
| F1 | A new-note draft is never restored. The composer mints a fresh id on every open and looks the draft up under it, so the draft a crash left behind is never read. | `lib/features/capture/text/text_composer.dart:92,95,98` | `draft-restore` |
| F2 | The feed preview renders every photo in the note's first 1200 characters, and every photo of a note at or under 1200 characters. The parent spec says the first photo only. | `lib/features/entry_cards/cards/note_preview.dart:70-71,82` | `preview-first-photo` |
| F3 | The placement mini-diagram never passes `nextIsParagraph`, so it reports "stacked" for a photo the reader will float. | `lib/features/notes/photos/photo_options_sheet.dart:773-787`; locked in by `test/features/notes/photos/photo_rail_test.dart:575-605` | `photo-diagram-and-placement` |
| F4 | The Add photo tile disappears when the composer is short: the rail returns `SizedBox.shrink()` below 72pt, which a landscape phone with the keyboard up reaches. There is then no way to add a photo. | `lib/features/notes/photos/photo_rail.dart:321-323`; locked in by `photo_rail_test.dart:369-379` | `short-screen-tools` |
| F5 | The format bar, and with it the only Undo on Android, is removed on the same short panels. | `lib/features/capture/text/text_composer_sheet.dart:215-223`; locked in by `test/features/capture/text/editor/format_bar_test.dart:265-275` | `short-screen-tools` |
| F6 | A photo line whose placement title holds an unknown or repeated token still floats, at the right/medium default. The parent spec lists an unparseable token as a stacked case. | `lib/features/notes/model/photo_placement.dart:42-66` | `photo-diagram-and-placement` |
| F7 | A photo whose file exists but cannot be decoded still floats, with a broken-image placeholder inside the float. The parent spec lists a corrupt blob as a stacked case. | `lib/features/entry_cards/media/media_resolver.dart:75-86`; `lib/features/notes/render/photo_wrap_block.dart:264-297` | `corrupt-photo-fallback` |
| F8 | A preview cut can land inside a photo line, because the cut is made at the last whitespace and a photo line contains one. | `note_preview.dart:35-41,52-53` | `preview-first-photo` |
| F9 | A tap on the composer's backdrop does nothing. `u3`'s acceptance line says a barrier tap routes through the dirty-check confirm. | `lib/features/capture/core/composer_shell.dart` (scrim absorbs the tap); locked in by `test/features/capture/core/text_composer_test.dart` "a barrier tap no longer dismisses the composer" | `composer-scrim-close` |
| F10 | Delete all clears the database and media but not the drafts folder. Harmless only while drafts are never restored; with F1 fixed, a deleted journal could resurface through a draft. | `lib/features/data/journal_delete_all_service.dart` | `draft-restore` |
| F11 | Benchmark numbers 3 and 4 measure placeholders. Number 4 mounts `NoteBody` with no media scope, so every photo renders as `NotePhotoStub`; number 3 measures a paragraph wrapping at the column edge, not a paragraph wrapping around a photo. Number 1 uses a copy of the shipping controller. The results document names a flag that does not exist. | `integration_test/note_perf_bench_test.dart:35-77,133-201`; `docs/specs/research/2026-09-20-android-measurement.md:242` | `bench-real-photos` |
| F12 | `u5` promises the length-preserving assert on every `buildTextSpan`; the empty and over-limit paths return before it runs. | `lib/features/capture/text/editor/markdown_style_controller.dart:78-84` | `bench-real-photos` |
| F13 | The goldens workflow's `paths:` filter omits every directory the float goldens render from, so a float change never runs them in CI. | `.github/workflows/goldens.yml:4-9` | `note-guards` |
| F14 | `u7` promised a test that GC never runs automatically. None exists. | `test/` has no such test; the only caller is `lib/features/settings/journal_data_controller.dart:56` | `note-guards` |
| F15 | EXIF orientation. `u7` said to read orientation; the code reads width and height only. **Measured: not a defect.** See ruling W7. It gets a guard test so it stays true. | `lib/features/capture/photo/photo_intrinsics.dart:11-15` | `note-guards` |

---

## 2. Rulings for this wave

These settle every question the findings raise. Workers do not reopen them.

### W1 — New-note drafts are keyed by date. Supersedes `u3`'s session-key stress fix.

`u3` keyed a new-note draft by a session id so that "an abandoned draft [would not] silently return
to a later blank composer". But Discard already deletes the draft, and a successful save deletes it
too. The only draft that can survive is one a crash or a killed process left behind — exactly the
draft the feature exists to recover. The session key made that recovery impossible.

- The key is `new-<date>`, where `<date>` is the composer's `YYYY-MM-DD` date key. Example:
  `new-2026-09-21`.
- Reopening a new-note composer for the same date restores the draft behind the existing inline
  "Draft restored · Discard" chip. A composer for a different date does not see it.
- At most one new-note draft exists per date, so orphans are bounded.
- The edit route keeps keying by entry id, unchanged.
- Delete all removes the drafts folder (F10), so deleting the journal cannot resurface a note.
- The draft controller stops drafting the moment its composer commits to closing: on Discard, on a
  clean close, and after a successful save, before the route pops. Without this, the app going to the
  background during the 220 ms close animation flushed the text and wrote the draft back, so a
  discarded or already-saved note reappeared in the next composer. Found in review of the first build;
  the edit route had the same hole before this wave.
- `IntegrationSandbox` redirects the drafts folder into its temporary root, so an integration test can
  never read or delete the real journal's drafts.
- A close requested while the stored draft is still loading counts as dirty, so it asks "Discard
  this note?" at once and the draft finishes loading behind the question. Without this, closing in the
  instant before a crash-left draft loaded counted as a clean close and deleted the draft unseen. An
  earlier version waited for the load before deciding; review showed a Save tapped during that wait
  closed the confirm instead of the composer, so the close never waits.
- A draft that finishes loading after the composer was discarded is not applied to the editor.

### W2 — A backdrop tap routes through the close request. Resolves `u3`'s internal inconsistency.

`u3` said both `barrierDismissible: false` and "a barrier tap ... route[s] through one dirty-check
confirm". Both hold if the barrier never dismisses directly and a backdrop tap asks the same question
the X does. The composer's own scrim covers the route barrier, so the tap is taken on the scrim.

- Clean composer: a backdrop tap closes it, as the X does.
- Dirty composer: a backdrop tap shows "Discard this note?". Keep editing leaves everything as it was.
- While saving, a backdrop tap does nothing, as the X does.
- Applies to the new-note and edit-note routes only. Voice and video composers are untouched.

### W3 — A short composer never loses Undo or Add photo.

Measured on `748aec7`: at 844×390 with a 200pt keyboard the sheet gets 186pt and the editor 86pt,
against the 76.8pt three-line floor `test/features/capture/text/text_composer_geometry_test.dart`
already enforces. There is no room for another 36pt row, so the tools move into rows that already
exist rather than adding one.

- **Roomy** means the panel fits chrome + format bar + four writing lines — the formula
  `_hasRoomForFormatBar` already uses, unchanged.
- Roomy: the format bar sits where it sits today (header on the desktop shell, above the keyboard
  otherwise).
- Not roomy: the format bar moves **into the header row**, between the close X and Save, and the
  title block is omitted for as long as the panel stays short. The header row grows from 31pt to
  36pt; the editor keeps its three lines.
- The photo rail sits below the writing surface only when its budget reaches the compact rail's 72pt.
  Otherwise the rail renders a **slim Add photo tile** inside the format bar's trailing slot. The rail
  is never removed.
- The six formatting toggles scroll horizontally when the bar is narrower than they are. Undo and the
  trailing slot are always visible.
- The rail keeps its State when it moves between the two positions, so a pick started from the slim
  tile still lands after the system picker closes the keyboard and the panel grows.

### W4 — The feed preview is a prefix of the note, cut by blocks.

- The preview keeps blocks in source order until the next block would pass 1200 source characters.
- The first photo block inside that prefix is kept whole. Every later photo block is dropped.
- A photo block is never cut. If the limit falls inside one, the preview ends before it.
- A non-photo block that straddles the limit is cut at its last whitespace before the limit, as today.
- `wasTruncated` is true whenever anything was dropped or cut, so Read more appears.
- A photo that sits past the cut is not pulled forward. R2 anchors a photo to its place in the text, and
  a preview that relocates it would contradict the read view it previews. A long note whose first photo
  is deep in the text shows text only in the feed.

### W5 — Placement validity.

- A placement is **valid** when every whitespace-separated title token, compared case-insensitively,
  is a side name (`left`, `right`) or a size name (`small`, `medium`, `large`, `full`), with at most one
  side token and at most one size token.
- An empty or absent title is valid: right, medium.
- An invalid placement always renders as `StackedPhoto`, and the mini-diagram reports it stacked.
- Setting a side, a size, a caption or a replacement through the UI rewrites the title from the parsed
  side and size only, so any UI edit writes a valid placement. Unknown tokens are not preserved.

### W6 — A photo that cannot be decoded falls back to `StackedPhoto`.

Detection is event-driven: `MediaImage` already reaches its `errorBuilder` on a decode failure. It
reports that through a new callback, and `PhotoWrapBlock` rebuilds as its stacked fallback. No extra
file read is added to the resolver, which every feed card and thumbnail goes through.

### W7 — EXIF orientation is honoured by the engine. Pinned by tests, no code change.

Measured on Flutter 3.44.8 with JPEG fixtures carrying EXIF orientation 6 (ImageIO confirms the tag):

| Fixture | `ImageDescriptor` size | Decoded size | After `downscalePhoto` |
|---|---|---|---|
| 60×30, no orientation | 60×30 | 60×30 | 60×30, unchanged bytes |
| 60×30, orientation 6 | **30×60** | **30×60** | 30×60, unchanged bytes |
| 3000×1500, orientation 6 | **1500×3000** | **1500×3000** | 1024×2048 PNG |

The stored dimensions, the decoded pixels and the downscale target all agree, so a portrait phone photo
is stored and drawn portrait. Measured on the host engine; the device engines share the same image
generator path but were not measured. The guard tests make a regression fail the suite.

### W8 — Accepted divergences. The code is authoritative; recorded so nobody reopens them.

| Divergence | Why it stands |
|---|---|
| A 9:16 portrait floats with its height clamped to 1.6× its width. §3.4's failure list says "aspect past the clamp" stacks. | §5 `u9` gives the formula `photoH = min(photoW / aspect, 1.6 * photoW)` "so a portrait photo cannot become a wall", which clamps rather than stacks, and the shipped golden `note_float_*` set pins it. The stacked path applies the same clamp, so stacking would not show more of the photo. |
| `planFloat` adds a gate: a float must be at least one line tall. | A photo shorter than one line cannot have text beside it. It stacks, which is the single fallback. |
| Tilt is drawn by scaling the paper inside the reserved box rather than reserving `w + h·sin|θ|`. | `notePhotoFitScale` computes the rotated bounding box exactly and scales to fit it, shadow included. The wrap contour stays rectangular, which was the requirement. |
| Day detail keeps `shrinkWrap: true`. | A day holds a handful of entries, and the dialog sizes to its content. The Today feed is the lazy surface `u2` required. |
| The `TextCaptureRequest` branch of `JournalCaptureService` stays. | No UI reaches it since `u3`, but more than twenty capture tests exercise it. Removing it means deleting tests. |
| An ambiguous 12-hex prefix resolves to nothing. | 48 bits of prefix; insert-time extension already prevents a collision the app creates. |

**Dropped audit findings.** "The edit route's reindex is tested only with an empty list" is wrong:
`test/features/day_detail/day_detail_edit_note_test.dart:377-434` saves through the edit route against
a real database and asserts `[photoIdA, photoIdB]`, then `[photoIdB]`, then empty. "EXIF orientation is
never read" is not a defect, per W7.

### W9 — The benchmark measures photos.

- Number 3 becomes a photo line followed by one paragraph, rendered at the 560pt canonical measure
  through a real resolver, so `PhotoWrapBlock` performs the split. The run asserts the float happened.
- Number 4 renders its eight photo lines through a real resolver instead of `NotePhotoStub`.
- Number 1 uses the shipping `MarkdownStyleController` with a raised style limit instead of a copy.
- The results document's desktop baseline for numbers 3 and 4 is re-measured, and the "flag flip"
  sentence names the real seam.

---

## 3. The steps and how they ship

Eight Steps, six MSPs. One MSP is one branch and one pull request. Steps that share a file are one Lane
and run in order inside it; different MSPs share no file and build in parallel.

| MSP | Steps, in order | Branch | Tier |
|---|---|---|---|
| `note-drafts` | `draft-restore`, `composer-scrim-close` | `mitosis/note-drafts` | top |
| `note-preview` | `preview-first-photo` | `mitosis/note-preview` | top |
| `composer-photo-tools` | `short-screen-tools`, `photo-diagram-and-placement` | `mitosis/composer-photo-tools` | top |
| `corrupt-photo` | `corrupt-photo-fallback` | `mitosis/corrupt-photo` | top |
| `bench-photos` | `bench-real-photos` | `mitosis/bench-photos` | top |
| `note-guards` | `note-guards` | `mitosis/note-guards` | cheap |

No MSP depends on another, so the six pull requests can merge in any order.

### Coupling verdict

`mitosis --plan-only` (plan `7c38953529e5`) returned 6 Lanes, 6 MSPs, parallelism 6, no fused MSP and
no cycle. It named three pairs joined only by an import. Each is ruled independent:

| Pair | Import | Why neither needs the other's output |
|---|---|---|
| `preview-first-photo` + `photo-diagram-and-placement` | `note_preview.dart` imports `note_document.dart` | The preview changes which blocks reach `NoteDocument`; the placement Step changes how `NoteDocument` pairs an invalid photo. The preview's tests use valid placements only. |
| `short-screen-tools` + `bench-real-photos` | the sheet imports `MarkdownStyleController` | The controller gains one optional parameter with the current default; the sheet's two constructor calls compile and behave unchanged. |
| `photo-diagram-and-placement` + `corrupt-photo-fallback` | `note_document.dart` imports the float and stacked widgets | An invalid placement never reaches `PhotoWrapBlock`; the decode fallback lives inside it. Both add only optional parameters. |

### Tests that assert a defect

Each of these currently passes because it asserts the wrong behaviour. The Step that owns it rewrites
it **first**, watches it fail against the unfixed code, then fixes the code. This is the only case in
which an existing test's assertion may change, and each rewrite asserts the behaviour the parent spec
or §2 requires — never a weaker one.

| Test | Owner | Asserts today | Must assert |
|---|---|---|---|
| `test/features/capture/core/text_composer_test.dart` "a barrier tap no longer dismisses the composer" | `composer-scrim-close` | nothing happens on a dirty backdrop tap | the confirm appears and the note survives Keep editing |
| `test/features/capture/text/editor/format_bar_test.dart` "a panel too short for both yields the bar to the text" | `short-screen-tools` | no format bar at 844×390 with the keyboard up | the bar, and Undo, in the header row |
| `test/features/notes/photos/photo_rail_test.dart` "steps aside entirely when there is no room even for thumbnails" | `short-screen-tools` | no rail and no Add tile | a slim Add tile and no thumbnails |
| `test/features/notes/photos/photo_rail_test.dart` "is driven by the same planFloat the renderer calls" | `photo-diagram-and-placement` | a stacked plan for a photo followed by a paragraph | the floated plan and "text wraps beside it" |

`test/features/entry_cards/entry_card_test.dart` "preview:true bounds the note and offers Read more"
was weakened in `u7` when its photos were removed. It stays as it is, correct for a text-only note, and
`preview-first-photo` adds the photo case back as a new test.

---

## 4. Per-Step detail

The items file carries each Step's full brief. This section is the reviewer's summary.

### `draft-restore` — F1, F10

- `lib/data/drafts/draft_paths.dart`: `newNoteDraftKey(String date)` returns `new-$date` and throws
  `ArgumentError` unless `date` matches `^\d{4}-\d{2}-\d{2}$`. `isDraftKey` accepts a ULID-shaped key
  or `^new-\d{4}-\d{2}-\d{2}$`. The existing rejected list stays rejected.
- `lib/features/capture/text/text_composer.dart`: the draft key is `newNoteDraftKey(widget.date)`;
  the session id and its `newId()` import go.
- `lib/features/data/journal_delete_all_service.dart`: optional `Directory? draftsRoot`; after the
  media wipe, the drafts directory is deleted recursively when it exists.
- `lib/features/settings/settings_providers.dart` passes `mediaDraftsRootProvider`'s directory;
  `settings_providers.g.dart` is regenerated.
- Acceptance: a seeded `new-2026-07-19` draft is restored behind the chip when the composer opens for
  `2026-07-19`, and not for `2026-07-20`; the save hands `draftKey: 'new-2026-07-19'` to the writer; a
  new-note key is a valid draft key; delete all removes every draft file.
- Added after review: `NoteDraftController` seals on `discard()` and on `seal()`, which both connectors
  await after a successful save; a sealed controller ignores edits and lifecycle flushes. Regression
  tests cover Discard and save on the new-note route and save on the edit route, each followed by the
  app going inactive mid-close.

### `composer-scrim-close` — F9

- `ComposerShell` gains `closeOnScrimTap` (default `false`). When true, a tap on the scrim calls
  `Navigator.maybePop(context)`, which the composer's `PopScope(canPop: false)` routes into
  `ComposerGuard`'s close request.
- `showTextComposer` and `showEditNote` pass `closeOnScrimTap: true`. `barrierDismissible` stays
  `false`.
- Acceptance: dirty backdrop tap shows the confirm and Keep editing preserves the text, on both routes;
  a clean backdrop tap closes the new-note composer with a null result.

### `preview-first-photo` — F2, F8

- `notePreviewOf` keeps its signature and becomes block-based per W4.
- `NotePreview` keeps its two render paths: the whole note when nothing was dropped, the faded prefix
  with Read more otherwise.
- Acceptance: a short note with three photo lines previews exactly one photo, the first, and offers Read
  more; a limit falling inside a photo line never leaves a partial photo token; the card renders one
  `NotePhotoFigure` in preview and three in the full view.

### `short-screen-tools` — F4, F5

- `text_composer_sheet.dart` implements W3's placement rule and wraps the rail builder's output in a
  `KeyedSubtree` with a `GlobalKey` so the rail's State survives the move.
- `format_bar.dart`: the six toggles sit in a horizontally scrolling region; trailing slot and Undo are
  always visible.
- `photo_rail.dart`: below the compact height the rail renders the slim Add tile (36×36, same key, same
  label, same focus node, same pick path); pick errors in slim mode use `showTransientToast`.
- Acceptance: at 844×390 with a 200pt keyboard the bar and Undo sit in the header row and the editor
  keeps three lines; the rail at `photoRailCompactHeight - 1` shows the slim Add tile and no thumbnail;
  the connected composer shows Add photo on that surface; a pick started from the slim tile lands after
  the panel grows; the shared constants agree.

### `photo-diagram-and-placement` — F3, F6

- `PhotoPlacement` gains `isValid` per W5 and loses `extras`. `copyWith` returns a valid placement.
- `NotePhotoLine` gains `wrapsParagraph`, set by `notePhotoLines` from the parsed blocks.
- `photoPlanFor` passes `nextIsParagraph: line.wrapsParagraph && line.placement.isValid`.
- `noteBlockRuns` pairs a photo with the next paragraph only when its placement is valid.
- The diagram re-plans when the photo's media resolves after the diagram was first built.
- Acceptance: the rewritten rail diagram test; the options sheet floats a paragraph-followed photo at a
  floating measure; placement validity cases; an invalid placement stacks in `NoteDocument` although a
  paragraph follows; a UI side edit on an invalid placement writes a valid one.

### `corrupt-photo-fallback` — F7

- `MediaImage` gains `onDecodeError`, invoked after the frame in which its `errorBuilder` ran.
- `NotePhotoFigure` forwards it. `PhotoWrapBlock` sets a failed flag and rebuilds as `_stacked`,
  resetting the flag when the photo's reference changes.
- Acceptance: a float whose file holds undecodable bytes renders `StackedPhoto` and no float once the
  decode fails; `MediaImage` reports the failure through the callback.

### `bench-real-photos` — F11, F12

- `MarkdownStyleController` gains `styleLimit` (default `liveStyleLimit`) on both constructors, and
  the length assert runs on every return path.
- The bench deletes `ForcedLiveStyleController`, uses the shipping controller for number 1, and
  renders numbers 3 and 4 through a pre-resolved `MediaStoreResolver`.
- The results document is corrected and its numbers 3 and 4 re-measured headless.
- Acceptance: a raised `styleLimit` live-styles a buffer longer than `liveStyleLimit`.

### `note-guards` — F13, F14, F15

- `goldens.yml` adds the five directories the float goldens render from.
- A static test pins that workflow's paths. A static test pins that only the Reclaim space controller
  calls `collectGarbage` in `lib/`. Two fixture tests pin EXIF orientation through
  `readPhotoIntrinsics` and `downscalePhoto`.
- Acceptance: the workflow-paths test. The GC and orientation tests are guards over code this Step does
  not change, so the gate reports them not applicable by design.

---

## 5. Verification

**The local suite is the gate. CI is never evidence** — no GitHub check runs a Dart test here except
the goldens job.

1. **Per Step, by the Worker:** the named acceptance tests red before the fix and green after,
   `flutter analyze` clean, full `flutter test` green.
2. **Per MSP, by mitosis:** each acceptance property run with the work present and again with the
   implementation reverted. Only `pass` — fails without the work — proves the property.
3. **Per branch, by the dispatching session:** `flutter pub get`, `flutter analyze`, `flutter test`,
   `flutter test --tags golden`, run in the foreground on the branch itself and read.
4. **Together:** all six branches merged into a throwaway local branch, the same suite run once more,
   `flutter build macos --debug` built, and `integration_test/note_perf_bench_test.dart` run headless.
5. **Review:** each diff reviewed by an agent that did not write it before its pull request opens.

Never `flutter test integration_test/` as a directory. `capture_save_persist_test.dart` writes into the
real journal container.

---

## 6. After this wave — owed by a person

1. **Delete the old test notes.** Settings → Data → Delete all. With `draft-restore` merged this
   also removes leftover drafts.
2. **See it on macOS.** `flutter run -d macos` from a terminal.
3. **Run the Android benchmark** on a mid-range phone: `scripts/android-bench.sh`, then record the
   figures in `docs/specs/research/2026-09-20-android-measurement.md` §5.
4. **Decide `u10`** from keystroke numbers 1 and 2, mechanically, per that document's §6.
5. **See it on Android.**

---

## 7. Out of scope

Everything the parent spec's §8 excludes, plus: the `u10` segment editor; any change to how a photo is
stored, hashed or garbage-collected; the voice and video composers; any new package; any schema change.
