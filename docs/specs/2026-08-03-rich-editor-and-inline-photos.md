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
  `ValueListenableBuilder` at `:277`. `[verified]`
- `docs/specs/2026-08-02-inline-photo-notes.md` is 1228 lines and its own §7 states every citation in it
  was re-opened at `712c978` — a claim made by an unhardened document about itself. `[verified]` that the
  claim exists; the claim itself is `[inherited]`.

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
| Read view | `NoteBody`, a `Text` | **Yes** — a `RenderParagraph`, never a `RenderEditable`. This is where R15/R18's float lives |
| Arrange mode | read-only float renderer + handles (R22) | **Yes** — R22 already forbids arrange mode from mounting an `EditableText` |

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
| **N1** | **`buildTextSpan`'s plain text equals `controller.text`, char for char, always.** Markers are hidden by style; never deleted, never substituted, never reordered | maintainer statement on #159171 `[audit]` |
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

**Branch** `editor/e1-read` — base `main`. **Depends on** E0 green.

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
the substrate research's predicted first failure: type-to-transform × undo/redo × IME composing, where
every piece is separately documented as fragile and the built-in undo stack already desyncs from IME with
no custom code (flutter#130881) `[audit]`.

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
forbidden `[audit]`. Five controls, matching the prototype exactly: B, I, U, `<>` (inline code), and
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

```
E0 (test-only gate)
 └── E1 ── E2 ── E3 ── E4 ── E5 ── E6* ── E7*          * droppable, user's call
                                    │
P0 (test-only gate, independent)    │
 │                                  ▼
 └──────────── P1 ── P2 ── P3 ── P4 ── P5
                      ▲     ▲
                      │     └── ALSO gated on P0 green
                      └── requires E2 (one controller, §3/A4)
```

**Hard ordering law: P2 may not open until E2 has merged.** P2 grows the controller E2 creates (A4).
P1 is genuinely independent of the whole editor ladder — it wires `photos:` and ships the stripper, and
touches no rendering — so **P1 may ship in parallel with E1–E5**, and should, since it is the phase that
makes photos reachable for the first time.

**P0 may run at any time** and is best run early: it is test-only, it gates P3, and a red truncates the
photo ladder at P2. Running it late means discovering late.

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

**Rule for implementers, inherited verbatim because it is the rule this project keeps learning:** re-open
every cited line before adopting any value, and open the widget or the DAO the value has to pass through
before assuming it can hold it. If you meet an anchor that does not resolve, or a target the code has no
way to express, **stop and report. Do not make the call yourself.**
