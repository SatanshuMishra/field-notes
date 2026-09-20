# Design panel — markdown editor + scrapbook photo notes

Date: 2026-09-20. Six independent designs, three judge lenses, one synthesis, three stress tests.
15 agents, 2.5M tokens. Prior specs were under embargo.

---

## Resolved facts

### Float packages, measured with probe tests

## 1. Package facts (measured 2026-09-20)

| | **float_column** | **hyper_render** |
|---|---|---|
| Latest / published | 4.1.3 — 2026-08-31 | 1.9.1 — 2026-09-07 |
| Stable? | Yes. 46 versions since 2021-04-26; stable semver since 1.0 | Nominally. 22 versions since 2026-03-08 (first release); ~1 release / 8 days |
| Licence | MIT (`license:mit`, `osi-approved`) | MIT |
| Publisher | `ronbooth.com` | `brewkits.dev` |
| Maintainers | **1** — `ronjb`, 147 commits, sole contributor | **1** — `vietnguyentuan2019`, 255 commits (+3 bot) |
| Repo age | 2021-04-06, last push 2026-08-31 | 2025-12-25, last push 2026-09-07 |
| Open issues | **0** (11 issues ever, all closed) | **0** (5 issues ever, all closed) |
| pub points / likes / 30-day downloads | 160/160 · 86 · **7 214** | 160/160 · 19 · **546** |
| Dependencies | **flutter only** | `hyper_render_core`, `flutter_svg`, `markdown`, `html`, `csslib`, `highlight`, `flutter_highlight`, `vector_math` |
| Platforms | android/ios/macos/windows/linux/web, wasm-ready | same |

Both are bus-factor 1. The difference is duration: float_column has 5.4 years of single-maintainer history and survived three Flutter breakages (3.24, 3.29, and the Material-out-of-SDK move in 4.1.3); hyper_render is 9 months old and has never been through a Flutter major.

## 2. Do they actually flow text around a float? Both YES — measured, not read off the blurb

**float_column.** Probe (`.../scratchpad/probe/test/probe_test.dart`): `FloatColumn` at 360px with `Floatable(float: FCFloat.left, padding: right 12, child: SizedBox(120,120))` + `WrappableText`:

```
FC_PARAGRAPHS n=2 :: w=228.0 h=140.0 | w=360.0 h=240.0
```

Two `RenderParagraph`s — 360−120−12 = 228 for the band beside the float, then 360 below it. Real band slicing, exactly as the terrain survey's source read described.

**hyper_render.** Its own `packages/hyper_render_core/test/float_layout_test.dart` (296 lines) is misleading — every assertion is enum membership or a `ComputedStyle` getter; it measures **zero geometry**. The real pin is `test/flagship_execution_audit_test.dart`, which is differential but under-discriminating (it only asserts `floated > stacked`, which a non-wrapping implementation also satisfies). So I measured it (`.../probe/test/hr3_test.dart`):

```
textOnly@360=304  textOnly@228=528
float 120x120 = 336   (stack-prediction 424)
float 120x300 = 416   (stack-prediction 604)
float 120x900 = 908   (i.e. driven entirely by the float band)
floated <img> (unresolvable src, w/h in CSS) = 336
```

336 ≪ 424 and 416 ≪ 604: the text genuinely occupies the band beside the float. Confirmed.

**But hyper_render's float has a scope limit it documents honestly** (`doc/LIMITATIONS.md`, "float scope" row, pinned by a `KNOWN GAP` test at `flagship_execution_audit_test.dart:102-126`): a float reserves a box from the element's own `width`/`height` — it does **not** lay the floated element's content out inside that box. Works for `<img>` and for empty explicitly-sized boxes. Does **not** work for a block sized by its own text (renders in normal flow while still reserving a phantom box, making the container *taller*), and a floated inline `<span>` (drop cap) does nothing. For a photo-in-a-note that is fine — but it means **you must know the image's pixel dimensions before render**, and per the terrain survey `media_blobs.width`/`height` are NULL for every photo this app has ever stored.

`float_column` does not have that restriction — `Floatable` lays out a real widget child — but it inherits the same practical problem from a different direction: an async `Image.file` has zero size until decoded, so the band reflows on first frame.

Placement model, both: CSS float only — left/right/start/end in document order. Neither expresses arbitrary (x, y). `Floatable`'s complete field list is `float, clear, clearMinSpacing, margin, padding, maxWidthPercentage, child`.

## 3. The "crash-free selection" question — the prior survey's inference is REFUTED

The prior survey inferred that hyper_render's marketing "implies a known selection failure in the incumbent." It does not, because **float_column is not the incumbent it is aimed at**.

- `grep -i "float_column\|ronjb"` over hyper_render's `README.md` and `doc/COMPARISON_MATRIX.md`: **zero hits**. float_column is never mentioned.
- The claim's actual target is named in the feature matrix: `| Text selection — large docs | flutter_html ❌ Crashes | flutter_widget_from_html ❌ Crashes | HyperRender ✅ Crash-free |`. It is a widget-tree-vs-single-RenderObject argument about HTML renderers that emit ~500-600 widgets per document.
- hyper_render's own hedge (`COMPARISON_MATRIX.md:62-67`) is architectural, not empirical: *"That is an architectural property you can inspect in the source — it does not depend on a benchmark number."* The "Crashes" cells carry no citation at all (the only cited flutter_html issues in that doc are #1366, #1482, #1060, #508 — none about selection).

**And the mechanism does not transfer to float_column.** float_column's selectable count scales with *float count*, not document size. Measured (`.../probe/test/sel_test.dart`), 20-step drag under `SelectionArea`:

```
FCSEL chars=2050   paragraphs=2  dragMs=65  exception=null
FCSEL chars=20500  paragraphs=2  dragMs=20  exception=null
FCSEL chars=82000  paragraphs=2  dragMs=26  exception=null
```

Two `RenderParagraph`s at 82k characters. There is no selectable explosion to crash on.

**The one real float_column selection defect is documented, narrow, and already fixed.** CHANGELOG 4.1.1 (2026-08-27) introduced a hidden trailing word to make `TextAlign.justify` justify across wrap boundaries, and noted *"it can appear in text selections that span a boundary."* 4.1.2 (same day) fixed it with a zero-height inline widget plus a `SelectionContainer` delegate that excludes the fragment. Verified fixed in 4.1.3 (`.../probe/test/sel2_test.dart`) — ctrl-A ctrl-C across the float boundary:

```
FCCOPY align=TextAlign.start   srcLen=281 copiedLen=281 exact=true
FCCOPY align=TextAlign.justify srcLen=281 copiedLen=281 exact=true
```

Byte-exact both ways. Also relevant: float_column's only historical selection complaint is issue #1 (2021-09-16, `SelectableText` inside `WrappableText`), closed the same day, and made obsolete by the 4.0.0 rewrite onto `RichText` + Flutter's own `SelectionArea`.

Meanwhile hyper_render's *own* selection layer is hand-rolled and has churned continuously: its CHANGELOG records copy producing an empty clipboard, the Copy button outside hit-testable bounds, scroll-vs-selection gesture conflict, Escape failing to clear, the virtualized copy menu never appearing, `HyperTextSelection` missing `operator==`, ellipsis leaking hidden text via copy, and a selection-drag hit-test freeze. All fixed, but that is a surface being actively discovered, not a settled one. float_column delegates selection to the framework; hyper_render owns it.

**Verdict on Q3: refuted.** There is no selection defect in float_column at document scale. The marketing line targets flutter_html / flutter_widget_from_html, and the architecture it argues against is not float_column's.

## 4. Version solving against this repo — both clean; the drift_dev hazard is real but hits a different package

`flutter pub add --dry-run` against `/Users/satanshumishra/Documents/DevLabs/fireplace/pubspec.yaml` as pinned today (`drift ^2.34.1`, `drift_dev ^2.34.0`). Repo left unmodified (`git status --porcelain` clean afterwards).

```
float_column  -> + float_column 4.1.3                       Would change 1 dependency.
hyper_render  -> + hyper_render 1.9.1, hyper_render_core 1.9.0, flutter_svg 2.3.0,
                   markdown 7.3.1, highlight 0.7.0, flutter_highlight 0.7.0,
                   path_parsing 1.1.0, vector_graphics{,_codec,_compiler}
                                                             Would change 10 dependencies.
both together -> Would change 11 dependencies.
```

Zero downgrades, zero removals, no movement on drift/drift_dev/riverpod/build_runner. `html` and `csslib` did not appear as additions — already in the tree.

I then reproduced the drift_dev hazard directly, in a scratch copy with `drift: ^2.35.0` / `drift_dev: ^2.35.0` (the bump the survey says the migration work requires):

```
+ float_column                    Would change 1 dependency.    OK
+ hyper_render (10 pkgs)          Would change 10 dependencies. OK
+ super_editor                    version solving FAILED
    "So, because field_notes depends on both flutter_test from sdk
     and drift_dev ^2.35.0, version solving failed."
```

The conflict is `super_editor -> attributed_text -> test ^1.19.4` pinning `analyzer`, disjoint from `drift_dev ^2.35.0`'s `analyzer >=13.0.0 <15.0.0`. **Neither float_column nor hyper_render participates in it, under either pin.** This matches the survey's corrected numbers at line 894/900 (base 180 packages, float_column 181, hyper_render 190).

## 5. Replaceability and coupling depth

**float_column — shallow, genuinely reversible.** Pure widget API: `FloatColumn` / `Floatable` / `WrappableText`. Nothing touches the data model, no codegen, no build step, one dependency (Flutter). In this repo the blast radius is `lib/features/entry_cards/cards/note_body.dart` (24 lines, a single `Text`), with exactly one production call site at `entry_card.dart:136` and `EntryCard` itself having two call sites. Replacing float_column later = rewriting one widget's `build`. Two real constraints to design around: (a) it throws in debug under `IntrinsicHeight`/`IntrinsicWidth` (verified — `FCINTRINSIC ex=Multiple exceptions (4)`; harmless here, `grep -rn "Intrinsic" lib/` returns nothing); (b) `maxWidthPercentage` clamps the float but does **not** promote it to a block — measured at 160px width it still leaves an 84px unreadable text ribbon, so responsive collapse is yours to write either way.

**hyper_render — deep, and deep in the wrong dimension.** It is not a float widget, it is a document engine: you feed it HTML / Markdown / Quill Delta and it replaces your entire text pipeline — layout, painting, selection UI, selection menu, theming, hit-testing. `HyperViewer` exposes 45+ constructor parameters. Adopting it means:
- note content becomes its input dialect (mild if you store plain Markdown, severe if you store HyperRender-flavoured HTML with inline CSS for float placement);
- the app's `TypographyTokens` / Newsreader-and-Caveat font system has to be re-expressed through `customCss` / `ComputedStyle`;
- SHA-256 content-addressed local blobs must be routed through `HyperViewer.imageLoader` (added very recently — CHANGELOG 1.9.0 — to escape the built-in `NetworkImage` path; its stated first consumer is an "in-progress" EPUB package);
- selection chrome, menu and handles come from the package, not from Flutter, so they will not match anything else in the app;
- +10 transitive packages including `flutter_svg` and the `vector_graphics` triple.

Reversibility: the *content* stays portable if you store Markdown, but everything downstream of it — theming, selection, image resolution, the one-RenderObject assumption — is thrown away on swap. Call it 1 file for float_column vs. the whole note-rendering surface for hyper_render.

## 6. Hand-rolled cost — **68 lines, and it is written**

I built it: `/private/tmp/claude-501/-Users-satanshumishra-Documents-DevLabs-fireplace/f425e6df-232f-4dae-b76c-1c1a07f51237/scratchpad/probe/lib/hand_rolled.dart`, 68 lines including the responsive collapse.

Approach (restricted case: one photo, float left or right, known rectangle):
1. `LayoutBuilder` gives the full width. `bandWidth = full − floatWidth − gutter`.
2. If `bandWidth < minTextWidth`, return `Column(photo, gap, Text(whole))` — the responsive collapse falls out here, free.
3. Otherwise lay out one `TextPainter` at `bandWidth` with the ambient `textScaler` and `Directionality`; if its height already fits inside the float, the whole text is the head. Otherwise `split = painter.getPositionForOffset(Offset(bandWidth, floatHeight)).offset` — one call, ~1.1 µs per the survey's measurements.
4. Emit `Column(Row(photo, gap, SizedBox(bandWidth, Text(head))), Text(tail))`.

Measured (`.../probe/test/hand_test.dart`):

```
HAND_SLICES  n=2 :: w=228.0 h=132.0 | w=360.0 h=220.0   total=Size(360.0, 352.0)
HAND_NARROW  width=200 -> total=Size(200.0, 704.0)      (collapsed to block)
HAND_COPY    srcLen=282 copiedLen=282 exact=true        (ctrl-A ctrl-C across the boundary)
HAND_PERF    chars=282   firstLayoutMs=9
HAND_PERF    chars=5640  firstLayoutMs=16
HAND_PERF    chars=56400 firstLayoutMs=21
```

Identical slice geometry to float_column (228 / 360). Selection and copy work **with no custom `SelectionContainer` delegate at all** — Flutter's `SelectionArea` already walks multiple `Text` widgets in document order. float_column's `MultiSelectableSelectionContainerDelegate` exists solely to hide the justify hidden-word, which is a cost of *justified* text, not of slicing.

So the honest number is **~70 lines for the restricted case, not 500**. What the 70 lines do *not* buy you, and what float_column's ~3,000 do: `clear` with minimum spacing, multiple stacked floats, floats anchored from inline `WidgetSpan` positions inside the text, RTL start/end floats, justified text across wrap boundaries, nested float columns, semantics-label de-duplication across split spans, `maxLines` truncation interacting with floats, and five years of Flutter-upgrade scar tissue. The cost curve is steep: one float at a fixed anchor is ~70 lines; N floats with `clear` and inline anchoring is where you start rebuilding `findSpaceFor` and you are at 500+.

---

## Verdicts

**float_column — ADOPTABLE, and the low-risk choice.** MIT, zero non-Flutter dependencies, 160/160, 7.2k downloads/month, zero open issues, five years of maintenance, resolves against this repo under both the current pins and the drift_dev 2.35.0 bump with a **one-package** delta. It genuinely wraps (measured). Its selection is fine at 82k characters (measured) and the one real selection defect shipped and was fixed within the same day in August 2026 (verified fixed). Coupling is one widget file. Risks to carry into design, not blockers: bus-factor 1; render-only, with no `EditableText` integration anywhere in its source; CSS-float placement only, no (x, y); `maxWidthPercentage` clamps but does not collapse, so responsive promotion is yours; and a floated `Image.file` reflows on decode because dimensions are not known ahead of time.

**hyper_render — NOT ADOPTABLE for this feature.** Not because it is bad — it is candid, well-documented, and its float genuinely works (measured). Because it is the wrong shape and the wrong risk. It is a 10-package HTML/Markdown *document engine* that would replace this app's entire note-rendering, theming and selection surface to deliver one float; its float is restricted to replaced elements and pre-sized boxes, which collides head-on with `media_blobs.width`/`height` being NULL for every photo in this database; the local-blob escape hatch (`imageLoader`) is three weeks old with no shipped consumer; the repo is 9 months old with one maintainer, 546 downloads/month, 19 likes, and has never survived a Flutter major; its selection layer is hand-rolled and still actively discovering bugs release over release. And the single stated reason to prefer it here — "crash-free text selection at any document size" — is aimed at flutter_html and flutter_widget_from_html, never mentions float_column, carries no citation, and describes a failure mode float_column structurally cannot have.

**Hand-rolled — VIABLE, and it is the real competitor to float_column, not hyper_render.** 68 lines gets measured-correct geometry, free selection and copy, free responsive collapse-to-block, and 21 ms first layout at 56k characters, with zero dependencies and zero upgrade risk. Choose it if placement is going to be *restricted* (one photo, left/right, anchored at a paragraph boundary) — which is also the option the terrain survey independently identified as the cheapest and sturdiest. Choose float_column if `clear`, multiple floats, inline-anchored floats, RTL, or justified text are in scope — at which point the 70 lines become 500+ and you are reimplementing `findSpaceFor` worse than ronjb did.

**Unresolved and load-bearing for the design phase, unchanged by this survey:** none of the three does wrap-*while-typing*. All are renderers. The composer question is still the deciding question.

### The float/stack threshold, re-derived

Probe files removed; working tree is clean (only the pre-existing untracked `.serena/`).

---

# Demotion rule for a floated image: derivation from measured type

## BLUF

**The 520–560pt figure is not just unsourced, it is the wrong quantity.** At this app's real body style (Newsreader 13.5, `height: 1.5`), a 520pt column measures **81 characters per line** and 560pt measures **88 CPL** — both *above* every published maximum (Bringhurst 75, WCAG 80, Baymard 75). 520–560pt is roughly where a 16–18px web font hits ~65 CPL, which is the provenance I'd guess: someone carried a full-column desktop CSS number across and relabelled it a minimum residual.

A defensible rule exists, it is a **character count**, and it converts to a **font-size-relative multiple that I verified is exactly scale-invariant**. But the honest conclusion is uncomfortable: **at this app's current card geometry, no float on a phone can pass any sourced threshold.** The rule does not produce a breakpoint; it produces "desktop only" unless the card geometry changes.

---

## 1. The actual typographic constraint (characters, not pixels)

| Source | Recommendation |
|---|---|
| Bringhurst, *Elements of Typographic Style* | 45–75 CPL single column, **66 ideal**; **40–50 CPL for multiple columns**; **minimum ~40 for justified, below 38–40 spacing breaks down**; marginal notes 12–15 CPL; continuous text max 80 |
| Butterick, *Practical Typography* | "Aim for an average line length of 45–90 characters, including spaces"; "You should be able to fit between two and three alphabets on a line" |
| WCAG 2.x SC 1.4.8 (AAA) | "Lines should not exceed 80 characters or glyphs (40 if CJK)" — a **ceiling**, not a floor |
| Dyson & Haselgrove (2001), *Int. J. Human-Computer Studies* | **55 CPL** best compromise of speed and comprehension on screen |
| Dyson & Kipping (1998) | 100 CPL read *faster* than 25 CPL at equal comprehension — the low end is the real risk, not the high end |
| Tinker & Paterson (1929) | ~57 CPL optimum at 10pt |
| Baymard Institute | 50–75 CPL; implement as `max-width: 70ch` or `34em` (font-relative, not px) |
| Material Design | 40–60 CPL ideal; up to ~120 tolerable on large screens |

**The load-bearing number for a demotion rule is the floor, and only Bringhurst supplies one directly: ~40 CPL, from the multi-column range (40–50) and the explicit "below 38–40" breakdown point.** Everything else in the literature is about ceilings or optima. I found **no** empirical study that tested the specific case of text in a narrow band beside a float. That gap is real and I am not papering over it.

---

## 2. Measured character width for THIS app's body text

**Style under test** — `/Users/satanshumishra/Documents/DevLabs/fireplace/lib/design/tokens/typography.dart:70-76`, `TypographyTokens.bodySerif`: `fontFamily: 'Newsreader'`, `fontSize: 13.5`, `w400`, `height: 1.5`. Consumed by `NoteBody` at `/Users/satanshumishra/Documents/DevLabs/fireplace/lib/features/entry_cards/cards/note_body.dart:22`. Font file is the real variable asset `assets/fonts/Newsreader-Variable.ttf` (`pubspec.yaml:93-96`), loaded into the probe via `FontLoader` so these are the shipping glyphs, not a fallback.

**Method.** A throwaway `flutter test` (Flutter 3.44.8) laying out three English prose samples with `TextPainter`, then recovering per-line character counts with `getPositionForOffset(Offset(width + 1000, lineMidY))` and averaging over all but the final ragged line. Widths for a target CPL were found by binary search on that measurement, so **ragged-right waste is inside the numbers** rather than estimated on top.

**Measured, not assumed:**

- Average prose character width = **0.4587 em** (6.192px at 13.5). Three independent samples of 143 / 593 / 655 chars gave 0.4573, 0.4587, 0.4582 — a 0.3% spread.
- Lowercase alphabet `a`–`z` = **13.789 em** (186.15px at 13.5).
- Digit `0` (the CSS `ch` unit) = **0.600 em** (8.10px). So 1 char of prose ≈ 0.764 ch.
- Space = 0.2435 em.

**Butterick cross-check:** 2–3 alphabets = 27.6–41.4 em → measured **58–88 CPL**. Butterick states 45–90. Consistent.
**Baymard cross-check:** their `34em` ≈ 72 CPL by my measured conversion; they pair it with `70ch`. Consistent.

Both independent cross-checks landing inside their stated ranges is my evidence that the 0.4587 em/char constant is sound and not an artifact of my prose samples.

---

## 3. The conversion table — and why the em form is exact

| Target CPL | Width in **em** | px @12.15 (scale 0.9) | px @13.5 (1.0) | px @15.5 (1.15) | px @20.25 (1.5) | px @27 (2.0) |
|---|---|---|---|---|---|---|
| 35 | **17.0** | 207 | 230 | 264 | 344 | 459 |
| **40** | **19.4** | 236 | **262** | 302 | 394 | 525 |
| 45 | **21.8** | 264 | 294 | 338 | 440 | 587 |
| 55 | **26.0** | 316 | 352 | 404 | 527 | 703 |
| 66 | **31.6** | 384 | 427 | 491 | 641 | 854 |
| 75 | 36.5 | 444 | 493 | 567 | 739 | 986 |
| 80 | 37.7 | 458 | 509 | 585 | 763 | 1017 |

**The em column is identical at every scale, to the printed precision** — and identical again when I re-ran the whole thing at the composer's `fontSize: 19` (`composerBodySerif`, typography.dart:85-91): 35 CPL → 17.0 em, 40 → 19.4 em, 45 → 21.8 em, 55 → 26.0, 66 → 31.6. That is the empirical proof that a multiple-of-font-size rule survives text scaling and the editor/renderer size difference, and a pixel rule does not.

It does **not** survive a font-family change. 19.4 em is a Newsreader constant.

*Caveat on the top two rows:* 75 CPL → 36.5 em and 80 CPL → 37.7 em are compressed relative to the rest of the curve. That is binary-search quantization — at those widths my sample yields few enough full lines that the mean moves in steps. The rows I actually build the rule on (35–55) are on the dense part of the curve and are not affected.

---

## 4. What this app's real geometry already gives (the decisive measurement)

Card content width = screen width − feed padding − card padding. Feed padding is `EdgeInsets.all(20)` (`today_screen.dart:73`) on the stacked/phone branch and `EdgeInsets.all(24)` on the macOS rail branch (`:82`); card padding is `EdgeInsets.symmetric(vertical: 13, horizontal: 15)` (`entry_card.dart:26-27`); the rail is 266 wide with a 1.0 seam (`today_layout.dart:3`, `today_screen.dart:19`). There is no `maxWidth` constraint anywhere in the feed.

**Phone (stacked), content = screenW − 70:**

| Screen | Content | Full-width CPL |
|---|---|---|
| 320 | 250 | 37.5 |
| 360 | 290 | 42.9 |
| 375 | 305 | 45.5 |
| 390 | 320 | **48.8** |
| 430 | 360 | 54.8 |

**The body text on a modern phone is already at 43–55 CPL with no image at all** — at or below Bringhurst's 45 floor on anything ≤375pt.

**Residual beside a float on a 390pt phone (content 320, 12pt gutter):**

| Image fraction | Image | Residual | Residual CPL | Residual em |
|---|---|---|---|---|
| 30% | 96 | 212 | **31.2** | 15.7 |
| 35% | 112 | 196 | **28.9** | 14.5 |
| 40% | 128 | 180 | **26.4** | 13.3 |
| 50% | 160 | 148 | **20.7** | 11.0 |

Every one of those is below 35 CPL. At 40–50% the residual lands in **Bringhurst's 12–15 CPL marginal-note band** — that is not a text column, it is a caption rail.

**macOS with rail, content = winW − 345:** 900 → 555px → **86.7 CPL**; 1280 → 935px → **148.8 CPL**; 1600 → 1255px → **199.5 CPL**. The desktop card body **already exceeds the WCAG 80-CPL ceiling at any window wider than ~854pt** and is 2× Bringhurst's maximum at a normal 1280 window. On desktop, a float does not endanger the measure — it *repairs* it. A 40% float at a 1280 window leaves ≈549px ≈ **86 CPL**, still past the ceiling.

---

## 5. What real products use for this exact decision

- **CSS-Tricks, "Minimum Paragraph Widths in Fluid Layouts"** is the closest thing to a published rule, and it is font-relative: a zero-height `p::before { content:""; width: 10em; display:block; overflow:hidden; }` so that "if the space left by the floating image is below this width, then the whole paragraph moves down underneath the image." It presents this as *better* than the `@media (max-width: 400px) { img { float: none } }` alternative precisely because it works for arbitrary image widths without a viewport breakpoint. **10em ≈ 21 CPL in Newsreader** — an absurdity guard, not a comfort threshold.
- **Viewport media queries** (`float: none` below 400–600px) are the common shipping practice, per the same article and MDN's floats guidance. These are viewport-based, not measure-based, and therefore wrong in a card-in-a-rail layout like this one, where viewport width and text width differ by 345pt.
- **Baymard and Material** both express the constraint font-relatively (`70ch`/`34em`; 40–60 CPL), supporting the em/ch form over px.
- **`float_column` v4.1.3** — the package the terrain survey identifies as the only mature Flutter float-wrap implementation — exposes `float`, `clear`, `clearMinSpacing`, `margin`, `padding`, `maxWidthPercentage`, and **no minimum-residual-width or auto-clear-if-too-narrow option**. Whatever rule this app adopts, the app owns it; the layout engine will not enforce it.
- I could **not** find any published editor (Medium, Notion, Substack, Gutenberg) that states a numeric threshold for demoting a wrapped image to a block. Gutenberg exposes `alignleft`/`alignright` and leaves the responsive behaviour to themes; theme breakpoints in the wild are 600/767px viewport values with no stated derivation. **No product-published number exists for this decision.** Anyone citing one is citing a theme default.

---

## 6. The rule I would put in the spec

> **R-FLOAT-DEMOTE.** An image may float only when the residual text band is at least **40 characters** wide. Below that, the image demotes to a full-width block.
>
> Evaluate as: `residualWidth >= 19.4 * effectiveBodyFontSize`, where
> - `residualWidth = containerWidth - imageWidth - gutter`, taken from a `LayoutBuilder` at the note-body boundary;
> - `effectiveBodyFontSize = TypographyTokens.bodySerif.fontSize * MediaQuery.textScalerOf(context).scale(1)` (or the composer style in the editor) — **never the token constant alone**;
> - **19.4** is the measured Newsreader-Variable constant for 40 CPL and is valid for any size and any text scale. It must be re-measured if the body family changes.
>
> Target, not gate: a residual of **21.8 em (45 CPL)** or more is comfortable; 19.4–21.8 em is tolerable; below 19.4 em demote.

**Derivation chain:** Bringhurst 40–50 CPL multi-column / "below 38–40 it breaks down" → 40 CPL floor → measured Newsreader prose width 0.4587 em/char → binary-searched against real line breaking (which adds ~6% rag overhead: 40 CPL costs 6.55px/char at 13.5, vs 6.19px/char of pure glyph width) → 19.4 em → verified scale-invariant at 0.9/1.0/1.15/1.5/2.0 and at both 13.5 and 19.

**Steps where I estimated, and did not measure or source:**

1. **The 12pt gutter** in the residual table is my placeholder. The app has no float gutter token. Whatever the spec picks must be subtracted before the comparison.
2. **No source exists for a float residual specifically.** I am transferring Bringhurst's multi-column floor to a band beside an image. A wrap band is arguably *harsher* than a real column — rag against a hard image edge is more visible, and the band is only a few lines tall so the rag never averages out — which argues the true floor is above 40 CPL, not below. I have no evidence for how much above, so I did not pad it.
3. **0.4587 em/char is English prose.** Markdown syntax characters, other languages, and heavy punctuation shift it. CJK would need the WCAG 40-glyph rule instead and a separate measurement.
4. **The 520–560 provenance guess** (a desktop 16–18px sans full-column number) is inference from the arithmetic, not something I traced to a document.

---

## 7. What the rule actually decides here, which the spec must confront

Applying R-FLOAT-DEMOTE to the code as it stands:

- **Phone: every float demotes.** To clear 19.4 em (262px) residual plus a 12pt gutter on a 390pt phone (320pt content), the image would have to be ≤46pt wide — smaller than the existing 56pt `InlinePhotoStrip` thumbnail (`photo_strip.dart:19`). The gate is unsatisfiable at current card geometry. On a 430pt phone the ceiling is 86pt. Neither is a scrapbook image.
- **macOS: no float ever demotes,** and the un-floated body is already 87–200 CPL, i.e. already past the accessibility ceiling.

So the rule as derived is not a breakpoint — it is a statement that **float-wrap is a wide-container feature, and this app's phone card is not a wide container.** Three ways out, all spec decisions rather than research findings: cap the feed column so desktop stops running to 200 CPL (which also creates a real tablet/desktop band where floats work), shrink the phone card chrome (70pt of the 390 is padding — recovering it buys ~11 CPL, not enough), or accept phone = block-only and say so explicitly.

**Is a precise number defensible?** Yes for the *floor* — 40 CPL / 19.4 em is traceable to a named source and a reproducible measurement. What is **not** defensible is any claim that a specific number is the *comfort* threshold for wrap specifically; the literature does not cover that case, and I'd write the 45-CPL target into the spec as a preference with its provenance stated, not as a gate.

---

## 8. Implementation facts the rule depends on

- `lib/` contains **zero width-based branching** — both resolvers switch on `TargetPlatform` (`shell_layout.dart:5-9`, `today_layout.dart:7-11`), and the two `MediaQuery` reads are `accessibleNavigation` and `disableAnimations`. A `LayoutBuilder` at the note-body boundary is new infrastructure.
- `textScaleProvider` (`lib/state/settings_providers.dart:7-22`, values 0.9/1.0/1.15) has **no production consumer**. If the rule reads the token `fontSize` rather than the effective one, it is correct today and silently wrong the day that provider is wired up.
- `media_blobs.width`/`height` are NULL for every photo ever stored (`image_picker_photo_picker.dart:35` passes neither), so `imageWidth` in the rule cannot come from the database today — it must be a layout-time decision or the capture sites must be fixed first.

---

**Sources:**
- [Line length — Wikipedia](https://en.wikipedia.org/wiki/Line_length) (Bringhurst 1992, Tinker & Paterson 1929, Dyson & Haselgrove 2001, Dyson & Kipping 1998, Shaikh 2005, Ling & Van Schaik 2006)
- [Line length — Butterick's Practical Typography](https://practicaltypography.com/line-length.html)
- [Understanding SC 1.4.8 Visual Presentation — W3C](https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-visual-presentation.html)
- [Readability: The Optimal Line Length — Baymard](https://baymard.com/blog/line-length-readability)
- [The influence of reading speed and line length on the effectiveness of reading from screen — Dyson & Haselgrove, ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S1071581901904586)
- [Minimum Paragraph Widths in Fluid Layouts — CSS-Tricks](https://css-tricks.com/minimum-paragraph-widths/)
- [Floats — MDN](https://developer.mozilla.org/docs/Learn_web_development/Core/CSS_layout/Floats)
- [Typography — Material Design 3](https://m3.material.io/styles/typography/applying-type)
- [float_column `float_data.dart` — GitHub raw](https://raw.githubusercontent.com/ronjb/float_column/main/lib/src/float_data.dart)

---

## Judge rankings

**Lens: Product owner who must live with this daily: does it deliver the scrapbook feel, does the compaction work the way I desc**

| Rank | Design | Score | Fatal flaws |
|---|---|---|---|
| 1 | DESIGN 1: One String, Two Renderers | 86 | Its biggest risk is real and it is the one a constant cannot absorb: RenderEditable relayouts the whole paragraph per keystroke, desktop already measures 14ms at 20k chars, and its own noteSourceLimit |
| 2 | DESIGN 6: One String, Two Slices | 76 | Cross-segment drag-selection is gone - in a writing app, that is a thing I hit on day one and every day after, and Select-All is not a substitute for dragging from the paragraph above a photo to the o |
| 3 | DESIGN 4: Cold Wrap | 70 | No cross-block text selection while editing. In a writing app. Hit daily, and it is the direct price of the roaming-editable bet. No captions in v1 - in a SCRAPBOOK, in an app that already ships Cavea |
| 4 | DESIGN 2: Tuck | 63 | The entire editor photo experience rests on a U+E000 sentinel inside a live EditableText whose survival through Gboard is explicitly unmeasured by the survey and unmeasurable on this machine - and R1  |
| 5 | DESIGN 3: One String, One Measure | 55 | A hard 8,000-character cap with paste truncation, in a journaling app. It says so itself - 'a visible, annoying failure in an app whose entire job is capturing text'. That is a product wound I would f |
| 6 | DESIGN 5: Two Renderers, One Buffer | 44 | It takes the most dependencies of any design - float_column plus markdown plus a drift/drift_dev bump plus a new note_drafts table - and then uses almost nothing float_column's 3000 lines buy, because |

Ideas grafted:

- from **DESIGN 2: Tuck**: The live mini-diagram on the photo's placement control, showing what the READ view will do at this screen's current width - e.g. 'Right . Medium - on this screen, text sits above and below'. — R1 means the editor and the reader show two different pictures of the same note, and Design 1 correctly names that as the single biggest thing it gives up. This is the only mitigation anyone proposed that actually addresses it: it teaches the demotion rule at the moment of placement instead of letting it surprise people at read time. It costs one small widget driven by the same decideFloat function the renderer already calls, so it cannot drift from the real behaviour. Graft it onto the photo rail's Side/Size controls.
- from **DESIGN 2: Tuck**: Bound the Today feed by construction: each card renders a preview (first ~1200 chars of source plus the first photo, with a fade and 'Read more'), with the full note reading in day detail. — I verified today_entry_feed.dart:68 is a non-lazy Column inside a SingleChildScrollView - every entry card in a day builds eagerly. Design 1 names this as a cost that 'becomes a real cost before it becomes an obvious one' but does nothing about it. This makes per-card layout O(1) regardless of note length and is the only structural answer to the unmeasured Android scroll cost. Design 4's lazy feed is the complementary half and should be taken with it.
- from **DESIGN 2: Tuck**: Shrink-before-demote: treat the stored width as a REQUEST and let the solver be the authority - photoW = min(frac * col, col - gutter - 19.4em), then demote only if the result falls below a minimum useful photo width (~11em). — My worded requirement was that the photo SHRINKS AND MOVES. Design 1's binary gate at the requested fraction makes a narrowing macOS window jump from float to block; this makes it compact continuously and then block, with no breakpoint and no visual jump. It is one clamp replacing one multiplication. Design 5 derives the same solver independently, which is corroboration.
- from **DESIGN 4: Cold Wrap**: Ship the editor as an interface with two implementations from day one - the single-buffer editor as default and a block-scoped editor behind a flag - and make the block split on blank lines so keystroke cost scales with the focused block (~300 chars) rather than the document. — Design 1's biggest risk is the only one it admits a constant cannot absorb, and its stated fallback is 'a different design'. That is unacceptable as a plan. Design 4 proves the fallback is a swap of one widget when the parser already yields blocks with source ranges - which Design 1's parseNote and Design 3's sourceRange both already provide. Building the seam up front converts Design 1's single unhedged risk into a flag flip, and the Android measurement Design 1 schedules against unit 3 then has somewhere to land.
- from **DESIGN 4: Cold Wrap**: Make the read surfaces lazy, and add the native downscale arguments to the picker: pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 88). — Three arguments that cut blob size, write time, Android decode cost and image-cache bytes at once, with zero new dependencies, on a call site that today passes no options at all. Combined with cacheWidth on every MediaImage (which Designs 1, 3, 5 and 6 all correctly identify as absent from lib/ today), this is the cheapest performance work available and it lands before any of the risky units.
- from **DESIGN 6: One String, Two Slices**: Solve the canonical width and the body type size together and commit to both: 560pt measure at 16pt Newsreader, height 1.6, with the same style in the composer so editor line breaks equal read-view line breaks character for character. — Design 1 recommends 13.5 to 16 but makes it optional, which leaves the door open to shipping a 472pt column of 13.5pt serif with a 45-CPL float band beside it. Design 4's argument closes that door: at 13.5 an 80-CPL column is 509pt and no useful float fits, so the type change is what makes the rule solvable rather than scope creep. Design 6 shows the arithmetic both ways and sets kMaxFloatFrac exactly where the band lands on the 40-CPL floor. Take the number, take the derivation, and make it a requirement rather than a recommendation.
- from **DESIGN 3: One String, One Measure**: The verification regime: prove the responsive rule with a ~360-row pure-function table test over (width x scale x fraction x side), and use a dozen goldens only to prove a correct plan gets painted. Plus the parser losslessness property - assert concat(source[block.range]) == source over a corpus. — The survey's critic asked what verification regime the design must be buildable against and nobody answered it in the abstract - Design 3 answered it concretely. This repo has 204 test files and exactly five goldens; a golden matrix across widths and scales will never be adopted here, a table test can be adopted tomorrow. Pair it with Design 6's partitionSource equality (parts.join('') == src) and the parser becomes provably lossless with one test rather than a corpus of hope.
- from **DESIGN 6: One String, Two Slices**: If 'discard my changes' has to come back, restore it with Design 6's single-slot file draft (raw source string in <appDocuments>/drafts/, 400ms debounce, temp-file-then-rename, drafts directory as a GC root) rather than a table - and surface restoration with Design 2's inline 'Unsaved draft restored . Discard' chip, never a modal. — Design 1 deletes the draft concept entirely, which is its cleanest move and also the one place it makes a product ruling I did not make. If I want the discard gesture back, this is the cheapest way to get it: zero schema, zero DAO, zero drift bump, nothing in the settings KV table that delete-all cannot clear and GC cannot see. Designs 3, 4 and 5 all pay a migration and a drift/drift_dev bump for the same capability, which R3 explicitly told them not to do.
- from **DESIGN 3: One String, One Measure**: Clamp the float box height to min(w/aspect, 1.6*w) with BoxFit.cover so a 9:16 portrait cannot become a wall, and when tilt is applied, reserve w + h*sin|theta| so the layout rectangle stays axis-aligned and reflowable. — Design 1 mentions a decorative tilt is available but says nothing about the geometry, and nothing at all about extreme aspect ratios. Design 3's two clamps are the difference between a scrapbook and a note that reads as a column of single words beside a panorama. They also let the tilt-and-frame treatment survive without the wrap contour ever becoming non-rectangular.
- from **DESIGN 2: Tuck**: Decode dimensions at pick time as a deliberate HEIC canary: a photo that will not decode fails loudly at pick, not silently at read. — Every design populates media_blobs.width/height at pick time to stop the float box reflowing on first frame, which is right. Design 2 is the only one that notices the same decode doubles as an import-time validity check on the one format the survey flags as unverified on Android. Failing at the picker, where the user is already waiting and can choose another photo, beats a correctly-shaped hole containing a corrupt placeholder at read time.

**Lens: The engineer who has to build this, ship it in increments, and maintain it for two years. I weighted: (1) is the riskies**

| Rank | Design | Score | Fatal flaws |
|---|---|---|---|
| 1 | Design 6: One String, Two Slices | 84 | The segment editor's cross-boundary input plumbing — backspace-merge, arrow traversal, focus handoff between adjacent TextFields — is hand-built, stateful, framework-adjacent, and has no package, no p |
| 2 | Design 4: Cold Wrap | 79 | UNDO IS HAND-WAVED. The anchor section asserts 'Undo restores it' and the design never mentions an undo stack — not in GIVES UP, not in BREAKS WHEN, not in BIGGEST RISK. With N TextFields there are N  |
| 3 | Design 2: Tuck | 73 | The U+E000 sentinel inside a live EditableText with Gboard is the single most unmeasured mechanism in all six designs, and D2 stakes its entire headline editor experience on it. Its own biggest-risk s |
| 4 | Design 1: One String, Two Renderers | 69 | The span-slicing hole sits at the exact feature the project exists for. The read renderer supports inline bold, italic, code and strike, but PhotoWrapBlock emits `Text(head)` and `Text(tail)` — plain  |
| 5 | Design 3: One String, One Measure | 63 | An 8,000-character hard cap with the paste TRUNCATED at the cap, in a journaling app. That is not a degradation, it is data loss at the moment of capture, and 8,000 characters is roughly three pages — |
| 6 | Design 5: Two Renderers, One Buffer | 55 | Takes the most risk of any design for the least return. It is the only one stacking WidgetSpan-in-EditableText AND float_column AND package:markdown AND a schema migration AND a drift_dev bump; every  |

Ideas grafted:

- from **Design 4: Cold Wrap**: Ship NoteEditor as an INTERFACE with two implementations behind a flag, in the same build unit as the segment editor: SegmentNoteEditor (default) and SingleFieldNoteEditor (one TextField over the whole source, photo as a dimmed one-line token plus a thumbnail rail). D6 describes this retreat in prose; D4 constructs it. — D6's own biggest risk is the cross-boundary input plumbing, and it is the one part of the design that cannot be settled from this machine — no Android SDK, no way to test Gboard swipe-typing across a merge, no golden image that can prove focus handoff. A prose retreat costs a rewrite under pressure; a flag costs a boolean. Because storage, parser, read renderer, wrap, drafts and GC are all ignorant of how the text got typed, the seam is nearly free to build and it converts D6's single unmeasured bet into a reversible one.
- from **Design 4: Cold Wrap**: Make planWrap/decideFloat a pure function cached in a process-wide LRU keyed by (entryId, updatedAt, columnWidth.round(), (scale*20).round(), photoIndex), and make the build method's DEFAULT branch on a miss `schedulePlan(key); return StackedLayout()`. Then route every other failure — corrupt photo, unparseable token, missing intrinsic dimensions, extreme aspect ratio, device over budget — into that same stacked branch. — This is the best robustness idea in all six designs and it is the answer to the brief's 'no Android performance measurement exists.' Jank stops being a tuning problem and becomes structurally impossible: the worst case is one unfloated frame. More importantly it collapses six distinct failure modes into ONE path that every phone exercises on every note forever, so the fallback is proven in production long before a slow desktop device needs it. D6 has the pure function already (decideFloat); it is missing the cache and the unification. Add nearestFor stale-while-revalidate too, or a macOS window drag flickers between stacked and floated.
- from **Design 4: Cold Wrap**: Make the read surfaces lazy as a named build unit that lands BEFORE the Markdown renderer, not after. Today's Today feed is a non-lazy Column inside a SingleChildScrollView (verified at today_entry_feed.dart:68-80 / today_screen.dart:73) that builds every entry in the day eagerly. — Five of the six designs ship a strictly heavier note renderer into a feed that builds every card in one frame, and only D4 fixes it as a unit. Landing a parser, a span builder and a TextPainter-based wrap into an eager feed is how a design that measured fine in isolation becomes a janky app. Doing it first also means the later performance unit measures the real structure instead of an artifact.
- from **Design 2: Tuck**: Render a bounded PREVIEW in the Today card — roughly the first 1200 characters of source plus the first photo, with a fade and 'Read more' — and read the full note in day detail. — It bounds per-card cost to O(1) regardless of note length, which is a stronger guarantee than caching because there is nothing left to cache. Combined with the laziness graft it retires the entire unmeasured-Android scroll risk by construction rather than by a budget knob nobody has the hardware to calibrate. It is also the better product: a feed of full-length illustrated notes is not a feed.
- from **Design 2: Tuck (also Design 5)**: Shrink before demoting: pw = min(sizeEm*em, col - gutterEm*em - minTextEm*em), then float if pw >= minPhotoEm*em, else block. One clamp instead of computing photoW = fraction*column and testing the residual. — D6 computes imageW from frac and clamps only at kMinFloatWidth, so narrowing a macOS window produces a discontinuous jump from floated to stacked. The clamp makes the photo shrink continuously until it genuinely cannot float, which is both better-feeling and strictly closer to the owner's worked example ('shrink AND move'). It is one line and it changes nothing else in the rule.
- from **Design 3: One String, One Measure**: Adopt the four framework-landmine defences verbatim: assert(span.toPlainText().length == value.text.length) inside buildTextSpan; a grep-style test that FAILS THE BUILD if `recognizer:` appears under the editor directory; spellCheckConfiguration left null and stylusHandwritingEnabled:false, with the reason recorded (EditableTextState.buildTextSpan short-circuits past the controller override in both states and all styling vanishes mid-composition); and reapply the IME composing underline by hand, because overriding buildTextSpan drops it. — The survey is explicit that the framework fires NO assertion when span length and value length disagree — it just silently miscomputes every caret and delete offset past the break. That is the worst failure signature possible: no crash, no exception, no test failure. D6's markers-stay-visible design makes the invariant true by construction, but the assert is what keeps it true through two years of edits by someone who does not know why it matters. The recognizer grep test and the two short-circuit settings are the same kind of cheap insurance against a defect that is invisible on macOS and cascades on Android.
- from **Design 3: One String, One Measure**: Prove responsiveness with a pure-function decision TABLE — a few hundred rows of (width, font size, scale, fraction, side) → expected plan, running with no render tree — and keep goldens to roughly a dozen that only prove a correct plan gets painted. — This repo has 204 test files and exactly 5 matchesGoldenFile call sites. A width-by-scale-by-side golden matrix is not a regime it can sustain, and Design 4's proposed 48 goldens is already past what anyone will keep green. D6's decideFloat is already the right shape for this; it just needs the table named as the acceptance artifact so the responsive rule is pinned by arithmetic rather than by images someone will eventually bulk-regenerate.
- from **Design 3: One String, One Measure (also Design 2)**: Split at a real line boundary — walk computeLineMetrics() for the last line whose bottom <= floatHeight, or use getLineBoundary(getPositionForOffset(...)).start — rather than a raw offset or a word-boundary snap. — D6 says 'line-snapped split' but does not say how, and it is the one place in the whole wrap where getting it approximately right looks visibly broken: a line that straddles the photo's bottom edge either re-breaks when the head is re-laid-out or leaves a ragged stub beside the image. computeLineMetrics is the rigorous version and costs nothing extra, since the TextPainter is already laid out.
- from **Design 1: One String, Two Renderers**: Keep media garbage collection MANUAL — a Settings → Data → Reclaim space action — rather than wiring it to app launch or media-provider init. — This is the sharpest single argument in any of the six and four designs got it wrong. In every design the photo reference lives in text the user can hand-edit. Break a photo line and the reconcile drops its entry_photos row; an automatic startup sweep then takes the bytes before the user can fix the typo. That is silent data loss, and the cost of avoiding it is orphan blobs occupying disk until someone taps a button. D6 already adds the drafts directory as a GC root — it should not also pull the trigger automatically.
- from **Design 5: Two Renderers, One Buffer**: Carry the measured package-rejection dossier into the spec as an appendix: float_column, hyper_render, super_editor, live_markdown_editor, markdown_editor_live, flutter_smooth_markdown, markdown_editor_plus, flutter_markdown_plus — each with the measured reason it was rejected. — Six designs independently concluded hand-rolled beats every package for a restricted placement model. That conclusion will be re-litigated by the next engineer, or by this one in four months when the wrap has a bug. D5 already did the work, including the non-obvious findings (markdown_editor_live mutates the buffer and hard-codes Image.network so it cannot render a single file-backed blob; live_markdown_editor requires an SDK newer than this machine's). Writing it down once is cheaper than discovering it twice.
- from **All six**: Move the on-device Android measurement from the last build unit to immediately after the editor unit, and give it three named numbers: sentinel-free keystroke cost in a 20k-character note, first-layout cost for a wrapped note, and a scroll frame over a feed of note cards. — Every one of the six schedules this last, and three of them say in their own biggest-risk section that it must come first. The measurement is the only thing that can retire the single unmeasured risk all six share, and it is the only result that can still change the design cheaply — after unit 7 it can only confirm or condemn. This is not a graft from one design so much as the correction all six need.

**Lens: Hostile: which of these is still standing in six months, on a mid-tier Android phone, maintained by one person who did n**

| Rank | Design | Score | Fatal flaws |
|---|---|---|---|
| 1 | DESIGN 1: One String, Two Renderers | 84 | The editor photo experience is the worst in the set and the design understates it. The user sees the literal source line `![alt](photo/<64-hex-mediaId> "right medium")` as a 'tinted mono chip'. That i |
| 2 | DESIGN 6: One String, Two Slices | 75 | It hand-builds the typing loop, and its own author names this as the biggest risk: Backspace-merge at offset 0, arrow-key traversal via getPositionForOffset at the caret's x, and focus handoff between |
| 3 | DESIGN 2: Tuck | 67 | It bets the entire editor photo experience on a U+E000 private-use sentinel surviving Gboard's composing region, on a device nobody has tested, and the survey flags this as explicitly unmeasured. The  |
| 4 | DESIGN 3: One String, One Measure | 64 | All that discipline is spent defending a bet it should not have taken: a WidgetSpan for character 0 plus an (L-1)-character fontSize:0 run inside the LIVE editable. The assertion catches the case wher |
| 5 | DESIGN 4: Cold Wrap | 56 | It gives up cross-block text selection WHILE EDITING. Not in the reader — in the editor. You cannot drag a selection from block 3 into block 5 in a note you are writing. In a note-taking app this is n |
| 6 | DESIGN 5: Two Renderers, One Buffer | 52 | It stacks more independent risk classes than any other design, and the brief's ranking criterion is exactly that count. (1) A bus-factor-1 dependency under the core UX pillar, whose anchor model relie |

Ideas grafted:

- from **DESIGN 4: Cold Wrap**: Ship NoteEditor as an interface with two implementations behind a flag from day one, before the risky editor is built — not as a paper retreat described in a BREAKS WHEN section. — Design 1's own stated biggest risk is the one thing a constant cannot absorb: if mid-tier Android keystroke cost in a long live-styled single buffer is unacceptable, 'the single-buffer editor has to become a per-paragraph block editor, and that is a different design'. That is a rewrite discovered after unit 5 has shipped. Design 4 builds the seam first, at near-zero cost, because storage, parser, read renderer, wrap, drafts, photos and GC all genuinely do not know how the text got typed. Graft the seam, not Design 4's block editor: keep Design 1's single field as the default and let the Android measurement, run against unit 3 the week it lands, decide whether the second implementation is ever needed.
- from **DESIGN 6: One String, Two Slices**: Partition the source into segments so a photo line becomes a real PhotoSegmentCard widget between TextFields, with the actual photo visible in place — no WidgetSpan, no sentinel, no rail. — This directly fixes the winner's worst flaw. Design 1's editor shows `![alt](photo/<64-hex-mediaId> "right medium")` as visible source — 80+ characters wrapping across multiple lines per photo, unfixable within its own length-preserving invariant, with the real image exiled to a rail below. Design 6 proves you can render the photo where it sits WITHOUT putting a widget inside an editable. Graft it as the considered upgrade path rather than unit 5's default, because it imports Design 6's cross-segment Backspace-merge, arrow traversal and focus handoff — which is real hand-built work in the typing loop, not the '~80 lines' claimed. Sequencing: ship Design 1's rail first so the feature is usable, then evaluate segmentation as the same flag-gated alternative the Design 4 seam already creates. Also graft Design 6's `parts.join('') == src` fuzz equality as the losslessness proof either way.
- from **DESIGN 3: One String, One Measure**: Compute the effective body size as MediaQuery.textScalerOf(context).scale(fontSize), never scale(1) * fontSize, and add assert(span.toPlainText().length == value.text.length) in buildTextSpan plus a build-failing grep test banning `recognizer:` in the editor. — The scaler point is a live correctness bug in the winner and in four of the other five: Android 14+ font scaling is non-linear, so scale(1)*fontSize is not scale(fontSize), which means the 19.4em demotion gate silently computes against the wrong number at exactly the accessibility sizes where the gate matters most. I confirmed grep for textScaler over lib/ returns zero hits, so whatever is written here is what the app will have forever. The assertion costs one line and guards the one invariant the survey proved fails with takeException()==null — cheap insurance even in a design with no WidgetSpans, because the next person to add one will not know. The recognizer grep test is the only defence against a hard limit that is invisible on macOS and produces 23 cascading render-tree exceptions on Android.
- from **DESIGN 2: Tuck**: Shrink-before-demote — pw = min(sizeEm*em, col - gutter - minTextEm*em) — plus a live mini-diagram in the placement control showing what the read view will do at this screen's width, and getLineBoundary(...).start as the split point. — Three independent fixes to the winner. Shrink-before-demote makes the desktop-to-phone and window-drag transitions continuous instead of a cliff between a fixed fraction and a block, and it is one clamp. The mini-diagram is the only answer anyone proposed to the genuine UX hole R1 creates — the editor and reader show different pictures — and Design 1's GIVES UP section concedes 'the owner should picture it before unit 5 lands', which is exactly what the diagram does for the user on every placement. Snapping the split to a line boundary rather than the raw getPositionForOffset result is a correctness detail: a mid-line cut is the one way the wrap can look visibly broken, and Design 1 specifies the raw offset.
- from **DESIGN 6: One String, Two Slices**: A shared plainTextOf(source) projection wired into the search haystack, the search preview, the On-This-Day preview and the note snippet; plus a file-backed single-slot draft with barrierDismissible:false. — I verified search_day_view.dart:76-90 concatenates raw textContent into the search index and _previewFor:63-70 takes the first line verbatim, so without a projection the winner ships markdown syntax and 64-hex photo tokens into search results and On-This-Day cards — a defect Design 1 never mentions. Separately, Design 1's no-draft model removes 'discard my changes' and deletes the edit path's existing confirmation dialog, so a stray edit to a real note is permanent; Design 6's drafts/<key>.md file plus barrierDismissible:false restores discard AND fixes the stray-tap loss with no table, no DAO, no settings-KV orphans and no schema change, preserving the winner's zero-migration property exactly.
- from **DESIGN 5: Two Renderers, One Buffer**: Reveal-at-caret: render the line containing the selection as raw source, and the test blast radius called out by name. — Keep this in the drawer rather than shipping it now. Design 1 chose permanently visible markers to delete a bug class, which is the right call under a hostile lens, but it is a real legibility trade the owner may reject once they see `**bold**` everywhere. Reveal-at-caret is the upgrade that recovers clean prose without reintroducing the caret-inside-a-collapsed-run problem, because arriving at a collapsed run reveals it — and it needs no WidgetSpan, so it is compatible with the winner's posture. Also graft Design 5's specific test-breakage list: note_body_test.dart:25-29,34-36 finds the note by literal string and asserts a single Text with fontFamily == TypographyTokens.serif, which any span renderer fails at both the finder and the assertion. The winner should name that in its build order instead of discovering it.

---

## The synthesis: One String, Two Renderers, One Fallback

**Thesis.** The note is one Markdown string and a photo is one short line inside it — so anchoring, reflow, ordering and undo are the text buffer's rather than ours — and every layout decision on every surface is one clamp in ems that either produces a float or produces the single stacked layout that also absorbs every corrupt photo, unknown token, narrow column and slow device.

### Storage

NO SCHEMA CHANGE, and that is a finding rather than a constraint — R3 freed the schema and I looked for a use and did not find one. `entries.text_content` (verified TEXT NULL, one column, one production consumer at entry_card.dart:136 -> NoteBody) holds the whole note as CommonMark source and is the only authority for body AND placement.

PHOTO LINE: `![alt](photo/7f3ac91b2d4e "right medium")` on its own line. Valid CommonMark — the destination is an ordinary relative path, the attributes ride the title slot — so another renderer shows the alt text and a broken image rather than garbage.

THE REFERENCE IS A 12-HEX PREFIX OF THE SHA-256, NOT THE FULL DIGEST. This is the one place I changed the base design's data format, and it exists to fix the flaw the hostile lens identified as its worst: a length-preserving span styler cannot collapse 64 hex characters into a chip, so the base design's editor would show 80+ literal characters per photo, forever, wrapping across lines. At 12 hex the whole line is 38 characters — half a line at a 72-CPL measure — which a dim mono run genuinely can style as a chip. Resolution is `SELECT id FROM media_blobs WHERE id LIKE '<prefix>%'` (prefix match uses the TEXT primary-key index in SQLite); at insert the prefix is extended in 4-char steps until unique among existing blobs. 48 bits against a personal journal gives a future-collision probability around 2e-10 at 10k photos, and the failure is loud (exactly-one-match, else a visible broken-photo chip), never a silently wrong photo. `media_blobs.id` keeps the full digest; content-addressing and dedup are untouched.

`entry_photos` (verified mediaId / sortOrder / deletedAt, lib/data/database/tables.dart:36-40) survives unchanged in shape and changes meaning: it is a DERIVED reachability index, replaced transactionally on every save from the mediaIds found in the source, sortOrder = order of first appearance. `media_blobs.width`/`height` (tables.dart:55-56, nullable, NULL for every photo ever stored) are populated at pick time — the break in the chain is exactly one function, `photoCaptureFromXFile` (image_picker_photo_picker.dart:30-36), which builds `CaptureFile(file:, mime:)` and drops them; `MediaStore.putFile(width:, height:)` already exists downstream.

Drafts are FILES, not rows: `<appDocuments>/drafts/<entryId|new-YYYY-MM-DD>.md` holding the raw source, written temp-file-then-rename. Not the `settings` KV table (invisible to delete-all and to GC). schemaVersion stays 1, the throwing `onUpgrade` stays exactly as it is, and drift/drift_dev stay pinned — no migration, no generated snapshots, no 2.35.0 bump, and no destructive drop-and-createAll left in the tree as a footgun after R3's disposable-data window closes.

### Editor surface

`NoteEditor` IS AN INTERFACE WITH TWO IMPLEMENTATIONS FROM THE DAY IT LANDS. All three lenses grafted this and they were right: the base design's own biggest risk was the one it admitted a constant could not absorb, with the stated fallback being 'a different design'. A prose retreat costs a rewrite under pressure; an interface costs a boolean. Storage, parser, read renderer, wrap, drafts, photos and GC genuinely do not know how the text got typed, so the seam is nearly free.

DEFAULT — `SingleFieldNoteEditor`. One `TextField` (replacing the raw `EditableText` at text_composer_sheet.dart:293, which today passes neither `selectionControls` nor `contextMenuBuilder`, so Flutter disposes the selection overlay: no handles, no copy/paste toolbar, no painted selection — all three come back for free) driven by `MarkdownStyleController extends TextEditingController` overriding `buildTextSpan`. LENGTH-PRESERVING BY CONSTRUCTION: nothing is added, removed or collapsed. No WidgetSpan, no U+E000 sentinel, no fontSize:0 run, no `TextSpan.recognizer`. Markers stay VISIBLE and de-emphasised (Palette.ink34) rather than hidden — that one constraint deletes the 0.3px twin-caret artifact, the caret-inside-a-collapsed-run class, and flutter#107432 / #96147 / #159171 / #90355 / #187598 all at once, because there is no inline object in the editable at all.

FOUR FRAMEWORK-LANDMINE DEFENCES, verbatim: (1) `assert(span.toPlainText().length == value.text.length)` inside `buildTextSpan` — the framework fires nothing when this breaks (measured valueLen=7/plainLen=5, takeException()==null) and every caret and delete offset past the break is then silently wrong; the invariant is true by construction here, and the assert is what keeps it true through two years of edits by someone who does not know why it matters. (2) A grep-style test that FAILS THE BUILD if `recognizer:` appears under the editor directory — the defect is invisible on macOS and cascades into 23 render-tree exceptions on Android. (3) `spellCheckConfiguration` left null and `stylusHandwritingEnabled: false`, with the reason recorded: `EditableTextState.buildTextSpan` short-circuits past the controller override in both states and all styling silently vanishes mid-composition. (4) The IME composing underline is reapplied by hand over `value.composing`, because overriding `buildTextSpan` drops it.

A photo line styles as a dim mono chip; the actual image lives in `PhotoRail`, a horizontal thumbnail strip under the writing surface that highlights the thumbnail whose source line contains the caret and carries visible tap-only controls — Side (Left|Right), Size (S|M|L|Full), Move up, Move down, Replace, Remove, Caption. No drag anywhere, so WCAG 2.2 SC 2.5.7 passes by construction and nothing races Android's scroll recogniser. The rail carries a LIVE MINI-DIAGRAM driven by the same `planFloat()` the renderer calls, so it cannot drift from real behaviour: 'Right · Medium — on this screen, text sits above and below.' That is the only mitigation anyone proposed for the genuine hole R1 opens, and it teaches the demotion rule at placement instead of surprising people at read time. Caption editing lives in a modal sheet rather than inline, so the composer tests' `tester.widget<EditableText>(find.byType(EditableText))` cast never sees two editables.

NO PASTE TRUNCATION. The base design's `LengthLimitingTextInputFormatter(16000)` truncates a pasted transcript in an app whose entire job is capturing text; two lenses flagged it and I am not shipping it. There is ONE soft threshold, `liveStyleLimit = 6000`, past which `buildTextSpan` returns a single plain span — live styling switches off, the read view stays fully rendered, and nothing is ever destroyed.

SECOND IMPLEMENTATION — `SegmentNoteEditor`, built only if U6's measurement demands it: `partitionSource(src)` returns parts with `parts.join('') == src` byte-exact, text parts as TextFields and photo lines as a real `PhotoSegmentCard`, so keystroke cost scales with the focused segment rather than the document. It is deliberately NOT the default: two of three lenses ranked the single buffer above it for the same reason, which is that its cross-boundary plumbing (Backspace-merge at offset 0, arrow traversal via `getPositionForOffset` at the caret's x, focus handoff) is hand-built, stateful, ungoldenable, sits in the path of every keystroke at a boundary, and costs cross-segment drag-selection in a writing app.

Also fixed here because it is measured and free: the composer panel gets `EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)` (44.8% of the writing area is under the keyboard on a 360x640 phone today) and the hard `SizedBox(height: 440)` becomes `Flexible`.

### Read renderer

`parseNote(String source) -> List<NoteBlock>` — a hand-rolled line classifier plus a single-pass inline tokenizer, ~200 lines, closed set: Paragraph, Heading(1-3), Bullet, Number, Quote, Code, Divider, Photo; inline bold, italic, code, strike, link. Hand-rolled rather than `package:markdown` for one concrete reason that is not preference: the SAME parser drives the editor's live styling, which needs source offsets for every run, and `package:markdown` produces an AST without inline source spans. One grammar, two consumers, so what is bold while typing can never disagree with what is bold when reading — the alternative ships two implementations and calls the disagreement cosmetic, which it is until the first six months of patches. Every block carries a `sourceRange`, and the losslessness proof is one property test over a fuzz corpus: `concat(source[b.range]) == source`.

`NoteDocument` is a `Column` of boring block widgets under ONE `SelectionArea` (the app has none today). `plainTextOf(source)` is the shared projection wired into the search haystack (verified: search_day_view.dart:86-90 concatenates raw `textContent`), the search preview (`_previewFor`/`_firstLine`, :63-95) and the On-This-Day preview — without it, Markdown syntax and hex photo references leak straight into search results and memory cards, which the base design never noticed.

THE WRAP. A Photo block whose side is left/right and whose NEXT block is a paragraph renders as `PhotoWrapBlock`. Inside one `LayoutBuilder`:

    final plan = planFloat(measure, em, sizeEm, side, aspect);
    if (plan.isStacked) return StackedPhoto(...);
    final tp = TextPainter(text: paraSpan, textScaler: scaler, textDirection: dir)
      ..layout(maxWidth: plan.band);
    final lines = tp.computeLineMetrics();
    final lastFit = lines.lastIndexWhere((l) => l.baseline + l.descent <= plan.photoH);
    if (lastFit < 0) return StackedPhoto(...);
    if (lastFit == lines.length - 1) return allBesideThePhoto;
    final split = tp.getLineBoundary(
        tp.getPositionForOffset(Offset(0, lines[lastFit + 1].baseline))).start;
    final (head, tail) = sliceInlineSpan(paraSpan, split);
    return Column([
      Row(side == left ? [photo, gap, SizedBox(plan.band, Text.rich(head))]
                       : [SizedBox(plan.band, Text.rich(head)), gap, photo]),
      if (tail != null) Text.rich(tail),
    ]);

Two corrections to the base design here, both called fatal by the engineering lens, both cheap. (a) `computeLineMetrics()` rather than a raw `getPositionForOffset` result or a word-boundary snap: the cut is always a line start, which is the only way this cannot look broken. (b) `sliceInlineSpan(InlineSpan, int) -> (InlineSpan, InlineSpan?)` is a named, specified, ~40-line pure recursive walk that accumulates plain-text length, splits the straddling leaf and re-parents each ancestor's style down both sides — the base design emitted `Text(head)`/`Text(tail)` over Strings, which silently kills inline bold and italic inside the exact paragraph the feature exists to wrap. Its property test is `head.toPlainText() + tail.toPlainText() == root.toPlainText()` over a fuzz corpus.

FLOAT SCOPE RULE, the single most important constraint: a float wraps the NEXT PARAGRAPH BLOCK ONLY. If the next block is a heading, a list, another photo, or the end of the note, the photo renders as a block. Two floats therefore cannot interact, `clear` is structural rather than implemented, and `findSpaceFor` is never reimplemented. It also bounds the cost: the TextPainter measures one paragraph (typically under 1500 characters), not the note.

ONE FALLBACK. `StackedPhoto` is the single return value for every failure: column too narrow, size=full, next block not a paragraph, missing or unreadable intrinsic dimensions, corrupt blob, unparseable token, aspect past the clamp, `NoteRenderBudget.floatEnabled == false`. One path, exercised by every phone on every note forever, so it is proven in production long before a slow desktop needs it. Selection and ctrl-A/ctrl-C across the head/tail boundary are byte-exact under plain `SelectionArea` with NO custom `SelectionContainer` delegate — that delegate exists only to hide float_column's justification hack, and this design forbids justified text.

FEED COST IS BOUNDED BY CONSTRUCTION. `TodayEntryFeed` is verified today a non-lazy `Column` inside a `SingleChildScrollView` (today_entry_feed.dart:68-80) that builds every entry in the day eagerly. It becomes a `ListView.builder` with `cacheExtent: 600`, and each card renders a PREVIEW — the first ~1200 characters of source plus the first photo, with a fade and 'Read more' — with the full note read in day detail. Per-card layout is then O(1) regardless of note length, which is a stronger guarantee than caching because there is nothing left to cache.

### Anchor model

There is no anchor object. The photo IS a line in the source, and its position is that line's position. Typing above it moves it exactly as it moves every other line, with zero code: no stored offset to shift per keystroke, no anchor row to orphan, no second copy of the position to drift. Word's documented anchor drift — the most-complained-about behaviour of anchored objects — is not mitigated here, it is unrepresentable.

Three consequences fall out free. Undo covers placement correctly, because Flutter's `UndoHistory<TextEditingValue>` covers the text string and nothing else, and any attribute state kept outside the buffer desynchronises on Ctrl-Z. Cut/copy/paste of a region carries its photos. The draft, the clipboard, the export and the search projection are all the same one string.

Placement attributes (side, size, alt) live in the same line for the same reason: one source of truth means a deleted line cannot orphan a row and a rewritten line cannot disagree with a column. Duplicating a photo line shows the photo twice at zero byte cost, because blobs are content-addressed. Moving a photo is moving its line; removing it is deleting its line.

Parsing is total and crash-free: a line whose trimmed content is exactly one photo token is a photo block; a photo token anywhere else renders as its alt text; a malformed token renders as a visible broken-photo chip carrying the raw source, and Ctrl-Z restores it because it is text.

### Responsive rule

ONE CLAMP AND ONE COMPARISON, in one `LayoutBuilder` at the note-body boundary. No breakpoints, no window-size classes, no `TargetPlatform` branch, no `MediaQuery` width read. (Verified: `grep textScalerOf` over lib/ returns zero hits, and there are four `LayoutBuilder`s in the whole app, none width-responsive — whatever is written here is what this app will have.)

    em      = MediaQuery.textScalerOf(context).scale(noteBody.fontSize)   // NOT scale(1) * fontSize
    measure = min(constraints.maxWidth, 35 * em)
    gutter  = 1 * em
    cap     = measure - gutter - 19.4 * em
    photoW  = min(sizeEm * em, cap)                    // SHRINK BEFORE DEMOTE
    FLOAT iff size != full && nextBlockIsParagraph && photoW >= 8.5 * em
    else BLOCK, width = clamp(2 * sizeEm * em, 0.60 * measure, 0.82 * measure), centred
    photoH  = min(photoW / aspect, 1.6 * photoW)       // BoxFit.cover; a 9:16 portrait cannot become a wall

`scale(fontSize)`, never `scale(1) * fontSize`: Android 14+ font scaling is non-linear, so the two are not equal, and four of the six designs got this wrong at exactly the accessibility sizes where the gate matters most.

19.4 em is the measured Newsreader-Variable constant for a 40-character residual — Bringhurst's multi-column floor and his explicit 38-40 breakdown point, converted through 0.4587 em/char and binary-searched against real line breaking so ragged-right waste is inside the number, verified scale-invariant at 0.9/1.0/1.15/1.5/2.0 and at both 13.5 and 19pt. It is a Newsreader constant and must be re-measured if the body family changes. 21.8 em (45 CPL) is the comfort target, stated as a preference and not a gate — no study covers a band beside a float, and I am not dressing a judgement as arithmetic. 8.5 em is a judgement too, and labelled one: below it the image reads as a thumbnail rather than a photo.

SIZES IN EM, NOT FRACTIONS OF THE MEASURE. This is a correction to every design that used fractions. With `photoW = min(frac * measure, cap)` a narrowing window makes the SMALL size demote before the medium one, because the fraction term drops below the minimum-photo gate while the cap has not yet bitten. In em the size term is constant, so only the cap can bite and the gate collapses to one clean inequality: FLOAT iff measure >= 28.9 em. Small 8.5 em, Medium 12 em, Large 14.5 em, Full spans the measure and never floats.

R4 — CANONICAL READING WIDTH, A REQUIREMENT AND NOT A RECOMMENDATION: 35 em, with the body type raised from `bodySerif` 13.5/1.5 (verified typography.dart:70-76) to `noteBody` Newsreader 16 / height 1.6. That is 560pt at default scale, ~72 CPL — under WCAG 1.4.8's 80 ceiling, at Bringhurst's 75 maximum. The two numbers are solved together, and the type change is what makes the rule solvable rather than scope creep: at 13.5pt a 72-CPL column is 472pt, below the 28.9 em float threshold, so no useful float would ever fit and the headline feature would not exist on any surface. Today the desktop feed runs 87 CPL at a 900pt window and 149 CPL at 1280 — already past the accessibility ceiling with no image present — and day detail is hard-capped at 520 (verified day_detail_panel.dart:30). One widget, `NoteColumn`, clamps to `min(available, 35 em)` and centres; applied inside `NoteBody` it reaches every read surface at once. Shell changes it licenses: DayDetailPanel.maxWidth 520 -> 640; composerPanelWidth 760 -> 640 with page padding tuned so the composer's text column is exactly 560 and editor line breaks equal read-view line breaks character for character; the Today feed card wrapped in the same NoteColumn; and `contentMinSize` added to MainFlutterWindow.swift so the macOS window cannot be dragged into the measured negative-column region.

THE SCALE-INVARIANCE PROPERTY, which is stronger than any single design claimed: because the measure is 35 em and every term is in em, whenever the pane can supply 35 em the float geometry is IDENTICAL at every text scale. A float demotes only when the pane itself clamps the measure below 28.9 em. At 1.5x on a 1280 macOS window the measure is 840pt and Medium floats at 288pt against a 528pt band — still 45 CPL. The accessibility case needs no separate rule and does not lose the feature.

WORKED, against real geometry (feed padding 20, card padding 15 horizontal — verified entry_card.dart:26-27):
- 390pt Android phone: content 320 = 20 em < 28.9 em -> BLOCK, photo 262pt centred, text above and below. The owner's worked example falls out of the clamp rather than a phone special case.
- 430pt phone: content 360 = 22.5 em -> BLOCK. No phone in portrait ever floats at any size.
- macOS 1280: pane 935 -> measure 560; Medium floats at 192pt, band 352pt = 45 CPL.
- Narrowing that window: Medium holds 192pt down to a 518pt measure, then shrinks continuously 192 -> 136 as the measure falls to 462, then blocks. Shrink AND move, no jump, no breakpoint.
- Tablet at 768: measure pins at 560; identical to desktop.

### Photo lifecycle

ADD: the already-built, already-tested `ImagePickerPhotoPicker` (the one genuinely reusable piece of the dead photo layer — MIME map and permission copy included) gains three arguments it is called with none of today: `pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 88)`, which downscales natively before the file is handed over and cuts blob size, write time, Android decode cost and image-cache bytes at once. Then intrinsic dimensions are read via `ui.ImageDescriptor.encoded` (header-only, dart:ui, no full decode) and passed through the already-existing `CaptureFile(width:, height:)` -> `MediaStore.putFile` path into the already-existing `media_blobs.width`/`height` columns. That read doubles as a DELIBERATE HEIC CANARY: a photo that will not decode fails loudly at the picker, where the user is already waiting and can choose another, rather than silently at read time as a correctly-shaped hole containing a corrupt placeholder. Bytes land in the content-addressed store immediately rather than at save, so dedup, the draft and the renderer all resolve through one path. Then one photo line is spliced in at the caret, on its own line.

MOVE / RESIZE / SIDE / CAPTION: the rail rewrites that one line, caret preserved. Move up/down swaps the photo line with the adjacent block. All tap targets >= 48dp; no drag anywhere.

REMOVE: delete the line. That is the whole delete path — no DAO call, no confirmation dialog, and Ctrl-Z restores it because it is text. Undoable beats confirmable.

REINDEX: on each save, replace the entry's `entry_photos` rows from the mediaIds found in the source. Derived, idempotent, ~15 lines.

REFCOUNTING IS NOT WRITTEN AND IS NOT NEEDED. `MediaGarbageCollector._reachableMediaIds` (verified, media_gc.dart:26-51) already computes a reachable SET by unioning `entries.media_id`/`thumbnail_media_id` and live `entry_photos.media_id` over non-deleted rows, then sweeps unreachable files and rows. Set reachability over content-addressed blobs IS refcounting, and it is strictly safer: two notes sharing identical bytes are correct by construction and there is no counter to increment wrongly. It is built, tested, and has zero production callers. The only addition is the drafts directory as a GC root, ~10 lines.

GC STAYS MANUAL — Settings -> Data -> Reclaim space, never automatic, never on app launch. This is the sharpest single argument anyone made and four of the six designs got it wrong. The photo reference lives in text the user can hand-edit; break a photo line and the reindex correctly drops its `entry_photos` row, and an automatic startup sweep would then take the bytes before the user can fix the typo. That is silent, permanent data loss in a local-first journal. The cost of avoiding it is honest and small: orphan blobs occupy disk until someone taps a button.

MEMORY: every `Image.file` for a note photo passes `cacheWidth` from the box's device pixels. Nothing in lib/ does today, so a 12MP photo currently occupies ~48MB of image cache to paint a 56px thumbnail.

SCRAPBOOK TREATMENT, geometry-safe: a tilt of +/-0.5-1.2 degrees derived from the mediaId hash (the same trick EntryCard already uses on cards), applied as a paint-only `Transform.rotate` INSIDE the reserved box, with the plan reserving `w + h*sin|theta|` so the layout rectangle stays axis-aligned and reflowable. Paper frame, shadow and caption live inside the same box. The aesthetic survives; the wrap contour never becomes non-rectangular.

### Draft model

The base design deleted the concept of unsaved work — continuous save, no draft, no discard, and the edit path's existing confirmation dialog removed. Two of the three lenses called that a product ruling made on the owner's behalf, and they are right: a user opens a real note, types into it by accident, taps away, and the note is permanently altered with no recovery past the session. I restore discard, and I do it the cheapest way available so the zero-migration property is preserved exactly.

(1) `barrierDismissible: false` on both composer routes — verified both are `true` today (text_composer.dart:135; day_detail_edit_note.dart:43 and :149) — plus a dirty-check confirm on close. That one change kills the stray-tap loss, which is the failure that actually happens.

(2) A single-slot FILE draft: `<appDocuments>/drafts/<entryId|new-YYYY-MM-DD>.md` holding the raw source string, written on a 400ms idle debounce and flushed on `AppLifecycleState.inactive`/`paused`, via the temp-file-then-rename the media store already uses. No table, no DAO, no `settings` KV keys (which delete-all does not clear and GC cannot see), no drift_dev, nothing to migrate. Because placement lives in the text, the draft payload is ONE string — there is nothing else to checkpoint. Android process death loses at most 400ms.

(3) Restore is silent with an inline 'Draft restored · Discard' chip, never a modal. A dialog on every open punishes the common case to handle the rare one.

(4) Photo bytes go into the content-addressed store at pick time, so a restored draft's photos are really there; the drafts directory being a GC root is what makes that safe, and an abandoned draft's blobs are reclaimed by the manual sweep.

This forces the create/edit asymmetry closed, which is overdue rather than a cost. `EditNoteConnector` calls `journalRepository.updateEntryText` directly (day_detail_edit_note.dart:59), bypassing `CaptureService`, so the `trim()` normalisation and blank-text validation the architecture appears to centralise are create-only and the edit path has no timeout guard. Photo reindexing cannot be written twice. Both routes now go through one `NoteWriter.save({entryId?, date, source})` performing {normalise, write entry, reindex entry_photos, delete draft} in a single drift transaction, with the create path's existing 20s timeout. `JournalCaptureService` keeps its job for voice and video.

### Dependencies

- none — zero packages added, zero schema change, no drift/drift_dev bump
- float_column REJECTED: a one-photo, block-anchored, unjustified, LTR placement model is precisely its restricted case, where the hand-rolled version is measured to produce identical slice geometry (228/360 at a 360pt column) with free selection and free responsive collapse; its ~3,000 extra lines buy clear, clearMinSpacing, stacked floats, inline WidgetSpan anchors, RTL and justified text, every one of which this design structurally excludes, and the price is bus-factor 1 under a core UX pillar
- hyper_render, super_editor, package:markdown, live_markdown_editor, markdown_editor_live, flutter_smooth_markdown, markdown_editor_plus and flutter_markdown_plus REJECTED with measured reasons, shipped as a spec appendix so the next engineer does not re-litigate it in four months

### Build order (pre-stress-fix)

| Unit | Risk | Delivers |
|---|---|---|
| U1 — Canonical measure and reading type | low | NoteColumn clamping to min(available, 35 em) applied inside NoteBody; a noteBody token at Newsreader 16/1.6 shared by composer and reader; DayDetailPanel maxWidth 520->640; composerPanelWidth 760->640 with padding tuned so the text column is exactly 560; Today feed card wrapped; textScaleProvider (0.9/1.0/1.15, verified zero production consumers) wired into MaterialApp.builder as a MediaQuery override composed with the OS scaler; composer reads viewInsets and drops the hard SizedBox(440); macOS contentMinSize. One note reads at one width on every surface for the first time. |
| U2 — Lazy feed and bounded preview | low | TodayEntryFeed becomes ListView.builder with cacheExtent; each card renders a 1200-character preview plus the first photo with a fade and Read more; full notes read in day detail. Lands BEFORE any heavier renderer, so the later measurement measures the real structure rather than an artifact of an eager Column. |
| U3 — Drafts, non-dismissible composer, one NoteWriter | medium | File-backed draft with 400ms debounce and lifecycle flush; barrierDismissible:false on both routes with a dirty confirm; inline restore chip; NoteWriter.save as the single write path, closing the create/edit asymmetry. Stray taps, the Android back button and process death stop destroying work. |
| U4 — Parser and read renderer, text only | low | parseNote with sourceRanges, plainTextOf, sliceInlineSpan, NoteDocument under one SelectionArea replacing NoteBody; the projection wired into the search haystack, search preview and On-This-Day. Named in the plan rather than discovered: note_body_test.dart:25-29,34-36 finds the note by literal string and asserts a single Text with fontFamily == TypographyTokens.serif, and a span renderer fails both the finder and the assertion. |
| U5 — Live Markdown editing behind the NoteEditor seam | medium | The NoteEditor interface with SingleFieldNoteEditor as the default implementation; EditableText->TextField (handles, toolbar, magnifier, selection highlight); MarkdownStyleController with the length assert, visible dim markers, the recognizer grep test, the spellcheck/stylus settings and the hand-reapplied composing underline; liveStyleLimit with no truncation anywhere. |
| U6 — The Android measurement on a real mid-tier device | low | Three named numbers and nothing else: keystroke cost in a 20k-character live-styled buffer, first-layout cost for one wrapped paragraph, and a scroll frame over a feed of preview cards. It runs here, immediately after the editor and before any photo work, because this is the last point at which the result can still change the design cheaply; after the float ships it can only confirm or condemn. |
| U7 — Photo substrate | low | Dimensions at pick via ImageDescriptor.encoded with the HEIC canary; native downscale arguments; cacheWidth on every MediaImage; the 12-hex prefix reference with insert-time uniqueness and the resolver; entry_photos reindex on save; drafts directory as a GC root; the manual Reclaim space action in Settings. |
| U8 — Photos in notes, stacked everywhere | medium | Photo lines, PhotoRail with caret-following highlight, tap-only Side/Size/Move/Replace/Remove/Caption, and the live mini-diagram. Every photo renders as a block on every surface. The feature is complete and usable with no float at all, which is also the permanent phone experience. |
| U9 — The float | medium | planFloat, PhotoWrapBlock, the computeLineMetrics split, the aspect clamp and tilt-in-reserved-box, NoteRenderBudget.floatEnabled. Read view only. The ~360-row decision table and ~12 goldens land with it. |
| U10 — SegmentNoteEditor, conditional on U6 | high | The second NoteEditor implementation, built only if the measurement says the single buffer is unusable on a mid-tier phone. Storage, parser, renderer, wrap, drafts, photos and GC are untouched by it. |

### What it gives up

- Wrap while typing. The editor shows a photo line as a dim chip with the real image in the rail below; the wrap exists only in the read view. R1 sanctions it and no Flutter code in existence does otherwise, but it is still two pictures of one note, and the rail's live mini-diagram is a mitigation rather than a fix.
- Floats on phones, permanently. The gate needs a 28.9 em measure (462pt at default type) and a 430pt phone gives 360pt of card content. No Android phone in portrait will float a photo under this design at any size. That is the honest consequence of the only sourced typographic floor that exists, and I chose not to fudge it.
- Literal scrapbook physics: no free (x, y), no rotation of the layout box, no overlap, no z-order. Photos are axis-aligned boxes in flow; tilt, paper frame and shadow are paint inside the reserved box.
- Multiple interacting floats, CSS clear, clearMinSpacing, and a float spanning more than one paragraph. A tall photo beside a short paragraph leaves vertical space, exactly as clear: both would.
- Justified text, permanently. It is forbidden by design because it is the sole reason the mature package needs a hidden trailing word and a custom selection delegate.
- Arbitrary photo width. Four states — Small 8.5 em, Medium 12 em, Large 14.5 em, Full — rather than a continuous fraction, because a user who builds an 88% float that demotes everywhere learns nothing from it.
- Drag, entirely. No drag to place, no drag to resize. Placement is the caret plus tap controls. Deliberate under WCAG 2.2 SC 2.5.7 and the gesture race with scroll, but less direct than dragging a corner on a desktop.
- CommonMark conformance. A documented journaling subset: no tables, footnotes, task lists, nested lists, reference links, setext headings, indented code blocks or HTML blocks. Unknown constructs render as literal text.
- Hidden Markdown markers. Syntax stays visible and de-emphasised — a legibility trade taken to delete an entire class of caret bug, reversible later via reveal-at-caret.
- Portability of the photo line's attributes. The line is valid CommonMark and another tool renders the alt text, but photo/<prefix> plus a title-slot convention is a private convention, as it is in every product that has tried.
- RTL. Sides are stored as left/right and resolved in one place, so RTL is a later addition rather than a designed-in capability. The app has no localisation delegates to test against today.
- Automatic disk reclamation. Orphan blobs from broken photo lines and abandoned picks accumulate until the user runs Reclaim space — the deliberate price of never sweeping bytes out from under a typo.
- Original-resolution photo bytes. Import downscales to a 2048px long edge; the original stays in the camera roll but not in the blob store.
- Full-length notes in the Today feed. Cards show a 1200-character preview with the first photo; the whole note reads in day detail.

### Biggest risk

Keystroke cost on a real mid-tier Android phone in a long, live-styled single buffer. It is the only number in this design with no measured analogue anywhere in the survey, every figure in that survey is desktop Apple Silicon under flutter_test, and the plausible multiplier spans 5x to 15x — the difference between a fine editor and a broken one.

What changed relative to the design I started from is that this is no longer an unhedged bet. NoteEditor is an interface with two implementations from U5, the measurement is a named unit with three named numbers running in U6 immediately after the editor and before any photo work, and storage, parser, read renderer, wrap, drafts, photos and GC are all ignorant of how the text got typed. So the failure is a flag flip plus a build, not a rewrite of everything.

The residual risk is honest and I am not pretending it is solved: the thing the flag flips TO is the segment editor, whose cross-boundary Backspace-merge, arrow traversal and focus handoff two of the three lenses identified as the worst-propertied subsystem anyone proposed — hand-built, stateful, in the path of every keystroke at a boundary, unverifiable by golden image, and costing cross-segment drag-selection. If U6 comes back bad, the project's cost rises by a genuinely hard unit and the editor loses a capability it has today. That is why U6 runs sixth rather than last, and why every unit before it stands alone: U1 fixes the reading width, U2 stops the feed building every card eagerly, U3 stops losing work, U4 makes the reader a Markdown reader, U5 makes the editor a Markdown editor. If the measurement is bad, five useful units have already landed and the photo work re-plans against a known number instead of a hope.

---

## Stress tests

### Adversarial edge-case and real-use attack, verified against live code in /Users/satanshumishra/Documents/DevLabs/firepla

**Verdict: SOUND_WITH_FIXES**

**Single biggest problem.** There is no full-note read surface, so the headline feature has nowhere to live. U2 turns EntryCard into a 1200-char preview and points at day detail for the full note — but day_detail_entry_tile.dart:28 builds the SAME EntryCard, inside day_detail_panel.dart's ConstrainedBox(maxWidth:520, maxHeight:520) with `padding: EdgeInsets.all(20)` and a `shrinkWrap: true` ListView.separated (:141). So after U1/U2 either both surfaces preview (a 10,000-word note with eight photos can never be read in full anywhere in the app, and the float renders for at most the first photo in a 1200-char window) or neither does (U2's O(1) feed guarantee is defeated, since shrinkWrap ListView builds every child anyway — day detail is exactly as eager as the Column U2 replaces). The design names no preview/full flag, no new route, and no change to maxHeight:520. R4 raises the width to 640 and leaves the note being read through roughly 340pt of scrollable height inside a modal dialog. Everything else here is a patch; this one is a missing unit.

#### FATAL (1)

- **Read a 10,000-word note with eight photos. Where does it render at full length?**
  - survives: False
  - what happens: Nowhere. day_detail_entry_tile.dart:28 constructs the same EntryCard the Today feed does, so U2's 1200-character preview applies to day detail too. The panel is ConstrainedBox(maxWidth:520, maxHeight:520) with EdgeInsets.all(20) and a shrinkWrap ListView.separated at day_detail_panel.dart:141 — shrinkWrap builds every child, so day detail is as eager as the Column U2 replaces. The float, the whole point, is only ever visible for photo #1 inside a ~340pt-tall modal.
  - FIX: Add a unit before U8: a full-note read route (EntryCard gains `preview: bool`, day detail's tile passes false, plus a real push route from 'Read more'). Drop maxHeight:520 for that surface. Make NoteDocument's block list a sliver there and accept that ctrl-A covers materialized blocks only, or keep the Column and measure its Android first-layout cost in U6.

#### SERIOUS (9)

- **Ship U7 (entry_photos reindex on save) and use the app before U8 lands.**
  - survives: False
  - what happens: entry_card.dart:69-70 is `if (photos.isNotEmpty) InlinePhotoStrip(photos: photos, resolver: resolver)` — unconditional and already mounted. It is dormant today only because nothing ever writes entry_photos. U7 writes entry_photos for the first time in the project's history, so every note in the Today feed and day detail instantly grows a dashed divider plus a 56px horizontal thumbnail strip. After U8 that strip sits under the in-text photos, showing each photo twice.
  - FIX: Delete the InlinePhotoStrip mount from EntryCard in U7, in the same commit as the reindex — not in U8. entry_photos is a derived GC index with no render consumer.
- **Use the rail's Caption control.**
  - survives: False
  - what happens: The photo line has an alt slot and a title slot, and the title slot already holds `"right medium"`. The design lists Caption among the rail's seven tap controls and never says where the caption is stored. Every available slot destroys the 12-hex-prefix argument: `![Sunset over the bay](photo/7f3ac91b2d4e "right medium")` is already 56 characters, and a real caption pushes it past 100 — so the line no longer fits 'half a line at a 72-CPL measure' and no longer styles as a chip, which was the sole stated reason for truncating the digest at 12 hex in the first place.
  - FIX: Name the slot: alt doubles as caption (`![caption](photo/<prefix> "right medium")`, alt=caption for screen readers and for portable renderers). Then drop the '38 characters' claim from the spec and re-justify the 12-hex prefix on its own merits, or go back to the full digest since the chip argument no longer holds.
- **Rotate an Android phone to landscape mid-edit with the keyboard up.**
  - survives: False
  - what happens: U3/U1 add `EdgeInsets.only(bottom: viewInsets.bottom)` and replace SizedBox(height: 440) with Flexible, but leave text_composer_sheet.dart:28-29 untouched: `_pageTopPadding = 44` and `_pageBottomPadding = 120`. That Padding is outside the editor's scroll view (RawScrollbar > Padding > Stack > EditableText), so 164pt is subtracted from the viewport before a single glyph. On a 390pt-tall landscape phone with viewInsets ~200, the writing surface gets roughly 112pt. 164 > 112: zero-height editor and a RenderFlex overflow, on the primary mobile platform.
  - FIX: Make the page paddings proportional to available height (e.g. clamp(available * 0.1, 8, 44) top / clamp(available * 0.12, 12, 120) bottom), or move the bottom padding inside the scrollable as trailing whitespace so it does not consume viewport. Add a widget test at 844x390 with viewInsets.bottom = 200.
- **Remove a photo on Android. Then realise it was the wrong one.**
  - survives: False
  - what happens: It is gone. The design explicitly ships no confirmation ('Undoable beats confirmable') and rests the whole recovery story on Ctrl-Z. `grep -rn 'undo' lib/` returns exactly one hit, a string in delete_all_dialog.dart:34 — there is no undo affordance anywhere in the app, and a phone has no Ctrl key. Same for Move up/down, which is the gesture people will fumble most.
  - FIX: Every destructive rail action emits an inline `Toast` ('Photo removed · Undo', the app already has design/feedback/toast.dart) holding the removed line and its offset for ~6s. That is the Android substitute for Ctrl-Z and it is about 20 lines.
- **On any Android phone, set a photo to Small, then Medium, then Large.**
  - survives: False
  - what happens: Nothing changes. Block width is `clamp(2 * sizeEm * em, 0.60 * measure, 0.82 * measure)`. On a 390pt phone measure = 320, so the bounds are [192, 262]. Small 2*8.5*16 = 272 -> 262. Medium 384 -> 262. Large 464 -> 262. All three clamp to the upper bound. Since no phone in portrait ever floats, the Size control is a four-state control with three visually identical states on the entire mobile platform, forever — and the rail's live mini-diagram will truthfully say the same sentence for all three.
  - FIX: Make the block bound track the size: width = measure * {S: 0.55, M: 0.72, L: 0.88}[size], capped at measure. The em-vs-fraction argument only needed to hold for the float gate; in block mode there is no cap to race.
- **Select all and copy a multi-paragraph note from the read view.**
  - survives: False
  - what happens: Paragraphs come back run together with no line breaks. NoteDocument is a Column of separate block widgets under one SelectionArea; MultiSelectableSelectionContainerDelegate.getSelectedContent concatenates each child's plainText with no separator (flutter/flutter#104012). Head/tail across a float happen to be correct because the split is mid-paragraph, but every paragraph, heading and list-item boundary in the note loses its newline. The design's 'the draft, the clipboard, the export and the search projection are all the same one string' is false for the clipboard, and the stated fix — a custom SelectionContainer delegate — is explicitly forbidden.
  - FIX: Either allow one small SelectionContainer delegate that injects '\n\n' at block boundaries (it is unrelated to the float_column justification hack the design was rejecting), or intercept CopySelectionTextIntent / SelectAll on NoteDocument and serve the slice of `source` covered by the selection's sourceRanges. The second is better: it returns the real Markdown.
- **Pick the same photo twice, once on an Android 13 device and once after an OS update; or check whether the HEIC canary fires.**
  - survives: False
  - what happens: `pickMultiImage(maxWidth: 2048, maxHeight: 2048, imageQuality: 88)` makes image_picker decode and re-encode to JPEG on the platform side before Dart sees a byte. Re-encoded output is not byte-stable across OS versions, vendor codecs or plugin upgrades, so the same source photo yields different SHA-256s and content-addressed dedup silently stops deduping. It is also the documented path where image_picker drops EXIF orientation on Android — which is precisely the 'aspect drift' the design lists under BREAKS WHEN, promoted from a risk to a default. And the HEIC canary is dead code: with maxWidth set there is no HEIC left for ui.ImageDescriptor.encoded to choke on.
  - FIX: Do not pass maxWidth/maxHeight/imageQuality. Pick the original, read dimensions and orientation via ImageDescriptor.encoded (the canary then works as designed), and downscale in Dart with a deterministic codec before hashing so identical input bytes always produce identical stored bytes. Keep the 2048 long-edge target; move it downstream of the hash decision.
- **Close the composer with the Android system back button or a back-edge swipe after typing 800 words.**
  - survives: False
  - what happens: Work is lost, exactly as today. U3 says 'Stray taps, the Android back button and process death stop destroying work' but the only listed mechanism is `barrierDismissible: false` plus a dirty confirm on close. barrierDismissible governs taps on the barrier; it does nothing to the system back button, which pops a showGeneralDialog route regardless (text_composer.dart:135, day_detail_edit_note.dart:149). The dirty confirm is wired to the X button's onCancel, which back never calls.
  - FIX: Wrap both connectors in PopScope(canPop: false, onPopInvokedWithResult: ...) routed through the same dirty-check. One widget, both routes.
- **U6 runs on a mid-tier Android phone and reports its three numbers. Does it cover the risk it exists for?**
  - survives: False
  - what happens: Partly, and it misses the two worst paths. The design's own BREAKS WHEN names 'a 200,000-character note pasted in one go' and says liveStyleLimit only disables styling while the RenderEditable whole-paragraph relayout underneath continues — yet U6's named numbers stop at 'a 20k-character live-styled buffer'. It never measures a >6000-char plain-mode buffer, which is the actual failure mode and the case the segment editor exists for. It also never measures full read-view first layout for a long note, which after attack #1 is the heaviest path in the app.
  - FIX: Add two numbers to U6: keystroke cost in a 60k-character buffer with styling off, and first-layout cost for a 10,000-word NoteDocument with eight photos. Without the first, a good U6 result does not license skipping U10.

#### ANNOYING (8)

- **Tap a rail control (Move up), then press Ctrl-Z on macOS.**
  - survives: False
  - what happens: Nothing, or the wrong thing. Flutter's UndoHistory shortcut is registered in the editor's focus scope. A tappable rail button with default focus behaviour takes focus on tap, so the Ctrl-Z the design leans on for every rail mutation is unreachable immediately after the mutation — which is the only moment anyone wants it.
  - FIX: Rail controls use `canRequestFocus: false` / `skipTraversal: true` and the editor re-requests focus with the preserved selection after every line rewrite. Add a widget test: move, Ctrl-Z, assert the buffer.
- **Resolve a 12-hex prefix to a blob id at read time.**
  - survives: True
  - what happens: Correct, but not for the stated reason. I ran it: `EXPLAIN QUERY PLAN SELECT id FROM media_blobs WHERE id LIKE 'abc123%'` returns `SCAN media_blobs USING COVERING INDEX`, not SEARCH. SQLite's LIKE optimization requires a NOCASE index when case_sensitive_like is off (the default); drift's TEXT primary key is BINARY, so the optimization never applies. Every resolution is a full index scan. Harmless at journal scale, but the spec's justification ('prefix match uses the TEXT primary-key index') is false and will be copied into code review as if verified.
  - FIX: Use `WHERE id GLOB '<prefix>*'` — I confirmed it plans as `SEARCH ... (id>? AND id<?)`. One token.
- **Pick a photo whose bytes are already in the blob store from a pre-U7 pick.**
  - survives: False
  - what happens: It is permanently stacked, silently. filesystem_media_store.dart:133-135 is `final existing = await blobById(id); if (existing != null) return existing;` — dedup short-circuits before the insert and never backfills width/height. The design's own rule sends missing intrinsic dimensions to StackedPhoto, so that photo can never float on any surface and no user action repairs it. The design lists this under BREAKS WHEN without naming the one-line fix sitting in the file.
  - FIX: In putFile/putBytes, when `existing != null && existing.width == null && width != null`, write the dimensions before returning. Four lines at filesystem_media_store.dart:134.
- **Float a photo right of a short paragraph; then float one left of a tilted photo.**
  - survives: False
  - what happens: Two geometry bugs in the spec as written. (a) The pseudocode's `Row(...)` takes CrossAxisAlignment.center by default, so a photo taller than the head text is vertically centred against it — the top of line 0 is no longer the top of the photo, and every `lastFit` offset computed from `baseline + descent <= plan.photoH` is measured against the wrong origin. (b) The tilt reserve is `w + h*sin|theta|`, but the axis-aligned bounding box of a rotated rect is `w*cos + h*sin` wide AND `h*cos + w*sin` tall. Width is over-reserved (safe); height is not reserved at all, so a tilted photo's corners overhang the reserved box by about w*sin(theta) — roughly 4pt at a 192pt Medium — clipping or colliding with the block below.
  - FIX: `crossAxisAlignment: CrossAxisAlignment.start` on the Row, asserted in a golden. Reserve both AABB dimensions in planFloat.
- **A note whose first 1200 characters end mid-photo-line, or whose very first line is a photo.**
  - survives: False
  - what happens: Two related cuts. (a) U2 previews 'the first ~1200 characters of source' — a raw character cut can bisect `![alt](photo/7f3ac91b2d4e "right medium")` and the feed card shows a visible broken-photo chip on a perfectly healthy note. (b) search_day_view.dart:63-95 `_previewFor` -> `_firstLine` returns the first non-blank line; when that is the photo line, `plainTextOf` of a photo block is undefined by the spec, so the search result and the On-This-Day card show either raw hex or an empty preview for the note.
  - FIX: Truncate the preview at the last block boundary inside 1200 chars — sourceRange already gives it for free. Define plainTextOf(Photo) as the caption/alt text, and make _previewFor skip to the first block with non-empty projected text.
- **Write past 6000 characters — roughly 1000 words, ordinary for a journal entry.**
  - survives: True
  - what happens: On one keystroke, every heading, bold run and photo chip in the buffer reverts to undifferentiated plain text and the photo lines become raw 38-to-56-character strings. Nothing is destroyed and the read view is fine, but the user is given no indication of what happened or that it is reversible by deleting text. In an app whose headline feature is live Markdown, the feature silently switches itself off at a length the target user hits weekly.
  - FIX: Show a persistent, quiet status line ('Plain view — long note') with a one-line explanation, and set liveStyleLimit from U6's measured number rather than a guessed 6000.
- **Rotate an Android phone to landscape while reading a note with photos.**
  - survives: True
  - what happens: Works, and the clamp handles it — but it falsifies a headline claim. In landscape a 390x844 phone gives 844 - 40 feed padding - 30 card padding = 774pt = 48 em, well past the 28.9 em gate, so measure pins at 560 and Medium floats. 'No Android phone in portrait will float a photo under this design at any size' is true only with the portrait qualifier; photos visibly jump from stacked to floated and back on every rotation.
  - FIX: None needed for behaviour. Correct the GIVES UP text, and cover rotation with a golden pair so the reflow is deliberate rather than discovered.
- **Process death mid-edit; accessibility text at 200%; a photo deleted from the camera roll; two adjacent photos; pasting text above a photo.**
  - survives: True
  - what happens: All five hold. Temp-file-then-rename means a killed write leaves the previous draft intact, and AppLifecycleState.paused precedes death in normal backgrounding. The scale-invariance argument is real because every term is in em and `scale(fontSize)` is correctly used (`grep textScaler lib/` confirms there is nothing to conflict with). Camera-roll deletion is irrelevant because bytes are copied into the content-addressed store at pick time. Two adjacent photo lines both block cleanly under the next-block-is-a-paragraph rule. Pasting above a photo is pure text-buffer motion with no anchor to drift — this is the design's strongest property and it earns it.
  - FIX: None. One note: if a paste lands with no trailing newline immediately before a photo line, the token stops being alone on its line and the photo vanishes from the read view with no explanation. Detect that specific case on paste and reinsert the newline.

---

### Performance and scale on an unmeasured mid-tier Android: where layout is recomputed, how often, and what is cached — fee

**Verdict: SOUND_WITH_FIXES**

**Single biggest problem.** The design's only structural scale guarantee — "FEED COST IS BOUNDED BY CONSTRUCTION" via ListView.builder with cacheExtent — cannot be delivered by U2 as scoped, because TodayEntryFeed sits inside a Column inside a SingleChildScrollView (today_screen.dart:59-86). A ListView.builder there throws on unbounded height; shrinkWrap:true compiles and then builds every child anyway, with cacheExtent discarded, because RenderShrinkWrappingViewport treats an infinite mainAxisExtent as "it builds everything anyway" (viewport.dart:2156). The unit needs a CustomScrollView/sliver conversion of TodayScreen in both layout branches and is not "low". Underneath it sits the thing that actually janks on a mid-tier Android: nothing in this design is cached. MediaImage recreates its SQL+stat future inside build(), parseNote re-runs on every EditableText and NoteDocument rebuild rather than on text change, PhotoWrapBlock re-splits and re-shapes the paragraph every constraint frame against the survey's own measured advice, and cacheWidth is derived from a continuous width so a resize decodes the same photo dozens of times. Each fix is local and cheap, but until the caching layer exists the performance argument rests on per-run microbenchmarks multiplied by an uncounted number of runs.

#### FATAL (1)

- **U2: "TodayEntryFeed becomes a ListView.builder with cacheExtent: 600" — build it where the design puts it and scroll a feed of 50 notes.**
  - survives: False
  - what happens: It cannot be built there. TodayEntryFeed is a child of a Column inside a SingleChildScrollView (today_screen.dart:59-65 builds `main`, :71-76 stacked branch, :81-86 rail branch). A ListView.builder in that slot receives unbounded height and throws 'Vertical viewport was given unbounded height'. The only non-structural escape is shrinkWrap: true — and that is exactly as eager as the Column it replaced. RenderShrinkWrappingViewport._attemptLayout passes `remainingPaintExtent: mainAxisExtent` and, when mainAxisExtent is infinite (which is what SingleChildScrollView hands its child), sets _calculatedCacheExtent = 0 with the comment 'If mainAxisExtent is infinite, it builds everything anyway, so we don't need any extra cache' (/opt/homebrew/share/flutter/packages/flutter/lib/src/rendering/viewport.dart:2156). So U2 ships either a crash or all 50 cards built and laid out per frame, with cacheExtent:600 silently discarded. The design's one load-bearing scale guarantee — 'FEED COST IS BOUNDED BY CONSTRUCTION' — is false as specified, and U2 is priced 'low' on a unit whose real content is a scroll-architecture change.
  - FIX: Convert TodayScreen to a CustomScrollView in both branches: TodayHeader / MoodBannerForDate / TodayFeedEyebrow as SliverToBoxAdapter, the feed as SliverList.builder, cacheExtent on the CustomScrollView. Reprice U2 low -> medium and name today_screen.dart in its scope.

#### SERIOUS (4)

- **Scroll the feed with photos present: what does resolving `photo/<12hex>` to a file cost per card?**
  - survives: False
  - what happens: MediaImage builds its future inside build(): `future: resolver.resolve(id)` (media_image.dart:52). resolve() is a SQL SELECT through NativeDatabase.createInBackground (a cross-isolate round trip) plus an async File.exists (media_resolver.dart:38-44). There is no cache anywhere. So the cost is paid per rebuild, not per photo — and under the new design rebuilds are frequent: entriesForDateProvider is a drift stream over the entries table, so any note save re-emits and rebuilds all 50 tiles; a lazy feed rebuilds every card on scroll-in; NoteColumn's LayoutBuilder rebuilds the subtree on every resize frame. Each rebuild also renders one placeholder frame first (_neutral() while connectionState != done), so scrolling back up flashes empty boxes that were already resolved. The design adds a LIKE prefix query in front of this and never mentions memoizing any of it.
  - FIX: Give MediaStoreResolver a synchronous memo: `final Map<String, ResolvedMedia> _hot` populated on first resolve, returned synchronously thereafter (the resolver is one provider-scoped instance via todayMediaResolverProvider, so the cache lives as long as the surface). Alternatively hoist the future into a StatefulWidget keyed by mediaId. Without this, every other performance claim in the design is void.
- **Desktop: narrow the macOS window continuously through the shrink band the design advertises (Medium holding 192pt down to a 518pt measure, then shrinking 192 -> 136 as the measure falls to 462).**
  - survives: False
  - what happens: photoW is continuous in that band by construction (cap = measure - gutter - 19.4em, measure = min(maxWidth, 35em)), and so is the block width (clamp(2*sizeEm*em, 0.60*measure, 0.82*measure)). The design then passes cacheWidth 'from the box's device pixels' to every Image.file. Flutter's ImageCache keys on (file, cacheWidth, cacheHeight), so a single resize drag through that 56pt band triggers roughly 56 distinct decodes of the same 2048px source photo, and the default cache (100MB / 1000 entries) retains them rather than replacing. The fix the design is proudest of is the one that introduces the decode storm. The block path is continuous too, so this is on the phone as well at rotation and split-screen, not only on desktop.
  - FIX: Quantize the decode target: `cacheWidth = (boxDevicePx / 64).ceil() * 64`. One expression; it collapses the whole band to one or two cache entries and BoxFit.cover absorbs the residual.
- **Type in a long note, then drag-select across it. How often does parseNote run?**
  - survives: False
  - what happens: The design has no memoization story at all, and buildTextSpan is called on every EditableText rebuild, not on every text change — selection changes, focus changes, viewInsets changes and composing updates all rebuild it. So a drag-select over a 20k-character note re-parses the entire document on every pointer move at 60-120Hz, for a span tree that is byte-identical (TextSpan's deep operator== then suppresses the relayout, so the parse is pure waste). On the read side the same parser runs in NoteDocument.build: once per card build, and once per resize frame under NoteColumn's LayoutBuilder. The survey's comfortable numbers are per-run (311us span build at 20k chars, survey:465); at the survey's own 5-15x Android multiplier, times the number of visible cards, they stop being comfortable.
  - FIX: Memoize at the parser entry point on source identity — `String? _lastSource; List<NoteBlock>? _lastBlocks;` — which covers both consumers for free precisely because the design already commits to one grammar with two consumers.
- **Resize the desktop window with a floated photo on screen — the design's only continuous constraint-change loop, since it removed drag.**
  - survives: False
  - what happens: PhotoWrapBlock does a full re-split every frame: fresh TextPainter, layout(maxWidth: plan.band), computeLineMetrics, getLineBoundary, sliceInlineSpan, then a brand-new span tree handed to Text.rich — which shapes the head paragraph a second time, so the paragraph is paid for twice per frame. The survey measured exactly this and reached the opposite conclusion: relayout 0.025ms vs full rebuild 0.285ms, 11.5x (survey:503); a rebuild-everything frame is 0.2482ms per note on desktop, 'plausibly 7-22% on mid-tier Android' (survey:585); and its stated design implication is 'prefer relayout during drag ... a drag that holds split points stable is nearly free' (survey:569). The design did not adopt the survey's own finding. Multiply by the number of visible floats, and note that the cacheWidth storm above rides the same frames.
  - FIX: Cache the split offset per (paragraph span identity, textScaler, band bucket) and recompute only when the new band would move the split across a line boundary — one line of hysteresis. Between recomputes, relayout the existing head/tail spans instead of re-slicing.

#### ANNOYING (7)

- **Leave the resize running for a few seconds with several floats on screen and watch native memory.**
  - survives: False
  - what happens: The TextPainter constructed inside PhotoWrapBlock's LayoutBuilder is never disposed. Each one owns a ui.Paragraph holding native memory, so the design allocates and abandons one per float per build — during a resize that is one per float per frame. Flutter's leak tracking will flag it in debug; on Android it is native heap churn under exactly the workload the design says is cheap.
  - FIX: `final tp = TextPainter(...); try { ...layout/metrics/slice... } finally { tp.dispose(); }`, or hoist the painter into the State and reuse it, which the split-caching fix wants anyway.
- **The 12-hex prefix resolver: `SELECT id FROM media_blobs WHERE id LIKE '<prefix>%'`. The design asserts this 'uses the TEXT primary-key index in SQLite'.**
  - survives: False
  - what happens: It does not. SQLite applies the LIKE optimization only when a BINARY-collated index is paired with case_sensitive_like=ON, or a NOCASE index with it OFF. The default is OFF, drift creates the TEXT primary-key index with BINARY collation, and app_database.dart:34 sets only `PRAGMA foreign_keys = ON` in beforeOpen. So every photo resolution is a full scan of media_blobs, on the background isolate, and per the FutureBuilder finding above that is once per rebuild rather than once per photo. Small in absolute terms for a personal journal, but the design cites index use as the reason the format is safe, and that reason is wrong.
  - FIX: Range predicate instead of LIKE: `id >= :prefix AND id < :prefixSuccessor` where the successor increments the last hex character. Always index-usable, no pragma, no collation dependency, and it makes the insert-time uniqueness extension a range count.
- **Scroll a lazy feed of notes whose blobs have no stored width/height — which is every blob in the database today, and any blob U7 did not import.**
  - survives: False
  - what happens: The design routes 'missing or unreadable intrinsic dimensions' to StackedPhoto but never specifies what height StackedPhoto reserves when there is no aspect. In a lazy list that is the classic scroll-jump: the card is measured at a guessed height, the decode lands asynchronously, the card grows, and ListView corrects the scroll offset under the user's thumb. This is the one place the design's otherwise-solid 'reserve from stored numbers' discipline has a hole, and U7 only populates dimensions at pick time — there is no backfill.
  - FIX: State a fixed reserve aspect for unknown dimensions (4:3) and keep the reserved box after decode — never re-measure the box from the decoded image. Same rule covers the aspect-drift case the design already lists under BREAKS WHEN.
- **U6's three named Android numbers, run in U6's stated slot.**
  - survives: False
  - what happens: U6 runs before U7 and U8, so photos do not exist in the app yet. 'A scroll frame over a feed of preview cards' therefore measures text-only cards — while every expensive thing in a feed scroll (blob resolve, 2048px decode, cacheWidth churn, reserved-box layout) arrives in U7/U8. The number that would actually predict feed jank is measured on content that cannot produce it. The other two numbers are correctly placed.
  - FIX: Either seed U6's fixture with photos through the already-built, already-tested photo layer (the DAO and MediaStore exist; only the production UI is missing), or split U6 into U6a (keystroke + paragraph layout, before the photo work) and U6b (feed scroll frame, immediately after U8).
- **Scroll down past 20 cards and back up, once the feed is lazy.**
  - survives: False
  - what happens: today_entry_feed.dart:73 wraps every tile in FadeIn, whose controller calls forward() in initState (fade_in.dart:29-33). Under today's eager Column the State lives for the life of the screen and the fade plays once. Under a builder the State is recreated every time a card re-enters the cacheExtent, so scrolling back up re-fades every card and adds an AnimationController ticker per card entering the viewport — a visual defect plus per-frame cost on precisely the surface U2 exists to make cheap.
  - FIX: Pass `animate: false` inside the feed, or lift a played-once set keyed by entry id into the feed's State.
- **liveStyleLimit = 6000 as a performance lever.**
  - survives: False
  - what happens: It buys nothing and costs something. The survey's re-measurement shows span construction is sub-millisecond at every length (231us at 4.5k, 311us at 20.7k, 741us at 88k) while the keystroke cost is relayout: 7ms / 14ms / 109ms (survey:465). Styling is not the expensive half at any length, so switching it off cannot help. Worse, at 6000 characters the plain relayout is already ~7-8ms on desktop — 35-120ms at the survey's own 5-15x Android multiplier — so the threshold sits at a length where turning styling off does not rescue typing and turning it on was never the problem. What it does do is flip the painted style of every marker from Palette.ink34 to full ink on one keystroke, mid-sentence, plus a full relayout on the transition. The design already concedes the limit does not address the real cost; it should follow that through.
  - FIX: Delete liveStyleLimit. If a guard is wanted, put it on the measured variable — an Android-measured character count from U6 that switches the editor implementation behind the NoteEditor seam, which is the lever the design already built.
- **Save one note while the Today feed and a day detail panel are both open.**
  - survives: True
  - what happens: NoteWriter.save writes entries and replaces entry_photos in one transaction. Drift invalidates stream queries by table name, so this re-runs entriesForDateProvider plus every open watchPhotosForEntry stream — one per visible tile (today_entry_feed.dart:100-102, day_detail_entry_tile.dart:27-29). At 50 subscribed tiles that is ~51 queries on one save. It survives because a save is a discrete user action, not a per-frame event, and because day detail's shrinkWrap ListView does bound its subscribers to the viewport (its mainAxisExtent is finite under the Flexible + 520 maxHeight, so the shrink-wrapping viewport stays lazy there — unlike the feed case above). Worth noting only because the design makes entry_photos a derived index rewritten on every save while leaving photosForEntryProvider wired into both tiles, where it is now dead weight: the renderer reads placement from the text.
  - FIX: Drop the photosForEntryProvider watch from TodayEntryTile and DayDetailEntryTile once photos come from the source string. Removes 50 live stream queries and 50 rebuild triggers for no behaviour change.

---

### UX and coherence — does a real person, especially a non-technical one on an Android phone, understand what this thing is

**Verdict: SOUND_WITH_FIXES**

**Single biggest problem.** On every Android phone the photo control panel is mostly inert, by the design's own arithmetic. Side (Left|Right) can never produce a visible difference because no phone ever floats. And the block clamp `width = clamp(2*sizeEm*em, 0.60*measure, 0.82*measure)` at the design's own worked measure of 320 gives Small 272→262, Medium 384→262, Large 464→262 — S, M and L render at the identical 262pt. So the scrapbook's primary UI is six controls of which five (Left, Right, S, M, L) do nothing the user can see; only Full and Remove/Move respond. The mini-diagram dutifully says "text sits above and below" for all of them, which reads as the app ignoring you rather than teaching you. Fix: express BLOCK width as fractions of the measure (S 0.55, M 0.75, L 0.92, Full 1.0) so the four sizes are distinct at every width — em sizing is right for the float and wrong for the block — and hide Side entirely whenever the current measure cannot float, rather than showing a dead toggle.

#### FATAL (3)

- **Android phone, 390pt wide. User taps Side → Right, then cycles Size S → M → L, watching the note.**
  - survives: False
  - what happens: Nothing changes. The design's own block clamp at measure 320 maps 272, 384 and 464 all onto the 262pt ceiling (0.82 × 320), and Side is unreachable because the float gate needs 28.9 em ≈ 462pt, which no phone supplies at any size. Five of six placement controls are visually inert on the platform that is a hard requirement. The user concludes the feature is broken, not that their screen is narrow.
  - FIX: BLOCK width becomes a fraction of the measure (S 0.55, M 0.75, L 0.92, Full 1.0) so sizes stay distinct at every width; float width stays in em. Hide Side whenever planFloat reports the current measure cannot float, instead of rendering a toggle with no effect.
- **360x640 Android phone, keyboard up, user starts writing a note after U1 lands the viewInsets fix and the Flexible surface.**
  - survives: False
  - what happens: The writing surface gets roughly 320pt of panel height minus header (~47) and footer (~48) ≈ 219pt — and text_composer_sheet.dart:_editor() wraps the EditableText in a hard Padding of top 44 / bottom 120 / horizontal 54 that sits OUTSIDE the scroll view. 164pt of that 219 is dead chrome, leaving ~55pt ≈ two lines of visible text at 16/1.6. The design's U1 changes the height constraint and the horizontal padding ("tuned so the text column is exactly 560") but never touches _pageTopPadding 44 / _pageBottomPadding 120. The keyboard fix trades a 44.8% occlusion for a two-line porthole.
  - FIX: Make the vertical page padding of the writing surface width/height-responsive in U1 (e.g. 44/120 at the 640 panel, 12/16 under a compact height), or move that padding inside the scrollable content so it is leading/trailing whitespace rather than permanent chrome.
- **Same phone, keyboard up, user places a photo and the PhotoRail appears with its tap-only controls.**
  - survives: False
  - what happens: The rail needs a thumbnail row (56pt today) plus Side, Size ×4, Move up, Move down, Replace, Remove, Caption — at least 11 targets at the design's own ≥48dp, which is ~528dp of width on a 360dp screen, so it wraps to two rows ≈ 96dp. Rail total ~152dp+ eats the entire remaining writing area from the previous attack. The Flexible surface collapses toward zero or overflows. The design states the ≥48dp rule and the seven control names but never sizes the rail against a phone with a keyboard.
  - FIX: On compact width the rail is thumbnails only; tapping a thumbnail opens a Photo options sheet carrying Side/Size/Move/Replace/Remove/Caption. Keep the caret-following highlight and the mini-diagram in the sheet. This also reuses the caption-sheet route the design already committed to.

#### SERIOUS (8)

- **User reads a long photo note in the Today feed after U2 truncates cards to 1200 characters, and taps 'Read more'.**
  - survives: False
  - what happens: There is nowhere to go. EntryCard (entry_card.dart:55-73) has no onTap, no GestureDetector and no InkWell; grep confirms the only day-detail entry points are calendar_screen.dart:29 and search_screen.dart:70. And the destination the plan names is a modal: DayDetailPanel is Center + ConstrainedBox with maxWidth 520 AND maxHeight 520 (day_detail_panel.dart:29-31), holding a scrolling list of cards. U1 raises maxWidth to 640 and is silent on maxHeight. So U2 removes the surface where users currently read whole notes and points them at a route that does not exist, ending in a ~380pt-tall porthole.
  - FIX: U2 adds an onTap on EntryCard that opens that entry's day detail scrolled to it, and U1 raises DayDetailPanel.maxHeight alongside maxWidth (or makes day detail a full-height sheet on compact screens). R4 is about width; the read surface also has a height problem.
- **Desktop user slowly drags the macOS window narrower while a Medium photo floats right.**
  - survives: False
  - what happens: The design promises "Shrink AND move, no jump, no breakpoint." It jumps. At the gate the float is 8.5 em = 136pt; one pixel narrower it becomes a centred BLOCK of clamp(384, 0.60×462, 0.82×462) = 379pt. The photo triples in size and the paragraph reflows around it in a single frame. That is the most visible discontinuity in the whole design and the spec asserts it does not exist.
  - FIX: Make the block width at the demote boundary continuous with the float width it replaces — start the block at the last float width and grow it as the measure falls — or stop claiming there is no breakpoint and state plainly that demotion is a step change.
- **Non-technical user writes a note with a bold word and a photo, on a desktop, trusting U1's claim that "editor line breaks equal read-view line breaks character for character."**
  - survives: False
  - what happens: They cannot be equal. The editor is length-preserving by construction and keeps `**` visible; the reader removes it. Every bold, italic, code, strike, link and heading marker is extra characters in the editor and zero in the reader, and a photo is a 38-character chip in the editor versus a reserved image box in the reader. Matching the column to 560pt makes the line breaks match only for a paragraph containing no syntax at all. The design sells a WYSIWYG guarantee it structurally cannot hold, and 'character for character' is exactly the kind of promise a reviewer will treat as a spec and a user will notice breaking.
  - FIX: Keep the equal 560pt column; delete the character-for-character claim and replace it with 'the same measure on every surface, so an unformatted paragraph breaks identically.' Nothing else changes.
- **Android user taps Remove on a photo in the rail, or backspaces once at the end of a photo line.**
  - survives: False
  - what happens: The photo is gone with no confirmation, and the design's entire justification is "Ctrl-Z restores it because it is text. Undoable beats confirmable." Android has no Ctrl-Z. Flutter's UndoHistory is wired to keyboard shortcuts; Gboard has no undo key and AdaptiveTextSelectionToolbar carries no undo item. So on the required mobile platform, Remove is an unconfirmed, unrecoverable destructive action — and so is a stray backspace that silently turns a valid photo line into a broken chip whose entry_photos row the next save correctly drops.
  - FIX: Put an explicit Undo control in the composer chrome (it costs one button over the existing UndoHistory), and show an inline 'Photo removed · Undo' chip in the rail slot for a few seconds after Remove. Keep no confirmation dialog.
- **User opens the composer on a blank note and wants to add their first photo.**
  - survives: False
  - what happens: The design never names the affordance. U8 specifies 'PhotoRail with caret-following highlight, tap-only Side/Size/Move/Replace/Remove/Caption' — every control operates on a photo that already exists. The picker, the splice-at-caret and the blob path are all fully specified; the button that starts them is not, and with zero photos the rail is presumably empty. The primary gesture of the entire feature has no stated entry point, which is also where a first-run user learns the feature exists at all.
  - FIX: Specify an always-present 'Add photo' tile as the first cell of the rail (and a keyboard-accessible control in the composer header), so the rail is non-empty and self-explanatory on a blank note.
- **U7 lands (entry_photos reindexed on save) but U8/U9 have not shipped, or they ship without touching EntryCard.**
  - survives: False
  - what happens: Every photo renders twice. entry_card.dart:70-71 still mounts InlinePhotoStrip whenever photos.isNotEmpty, and both feeds still watch photosForEntryProvider (today_entry_feed.dart:106-108, day_detail_entry_tile.dart:26-28). The moment reindex starts writing rows, the legacy 56px attachment strip appears under every note — under a dim chip in U7, and under the real inline photo in U8. The plan never says the strip is removed, and its BREAKS WHEN list never mentions it.
  - FIX: U7 removes InlinePhotoStrip from EntryCard in the same unit that starts populating entry_photos, and the build order says so explicitly.
- **User starts a new note, types two paragraphs, backs out and confirms Discard. Later the same day they tap 'Write a note' again.**
  - survives: False
  - what happens: Ambiguous, and probably wrong. NoteWriter.save is specified to delete the draft; the discard path is not. If discard leaves the file, the fresh blank composer silently restores the text the user just deliberately threw away, with a chip that says 'Draft restored'. Separately the slot key `new-YYYY-MM-DD` is one slot per day, so two different abandoned new notes on the same day overwrite each other and the survivor surfaces in an unrelated composer session. Both are exactly the 'surprising' class the brief asks about.
  - FIX: State that Discard deletes the draft file as part of the same action, and key the new-note draft by the composer session (a ULID minted on open) rather than by date, so an abandoned draft only ever returns to the session that made it.
- **Non-technical user is told this is a 'feature-rich live Markdown editor' and tries to make a word bold or add a heading.**
  - survives: False
  - what happens: There is no affordance at all. The design adds no formatting toolbar; the only composer chrome specified is the PhotoRail. A user who does not already know Markdown gets a plain writing surface that occasionally greys out characters they typed. Discoverability of bold, italic, headings, lists and quotes is zero, and on a phone there is no keyboard shortcut path either. The visible-markers decision is defensible; the absence of any way to learn the syntax is not.
  - FIX: Add a compact format bar above the keyboard on compact screens and in the composer header on desktop: B / I / H / list / quote / link, each inserting or toggling markers at the selection. It also gives Undo and Add photo a home, resolving two other findings at the same cost.

#### ANNOYING (4)

- **The stated headline risk: editor shows a chip and a rail, reader shows a float. Does the user feel betrayed at save?**
  - survives: True
  - what happens: Mostly survives, but not for the reason the design gives. On phones the editor and reader agree completely — both stack — so the split never appears where most users live. It appears only on desktop, where the 560pt equal measure and the rail's planFloat-driven mini-diagram genuinely do predict the outcome before the save. The residual surprise is that the photo physically relocates (rail below the text → inline in the flow), which the mini-diagram does not depict. That is a modest, one-time learning cost, not a coherence failure.
  - FIX: Make the mini-diagram show the photo's position in the paragraph, not just the words 'above and below' — it already runs planFloat, so drawing the box costs nothing and removes the relocation surprise.
- **An existing user who has been writing notes at composerBodySerif 19pt opens the composer after U1.**
  - survives: True
  - what happens: Their writing text shrinks. The design describes U1 as raising body type 'from bodySerif 13.5/1.5 to noteBody Newsreader 16/1.6' — true for the READER (note_body.dart uses bodySerif), but the composer is typography.dart composerBodySerif at fontSize 19, so the same change is a 16% reduction in the editor. It is necessary for the equal-measure story and it is fine, but the spec presents a reduction as an increase, which will read as an unintended regression in review.
  - FIX: State both moves explicitly in U1: reader 13.5 → 16, composer 19 → 16, and say the convergence is the point.
- **TalkBack user reads a note with a right-floated photo in the read view.**
  - survives: True
  - what happens: The Row places head text and photo side by side and the tail below, so the semantic order for a right float is head, image alt, tail — the image is announced in the middle of a sentence, frequently mid-clause since the split is at a line boundary rather than a sentence boundary. Not broken, but jarring, and the design's accessibility argument stops at WCAG 2.5.7 and tap targets.
  - FIX: Wrap the head/tail pair so the paragraph reads continuously and the photo's semantics follow it — a Semantics sort key or MergeSemantics over the sliced paragraph with the image excluded from the inline order.
- **User wants to caption a photo while writing.**
  - survives: True
  - what happens: They leave the composer for a modal sheet and come back. The design is honest that this exists to stop a second EditableText breaking three composer test files and one integration test at the tester.widget<EditableText> cast. It works, but a test cast is driving the interaction model, and captioning is a core scrapbook gesture that now costs a context switch.
  - FIX: Change the four test sites to .first or a keyed finder and allow an inline caption field under the rail thumbnail. If that is deferred, say so as a deferral rather than as a design principle.

---
