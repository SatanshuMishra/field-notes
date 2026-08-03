# Rich Markdown Editor, then Inline Anchored Photos — Combined Implementation Spec

Thread: logbook `01KZ33PK4E5RN3G6MD458S2N5D` (`inline-photo-notes`)
Binding decisions: `.claude/ledger/decisions/2026-08-02-markdown-source-of-truth-editor.md` (the substrate),
`.claude/ledger/decisions/2026-08-02-oq6-inline-anchored-photo-model.md` (the photo model)
Sibling spec, amended not replaced: `docs/specs/2026-08-02-inline-photo-notes.md` (P0–P5, 1228 lines)
Audits, read not re-derived: `docs/specs/research/2026-08-02-editor-audit-app.md`,
`-editor-audit-prototype.md`, `-editor-research-packages.md`, `-editor-research-substrate.md`
Base: `inline-photo/spec` at `92dfb7c`, three docs-only commits ahead of `origin/main` at `712c978`
Phases: **E0–E7** (editor) then **P0–P5** (photos) — fourteen MSPs, fourteen PRs

---

## 0. What this document is

The user's directive: **one spec covering the rich markdown editor and OQ-6, editor strictly first.**
This is that spec. It is deliberately **not** a rewrite of the 1228-line P0–P5 document.

*Why by amendment and not by merge.* That document's value is its 28 primitive resolutions and its
twelve hull points — work that took a full session to derive. Copying 1228 lines into a second file
creates two authorities for one subsystem and guarantees drift, which is the exact failure this
project has already been bitten by five times (§10). **§5 below amends it by resolution number.** An
implementer reads this document first, then the amended resolutions in the sibling.

### 0.1 Citation provenance — read this before adopting any value

This project's spec family has cited wrong line numbers **five times**. Two classes of citation appear
below and they are **not equally trustworthy**:

| Marking | Meaning | Implementer's duty |
|---|---|---|
| `[verified]` | Re-opened from the repo while composing **this** document, at `92dfb7c` | Confirm on your own base; low risk |
| `[audit]` | From the four 2026-08-02 audits, verified at their composition time | Re-open before adopting |
| `[inherited]` | Carried from the P0–P5 spec, which was **never critic-hardened** | **Treat as unverified. Re-open every one.** |

Nothing in this document is `[verified]` unless it says so. Three things are:

- `lib/features/entry_cards/cards/note_body.dart` is **25 lines**, takes `text` as its only field, and
  returns a plain `Text(text, style: TypographyTokens.bodySerif, softWrap: true, overflow: clip)` with an
  `'Empty note'` italic branch at `:12-17`. `[verified]`
- `text_composer_sheet.dart:293-304` is a raw `EditableText` — not a `TextField` — bound to a plain
  `TextEditingController` constructed at `:75` and declared `late final` at `:66`, also consumed by a
  `ValueListenableBuilder` at **`:276`**. `[verified]`
- `docs/specs/2026-08-02-inline-photo-notes.md` is 1228 lines and its own §7 states every citation in it
  was re-opened at `712c978` — a claim made by an unhardened document about itself. `[verified]` that the
  claim exists; the claim itself is `[inherited]`.

### 0.2 CITATION PROOF — RUN 2026-08-03, 28 anchors, 25 clean, 3 drifts

The pass this spec's own §11 flagged as never-returned has now run against the repo at `c573010`.
**Every in-repo anchor in both specs' load-bearing set was re-opened.** Result: **25 OK, 3 DRIFT, 0 ABSENT.**
**No drift changes a design decision.** All three are corrected below and in place.

| # | Drift | Corrected to | Severity |
|---|---|---|---|
| 1 | `text_composer_sheet.dart:277` for the `ValueListenableBuilder` — **a claim this document marked `[verified]`** | **`:276`**; `:277` is its first named argument | off-by-one; **fixed above** |
| 2 | `app_database_test.dart:27-31 and :98-127` cited as jointly pinning the migration refusal | **`:27-31` pins `schemaVersion == 1`, NOT the refusal.** Only **`:98-128`** pins the `onUpgrade` throw | **material** — see below |
| 3 | `photo_tray_test.dart:123` cited as the cap assertion | **`:123` is the test's NAME string.** The cap assertions are **`:143-145`** (`findsNWidgets(2)`, `hasLength(2)`, Add button `isEnabled` false), with `maxPhotos: 2` passed at `:137` | **material** — see below |

**Drift 2 is the one that matters, and it lives in the migration landmine — the most dangerous claim in
either document.** `:27-31` asserts a fresh database reports version 1; it does **not** pin the refusal.
**The refusal is pinned by `:98-128` alone**, and the whole no-migration doctrine rests on that one case.

*Where it actually lived, corrected from the first reading.* The wrong anchor originated in
`docs/specs/research/2026-08-02-editor-audit-app.md`, which cited `:27-31 and :98-127`. **The sibling's
M1/R1 never carried the wrong number — they named the test file with NO line anchor at all**, and that
vagueness is what let the bad anchor propagate unchallenged. Both are now fixed: the audit's joint
citation is corrected, and M1/R1 gained the precise `:98-128` anchor they lacked. **The OQ-6 decision
record still reads `:97-128` and is deliberately NOT edited** — decision records are write-once after
acceptance (`continuity-ledger.md`), so the correction lives here and in the specs, not in the record.

**Drift 3 strands an implementer looking for the cap.** The sibling's M5 and R5 sent them to a test name.
**Both now cite `:143-145`**, with `maxPhotos: 2` at `:137`.

**All four amendments are applied. This section is a record, not a worklist.**

**Two precision notes, non-material.** `search_day_view.dart:63-98` is really `_previewFor` at `:63-74`
and `_searchTextFor` at `:76-89`; the cited range also spans an unmentioned `_firstLine` at `:91-98` —
D6 concerns `_searchTextFor` specifically, so cite `:76-89`. And `media_gc.dart:139-144` overruns by one
line; the statement ends at `:143`.

**Everything else held**, including every negative claim the design depends on: **zero** markdown,
`RichText`, `TextSpan(`, `WidgetSpan(` or `buildTextSpan` anywhere in `lib/` or `pubspec.yaml`; **zero**
external importers of `PhotoTray`, its barrel, or `photoPickerProvider`; `lib/design/layout/` and
`lib/design/markdown/` both absent; no golden renders note text or the composer (six families, none
touching `NoteBody`, `TextComposerSheet` or `InlinePhotoStrip`); and `note_body_test.dart` (2 cases) and
`entry_card_test.dart` both match with literal `find.text(...)`, confirming E1's declared retarget is real
and bounded.

**Consequence for §0.1's provenance table:** the `[audit]` tier is now **proven** for the 28 anchors above.
Every `[inherited]` citation OUTSIDE that set remains unverified — the sibling has ~60 more.

---

## 1. BLUF

The note composer is a raw `EditableText` over a plain `TextEditingController`, and **zero markdown
parsing exists anywhere in `lib/`** `[audit]`. `NoteBody` renders that string literally, so a `#` shows
as a `#`. Separately, no UI has ever populated `CaptureRequest.photos`, so a photo cannot be attached to
a note at all.

**E0–E7** make the note a live rich markdown document whose stored form is raw markdown — no schema
change, no transcode, no dependency. **P0–P5** then anchor photos at positions inside that text.

**The editor is strictly first, and the reason is structural, not preference.** OQ-6 needs a custom
`TextEditingController.buildTextSpan` to render its U+FFFC sentinel as a `WidgetSpan`
(`inline-photo-notes.md:176` `[inherited]`). The editor needs a custom `buildTextSpan` to render markdown
live. **There is exactly one `buildTextSpan` per controller.** Building them in the other order means
writing that override twice and merging it once — the substrate decision's stated reason for the ordering,
and it holds.

---

## 2. THE VERDICT ON flutter/flutter#82595 — P0–P5 SURVIVES

The thread's standing question was whether the no-wrap limit kills the photo ladder. **It does not. No
phase is abandoned and no phase changes its outcome.** The reasoning, stated once:

[flutter/flutter#82595](https://github.com/flutter/flutter/issues/82595), open since 2021: a `WidgetSpan`
inside an **`EditableText`** is an unbreakable block that cannot participate in line-wrap `[audit]`. The
constraint is scoped to editable text. The float and wrap in P3–P5 do **not** live in editable text:

| Surface | Widget | Wrap legal? |
|---|---|---|
| Write mode | `EditableText` | **No** — #82595. Already excluded by OQ-6's decision ("write mode is plain editable text") and by the sibling's R22/M3 `[inherited]` |
| Read view | `NoteBody`, a `Text`/`Text.rich` | **Yes — but not by wrapping around a span at all.** See the sharpening below. This is where R15/R18's float lives |
| Arrange mode | read-only float renderer + handles (R22) | **Yes** — R22 already forbids arrange mode from mounting an `EditableText` |

**The sharpening, and it closes a hole a reviewer correctly found in the first draft.** #82595's actual
title is *"Feature Request: Implement InlineSpan for TextFields"* and its text is scoped to a `WidgetSpan`
inside a `TextField`. It does **not** state that a non-editable `Text`/`RichText` can wrap around an inline
span, and the first draft's reasoning leaned on that inference. **The verdict does not need it.** R15's
float never puts the card in a span tree at any layer: it is `LayoutBuilder` + `Stack` + **two separate
`Text` widgets**, with the paragraph split manually at an offset `TextPainter` computes `[inherited]`. No
widget is ever asked to flow text around an inline object. The exclusion is achieved by *laying out two
paragraphs at two widths in two positions* — which is why R15 rejects a custom `RenderBox` and why the
whole approach sidesteps #82595 rather than depending on how far it reaches.

**Consequence for implementers:** do not "simplify" R15 by putting the photo in a `WidgetSpan` inside a
single `Text.rich` and expecting the text to flow around it. That is the one thing #82595 guarantees will
not work, and it is the obvious-looking shortcut. **Stop and report if the split appears unnecessary.**

So #82595 **sharpens and does not contradict** the model, exactly as the substrate decision predicted.
The one place it bites is a place the ladder already forbade itself from going.

**What the editor changes is different, and it is real.** After E1, `NoteBody` is no longer a plain
`Text` over a `String` — it is a span tree. R15 and R18 assume `String` + one `TextStyle`. That is the
genuine collision, and §5 resolves it.

**Say this out loud before starting P3**, replacing the sibling's now-answered gate language: *P0's spike
still gates P3, but #82595 is not the thing that would kill it. The gate is whether the exclusion box
holds against real glyph boxes.*

---

## 3. Architecture — one grammar, two renderers, one controller

The single most important structural fact, and it is not in any audit:

> **The editor may not delete a markdown marker. The read view must.**

`buildTextSpan`'s output must match `controller.text` character for character — enforced structurally,
because `RenderEditable` treats `selection.baseOffset` as a direct index into the text the `TextPainter`
laid out, and confirmed verbatim by a Flutter text-input maintainer on #159171 `[audit]`. A `#` in the
editor can be styled to near-invisibility but never removed.

`NoteBody` has **no controller and no caret**. Nothing constrains its span tree to the source string.
It can and must delete the `#` outright — "present but nearly invisible" is a compromise the editor is
forced into, not a look worth porting to the read view.

Therefore: **one parser, two renderers.**

```
lib/design/markdown/
  markdown_grammar.dart     the 12-feature token model, pure Dart, zero Flutter widgets
  markdown_parse.dart       String -> List<MarkdownBlock>, offsets preserved into the source
  markdown_editor_spans.dart  blocks -> InlineSpan, plain text == source, char for char
  markdown_read_spans.dart    blocks -> InlineSpan, markers removed, free to restructure
  markdown_plain_text.dart    blocks -> String, for preview extraction
  markdown.dart               barrel (one-barrel-per-subdirectory, Cluster G R10 precedent [inherited])
```

`markdown_plain_text.dart` is not optional garnish. Two sites consume `entry.textContent` raw and bypass
`NoteBody` entirely — `firstTextPreview` (`today_memory.dart:57-73`) and `_previewFor`/`_searchTextFor`
(`search_day_view.dart:63-98`) `[audit]`. Without it, markdown punctuation leaks into the On This Day
card and every search result.

### 3.1 THE GRAMMAR — enumerated, because E0 cannot express its gate without it

The first draft said "the 12 grammar features" and named no list, leaving the one phase that can falsify
the substrate unable to state its own acceptance criterion. **This table is the definition. E0's criteria
1–3 run once per row.**

| # | Feature | Markdown source | Renders in | Block/inline |
|---|---|---|---|---|
| 1 | h1 | `# ` | E1 read, E3 editor | block |
| 2 | h2 | `## ` | E1 read, E3 editor | block |
| 3 | h3 | `### ` | E1 read, E3 editor | block |
| 4 | bullet | `- ` / `* ` / `+ ` | E1 read, E3 editor | block |
| 5 | ordered | `1. ` (any `\d+.`) | E1 read, E3 editor | block |
| 6 | quote | `> ` | E1 read, E3 editor | block |
| 7 | to-do | `[] ` / `[ ] ` / `[x] ` | E1 read, E3 editor | block |
| 8 | divider | `---` / `***` | E1 read, E3 editor | block |
| 9 | bold | `**text**` | E1 read, E2 editor | inline |
| 10 | italic | `*text*` | E1 read, E2 editor | inline |
| 11 | inline code | `` `text` `` | E1 read, E2 editor | inline |
| 12 | highlight | `==text==` | E1 read, E2 editor | inline |

**Twelve. UNDERLINE IS DROPPED — resolved by the user 2026-08-03. It is not an oversight.**
The prototype's U button is `document.execCommand('underline')` producing a `<u>` tag `[audit]`, and
**standard markdown has no underline syntax.** In a markdown-source-of-truth buffer that button has
nothing to write.

*Rejected: inventing `__text__`.* CommonMark assigns it to strong, so every other reader renders it bold —
silent corruption, the worst of the three outcomes.
*Rejected: raw inline HTML `<u>`.* Widens the grammar to arbitrary HTML for one control.

Both break the portability that is the entire reason this substrate was chosen over three editor packages:
the export round-trips `textContent` verbatim `[audit]`, and a note must stay readable markdown outside
this app.

**Consequence: E5 ships FOUR toolbar buttons — B, I, `<>`, ◆ — not five, and diverges from the prototype
by exactly one control. That divergence is intended.** *Adopt the prototype's form, never its promises* is
this project's own standing rule (`decisions/2026-07-27-prototype-alignment-open-questions.md`
`[inherited]`); a U button that cannot persist what it claims to do is a promise the storage cannot keep.

**Row 12 (`==highlight==`) STAYS, and the asymmetry is deliberate.** It is not CommonMark either, but it
has a real, widely-adopted syntax that **degrades gracefully** — another reader shows `==text==` as
literal visible characters, so the content survives and only the emphasis is lost. Underline has no
representation at all, so its choice was between silent corruption and dropping it. Different failure
modes, different calls.

### 3.2 FILE FENCES — every E phase, because mitosis cannot dispatch without them

The first draft fenced only E0. The sibling carries a hard scope fence for exactly the reason this project
keeps relearning: an implementer meeting an unfenced file makes a judgement call and a feature is lost.

| Phase | May edit | New? |
|---|---|---|
| E0 | `test/features/entry_cards/markdown/**` only | new |
| E1 | `lib/design/markdown/**` (from E0), `lib/features/entry_cards/cards/note_body.dart`, `cards/note_blocks.dart`, `lib/features/today/today_memory.dart`, `lib/features/search/search_day_view.dart`, and the four test files those red | mixed |
| E2 | `lib/features/capture/text/markdown_note_controller.dart`, `text_composer_sheet.dart` (controller swap only) | mixed |
| E3 | `lib/design/markdown/markdown_editor_spans.dart`, `markdown_note_controller.dart` | no |
| E4 | `markdown_note_controller.dart`, `lib/features/capture/text/markdown_transforms.dart` | mixed |
| E5 | `text_composer_sheet.dart` (`contextMenuBuilder` only), `lib/features/capture/text/markdown_toolbar.dart` | mixed |
| E6 | `lib/features/capture/text/markdown_line_metrics_overlay.dart`, `text_composer_sheet.dart` | mixed |
| E7 | `markdown_line_metrics_overlay.dart`, `markdown_note_controller.dart` | no |

**Named traps — out of bounds in EVERY E phase, each a file a reasonable implementer might otherwise open:**

- `lib/data/database/**` — **NEVER.** M1. Markdown needs no schema change; `textContent` already holds it.
- `lib/features/entry_cards/playback/**`, `cards/video_*`, `cards/voice_*` — N24's protected suite. Untouched by path disjointness; a diff reaching one **is** the signal the fence broke.
- `lib/features/entry_cards/cards/photo_strip.dart` — M6, the permanent degrade target for the photo ladder.
- `lib/features/capture/photo/**` — read-only in every phase of both ladders.
- `lib/design/widgets/sticker_card.dart` — 16 call sites plus A4's contract; Cluster G's R1 precedent.
- `lib/features/day_detail/day_detail_edit_note.dart` — **the gap the critique found.** `EditNoteConnector` mounts the same `TextComposerSheet` E2 modifies. E2 changes the controller for BOTH connectors, which is intended — the edit path should render markdown too — but it is **declared here**, not discovered. Its tests must pass unmodified.
- `pubspec.yaml` — N4/M10. No phase adds a dependency.

**The controller is ONE class**, `MarkdownNoteController extends TextEditingController`, living at
`lib/features/capture/text/markdown_note_controller.dart`. E2 creates it. P2 **grows** it with the anchor
bookkeeping the sibling's R9/R11 specify — it does **not** create a second
`PhotoAnchorTextEditingController`. **The sibling's file `lib/features/capture/text/photo_anchor_controller.dart` is
deleted from its fence by this document (§5, A4).**

---

## 4. Non-negotiables

M1–M10 of the sibling spec (`inline-photo-notes.md:754-765` `[inherited]`) bind every phase here
unchanged — above all **M1, no schema migration ever**, and **M10, no new dependency**. Markdown source
needs neither: `Entries.textContent` is already an unconstrained nullable `TextColumn`
(`tables.dart:23`) `[audit]`, so markdown is a convention inside an existing string.

Six more bind the editor specifically:

| # | Constraint | Source |
|---|---|---|
| **N1** | **`buildTextSpan`'s plain text equals `controller.text`, char for char, always.** Markers are hidden by style; never deleted, never substituted, never reordered. **This contract is UNDOCUMENTED** — api.flutter.dev says only *"Builds TextSpan from current editing value."* It is enforced structurally, by `RenderEditable` indexing selection offsets straight into the laid-out text, and by a maintainer statement on #159171. Treat it as load-bearing but unguaranteed: E0's criterion 1 is the only thing that will catch a violation | maintainer statement + framework source `[audit]`; doc absence verified 2026-08-03 |
| **N2** | **Every programmatic mutation of the buffer is gated on `value.composing.isCollapsed`.** No exceptions, including Enter-continues-list and auto-renumber | Flutter's own `TextInputFormatter` docs, quoted verbatim in the substrate audit `[audit]` |
| **N3** | **No `TapGestureRecognizer` in the span tree.** flutter#187598, reproduced on 3.44.1, throws `'readOnly && !obscureText'` on iOS. Tappable anything is a hit-tested overlay | `[audit]` |
| **N4** | **No editor package.** super_editor, flutter_quill, appflowy_editor, re_editor and flutter_markdown are all rejected on named constraints | substrate decision, Consequences |
| **N5** | **The prototype's photo-destroying re-edit is an explicit NON-GOAL.** Reopening a note there sets `n.photos = undefined` on save — permanent data loss, a code-provable bug | prototype audit `[audit]` |
| **N6** | **The read view renders rich. The prototype's does not.** Its read-only surface shows flattened plain text and `e.html` is referenced by no template. Being better than the prototype here is correct, not a deviation | prototype audit `[audit]` |

---

## 5. Amendments to the P0–P5 spec

Each amendment names a resolution in `docs/specs/2026-08-02-inline-photo-notes.md` and states what
changes. **Every resolution not named here stands unchanged.**

**A1 — R15 and R18 take an `InlineSpan`, not a `String` + `TextStyle`.** *This is the load-bearing one.*
After E1, `NoteBody` renders a span tree, so `splitForFloat({required String text, required TextStyle
style, ...})` cannot express the paragraph it must split. New signature:

```dart
InlinePhotoSplit splitForFloat({
  required InlineSpan span,          // was: String text + TextStyle style
  required double columnWidth,
  required Rect exclusion,
  required TextDirection direction,
  required TextScaler scaler,
});
```

`TextPainter` accepts a `TextSpan` tree natively, so R18's probe, its `computeLineMetrics()` walk and its
`getLineBoundary` snap all survive verbatim. **What does not survive is `text.substring(0, splitOffset)`.**
Splitting a span tree at a plain-text offset is strictly harder than splitting a string and needs its own
helper, `splitSpanAt(InlineSpan, int offset) -> (InlineSpan before, InlineSpan after)`, which must
preserve every enclosing style across the cut. It lives beside the split in `lib/design/layout/` and is
**P3's** work. R15's two `Text` widgets become `Text.rich`. The `Stack`, the `LayoutBuilder` and the
no-custom-`RenderBox` ruling are all unaffected.

**A2 — R8 gains one rule: U+FFFC is opaque to the parser.** A sentinel may now sit inside `**bold**` or
on a `# heading` line. The parser treats U+FFFC as an ordinary content character that **never** opens,
closes or splits a marker run, and **never** itself becomes a marker. Its offset is preserved through
parse exactly as any other character is (N1 already requires this of the editor renderer; A2 extends it
to the read renderer, where markers *are* deleted and the sentinel must survive that deletion with its
document order intact).

**A3 — R7's `stripPhotoAnchors` and the read-view parse compose in ONE pass, in a stated order.** Both
mutate what is rendered. Anchor-stripping runs **first**, on the raw source, producing the string the
parser consumes. Running the parser first would delete markers and shift every sentinel offset, silently
rebinding photos to the wrong anchors. E1 ships this ordering as a comment-free single call path in
`NoteBody`; P1's stripper slots into it. Stated so no implementer discovers it by debugging a rebound photo.

**A4 — There is no `PhotoAnchorTextEditingController`.** Delete
`lib/features/capture/text/photo_anchor_controller.dart` from the sibling's fence (`:616`) and from P2's
file list (`:890`). P2 instead **grows** `MarkdownNoteController` (§3) with R9's `WidgetSpan` substitution
and R11's prefix/suffix delta. R11's delta rule is unchanged and is now **more** load-bearing, because the
editor's own transforms (E4) also mutate the buffer programmatically and must not be mistaken for user
edits — see A6.

**A5 — R20's 200-line split threshold will be crossed, and that is expected.** `NoteBody` is 25 lines
today `[verified]`. E1 alone takes it past that. The block-assembly loop moves to
`lib/features/entry_cards/cards/note_blocks.dart` **in E1**, not deferred to P2 as R20 assumes.

**A6 — R11's delta rule must distinguish user edits from E4's transforms.** A type-to-transform that
rewrites `# ` styling, renumbers a list, or continues a bullet is a programmatic contiguous replacement
that R11's prefix/suffix scan will happily interpret as a user deleting an anchor. `MarkdownNoteController`
sets an `_applyingTransform` latch around every E4 mutation; R11's bookkeeping shifts offsets but performs
**no** unanchoring while the latch is set. **Receipt:** a P2 case that types `# ` at the head of a line
containing an anchor and asserts the anchor is still bound.

**A7 — §5.3's absolute test totals are void; its deltas stand.** The sibling predicts P0 → 951 … P5 → 981
from a 944 baseline. E0–E7 land first, so every absolute is wrong. The **per-phase deltas** are unaffected.
Re-measure the baseline on your own branch — the recorded figure has gone stale three times `[inherited]`.

**A8 — R0 is spent.** It says the OQ-6 decision record is not on `main` and every dispatch must carry it
inline. Both records and the thread now live on `inline-photo/spec` at `92dfb7c` `[verified]`, which is
this ladder's base. R0's dispatch hazard evaporates once that branch merges; until then, name the branch.

---

**A9 — P0 writes the `InlineSpan` signature from the start, and therefore depends on E0.** *This
supersedes §7's "P0 may run at any time" and is the second blocking defect the hardening pass found.*
A1 retypes `splitForFloat` to take an `InlineSpan`. P0 authors that function in the test tree and R4 has
P3 promote it **byte-identical**, with P3's must-not-regress clause reading "P0's seven cases pass
unmodified". Those two facts are incompatible with A1 unless P0 writes the final signature. So:

- **P0 writes `splitForFloat({required InlineSpan span, ...})`.** Never the `String` + `TextStyle` form.
- **P0 gains one dependency: E0 must be MERGED** (not merely green), because P0's criteria 5 and 6 must
  build a probe span, and the span model lives in E0's grammar files.
- P0's criteria 5 and 6 are rewritten to construct their probe as a `TextSpan` tree rather than a `String`.
- P0 stays independent of E1–E7 and of P1. It is no longer independent of E0.

*Rejected: P0 writes the `String` form and P3 converts it.* That makes R4's byte-identical promotion and
P3's regression clause false on the day A1 lands, and buries the conversion in the ladder's biggest phase.

**A10 — Reverts run TOP-DOWN across BOTH ladders, and one pairing is a build break.** The sibling states a
revert law scoped to P2/P4/P5 only. Combined, there is a cross-ladder edge: **A4 has P2 grow the class E2
creates.** Reverting E2 while P2 is merged does not degrade — it **fails to compile**. Law: `E2 may not be
reverted while P2 is merged.` More generally, revert order is the exact reverse of merge order across the
union of both ladders, never per-ladder.

**A11 — A5 also voids R20's filename, R20's receipt, and two rows of §5.6.** A5 moves the block loop into
E1. Consequently: R20's `inline_photo_blocks.dart` becomes `note_blocks.dart`; **R20's receipt
("`note_body_test.dart`'s two existing cases pass unmodified") is void** — E1 retargets that file by
mandate; and §5.6's "Verified NOT red — do not touch" rows for `note_body_test.dart` and
`entry_card_test.dart:55` are void for E1 and stand for every P phase. A P2 implementer reading R20 must
not find a receipt that E1 already broke with no note.

**A12 — A8 is WRONG: R0 is still live.** A8 claimed R0 spent because the decision records are on
`inline-photo/spec`. But E0, E1 and P0/P1 all base on `main`, and `inline-photo/spec` has **not merged** —
so an implementer branching from `main` still cannot read either decision record **or this spec**. **R0
stands until `inline-photo/spec` merges.** Every dispatch names the branch or quotes the records inline.
This is the same defect R0 was written to catch, recurring one branch later.

---

## 5.1 EDITOR RESOLUTIONS D1–D8 — the hardening worklist, closed 2026-08-03

Where §5's A-amendments amend the sibling's resolutions, these decide the editor ladder's own open
questions. Each was found by the 2026-08-03 hardening pass, accepted as real, and is resolved here so no
implementer meets it mid-flight. **§11 is now closed.**

**D1 — The emptiness predicate is `plainText(parse(stripPhotoAnchors(text))).trim().isEmpty`, and it has
TWO consumers.** *(closes H1 and H2 together — they are one defect seen from two ends.)*

`note_body.dart:12` guards on `text.trim().isEmpty` `[verified]`. After E1, `'# '`, `'---'` and `'**'` are
non-blank strings that parse to an **empty span tree** — a card rendering nothing, with no `'Empty note'`
affordance. The same string saved through the composer produces an entry that renders as nothing, because
`text_composer_sheet.dart:186`'s guard is also `text.trim().isEmpty` `[audit]`.

*Resolution.* One predicate, exported from `lib/design/markdown/markdown_plain_text.dart` as
`bool rendersEmpty(String rawText)`, applied at **both** sites:

- **E1** applies it in `NoteBody`, replacing the raw `text.trim().isEmpty` guard. Order is A3's:
  strip anchors, then parse, then test. **Receipt:** `NoteBody(text: '# ')` renders the `'Empty note'`
  affordance; `NoteBody(text: '# ￼')` does too.
- **E3** applies it in the composer's save guard, the phase that first makes marker-only text typeable.
  **Receipt:** saving `'---'` does not write an entry.

This supersedes H2's "assign to E3 **or** exclude in §9" — excluding it would ship a save path that
creates invisible entries. **M7's deferred `&& photos.isEmpty` clause is untouched and stays deferred.**

**D2 — `markdown_line_metrics_overlay.dart` owns the `computeLineMetrics` machinery, and E6's drift
criteria MOVE to E7 if E6 is dropped.** *(closes H3.)*

E6 and E7 are both droppable and E7 needs E6's machinery (§6). "Say so in its PR" was not an obligation an
implementer could execute. *Resolution:* the file is named above and is created by whichever of E6/E7
ships first. **If E6 is dropped, E7 inherits E6's three drift criteria verbatim — resize, accessibility
text-scale, and mid-scroll — and E7's predicted delta becomes +6, not +3.** State the inheritance in E7's
PR body. Dropping E6 does not drop its risk; it relocates it.

**D3 — An anchor inside a transform's replaced range keeps its offset relative to the replacement's
start.** *(closes H4.)*

A6 removed R11's middle-bucket unanchoring while `_applyingTransform` is set, but never said what offset
the anchor then takes — undefined for exactly A6's own receipt (typing `# ` at the head of a line whose
anchor is at offset 0). *Resolution:* under the latch, for an anchor at old offset `o` in `[start, oldEnd)`,
the new offset is `start + (o - start)` clamped to `[start, newEnd)` — the anchor rides the replacement
rather than being consumed by it. Outside the latch, R11's original rule stands unchanged: an anchor in
that range is **removed** and its photo unanchors. **Receipt:** A6's case, extended to assert the anchor's
resulting offset, not merely that it is still bound.

**D4 — Accessibility obligations, named per phase.** *(closes M1(a) — the lowest-detection-probability
class in this spec.)*

- **E1** — `Text` → `Text.rich` drops heading structure. Headings carry `Semantics(header: true)`.
- **E2** — hidden markers are suppressed from the semantics tree (already named in §6; restated here as a
  per-phase obligation rather than prose).
- **E3** — the to-do glyph carries `Semantics(checked:)` reflecting `[ ]` vs `[x]`, even though E3's
  checkbox is inert.
- **E5** — all four toolbar buttons carry semantic labels.

Each is one receipt in its own phase. **None will surface in visual QA**, which is why they are pinned
here rather than left to review.

**D5 — R10's traversal matrix gains marker-surrounded rows.** *(closes M2.)*

R10's six cases use the plain buffer `'ab￼cd'` `[inherited]`. A2 newly permits a sentinel inside a marker
run, and nothing measures it. *Resolution:* **P2's matrix grows from six cases to ten** — the existing six,
plus `'**ab￼cd**'` (inline run) and `'# ab￼cd'` (block line), each under `TargetPlatform.macOS` and
`TargetPlatform.iOS`. P2's predicted delta becomes **+15, not +11**. This is a genuine amendment to the
sibling's R10 and A7 already voids its absolute totals.

**D6 — Search MATCH semantics change deliberately, and are stated.** *(closes M3.)*

`_searchTextFor` (`search_day_view.dart:76-89` `[audit]`) is the **match index**, not a preview. Routing it
through `plainText` (§3) means a query spanning a marker starts matching, and a query containing a literal
`#` or `*` stops matching the marker. *Resolution:* **that is the intended behaviour** — a user searching
their own words should match the words, not the punctuation the editor inserted on their behalf. **Receipt
in E1:** a note stored as `'a **bold** word'` matches the query `'bold word'`, and does **not** match
`'**bold**'`.

**D7 — §2's "no phase changes its outcome" is overstated; P3's scope grows.** *(closes M1(b).)*

The verdict that P0–P5 survives #82595 stands. But A1 gives P3 a new algorithm (`splitSpanAt`) that is
unspiked, and D5 grows P2's matrix. **Correct statement: no phase is abandoned and no phase's OUTCOME
changes; P2 and P3 both gain scope.** §10.4's flag on `splitSpanAt` stands and is the one to watch.

**D8 — E5 ships four buttons.** *(closes M4.)* Resolved in §3.1: underline is dropped.

---

## 6. The editor ladder — E0 through E7

Risk-ordered per `decisions/2026-08-02-h1-splits-by-font-risk.md` `[inherited]`: a test-only gate first,
then the rungs in dependency order, with the two genuinely optional capabilities **last** so dropping
either loses nothing beneath it. Each phase is ONE PR, one squash-merge, independently revertible, and
each **must leave note capture working on its merge commit**, proven by a measured `fullValidationCmd`.

### E0 — Grammar and the two-renderer invariant. TEST-ONLY, zero files under `lib/`

**Branch** `editor/e0-grammar` — base `main`. **Gates** E1. **Depends on** nothing.

Files, all new, all under `test/features/entry_cards/markdown/` — the same test-tree-then-promote shape
the sibling's R4 establishes `[inherited]`; **E1 `git mv`s them into `lib/design/markdown/`**.

**Acceptance criteria:**

1. For every one of the 12 grammar features, `editorSpans(parse(src)).toPlainText() == src`, char for char.
2. Property case: for 200 generated documents mixing all 12 features, the same equality holds.
3. `readSpans(parse(src)).toPlainText()` has every marker removed and every content character retained,
   in order.
4. A U+FFFC placed inside a marker run survives both renderers at its document-order position (A2).
5. `plainText(parse(src))` for a heading + bullet + bold document contains no `#`, `-`, or `*`.
6. Parsing is total: no input throws, including unterminated `**`, a bare `>`, and an empty string.

**Tests it adds: 6 cases.** *Admission gate:* each defines the public contract of a new pure function with
zero existing coverage — no markdown parsing exists anywhere in the repo `[audit]`. Criterion 1 is N1
itself, machine-checked. None asserts a literal copied from output.

**Must not regress:** nothing. Zero files under `lib/`. **A revert degrades to:** nothing.

**If E0 is RED on criterion 1 or 2, the markdown-source-of-truth substrate is falsified** and the whole
ladder stops for a re-decision. That is what a gate is for.

### E1 — The read view renders markdown

**Branch** `editor/e1-read` — base `main`. **Depends on** E0 **merged** (A9) **and P1 merged** (§7.1).

**E1 rewrites a `NoteBody` that P1 has already changed, and must PRESERVE that change.** P1 adds a
`stripPhotoAnchors` call; E1 rewrites the widget wholesale around it, in A3's order — strip anchors, then
parse, then test emptiness (D1). **If E1 is implemented against a pre-P1 `NoteBody` the stripper is
silently dropped and every stored U+FFFC renders as tofu** — precisely the outcome the sibling's R7 exists
to prevent. This obligation is why P1 ships first; state it in E1's dispatch.

Promotes E0's six files into `lib/design/markdown/` (`git mv`, plus the barrel). `NoteBody` renders
`Text.rich(readSpans(...))`; the block-assembly loop moves to `note_blocks.dart` (A5). `today_memory.dart`
and `search_day_view.dart` route through `plainText` (§3).

**Ships value alone**: every note already stored renders rich, everywhere notes are displayed, with no
editor change at all. This is where the app is deliberately **better than the prototype** (N6).

**Acceptance criteria:** a note whose text is `'# Title\n\nsome **bold** words'` renders `'Title'` at
heading scale and `'bold'` at `FontWeight.bold`, and `find.text('# Title')` is `findsNothing`; the
`'Empty note'` affordance still fires for blank text; the On This Day preview and a search result for the
same note contain no `#` or `*`.

**Tests it adds: 4 cases.** **Declared retarget, and it is the whole risk of this phase:**
`note_body_test.dart` and `entry_card_test.dart` both match rendered text with literal `find.text(...)`
and are flagged HIGH by the app audit `[audit]`. Retargeting an assertion that pins a rendering the phase
is mandated to change is maintenance, not a new test
(`decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md` `[inherited]`) — the
retarget must pin the **same behaviour through the changed surface**, never preserve assertion count.

**A revert degrades to:** today's literal rendering. Stored text is untouched; markdown is inert convention.

### E2 — Live inline styling in the editor

**Branch** `editor/e2-inline` — base `editor/e1-read`. Creates `MarkdownNoteController` (§3) and swaps
`text_composer_sheet.dart:75`'s plain controller for it `[verified]`. Bold, italic, underline, inline code,
highlight. Markers styled to near-invisibility, **never deleted** (N1). No transforms, no blocks, no toolbar.

**The one accessibility obligation, and it is the lowest-detection-probability defect in this spec:**
VoiceOver voices a near-invisible `**` unless semantics suppress it `[audit]`. E2 ships that suppression
and a receipt for it. It will never surface in visual QA.

**Tests it adds: 4 cases** — one round-trip equality case through the real controller (N1 through the
public surface), one per style family, one semantics case.

### E3 — Live block styling in the editor

**Branch** `editor/e3-blocks` — base `editor/e2-inline`. Headings h1/h2/h3, bullet, ordered, divider, and
the to-do checkbox **as a rendered glyph only** — no tap (N3; the tap is E7). Quote text styling ships
here; the quote **bar** is E6.

**Tests it adds: 3 cases.**

### E4 — Type-to-transform, list continuation, backspace demotion, auto-renumber

**Branch** `editor/e4-transform` — base `editor/e3-blocks`. **The highest-risk phase in the ladder** and
the substrate research's predicted first failure: type-to-transform × undo/redo × IME composing.

**CORRECTION, verified 2026-08-03 against the tracker.** The substrate audit, the logbook thread's
open-risk list, and this spec's own first draft all cite **flutter#130881** ("Undo/Redo history disappears
on Japanese keyboard") as **OPEN** evidence that the built-in undo stack desyncs from IME with no custom
code. **It is CLOSED** — fixed by PR #138674, shipped in **Flutter 3.19.0**, and this repo is on 3.44.8.
That leg of the argument is gone. **Fix the logbook thread's open_risks entry, which still carries it.**

E4 remains the highest-risk phase, on a narrower and better-sourced footing: N2's gate rests on Flutter's
**own official `TextInputFormatter` documentation**, which warns verbatim that text modification must be
applied only when `TextEditingValue.composing` is collapsed `[audit]`. That warning is independent of
#130881 and is not weakened by its closure.

Every mutation gated on `composing.isCollapsed` (N2). The `_applyingTransform` latch of A6 ships here even
though the anchor bookkeeping it protects does not exist until P2 — **the latch is cheaper to ship early
than to retrofit**, and P2's receipt then has something to assert against.

**Acceptance criteria include the IME gate explicitly:** a transform trigger delivered while
`composing` is non-collapsed performs **no** mutation. **macOS Cmd+Z parity is `[unverified]`** — no macOS
`NSUndoManager` equivalent of iOS PR #98294 was found `[audit]` — so it is a **manual** check in §8, and
the PR says `--not-verified "macos system undo parity - manual check owed"` if it was not run.

**Tests it adds: 6 cases.** **If E4 proves unshippable, E0–E3 stand**: the editor renders live and the
user types markdown by hand, which is exactly what a markdown source-of-truth buffer means.

### E5 — Selection toolbar and ⌘B/⌘I/⌘U

**Branch** `editor/e5-toolbar` — base `editor/e4-transform`. `EditableText.contextMenuBuilder` +
`AdaptiveTextSelectionToolbar.buttonItems`; the deprecated `toolbarOptions`/`selectionControls` path is
forbidden `[audit]`. **FOUR controls, not the prototype's five — underline is dropped (§3.1, D8).**
B, I, `<>` (inline code), and
◆ U+25C6 (highlight) — **◆ is a real `<mark>` wrap, not a placeholder** `[audit]`. Toolbar appears only on
a non-collapsed selection, as the prototype does.

`CupertinoTextSelectionToolbar` (iOS) and `CupertinoDesktopTextSelectionToolbar` (macOS) genuinely diverge
and **both** must be validated `[audit]`.

**Tests it adds: 3 cases.**

### E6 — Quote bars — DROPPABLE TOP RUNG 1

**Branch** `editor/e6-quotebar` — base `editor/e5-toolbar`.

*This is the first of the two scope calls the thread reserved for the user.* It is **in** the spec, at the
top of the ladder, so the call is made with a working implementation in hand rather than in advance — a
strictly better position to decide from. **Merging it is the user's call. Dropping it costs nothing
beneath it.**

The cost is real and is why it sits here: a quote bar spanning wrapped lines has **no native primitive**.
It is a hand-synced `CustomPaint` overlay driven by `TextPainter.computeLineMetrics()`, recomputed on every
edit, resize and font-scale change, and the substrate research rates it **HIGH** risk with a named failure
mode — geometry drift that looks fine at rest in manual QA and surfaces after ship `[audit]`.

**Acceptance criteria must include the drift cases or the phase is not worth shipping:** the bar tracks a
quote across a resize, across an accessibility text-scale change, and across a scroll.

**Tests it adds: 3 cases.** **A revert degrades to:** E3's quote text styling with no bar.

### E7 — Tappable to-do checkboxes — DROPPABLE TOP RUNG 2

**Branch** `editor/e7-todo` — base `editor/e6-quotebar` (or `e5` if E6 is dropped).

*The second reserved scope call.* Same structure, same reasoning.

The checkbox already **renders** from E3. E7 adds **only the tap**, and the tap cannot live in the span
tree: `TapGestureRecognizer` in `buildTextSpan` throws on iOS, reproduced on 3.44.1 (N3, flutter#187598)
`[audit]`. It must be a separately hit-tested overlay positioned from the same `computeLineMetrics`
machinery E6 builds — **which is why E7 sits above E6 and not beside it.** If E6 is dropped, E7 pays for
that machinery alone; say so in its PR rather than discovering it.

**Tests it adds: 3 cases**, one of which asserts under `debugDefaultTargetPlatformOverride =
TargetPlatform.iOS` — under `flutter test` the platform is forced to `android` by an SDK assert keyed on
`FLUTTER_TEST`, so a test without the override proves nothing about the platform the bug is on
`[inherited]`.

**A revert degrades to:** E3's rendered-but-inert checkbox.

---

## 7. Ship order and dependency chain

### 7.1 THE FILE-OVERLAP MATRIX — computed 2026-08-03, and it overturns the first draft

Per `decisions/2026-07-27-shared-file-cluster-serializes.md` `[inherited]`, **a file shared by two MSPs is
a HARD dependency edge, declared here, never left to the engine to infer** — the engine catches
overlapping *hunks*, not two coherent-but-incompatible rewrites of one widget. The E-fences (§3.2) crossed
with the sibling's fence table yield **exactly three contended files**:

| Contended file | E phases | P phases | Verdict |
|---|---|---|---|
| `lib/features/entry_cards/cards/note_body.dart` | **E1** | **P1, P2, P3** | HARD EDGE |
| `lib/features/capture/text/text_composer_sheet.dart` | **E2, E5, E6** | **P1, P2, P4** | HARD EDGE |
| `markdown_note_controller.dart` (= the sibling's `photo_anchor_controller.dart`, per A4) | **E2, E3, E4, E7** | **P2, P4** | HARD EDGE |

Everything else is disjoint by path: `lib/design/markdown/**` vs `lib/design/layout/**`,
`test/features/entry_cards/markdown/**` vs `test/features/entry_cards/photo/**`, and E1's
`today_memory.dart` / `search_day_view.dart` are touched by no P phase.

**The first draft's claim "P1 may ship in parallel with E1–E5" is FALSE, and on two files rather than the
one originally suspected** — `note_body.dart` (E1) *and* `text_composer_sheet.dart` (E2, E5). It is struck.

**But the fix is not to bury P1 behind the editor. It is to put P1 FIRST.** P1 holds the *smaller* diff on
both contended files — it adds a `stripPhotoAnchors` call to `NoteBody` and mounts `PhotoTray` behind a
nullable callback — while E1 *rewrites* `NoteBody` wholesale and E2 swaps the controller. Landing the small
change first and rebasing the large one onto it is strictly cheaper than the reverse, and **A3 already
defines the composition** (strip anchors, then parse), so E1 knows exactly what it must preserve. P1 is
also the lowest-risk product change in either ladder and the one that makes photos reachable at all.

**New obligation on E1, created by this ordering:** E1 rewrites a `NoteBody` that already calls
`stripPhotoAnchors`. **It must preserve that call, in A3's order.** If E1 is implemented against a
pre-P1 `NoteBody`, the stripper is silently dropped and every stored U+FFFC renders as tofu — the exact
outcome R7 exists to prevent. State it in E1's dispatch.

### 7.2 The resulting order

```
E0  (test-only gate; no contended file)
 ├── P0  (test-only; needs E0 MERGED per A9)   ─┐ genuinely parallel:
 └── P1  (small, product; photos reachable)    ─┘ P0 and P1 share no file
      └── E1 ── E2 ── E3 ── E4 ── E5 ── E6* ── E7*      * droppable, user's call
                                                 └── P2 ── P3 ── P4 ── P5
                                                          ▲
                                                          └── ALSO gated on P0 green
```

**Three ordering laws, all derived from the matrix above, none negotiable:**

1. **P0 and P1 are the only genuinely parallel pair in either ladder.** P0 touches
   `test/features/entry_cards/photo/**` and nothing else; P1 touches no test file P0 owns.
2. **P1 merges before E1 is cut.** Both edit `note_body.dart`; P1 is the smaller diff and E1 rebases onto it.
3. **P2 may not open until the ENTIRE editor ladder has merged** — not merely E2. The first draft said
   "P2 requires E2", which is necessary but **insufficient**: E3, E4 and E7 all edit
   `markdown_note_controller.dart`, the same class A4 has P2 grow. P4 inherits the same constraint.

*Rejected: running P2 after E2 and rebasing it through E3–E7.* That is four rebases of the ladder's
second-largest phase through a class that is still being rewritten under it — the shape
`decisions/2026-07-28-stacked-msps-ship-sequentially.md` was written to forbid `[inherited]`.

**P0 is run as early as A9 permits** — it is test-only, it gates P3, and a red truncates the photo ladder
at P2. Running it late means discovering late.

Branch prefixes are per-run: `editor/` and `inline-photo/`, per
`decisions/2026-07-25-msp-branch-prefix-not-per-type.md` `[inherited]`. Every branch is cut with
`git switch -c <branch> <base-ref>` — **never `git switch main`**, which has aborted twice on this repo
over uncommitted ledger edits `[inherited]`.

The repo squash-merges, so each phase **rebases `--onto main` after its predecessor merges and re-runs
`fullValidationCmd` on the new base. Never carry a green from one base to another** `[inherited]`.

E1–E7 and P1–P5 each ship as a native GitHub stack per
`decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md`; **E0 and P0 are standalone PRs against
`main`, outside their stacks.** `gh pr create` and `gh pr merge` are **both denied globally** — every PR
goes through the `pr-create` tool, every merge is a human action `[inherited]`.

---

## 8. Verification

**`fullValidationCmd` is the only gate. CI is not evidence** — no GitHub check runs a Dart test in this
repo `[inherited]`. Run it in the **foreground**; a subagent's background shells are swept at teardown and
two earlier attempts on this project were lost that way.

**Never `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into
the real journal container. Name a single file.

**Baseline: 944 passed, analyze clean, measured on `inline-photo/spec` at `712c978`** `[inherited]`.
**Measure it again on your own branch.** Per-phase deltas: E0 +6, E1 +4, E2 +4, E3 +3, E4 +6, E5 +3,
E6 +3, E7 +3 — **+32 across the editor ladder**. The sibling's P-phase deltas stand; its absolute totals
do not (A7). A total **below** your measured baseline at any point means a case was lost.

**Two failure categories that are not test-count movements** `[inherited]`: a build break (growing an
`abstract interface class` without updating every implementer) produces **zero**, not a reduced count; and
a leaked `TextPainter` reds a whole file with a stack trace naming the binding, not the widget.

**The manual pass is owed by a human on macOS** — no agent runs this app; `flutter run -d macos` needs a
TTY and the standalone binary renders a black window `[inherited]`. Per phase:

- **E1** — open a note containing `#` and `**`. It renders styled. Search for it; the result shows no punctuation.
- **E2** — type `**bold**`. It styles live and the asterisks nearly vanish. **Turn VoiceOver on and confirm it does not read the asterisks.**
- **E3** — type `# `, `- `, `1. `, `> `, `---`. Each block styles.
- **E4** — **the highest-value manual check in the editor ladder.** Type each trigger. Press Enter mid-list; it continues. Backspace an empty item; it demotes. **Switch to a CJK input method and type through a transform trigger — nothing may mutate mid-composition. Then press ⌘Z repeatedly and confirm the buffer walks back cleanly** (macOS parity is `[unverified]`; this check is how it becomes known).
- **E5** — select text on macOS **and** iOS. Both toolbars appear correctly placed. ⌘B/⌘I/⌘U work.
- **E6** — resize the window and change the system text size with a quote on screen. The bar must track.
- **E7** — tap a checkbox **on iOS**. It toggles and does not throw.
- **P0–P5** — the sibling's §5.5 checklist, unchanged `[inherited]`.

---

## 9. Out of scope

Everything in the sibling's §6.1/§6.2 `[inherited]`, plus:

- **Nested lists and indent, links, and custom undo/redo beyond Flutter's built-in `UndoHistory`.** None
  exist in the prototype to reference `[audit]`; there is nothing to be faithful to.
- **Backtick-triggered inline code.** Toolbar only, as the prototype has it `[audit]`.
- **A title/body split.** The prototype has one `contenteditable` region; the large serif "title" is a
  block the user turned into `h1` by typing `# `. `{{ composerTitle }}` is the modal's chrome label, not
  content `[audit]`.
- **Storing rendered HTML alongside the source.** The prototype stores both and its `html` is referenced
  by no read template — write-only, for its own edit round-trip `[audit]`. Markdown source-of-truth makes
  it redundant; storing it would be a second authority for one note.
- **Any editor package** (N4). **Any database migration** (M1).
- **Photo destruction on re-edit** (N5) — named so no one ports the bug.

---

## 10. What in this document is NOT hardened — read before dispatching

Stated plainly, because the prior attempt at this spec died mid-hardening and this project's failure mode
is a confident document that was never checked.

1. **This document has not been critic-hardened.** Neither has the 1228-line sibling it amends. The
   hardening pass is owed and is the correct next act after review.
2. **Every `[inherited]` citation is unverified.** §0.1 is not a formality — the sibling's own §7 lists
   four citation-drift defects it found in the ledger, and it was itself never checked.
3. **The E-phase test-count deltas are estimates**, not derived from written tests. A mismatch is a signal
   to report, not to absorb.
4. **`splitSpanAt` (A1) is asserted to be tractable, not proven.** It is the one genuinely new algorithm
   this document adds and nothing has spiked it. If P3 finds it harder than stated, that is a finding
   against A1, not an implementer's judgment call — **stop and report.**
5. **macOS system undo parity is `[unverified]`** and stays that way until E4's manual pass runs.
6. **The markdown-source-of-truth decision is `Status: proposed`.** This document builds on it because the
   user directed the work to proceed. **Flip it to `accepted` before dispatching E0, or say why not.**

---

## 11. HARDENING DEFECTS — CLOSED 2026-08-03

A hardening pass ran 2026-08-03 and returned a BLOCK verdict. **Every finding it raised is now resolved.**

| Finding | Closed by |
|---|---|
| CRITICAL — grammar never enumerated | §3.1, twelve-row table |
| CRITICAL — `splitForFloat` signature vs P0 independence | A9 |
| CRITICAL — E0–E7 had no file fences | §3.2, per-phase fences + named traps |
| HIGH — reverting E2 after P2 is a build break | A10 |
| HIGH — "E0 green" insufficient for E1 | A9 (E0 must be MERGED) |
| HIGH — A5 silently broke R20's receipt and §5.6 | A11 |
| HIGH — R0 declared spent while bases are `main` | A12 |
| H1 marker-only render / H2 empty-save guard | **D1** (one predicate, two consumers) |
| H3 metrics-overlay owner if E6 drops | **D2** |
| H4 undefined anchor offset under the transform latch | **D3** |
| M1(a) accessibility gaps | **D4** |
| M1(b) §2 overstated | **D7** |
| M2 markdown × `WidgetSpan` unmeasured | **D5** (P2 matrix 6 → 10 cases) |
| M3 search MATCH semantics | **D6** |
| M4 underline | **D8** / §3.1 — dropped |

**Two items below remain genuinely open. They are the only ones.** The table originally in this section is
superseded by the mapping above; the resolutions live in §5.1.

**CLOSED 2026-08-03 — the citation proof RAN.** 28 anchors re-opened at `c573010`: **25 OK, 3 DRIFT,
0 ABSENT**, all three corrected in **§0.2**, none design-changing. The `[audit]` tier is proven for that
set. **Still open:** the ~60 `[inherited]` citations in the sibling that fall outside the 28 — they remain
unverified and §0.1's duty ("re-open every one") stands for them.

**CLOSED 2026-08-03 — §7's parallelism claim was FALSE and is struck.** The E×P file-overlap matrix is
computed in **§7.1**. The claim was wrong on **two** contended files, not the one suspected
(`note_body.dart` via E1, and `text_composer_sheet.dart` via E2/E5), and a third contended file
(`markdown_note_controller.dart`) proved the "P2 requires E2" law insufficient — E3, E4 and E7 edit the
same class. §7.2 carries the corrected order and its three derived laws. The resolution is **not** to bury
P1 behind the editor: P1 holds the smaller diff on both contended files and now ships **first**, with E1
rebasing onto it under a newly declared obligation to preserve the stripper.

---

**Rule for implementers, inherited verbatim because it is the rule this project keeps learning:** re-open
every cited line before adopting any value, and open the widget or the DAO the value has to pass through
before assuming it can hold it. If you meet an anchor that does not resolve, or a target the code has no
way to express, **stop and report. Do not make the call yourself.**
