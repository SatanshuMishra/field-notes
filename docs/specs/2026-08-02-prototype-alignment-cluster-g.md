# Prototype Design Alignment — Cluster G (Capture composers) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **G — Capture composers**
MSPs: **G1, G2, G3, G4, G5, G6, G7, G8**
Base: `origin/main` at `dd63025`
Citation source: `docs/prototype/project/Field Notes.dc.html`

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec on matters of fact.** Where this document reproduces parent text, it reproduces it verbatim. Where this document **corrects** the parent, the correction is marked inline with `CORRECTION` and states what the parent said, what the source actually says, and which line proves it. Where this document **adds** a value the parent omitted, it is marked `ADDITION` and carries its own prototype citation. Where a reader needs material this slice omits — findings §3.1–§3.6, MSPs A1–F4 and H1, the excluded-elements table §6.1 — the parent spec on `main` is the authority.

**Clusters A, B, C, D, E and F are already merged and are this run's base.** The token layer closed with Cluster A, and Cluster G is the first cluster since to reopen it: it adds **seventeen** new token values, every one of them named and justified in §0's token ledger. Three recon passes ground this slice — G1/G2/G3, G4/G5/G6, and G7/G8 — and all three are reproduced into the resolutions and tables below rather than referenced. Every prototype line this slice cites was independently re-opened from `Field Notes.dc.html` while composing it; every app anchor was independently re-read from the base commit.

**Base SHA correction.** The dispatch named `a6cdcc2`. `origin/main` has since advanced to **`dd63025`** (`chore: hand off the cluster f ledger (#111)`), which is a ledger-only commit: `git diff a6cdcc2 dd63025 -- lib/ test/` is empty. Every measurement and every line citation in this document is against `dd63025`, and the two are interchangeable for code purposes.

### The headline recon result, stated up front

**Cluster G is the largest, most seam-hostile cluster in the spec, and five of its eight MSPs cannot be executed from the parent spec as written.**

- **G1's declared file fence does not contain the thing G1 changes.** Every value G1 targets — width, surface, border, radius, shadow — lives in the three `*_sheet.dart` files, one layer below the three `*_composer.dart` files G1 names. Only the scrim is genuinely in the declared fence (R2).
- **G1's scrim cannot be expressed as a `barrierColor` at all**, and the naive fix silently kills barrier dismissal on the note composer — the one composer of the three that has it (R4).
- **G5 grows the `VoiceRecorder` interface, which is an `abstract interface class` with three implementers.** Two of them are test files. The suite does not go red; it fails to **compile** (R27). G7 does the same to `VideoRecorder`, which has **seven** (R51).
- **G6's two headline surfaces have no mechanism in the app.** There is no toast host of any kind — `grep -rn "OverlayEntry\|ScaffoldMessenger\|showSnackBar" lib` returns zero hits — and the toast must appear *after* the composer dialog pops, on the screen behind it (R40).
- **G8's pause/resume is physically unreachable on macOS.** The vendored `camera_macos` backend has no pause API in Dart or in Swift. A UI-only pause would write a `durationMs` to the database that disagrees with the file on disk (R54).

**Fifty-nine resolutions are decided in this section.** No implementer should ever meet one of them mid-flight.

This matters because of this project's own history: the C5 caption and three C7 ladder rows were lost precisely because an implementer met an unreachable anchor or a stale target value while executing, and made a judgement call instead of stopping. This section exists so that no such call is ever needed.

---

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Fifty-nine decisions. Each states the problem, the chosen resolution, and what was rejected and why. Where a resolution widens an MSP's fence, the widening is **declared** and carries the standard obligation: every other consumer's tests pass **unmodified**.

#### G1 — shared composer shell

**R1 — `ComposerShell` composes its own `DecoratedBox`. `lib/design/widgets/sticker_card.dart` is NOT opened.**

*Problem.* G1's panel needs a 2px border and `overflow: hidden`. The three sheets build their panel with `StickerCard`, whose `build()` hardcodes `border: Shapes.outline` (`sticker_card.dart:30`; `Shapes.outlineWidth = 1.5`, `shapes.dart:6`) and renders a `DecoratedBox` (`:27`), which **never clips**. The constructor (`:8-16`) exposes `padding`, `surface`, `borderRadius`, `shadow`, `rotationDegrees` — no `border`, no `clipBehavior`. Measured blast radius: **16 `StickerCard(` call sites across 16 files in `lib/`**.

*Resolution.* `ComposerShell` composes the panel locally:

```dart
Container(
  clipBehavior: Clip.hardEdge,
  decoration: BoxDecoration(
    color: Palette.composerPaper,
    border: Border.all(color: Palette.ink, width: _kComposerBorderWidth),
    borderRadius: BorderRadius.circular(Shapes.radiusXl),
    boxShadow: Shadows.panelLift,
  ),
  child: ...,
)
```

This is the identical shape Cluster F resolved at its own R1, for the identical reason. The clip is not cosmetic: the sprig at `top:-10; right:-8` (`:461`) sits at negative offsets **inside** an `overflow:hidden` box and is visibly cropped by the panel edge. Without the clip the sprig paints outside the 2px border and the panel reads wrong, and G7's viewport cannot bleed edge to edge.

*Rejected: add `border` / `clipBehavior` parameters to `StickerCard`.* A fence widening onto a shared primitive with 16 call sites, re-opening A4's sticker contract mid-spec, buying nothing the shell cannot do in a file it owns outright.

---

**R2 — G1's Files list is WIDENED to name the three `*_sheet.dart` files. Declared, and it adds no dependency edge.**

*Problem, and it is structural.* G1's declared files are `text_composer.dart`, `voice_composer.dart`, `video_composer.dart` (parent `:1471`). Those three files contain only `showGeneralDialog` plus a Riverpod connector. Every value G1's target block names lives one layer down:

| Target | Actual owner | Anchor |
|---|---|---|
| width 420 (note) | `lib/features/capture/text/text_composer_sheet.dart` | `:19` `this.maxWidth = 420` |
| width 420 (voice) | `lib/features/capture/voice/voice_recorder_sheet.dart` | `:25` `this.maxWidth = 420` |
| width 460 (video) | `lib/features/capture/video/video_recorder_sheet.dart` | `:40` `this.maxWidth = 460` |
| surface / border / radius / shadow, all three | `StickerCard(surface: Palette.cardBright, padding: EdgeInsets.all(20))` | text `:62-64`, voice `:52-54`, video `:84-86` |
| flat scrim `Palette.ink.withValues(alpha: 0.32)` | the three `*_composer.dart` | text `:102`, voice `:150`, video `:347` |

Only the scrim is in the declared fence.

*Resolution.* `ComposerShell` owns `Center` + the width clamp + the panel decoration + the sprig. Each `*_composer.dart` wraps its connector as `DialogHost(child: ComposerShell(child: <Connector>(...)))` (R6). Each `*_sheet.dart` **deletes** its `Center` / `ConstrainedBox` / `StickerCard` wrapper, and its now-dead `maxWidth` parameter is removed with it. **G1's Files list therefore gains all three `*_sheet.dart` files.**

*This widening adds no edge to the dependency chain.* `text_composer_sheet.dart` is G2's (edge G1 -> G2, already declared); `voice_recorder_sheet.dart` is G5's (G1 -> G5, already declared); `video_recorder_sheet.dart` is G7's (G1 -> G7, already declared). See §0's FILE-OVERLAP MATRIX.

*Rejected: thread `maxWidth: 760` and a `panel:` decoration down into each sheet.* It ships three copies of the panel and no shared shell, which is the outcome G1 exists to produce.

---

**R3 — 760 is a CLAMP, not a `maxWidth`. `LayoutBuilder` + `min(760, available)`.**

*Problem.* All three sheets use `ConstrainedBox(maxWidth: …)` (text `:60-61`, voice `:50-51`, video `:82-83`), which is a ceiling — the panel currently shrink-wraps its `Column`. `maxWidth: 760` alone produces whatever the content wants, not a 760px panel. `:460` is `width:760px`, a fixed width.

*Resolution.* Inside `ComposerShell`:

```dart
LayoutBuilder(
  builder: (BuildContext context, BoxConstraints constraints) =>
      SizedBox(width: math.min(_kComposerWidth, constraints.maxWidth), child: panel),
)
```

**Test-surface hazard, and it is not theoretical.** The `flutter_test` default surface is 800x600 and `captureHarness` (`test/features/capture/core/capture_test_support.dart:16-21`) sets **no** surface size, so it inherits 800x600. A hard 760 leaves 20px per side and overflows the moment any test sets a phone surface. The `math.min` clamp is what makes that safe; a bare `SizedBox(width: 760)` is not acceptable.

*Rejected: `BoxConstraints.tightFor(width: 760)`.* Same overflow on a narrow surface, with a thrown assertion instead of a clamp.

---

**R4 — The scrim is painted by the shell, and its own layer MUST be `IgnorePointer`. This is the single highest-risk regression in G1.**

*Problem.* `:459` is a radial-gradient plus `backdrop-filter:blur(7px)`. `showGeneralDialog`'s `barrierColor` is a flat `Color` and cannot express either. The three composers set it at text `:102`, voice `:150`, video `:347`.

*Resolution.* `barrierColor: Color(0x00000000)` on all three; the shell paints a full-screen `BackdropFilter` + radial-gradient `DecoratedBox` behind the panel. **That layer is wrapped in `IgnorePointer`.** The framework's `ModalBarrier` remains beneath it and is what implements dismissal, so a hit-testing scrim silently eats the tap.

**The failure is invisible on two of three paths.** `barrierDismissible` is `true` only on the note composer (`text_composer.dart:100`); voice (`:148`) and video (`:346`) are `false`. A non-ignoring scrim therefore kills exactly one behaviour, on exactly one composer, with no compile error and no analyze warning. Treat `IgnorePointer` as load-bearing, not hygiene.

*Blur conversion.* CSS `blur(7px)` is a Gaussian standard deviation of `7 x 0.5 = 3.5`, not `sigmaX: 7`. Use `ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5)`. This is the app's **first** `BackdropFilter` — `grep -rn "BackdropFilter\|ImageFilter" lib` returns zero hits (the only `blur` in the codebase is `blurRadius` on `BoxShadow`), so there is no precedent to match and no measured performance history.

---

**R5 — Radial-gradient geometry: `Alignment(0, -0.36)`, radius 1.2. The obvious conversion is wrong.**

`:459` is `radial-gradient(120% 100% at 50% 32%, rgba(42,32,22,.36), rgba(28,20,12,.62))`. Flutter's `RadialGradient` is circular with a single `radius`, so the 120% x 100% ellipse is approximated:

```dart
RadialGradient(
  center: Alignment(0.0, -0.36),
  radius: 1.2,
  colors: <Color>[Color(0x5C2A2016), Color(0x9E1C140C)],
)
```

**The trap is the `Alignment` conversion.** CSS `32%` on the y axis maps to `2 x 0.32 - 1 = -0.36`, not `-0.32`. `Alignment` is a -1..1 space, CSS percentages are a 0..100 space. Arithmetic for the colours: `.36 x 255 = 91.8 -> 0x5C`; `.62 x 255 = 158.1 -> 0x9E`; `rgb(42,32,22) = 0x2A2016`; `rgb(28,20,12) = 0x1C140C`.

---

**R6 — `DialogHost` stays the OUTERMOST wrapper. `DialogHost(child: ComposerShell(...))`, never the reverse.**

`test/design/feedback/dialog_host_test.dart` imports all three `*_composer.dart` and all three `*_sheet.dart` (`:10-17`) and asserts dialog ancestry. Re-parenting the connector under `ComposerShell` changes the tree that test walks. If `ComposerShell` wraps `DialogHost`, A3's guarantee — a `Material` ancestor above every dialog subtree — is silently inverted and the yellow-double-underline defect returns inside the shell. Keep the order and the test stays green unmodified.

---

**R7 — Each `*_sheet.dart` must stay self-sufficient when pumped bare. Verify by pumping each one alone.**

*Problem.* `text_composer_test.dart:48-51`, `voice_recorder_sheet_test.dart` and `video_recorder_sheet_test.dart` pump their sheets **directly**, not through `showTextComposer`. Once R2 moves `Center` / `ConstrainedBox` out of the sheet and into the shell, a directly-pumped sheet is unconstrained inside `captureHarness`'s `Center` (`capture_test_support.dart:19`). An unbounded-width `Column(crossAxisAlignment: stretch)` under a `Center` **throws a layout assertion** — a hard failure, not a soft diff.

*Resolution.* Each sheet's root becomes width-agnostic: `Column(mainAxisSize: MainAxisSize.min)` with no `stretch` at the root. The shell supplies the box; the sheet never assumes one. **Each sheet is pumped bare as part of G1's own verification**, before the MSP is called done.

---

**R8 — The note header's title and meta line are composed by the CONNECTOR and passed down. `{clock}` resolves through `todayClockProvider`.**

*Problem.* `TextComposerSheet`'s constructor (`:7-20`) takes `title` as a flat `String`. `TextComposerConnector` has `widget.date` (`text_composer.dart:31`) and passes **nothing** date-shaped to the sheet (`:88-93`). The header's meta line `{longDate} · {clock}` (`:465`) has no source at all: nothing in the composer path reads wall-clock time.

*Resolution.* The connector composes both strings and passes them down as `title` and a new `metaText` parameter — the shape `EditNoteConnector` already uses (`day_detail_edit_note.dart:57`). The sheet stays dumb.

- `{longDate}` is `headerDateLabel(parseDateKey(date))` (`lib/features/today/today_date.dart:48`, `:74`), reused, not re-authored. On a `null` parse the label falls back to the raw date key rather than throwing.
- `{clock}` is `ref.read(todayClockProvider)()` formatted **zero-padded 24-hour `HH:mm`**, matching the prototype's own `fmtClock` at `:1315`: `(h<10?'0':'')+h+':'+(m<10?'0':'')+m`. `todayClockProvider` is `DateTime Function()` (`lib/features/today/today_providers.dart:15`), already the app's injectable clock seam and already used cross-feature. A bare `DateTime.now()` in a widget build is forbidden here: it makes the header non-deterministic and the composer untestable.
- The separator is U+00B7 MIDDLE DOT.

Import `package:field_notes/features/today/today_providers.dart` directly, not the `today.dart` barrel, which re-exports `today_screen.dart`.

---

**R9 — `Palette.composerPaper` is the ONLY token G1 adds. Every other value in G1's block already shipped.**

Verified against `lib/design/tokens/` on this base:

| Value G1 names | Status |
|---|---|
| `Palette.composerPaper` `#FBF3E4` | **MISSING — G1 adds it.** Absent from `palette.dart`; `cardBright` is `#FFFAF1`, `cardWarm` `#F8EFE0`, `cardAlt` `#F6EFE0` — none is `#FBF3E4` |
| `Shadows.panelLift` | shipped **exact**, `shadows.dart:105-112` |
| `Shapes.radiusXl` 20 | shipped, `shapes.dart:17` |
| `Shapes.radiusPill` 13 | shipped, `shapes.dart:14` |
| `Shadows.control` 1.5/1.5/0 ink | shipped **exact**, `shadows.dart:33-40` |
| `TypographyTokens.composerTitleAccent` | shipped **exact**, `typography.dart:125-130` |
| `TypographyTokens.caption9Sans` | shipped **exact**, `typography.dart:222-227` |
| `TypographyTokens.captureLabelSans` | shipped, `typography.dart:195-199` (no colour; `.copyWith(color: Palette.onAccent)` per the target) |
| `Palette.onAccent` / `ink25` / `ink20` | shipped, `palette.dart:47` / `:26` / `:24` |

---

**R10 — `lib/design/art/` does not exist. G1 creates it with a barrel, matching the established convention.**

`grep -rn "sprig\|Sprig" lib test` returns zero hits in code. `lib/design/` uses one barrel per subdirectory — `flowers.dart`, `motion.dart`, `widgets.dart`, `tokens.dart`, `feedback.dart` all exist. G1 therefore ships `lib/design/art/sprig_art.dart` **plus** `lib/design/art/art.dart` as its barrel, and imports through the barrel. No SVG dependency (parent §6.2); the sprig is a `CustomPainter`: stem stroked `#8A9A63` at width 2.2, three leaves filled `#9BB078`, `#8FA66C`, `#A3B782` (`:461` mount, values from the parent's own `:250` finding row).

---

#### G2 — note composer writing surface

**R11 — CORRECTION: the editor's current style is `bodySerif` at **13.5**, not 16. The jump is 13.5 -> 19.**

The parent's G2 block reads `(from bodySerif 16 / height 1.5 …)`. `TypographyTokens.bodySerif` is `fontSize: 13.5` (`typography.dart:63-69`). Non-blocking — the target is 19 either way — but recorded so the error stops recirculating, and so no implementer "corrects" 19 down toward a phantom 16.

Verbatim current config, `text_composer_sheet.dart:103-112`: `style: TypographyTokens.bodySerif`, `cursorColor: Palette.coral`, `backgroundCursorColor: Palette.muted`, `keyboardType: TextInputType.multiline`, `minLines: 4`, `maxLines: 8`.

---

**R12 — `expands: true` + `scrollController`. `minLines` and `maxLines` must BOTH become null, and a stale `maxLines: 8` throws.**

*Problem.* A 440px scrolling page cannot be built from `maxLines: 8` — the editor caps at eight lines and will not fill the box. `EditableText` asserts `maxLines == null && minLines == null` whenever `expands` is true.

*Resolution.* `minLines: null, maxLines: null, expands: true` inside a `SizedBox(height: 440)`, with an explicit `ScrollController` passed to `EditableText.scrollController` (currently unset) and shared with `Scrollbar(thickness: 9, controller: …)` so the 9px scrollbar has something to attach to.

**This is the one place in G2 where a partial edit is worse than no edit.** `expands: true` left beside a stale `maxLines: 8` throws an assertion in `EditableText`'s constructor, which reds **every** text-composer test at once. That is an implementation bug, not a test problem — do not touch the tests.

*Rejected: `maxLines: null` + an outer `SingleChildScrollView`.* `EditableText` owns its own scroll controller; nesting a second scrollable double-scrolls and breaks caret-into-view.

---

**R13 — The placeholder stays in the existing `Stack` + shared padding. Do NOT convert it to `Positioned`.**

`text_composer_sheet.dart:82-102` is a `Stack` whose `IgnorePointer` hint and `EditableText` both inherit the parent `Padding` (`:78-81`). G2's target places the placeholder at `top: 44, left: 54` while the page padding becomes `44 top / 54 horizontal / 120 bottom` — they coincide, so the existing structure already puts it in the right place once the padding values change. A `Positioned` inside a scrolling page detaches from the scroll and the placeholder floats over scrolled text.

The hint's `ValueListenableBuilder` on `_controller` (`:85-101`) is the empty-state mechanism and **must survive** — G3's guard toast reuses the same emptiness signal.

---

**R14 — Two new type tokens and `Palette.ink34`. The 34% alpha is not on the existing ladder.**

`typography.dart` has no 19px serif and no 19px serif italic; `bannerSerif` is 19 but w500 with **no** `height` (`:42-47`), and `bodySerifItalic` is 13.5 (`:71-78`). `Palette` has `ink30` (`:27`) and `ink35` (`:28`) but no `ink34`.

*Resolution.* G2 adds three token values:

| Token | Value |
|---|---|
| `TypographyTokens.composerBodySerif` | Newsreader, 19, w400, `height: 2.0` (= 38/19 exactly), `Palette.ink` |
| `TypographyTokens.composerPlaceholderSerif` | same + `fontStyle: FontStyle.italic`, colour `Palette.ink34` |
| `Palette.ink34` | `Color(0x574A3B2E)` — `0.34 x 255 = 86.7 -> 0x57` |

`ink34` rather than a runtime `withValues(alpha: 0.34)` because the palette's ladder is all `const` and keeping the style `const` is what lets it sit in the token file at all. Naming them in the token layer follows Cluster A's precedent (40+ named styles); a local `TextStyle` in the sheet is the rejected alternative.

---

**R15 — `DashedDivider` is ALREADY fully parameterised. It is not a second `StickerCard`.**

The G1/G2 recon flagged this as an open primitive-resolution item. Resolved by reading the file: `lib/design/widgets/dashed_divider.dart:6-13` declares `axis`, `thickness`, `color`, `dashLength`, `dashGap`, all optional with defaults, and `Shapes.dashLength = 6` / `dashGap = 4` exist (`shapes.dart:29-30`). Both dashed rules this cluster needs are reachable with no widget change: G1's header rule is `DashedDivider(thickness: 1.5, color: Palette.ink25)`, G2's surface rule is `DashedDivider(thickness: 1, color: Palette.ink20)`.

---

#### G3 — note composer copy and edit variants

**R16 — CORRECTION: the parent's return-contract sentence is wrong. There are TWO contracts, and `showEditNote` returns `Future<bool?>`.**

The parent's G3 reads: *"The composer's return contract (an entry id, or null on cancel) is unchanged so `day_detail_edit_note.dart` and `capture_route.dart` keep working."*

`showEditNote` is `Future<bool?>` (`day_detail_edit_note.dart:67`), popping `true` at `:41` and `false` at `:60`. It never returns an entry id. Only `showTextComposer` / `showVoiceComposer` / `showVideoComposer` return `String?`, matching `CaptureRouteOpener` (`capture_route.dart:4-7`).

*Resolution.* Both contracts are preserved, and they are different. An implementer who "preserves the entry-id contract" on the edit path breaks `day_detail_panel`'s refresh, which keys on the `bool`.

---

**R17 — CORRECTION and ADDITION: `:1387-1388` carries a `confirmLabel` and a `danger` flag the parent omits, and the non-danger confirm button is CORAL.**

`:1388` verbatim: `if(ref){ this.askConfirm(dev,{ title:'Save changes?', message:'Update this note with your edits?', confirmLabel:'Save changes', danger:false, onYes:… }); return; }`. The parent's G3 gives only the title and the message.

`:1692` `confirmYesStyle` has **two** branches, both verified verbatim: `danger` is `background:#c0392b`, non-danger is `background:#c76a54`; both are `font:600 12px 'Instrument Sans'; color:#fff; border:1.5px solid #4a3b2e; border-radius:11px; padding:9px 16px; box-shadow:1.5px 1.5px 0 #4a3b2e`. So G3's confirm button is `StickerButtonVariant.primary` with `labelStyle: TypographyTokens.captureLabelSans` — **not** `danger`, which `delete_all_dialog.dart:50` would otherwise suggest by proximity.

Reuse the existing constant `editNoteSaveLabel` (`day_detail_edit_note.dart:11`) for the confirm's label rather than authoring a second `'Save changes'` literal.

---

**R18 — ADDITION: the empty-save guard is at `:1386`, which the parent never cites, and its predicate is TEXT-EMPTY **AND** NO PHOTOS. The app's predicate is text-only, and that is a decision, not an oversight.**

`:1386` verbatim: `if(!t && pc===0){ this.flash(dev,'Write something first'); return; }`.

*Resolution.* The app's guard is `text.trim().isEmpty`. `PhotoTray` exists (`lib/features/capture/photo/photo_tray.dart`) but is **mounted by nothing in `lib/`** — it is dead UI and a parent preserve row, and OQ-6 (the photo attachment model) is explicitly still open. A `&& photos.isEmpty` clause would gate on a surface the user cannot reach. When OQ-6 resolves and the tray is wired into the composer, the clause is added in that spec; the guard is one predicate and this is a one-line change.

---

**R19 — The guard toast and the confirm dialog are BOTH shipped patterns. Neither is a missing mechanism. Copy `mood_banner_for_date.dart`.**

The parent implies both are new. They are not:

- **Confirm dialog — two shipped precedents.** `_confirmMoodChange` -> `_MoodChangeConfirmDialog` (`mood_banner_for_date.dart:58-71`, `:155-202`, landed four commits ago in `a6cdcc2`) and `confirmDeleteAll` (`delete_all_dialog.dart:5-12`). Both are `showDialog<bool>` + `Center` + `Material(type: MaterialType.transparency)` + `ConstrainedBox(maxWidth: 420)` + `StickerCard(cardBright)` + `titleSerif` + `bodySans` + a `Wrap` of two `StickerButton`s. G3's `Save changes?` is a third instance of an established shape.
- **Guard toast — shipped, and its timing already matches the prototype.** `mood_banner_for_date.dart:19` declares `_kToastLifetime = Duration(milliseconds: 1900)` — identical to `flash`'s 1900 at `:1323`. The pattern (`:73-85`, rendered at `:148`) is a `String? _toastMessage` + `Timer?` in state, `setState` then `Timer(lifetime, …)`, cancelled in `dispose` (`:42-46`).

**`Timer` cancellation in `dispose()` is mandatory, and it is a hard test requirement, not hygiene.** `_TextComposerSheetState.dispose` (`text_composer_sheet.dart:49-54`) currently disposes only the controller and the focus node. `AutomatedTestWidgetsFlutterBinding` asserts `!timersPending` after the tree is disposed; a leaked 1900ms timer fires `setState` after unmount and reds every text-composer test with a stack trace that names the binding, not the composer.

Promote `_kToastLifetime` to a shared constant rather than authoring a third copy of `1900`.

---

**R20 — `showEditNote`'s `pageBuilder` has NO `DialogHost` and NO `Material`. G3 fixes it. One line, one test case, squarely in fence.**

`day_detail_edit_note.dart:79` returns `EditNoteConnector(entry: entry)` **bare**. The three composers all wrap: `text_composer.dart:109`, `voice_composer.dart:157`, `video_composer.dart:355`. `test/design/feedback/dialog_host_test.dart` imports the three composers, both chooser files and the mood picker (`:6-19`) — it does **not** import `day_detail_edit_note.dart`. A3 shipped a fix and a regression test that both skip the fourth dialog on the same widget.

This is invisible today only because `TextComposerSheet` imports `package:flutter/widgets.dart` alone (`:1`) and touches no Material widget. It stops being invisible the moment G3 adds a `showDialog`-based confirm on that path — and note that `captureHarness` wrapping in `MaterialApp` + `Scaffold` does **not** help, because a `showGeneralDialog` route mounts in the overlay above the `Scaffold`.

*Resolution.* G3's fence gains one line — `pageBuilder` returns `DialogHost(child: EditNoteConnector(entry: entry))` — and one case in `dialog_host_test.dart`. `day_detail_edit_note.dart` is already a G3 file; `test/design/feedback/dialog_host_test.dart` is a **declared, bounded** addition to G3's fence: one case added, no existing assertion touched.

---

**R21 — `Saving...` -> `Saving…` is a two-character diff that reds three assertions across three files.**

`text_composer_sheet.dart:17` `savingLabel = 'Saving...'` is the last ASCII-ellipsis label in the app; voice (`:23`) and video (`:36`) already use U+2026. The reds are `text_composer_save_hang_test.dart:56` (a test **name**), `:81`, `:87`, and `integration_test/capture_ui_flow_test.dart:87`. `test/repro/capture_save_hang_repro_test.dart:69` contains the string in a description only — cosmetic, not an assertion.

---

#### G4 — capture chooser

**R22 — G4 is a structural CLONE of `showMoodPicker`. The phone/desktop split has a shipped mechanism; do not invent one.**

`ShellLayout` and `resolveShellLayout(TargetPlatform)` are at `lib/app/shell/shell_layout.dart:3-9`. `showMoodPicker` (`lib/features/mood/mood_picker.dart:13-69`, landed as #108) is a line-for-line precedent for everything G4 needs: an optional `ShellLayout? layout` override, `resolveShellLayout(Theme.of(context).platform)` resolved **before** `showGeneralDialog`, a per-branch `barrierColor`, a per-branch `transitionDuration`, and a `SlideTransition` vs `Fade`+`Scale` `transitionBuilder`. `MoodPickerSheet` branches its own body on the same enum (`mood_picker_sheet.dart:47`).

*Resolution.* `CaptureChooserSheet` gains `ShellLayout layout = ShellLayout.sidebar` and `showCaptureChooser` gains `ShellLayout? layout`, mirroring `mood_picker_sheet.dart:36` and `mood_picker.dart:16-19`. The default stays **desktop** for the same reason Cluster F's R4 required it: direct-pump tests are the only desktop coverage that exists (R25). G4 does not open `shell_layout.dart`.

The phone entrance is `fn-sheet` at `:25` — `from{translateY(100%)} to{translateY(0)}`, `.24s cubic-bezier(.2,.8,.2,1)` — a **pure slide**, identical to `_kMoodSheetEntrance` / `_kMoodSheetCurve` at `mood_picker.dart:10-11`. Reuse those constants or promote them; do not add a fade or a scale the design does not have.

---

**R23 — The three chooser rows are composed LOCALLY. `StickerButton` cannot express any of them.**

*Problem.* `StickerButton` hardcodes `border: Shapes.outline` (`sticker_button.dart:51-52`) and fixes radius / padding / shadow per variant (`:94-121`). `Shapes.radiusMd` 14 is not any variant's radius, and `StickerButtonVariant.secondary` (no shadow) is radius 12, so row 1's `radius 14 + Shadows.emphasis` is unreachable and rows 2-3's `radius 14 + no shadow` is unreachable.

*Resolution.* Compose the row inside `capture_chooser_sheet.dart` as `GestureDetector` + `DecoratedBox`. This is not a widening of `StickerButton`'s job: the target row is a two-line icon-plus-column, not a labelled button. `onTap` is `null` when the option is unavailable, which is what keeps the existing "tapping an unavailable row is a no-op" assertion green.

The 20x20 row icon is **reachable**: `CaptureIcon(glyph:, color:, size:)` (`lib/design/icons/capture_icons.dart:5-27`) with `CaptureGlyph { pencil, mic, video }` (`:3`) mapping 1:1 to the three rows. `today_capture_buttons.dart:18-27` already has `_captureGlyphFor(EntryType)` — lift or duplicate the nine-line switch. Pass `size: 20`; the default is 17.

---

**R24 — G4 adds no token. The one gap is a 14/w600 sans style, resolved with `copyWith`.**

Every other value resolves against shipped tokens: `Palette.panelTop` (`:8`), `ink30` (`:27`), `cardWarm` (`:12`), `coral` (`:31`), `muted` (`:39`), `onAccent` (`:47`); `Shapes.radiusMd` 14 (`:15`), `radiusSheet` 22 (`:18`); `Shadows.emphasis` (`:51-58`), `chooserSheetLift` (`:123-130`); `TypographyTokens.sectionSerif` = Newsreader 17 w500 ink (`:56-61`), `caption10Sans` = Instrument Sans 10 w400 (`:208-213`) — an **exact** match for the row subtitle.

The row **title** is Instrument Sans 14 w600. The closest token is `labelSans`, 14 **w500** (`typography.dart:167-172`). *Resolution:* `TypographyTokens.labelSans.copyWith(fontWeight: FontWeight.w600)` locally in `capture_chooser_sheet.dart`. A new type token would open `lib/design/tokens/**` for a single consumer; G4 does not open the token layer at all.

The phone barrier colour `Color(0x572A241D)` is already inlined at `mood_picker.dart:25` for the mood sheet's phone branch. Reuse the literal in `capture_chooser.dart`, matching the app's established inline-scrim idiom; do not promote it to `Palette`.

---

**R25 — Under `flutter test` every existing chooser test already drives the PHONE branch. Desktop is untested by construction, and that is recorded, not fixed.**

`defaultTargetPlatform` is forced to `android` under `flutter test` by an assert in the Flutter SDK's `_platform_io.dart`, keyed on the `FLUTTER_TEST` environment variable. `ThemeData.platform` defaults to `defaultTargetPlatform`, and `captureHarness` is a bare `MaterialApp` with no `platform` override, so `resolveShellLayout(Theme.of(context).platform)` returns `bottomBar` in every widget test in this repo.

*Consequence.* Every assertion in `capture_chooser_test.dart` exercises the new phone bottom sheet. The desktop centred-dialog branch has **zero** coverage unless a test wraps in `Theme(data: ThemeData(platform: TargetPlatform.macOS))` or passes `layout: ShellLayout.sidebar` explicitly. Per the admission gate this is a styling change and warrants **no new test** — but the desktop default on the widget (R22) is what preserves the option, and the fact is recorded here so no future MSP mistakes green for covered.

---

#### G5 — voice recorder stage, timer and waveform

**R26 — CORRECTION: the bar generator is `:1258-1262`, not `:1261-1263`.**

`liveBars()` opens at `:1258`. The heights array is at **`:1259`** (`[0.3,0.65,0.95,0.5,0.8,0.4,1,0.55,0.85,0.35,0.7,0.45]` — matching the parent's values exactly). The colour threshold and the per-bar durations are at **`:1261`**: `background: h>0.6?'#c76a54':'#dcae9a'`, `animation: fn-bob ${0.7+(i%4)*0.15}s`. `:1262` is a closing brace and `:1263` is blank.

Do not conflate this with `bars()` at `:1256`, which is G8's **static** silhouette and uses a **three**-tone ramp with different thresholds (R56).

---

**R27 — Growing `VoiceRecorder` does not red the suite; it breaks the BUILD. Three implementers, two of them test files.**

`VoiceRecorder` is an `abstract interface class` (`voice_recorder.dart:30`) exposing only `hasPermission / start / stop / cancel / dispose`. `implements` means every implementer must carry every member:

| Implementer | Anchor |
|---|---|
| `RecordVoiceRecorder` | `lib/features/capture/voice/record_voice_recorder.dart:22` |
| `FakeVoiceRecorder` | `test/features/capture/voice/voice_test_support.dart:13` |
| `_HangingStopRecorder` | `test/features/capture/voice/voice_composer_save_hang_test.dart:15` |

*Resolution.* Add a **synchronous** `Duration get elapsed`, not a stream. The 250ms tick lives in the connector (R32), which reads `elapsed` on each tick — so the two fakes gain a one-line getter each and no stream plumbing exists to leak a subscription. `RecordVoiceRecorder` already holds the `Stopwatch` privately at `:27`; the getter returns `_elapsed.elapsed`.

**Updating the two test fakes is in-fence maintenance, not a new test and not a retarget.** It changes no assertion. State it in the MSP's plan so it is not mistaken for fence-widening.

---

**R28 — `GlowPulse`'s model is REPLACED, not retuned. Zero `lib` call sites, two test call sites.**

`glow_pulse.dart:6-17` emits a `boxShadow` with `maxBlur` / `maxSpread` / `maxAlpha` / `borderRadius` (`:12-15`, painted at `:60-72`). The prototype halo (`:484`, keyframe `fn-pulse` at `:21`) is a radial-gradient **disc behind** the button doing `scale(.9)/opacity .5 -> scale(1.25)/opacity .18` — a scale-and-fade, not a blur-and-spread. The parent says so explicitly.

*Resolution.* `GlowPulse({minScale: 0.9, maxScale: 1.25, minOpacity: 0.18, maxOpacity: 0.5, color, duration})` renders its **own** 150x150 radial-gradient circle; the mic button is `Stack`ed on top. `maxBlur`, `maxSpread` and `borderRadius` are deleted. The current `required this.child` (`:9`) forces a wrapper shape that does not match the design and is dropped or made optional.

`glow_pulse_test.dart:16` (`deco.boxShadow!.first.color.a`) and `:44` red on a null-assert. Both are **retargets** of assertions pinning a rendering G5 is mandated to change, permitted by `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`.

---

**R29 — `WaveformBars` grows three NULLABLE parameters. Defaults are frozen, and that is what protects the entry card until G8.**

`waveform_bob.dart` is one `SingleTickerProviderStateMixin` controller (`:35`) driving `sin((t + index/barCount) * 2pi)` for every bar (`:53-59`), with defaults `barCount: 5`, `width: 3`, `spacing: 3`, `maxHeight: 20` (`:11-17`). Per-bar periods of 700/850/1000/1150ms cycling `i % 4` cannot come from one controller with a shared period.

*Resolution.* Add `List<double>? heights`, `List<Duration>? perBarDurations`, `double? twoToneThreshold`, all null-defaulting to today's sine path. Per-bar phase is computed from the **single** controller as `t_i = (controller.lastElapsedDuration / dur_i) % 1` rather than switching to `TickerProviderStateMixin` with N tickers — it avoids N tickers, keeps `animate: false` trivial, and keeps the widget's disposal surface unchanged.

Both existing consumers are verified safe: `voice_body.dart:206-209` passes only `key` and `animate`; `voice_recorder_sheet.dart:137` passes nothing. `waveform_bars_test.dart:21` (`barCount: 6` -> six `wave-bar-N` keys) and `:30-38` (bar-0 height changes over 175ms) stay green **unmodified** on the default path.

---

**R30 — `Blink(stepped: true)` must still emit a `FadeTransition`.**

`Blink` renders a `FadeTransition` (`blink.dart:47`) and has three `lib` call sites (`video_recorder_sheet.dart:195`, `voice_recorder_sheet.dart:133`, and its own declaration). `blink_test.dart:10` asserts `find.byType(FadeTransition)`.

*Resolution.* Add `bool stepped = false` and drive the **same** `FadeTransition` from a step curve (a flattened `Interval` / `Threshold` tween) so the hard on/off is achieved without changing the emitted widget type. If stepped mode switched to `Visibility` or `Offstage`, `blink_test.dart:8-13` breaks even for the default case, because the finder walks the subtree. This is a design constraint on the implementation, not a licence to edit the test.

---

**R31 — G5 adds three token values. `Motion.all` must NOT grow.**

| Token | Value | Why |
|---|---|---|
| `Palette.waveMid` `#DCAE9A` | `Color(0xFFDCAE9A)` | **MISSING.** `grep -i dcae9a lib` returns zero hits. Required by the two-tone rule at `:1261`. The parent names the hex without flagging it as new |
| `TypographyTokens.timerSerif` | Newsreader 38 w400 `Palette.ink` | **MISSING.** The largest serif token is `displaySerifToday` 34/w500 (`typography.dart:11-17`) |
| `TypographyTokens.hintAccent` | Caveat 15 w600 `Palette.muted` | **MISSING at 15.** `subtitleAccent` is Caveat 14 w600 muted (`:132-137`); `promptAccent` is 13 |

Already present and used as-is: `Palette.ink18` = `Color(0x2E4A3B2E)` = `rgba(74,59,46,.18)` (`palette.dart:23`, exact match for the idle hairline at `:491`); `Palette.danger` `#C0392B` (`:44`); `composerTitleAccent` for the header (`typography.dart:125-130`, exact); the halo gradient is `Palette.coral` at alpha, no token needed; the status label is `captureLabelSans.copyWith(letterSpacing: 0.96, color: Palette.danger)` — `.08em x 12px = 0.96`.

**Durations are passed as parameters, never added to `Motion.all`.** `Motion.pulse` is 1500ms (`motion_tokens.dart:5`) against the halo's 2400; `Motion.blink` is 900ms (`:4`) against the step blink's 1200. `test/design/feedback/motion_tokens_test.dart:18` asserts `hasLength(7)` and `:21-29` enumerates the seven — adding to `Motion.all` reds both. G5 passes 2400ms and 1200ms as constructor arguments from local `_k…` constants in the sheet.

---

**R32 — SPEC GAP RESOLVED: the idle `Cancel` + `Record` button row is DELETED in G5, and the voice sheet gains the close X in the same MSP.**

*Problem.* `voice_recorder_sheet.dart:76-87` renders a persistent `Cancel` + primary row for **all three** phases. G5 introduces the 92px mic button as the record affordance but is silent on the old row; G6 only says the pills replace the row "for the active-recording phase only". Read literally, idle keeps both a `Cancel` button and a `Record` button beside a mic button that also starts recording — two record affordances and a stranded cancel.

*Ground truth.* The prototype's voice branch (`:478-492`) has **no** Cancel and **no** Record button in any state. Its only persistent affordance is the absolutely-positioned close X at `:479` (`left:18px; top:18px`, 22x22). The pills at `:494-496` are gated on `recActive`, i.e. they exist only in `recording` and `paused`.

*Resolution.* **G5 deletes the whole `Cancel` / `Record` / `Stop & save` / `Saving…` row and ships the close X at `left:18, top:18` inside the voice branch.** The mic button is the only record affordance; the close X is the only dismissal affordance; the pills arrive in G6 for the active phases. Idle therefore has exactly one control, which is what `:478-492` draws.

*Consequence, and it is the reason this gap had to be closed at slice time:* it decides whether `voice_recorder_sheet_test.dart:23,67` and `voice_composer_test.dart:174` are green or red. They are **red**, and they retarget to the close X's key.

---

**R33 — Every icon-only control in this cluster ships a stable finder. `ValueKey`s are named here, once, so no two MSPs invent different ones.**

An icon has no findable text, so R32's deletion of the labelled buttons is only retargetable if the replacement carries a key. These are contract, added by the MSP that ships the control, and never renamed afterwards:

| Key | Control | Ships in |
|---|---|---|
| `ValueKey('composer-close')` | the note composer's header close X | G1 |
| `ValueKey('voice-close')` | the voice composer's close X | G5 |
| `ValueKey('voice-record-button')` | the 92px mic button | G5 |
| `ValueKey('voice-discard-pill')` / `ValueKey('voice-save-pill')` | the two review pills | G6 |
| `ValueKey('video-close')` | the viewport close X | G7 |
| `ValueKey('video-shutter')` | the 70px shutter | G7 |
| `ValueKey('video-discard-circle')` / `ValueKey('video-save-circle')` | the flanking circles | G8 |

These are **new** keys on **new** controls. N24 forbids renaming the six existing playback keys; it does not forbid adding keys to controls that did not exist.

---

**R34 — A pause glyph does not exist anywhere. G5 defers it; G6 ships it through the shared enum.**

`CaptureGlyph` is `{ pencil, mic, video }` (`capture_icons.dart:3`). `IconStickerGlyph` is `{ gear, soundOn, soundOff, edit, trash }` (`icon_sticker_button.dart:5`). The only pause glyph in the app is `_TransportGlyph`, **private** in `voice_body.dart:261` with `Palette.cardBright` hardcoded at `:268` and no colour parameter.

`recTapIcon` (`:1705`) shows the pause glyph **only** when `recState === 'recording'`; idle and paused both show the mic. G5 ships no `recording` mic-button state that needs it — the pause toggle is G6's — so **G5 needs no pause glyph** and must not author one. G6 adds `pause` to the shared enum (R43).

---

**R35 — `formatMediaDuration` is verified to emit `M:SS` and is reused unmodified.**

`lib/features/entry_cards/util/duration_format.dart:1-13` produces `0:03`, not `00:03`, which is the prototype's own format (`:1396` builds `Math.floor(s/60)+':'+(s%60<10?'0':'')+(s%60)`). It is N11-load-bearing at `voice_body.dart:213` and is **read-only** for this cluster: G5 and G7 import it, neither changes it.

---

#### G6 — voice pause, review pills, discard confirmation

**R36 — CORRECTION x2: `Palette.statusAmber` is at `palette.dart:54`, and it is NOT unused.**

The parent says `palette.dart:36` and "currently unused". `:36` is blank. The declaration is at **`:54`** (`Color(0xFFC9821F)`, the value is right), and it is consumed at `lib/design/settings_fields/settings_status_pill.dart:9` as the `dotColor` default, pinned by `test/design/settings_fields/settings_status_pill_test.dart:34`. **G6's token work for the amber is zero.** Reference `:54` and apply it; do not add it and do not "clean up" an unused token that has a consumer and a test.

---

**R37 — CORRECTION: `Toast` has THREE consumers, not one. The dark pill is a VARIANT defaulting to today's light treatment — a declared deviation from the parent's "restyle it".**

The parent says `Toast` is "used only by the video nudges". Measured:

| Consumer | Anchor | Passes `surface`? |
|---|---|---|
| `SettingsNotice` | `lib/features/settings/widgets/settings_notice.dart:19` | no |
| video nudges | `lib/features/capture/video/video_recorder_sheet.dart:115` | yes, `Palette.cardWarm` |
| mood planted toast | `lib/features/mood/mood_banner_for_date.dart:148` | no |

The third landed **four commits ago** in `a6cdcc2` (#109) and the parent spec predates it. A wholesale restyle silently turns the settings notice and the just-shipped mood toast into dark pills — a visible regression to a design that shipped this week, in two files no G MSP has any business editing.

*Resolution — declared deviation.* `Toast` gains a variant that **defaults to today's light `StickerCard` rendering**. The dark pill is opt-in, and only the capture surfaces opt in. Consequences, all of them good:

- `settings_notice.dart` and `mood_banner_for_date.dart` are byte-identical and stay out of every fence.
- `test/design/feedback/toast_test.dart` stays green **unmodified** — its four predicted reds at `:11`, `:23`, `:24`, `:35` all evaporate, because the default path is untouched.
- `video_recorder_sheet.dart:115` keeps compiling: G6 changes the default of nothing, and **G7** — the file's owner — swaps the explicit `surface: Palette.cardWarm` for the dark variant when it builds the viewport. Neither MSP reaches into the other's file.

*Rejected: restyle `Toast` wholesale as the parent instructs.* The instruction rests on a fact that is false on this base.

---

**R38 — The dark pill is composed LOCALLY inside `toast.dart`. It cannot be a `StickerCard`.**

`:900` has **no border**; `StickerCard` hardcodes `Shapes.outline` (`sticker_card.dart:30`, 16 call sites — R1). The pill also needs `0 10px 24px -8px rgba(0,0,0,.5)`, a blurred soft shadow that no `Shadows.*` member expresses: every soft shadow in the system is ink- or brown-tinted (`softLift` `0x99322314`, `panelLift` `0xB81E140A`, `pickerSheetLift`, `chooserSheetLift`). This is the first pure-black shadow in the app.

*Resolution.* The dark branch of `Toast.build` is a local `DecoratedBox` with `color: Palette.ink`, `borderRadius: BorderRadius.circular(Shapes.radiusXl)`, and the new `Shadows.toastLift` (R42). `StickerCard` is untouched.

---

**R39 — ADDITION and CORRECTION: the review pills are `:494-496`, and the prototype has TWO toast renderings. G6 ships ONE, the `:900` values the parent names.**

*Citation.* The parent cites `:494-495`. `:494` is the flex container (`gap:10px; margin-top:6px`), `:495` is **Discard**, `:496` is **Save memo**. `:493` is the `recActive` gate. Correct span: **`:494-496`**.

*Two toasts.* `:900` is the **phone** toast: `bottom:84px; border-radius:20px; padding:8px 16px; font:600 11px; gap:7px; 13x13 check`. `:452-453` is the **desktop** toast: `bottom:22px; border-radius:22px; padding:10px 20px; font:600 13px; gap:8px; 15x15 check`. Both are `background:#4a3b2e; color:#f6ead6; box-shadow:0 10px 24px -8px rgba(0,0,0,.5); animation:fn-rise .22s ease-out`.

*Resolution.* G6 ships **one** treatment, the `:900` values, exactly as the parent's target block specifies. The app has one `Toast` widget; forking it by form factor for an 11-vs-13px label is not a shippable distinction, and the parent's chosen source is internally consistent. The `:452-453` variant is recorded here and **deferred** (§6.1) so that a future reader does not mistake the parent's citation for an error.

---

**R40 — The toast host is the app's first transient-notification primitive. G6 builds it in `toast.dart`, and it CLEARS the three-consumer bar.**

*Problem, and it is the largest unscoped item in the cluster.* `grep -rn "OverlayEntry\|ScaffoldMessenger\|showSnackBar" lib` returns **zero hits**. Both existing toast usages are permanently-mounted inline `Column` children (`settings_notice.dart:19`; `mood_banner_for_date.dart:73-85`, `:148`). `Recording discarded` and `Voice memo saved` must appear **after** the composer dialog pops, on the screen behind it — the prototype does exactly that at `:1377` and `:1394`, patching `composer:null` and then calling `flash`. Nothing in the app can render anything after its own route is gone.

*Resolution.* G6 adds `void showTransientToast(BuildContext context, String message)` to `lib/design/feedback/toast.dart`: it inserts an `OverlayEntry` on the **root** overlay carrying the dark `Toast`, and removes it after `_kToastLifetime` (1900ms, R19). The caller is the composer connector, holding the context of the screen **behind** the dialog, captured before `Navigator.pop`. Re-entry cancels and restarts the timer rather than stacking, matching `:1323`'s `clearTimeout`.

*Why a primitive is justified here and was not in Cluster F.* F4 declined one because it had a single consumer and "two is not three". This has **four** — voice discard, voice save, video discard, video save — plus the two existing inline consumers that could migrate later. That clears the rule-of-three bar on its own.

**Mandatory: the timer and the `OverlayEntry` are both cancellable, and the entry is removed if the overlay goes away first.** A leaked `OverlayEntry` plus a pending `Timer` trips `AutomatedTestWidgetsFlutterBinding`'s `!timersPending` assertion after the tree is disposed, which reds every test that touches the path with a stack trace naming the binding.

*Rejected: change `showVoiceComposer`'s return type to a discriminated result and toast from the caller.* It breaks the `Future<String?>` contract that G1's "Must not regress" and `CaptureRouteOpener` (`capture_route.dart:4-7`) both protect.

---

**R41 — Adding `VoiceRecorderPhase.paused` is a COMPILE-TIME forcing function, and `voice_composer.dart:124` is a latent take-leak the moment it exists.**

`enum VoiceRecorderPhase { idle, recording, saving }` (`voice_recorder_sheet.dart:7`) is consumed by an **exhaustive** `switch` at `:129-164`. Adding `paused` makes that switch non-exhaustive, which is an **analyze error** — the desired outcome, since it forces every branch to be considered rather than defaulted.

Two more sites must learn about `paused` and neither is caught by the switch:

- `_isRecording` / `_isSaving` getters (`voice_recorder_sheet.dart:43-44`).
- **`voice_composer.dart:124`** — `if (_phase == VoiceRecorderPhase.recording) await _recorder.cancel();`. Cancelling from `paused` would skip `recorder.cancel()` entirely and leak the take's file. This is a bug that does not exist today and is created by G6; it is named here so it is fixed in the same change, not discovered later.

`record: ^7.1.1` supports the state machine natively: `pause()` (`record.dart:93`), `resume()` (`:100`), `isPaused()` (`:139`), `onStateChanged()` (`:124`), `enum RecordState { pause, record, stop }`. No shim is needed. `RecordVoiceRecorder` drives `_elapsed.stop()` / `.start()` alongside, which gives the accumulate-across-pauses behaviour for free — the same thing `_rAcc` does at `:1373` and `:1396`. Today `stop()` (`:57`) and `cancel()` (`:82`) both call `_elapsed.stop()`; `pause()` joins them and `resume()` restarts.

---

**R42 — G6 adds two token values and reuses the rest. No new `Shapes` or `Shadows` geometry is required beyond one shadow.**

| Token | Value | Status |
|---|---|---|
| `Palette.toastInk` `#F6EAD6` | `Color(0xFFF6EAD6)` | **MISSING.** `grep -i f6ead6 lib` returns zero hits. The dark pill's foreground |
| `Shadows.toastLift` | `BoxShadow(Color(0x80000000), Offset(0, 10), blurRadius: 24, spreadRadius: -8)` | **MISSING.** No existing member matches; all soft shadows are brown-tinted (R38) |

Already present: `Palette.statusAmber` (`:54`, R36), `dangerSurface` `#FBECEA` (`:45`), `danger` `#C0392B` (`:44`), `Shapes.radiusSheet` 22 (`:18`), `radiusXl` 20 (`:17`), `Shadows.emphasis` 2/2/0 (`:51-58`). The toast label is `caption11Sans.copyWith(color: Palette.toastInk)` — `caption11Sans` is sans 11 w600 but coloured `Palette.coral` (`typography.dart:201-206`), so the `copyWith` is required and the **token may not be recoloured** (`mood_banner.dart:110` depends on the coral, and `tokens_test.dart:315` pins it). The pill labels are 13/w600, which no token carries: `labelSans.copyWith(fontSize: 13, fontWeight: FontWeight.w600)` locally.

`fn-rise` is `.22s` (220ms) against `Motion.toastRise` at 280ms (`motion_tokens.dart:8`). *Resolution:* retune the token to 220ms. It reds nothing — `motion_tokens_test.dart` asserts positivity and count, not values — and the token exists for exactly this animation.

---

**R43 — `IconStickerGlyph` gains `close`, `check` and `pause`. G6 owns the enum extension; G7 and G8 consume it.**

`IconStickerGlyph` is `{ gear, soundOn, soundOff, edit, trash }` (`icon_sticker_button.dart:5`) and `_path()`'s switch (`:157-170`) is exhaustive, so omitting an arm fails analyze. `IconStickerGlyphIcon` (`:103-125`) already takes `color` and `size`, so **trash-light is already reachable** at any size and colour — `IconStickerGlyphIcon(glyph: IconStickerGlyph.trash, color: …, size: 15 or 18)` (path at `:194-207`, stroked 1.8 on a 24 viewBox). Close, check and pause are not: the app's only close glyph is a raw `Icons.close` in `search_field.dart:50`, there is no check glyph at all, and the only pause glyph is private (R34).

*Fence assignment, and it matters because three MSPs want the same glyph.* `lib/design/widgets/icon_sticker_button.dart` is in no MSP's declared Files list, and **G6, G7 and G8 all need `check`**. It is assigned to **G6**, which is the first of the three in ship order. G7 and G8 consume the extended enum and must not add an arm. Growth is safe: only four `lib` call sites reference the enum (`sidebar_shell.dart:145`, `:154`; `entry_card.dart:92`, `:102`), and adding members breaks none of them.

---

**R44 — ADDITION: `recActive` and `recNotRecording` pin two behaviours the parent leaves ambiguous, and they bind G5 and G6 jointly.**

`:1702` verbatim: `recActive:(D.recState||'idle')!=='idle'`, `recNotRecording:(D.recState||'idle')!=='recording'`.

1. **The review pills show in BOTH `recording` and `paused`** — `:493` gates on `recActive`. The parent's "shown whenever recording is active" is ambiguous; this pins it.
2. **G5's 120px idle hairline also renders while PAUSED** — `:491` gates on `recNotRecording`. The paused state does **not** show a frozen waveform. Neither G5's nor G6's section says this, and the two MSPs must agree or the paused state renders two mutually exclusive things.
3. The mic button is a **three-way** toggle: `idle -> beginRec`, `recording -> pauseRec`, `paused -> resumeRec` (`recTap`, `:1375`), and its glyph is the pause fill only while `recording` (`:1705`).
4. `saveVoice` (`:1394`) carries its own idle guard — `if(recState==='idle') return;` — mirroring `askDiscardRec`'s (`:1376`). Save from idle is a no-op, not an empty save.

---

#### G7 — video recorder dark viewport chrome

**R45 — CORRECTION: `camera_video_recorder.dart` is in `lib/features/capture/platform/`, not `lib/features/capture/video/`.**

G7's Files list names `lib/features/capture/video/camera_video_recorder.dart`. No such file exists; `lib/features/capture/video/` contains `camera_picker.dart`, `camera_selection.dart`, `camera_selection.g.dart`, `video.dart`, `video_composer.dart`, `video_recorder.dart`, `video_recorder_provider.dart`, `video_recorder_sheet.dart`, `video_timeline.dart`. The real path is **`lib/features/capture/platform/camera_video_recorder.dart`**, and `createPlatformVideoRecorder()` at `:30` is what routes to the two implementations.

---

**R46 — There are TWO `_elapsed` Stopwatches, not one. Both must surface or the non-macOS timer reads `0:00` forever.**

The parent cites `camera_video_recorder.dart:212` (`CameraMacosVideoRecorder`), which is correct. It omits the **second, independent** `Stopwatch` at **`:35`**, inside `CameraVideoRecorder` — the iOS/Android path. Both are private and read only inside `stop()` (`:78`, `:346`), which is also where `durationMs` is written to the entry.

*Resolution.* `Duration get elapsed` is added to the `VideoRecorder` interface and implemented by **both** classes, each returning its own stopwatch's elapsed. Mirrors G5's R27 exactly, deliberately: the two interfaces get the same member shape so the two sheets get the same ticker pattern.

---

**R47 — CORRECTION: G7's paused timer dot is `#f0b34a`. It is NOT `Palette.statusAmber #c9821f`. Two ambers, one cluster.**

`:508` is `background:#f0b34a`. `:482` — the **voice** paused status row, which is G6's — is `background:#c9821f`. They are different hues for different surfaces: `#c9821f` reads on cream, `#f0b34a` reads on a dark viewport. Collapsing them onto the shipped `statusAmber` token loses the second value silently.

`#F0B34A` is **not** in `Palette` and G7 adds it as `Palette.viewportAmber` (R52).

---

**R48 — The feed placeholder is ALREADY SHIPPED, complete. A5 built every part of it.**

`lib/design/widgets/cross_hatch_placeholder.dart` already carries: `CrossHatchVariant.viewport` (`:9`); the exact geometry `ground: Palette.viewportDark`, `band: Palette.viewportDarkAlt`, `bandWidth: 8`, `bandPitch: 16` (`:39-44`); the outline suppressed for that variant (`border: variant == viewport ? null : Shapes.outline`, `:88-89`); an overridable `borderRadius` for the edge-to-edge bleed (`:53`, `:62`); and a centred `child` slot for the label (`:57`, `:101`). `Palette.viewportDark = Color(0xFF3A352E)` and `viewportDarkAlt = Color(0xFF443F37)` are at `palette.dart:60-61`, matching `:502` exactly.

*Resolution.* G7's row collapses to a call: `CrossHatchPlaceholder(variant: CrossHatchVariant.viewport, borderRadius: BorderRadius.zero, child: Text('CAMERA FEED', style: …))`. The only remaining work is the label's text style, which is a new token (R52), not a widget change.

---

**R49 — `SettingsFieldRow` and `SettingsSelect` gain OPTIONAL colour parameters. All 17 existing call sites are unchanged. Do not compose a bespoke dark row.**

*Problem — this is N12's blocker.* `settings_field_row.dart:5-49` hardcodes `TypographyTokens.labelSans` (`:27`, ink) and `Palette.muted` (`:33`); its constructor (`:6-15`) takes `label`, `description`, `control` and **no colour hook**. `settings_select.dart:15-66` hardcodes four light values — `Palette.cardBright` fill (`:48`), `Shapes.outline` (`:49`), `bodySans` (`:57`), `Icon(color: Palette.ink)` (`:59`) — with a constructor (`:16-22`) exposing only `options`, `value`, `onChanged`, `enabled`. Measured: **16 `SettingsFieldRow(` sites** and **1 `SettingsSelect(` site** in `lib/`.

*Resolution.* Additive optional parameters, defaulting to today's tokens so every existing call site is byte-identical: `Color? labelColor` / `Color? descriptionColor` on the row; `Color? surface`, `Color? foreground`, `Border? border` on the select. Dark values, chosen to reuse `:514`'s Discard-circle treatment so the viewport reads as one system: surface `rgba(15,13,11,.5)`, foreground `#fff`, border 1.5px `rgba(255,255,255,.4)`.

**Leave the `PopupMenuItem` list light** (`settings_select.dart:41-44`). The menu floats above the viewport on the app's own surface; darkening it forces a fifth change (the item text at `:43` is also ink) for no fidelity gain.

*Rejected: compose a bespoke dark row inside the recorder sheet.* N12 says the picker is **re-homed**, not rebuilt; a bespoke row drifts from the settings row it is supposed to remain, which is the exact hazard N12 exists to name.

---

**R50 — The video composer has NO elapsed clock at any layer. The timer pill is new machinery in three files, not a restyle.**

`VideoRecorderSheet` has no timer, no `Duration` field and no ticker (`video_recorder_sheet.dart:14-41` is the whole constructor). `VideoComposerConnector`'s `_timers` list (`video_composer.dart:58`) holds only the nudge and cap one-shots. The `VideoRecorder` interface (`video_recorder.dart:64-78`) exposes `listDevices / openSession / start / stop / cancel / release / dispose` and nothing time-shaped.

*Resolution, and it is the same shape as G5's R32 by design.* `elapsed` on the interface (R46); a `Timer.periodic(Duration(milliseconds: 250), …)` owned by the **connector**, which is already a `ConsumerState`; a new `elapsed` parameter on the sheet, which stays stateless and therefore testable by direct pump. 250ms is the prototype's own interval (`:1396`, verified).

---

**R51 — `VideoRecorder` has SEVEN implementers. Growing it is a build break across five test files.**

| Implementer | Anchor |
|---|---|
| `CameraVideoRecorder` | `lib/features/capture/platform/camera_video_recorder.dart:32` |
| `CameraMacosVideoRecorder` | `lib/features/capture/platform/camera_video_recorder.dart:207` |
| `FakeVideoRecorder` | `test/features/capture/video/video_test_support.dart:33` |
| `DeferredReadyVideoRecorder` | `test/features/capture/video/video_test_support.dart:141` |
| `_HangingStopRecorder` | `test/features/capture/video/video_composer_save_hang_test.dart:15` |
| `_ArmingRecorder` | `test/features/capture/video/video_camera_review_test.dart:20` |
| `_HangingReleaseRecorder` | `test/features/capture/video/video_camera_review_test.dart:83` |

All seven gain `elapsed` in G7 and all seven gain `pause` / `resume` / `supportsPause` in G8. **Both MSPs' Files lists include the five test files**, as declared, bounded harness maintenance: members added, no assertion touched, no case added or removed.

---

**R52 — `Palette` has ZERO white-alpha entries. G7 adds five colour tokens and one type token.**

`palette.dart:3-71` carries ink-alpha and coral-alpha ladders and an opaque `onAccent` `#FFFFFF` (`:47`), but nothing translucent-white. The dark viewport needs six such values plus two dark scrims plus the second amber.

| Token | Value | Used by |
|---|---|---|
| `Palette.onDark30` | `Color(0x4DFFFFFF)` | `CAMERA FEED` label (`:504`), idle timer dot (`:509`) |
| `Palette.onDark40` | `Color(0x66FFFFFF)` | Discard-circle border (`:514`), dark `SettingsSelect` border |
| `Palette.onDark72` | `Color(0xB8FFFFFF)` | instruction line (`:512`) |
| `Palette.onDark85` | `Color(0xD9FFFFFF)` | Save-circle caption (`:519`) |
| `Palette.viewportScrim` | `Color(0x800F0D0B)` = `rgba(15,13,11,.5)` | timer pill (`:506`), Discard circle (`:514`), vignette top (`:503`) |
| `Palette.viewportAmber` | `Color(0xFFF0B34A)` | paused timer dot (`:508`) — R47 |
| `TypographyTokens.viewportMonoLabel` | monospace 10 w500, `letterSpacing: 1.0` (`.1em x 10px`), `Palette.onDark30` | `CAMERA FEED` |

Arithmetic: `.3 x 255 = 76.5 -> 0x4D`; `.4 -> 0x66`; `.72 x 255 = 183.6 -> 0xB8`; `.85 x 255 = 216.75 -> 0xD9`; `.5 -> 0x80`; `rgb(15,13,11) = 0x0F0D0B`. The vignette's fourth stop `rgba(15,13,11,.72)` is `viewportScrim` at a different alpha and is expressed inline in the gradient rather than as a seventh token. `TypographyTokens` has `monoMicroSans` at 7px (`typography.dart:250`) and `monoThumbSans` at 6px (`:257`) — nothing at 10 and nothing with `.1em` tracking. `Palette.recordFill #E0574A` (`:55`) already exists for the recording dot.

---

**R53 — `Try again`, `Preparing…` and the armed labels have no prototype counterpart. They ROUTE, they are not deleted.**

N13 is explicit that the denied stage may not be removed, and the parent's own G7 says the surfaces "need dark-viewport treatments … do not delete them for lack of a prototype counterpart". Two of them have no obvious slot:

- **`Try again`** (`video_recorder_sheet.dart:196-199` in test terms) is the denied stage's retry affordance. *Resolution:* the shutter tap **is** `onStart` in the denied phase already (`:156`), so the shutter carries the retry and the dark denied message carries the affordance text. No separate button.
- **`Preparing…` / `Saving…`** were button labels on a button G7 deletes. *Resolution:* they move into the instruction-line slot at `bottom: 70` as `armingHint` (`Getting the camera ready…`) and `savingHint` (`Saving your video…`), which already exist as parameters (`:29`, `:31`).

The full re-homing ledger for all sixteen current surfaces is in §4's G7 body. **No row of it may be dropped**; that table is N12 and N13 in operational form.

---

#### G8 — video pause/resume and the entry-card voice row

**R54 — BLOCKER RESOLVED: pause is a DECLARED CAPABILITY (`supportsPause`), because the macOS backend has no pause API at all.**

*Problem.* `createPlatformVideoRecorder()` (`camera_video_recorder.dart:30`) routes **macOS -> `CameraMacosVideoRecorder`**, backed by the vendored `third_party/camera_macos` (`pubspec.yaml:53-54`, a `path:` dependency). `CameraMacOSController`'s complete public surface (`third_party/camera_macos/lib/camera_macos_controller.dart:8-86`) is `takePicture / recordVideo / stopRecording / destroy / toggleTorch / startImageStream / stopImageStream / setFocusPoint / setZoomLevel / setOrientation / setVideoMirrored`. **No `pause`, no `resume.`** A case-insensitive grep for `pause|resume` across `third_party/camera_macos/lib/**` returns one unrelated hit (`camera_macos_method_channel.dart:26`, `events!.isPaused` on the image stream); the Swift layer has zero. The non-macOS path is fine: `camera-0.12.0+2/lib/src/camera_controller.dart:639` `pauseVideoRecording()`, `:658` `resumeVideoRecording()`.

*Resolution — in fence, and honest.*

- `VideoRecorder` gains `bool get supportsPause;` alongside `Future<void> pause();` / `Future<void> resume();`.
- `CameraVideoRecorder` (`:32`) returns `true` and delegates to the camera plugin, driving `_elapsed.stop()` / `.start()` alongside (`:35`).
- `CameraMacosVideoRecorder` (`:207`) returns `false`; `pause()` and `resume()` throw `UnsupportedError` and are never reached.
- `VideoRecorderSheet` renders the pause glyph, the `paused` dot and the paused instruction line **only when `supportsPause`**. Otherwise the shutter keeps stop-semantics. The Discard and Save circles ship on both paths — they need no pause.

The prototype look lands fully on iOS and Android and degrades honestly on macOS.

*Rejected: freeze the UI timer while `recordVideo` keeps rolling.* It fabricates a pause. `durationMs` is written straight off `_elapsed` (`camera_video_recorder.dart:346`), so the saved clip's real length would disagree with both the displayed time and the database row.

*Escalation recorded:* the alternative is widening G8's fence into `third_party/camera_macos/` (Swift plus Dart plus `LOCAL_MODIFICATIONS.md`), which is a materially different MSP. This slice does **not** authorise it.

---

**R55 — `WaveformBars` gains three more nullable parameters for the static silhouette, and the sinusoid MODULATES the ratios rather than replacing them. This is what satisfies N11.**

*Problem.* Three blockers in one widget (`waveform_bob.dart:8-88`): every height comes from `_heightFor(index, t) = sin((t + index/barCount) * 2pi)` (`:53-59`) with no ratio input; there is a single `color` (`:12`, applied at `:78`); and `borderRadius` is hardcoded to `barWidth / 2` (`:79-81`), which is 1.5 for a 3px bar against a target of a fixed 2.

*Resolution.* Add `List<double>? ratios`, `Color Function(double)? colorFor`, `double? barRadius`, all null-defaulting to today's behaviour. When `ratios != null`, bar *i* takes `ratios[i]` as its **base** factor and the sinusoid modulates around that base when `animate` is true.

**That modulation is not a nicety — it is N11.** N11 requires the fourteen ratios as the **resting** silhouette while the widget keeps animating during playback. `voice_body.dart:206-209` already passes `animate: _isPlaying` and rekeys on `ValueKey<bool>(_isPlaying)` at `:207`; **both survive unchanged**. Flipping the widget's defaults to static instead would red `waveform_bars_test.dart:25-40` ("bobs a bar height over time", default constructor, asserting a height delta over 0.1) — a test that is not N24-protected but whose behaviour N11 says must survive.

The second `lib` consumer, `voice_recorder_sheet.dart:137`, is G6's live recording wave and must keep bobbing; the nullable defaults are what keep it correct.

---

**R56 — ADDITION: the three-tone ramp is a threshold function and the parent gives no thresholds. Here they are, with the resulting fourteen-bar sequence.**

`bars()` at `:1256`, verbatim: `background: h>0.62?'#c76a54':(h>0.42?'#dcae9a':'#e3c4b2')`, `height:(h*100)+'%'`, `borderRadius:'2px'`; `:1254` gives the defaults `w = 3`, `gap = 2.5`.

Applied to `:1579`'s ratios `[.4,.75,1,.55,.85,.35,.7,.5,.9,.45,.65,.8,.38,.6]` the sequence is:

`e3c4b2, c76a54, c76a54, dcae9a, c76a54, e3c4b2, c76a54, dcae9a, c76a54, dcae9a, c76a54, c76a54, e3c4b2, dcae9a` — **7 coral / 4 mid / 3 light**.

Three further facts the parent omits: heights are **percentages of the 24px container**, i.e. `ratio x 24` px; `borderRadius` is a **fixed 2**, not `barWidth / 2`; and `gap` is `2.5`, matching the parent. Without the thresholds an implementer guesses and gets a different silhouette — which is exactly how a design value is lost silently.

`#DCAE9A` is added by G5 as `Palette.waveMid` (R31). `#E3C4B2` is **also** absent from `Palette` (`:31-35` carries only `coral`, `coralHover #9A4832`, `coralLink #B45C44`, `coral12`, `coral30`) and is added by G8 as `Palette.waveLight = Color(0xFFE3C4B2)`.

---

**R57 — The `_PlayToggle` restyle is entirely in-fence. Edit `voice_body.dart` directly; add no API.**

`voice_body.dart:222-259`. The container is 40x40 (`:241-242`) against a target of 38; the glyph is `CustomPaint(size: Size(14, 14))` (`:250`) against 15; `Center` (`:248`) centres it dead-on where `:122` has `margin-left:2px` — a deliberate optical offset for a triangle, which needs an explicit 2px translation. `_TransportGlyph` (`:261-289`) is private with `Palette.cardBright` hardcoded at `:268`, which is fine because the glyph stays light on coral. The border stays `Shapes.outline` (`:246`) = ink 1.5px, matching `:122` exactly.

`voice_body.dart` is a named G8 file, so all of this is direct editing with no new parameter and no shared-widget reach.

---

**R58 — Adding `paused` breaks FOUR guards in `video_composer.dart`, and one of them can swallow the 30:00 cap. These are correctness defects, not styling.**

Each is created by G8 and must be fixed in the same change:

1. **The nudge and cap timers are wall-clock one-shots that pause does not pause, and a fire-while-paused is swallowed permanently.** `_scheduleTimeline()` (`:202-206`) creates `Timer(event.at, …)` from `start()`. `_onTimelineEvent` (`:208-211`) returns early when `_phase != recording` **and never reschedules**. Pause at 4:50, resume at 6:00: the 5-minute nudge fires at wall-clock 5:00 while paused, is dropped, and never re-fires. The same path can swallow the **`cap` event**, so the 30:00 hard stop never fires and recording is unbounded. **This regresses N13 directly.** *Fix:* drive the timeline off recorded elapsed — cancel and reschedule by remaining time on pause and resume — not off wall clock.
2. **`_stop()` refuses to run from `paused`** (`:228-230`, `if (_phase != VideoRecorderPhase.recording) return;`). Save-from-paused — the `:519` Save circle, and `:1395`'s explicit non-idle allowance — would be a silent no-op.
3. **`_cancel()` leaks a paused take** (`:289-296`): it calls `_recorder.cancel()` only for `recording || arming`, so a paused take's file is never discarded. This is the video twin of G6's `voice_composer.dart:124` (R41).
4. **`_failBackToRecording()` silently resumes** (`:277-285`): it forces `_phase = recording` on save failure. From `paused` that is a state-machine lie and, on a real backend, a UI-versus-hardware desync.

Also decide deliberately: `_showsPicker` (`video_recorder_sheet.dart:75`) excludes only `denied` and `saving`, so the camera dropdown is **visible** during `paused`. Its `onChanged` is gated on `_isIdle` (`:108`) so it is inert, but visible-and-inert is a choice, and the choice recorded here is to exclude `paused` as well.

---

**R59 — CORRECTION: the N24 shorthand path is wrong, and `voice_body_test.dart` is NOT one of the protected files. G8's voice half reds NOTHING.**

The invariant shorthand writes `test/playback/video_slots_test.dart`. The real path is **`test/features/entry_cards/playback/video_slots_test.dart`**. The nine untouchable files, verified present with their case counts summing to 106 plus one:

| # | File | Cases |
|---|---|---|
| 1 | `test/features/entry_cards/playback/video_slots_test.dart` | 29 |
| 2 | `test/features/entry_cards/cards/video_body_lifecycle_test.dart` | 20 |
| 3 | `test/features/entry_cards/cards/video_controls_overlay_test.dart` | 18 |
| 4 | `test/features/entry_cards/cards/video_body_test.dart` | 16 |
| 5 | `test/features/entry_cards/cards/video_body_slots_test.dart` | 11 |
| 6 | `test/features/entry_cards/cards/video_body_poster_gate_test.dart` | 7 |
| 7 | `test/features/entry_cards/cards/video_body_attempt_identity_test.dart` | 4 |
| 8 | `test/features/entry_cards/cards/video_scrubber_test.dart` | 1 |
| 9 | `test/features/entry_cards/playback/video_player_impl_test.dart` | 1 (covered by the `playback/**` clause) |

**None of the nine references `VoiceBody`, `voice_body` or `voice-play-toggle`.** A repo-wide grep for those three symbols returns five files plus one integration test, and not one of them is on that list. G8's voice half is **out of the protected suite's blast radius entirely**.

`test/features/entry_cards/cards/voice_body_test.dart` (7 cases) is in `cards/`, is not one of the nine, and is therefore legitimately retargetable — **but no retarget is needed.** It asserts no geometry at all: semantics (`:43`, `:51`, `:52`, `:192`, `:202`, `:279`, `:289`), the `voice-play-toggle` key (`:45`, `:54`, `:108`, `:155`, `:185`, `:205`, `:274`), the two-valued readout text (`:85` `0:00 / 1:05`, `:89` `0:12 / 1:05`, `:290` `0:00 / 1:05` after a media-id change), `CorruptMediaPlaceholder` (`:106`, `:144`, `:151`, `:244`), and player-lifecycle call counts. Every one of those is precisely what N11 requires to survive, and the G8 restyle (40 -> 38 circle, ratio'd bars, colour ramp) touches none of them. `entry_card_test.dart:100-124`, `:157-171` assert `find.byType(VoiceBody)` only and are geometry-blind.

**The voice-row restyle is correctly exempt under the admission gate. Add nothing here.** Keep `voice_body.dart:212-216` intact; only its `style:` argument may change.

---

### ROWS DELETED AS ALREADY SATISFIED

Twenty-eight target-block rows are struck from the MSPs below because the value or the widget already shipped. Each carries a one-line proof. **Every one of them reads in the parent spec as work to be done**, and an implementer who authors it a second time produces a duplicate token, a duplicate widget, or a rename.

| # | Row, as the parent writes it | MSP | Proof it already shipped |
|---|---|---|---|
| 1 | `boxShadow Shadows.panelLift 0 44px 96px -30px rgba(30,20,10,.72)` | G1, G7 | `shadows.dart:105-112` = `Color(0xB81E140A)` / `Offset(0,44)` / blur 96 / spread -30; `0xB8/255 = .7216`. Pinned `tokens_test.dart:193-196`. **Apply, do not author** |
| 2 | `borderRadius Shapes.radiusXl 20` | G1, G6 | `shapes.dart:17` |
| 3 | `borderRadius Shapes.radiusPill 13` | G1 | `shapes.dart:14` |
| 4 | `boxShadow Shadows.control 1.5px 1.5px 0 #4a3b2e` | G1 | `shadows.dart:33-40`, colour `Palette.ink` = `0xFF4A3B2E` (`palette.dart:17`) |
| 5 | `title in composerTitleAccent Caveat 16 w600 Palette.coral` | G1, G5 | `typography.dart:125-130`, exact. Pinned `tokens_test.dart:339-340`, `:348` |
| 6 | `meta in caption9Sans Instrument Sans 9 w400 #a08a70` | G1 | `typography.dart:222-227`; `Palette.muted = 0xFFA08A70` (`palette.dart:39`) |
| 7 | `captureLabelSans recoloured to Palette.onAccent #fff` | G1 | `typography.dart:195-199` (no colour, so `.copyWith` is the whole change); `Palette.onAccent` `palette.dart:47` |
| 8 | `borderBottom 1.5px DASHED Palette.ink25` needs a dashed primitive | G1 | `DashedDivider` takes `axis`, `thickness`, `color`, `dashLength`, `dashGap` (`dashed_divider.dart:6-13`). `Palette.ink25` `palette.dart:26` |
| 9 | `borderTop 1px DASHED Palette.ink20` | G2 | same widget; `Palette.ink20` `palette.dart:24` |
| 10 | `editing -> title 'Edit note' / save label 'Save changes'` | G3 | `day_detail_edit_note.dart:10-11` declares both, `:57-58` passes them. Pinned `day_detail_edit_note_test.dart:66`, `:71`, `:78`, `:137`. **The edit variant is fully shipped; only the confirm dialog is new** |
| 11 | the confirm's `Save changes` action label | G3 | reuse the existing `editNoteSaveLabel` constant (`day_detail_edit_note.dart:11`); do not author a literal |
| 12 | the toast's `1900 ms` lifetime | G3, G6 | `_kToastLifetime` `mood_banner_for_date.dart:19`; identical to `:1323`. Promote, do not re-derive |
| 13 | `boxShadow Shadows.chooserSheetLift 0 -14px 34px -14px rgba(50,35,20,.55)` | G4 | `shadows.dart:123-130` = `Color(0x8C322314)` / `Offset(0,-14)` / blur 34 / spread -14. Pinned `tokens_test.dart:205-210` |
| 14 | `title 'Capture a moment'` | G4 | already the default at `capture_chooser_sheet.dart:13`. **Only the style changes** |
| 15 | `sectionSerif Newsreader 17 w500 ink` | G4 | `typography.dart:56-61`, exact. No new type token |
| 16 | `caption10Sans` for the row subtitle | G4 | `typography.dart:208-213`, exact |
| 17 | the three route labels and their order | G4 | `capture_route.dart:21-37`, pinned green by `capture_route_test.dart:15-24` |
| 18 | `Shapes.radiusMd 14` / `radiusSheet 22` | G4, G6 | `shapes.dart:15` / `:18` |
| 19 | `Shadows.emphasis 2px 2px 0 #4a3b2e` | G4, G6 | `shadows.dart:51-58` |
| 20 | `background Palette.ink18` idle hairline | G5 | `palette.dart:23` = `Color(0x2E4A3B2E)` = `rgba(74,59,46,.18)`, exact |
| 21 | `Palette.danger #c0392b` | G5, G6 | `palette.dart:44` |
| 22 | `Palette.statusAmber #c9821f` — "the token already exists at `palette.dart:36` and is currently unused" | G6 | **Line wrong and "unused" wrong.** `palette.dart:54`, consumed at `settings_status_pill.dart:9`, pinned `settings_status_pill_test.dart:34` (R36) |
| 23 | `Palette.dangerSurface #fbecea` | G6 | `palette.dart:45` |
| 24 | confirm-button chrome from `:1692` | G6 | reachable **exactly** as `StickerButtonVariant.danger`: `Palette.danger` bg, `onAccent` fg, `Shapes.buttonBorderRadius` 11, `_confirmPadding` 9/16, `Shadows.control` 1.5/1.5, `Shapes.outline` 1.5px (`sticker_button.dart:112-119`). Only the label style differs -> `labelStyle: captureLabelSans`. The parent is right; recorded so nobody builds a bespoke button |
| 25 | feed placeholder — hatch geometry, stripe colours, suppressed outline, zero radius, centred label slot | G7 | **A5 shipped all of it**: `cross_hatch_placeholder.dart:9`, `:39-44`, `:53`, `:57`, `:62`, `:88-89`, `:101`; `palette.dart:60-61` (R48) |
| 26 | `Palette.recordFill #e0574a` blinking dot | G7 | `palette.dart:55` |
| 27 | `gap 12` on the voice entry row | G8 | the parent flags it "(already correct)"; confirmed at `voice_body.dart:204` and `:211` |
| 28 | `duration` readout formatting `M:SS` | G8 | `formatMediaDuration` (`duration_format.dart:1-13`) already emits `0:03`; `voice_body.dart:212-216` already uses it. Only the `style:` argument changes (R35) |

### TOKEN LEDGER — the seventeen values Cluster G adds

The token layer closed with Cluster A and Cluster G reopens it. That is deliberate and bounded: the composers are the last unaligned surface and the prototype's dark viewport introduces a colour family — translucent white — that no earlier cluster needed. Every addition below has a prototype line and at least one consumer in this run; **no token is added speculatively.**

| Token | Value | Added by | Prototype |
|---|---|---|---|
| `Palette.composerPaper` | `Color(0xFFFBF3E4)` | G1 | `:460` |
| `TypographyTokens.composerBodySerif` | Newsreader 19 w400 height 2.0 ink | G2 | `:469` |
| `TypographyTokens.composerPlaceholderSerif` | same, italic, `ink34` | G2 | `:469` |
| `Palette.ink34` | `Color(0x574A3B2E)` | G2 | `:469` |
| `Palette.waveMid` | `Color(0xFFDCAE9A)` | G5 | `:1261` |
| `TypographyTokens.timerSerif` | Newsreader 38 w400 ink | G5 | `:487` |
| `TypographyTokens.hintAccent` | Caveat 15 w600 muted | G5 | `:488` |
| `Palette.toastInk` | `Color(0xFFF6EAD6)` | G6 | `:900` |
| `Shadows.toastLift` | `0x80000000` / `Offset(0,10)` / blur 24 / spread -8 | G6 | `:900` |
| `Palette.onDark30` | `Color(0x4DFFFFFF)` | G7 | `:504`, `:509` |
| `Palette.onDark40` | `Color(0x66FFFFFF)` | G7 | `:514` |
| `Palette.onDark72` | `Color(0xB8FFFFFF)` | G7 | `:512` |
| `Palette.onDark85` | `Color(0xD9FFFFFF)` | G7 | `:519` |
| `Palette.viewportScrim` | `Color(0x800F0D0B)` | G7 | `:503`, `:506`, `:514` |
| `Palette.viewportAmber` | `Color(0xFFF0B34A)` | G7 | `:508` |
| `TypographyTokens.viewportMonoLabel` | mono 10 w500 `.1em` `onDark30` | G7 | `:504` |
| `Palette.waveLight` | `Color(0xFFE3C4B2)` | G8 | `:1256` |

One **retune**, not an addition: `Motion.toastRise` 280ms -> 220ms, matching `fn-rise .22s` at `:900` (G6, R42).

**`Motion.all` does not grow.** `motion_tokens_test.dart:18` asserts `hasLength(7)` and `:21-29` enumerates the seven. The halo's 2400ms and the step blink's 1200ms are passed as constructor arguments from local constants, never added to the list (R31).

**Every MSP that adds a token extends `test/design/tokens/tokens_test.dart` in the same change.** That is the parent's own A1 rule (`:1919`) — a new public constant is a contract, and contracts get a test. This is the only category of new test in this cluster besides G6's and G8's behaviour files.

---

### HARD SCOPE FENCE

This run ships **exactly eight MSPs: G1 through G8.** No others.

- Do **not** create MSPs for clusters A, B, C, D, E, F or H. They are named below only so cross-cluster dependencies stay legible. Clusters A–F are already merged; re-implementing any part of them is a defect, not a dependency.
- The complete set of files this run may touch:

| File | Owning MSP(s) | New? |
|---|---|---|
| `lib/design/tokens/palette.dart` | G1, G2, G5, G6, G7, G8 | no — **declared reopening**, additive only |
| `lib/design/tokens/typography.dart` | G2, G5, G7 | no — additive only |
| `lib/design/tokens/shadows.dart` | G6 | no — additive only |
| `lib/design/motion/motion_tokens.dart` | G6 | no — one retune (R42) |
| `test/design/tokens/tokens_test.dart` | every MSP that adds a token | no — extended, never rewritten |
| `lib/design/art/sprig_art.dart` | G1 | **new** |
| `lib/design/art/art.dart` | G1 | **new** (barrel, R10) |
| `lib/features/capture/core/composer_shell.dart` | G1 | **new** |
| `lib/features/capture/text/text_composer.dart` | G1, G3 | no |
| `lib/features/capture/voice/voice_composer.dart` | G1, G6 | no |
| `lib/features/capture/video/video_composer.dart` | G1, G8 | no |
| `lib/features/capture/text/text_composer_sheet.dart` | G1 (R2), G2, G3 | no |
| `lib/features/capture/voice/voice_recorder_sheet.dart` | G1 (R2), G5, G6 | no |
| `lib/features/capture/video/video_recorder_sheet.dart` | G1 (R2), G7, G8 | no |
| `lib/features/day_detail/day_detail_edit_note.dart` | G3 | no |
| `test/design/feedback/dialog_host_test.dart` | G3 | no (**declared, bounded**: one case added — R20) |
| `lib/features/capture/chooser/capture_chooser_sheet.dart` | G4 | no |
| `lib/features/capture/chooser/capture_chooser.dart` | G4 | no |
| `lib/features/capture/core/capture_route.dart` | G4 | no (three `description` values only) |
| `lib/features/capture/voice/voice_recorder.dart` | G5, G6 | no |
| `lib/features/capture/voice/record_voice_recorder.dart` | G5, G6 | no |
| `lib/design/motion/waveform_bob.dart` | G5, G8 | no |
| `lib/design/motion/glow_pulse.dart` | G5 | no |
| `lib/design/motion/blink.dart` | G5 | no |
| `test/design/feedback/glow_pulse_test.dart` | G5 | no (**declared retarget** — R28) |
| `test/features/capture/voice/voice_test_support.dart` | G5, G6 | no (**declared, bounded**: interface members — R27) |
| `test/features/capture/voice/voice_composer_save_hang_test.dart` | G5, G6 | no (same) |
| `lib/design/feedback/toast.dart` | G6 | no — **declared widening** (R37, R38, R40) |
| `lib/design/widgets/icon_sticker_button.dart` | G6 | no — **declared widening**, enum + three paths (R43) |
| `test/features/capture/voice/voice_pause_test.dart` | G6 | **new** |
| `lib/features/capture/platform/camera_video_recorder.dart` | G7, G8 | no (**path corrected** — R45) |
| `lib/features/capture/video/video_recorder.dart` | G7, G8 | no |
| `lib/features/capture/video/camera_picker.dart` | G7 | no |
| `lib/design/settings_fields/settings_field_row.dart` | G7 | no — **declared widening**, additive params (R49) |
| `lib/design/settings_fields/settings_select.dart` | G7 | no — same |
| `test/features/capture/video/video_test_support.dart` | G7, G8 | no (**declared, bounded**: interface members — R51) |
| `test/features/capture/video/video_composer_save_hang_test.dart` | G7, G8 | no (same) |
| `test/features/capture/video/video_camera_review_test.dart` | G7, G8 | no (same) |
| `lib/features/entry_cards/cards/voice_body.dart` | G8 | no |
| `test/features/capture/video/video_pause_test.dart` | G8 | **new** |
| every other `test/features/capture/**` file named in §5.6 | the MSP that changes the label | no (**declared retargets**) |

- **Five declared widenings beyond the parent's stated file lists.** Each is bounded, each carries the standard obligation that every other consumer's tests pass **unmodified**:
  1. **G1 gains the three `*_sheet.dart` files** (R2) — the values it targets live there and nowhere else.
  2. **G3 gains `test/design/feedback/dialog_host_test.dart`** (R20) — one case for the fourth dialog, closing a gap A3 left.
  3. **G6 gains `lib/design/feedback/toast.dart` and `lib/design/widgets/icon_sticker_button.dart`** (R37, R38, R40, R43) — the parent mandates the toast restyle without listing the file, and three MSPs need the same `check` glyph.
  4. **G7 gains `lib/design/settings_fields/settings_field_row.dart` and `settings_select.dart`** (R49) — N12's dark treatment is unreachable without optional colour parameters, and 17 call sites stay byte-identical.
  5. **G5, G6, G7 and G8 gain the five recorder test-support files** (R27, R51) — an `abstract interface class` gaining a member is a build break, not a test failure.
- Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/design/widgets/sticker_card.dart` — 16 call sites in `lib/`, plus A4's contract and `test/design/widgets/sticker_card_test.dart`. **Adding a `border` or `clipBehavior` parameter is out of bounds — stop and report** (R1, R38).
  - `lib/design/widgets/sticker_button.dart` — the chooser rows (R23) and the review pills (R38) are composed locally. **Do not add a variant.** The one place `StickerButton` IS the answer is G6's confirm button (deleted row 24) and G3's confirm button (R17).
  - `lib/features/settings/widgets/settings_notice.dart` and `lib/features/mood/mood_banner_for_date.dart` — the two `Toast` consumers outside this cluster. **READ ONLY.** R37's variant default is what keeps them so.
  - `lib/app/shell/shell_layout.dart` — G4 consumes `resolveShellLayout`; it does not change it. `test/app/shell/shell_layout_test.dart` stays green unmodified.
  - `lib/features/entry_cards/util/duration_format.dart` — N11-load-bearing, read-only (R35).
  - `third_party/camera_macos/**` — **not in any fence.** G8 degrades via `supportsPause` (R54). Editing the vendored Swift or Dart is a different MSP; stop and report.
  - `lib/features/entry_cards/**` apart from `cards/voice_body.dart`, and **every file in R59's nine-file table** — untouchable infrastructure. **If your diff touches one of those nine, you have gone out of bounds — stop and report.**
  - `lib/domain/**` — no MSP in this cluster opens it.
- If decomposition suggests a unit outside G1–G8, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

---

### DEPENDENCY CHAIN, FILE-OVERLAP MATRIX, and SHIP ORDER

**The declared chain**, taken from the parent's own "Depends on" lines with A–F all merged and therefore dropped:

```
G1  (shared shell)          root
 |-- G2  -> G1
 |    |-- G3  -> G2   (and A3, merged)
 |-- G5  -> G1
 |    |-- G6  -> G5   (and A3, merged)
 |-- G7  -> G1        (and A5, merged)
 |
G4  INDEPENDENT       (A1, A2, A3, A4, D3 — all merged)
G8  -> G6 AND G7
```

**G4 is genuinely independent**, and that is the parent's own scope correction at `:1479` speaking: the chooser is a separate phone-only bottom sheet at `:746-756` with its own chrome and no desktop counterpart, explicitly excluded from G1's shell. G4 shares no file with any other G MSP and inherits no contract from one.

**FILE-OVERLAP MATRIX.** Per `decisions/2026-07-27-shared-file-cluster-serializes.md`, a shared file is a HARD dependency edge that the slice **declares** rather than leaving the engine's graph to infer:

| Shared file | Claimed by | Edge it forces | Already in the chain? |
|---|---|---|---|
| `text_composer.dart` | G1, G3 | G1 -> G3 | yes, via G1 -> G2 -> G3 |
| `text_composer_sheet.dart` | G1 (R2), G2, G3 | G1 -> G2 -> G3 | yes |
| `voice_composer.dart` | G1, G6 | G1 -> G6 | yes, via G1 -> G5 -> G6 |
| `voice_recorder_sheet.dart` | G1 (R2), G5, G6 | G1 -> G5 -> G6 | yes |
| `record_voice_recorder.dart`, `voice_recorder.dart` | G5, G6 | G5 -> G6 | yes |
| `video_composer.dart` | G1, G8 | G1 -> G8 | yes, via G1 -> G7 -> G8 |
| `video_recorder_sheet.dart` | G1 (R2), G7, G8 | G1 -> G7 -> G8 | yes |
| `camera_video_recorder.dart`, `video_recorder.dart` | G7, G8 | G7 -> G8 | yes |
| `waveform_bob.dart` | G5, G8 | G5 -> G8 | yes, via G5 -> G6 -> G8 |
| `toast.dart` | G6 (owner), G7 (consumer at `:115`) | G6 -> G7 | **not in the declared chain** |
| `icon_sticker_button.dart` | G6 (owner), G7 + G8 (consumers) | G6 -> G7, G6 -> G8 | G6 -> G8 yes; G6 -> G7 **not in the chain** |
| the five recorder test-support files | G5/G6 (voice), G7/G8 (video) | disjoint pairs | yes |

**The matrix adds exactly one edge the declared chain does not carry: G6 -> G7.** It comes from R37 (G7 swaps the nudge's `surface` for G6's dark variant) and R43 (G7 consumes the `close` glyph G6 adds). **G1's R2 widening adds no edge at all** — each `*_sheet.dart` it touches is already downstream of G1 through a declared contract edge, which is why the widening is safe to declare rather than re-plan.

**SHIP ORDER — one linear stack, and it satisfies every edge above including G6 -> G7:**

```
slice -> G1 -> G2 -> G3 -> G4 -> G5 -> G6 -> G7 -> G8
```

G4's independence buys no parallelism here and is not spent on any: it is placed after G3 because it is the cheapest, lowest-risk MSP in the cluster (no new token, no missing mechanism, zero predicted reds) and landing it mid-stack gives the run a green checkpoint between the note half and the recorder half. If wall-clock pressure ever forces G4 to run alongside another MSP, it is the only MSP in this cluster that may — and it must still rebase onto `main` and re-run `fullValidationCmd` on that base before it ships.

The repo squash-merges, so once an MSP lands, `main` holds its content under a SHA absent from the next branch's history. **Each MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. Never carry a green from one base to another.**

---

### THE STANDING INVARIANT — all four capture surfaces open, capture and dismiss at EVERY commit

This governs every MSP in this cluster and outranks any convenience.

Capture is the app's reason to exist. Four modals carry it — the chooser, the note composer, the voice recorder, the video recorder — and every one of them is rewritten by this cluster. Five receipts hold the chain and must be green at every commit, on every branch:

1. `test/features/capture/core/capture_chooser_test.dart` — the chooser opens, lists three options, honours `Coming soon`, dismisses by barrier.
2. `test/features/capture/core/text_composer_test.dart` — the note composer takes text and saves; an empty save does not write.
3. `test/features/capture/voice/voice_composer_test.dart` — the voice composer records, stops, saves, cancels.
4. `test/features/capture/video/video_composer_test.dart` and `video_camera_lifecycle_test.dart` — the video composer arms, records, saves, releases the camera.
5. `test/design/feedback/dialog_host_test.dart` — every dialog still has a `Material` ancestor.

Concretely, per MSP:

- **G1** changes the box the three composers live in. It changes nothing any of them contains and no callback. If a composer stops opening, stops dismissing (R4), or throws a layout assertion when pumped bare (R7), G1 is wrong.
- **G2** changes only how the editor renders. The controller, the focus node, the cursor colour and the keyboard type are byte-identical (parent's own "Must not regress").
- **G3** adds a gate and renames labels. The no-text path must still refuse to write; the edit path must still return its `bool` (R16); `editNoteFailedMessage` must still be reachable (N23).
- **G4** restyles a sheet and adds a branch. The three route labels, their order and `Coming soon` are exact and stay (N-additive).
- **G5** deletes the voice button row and replaces it with a mic button and a close X (R32). **Recording must still start, stop and save.** Opening must still not record (N14).
- **G6** adds a state to a machine. Every existing transition must still work, and cancelling from `paused` must still discard the take (R41).
- **G7** turns a cream card into a dark viewport. Every one of the sixteen surfaces in its ledger must still be reachable (N12, N13), and the camera must still be selectable and still remembered.
- **G8** adds a state to a second machine and restyles one entry row. The nudges and the 30:00 cap must survive a pause (R58); the voice row's readout, keys and semantics must survive the restyle (N11).

An MSP that ships a composer that cannot be opened, cannot be dismissed, or loses a recording violates the green-branch invariant regardless of test results. **No agent can run this app**; the manual pass in §5.5 is load-bearing and is owed by a human.

---

## 1. BLUF

Capture is the app's reason to exist and it is the least aligned part of it. Four dialogs open at four different widths on four near-white sticker cards, over a flat brown scrim. The note composer writes into a small outlined box in 13.5px serif. The voice recorder has no timer, no mic button, no waveform worth the name, and no way to pause. The video recorder is a cream settings card with a 200px preview letterboxed inside it, a title nobody needs, and a pair of sticker buttons where a shutter belongs. Nothing anywhere tells the user a recording was saved.

**Cluster G's share.** G1 gives all three composers one 760px warm-paper panel with a 2px edge, a large soft drop shadow, a blurred warm-vignette scrim and a corner sprig, and gives the note composer the header bar the design draws — close X, handwritten terracotta title over a date-and-time line, terracotta save pinned right. G2 turns the writing box into a full sheet of paper: edge-to-edge under a dashed rule, 19px serif leaded to 38, an italic `Start writing…` where the old upright hint was. G3 makes the composer name itself correctly for new versus edit, confirms before overwriting an edit, and answers an empty save with a message instead of a dead button. G4 turns the chooser into a phone bottom sheet with bordered icon rows and inner subtitles. G5 rebuilds the voice stage around a 92px coral mic button on a pulsing halo, a 38px serif timer ticking every 250ms and a twelve-bar two-tone wave. G6 makes a take pausable and ending one a deliberate choice — discard with a confirmation, or save — and gives the app its first transient toast. G7 replaces the video card with a full dark camera viewport: vignette, corner X, timer pill with a state dot, handwritten instruction line, white-ringed shutter, with the camera picker re-homed inside the dark chrome rather than dropped. G8 makes the video take pausable from the shutter row and brings the entry-card voice row to its designed proportions.

**Cluster G reopens the token layer for seventeen values and touches thirty-nine files across eight MSPs.** It is the largest cluster in the spec and the only one that grows two interfaces, adds a transient-notification primitive, and ships a capability that degrades by platform.

**Aligned means**: every value in §4 matches its cited prototype line; every capability in §2 still works and still passes its existing tests, unmodified except for the declared interface-member and retarget edits; and no prototype value has been adopted where doing so would break a preserved behaviour — of which this cluster has more than any other.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set N1–N25 is defined in the parent spec. This cluster carries the heaviest preserve load in the spec, and this slice reproduces in full every row it can reach.

**N1–N10 (video playback stack), N15–N19 (settings and data), N21 (garden motion) and N22 (search) are unreachable from this run**, confirmed by path disjointness against §0's fence: no MSP here edits `lib/features/entry_cards/playback/**`, `lib/features/entry_cards/cards/video_*`, `lib/features/settings/**` beyond the two shared `settings_fields` primitives (R49, additive only), `lib/features/data/**`, `lib/features/search/**` or `lib/features/garden/**`. They are preserved by non-contact. **The parent's own note that "G5 through G7 inherit N1 through N10 by proximity" is honoured by the fence, not by care** — no G MSP opens a playback file.

### 2.1 The eight rows that bind THIS run

| # | Constraint | Verified citation |
|---|---|---|
| **N11** | **Restyle the voice row to the 38px coral circle and waveform proportions, but keep** the `isPlaying` state, the **two-valued elapsed/total readout**, completion-resets-to-zero, the error placeholder, and `ValueKey('voice-play-toggle')`. The prototype shows one static duration; **the app must keep showing `0:03 / 0:12`.** The waveform becomes static in its **resting** appearance and **must keep animating while playing** — the fourteen ratios define a silhouette, not a removal of motion | `lib/features/entry_cards/cards/voice_body.dart:203`, `:207`, `:213-214`, `:197`, `:157-161`, `:177`, `:235`, `:233`. Binds **G8**; mechanism at R55; receipts at R59 |
| **N12** | **`SettingsFieldRow` and `SettingsSelect` have a consumer outside `lib/features/settings` — the camera picker.** Any restyle must keep them functional inside the recorder sheet. The remembered-device provider and the first-camera fallback are untouched. The picker is **re-homed inside the dark viewport, never deleted** | `lib/features/capture/video/camera_picker.dart:8-52`, `camera_selection.dart:7-20`, `:22-28`; mounted at `video_recorder_sheet.dart:105` (**verified: `CameraPicker(` is exactly `:105`**, guarded by `_showsPicker` at `:75`, `:103`); primitives at `settings_select.dart:46-63`. Binds **G1, G7**; mechanism at R49 |
| **N13** | **The six-phase machine (preparing/idle/arming/recording/saving/denied), the 5/10/20-minute nudge schedule, and the 30:00 cap hint remain.** Copy and chrome may be restyled; the schedule, the cap and the denied stage may not be removed | `lib/features/capture/video/video_timeline.dart:3-5`, `:9-40`; `video_recorder_sheet.dart:11`, `:32`, `:33`, `:204-206`, `:222-228`. Binds **G1, G7, G8**; the re-homing ledger is in §4's G7 body; the pause-swallows-the-cap defect is R58 |
| **N14** | **Armed-idle semantics hold**: opening the voice or video composer must **never** start recording | `video_composer.dart:95` (sets `idle`, never calls `start()`), `voice_composer.dart:42`. Binds **G1, G5, G6, G7, G8** |
| **N20** | **All UI sound cues stay behind `GatedSoundService`** so the per-call enabled check and the error suppression remain in force | `lib/features/sound/gated_sound_service.dart:9-31`; provider at `sound_providers.dart:26-34`. Binds every MSP that could add a cue — and **none of them may**, see §6.2 |
| **N23** | **Inline failure messaging survives** in the note-editor save path. `editNoteFailedMessage` and its inline failure capture stay reachable | `lib/features/day_detail/day_detail_edit_note.dart:12-13` (**verified: the constant is `:12-13`, the capture is `:46-49`**). Binds **G3** |
| **N24** | **`ValueKey`s and Semantics labels are a public contract, not implementation detail.** They may not be renamed. If a rewrite breaks any test in the protected suite, the correct response is to fix the implementation — **never to delete or weaken the test** | The nine files, with **corrected paths and verified case counts**, are tabulated at R59. Binds **G8** hardest by proximity; actual exposure is **zero** |
| **N25** | **Blooms keep their accessible labels** and mood picker tiles keep their button + selected semantics | `lib/design/flowers/flower_bloom.dart:35-37`; `mood_picker_grid.dart:57-60`. **Unreachable from this run** by path disjointness; recorded for completeness |

### 2.2 Additive elements to preserve, not delete

These have no prototype counterpart. They are enrichments or real-hardware states. They are **re-homed into prototype chrome, never removed.**

| Element | Citation | Endangered by |
|---|---|---|
| Camera picker (multi-camera selection) | `camera_picker.dart:33-50`, mounted `video_recorder_sheet.dart:105` | **G1** (panel widen), **G7** (dark viewport) — N12 |
| Video permission / error / cap / nudge copy | `video_recorder_sheet.dart:29-33`, `:113-124`; `video_timeline.dart:1-41` | **G7** (chrome replacement), **G8** (pause) — N13, R58 |
| The chooser's `'Coming soon'` unavailable state | `capture_chooser_sheet.dart:14` (`unavailableLabel = 'Coming soon'`), rendered `:81` (`isAvailable ? option.description : unavailableLabel`) — **both anchors verified exact** | **G4** — it must keep rendering for unwired types, and it lands in the **row subtitle** slot |
| `PhotoTray` / `PhotoThumbnail` — dead UI, live test | `photo_tray.dart:9`, `:107-155` | nothing in this run. **G3's empty-save guard is text-only** because the tray is unreachable and OQ-6 is open (R18) |
| The `String?` return contract on the three composers | `capture_route.dart:4-7`; `text_composer.dart:97`, `voice_composer.dart:145`, `video_composer.dart:343` | **G1** (re-parenting), **G6** (the toast wants a richer result — refused, R40) |
| The `bool?` return contract on `showEditNote` | `day_detail_edit_note.dart:67`, popping `true` at `:41` / `false` at `:60` | **G3** — the parent claims it returns an entry id; it does not (R16) |
| `barrierDismissible: false` on the video composer | `video_composer.dart:346` — **CORRECTION: the parent cites `:345`, which is `context: context,`** | **G1** (R4), **G7** |
| `barrierDismissible: true` on the note composer | `text_composer.dart:100` — the **only** dismissible composer, and the only one where R4's `IgnorePointer` failure is visible | **G1** |

### 2.3 Preserve-to-MSP binding — the rows that bind THIS run

A preserve rule stated only here does not bind anything. Each row names the MSP that could regress the item and therefore carries it as an explicit constraint.

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| **N11** voice row state, readout, key, motion | **G8** | G8 "Must not regress"; R55 (mechanism), R59 (receipts) |
| **N12** camera picker inside the recorder | **G1**, **G7** | G1 and G7 "Must not regress"; R49; G7's surface ledger row 4 |
| **N13** six phases, nudges, cap, denied | **G1**, **G7**, **G8** | G7 "Must not regress" + its ledger; **R58** for the swallow defect |
| **N14** armed idle | **G1, G5, G6, G7, G8** | every one of their "Must not regress" |
| **N20** cues behind `GatedSoundService` | nothing — **this cluster adds no cue** | §6.2, which also records the `bookclose` cue the prototype plays and this run deliberately does not adopt |
| **N23** `editNoteFailedMessage` | **G3** | G3 "Must not regress" |
| **N24** keys, labels, the nine files | nothing — confirmed by path disjointness | §0's fence, R59, §5.4 gate 2 |
| A3's Material ancestor | **G1** (re-parents all three), **G3** (adds the fourth) | R6, R20 |
| The `Coming soon` state | **G4** | G4 "Must not regress" |
| `Toast`'s two out-of-cluster consumers | **G6** | R37 — resolved by a defaulting variant, so the constraint is satisfied structurally |

---

## 3. Findings that Cluster G implements

Reproduced from the parent spec's §3.7. **Two rows are dropped as already satisfied** and **six cells are corrected**, each marked inline. Every prototype line in the Citations column was re-opened while composing this slice.

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| ~~Text decoration in composers~~ | ~~No decoration anywhere~~ | **DROP — already fixed for three of four.** A3 shipped `DialogHost` and all three composers mount inside it (`text_composer.dart:109`, `voice_composer.dart:157`, `video_composer.dart:355`), so no yellow underline remains there. **It is NOT fixed on the fourth dialog**: `showEditNote`'s `pageBuilder` returns `EditNoteConnector` bare (`day_detail_edit_note.dart:79`). That residue is G3's, at R20 | — | proto `:465` / `dialog_host.dart`; `day_detail_edit_note.dart:79` |
| Composer panel | **One shared panel for all three modes**: `position:relative; width:760px; background:#fbf3e4; border:2px solid #4a3b2e; border-radius:20px; overflow:hidden; box-shadow:0 44px 96px -30px rgba(30,20,10,.72)` | Three separate cards — text 420, voice 420, video 460 — each a `StickerCard` with `cardBright`, 1.5px hardcoded border, radius 16, hard `Offset(3,3)` shadow. **The border is unreachable and nothing clips** (R1) | high | proto `:460` / `text_composer_sheet.dart:19`, `voice_recorder_sheet.dart:25`, `video_recorder_sheet.dart:40`. **ADDITION**: `:460` also carries `animation:fn-pop .2s ease-out` — a **200ms** panel entrance the parent omits (it cites only the scrim's 220ms) |
| Scrim | `radial-gradient(120% 100% at 50% 32%, rgba(42,32,22,.36), rgba(28,20,12,.62)); backdrop-filter:blur(7px); animation:fn-fade .22s ease` | Flat `barrierColor: Palette.ink.withValues(alpha: 0.32)` on all three. **Not expressible as a `barrierColor` at all** (R4); the app has no `BackdropFilter` anywhere | medium | proto `:459` / `text_composer.dart:102`, `voice_composer.dart:150`, `video_composer.dart:347` |
| Corner sprig art | `top:-10px; right:-8px; width:120px; height:150px; opacity:.4; pointer-events:none` — stem stroked `#8a9a63` at 2.2, three leaves `#9bb078` / `#8fa66c` / `#a3b782` | No decorative art on any composer. `lib/design/art/` **does not exist**; `grep -rn "sprig\|Sprig" lib test` returns zero code hits | medium | proto `:461` / R10 |
| Composer header bar | `padding:14px 18px; border-bottom:1.5px dashed rgba(74,59,46,.25)`; 22x22 close at left; centred two-line block (`line-height:1.1`) of title `600 16px 'Caveat'` `#c76a54` over meta `{{ longDate }} · {{ clock }}` at `400 9px 'Instrument Sans'` `#a08a70`; save pinned right at `600 12px; #fff on #c76a54; border:1.5px solid #4a3b2e; radius 13; padding:7px 15px; shadow 1.5px 1.5px 0` | One left-aligned `Text('Write a note')` in `titleSerif`; no close icon, no meta, no dashed rule; save lives in a bottom-right row. **The sheet has no date and no clock input at all** (R8) | high | proto `:463-466` (**verified: the bar is inside `sc-if isTextComposer` at `:462`, note-composer only**) / `text_composer_sheet.dart:15`, `:69-70`, `:126-153` |
| Note writing surface | `height:440px; margin:0 -18px; border-top:1px dashed rgba(74,59,46,.2)` bleeding past the body's `padding:0 18px 14px`; paper `#fbf3e4`, page padding `44px 54px 120px`, scrolling with a 9px scrollbar; editor `'Newsreader', serif; font-size:19px; line-height:38px; color:#4a3b2e` | A bordered inset box containing an `EditableText` in `bodySerif`, `minLines: 4`, `maxLines: 8`, padding 12/10. **CORRECTION**: the parent calls `bodySerif` "16"; it is **13.5** (`typography.dart:65`) — R11 | high | proto `:469` (surface), `:468` (body) / `text_composer_sheet.dart:71-116`, `:103-112` |
| Editor placeholder | Italic Newsreader 19/38 at ink 34%, `top:44px left:54px`. **Copy is `Start writing…` alone** — OQ-5 resolved to (b) on 2026-07-27; the prototype's markdown-shortcut tail advertises an engine that is out of scope | `'What happened today?'` in `bodySans` 14 upright at `Palette.placeholder`, positioned by the shared padding | high | proto `:469` (mount point only; the copy string is `[unverified]` against a `.dc.html` line) / `text_composer_sheet.dart:15`, `:95-99`. Structure resolution at R13, alpha token at R14 |
| Text composer copy | Title `New note` / `New note · {day}` / `Edit note`; save `Save` / `Save changes`; edit-save confirm `Save changes?` / `Update this note with your edits?` **with `confirmLabel:'Save changes'` and `danger:false`**; empty-save guard toast `Write something first` | Title fixed at `'Write a note'`; save `'Save note'`; saving `'Saving...'` (three ASCII periods); no new-vs-edit variants on the **composer** path; empty input disables the button at `Opacity(0.5)`. **The edit path already ships `Edit note` / `Save changes`** — deleted row 10 | medium | proto `:1694-1695`, `:1387-1388`, and **`:1386` for the guard, which the parent never cites** (R18) / `text_composer_sheet.dart:15-18`, `:142-150`; `day_detail_edit_note.dart:10-11` |
| Chooser presentation | Phone-only bottom sheet: scrim `rgba(42,36,29,.34)` with `align-items:flex-end`; sheet `width:100%; background:#efe2ce; border-top:2px solid #4a3b2e; border-radius:22px 22px 0 0; padding:16px 16px 22px; box-shadow:0 -14px 34px -14px rgba(50,35,20,.55); animation:fn-sheet .24s cubic-bezier(.2,.8,.2,1)`; 38x4 grab handle radius 3 `rgba(74,59,46,.3)` `margin:0 auto 12px` | A centred dialog for every layout: `Center` + `maxWidth 360` + `StickerCard`; fade + 0.92 scale over 220ms; no sheet edge, no grab handle, **no platform awareness of any kind** in either chooser file | high | proto `:747-749` (**verified: `:747` scrim, `:748` sheet, `:749` handle**) / `capture_chooser_sheet.dart:15`, `:26-31`, `capture_chooser.dart:16-51`. Mechanism at R22 |
| Chooser rows | One bordered row per option: `gap:12px; border:1.5px solid #4a3b2e; border-radius:14px; padding:13px 15px`, a 20x20 icon, then an **inner** column of title `600 14px` over subtitle `400 10px`. Row 1 primary `#c76a54` / `#fff` / `box-shadow:2px 2px 0 #4a3b2e` with subtitle at `opacity:.85`; rows 2-3 `#f8efe0` with `#a08a70` subtitles and no shadow. Container `gap:9px` | Each option is a `StickerButton` (all three **secondary**) with the description as a separate `Text` **below** the button; 12px between options; no icons. **No `StickerButton` variant can express radius 14 with these shadow rules** (R23) | high | proto **CORRECTION**: `:752` is the container (`gap:9px`, **and `margin-top:15px`, which the parent omits**); the three rows are `:753`, `:754`, `:755` — the parent's `:752-755` conflates them / `capture_chooser_sheet.dart:66-87` |
| Chooser copy | Title `Capture a moment` `500 17px 'Newsreader'` centred; subtitle `how do you want to plant today?` `600 12px 'Caveat'` `#a08a70` centred **with `margin-top:1px`**; row subtitles `put the day into words`, `speak it, hands-free`, `a moving snapshot` | Title string already matches but is `titleSerif` left-aligned; no subtitle; row descriptions are `'A few words for today'`, `'Say it out loud'`, `'Up to 30 minutes'` | medium | proto **CORRECTION**: the parent cites `:750` for "title and subtitle"; the title is `:750` and the subtitle is `:751` / `capture_chooser_sheet.dart:13`, `:32-44`, `capture_route.dart:21-37` |
| Voice record control | 92x92 circle, `background:#c76a54; border:2.5px solid #4a3b2e; box-shadow:0 10px 24px -8px rgba(199,106,84,.7)`; 38x38 white mic, pause fill while recording; centred in a 150x150 stage `margin:14px auto 6px` | `StickerButton('Record')` in a bottom-right `Row` beside `StickerButton('Cancel')`; no circular control, no icon. **The prototype's voice branch has no Cancel and no Record button in any state** — R32 resolves what happens to the row | critical | proto `:485` (button), `:483` (stage) — both verified / `voice_recorder_sheet.dart:21-22`, `:76-87` |
| Voice elapsed time | `400 38px 'Newsreader'; #4a3b2e`, below the button, `M:SS` from `0:00`, ticked every 250ms | No timer is rendered anywhere. `RecordVoiceRecorder` keeps a private `Stopwatch` and reports `durationMs` only at `stop()` | critical | proto `:487`, `:1396` — both verified / `record_voice_recorder.dart:27`, `:56-71`. Interface growth at R27, ticker at R32 |
| Voice pulse halo | 150x150 absolute circle behind the button, `radial-gradient(circle, rgba(199,106,84,.4), transparent 68%)`, `fn-pulse 2.4s ease-in-out infinite`, gated on recording | No halo. `GlowPulse` exists with **zero `lib` call sites** and the wrong animation model — blur/spread, not scale/opacity | high | proto `:484` (halo), `:21` (keyframe: `scale(.9)/opacity .5 -> scale(1.25)/opacity .18`) — both verified / `glow_pulse.dart:6-17`. Model replacement at R28 |
| Voice waveform | `gap:3px; height:40px; margin:12px 0 4px`; exactly **12** bars, `width:4px; border-radius:3px`; heights `[.30,.65,.95,.50,.80,.40,1.00,.55,.85,.35,.70,.45]`; `#c76a54` when h>0.6 else `#dcae9a`; `fn-bob` scaleY .45->1 with per-bar durations 0.7/0.85/1.0/1.15s | `WaveformBars` defaults: 5 bars, width 3, spacing 3, maxHeight 20, one coral, one 700ms phase-shifted sine controller | high | proto `:489` (container), `:490` (mount), and **CORRECTION: the bar generator is `:1258-1262`, not `:1261-1263`** (R26) / `waveform_bob.dart:9-19`, `voice_recorder_sheet.dart:137` |
| Voice idle rule | `width:120px; height:2px; border-radius:2px; background:rgba(74,59,46,.18)` whenever **not recording** — which by `recNotRecording` at `:1702` includes **paused** (R44) | A 12x12 muted dot with a 1.5px ink border plus hint text | medium | proto `:491` (verified) / `voice_recorder_sheet.dart:154-163` |
| Voice header + hints | Header `New voice memo` `600 16px 'Caveat'` `#c76a54` `margin-top:4px`. Hints `600 15px 'Caveat'` `#a08a70` **with `margin-top:2px`**: idle `tap the mic when you're ready`, recording `listening… speak freely`, paused `paused · resume when you're ready` | Title `'Record voice'` in `titleSerif`; hints in `captionSans` | high | proto `:480`, `:488`, `:1703` — all verified. **ADDITION**: the hint element carries `margin-top:2px`, and `:1703`'s apostrophes are **U+2019**, not ASCII / `voice_recorder_sheet.dart:17-20` |
| Voice recording status row | `gap:7px`; 8x8 dot `#c0392b` with `fn-blink 1.2s step-end infinite` (**hard on/off**) + label `Recording` uppercase `600 12px; letter-spacing:.08em; #c0392b` | 12x12 dot with a 1.5px ink border wrapped in `Blink` (900ms `easeInOut` fade), 12px gap, `'Recording…'` in `captionSans` | medium | proto `:481` (verified) / `voice_recorder_sheet.dart:130-143`, `blink.dart:9-11`. Stepped mode at R30 |
| Voice paused state | 8x8 **static** `#c9821f` dot + `Paused` uppercase `600 12px; letter-spacing:.08em; #c9821f` | `VoiceRecorderPhase` has only idle/recording/saving; the interface exposes no pause/resume | high | proto `:482` (verified) / `voice_recorder_sheet.dart:7`, `voice_recorder.dart:30-40`. **CORRECTION: `Palette.statusAmber` is `palette.dart:54` and is already consumed** (R36) |
| Voice review pills | Discard `#fbecea` / `#c0392b` / `1.5px solid #c0392b` / radius 22 / `10px 18px`, 15x15 trash, label `600 13px`. Save memo `#c0392b` / `#fff` / `2px solid #4a3b2e` / radius 22 / `11px 22px` / `box-shadow:2px 2px 0`, leading 15x15 white rounded square radius 4, label `Save memo`. **Shown whenever `recActive`, i.e. in recording AND paused** | No pills; the same Cancel / `'Stop & save'` buttons persist through every phase | high | proto **CORRECTION: `:494-496`, not `:494-495`** — `:494` container (`gap:10px; margin-top:6px`), `:495` Discard, `:496` Save memo; gate at `:493` (R39, R44) / `voice_recorder_sheet.dart:76-103` |
| Video panel | Dark camera viewport filling the 760px panel: `height:480px; background:repeating-linear-gradient(45deg,#3a352e,#3a352e 8px,#443f37 8px,#443f37 16px)`. **No header, no light body** | Light `StickerCard`, `EdgeInsets.all(20)`, `maxWidth 460`, a 200px-tall `ClipRRect` preview inside it | critical | proto `:460`, `:502` — both verified; the video branch is `:501-522` and contains **no title element** / `video_recorder_sheet.dart:40`, `:84-86`, `:243-261` |
| ~~Video feed placeholder~~ | ~~stripes + `CAMERA FEED` label~~ | **DROP — the widget already ships complete.** `CrossHatchVariant.viewport` with the exact `#3a352e`/`#443f37` geometry at 8/16 pitch, outline suppressed, radius overridable, centred child slot — all of it landed in A5. Only the **label's text style** remains, and that is a new token, not a widget change (R48) | — | proto `:502`, `:504` / `cross_hatch_placeholder.dart:9`, `:39-44`, `:53`, `:57`, `:62`, `:88-89`, `:101`; `palette.dart:60-61` |
| Video vignette | `inset:0`, `linear-gradient(to bottom, rgba(15,13,11,.5), transparent 22%, transparent 68%, rgba(15,13,11,.72))` | No overlay gradient over the preview; `ClipRRect` + ink outline only | medium | proto `:503` (verified verbatim) / `video_recorder_sheet.dart:247-260` |
| Video header and close X | No title. A 22x22 light close X at `left:16px; top:16px` inside the viewport | `Text('Record video')` in `titleSerif` across the card top; `StickerButton('Cancel', secondary)` bottom-right | high | proto `:505` (verified) / `video_recorder_sheet.dart:91-92`, `:129-133`; `video_composer.dart:346` (**CORRECTION: the parent cites `:345`, which is `context: context,`**) |
| Video timer pill | `top:16px`, centred; `background:rgba(15,13,11,.5); border-radius:14px; padding:5px 12px; gap:7px`; 8x8 dot — `#e0574a` blinking / **`#f0b34a`** static paused / `rgba(255,255,255,.5)` idle — plus `600 13px 'Instrument Sans'; #fff`, `M:SS` ticked every 250ms | **No elapsed readout exists anywhere in the video UI.** Two private `Stopwatch`es, neither surfaced | critical | proto `:506` container, `:507-509` dots, `:510` readout, `:1396` interval — all verified / `camera_video_recorder.dart:35` **and** `:212` (R46). **CORRECTION: the paused amber is `#f0b34a`, not `statusAmber #c9821f`** (R47) |
| Video shutter | Control row `bottom:22px; gap:30px`; shutter `70x70; border-radius:50%; border:4px solid #fff`, **no background fill**; inner 24x24 `#e0574a` when not recording, 26x26 light pause icon while recording | A bottom-right `Row` of `StickerButton('Cancel')` + `StickerButton('Record')` / `'Stop & save'` | critical | proto `:513`, `:515`, `:516`, `:517` — all verified / `video_recorder_sheet.dart:126-137`, `:145-159` |
| Video instruction line | `bottom:70px`, centred, `600 13px 'Caveat'; rgba(255,255,255,.72)`; idle `tap the button to start recording`, recording `recording… tap pause or stop`, paused `paused · resume or save your clip` | A boxed cream status strip with a 12x12 outlined dot and `captionSans` copy | high | proto `:512`, `:1704` — both verified / `video_recorder_sheet.dart:28-32`, `:231-239`, `:263-288` |
| Video pause / discard / save | `idle -> recording <-> paused`. While `recActive`: a 44x44 Discard circle (`rgba(15,13,11,.5)`, `1.5px rgba(255,255,255,.4)`, 18x18 light trash, caption `Discard` `500 10px` `rgba(255,255,255,.75)`) left of the shutter and a 44x44 Save circle (`#c76a54`, `1.5px solid #fff`, 18x18 light check, caption `Save` `rgba(255,255,255,.85)`) right of it | `VideoRecorderPhase` has no `paused`; the interface has no pause/resume; Discard is the generic Cancel; save is fused into `'Stop & save'`. **The macOS backend has no pause API** (R54) | high | proto `:514`, `:519`, `:513`, `:1371`, `:1375-1377`, `:1395` — all verified. **ADDITION: both captions sit in a `flex-direction:column; gap:3px` stack under their circle**, which the parent omits / `video_recorder_sheet.dart:11`, `video_recorder.dart:64-78` |
| Discard confirm + toasts | Confirm `Discard this recording?` / `This take will be thrown away and nothing will be saved.` / `Discard` / `danger:true`, with the button chrome from `confirmYesStyle`. **`:1376` also carries a behavioural guard: if `recState === 'idle'` the composer closes immediately with NO confirmation.** Toasts `Recording discarded`, `Voice memo saved`, `Video saved` on `#4a3b2e` / `#f6ead6` / radius 20 / `600 11px` with a 13x13 leading check | Cancel discards silently; no success toast anywhere. `Toast` is a light `StickerCard` with **three** consumers, not one | medium | proto `:1376-1377`, `:1692`, `:1394-1395`, `:900` — all verified. **CORRECTIONS: `Toast` has three consumers (R37); there are two toast renderings, `:900` phone and `:452-453` desktop (R39)** / `toast.dart:6-37`, `voice_composer.dart:122-130`, `video_composer.dart:286-301` |
| Voice entry row | `gap:12px`; play button `38x38` circle `#c76a54` with `1.5px solid #4a3b2e` and a 15x15 glyph at `margin-left:2px`; waveform `flex:1; gap:2.5px; height:24px` of 14 static bars, `width:3`, `borderRadius:2`, heights as percentages of 24, three-tone ramp; duration `600 11px 'Instrument Sans'; #a08a70` | 40x40 circle, 14x14 glyph dead-centred; `WaveformBars` defaults (5 uniform sinusoid bars, one colour, radius `barWidth/2`); readout already `M:SS` in `captionSans` | high | proto `:121-124`, `:1579`, and **`:1256` for the ramp thresholds `>0.62` / `>0.42`, which the parent omits entirely** (R56) / `voice_body.dart:204`, `:206-216`, `:222-259` |

---

## 4. MSP decomposition — Cluster G

**The governing invariant**: merging any MSP must leave the branch's app fully working, and specifically must leave all four capture surfaces openable, usable and dismissible (§0's STANDING INVARIANT). No MSP may depend on a surface a later MSP creates. Ordering is the strict linear stack in §0.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster G is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged** |
| B | Window chrome and nav rail | B1 – B4 | **merged** |
| C | Today centre column | C1 – C7 | **merged** |
| D | Today right rail | D1 – D4 | **merged** |
| E | Flower art | E1 – E4 | **merged** |
| F | Mood picker | F1 – F4 | **merged** |
| G | Capture composers | G1 – G8 | **YES** |
| H | Verification infrastructure | H1 | no |

---

### G1 — Shared composer shell

**Outcome**: the three capture composers — note, voice, video — share one wide warm panel with the prototype's scrim and sprig art, and the note composer gains the header bar. The capture chooser is **not** part of this shell.

**Files**: new `lib/features/capture/core/composer_shell.dart`, new `lib/design/art/sprig_art.dart`, new `lib/design/art/art.dart` (R10), `lib/features/capture/text/text_composer.dart`, `lib/features/capture/voice/voice_composer.dart`, `lib/features/capture/video/video_composer.dart`, **plus the three `*_sheet.dart` files (R2, declared widening)**, `lib/design/tokens/palette.dart` (one token), `test/design/tokens/tokens_test.dart` (one assertion).

**Depends on**: A1, A2, A3, A4 (all merged). Root of this cluster's chain.

**Scope correction, reproduced verbatim from the parent.** An earlier draft said "all four capture dialogs share one wide warm panel". The prototype does not do this. The 760px panel at `:460` sits inside `<sc-if value="{{ composerOpen }}">` (`:458`) and contains exactly three branches: `isTextComposer` (`:462`), `isVoiceComposer` (`:477`), `isVideoComposer` (`:501`). The **chooser is a separate phone-only bottom sheet** at `:746-756` with its own chrome and no desktop counterpart at all. Forcing the chooser into a 760px panel would ship a design the prototype never had, and would directly contradict G4's own line that the desktop chooser keeps its centred-dialog presentation. **G1 covers the three composers only; the chooser is G4's alone** — and this is exactly why G4 is independent of the whole G1 chain.

**Target values** — reproduced verbatim from the parent, `:460`:

```
width          760 FIXED (clamped to available width on narrow screens)
               replaces text 420 / voice 420 / video 460.  The chooser keeps its 360.
background     #fbf3e4                       (from cardBright #fffaf1)
border         2px Palette.ink               (from 1.5px)
borderRadius   Shapes.radiusXl 20            (from 16)
clipBehavior   hardEdge (overflow:hidden — the video viewport bleeds to the panel edge)
boxShadow      Shadows.panelLift  0 44px 96px -30px rgba(30,20,10,.72)
               (from a hard 3px offset, blur 0)
```

`#fbf3e4` is a new surface value not currently in `Palette`; add it in this MSP as `Palette.composerPaper`.

Scrim (`:459`):
```
radial gradient, centre 50% x / 32% y, extent 120% x by 100% y
  rgba(42,32,22,.36) -> rgba(28,20,12,.62)
backdrop-filter blur(7)
fade in 220ms ease
```
Replaces the flat `Palette.ink.withValues(alpha: 0.32)` on the three composer dialogs. The chooser's scrim is `rgba(42,36,29,.34)` per `:747` and is set in G4, not here.

Sprig art (`:461`): `position: absolute; top: -10; right: -8; width: 120; height: 150; opacity: 0.4; ignoring pointers` — a stem stroked `#8a9a63` at width 2.2 with three leaves filled `#9bb078`, `#8fa66c`, `#a3b782`. Drawn as a `CustomPainter`; **no SVG dependency**.

Note-composer header bar (`:463-466`), **note composer only** — it is wrapped in `<sc-if value="{{ isTextComposer }}">` at `:462`. The voice composer has no header bar (its branch opens at `:478` and carries only the close X at `:479` plus its own centred stack — that layout is G5's). The video composer has no header either (G7).

```
padding        14 vertical, 18 horizontal
borderBottom   1.5px DASHED Palette.ink25
left           22x22 close X, tappable
centre         line-height 1.1, two lines:
                 title in composerTitleAccent  Caveat 16 w600 Palette.coral
                 meta '{longDate} · {clock}' in caption9Sans  Instrument Sans 9 w400 #a08a70
right          save button:
                 captureLabelSans recoloured to Palette.onAccent #fff
                 background Palette.coral, border 1.5px Palette.ink
                 borderRadius Shapes.radiusPill 13, padding 7 vertical / 15 horizontal
                 boxShadow Shadows.control  1.5px 1.5px 0 #4a3b2e
```

**ADDITION (`:460`)**: the panel's own entrance is `animation:fn-pop .2s ease-out` — **200ms**, fade plus `scale(.96) -> scale(1)` per the `fn-pop` keyframe at `:24`. The parent's block cites only the scrim's 220ms fade and omits the panel's. Current value is `Motion.modalPop` on all three (`text_composer.dart:103`, `voice_composer.dart:151`, `video_composer.dart:349`).

**Ten resolutions bind G1 and none is optional**: R1 (local `DecoratedBox` + `Clip.hardEdge`), R2 (the fence widening), R3 (760 is a clamp), R4 (the shell paints the scrim; `IgnorePointer` is mandatory), R5 (the `Alignment(0, -0.36)` conversion), R6 (`DialogHost` outermost), R7 (each sheet stays pumpable bare), R8 (the connector composes title and meta; `todayClockProvider` supplies the clock), R9 (one new token), R10 (the new art directory and its barrel), plus R33's `ValueKey('composer-close')`.

**Structure after G1**:

```
showXComposer
  showGeneralDialog(barrierColor: transparent, transitionDuration: 200ms)
    DialogHost                                       R6 — outermost, always
      ComposerShell
        Stack
          IgnorePointer(BackdropFilter + RadialGradient)   R4, R5 — the scrim
          Center
            LayoutBuilder                                  R3
              SizedBox(width: min(760, constraints.maxWidth))
                Container(clipBehavior: hardEdge, …)        R1
                  Stack
                    <Connector>                             the mode's own content
                    Positioned(top: -10, right: -8, SprigArt)  R10, clipped by R1
```

**Must not regress** — reproduced verbatim, with corrected anchors:
- N14 — opening a composer must still never start recording.
- `barrierDismissible: false` on the video composer stays. **CORRECTED**: the anchor is `video_composer.dart:346`, not `:345`.
- **`barrierDismissible: true` on the note composer stays and must still WORK** (`text_composer.dart:100`). This is the one behaviour R4 can silently kill.
- Each mode keeps its own `pageBuilder` return type (`String?` entry id) so callers are unaffected.
- A3's Material ancestor stays in place inside the new shell (R6).
- **N12** — the camera picker at `video_recorder_sheet.dart:105` must still fit and function inside the widened panel.
- **N13** — the nudge / cap / denied surfaces must still be reachable at 760px; G1 widens the box, it does not remove anything from it.
- The chooser is untouched by G1 and must render exactly as it does today until G4.
- `lib/design/widgets/sticker_card.dart` is not opened (R1); its 16 call sites are untouched.

**Tests this MSP owes**: one assertion in `test/design/tokens/tokens_test.dart` for `Palette.composerPaper`. Nothing else. Width, colour, radius, shadow, clip, scrim and a new decorative painter are all styling and exempt; the header bar adds one copy line and one close affordance that replaces nothing yet.

**Acceptance criteria** — reproduced verbatim: the note, voice and video composers are the same wide warm-paper panel with a 2px ink edge and a large soft drop shadow, floating over a blurred warm-vignette background. A faint botanical sprig sits in the top-right corner. The note composer carries a header bar with a corner close X, a handwritten terracotta title over a small date-and-time line, and a terracotta save button pinned right. The voice composer shows a corner close X and its existing centred stack, unmoved. The capture chooser is visually unchanged by this MSP.

**Predicted reds**: `test/design/feedback/dialog_host_test.dart` is the one at risk and stays **green** if and only if R6 holds. No test asserts the current 420/420/460 widths, `Palette.cardBright` or `Shapes.outline` on any composer — verified by grep. The real hazard is R7's layout assertion, which is a hard throw, not a diff.

---

### G2 — Note composer writing surface

**Outcome**: writing happens on a full sheet of paper set in large serif, not in a small outlined textarea.

**Files**: `lib/features/capture/text/text_composer_sheet.dart`, `lib/design/tokens/typography.dart` (two styles), `lib/design/tokens/palette.dart` (one alpha), `test/design/tokens/tokens_test.dart`.

**Depends on**: A1, A2 (merged), **G1**.

**Target values** (`:468-469`) — reproduced verbatim from the parent:

```
body padding   0 horizontal 18, bottom 14
surface        height 440, margin 0 -18 (bleeds to the panel edges)
               borderTop 1px DASHED Palette.ink20
               background Palette.composerPaper #fbf3e4
               NO border box, NO radius, NO inset outline
page padding   44 top, 54 horizontal, 120 bottom
scrolling      vertical, with a 9px scrollbar
editor         'Newsreader', serif; fontSize 19; height 38/19 = 2.0; Palette.ink
               (from bodySerif 16 / height 1.5 in a 12/10 padded box, minLines 4 maxLines 8)
placeholder    'Start writing…'                  — OQ-5 resolved to (b)
               italic Newsreader 19 / line-height 38, Palette.ink at 34% alpha
               positioned top 44, left 54
               (from 'What happened today?' in bodySans 14 upright at Palette.placeholder)
```

**CORRECTION (R11)**: the "from" value is `bodySerif` at **13.5**, not 16 (`typography.dart:65`). The jump is 13.5 -> 19.

**Placeholder copy — OQ-5 resolved to (b) on 2026-07-27**, reproduced verbatim: adopt the prototype's *treatment* (italic serif, 19/38, 34% ink, top 44 / left 54) but **not** its full string. The prototype's markdown-shortcut tail advertises an engine that is out of scope (§6.1); shipping it promises behaviour the editor does not have. Ship `Start writing…` alone.

The line height is **38px absolute on a 19px font**, i.e. a `height` multiplier of exactly 2.0.

**Four resolutions bind G2**: R11 (the corrected "from"), R12 (`expands: true` with both line counts null, plus the shared `ScrollController`), R13 (the placeholder keeps the existing `Stack` + shared padding — do **not** convert to `Positioned`), R14 (two new type tokens plus `Palette.ink34`). R15 confirms `DashedDivider` needs no change.

**Must not regress** — reproduced verbatim: the `EditableText` controller, focus node, cursor colour and keyboard type are unchanged — only the style, sizing and chrome move. Save-button enablement based on non-empty input (currently `Opacity(0.5)`) survives until G3 replaces it with the guard toast.

Additionally: the hint's `ValueListenableBuilder` on `_controller` (`text_composer_sheet.dart:85-101`) is the empty-state mechanism and **must survive intact** — G3 reuses the same signal for its guard.

**Tests this MSP owes**: two assertions in `tokens_test.dart` for the two new type tokens and one for `ink34`. Nothing else — no test asserts the textarea's border, radius, padding, `minLines`, `maxLines`, or the hint string `'What happened today?'` (grep for that string across `test/` returns **zero** hits).

**Acceptance criteria** — reproduced verbatim: the note composer opens onto a tall sheet of warm paper that runs edge to edge under a dashed rule, with generously leaded 19px serif text and an italic serif `Start writing…` placeholder. The placeholder must not mention markdown shortcuts.

**Predicted reds**: **none.** `text_composer_test.dart:57`, `:75`, `:102`, `:110` use `find.byType(EditableText)` and `tester.enterText` and assert on controller text, not style. The only real risk is R12's assertion, which is an implementation bug that reds every text-composer test at once — fix the implementation, never the tests.

---

### G3 — Note composer copy and edit variants

**Outcome**: the composer names itself correctly for new versus edit, and empty saves are guarded with a message rather than a dead button.

**Files**: `lib/features/capture/text/text_composer_sheet.dart`, `lib/features/capture/text/text_composer.dart`, `lib/features/day_detail/day_detail_edit_note.dart`, plus the declared, bounded addition of one case to `test/design/feedback/dialog_host_test.dart` (R20), plus the declared retargets in §5.6.

**Depends on**: A3 (merged), G1, **G2**.

**Target values** (`:1694-1695`, `:1386-1388`):

| Context | Title | Save label |
|---|---|---|
| new note, today | `New note` | `Save` |
| new note, past day | `New note · {day}` | `Save` |
| ~~editing~~ | ~~`Edit note`~~ | ~~`Save changes`~~ — **DROPPED, already shipped** (deleted row 10): `day_detail_edit_note.dart:10-11` declares both and `:57-58` passes them, pinned by four assertions |

Editing an existing note and pressing save opens a confirm: title `Save changes?`, message `Update this note with your edits?`, **`confirmLabel: 'Save changes'`, `danger: false`** — the last two are ADDITIONS from `:1388`, which the parent omits (R17). The non-danger `confirmYesStyle` at `:1692` is **coral**, so the confirm's action is `StickerButtonVariant.primary` with `labelStyle: captureLabelSans`, not `danger`.

Attempting to save empty input shows the toast `Write something first` rather than disabling the button. **ADDITION**: the guard lives at `:1386` — `if(!t && pc===0){ this.flash(dev,'Write something first'); return; }` — a line the parent never cites. The app's predicate is `text.trim().isEmpty` alone (R18).

The saving label becomes an ellipsis character rather than three ASCII periods, matching the app's other in-flight labels: `'Saving...'` -> `'Saving…'` (R21).

The separator in `New note · {day}` is **U+00B7 MIDDLE DOT**, verified at `:1694` (`'New note · '`).

**Six resolutions bind G3**: R16 (two return contracts, and `showEditNote` returns `bool?`), R17 (the omitted confirm fields and the coral button), R18 (the guard's predicate), R19 (both mechanisms are shipped patterns; the `Timer` is cancelled in `dispose`), R20 (the missing `DialogHost` on the edit path), R21 (the ellipsis diff).

**Must not regress** — reproduced verbatim, with the correction applied: N23 — `editNoteFailedMessage` and its inline failure capture (`day_detail_edit_note.dart:12`, `:46-49`) must stay reachable. **CORRECTED**: the composer's return contract is **two** contracts — `Future<String?>` on the three capture composers (`capture_route.dart:4-7`) and `Future<bool?>` on `showEditNote` (`day_detail_edit_note.dart:67`, popping `true` at `:41` and `false` at `:60`). Both are unchanged so `day_detail_edit_note.dart` and `capture_route.dart` keep working. An implementer who "preserves the entry-id contract" on the edit path breaks `day_detail_panel`'s refresh.

Additionally: the guard's `Timer` **must** be cancelled in `_TextComposerSheetState.dispose` (currently `:49-54`, disposing only the controller and focus node). A leaked timer fires `setState` after unmount and reds every text-composer test.

**Tests this MSP owes**: no new file. The parent's own table names G3 as "extend the text-composer tests" (`:1928`), and the extension is satisfied by **strengthening the retargets** rather than adding cases:
- `text_composer_test.dart:53-59` — the case named *"save is inert until the note has text"* is retargeted to the new label **and its assertion is strengthened**: `expect(saved, isEmpty)` still holds, and `expect(find.text('Write something first'), findsOneWidget)` is added to it. The behaviour inverted from inert to announcing, and the existing case is its correct home.
- `day_detail_edit_note_test.dart:71`, `:103` — both gain the second tap on the confirm. Note the confirm's label is **also** `Save changes`, so `find.text('Save changes')` is transiently ambiguous; the retarget must disambiguate by `.last` or by a key.
- One case added to `dialog_host_test.dart` for the fourth dialog (R20). This is a shipped-bug fix on a fix, so a red-before / green-after case is mandatory — the same rule A3 followed.

**Acceptance criteria** — reproduced verbatim: opening the composer from Today reads `New note` with a `Save` button; opening it to edit an existing note reads `Edit note` with `Save changes` and confirms before writing. Pressing save with an empty editor shows `Write something first` instead of nothing happening.

**Predicted reds**: `text_composer_test.dart:53`, `:59`, `:77`, `:104`, `:129`; `text_composer_timeout_dedupe_test.dart:103`; `text_composer_save_hang_test.dart:56`, `:79`, `:81`, `:87`, `:88`; `day_detail_edit_note_test.dart:71`, `:103`, `:132`. All are label or flow retargets, all permitted, all enumerated in §5.6. **`day_detail_edit_note_test.dart:66`, `:78`, `:137` (`Edit note`) are already correct and must stay untouched**, and `day_detail_panel_test.dart:94`'s `'Edit note'` is a **menu item**, not the composer title — verify before touching it.

---

### G4 — Capture chooser

**Outcome**: the chooser is a bottom sheet on phone with bordered rows carrying icons and inner subtitles.

**Files**: `lib/features/capture/chooser/capture_chooser_sheet.dart`, `lib/features/capture/chooser/capture_chooser.dart`, `lib/features/capture/core/capture_route.dart` (three `description` values only).

**Depends on**: A1, A2, A3, A4, D3 (all merged). **INDEPENDENT of G1 through G8** — see the parent's own scope correction at `:1479`, reproduced in G1 above. G4 shares no file with any other G MSP.

**Target values.** Presentation, phone (`:747-749`) — reproduced verbatim:
```
scrim          rgba(42,36,29,.34) Color(0x572A241D), align-items flex-end
sheet          width 100%, background Palette.panelTop #efe2ce
               borderTop 2px Palette.ink only
               borderRadius 22 22 0 0
               padding 16 top, 16 horizontal, 22 bottom
               boxShadow Shadows.chooserSheetLift  0 -14px 34px -14px rgba(50,35,20,.55)
               entrance slide-up 240ms cubic-bezier(.2,.8,.2,1)
grab handle    38 x 4, radius 3, Palette.ink30, margin 0 auto 12
```

Title and subtitle — **CORRECTION: the title is `:750` and the subtitle is `:751`**, not both at `:750`:
```
title      'Capture a moment' in sectionSerif  Newsreader 17 w500 ink, CENTRED
           (from titleSerif 24 w600, left-aligned)
subtitle   'how do you want to plant today?' in Caveat 12 w600 Palette.muted, centred
           (currently absent)                                        ADDITION: margin-top 1
```

Rows — **CORRECTION: `:752` is the container, the three rows are `:753`, `:754`, `:755`**:
```
container  gap 9                                    ADDITION: margin-top 15
row        display flex, align-items center, gap 12
           border 1.5px Palette.ink
           borderRadius Shapes.radiusMd 14
           padding 13 vertical, 15 horizontal
           a 20x20 icon, then an INNER column of:
             title    Instrument Sans 14 w600
             subtitle Instrument Sans 10 w400
row 1      PRIMARY — background Palette.coral, foreground #fff,
           subtitle at opacity 0.85, boxShadow Shadows.emphasis 2px 2px 0 #4a3b2e
rows 2-3   background Palette.cardWarm #f8efe0, foreground ink,
           subtitle Palette.muted #a08a70, NO shadow
```

Row subtitle copy, verified verbatim at `:753-755`: `put the day into words`, `speak it, hands-free`, `a moving snapshot`.

**Four resolutions bind G4**: R22 (clone `showMoodPicker`'s branch-before-`showGeneralDialog` shape; the widget default stays desktop), R23 (rows composed locally; `CaptureIcon` supplies the 20x20 glyph), R24 (no new token; the 14/w600 title is a local `copyWith`), R25 (the desktop branch has no coverage by construction).

**Must not regress** — reproduced verbatim: the additive `'Coming soon'` unavailable state (`capture_chooser_sheet.dart:14`, `:81`) is a preserve item and must keep rendering for types that are not yet wired. The three route labels and their order are exact and stay. On desktop, the chooser keeps its centred-dialog presentation — the bottom sheet is the phone branch only.

Concretely: `'Coming soon'` lands in the **row subtitle** slot, which is the natural home now that the description moved inside the row. `capture_chooser_test.dart:60` asserts `findsNWidgets(2)` on it and must stay green **unmodified**. `today_capture_buttons.dart:102` consumes `captureOptions` but renders only `label` and glyph (`:114-118`, `:90-92`) and never touches `description`, so editing the three descriptions is safe.

**Tests this MSP owes**: **none.** Every change is chrome, copy or a platform branch, all exempt. `resolveShellLayout` — the only new logic G4 could test — is already pinned by `test/app/shell/shell_layout_test.dart`. Do **not** add a `TargetPlatformVariant` sweep over the chooser; it would be a second home for a behaviour that file already owns.

**Acceptance criteria** — reproduced verbatim: on phone the chooser slides up from the bottom edge with a grab handle. Its heading is a centred medium serif line with a handwritten `how do you want to plant today?` beneath it. Each option is one bordered row containing an icon and a stacked title-over-subtitle, with `Write a note` in terracotta with a hard shadow and the other two in warm cream with none.

**Predicted reds**: **zero**, and this is the reason G4 is the cheapest MSP in the cluster. `capture_chooser_test.dart:56` (title preserved), `:57-59` (labels), `:60` (`Coming soon`), `:76-82` (unavailable tap is a no-op, provided `onTap` is null), `:137` (`tapAt(Offset(5,5))` still hits scrim, because a bottom-aligned sheet leaves the top-left as barrier); `app_capture_integration_test.dart:27` (`pump(300ms)` exceeds the new 240ms entrance), `:29-32`; `integration_test/capture_ui_flow_test.dart:53-57` — all green.

---

### G5 — Voice recorder: stage, timer and waveform

**Outcome**: the voice composer is anchored by a big coral mic button with a pulsing halo, a large elapsed-time readout and a twelve-bar wave.

**Files**: `lib/features/capture/voice/voice_recorder_sheet.dart`, `lib/features/capture/voice/record_voice_recorder.dart`, `lib/features/capture/voice/voice_recorder.dart`, `lib/features/capture/voice/voice_composer.dart` (the 250ms ticker — R32), `lib/design/motion/waveform_bob.dart`, `lib/design/motion/glow_pulse.dart`, `lib/design/motion/blink.dart`, `lib/design/tokens/palette.dart` + `typography.dart` (three tokens), `test/design/tokens/tokens_test.dart`, plus the declared, bounded edits to `test/features/capture/voice/voice_test_support.dart` and `voice_composer_save_hang_test.dart` (R27) and the retarget of `test/design/feedback/glow_pulse_test.dart` (R28).

**Depends on**: A1, A2 (merged), **G1**.

**Target values.** Header and hints — header `:480`, hint element `:488`, hint strings `:1703`. *(An earlier draft cited `:479`, which is the close X, and `:487`, which is the elapsed-time readout. Both corrections verified.)*
```
header      'New voice memo' in composerTitleAccent  Caveat 16 w600 Palette.coral,
            margin-top 4   (from 'Record voice' in titleSerif Newsreader 24 w600)
hint idle   "tap the mic when you're ready"   in Caveat 15 w600 Palette.muted
hint rec    'listening… speak freely'
hint paused "paused · resume when you're ready"
            (from 'Tap record when you are ready.' / 'Recording…' in captionSans)
                                              ADDITION: the hint element carries margin-top 2
```
**ADDITION**: the apostrophes at `:1703` are **U+2019 RIGHT SINGLE QUOTATION MARK**, not ASCII, and the separator in the paused hint is U+00B7. The ellipsis in `listening…` is U+2026.

Record control — stage `:483`, halo `:484`, button `:485`. *(An earlier draft cited `:482`/`:484`; `:482` is the paused status row and `:484` is the halo, not the button. Both corrections verified.)*
```
stage      150 x 150, margin 14 auto 6
button     92 x 92 circle
           background Palette.coral #c76a54
           border 2.5px Palette.ink
           boxShadow 0 10px 24px -8px rgba(199,106,84,.7)
           icon 38x38 white mic; while recording, a white pause fill
halo       150 x 150 absolute circle behind the button, gated on recording
           radial gradient rgba(199,106,84,.4) -> transparent 68%
           fn-pulse 2400ms ease-in-out infinite, keyframe at :21 —
             0% and 100%: scale(0.9), opacity 0.5
             50%:          scale(1.25), opacity 0.18
           i.e. a scale-and-fade pulse, NOT a blur/spread pulse
```
The white pause fill is `recTapIcon` at `:1705` and appears **only** in the `recording` state. G5 ships no recording toggle on the mic button — that is G6's — so **G5 needs no pause glyph** (R34).

Elapsed time (`:487` readout, `:1396` the 250ms interval): `Newsreader 38 w400 Palette.ink`, placed below the record button, value `M:SS` starting at `0:00`, ticked every **250ms**. `RecordVoiceRecorder`'s private `Stopwatch` (`record_voice_recorder.dart:27`) is surfaced through the `VoiceRecorder` interface as a synchronous `Duration get elapsed` (R27), and the ticker lives in `VoiceComposerConnector` (R32).

Waveform — container `:489`, mount `:490`, **bar generator `:1258-1262` (CORRECTED from `:1261-1263`, R26)**:
```
container  gap 3, height 40, margin 12 top / 4 bottom
bars       exactly 12, each width 4, borderRadius 3
heights    [.30,.65,.95,.50,.80,.40,1.00,.55,.85,.35,.70,.45] of 40px
colour     #c76a54 when the ratio > 0.6, else #dcae9a
motion     fn-bob scaleY .45 -> 1, per-bar durations 700 / 850 / 1000 / 1150 ms
```
`WaveformBars` gains **nullable** `heights`, `twoToneThreshold` and `perBarDurations`. Its current defaults stay as defaults so the entry-card consumer is unaffected until G8 (R29).

Idle rule (`:491`): when **not recording** — which by `recNotRecording` at `:1702` includes **paused** (R44) — render `width 120; height 2; borderRadius 2; background Palette.ink18` in place of the waveform.

Recording status row (`:481`):
```
gap        7
dot        8 x 8 circle, Palette.danger #c0392b, NO border
           fn-blink 1200ms step-end infinite — HARD on/off, not a fade
label      'Recording' UPPERCASE, Instrument Sans 12 w600,
           letterSpacing 0.08em, Palette.danger
           (from 'Recording…' in captionSans muted, 12x12 outlined dot, 900ms easeInOut fade)
```
`Blink` gains a `stepped` mode — which **must still emit a `FadeTransition`** (R30).

**RESOLVED SPEC GAP (R32).** The parent never says what becomes of the persistent `Cancel` + `Record` / `Stop & save` row at `voice_recorder_sheet.dart:76-87`. **G5 deletes it and ships the close X at `left: 18, top: 18` (22x22, `:479`) as the sole dismissal affordance.** The mic button becomes the sole record affordance. The prototype's voice branch has no Cancel and no Record button in any state. New keys per R33: `ValueKey('voice-close')`, `ValueKey('voice-record-button')`.

**Eight resolutions bind G5**: R26, R27, R28, R29, R30, R31, R32, R33; plus R34 (no pause glyph here) and R35 (`formatMediaDuration` reused unmodified).

**Must not regress** — reproduced verbatim: N14 — opening the sheet must not start recording. N20 — any cue stays behind `GatedSoundService`. The `VoiceRecorderPhase` idle/recording/saving states and the existing save path are unchanged by G5; the paused state arrives in G6.

Additionally: **saving must still work through the deleted button row.** With the row gone, `onStop` is reached from the mic button in the interim (G5) and from the `Save memo` pill once G6 lands. G5 must not leave a phase from which the take cannot be saved.

**Tests this MSP owes**: three assertions in `tokens_test.dart` for `Palette.waveMid`, `TypographyTokens.timerSerif` and `hintAccent`. No new test file — the stage, timer rendering, halo and wave are all styling.

**Acceptance criteria** — reproduced verbatim: the voice composer opens on a handwritten `New voice memo` heading above a large coral mic button on a 150px stage, with a flat 120px hairline where the waveform will be and a handwritten coaching line beneath. Tapping record makes the halo pulse, replaces the hairline with a twelve-bar two-tone wave, shows a large serif `0:03` counting up, and shows a hard-blinking red dot beside uppercase `RECORDING`.

**Predicted reds** (13 assertions + 2 build breaks, all enumerated in §5.6): `glow_pulse_test.dart:16`, `:44`; `voice_recorder_sheet_test.dart:22`, `:23`, `:65`, `:67`; `voice_composer_test.dart:71`, `:109`, `:138`, `:170`, `:174`; `voice_composer_save_hang_test.dart:91`; `voice_composer_timeout_dedupe_test.dart:102`; plus the two `implements VoiceRecorder` **compile failures**. Verified **green**: `waveform_bars_test.dart:21`, `:30-38`; `blink_test.dart:10`, `:28`, `:31`, `:47` (given R30); `voice_recorder_sheet_test.dart:24-25`, `:42-43`, `:128-130`.

---

### G6 — Voice recorder: pause, review pills and discard confirmation

**Outcome**: a take can be paused and resumed, and ending one is a deliberate discard-or-save decision.

**Files**: `lib/features/capture/voice/voice_recorder_sheet.dart`, `lib/features/capture/voice/voice_recorder.dart`, `lib/features/capture/voice/record_voice_recorder.dart`, `lib/features/capture/voice/voice_composer.dart`, new `test/features/capture/voice/voice_pause_test.dart`, plus the declared widenings `lib/design/feedback/toast.dart` and `lib/design/widgets/icon_sticker_button.dart`, plus `lib/design/tokens/palette.dart` + `shadows.dart` + `lib/design/motion/motion_tokens.dart`, `test/design/tokens/tokens_test.dart`, and the two voice test-support files.

**Depends on**: A3 (merged), **G5**.

**Target behaviour and values.** Add `paused` to `VoiceRecorderPhase` and `pause()` / `resume()` to the `VoiceRecorder` interface. State machine: `idle -> recording <-> paused`, with save reachable from **both** `recording` and `paused`. The backend supports it natively (R41).

Paused status row (`:482`): an 8x8 **static** dot in `Palette.statusAmber` `#c9821f` — **CORRECTION: the token is at `palette.dart:54`, not `:36`, and it is already consumed** (R36) — plus label `Paused` uppercase, Instrument Sans 12 w600, letterSpacing 0.08em, `#c9821f`. Hint `paused · resume when you're ready`.

Review pills — **CORRECTION: `:494-496`, not `:494-495`** (R39); gate at `:493`, which is `recActive` and therefore covers **recording AND paused** (R44):
```
container gap 10, margin-top 6                                            :494
Discard   background Palette.dangerSurface #fbecea                        :495
          foreground Palette.danger #c0392b
          border 1.5px Palette.danger
          borderRadius Shapes.radiusSheet 22
          padding 10 vertical / 18 horizontal, gap 8
          15x15 trash icon, label Instrument Sans 13 w600
Save memo background Palette.danger #c0392b                               :496
          foreground #fff
          border 2px Palette.ink
          borderRadius 22
          padding 11 vertical / 22 horizontal, gap 9
          boxShadow Shadows.emphasis  2px 2px 0 #4a3b2e
          leading 15x15 white rounded square, radius 4
          label 'Save memo'
```
These replace G5's mic-button-only save path for the active phases. Both pills are composed locally (R38); the trash icon is reachable today as `IconStickerGlyphIcon(glyph: IconStickerGlyph.trash, color: Palette.danger, size: 15)`.

Discard confirmation — copy from `:1376`, side-effects and the `Recording discarded` toast from `:1377`: title `Discard this recording?`, message `This take will be thrown away and nothing will be saved.`, confirmLabel `Discard`, `danger: true`. Confirm-button chrome comes from `:1692` (`confirmYesStyle`), **not** from `:1376-1377`, and is **exactly** A4's corrected `danger` variant — use `StickerButton(danger)` with `labelStyle: captureLabelSans` rather than a bespoke button (deleted row 24).

`:1376` also encodes a behavioural guard the app must copy, verified verbatim: **if `recState === 'idle'` the composer closes immediately with NO confirmation.** Only a take with recorded content is gated. `saveVoice` at `:1394` carries the mirror guard: save from idle is a no-op.

Toasts — chrome from `:900`, strings from `:1377` (`Recording discarded`) and `:1394` (`Voice memo saved`):
```
background Palette.ink #4a3b2e
foreground Palette.toastInk #f6ead6
borderRadius Shapes.radiusXl 20
padding    8 vertical / 16 horizontal, gap 7
label      Instrument Sans 11 w600
leading    13x13 check icon
boxShadow  Shadows.toastLift  0 10px 24px -8px rgba(0,0,0,.5)
entrance   fn-rise 220ms ease-out
```
**CORRECTION (R37): the parent's "the existing `Toast` widget is used only for the video nudges" is false — it has three consumers.** The dark pill therefore ships as a **variant defaulting to today's light treatment**, so `settings_notice.dart` and `mood_banner_for_date.dart` are byte-identical and `toast_test.dart` stays green unmodified. **CORRECTION (R39): the prototype has two toast renderings, `:900` phone and `:452-453` desktop.** G6 ships the `:900` values the parent names; the desktop variant is deferred (§6.1).

**Eight resolutions bind G6**: R36, R37, R38, R39, R40 (the `showTransientToast` overlay host), R41 (the `paused` exhaustiveness break and `voice_composer.dart:124`'s latent leak), R42 (two tokens plus the `Motion.toastRise` retune), R43 (the shared glyph enum gains `close`, `check`, `pause`), R44 (`recActive` / `recNotRecording` semantics).

**Must not regress** — reproduced verbatim: N14. N20 — cues behind `GatedSoundService`. Cancelling out of an armed-but-not-started session must still discard silently with no confirmation; the confirm applies only to a take with recorded content.

Additionally: `voice_composer.dart:124` (`if (_phase == VoiceRecorderPhase.recording) await _recorder.cancel();`) **must** learn about `paused` in this change or a paused take's file leaks (R41). `_isRecording` / `_isSaving` (`voice_recorder_sheet.dart:43-44`) must too.

**Tests this MSP owes**: `test/features/capture/voice/voice_pause_test.dart`, named by the parent's own table (`:1929`), containing exactly **two** cases, one per named behaviour:

| # | Case | Asserts |
|---|---|---|
| 1 | the pause/resume state machine | `idle -> recording -> paused -> recording`; save is reachable from **both** `recording` and `paused`; the timer **freezes** at pause and continues at resume — assert `elapsed` does not advance across a pumped interval while paused |
| 2 | the discard gate | discarding from `recording` and from `paused` raises the confirm; discarding from **idle** closes with **no** confirm (`:1376`); cancelling the confirm keeps the take |

Plus two assertions in `tokens_test.dart` for `Palette.toastInk` and `Shadows.toastLift`. Everything else in G6 is styling and copy and is exempt.

**Acceptance criteria** — reproduced verbatim: while recording, the button row becomes a red-outlined `Discard` pill and a filled `Save memo` pill. Pausing shows a static amber dot beside uppercase `PAUSED` and freezes the timer; resuming continues it. Pressing Discard asks for confirmation and, on confirm, shows a dark `Recording discarded` toast. Saving shows `Voice memo saved`.

**Predicted reds**: `voice_recorder_sheet_test.dart:44`, `:90`; `voice_composer_test.dart:78`, `:142`; `voice_composer_save_hang_test.dart:105`; `voice_composer_timeout_dedupe_test.dart:106` — all `'Stop & save'` label retargets. Plus the **intentional analyze error** from the non-exhaustive `switch` at `voice_recorder_sheet.dart:129-164`, which is the forcing function, not a defect. **`toast_test.dart` is green unmodified** because of R37 — that is four reds the parent's approach would have caused and this slice avoids.

---

### G7 — Video recorder: dark viewport chrome

**Outcome**: the video composer is a full dark camera viewport with overlay chrome, not a cream settings card.

**Files**: `lib/features/capture/video/video_recorder_sheet.dart`, **`lib/features/capture/platform/camera_video_recorder.dart` (path CORRECTED — R45)**, `lib/features/capture/video/video_recorder.dart`, `lib/features/capture/video/camera_picker.dart`, plus the declared widenings `lib/design/settings_fields/settings_field_row.dart` and `settings_select.dart` (R49), `lib/design/tokens/palette.dart` + `typography.dart` (six tokens), `test/design/tokens/tokens_test.dart`, and the three video test-support files (R51).

**Depends on**: A1, A2, A5 (merged), **G1**; and **G6** for the dark `Toast` variant and the `close` glyph (the one edge the file-overlap matrix adds beyond the declared chain — §0).

**Target values.** Viewport (panel `:460`, dark surface `:502`): the dark camera surface fills the shared 760px panel at `height: 480` (1.583:1), bleeding edge to edge under the panel's `overflow: hidden` (which R1's `Clip.hardEdge` provides). It replaces the light `StickerCard` with its 20px padding, `maxWidth 460` and 200px-tall `ClipRRect` preview. **There is no title and no light body** — remove `Text('Record video')` in `titleSerif` entirely; `:501-522` is the entire video branch and contains no header element.

Feed placeholder (`:502` stripes, `:504` label): `CrossHatchPlaceholder(variant: CrossHatchVariant.viewport, borderRadius: BorderRadius.zero, child: Text('CAMERA FEED', style: TypographyTokens.viewportMonoLabel))`. **The widget already ships complete** — deleted row 25, R48. Only the label style is new.

Vignette (`:503`, verified verbatim): `position: absolute; inset: 0` linear gradient top to bottom, `rgba(15,13,11,.5) -> transparent 22% -> transparent 68% -> rgba(15,13,11,.72)`, drawn over the preview so overlaid controls never sit on raw video.

Close X (`:505`): 22x22 light close glyph pinned `left: 16; top: 16` inside the viewport, replacing the bottom-right `Cancel` sticker button. `barrierDismissible` stays `false` (`video_composer.dart:346`). Key `ValueKey('video-close')`.

Timer pill (`:506` container, `:507-509` state dots, `:510` readout; tick interval `:1396`):
```
position   absolute, top 16, horizontally centred
background Palette.viewportScrim rgba(15,13,11,.5)
borderRadius Shapes.radiusMd 14
padding    5 vertical, 12 horizontal
gap        7
dot        8 x 8 — Palette.recordFill #e0574a blinking while recording,
                   Palette.viewportAmber #f0b34a static while paused,
                   Palette.onDark30 rgba(255,255,255,.5) while idle
time       Instrument Sans 13 w600 #fff, value '0:00' when armed, M:SS, ticked every 250ms
```
**CORRECTION (R47): the paused dot is `#f0b34a`. It is NOT `Palette.statusAmber #c9821f`**, which is G6's voice-paused hue. Two ambers, two surfaces, do not collapse them.

**CORRECTION (R46)**: the parent names only `CameraMacosVideoRecorder`'s `_elapsed` at `camera_video_recorder.dart:212`. There is a **second, independent** `Stopwatch` at `:35` in `CameraVideoRecorder`. Both surface through the interface or the iOS/Android timer reads `0:00` forever.

Shutter (`:513` control row, `:515` shutter, `:516` pause glyph, `:517` inner dot):
```
control row  bottom 22, gap 30
shutter      70 x 70 circle, border 4px #fff, NO background fill
             inner 24x24 circle Palette.recordFill #e0574a when not recording
             26x26 light pause icon while recording
```
Key `ValueKey('video-shutter')`. The pause glyph renders only when `supportsPause` (R54).

Instruction line (`:512` element, `:1704` copy): `position: absolute; bottom: 70`, centred, `Caveat 13 w600 Palette.onDark72`. Copy, verified verbatim: idle `tap the button to start recording`, recording `recording… tap pause or stop`, paused `paused · resume or save your clip`. This replaces the boxed cream status strip.

**N12 / N13 SURFACE LEDGER — where every current surface re-homes. No row may be dropped.**

| # | Surface | Current site | Re-homes to | Dark treatment |
|---|---|---|---|---|
| 1 | `title` "Record video" in `titleSerif` | `:91` | **DELETED** — spec-sanctioned; `:501-522` has no header. Verified | n/a |
| 2 | `_VideoStage` preview frame, `ClipRRect` + ink outline + 200px | `:243-261` | Viewport fill, edge to edge under the panel clip, height 480 | outline and radius dropped |
| 3 | `CrossHatchPlaceholder` no-preview fallback | `:226`, `:245` | Same slot | `variant: viewport`, `borderRadius: BorderRadius.zero`, `child: CAMERA FEED` |
| 4 | **`CameraPicker` (N12)** | `:103-112` | **Overlay inside the viewport, top-right, inset 16**, mirroring the close X at top-left. The prototype has no counterpart, so this is the one free placement decision and it is made here. Keep `_showsPicker` gating (`:75`) and `enabled: _isIdle` (`:108-109`) verbatim | dark `SettingsSelect` per R49; **`camera_picker.dart:35-36`'s `Material(type: MaterialType.transparency)` STAYS** — it is `PopupMenuButton`'s required ancestor |
| 5 | **Nudge `Toast` 5/10/20 min (N13)** | `:113-116`, strings `video_timeline.dart:3-5` | Overlay, below the timer pill | G6's dark variant; **remove the explicit `surface: Palette.cardWarm` at `:115`** |
| 6 | **30:00 cap hint (N13)** | `:100`, `:203-207` | Overlay text under the timer pill | `Caveat 13 w600 Palette.onDark72`. No prototype counterpart; this choice is recorded here |
| 7 | `errorMessage` line, `Palette.danger` | `:117-124` | Overlay, above the instruction line at bottom 70 | on a `Palette.viewportScrim` chip for contrast |
| 8 | **`deniedMessage` + permission stage (N13)** | `:33`, `:222-230`, `_stageMessage` `:263-288` | Centred dark-surface message **inside** the viewport, over the hatch | `viewportScrim` panel, light text |
| 9 | `savingHint` "Saving your video…" | `:31`, `:221` | Instruction-line slot | `Caveat 13 w600 onDark72` |
| 10 | `armingHint` "Getting the camera ready…" | `:29`, `:218` | Instruction-line slot | same |
| 11 | `armedHint` / `recordingHint` | `:28`, `:30`, `:198`, `:237` | **Superseded** by `:1704`'s three strings; a `pausedHint` is added | same |
| 12 | `Blink`-wrapped red dot | `:195` | Timer-pill dot `:507` | `Palette.recordFill`, still `Blink` |
| 13 | `Cancel` sticker button | `:129-133` | Close X `:505`, 22x22, left 16 / top 16 | light glyph; `barrierDismissible: false` unchanged |
| 14 | Primary button (`Record` / `Stop & save` / `Saving…` / `Preparing…` / `Try again`) | `:145-159` | Shutter `:515`. **`Try again` has no counterpart** — the shutter tap is already `onStart` in `denied` (`:156`), so it carries the retry and the dark denied message carries the words (R53) | — |
| 15 | **Six-phase enum (N13)** | `:11` | **Unchanged** in G7; `paused` arrives in G8 | — |
| 16 | **N14 armed idle** | `video_composer.dart:96` sets `idle` and never calls `start()` | **Unchanged.** The shutter tap remains the only path to `_start()` (`:336`) | — |

**Nine resolutions bind G7**: R45, R46, R47, R48, R49, R50 (the timer is new machinery in three files), R51 (seven implementers), R52 (six new tokens), R53 (`Try again` and the arming labels route rather than vanish); plus R33's two keys and R37's `Toast` sequencing.

**Must not regress** — reproduced verbatim: this is the highest-preserve-load MSP in the spec.

- **N12** — the camera picker must be **re-homed inside the dark viewport chrome, not deleted.** `SettingsFieldRow` + `SettingsSelect` need a dark-surface treatment here; the remembered-device provider and the first-camera fallback are untouched. `camera_picker.dart:35`'s `Material(type: MaterialType.transparency)` wrapper stays.
- **N13** — the six-phase machine, the 5/10/20-minute nudges, the 30:00 cap hint, and the permission-denied stage all keep working, with dark-viewport treatments per the ledger. **Do not delete them for lack of a prototype counterpart.**
- **N14** — armed idle. Opening must not start recording.
- The error message line, `deniedMessage`, `savingHint` and `armingHint` all survive with dark-surface styling.

**Tests this MSP owes**: six assertions in `tokens_test.dart` for the six new tokens. No new test file — every behaviour is unchanged and the parent's §5.2 lists G7 explicitly under the exemption ("the composer chrome in G1, G2, G4, G7 where behaviour is unchanged").

**Acceptance criteria** — reproduced verbatim: opening the video composer fills the panel with a dark camera viewport. A corner X sits top-left, a dark timer pill with a state dot sits top-centre showing `0:00`, a handwritten white instruction line floats near the bottom, and a big white-ringed circular shutter with a red inner dot sits below it. The camera dropdown is still present and still remembers the last device. Recording for five minutes still produces the nudge, and the 30:00 cap hint is still visible.

**Predicted reds**: effectively the whole of `test/features/capture/video/video_recorder_sheet_test.dart` (10 cases) plus six collateral files, all label retargets, all enumerated in §5.6. Verified **green** and not to be touched: `:25`, `:26`, `:44`, `:45`, `:66-67` (given the nudge stays a `Toast`), `:136` (`'Camera is off.'`), `:172`, `:195`. Plus **seven compile failures** from the `elapsed` member (R51). **False alarms, verified NOT red**: `app_capture_integration_test.dart:32`, `capture_route_test.dart:22`, `capture_chooser_test.dart:59`, `today_screen_test.dart:105`, `today_capture_buttons_test.dart:45` all assert `'Record video'` as a **chooser row label**, not the deleted composer title; `settings_screen_test.dart:94` and `video_body_slots_test.dart:172`, `:449` are unrelated `Try again` surfaces.

---

### G8 — Video recorder pause/resume and the entry-card voice row

**Outcome**: a video take can be paused, discarded or saved from the shutter row; the voice entry row matches its designed proportions.

**Files**: `lib/features/capture/video/video_recorder_sheet.dart`, `lib/features/capture/video/video_recorder.dart`, `lib/features/capture/video/video_composer.dart`, `lib/features/capture/platform/camera_video_recorder.dart`, `lib/features/entry_cards/cards/voice_body.dart`, `lib/design/motion/waveform_bob.dart`, `lib/design/tokens/palette.dart` (one token), `test/design/tokens/tokens_test.dart`, new `test/features/capture/video/video_pause_test.dart`, plus the three video test-support files (R51).

**Depends on**: **G6** (reuses the discard confirm, the toast host and the shared glyphs), **G7**.

**Target behaviour and values.** Video pause (`:1371` state-machine comment, `:1375` `recTap`, `:1376-1377` discard path, `:1395` save path — all verified): add `paused` to `VideoRecorderPhase` and `pause()` / `resume()` **plus `supportsPause`** (R54) to the `VideoRecorder` interface. Shutter tap semantics: `idle -> beginRec`, `recording -> pauseRec`, `paused -> resumeRec`.

Discard and Save circles flanking the shutter while `recActive` (Discard `:514`, Save `:519`, row `:513`):
```
Discard  44 x 44 circle, background Palette.viewportScrim rgba(15,13,11,.5)
         border 1.5px Palette.onDark40 rgba(255,255,255,.4)
         18x18 light trash icon
         caption 'Discard' Instrument Sans 10 w500 rgba(255,255,255,.75)
Save     44 x 44 circle, background Palette.coral #c76a54, border 1.5px #fff
         18x18 light check icon
         caption 'Save' Palette.onDark85 rgba(255,255,255,.85)
                                     ADDITION: both circles sit in a column
                                     with gap 3 above their caption
```
Discard routes through G6's confirmation dialog and toast; save shows `Video saved` (`:1395`, verified). Keys per R33.

Voice entry row (`:121-124`, `:1579`) — restyle only:
```
play button  38 x 38 circle   (from 40 x 40)
             background Palette.coral, border 1.5px Palette.ink
             15x15 white play glyph with margin-left 2 optical offset  (from 14x14 centred)
gap          12   (already correct — deleted row 27)
waveform     flex 1, 14 STATIC bars, width 3, gap 2.5, container height 24, radius 2
             ratios [.4,.75,1,.55,.85,.35,.7,.5,.9,.45,.65,.8,.38,.6]
             three-tone ramp #c76a54 / #dcae9a / #e3c4b2
duration     Instrument Sans 11 w600 Palette.muted   (already M:SS — deleted row 28)
```
**ADDITION (R56)**: the parent gives the ramp's three colours but **no thresholds**. From `:1256`: `h > 0.62 -> #c76a54`, `h > 0.42 -> #dcae9a`, else `#e3c4b2`. Applied to the fourteen ratios the sequence is `e3c4b2, c76a54, c76a54, dcae9a, c76a54, e3c4b2, c76a54, dcae9a, c76a54, dcae9a, c76a54, c76a54, e3c4b2, dcae9a` — 7 coral, 4 mid, 3 light. Heights are **percentages of the 24px container** and `borderRadius` is a **fixed 2**, not `barWidth / 2`.

**Six resolutions bind G8**: R54 (the macOS blocker and `supportsPause`), R55 (additive `WaveformBars` parameters; the sinusoid modulates the ratios — this is what satisfies N11), R56 (the thresholds and the geometry), R57 (the `_PlayToggle` restyle is in-fence), R58 (the four guards `paused` breaks in `video_composer.dart`), R59 (the corrected N24 paths and the zero-red voice half); plus R51.

**Must not regress** — reproduced verbatim: **N11 is binding on the voice row.** The `isPlaying` state, the **two-valued elapsed/total readout**, the completion-resets-to-zero behaviour, the error placeholder and `ValueKey('voice-play-toggle')` all survive. The prototype shows a single static duration; the app must keep showing `0:03 / 0:12` in the control position. The waveform becomes static in its resting appearance but the widget must keep animating while playing — the 14-bar ratio set defines the resting silhouette, not a removal of motion. N13, N14, N20 all apply to the video half.

Concretely: `voice_body.dart:206-209` already passes `animate: _isPlaying` and rekeys on `ValueKey<bool>(_isPlaying)` at `:207`. **Both stay.** `voice_body.dart:212-216` stays intact; only its `style:` argument may change. **N13 is at acute risk from R58's first defect** — a pause that swallows the `cap` event removes the 30:00 hard stop, which is a preserved capability, not a styling detail.

**Tests this MSP owes**: `test/features/capture/video/video_pause_test.dart`, named by the parent's own table (`:1930`), containing exactly **five** cases:

| # | Case | Asserts |
|---|---|---|
| 1 | the shutter cycle | `idle -> recording -> paused -> recording` through shutter taps, on a `supportsPause: true` fake |
| 2 | the timer freezes while paused | `elapsed` does not advance across a pumped interval in `paused` and resumes advancing after |
| 3 | save from paused reaches persistence | the `:228` guard fix — `_persist()` runs from `paused`, not just `recording` |
| 4 | discard from paused cancels the take | the `:289` guard fix — `_recorder.cancel()` is called from `paused` |
| 5 | **the nudge and cap survive a pause** | a nudge whose wall-clock time elapses while paused still fires after resume, and the `cap` event is never swallowed |

Case 5 is the highest-value case in the file and the parent does not ask for it. It is the receipt for R58's first defect and therefore for N13. Plus one assertion in `tokens_test.dart` for `Palette.waveLight`.

**Acceptance criteria** — reproduced verbatim: while recording video, a dark Discard circle and a coral Save circle flank the shutter, and the shutter shows a pause glyph. Tapping it pauses; the timer dot turns static amber and the timer freezes. Tapping Discard confirms before throwing the take away. On the Today feed, voice entries show a slightly smaller coral play circle and a fourteen-bar static wave in three tints, while still displaying a running elapsed/total time and still pausing correctly.

**Amendment to the acceptance criteria, per R54**: on macOS the shutter keeps stop-semantics and no pause glyph appears, because the vendored backend has no pause API. The Discard and Save circles ship on every platform. This is a declared, honest degradation and is stated in §6.1.

**Predicted reds**: everything under G7's collateral list reds again on the shared file. The **voice half reds nothing at all** (R59) — `voice_body_test.dart`'s seven cases assert semantics, keys, readout text, the corrupt placeholder and lifecycle counts, and G8 touches none of them. `waveform_bars_test.dart:25-40` stays green because R55's parameters are additive.

---

## 5. Verification strategy

### 5.1 What the repo actually has

No golden or screenshot coverage exists. H1 builds it and is **not** dispatched in this run. The automated safety net for Cluster G is the existing widget suite, which for these surfaces is fifteen files:

| Area | Files | What they actually pin |
|---|---|---|
| Chooser | `capture_chooser_test.dart`, `capture_route_test.dart`, `app_capture_integration_test.dart` | Labels, order, `Coming soon`, barrier dismissal, route wiring |
| Note composer | `text_composer_test.dart`, `text_composer_timeout_dedupe_test.dart`, `text_composer_save_hang_test.dart`, `capture_save_hang_repro_test.dart` | Save flow, dedupe, hang behaviour, in-flight labels |
| Voice | `voice_recorder_sheet_test.dart`, `voice_composer_test.dart`, `voice_composer_save_hang_test.dart`, `voice_composer_timeout_dedupe_test.dart` | Phase rendering, start/stop/cancel, hang and timeout paths |
| Video | `video_recorder_sheet_test.dart`, `video_composer_test.dart`, `video_camera_lifecycle_test.dart`, `video_camera_review_test.dart`, `video_composer_save_hang_test.dart`, `video_composer_timeout_dedupe_test.dart`, `video_deadlock_test.dart` | The six-phase machine, camera lifecycle, review, deadlock |
| Design leaves | `dialog_host_test.dart`, `toast_test.dart`, `blink_test.dart`, `glow_pulse_test.dart`, `waveform_bars_test.dart`, `tokens_test.dart` | Widget structure and token values |
| Entry-card voice | `voice_body_test.dart`, `entry_card_test.dart` | N11's semantics, keys, readout and lifecycle |

**Almost none of them asserts a colour, a radius, a padding, a shadow, a width, a font size or a layout arrangement.** They assert **labels**, and this cluster changes almost every label. That is why §5.6's retarget register is the longest section of this document and why the manual pass in §5.5 is the only real fidelity check.

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling, layout or copy change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract.

In this cluster that yields exactly **three** categories:

| MSP | Test | Why it qualifies |
|---|---|---|
| G6 | New `test/features/capture/voice/voice_pause_test.dart`, **two** cases | Behaviour: a new state in a state machine, and a gate that can block a discard. No existing coverage. Named by the parent's own table (`:1929`) |
| G8 | New `test/features/capture/video/video_pause_test.dart`, **five** cases | Behaviour: a second state machine, plus four guard fixes and the nudge/cap survival receipt (R58). Named by the parent (`:1930`) |
| G3 | **One case** added to `test/design/feedback/dialog_host_test.dart` | Shipped-bug fix (R20). A3's own rule: a bug fix gets a red-before / green-after case |
| every MSP that adds a token | **assertions added to existing cases** in `tokens_test.dart` | Contract: a new public constant. This is the parent's A1 rule (`:1919`) and it adds **zero cases** — the file is grouped by token family and the new values join existing cases |
| G1, G2, G4, G5, G7 | none | Colour, radius, padding, shadow, width, font, layout, copy, one platform branch, one decorative painter. All exempt |

This matches the parent spec's own authorised-test table (`:1928-1930`), which lists G3, G6 and G8 and no other G MSP. **G3's entry there reads "extend the text-composer tests"** — satisfied by strengthening two retargeted assertions rather than adding cases (see G3's body), plus the one `dialog_host_test.dart` case.

Per `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, an MSP MAY retarget an existing assertion that pins a rendering it is mandated to change, and the admission gate does not apply to it. **This cluster leans on that permission harder than any before it** — §5.6 registers every instance in advance so no implementer has to judge.

The **declared interface-member edits** to the five recorder test-support files (R27, R51) are a different species again: they are neither new tests nor retargets. An `abstract interface class` gaining a member is a build break, and adding the member to a fake changes no assertion, adds no case and removes none.

**The hard boundary on all three permissions is N24.** None of them touches a `ValueKey`, a Semantics label, or any of the nine files at R59, under any circumstances.

### 5.3 Baseline and per-MSP test-count prediction

**Predict the test count before running.** Every MSP states its expected total before executing `fullValidationCmd`, and compares afterwards. A mismatch that cannot be explained is a defect, not a rounding error.

Baseline, **measured first-hand while composing this slice**, in the foreground, on a tree with `git diff origin/main -- lib/ test/` empty: **`flutter analyze` -> `No issues found!`; `flutter test` -> `+910: All tests passed!` — 910 passing, 0 failing.** The test phase took roughly 26 seconds. **This figure was measured, not inherited; the recorded figure in prior sessions has been stale three times, so measure it again on your own base.**

| MSP | Delta | Expected total | Reason |
|---|---|---|---|
| G1 | **0** | **910** | Token assertions join existing `tokens_test.dart` cases. Every other change is styling. Retargets: none |
| G2 | **0** | **910** | Same. Three token assertions, no case |
| G3 | **+1** | **911** | One `dialog_host_test.dart` case for the fourth dialog (R20). The fourteen label retargets add no case |
| G4 | **0** | **911** | No token, no new case, and zero retargets — G4 changes no asserted string |
| G5 | **0** | **911** | Three token assertions. Thirteen retargets and two fake-member edits, none of which adds a case |
| G6 | **+2** | **913** | Two cases in `voice_pause_test.dart`. Two token assertions add none |
| G7 | **0** | **913** | Six token assertions. All of G7's reds are retargets |
| G8 | **+5** | **918** | Five cases in `video_pause_test.dart`. One token assertion adds none |

**Cluster close: 918.** A result above 918 means a behaviour was split into more cases than the acceptance criteria name — report it rather than absorbing it. A result below 910 at any point means a case was lost, which is the failure this whole discipline exists to catch.

**Two categories of failure that are NOT test-count movements and must not be mistaken for them:**
1. **Build breaks** (R27, R51). Growing `VoiceRecorder` or `VideoRecorder` without updating every implementer produces a compile error and a total of **zero**, not a reduced count.
2. **The intentional analyze error** from the non-exhaustive `switch` when `paused` is added (R41 for voice, R58 for video). That is the forcing function working; it is fixed by handling the branch, never by adding a `default`.

### 5.4 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. **The protected playback suite runs unmodified and passes.** This is N24. In this run it is **background**, not acute — no MSP edits any file in R59's nine-file table, confirmed by path disjointness — but G8 edits `voice_body.dart`, which is the closest any MSP comes. A diff in that suite from a Cluster G change is itself the signal that the fence has been breached.
3. **Never run `flutter test integration_test/` as a directory.** `integration_test/capture_save_persist_test.dart` writes into the real journal container. Name the single file if one is needed — `capture_ui_flow_test.dart` is nameable and **is** needed by G3, G5 and G7, because it holds label assertions that `fullValidationCmd` will never reach (see below).
4. Diff-scoped verification during the work; the full suite runs at the cluster boundary and pre-push.

**CI is not evidence.** Neither GitHub check runs a Dart test. `receiptsPass` and `d6Pass` are never acceptable as proof that this run is green. Run `verify.fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge — verbatim:

```
export PATH="/opt/homebrew/bin:$PATH" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

Run it in the **foreground** with an explicit long timeout. Never background it: a subagent's background shells are swept at teardown, and two earlier attempts on this project were lost that way.

`--delete-conflicting-outputs` is ignored by this repo's `build_runner` version (`W These options have been removed and were ignored`); the build still completes. That warning is expected and is not a failure.

**`fullValidationCmd` runs `flutter test` on the `test/` tree only — it does NOT include `integration_test/`.** `integration_test/capture_ui_flow_test.dart` carries dead-label assertions at `:85`, `:87`, `:114`, `:116`, `:118`, `:120`, `:153`, `:155`, `:157`, `:159` and `:199` that G3, G5 and G7 all break, and **none of them will red under the gate**. Each of those three MSPs runs that one file by name, explicitly, as part of its own verification. `:144` and `:186` use `'Record video'` as a **chooser row** and survive.

### 5.5 Manual spot-check — REQUIRED, and OWED BY A HUMAN

**No agent can run this pass. It is owed by the human after merge, and it is the only fidelity check this cluster has.**

This is a capability fact, not a policy preference. Every surface Cluster G changes sits behind a modal that must be clicked open, and three of them need real hardware — a microphone, a camera, and a permission prompt. Screenshotting a running app is possible via the engine RPC (`decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md`), but click-driving is not: Accessibility TCC is ungranted and needs a Claude Desktop quit-and-reopen. A visible app requires `flutter run -d macos` and never the standalone binary, which renders a black window (`decisions/2026-07-22-black-window-standalone-binary.md`).

The pass is per-MSP, on macOS via `flutter run -d macos`:

**After G1:** all three composers are the same wide warm panel with a 2px edge on a soft blurred shadow, over a blurred vignette rather than a flat brown wash. A faint sprig sits top-right and is **cropped by the panel edge**. The note composer has its header bar. **Tap outside the note composer — it must still close** (R4). Tap outside voice and video — they must **not**. Narrow the window below ~800 logical px and confirm the panel shrinks rather than overflowing (R3).

**After G2:** the note composer opens onto a tall sheet of paper running edge to edge under a dashed rule, 19px serif leaded to 38, with an italic `Start writing…`. Type past the visible area and confirm it scrolls and the caret stays visible.

**After G3:** `New note` from Today; `New note · <day>` from a past day; `Edit note` from day detail. Saving an edit confirms first. Saving empty shows `Write something first` and does not write. The in-flight label is `Saving…` with one character.

**After G4:** on a phone form factor the chooser slides up from the bottom with a grab handle, three bordered rows with icons and inner subtitles, `Write a note` terracotta with a hard shadow. **On desktop nothing changes** — that is the half the macOS pass can actually verify (R25).

**After G5:** the voice composer opens on `New voice memo` above a 92px coral mic on a 150px stage, a flat 120px hairline, and a handwritten line beneath. **There is no Cancel button and no Record button** (R32) — the close X is top-left. Recording pulses the halo, shows the twelve-bar wave, counts up in large serif, and blinks the red dot hard beside uppercase `RECORDING`.

**After G6:** pausing shows a static amber dot beside `PAUSED` and **freezes the timer**; resuming continues from where it stopped, not from zero. Discard asks first; confirming shows a dark `Recording discarded` pill. Saving shows `Voice memo saved`. **Check the settings notice and the Today mood toast are still light** (R37). Discarding from idle closes with no confirmation.

**After G7:** the video composer is a dark viewport with a corner X, a timer pill with a state dot, a handwritten instruction line and a white-ringed shutter. **The camera dropdown is still there, still dark, still remembers the last device** (N12). Deny camera permission and confirm the denied stage still appears and is legible on dark. Record five minutes and confirm the nudge fires as a dark pill (N13).

**After G8:** the shutter pauses on iOS or Android; **on macOS it does not, and that is expected** (R54). Pausing turns the timer dot static amber and freezes the timer. Discard confirms. **Pause across a nudge boundary and confirm the nudge still fires after resume** (R58) — this is the highest-value manual check in the cluster. On Today, voice entries show a 38px coral circle and a fourteen-bar three-tint wave, **still counting `0:03 / 0:12`** and still pausing correctly (N11).

### 5.6 Red-test register — every predicted retarget, declared in advance

Each row is an existing assertion that pins a rendering the named MSP is **mandated** to change. All are permitted retargets. **None touches a `ValueKey`, a Semantics label, or any file in R59's table.**

| MSP | File | Lines | What breaks | Retarget |
|---|---|---|---|---|
| G3 | `test/features/capture/core/text_composer_test.dart` | `:53`, `:59` | `Save note` -> `Save`, **and the behaviour inverts** — the button is no longer inert, it toasts | new label; **strengthen** with `expect(find.text('Write something first'), findsOneWidget)`; rename the case |
| G3 | same | `:77`, `:104` | `Save note` -> `Save` | new label |
| G3 | same | `:129` | G1 deletes `Cancel`; the header has a close X | `find.byKey(ValueKey('composer-close'))` (R33) |
| G3 | `text_composer_timeout_dedupe_test.dart` | `:103` | `Save note` -> `Save` | new label |
| G3 | `text_composer_save_hang_test.dart` | `:56`, `:79`, `:81`, `:87`, `:88` | `Save note` -> `Save`; `Saving...` -> `Saving…` (incl. a test **name** at `:56`) | new labels |
| G3 | `test/features/day_detail/day_detail_edit_note_test.dart` | `:71`, `:103` | a confirm now sits between the tap and the write | add the second tap; **disambiguate** — the confirm's label is also `Save changes` |
| G3 | same | `:132` | `Cancel` deleted | close-X key |
| G3 | `integration_test/capture_ui_flow_test.dart` | `:85`, `:87` | `Save note`, `Saving...` | run by name, invariant on directory runs holds |
| G5 | `test/design/feedback/glow_pulse_test.dart` | `:16`, `:44` | the `boxShadow` model is gone; `:16`'s null-assert throws | assert scale and opacity |
| G5 | `test/features/capture/voice/voice_recorder_sheet_test.dart` | `:22`, `:65` | `Record` -> a 92px icon-only circle | `ValueKey('voice-record-button')` |
| G5 | same | `:23`, `:67` | `Cancel` deleted (R32) | `ValueKey('voice-close')` |
| G5 | `voice_composer_test.dart` | `:71`, `:109`, `:138`, `:170` | `Record` | record-button key |
| G5 | same | `:174` | `Cancel` (R32) | close key |
| G5 | `voice_composer_save_hang_test.dart` | `:91` | `Record` | record-button key |
| G5 | `voice_composer_timeout_dedupe_test.dart` | `:102` | `Record` | record-button key |
| G5 | `integration_test/capture_ui_flow_test.dart` | `:114`, `:116`, `:118`, `:120` | `Record`, `Saving…` flow | run by name |
| G6 | `voice_recorder_sheet_test.dart` | `:44`, `:90` | `Stop & save` -> the `Save memo` pill | `ValueKey('voice-save-pill')` |
| G6 | `voice_composer_test.dart` | `:78`, `:142` | `Stop & save` | save-pill key |
| G6 | `voice_composer_save_hang_test.dart` | `:105` | `Stop & save` | save-pill key |
| G6 | `voice_composer_timeout_dedupe_test.dart` | `:106` | `Stop & save` | save-pill key |
| G6 | `integration_test/capture_ui_flow_test.dart` | `:153`, `:155`, `:157`, `:159` | the voice save flow | run by name |
| G7 | `test/features/capture/video/video_recorder_sheet_test.dart` | `:23`, `:89` | `Record` -> the shutter | `ValueKey('video-shutter')` |
| G7 | same | `:24`, `:91` | `Cancel` -> the close X | `ValueKey('video-close')` |
| G7 | same | `:46`, `:68`, `:114`, `:128` | `Stop & save` | shutter / save-circle keys |
| G7 | same | `:152` | `Saving…` was a **button** label | `savingHint` `'Saving your video…'` |
| G7 | same | `:171` | `Preparing…` was a button label | `armingHint` |
| G7 | same | `:196-199` | `Try again` (R53) | the shutter carries the retry; assert the denied message |
| G7 | `video_composer_test.dart` | `:55`, `:129`, `:163`, `:165`, `:167`, `:191`, `:192`, `:198`, `:202`, `:227`, `:228`, `:231`, `:255`, `:284` | dead labels | keys per R33 |
| G7 | `video_camera_lifecycle_test.dart` | `:72`, `:88`, `:109`, `:112`, `:189`, `:217` | dead labels | keys |
| G7 | `video_camera_review_test.dart` | `:248`, `:265`, `:270`, `:272`, `:326` | dead labels | keys |
| G7 | `video_composer_save_hang_test.dart` | `:113`, `:118`, `:120`, `:127`, `:128` | dead labels | keys |
| G7 | `video_composer_timeout_dedupe_test.dart` | `:102`, `:107` | dead labels | keys |
| G7 | `video_deadlock_test.dart` | `:48`, `:74` | dead labels | keys |
| G7 | `integration_test/capture_ui_flow_test.dart` | `:199` | dead label | run by name |

**Verified NOT red — do not "fix" these:** `today_screen_test.dart:103-105`, `today_capture_buttons_test.dart:43-47`, `:65`, `:72`, `capture_chooser_test.dart:57-59`, `:76-80`, `:108`, `:174`, `capture_route_test.dart:22`, `app_capture_integration_test.dart:30-32`, `day_detail_panel_test.dart:77`, `:94` — all assert **chooser labels** or a **day-detail menu item**, not composer titles. `day_detail_edit_note_test.dart:66`, `:78`, `:137` (`Edit note`) are **already correct**. `test/repro/capture_save_hang_repro_test.dart:69` holds `Saving...` in a **description string only**, not an assertion. `settings_screen_test.dart:94` and `video_body_slots_test.dart:172`, `:449` are unrelated `Try again` surfaces.

### 5.7 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation.

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

- **The markdown editor engine.** Live block styles, the floating selection toolbar and the footer legend (`:473`, `:1360-1368`) are a whole editor subsystem with data-model implications, routed to its own spec by the parent's §6.1. **G2 delivers the paper surface only**, and OQ-5's resolution to (b) is why the placeholder is `Start writing…` alone.
- **`Add memory` and photo attachment.** The prototype's tape-framed free-manipulation photo cards (`:471`) are a drag-rotate-resize subsystem. `PhotoTray` exists and is dead UI. **OQ-6 is still open**, which is exactly why G3's empty-save guard is text-only (R18).
- **The prototype's desktop toast rendering** at `:452-453` — radius 22, padding 10/20, 13px label, `bottom: 22`, 15x15 check. G6 ships one treatment, the `:900` phone values the parent names (R39). Forking `Toast` by form factor for a two-pixel type difference is not a shippable distinction.
- **The `bookclose` cue on discard and save.** `:1377`, `:1394` and `:1395` all call `this.play('bookclose')`. The parent's G6 and G8 blocks do not mention it, no MSP in this run authorises a cue, and the app has exactly one cue today (F4's `pencil`). **Adding it here would be an unrequested behaviour change on the app's only gated audio path.** Recorded with its citations so a later spec can adopt it deliberately — and if it ever does, it goes behind `GatedSoundService` (N20).
- **macOS video pause.** `supportsPause` returns `false` and the chrome degrades honestly (R54). Real pause needs a Swift method-channel handler plus Dart plumbing in `third_party/camera_macos/`, which is outside every fence in this run and is a materially different MSP.
- **Migrating the two existing inline toast consumers to `showTransientToast`.** G6 builds the host; `settings_notice.dart` and `mood_banner_for_date.dart` keep their inline rendering (R37). A migration is a refactor with no shippable outcome.
- **Golden / screenshot infrastructure is H1's.** Cluster G does not build it and adds no golden test.
- **OQ-3** (entry-card Edit/Delete placement) remains open and touches no MSP in this run.

### 6.2 Explicitly not a task

- **No change to `lib/design/widgets/sticker_card.dart`**, including adding a `border` or a `clipBehavior` parameter (R1, R38). 16 call sites, plus A4's contract and `sticker_card_test.dart`.
- **No new `StickerButton` variant.** The chooser rows (R23) and the review pills (R38) are composed locally. `StickerButton` **is** the right answer for exactly two things in this cluster: G3's primary confirm (R17) and G6's danger confirm (deleted row 24).
- **No sound cue of any kind.** N20 governs cues, and this cluster adds none (§6.1). If a cue appears in a diff, it is out of bounds.
- **No edit to `lib/features/settings/widgets/settings_notice.dart` or `lib/features/mood/mood_banner_for_date.dart`.** Read-only; R37's defaulting variant is what keeps them so.
- **No edit to `lib/app/shell/shell_layout.dart`.** G4 consumes `resolveShellLayout`; it does not change it (R22).
- **No edit to `lib/features/entry_cards/util/duration_format.dart`.** N11-load-bearing (R35).
- **No edit to `third_party/**`.** G8 degrades by capability (R54).
- **No edit to `lib/domain/**`.**
- **No new dependency of any kind**, no `flutter_svg`, and no `showModalBottomSheet`. G4's sheet is `showGeneralDialog` with a bottom alignment and a slide transition, which is what keeps `DialogHost`, the barrier label and the shared dismissal path intact.
- **No growth of `Motion.all`** (R31). New durations are constructor arguments from local constants.
- **No golden test and no per-widget geometry test.** Change-detectors on values this document already pins.
- **No `flutter run` by an implementing agent.** Visual confirmation is a human step on macOS hardware (§5.5).
- **No deletion or weakening of the protected playback suite** under any circumstances (N24, R59).

### 6.3 Open questions

**One open question in the parent spec is touched by this run and is answered here, in bounds.** OQ-5 was already resolved to (b) on 2026-07-27 and G2 implements that resolution unchanged. **OQ-6** (the photo attachment model) remains open and is the reason G3's empty-save guard omits the prototype's `photoCount === 0` clause (R18) — that is a scoping consequence, not an answer. **OQ-3** remains open and touches no MSP here.

**Two decisions this slice makes that the parent left to the implementer, recorded as decisions rather than resolutions**, because they are placement choices with no prototype counterpart:

1. **The camera picker sits top-right inside the viewport, inset 16**, mirroring the close X (G7 ledger row 4).
2. **The 30:00 cap hint sits under the timer pill** as overlay text in `onDark72` (G7 ledger row 6).

Both preserve N12 and N13 respectively; neither has a `.dc.html` line, and both are stated so an implementer does not have to invent one mid-flight.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Every prototype line this cluster cites was re-opened while composing this slice.** `:21` (`fn-pulse`), `:24-25` (`fn-pop`, `fn-sheet`), `:121-124` (voice entry row), `:452-453` (desktop toast), `:458-473` (composer open, scrim, panel, sprig, note branch, header, body, surface, footer, legend), `:477-497` (voice branch, close X, header, status rows, stage, halo, button, timer, hint, wave container, mounts, idle rule, pills), `:501-522` (video branch, viewport, vignette, label, close X, timer pill, dots, readout, instruction, control row, discard, shutter, glyphs, save), `:746-756` (chooser), `:899-901` (phone toast), `:1254-1263` (both bar generators), `:1315` (`fmtClock`), `:1323` (`flash`), `:1371-1377` (the recording machine and the discard path), `:1386-1388` (the empty-save guard and the edit confirm), `:1394-1396` (save paths and the 250ms interval), `:1579` (the fourteen ratios), `:1692` (`confirmYesStyle`, both branches), `:1694-1695` (composer copy), `:1702-1705` (state predicates, hints, tap icon) — all read byte for byte.

**Where the parent quotes a value for Cluster G, the value is almost always right and the CITATION is often wrong.** Four kinds of defect, in descending order of danger:

1. **Values that are unreachable through the widget the target is built from.** `StickerCard` cannot render a 2px border or clip (R1); `StickerButton` cannot render any of the six pills and rows (R23, R38); `SettingsFieldRow` and `SettingsSelect` have no colour hook at all (R49); `WaveformBars` cannot express ratios, a ramp or a fixed radius (R29, R55); `GlowPulse` implements the wrong animation model entirely (R28). **Recon that only verifies citations does not find these.** Every one was found by opening the widget the value would have to pass through.
2. **Capabilities the app does not have, in any form.** No toast host anywhere (R40); no elapsed clock in either recorder at any layer (R27, R50); no `BackdropFilter` ever (R4); no `lib/design/art/` (R10); no close, check or pause glyph (R43); no pause API in the macOS camera backend, in Dart or in Swift (R54). These are gaps between a correct target and a codebase with no way to hold it.
3. **Fence defects — the file that owns the value is not the file the MSP names.** G1's entire target block lives one layer below its declared files (R2). `camera_video_recorder.dart` is in a different directory than the parent says (R45). G6's mandated `Toast` restyle names neither the widget file nor its test.
4. **Citation drift, now at fourteen instances in this region alone.** `video_composer.dart:345` -> `:346`; the bar generator `:1261-1263` -> `:1258-1262`; the review pills `:494-495` -> `:494-496`; `palette.dart:36` -> `:54`; the chooser title/subtitle conflated at `:750`; the chooser rows conflated at `:752-755`. Plus one factual error about the app (`bodySerif` is 13.5, not 16 — R11), one about a token's usage (`statusAmber` is not unused — R36), one about a widget's consumers (`Toast` has three, not one — R37), one about a return type (`showEditNote` returns `bool?` — R16), and one hue collapsed onto the wrong token (`#f0b34a` is not `#c9821f` — R47).

**And omission, which is this region's most common failure**: values sitting on lines the parent already cites. The panel's own 200ms `fn-pop` entrance (`:460`); the voice hint's `margin-top:2px` (`:488`); the chooser subtitle's `margin-top:1` and the row container's `margin-top:15` (`:751`, `:752`); the edit confirm's `confirmLabel` and `danger:false` (`:1388`); the empty-save guard's whole existence (`:1386`); the three-tone ramp's thresholds (`:1256`); the Discard/Save captions' column stack (`:514`, `:519`); `recActive` and `recNotRecording`'s semantics (`:1702`). Each is supplied above with its own citation.

**One environmental fact is load-bearing and binds G4 specifically**: under `flutter test`, `defaultTargetPlatform` is forced to `android` by an assert in the Flutter SDK keyed on `FLUTTER_TEST`. Every widget test in this repo therefore drives the **phone** branch, and desktop coverage exists only where a widget's own default is desktop (R22, R25).

**Rule for implementers:** re-open every cited line — both in the prototype HTML and in the app's own source — before adopting any value, and **open the widget the value has to pass through before assuming it can hold it.** If you meet an anchor that does not resolve, or a target the code has no way to express, **stop and report. Do not make the call yourself** — that is exactly how the C5 caption and three C7 ladder rows were lost.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
