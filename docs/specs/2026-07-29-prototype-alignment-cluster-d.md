# Prototype Design Alignment — Cluster D (Today right rail) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **D — Today right rail**
MSPs: **D1, D2, D3, D4**
Base: `main` at `5866470`
Citation source: `docs/prototype/project/Field Notes.dc.html`

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec.** Where this document reproduces parent text, it reproduces it verbatim. Where a reader needs material this slice omits — findings §3.1–§3.3 and §3.5–§3.7, MSPs A1–C7 and E1–H1, the excluded-elements table §6.1 — the parent spec on main is the authority.

**Clusters A, B and C are already merged and are this run's base.** A1–A5 shipped as PRs #51/#53/#54/#55/#56; B1–B4 shipped as PRs #62/#63/#64/#65; C1–C7 shipped and closed the centre column (16 of 39 MSPs landed). The Cluster D recon that grounds this slice (`.claude/ledger/sessions/2026-07-29-02-prototype-design-alignment.md`) confirmed every citation D1–D4 rely on resolves byte-identical and every token they consume already exists on this base — the token layer closed with Cluster A and **Cluster D touches no token file**. That recon is verified ground truth; this document does not re-derive it, but every path:line pair below was independently re-read against the base commit while composing this slice, and two corrections surfaced in that pass (an in-repo line-number drift in D3's reachability trace, and a fourth test-file collision the recon session did not enumerate) — both are called out at their point of use.

Every token D1–D4 target was confirmed present at value, at the cited line, on this base:

| Token | path:line | Value | Consumed by |
|---|---|---|---|
| `TypographyTokens.sectionHeaderAccent` | `lib/design/tokens/typography.dart:111-116` | Caveat 17 w600 `Palette.sage` | D1 (already wired at all three headers — copy/margin only), D2, D3, D4 |
| `TypographyTokens.caption10Sans` | `typography.dart:208-213` | Instrument Sans 10 w400 `Palette.muted` | D2 (week date-range subtitle) |
| `TypographyTokens.caption8Sans` | `typography.dart:229-233` | Instrument Sans 8 w600, `color: null` (state-dependent by design) | D2 (week cell label) |
| `TypographyTokens.caption9Sans` | `typography.dart:222-227` | Instrument Sans 9 w400 `Palette.muted` | D4 (memory meta line) |
| `TypographyTokens.monoMicroSans` | `typography.dart:250-255` | monospace 7 w500 `Palette.muted` | D4 (hatch-band caption) |
| `TypographyTokens.memoryTitleSerif` | `typography.dart:88-93` | Newsreader 12 w500 `Palette.ink` | D4 (memory title) |
| `TypographyTokens.captureLabelSans` | `typography.dart:195-199` | Instrument Sans 12 w600, `color: null` (per-row colour) | D3 (capture row labels) |
| `Shapes.radiusCell` | `lib/design/tokens/shapes.dart:11` | `10` | D2 (week cell radius) |
| `Shapes.radiusControl` | `shapes.dart:13` | `12` | D3 (capture row radius) |
| `Shapes.radiusPill` | `shapes.dart:14` | `13` | D4 (on-this-day card radius — named for a pill, correct anyway; see resolution 3) |
| `Shapes.outlineWidth` | `shapes.dart:6` | `1.5` | D1 — the value the rail's 1px seam must **not** use; see resolution 1 |
| `Shadows.cellToday` | `lib/design/tokens/shadows.dart:24-31` | `Palette.coral30`, offset (1.5, 1.5), blur 0 | D2 |
| `Shadows.cellFilled` | `shadows.dart:15-22` | `Palette.ink18`, offset (1.5, 1.5), blur 0 | D2 |
| `Shadows.cardDefault` | `shadows.dart:42-49` | `Palette.ink16`, offset (2, 2), blur 0 | D4 |
| `Shadows.emphasis` | `shadows.dart:51-58` | `Palette.ink`, offset (2, 2), blur 0 | D3 — already wired via `StickerButtonVariant.primary`, no direct reference needed |
| `Palette.dashMuted` | `lib/design/tokens/palette.dart:42` | `0xFFC3B39A` | D2 (empty-cell circle and label, replacing the wrong `Palette.placeholder`) |
| `Palette.ink35` | `palette.dart:28` | `0x594A3B2E` (0x59/0xFF = 0.349, matching the prototype's `rgba(74,59,46,.35)` at `:1610`) | D2 (empty-cell dashed border) |
| `Palette.ink22` | `palette.dart:25` | `0x384A3B2E` | D1 (rail left seam) |
| `Palette.ink16` | `palette.dart:22` | `0x294A3B2E` | D1 (the two section-separator hairlines) |
| `Palette.hatchMid` / `Palette.hatchLight` | `palette.dart:58` / `:57` | `0xFFE2D3BA` / `0xFFECDFC8` | D4 — `CrossHatchVariant.photo`'s existing defaults; see resolution 2 |

**Unlike Cluster C, no MSP in this run adds, renames, extends or overrides a token-layer primitive.** C4 extended `IconStickerGlyph` and C6 added an opt-in `headline` slot; Cluster D needs none of that — every value above is consumed exactly as it already exists. If a value appears to be missing, re-read the token file before concluding it is absent; if it is genuinely absent, stop and report rather than adding it.

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Five decisions this cluster depends on do not fall out of reading the target tables alone. Each is resolved here, and each names the specific test that would go red if the resolution is implemented backwards — the standard the C slice's own resolution 6 failed to meet, which cost C7 three rows when an implementer acted on reasoning instead of a receipt.

1. **D1's rail-seam left border is 1px, and no 1px width token exists or is added.** `Shapes.outlineWidth` is the only stroke-width constant in the token layer (`shapes.dart:6`) and it is fixed at `1.5`; the rail's left seam (`:152`, `border-left:1px dashed rgba(74,59,46,.22)`) is thinner than the house stroke by design, not by rounding error. D1 passes a **literal** `1.0` as the `thickness` argument to `DashedDivider(axis: Axis.vertical, color: Palette.ink22, thickness: 1.0)` at the rail's left edge, exactly mirroring the precedent B2 already shipped for the nav rail's own right-hand seam (`lib/app/shell/sidebar_shell.dart:47-50`: `DashedDivider(axis: Axis.vertical, thickness: 1.0, color: Palette.ink22)`). D1 must not read `Shapes.outlineWidth` for this value and must not add a new `Shapes` constant to name it.
   **Receipt**: `test/design/tokens/tokens_test.dart`, `'outline is a 1.5px ink border'` (:62-65), pins `Shapes.outlineWidth == 1.5` by name. Touching that shared constant to accommodate the rail's thinner seam reddens this test immediately, and because `Shapes.outline` is consumed by `StickerCard`, `StickerButton` and `CrossHatchPlaceholder` alike, it would silently thin every 1.5px border in the app at once.

2. **D4 supplies no `hatchColor` override to `CrossHatchPlaceholder`.** `CrossHatchVariant.photo` — the widget's default variant — is already `ground: Palette.hatchMid` (`#E2D3BA`) / `band: Palette.hatchLight` (`#ECDFC8`) at 6px band / 12px pitch (`lib/design/widgets/cross_hatch_placeholder.dart:27-32`), a byte-exact match for the prototype's `:175` gradient. `hatchColor`, when supplied, alpha-blends at 0.5 onto the ground (`:72-75`) and moves the rendered band away from `#ECDFC8`. D4 constructs `CrossHatchPlaceholder(variant: CrossHatchVariant.photo, height: 82)` and passes neither `background` nor `hatchColor`.
   **Receipt**: `test/design/widgets/cross_hatch_placeholder_test.dart`, `'resolves each variant to its two-tone band pair, defaulting to photo'` (the case opens at `:103` and runs past the photo block to cover the video and viewport variants; the photo assertions are at `:128-129` — `expect(photo.ground, Palette.hatchMid)` / `expect(photo.band, Palette.hatchLight)`, with `:126-127` fetching the painter), pins the zero-override band at exactly `Palette.hatchLight`. The sibling case `'blends a hatchColor override into the band instead of painting it at full strength'` (:172-199) proves the blend mechanism on the same painter — it demonstrates it on `Palette.danger` over `Palette.dangerSurface`, not on the photo pair. Both are pre-existing and stay unmodified; together they are the standing proof that omitting the override is the only path to the cited colour — the exact mechanism that cost C7 three rows when its own §0 resolution 1 called for supplying colour overrides on the video variant.

3. **`Shapes.radiusPill` (13) is numerically correct for D4's card and keeps its name.** The prototype's on-this-day card radius (`:174`, `border-radius:13px`) matches `Shapes.radiusPill` exactly, despite the constant being named for a pill-shaped control — it is also what C2's and C3's mood-banner change controls already consume (`lib/features/mood/mood_banner.dart:67`, `:75`, both merged). The token layer is rename-closed as of Cluster A; D4 uses the constant as-is and this line records the naming oddity rather than fixing it.
   **Receipt**: `test/design/tokens/tokens_test.dart`, `'the ladder exposes every prototype step in ascending order'` (:132-149), references `Shapes.radiusPill` by name at line 141 inside a fixed-position array. Renaming or removing the constant does not silently pass — it fails to compile, taking this test, and the whole file, down with it.

4. **D4 repurposes the existing preview snippet as the card's serif title; it does not delete it.** `OnThisDayMemory` (`lib/features/today/today_memory.dart:10-14`) carries only `day` and `yearsAgo` — there is no title field in the domain, and the prototype's `The garden last summer` (`:176`) is hardcoded mock filler bound to no data. Deleting the app's 2-line preview to match the prototype's silhouette would be a net information loss against what ships today.
   **Binding ruling** (`.claude/ledger/decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md`): the existing `preview` string (`firstTextPreview`, `today_memory.dart:57-73`) is restyled into `memoryTitleSerif` in the title slot instead of `bodySerifItalic` in a 2-line clamp; the domain model is untouched, so OQ-6 is not answered as a side effect.
   **Receipt**: `test/features/today/on_this_day_card_test.dart`, `'renders the memory with years-ago, long date, flower and preview'` (:16-34), specifically `expect(find.text('sun on the deck'), findsOneWidget)` at `:32` — this assertion matches on the string, independent of which `TextStyle` wraps it, so it stays green **unmodified** under the repurposing resolution. If an implementer instead deletes the preview, this exact line goes red.

5. **`StickerButton` gains an optional `labelStyle` parameter, defaulting to `null` (unchanged rendering).** D3's label target is `captureLabelSans` (Instrument Sans 12 w600, `typography.dart:195-199`), but `StickerButton` hardcodes `TypographyTokens.buttonSans` (15 w600, `lib/design/widgets/sticker_button.dart:62-65`) with no override — and that file sits outside D3's declared scope, shared with **12 other files carrying 24 other call sites** across settings, capture composers, day detail and the chooser (re-counted at compose time: 26 `StickerButton(` instantiations across 13 files, of which `today_capture_buttons.dart` holds 2 at `:79` and `:83`; the constructor declaration at `sticker_button.dart:19` and the unrelated `IconStickerButton` are excluded).
   **Binding ruling**: D3 adds `this.labelStyle` to `StickerButton`'s constructor, defaulting to `null`, and renders `(labelStyle ?? TypographyTokens.buttonSans).copyWith(color: style.foreground)` — a one-file, **declared** fence widening, mirroring the shape of C6's optional `headline` slot on `EmptyStatePlaceholder`. Every other consumer passes no `labelStyle` and renders exactly as before.
   **Receipt**: `test/design/widgets/sticker_button_test.dart`'s four variant-styling cases — `'outlines every variant in 1.5px ink'` (:83-96), `'lifts the default primary variant on the emphasis shadow'` (:98-113), `'drops the shadow entirely for the secondary variant'` (:115-130), `'fills the danger variant red on the control shadow'` (:132-147) — pin every variant's border, shadow, fill colour and padding without ever passing `labelStyle`. They must stay green **unmodified**; any collateral change to the widget while threading the new parameter through reddens them immediately.

A sixth item the recon flagged — `lib/design/icons/capture_icons.dart` does not exist yet — is **not** a decision with a wrong alternative; it is a new-file fact, recorded in the fence table below (mirroring how C1's `flame_icon.dart` and B3's `nav_icons.dart` were handled as fence-table facts rather than numbered resolutions).

### HARD SCOPE FENCE

This run ships **exactly four MSPs: D1, D2, D3, D4.** No others.

- Do **not** create MSPs for clusters A, B, C, E, F, G or H. They are named below only so cross-cluster dependencies stay legible. Clusters A, B and C are already merged; re-implementing any part of them is a defect, not a dependency.
- The complete set of files this run may touch is:

  | File | Owning MSP | New? |
  |---|---|---|
  | `lib/features/today/today_layout.dart` | D1 | no |
  | `lib/features/today/today_screen.dart` | D1 | no |
  | `lib/features/today/today_right_rail.dart` | D1 | no |
  | `lib/features/today/this_week_garden.dart` | D1, D2 | no |
  | `lib/features/today/today_capture_buttons.dart` | D1, D3 | no |
  | `lib/features/today/on_this_day_card.dart` | D1, D4 | no |
  | `lib/features/today/today_week.dart` | D2 — verify-only per its own "Must not regress"; the week model is already correct | no |
  | `lib/design/widgets/sticker_button.dart` | D3 | no (additive `labelStyle` param — **declared fence widening**, §0 resolution 5) |
  | `lib/design/icons/capture_icons.dart` | D3 | **new** |
  | `lib/features/today/today_memory.dart` | D4 | no |
  | `lib/features/today/today_date.dart` | D4 | no (additive short-date formatter; sole consumer, no shared-primitive hazard — see D4) |
  | `test/features/today/this_week_garden_test.dart` | D1, D2 | no (**existing**, 3 cases — the parent spec's "new" label is stale and corrected here) |
  | `test/features/today/today_capture_buttons_test.dart` | D1, D3 | no |
  | `test/features/today/today_screen_test.dart` | D1, D3, D4 | no |
  | `test/features/today/on_this_day_card_test.dart` | D1, D4 | no |
  | `test/features/today/today_date_test.dart` | D4 | no (**existing**, 6 groups — additive case for the new short-date formatter, §5.2) |
  | `integration_test/capture_ui_flow_test.dart` | D3 | no |

- **Two narrow carve-outs**:
  - **D3's `sticker_button.dart` widening is declared, not discovered.** It is bounded to one additive, default-`null` constructor parameter (§0 resolution 5); the widget's existing behaviour at every one of its 24 other call sites, across 12 other files, is unchanged, and that is the receipt (their tests pass unmodified — a stronger guarantee than a new test, per §5.2).
  - **D2's touch to `today_week.dart` is read-only in practice.** The parent spec lists it in D2's file set because the tap-to-Calendar navigation needs the cell's `date`, which `TodayWeekCell` already exposes (`today_week.dart:17`). If D2's implementation needs no edit here, that is the correct outcome, not a shortfall.
- **Three consumers are verify-only — read them, do not edit them:**
  - `lib/app/shell/app_shell.dart:34-36` (`_openCapture`), `:51` (`onCapture` wiring), `:70` (passed into `BottomBarShell`) — the phone capture-chooser's entry point. *Correction*: the parent spec's D3 body cites `app_shell.dart:41` / `:30-32` for this trace; those lines have drifted since Clusters A–C merged. The lines above were re-read directly against this slice's base and are current.
  - `lib/app/shell/bottom_bar_shell.dart:112-129`, specifically `:116` (`onTap: onCapture`) — unchanged from the parent's citation, re-verified here.
  - `test/app/shell/bottom_bar_shell_test.dart:52` (`'the center capture invokes onCapture'`) — the standing proof that the phone path survives D3's desktop-button removal. It asserts through `ValueKey('capture-button')`, not through the text `'Capture'`, so it is structurally immune to D3's copy change; it must still pass, unmodified.
- Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/design/tokens/*` — closed by Cluster A.
  - `lib/app/shell/**` — closed by Cluster B. D1's rail sits inside the app shell's layout but the files it touches live in `lib/features/today/`.
  - `lib/design/icons/nav_icons.dart` and `lib/design/icons/flame_icon.dart` — B3's and C1's respectively. D3 creates a **new** `capture_icons.dart` for the pencil/mic/video glyphs; extending `NavGlyph` or reaching into either existing file is out of scope even though the shape (enum + `CustomPainter`) is the same pattern.
  - `lib/design/widgets/sticker_card.dart` — C's §0 resolution 5 already forbids editing this shared surface; it does not apply to Cluster D's file list, but StickerCard's hardcoded `Shapes.outline` border is the same shared primitive D1's resolution 1 protects.
  - `lib/features/entry_cards/**`, `lib/features/mood/**`, `lib/features/streak/**`, `lib/features/capture/core/capture_route.dart` (D3 reads `captureOptions`'s order and labels but does not edit the file) — other clusters' territory.
  - `lib/features/entry_cards/playback/**` and every file named in N24 below — untouchable infrastructure, restated inline per the correction this slice makes to the parent's cross-reference-only treatment:

    | # | Test file | Cases |
    |---|---|---|
    | 1 | `test/features/entry_cards/playback/video_slots_test.dart` | 29 |
    | 2 | `test/features/entry_cards/cards/video_body_lifecycle_test.dart` | 20 |
    | 3 | `test/features/entry_cards/cards/video_controls_overlay_test.dart` | 18 |
    | 4 | `test/features/entry_cards/cards/video_body_test.dart` | 16 |
    | 5 | `test/features/entry_cards/cards/video_body_slots_test.dart` | 11 |
    | 6 | `test/features/entry_cards/cards/video_body_poster_gate_test.dart` | 7 |
    | 7 | `test/features/entry_cards/cards/video_body_attempt_identity_test.dart` | 4 |
    | 8 | `test/features/entry_cards/cards/video_scrubber_test.dart` | 1 |

    None of these eight files sit under `lib/features/today/` or `lib/design/`, and **no MSP in this run has a file-scope reason to open any of them.** Listing them by name here — not only by N-number in §2.5 — is deliberate: `video_body_test.dart` and its five `cards/`-directory siblings read as ordinary application files to an implementer who has not memorised N24, and Cluster D is confirmed to have zero exposure to any of them (path disjointness against every D1–D4 file list above). **If your diff touches one of these eight files, you have gone out of bounds — stop and report.**
- If decomposition suggests a unit outside D1–D4, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

### SERIALIZATION — read before planning parallelism

A file shared between two MSPs is a **hard dependency edge**, declared here, never left to a dependency graph to infer. Cluster D's source-file matrix has D1 colliding with all three other MSPs; re-verifying it against the current test suite surfaced that the **test files** shadow the same collisions, plus one the recon session did not enumerate.

| Shared file | Claimed by | Edge |
|---|---|---|
| `lib/features/today/this_week_garden.dart` | D1, D2 | **D1 -> D2** |
| `test/features/today/this_week_garden_test.dart` | D1, D2 | **D1 -> D2** |
| `lib/features/today/today_capture_buttons.dart` | D1, D3 | **D1 -> D3** |
| `test/features/today/today_capture_buttons_test.dart` | D1, D3 | **D1 -> D3** |
| `lib/features/today/on_this_day_card.dart` | D1, D4 | **D1 -> D4** |
| `test/features/today/on_this_day_card_test.dart` | D1, D4 | **D1 -> D4** |
| `test/features/today/today_screen_test.dart` | D1, D3, D4 | **D1 -> {D3, D4}**, plus a same-wave line-disjoint adjacency between D3 and D4 (see below) |

**No contract edges exist beyond the file-based ones above.** Unlike C5 -> C7 (a shared `MediaImage` API contract with no shared file), D2, D3 and D4 do not consume anything one of the others produces — each depends only on D1's restructured rail plus A1/A2 (both merged). This is stated explicitly because C's slice established the pattern of naming contract edges, and a reader should not have to conclude their absence by omission.

**`today_screen_test.dart` needs re-verification beyond what the recon session recorded.** Re-reading the file against this slice's base gives these exact lines, independent of the recon's approximate `:86-91` range:

| Line | Assertion | Broken by |
|---|---|---|
| `:87` | `expect(find.text('This week'), findsOneWidget)` | D1 (title becomes `this week's garden`) |
| `:88` | `expect(find.text('Quick capture'), findsOneWidget)` | D1 (title becomes `capture a moment`) |
| `:89` | `expect(find.text('Capture'), findsOneWidget)` | D3 (button removed — already declared in the parent) |
| `:90` | `expect(find.text('On this day'), findsOneWidget)` | D1 (title becomes `on this day`) |
| `:91` | `expect(find.text('1 year ago'), findsOneWidget)` | D4 (band caption becomes `memory · 1 year ago`) |

D1 lands first and fixes `:87`, `:88`, `:90` so the suite is green at its own merge point. D3 and D4 then both touch this same file in wave 2 — D3 at `:89`, D4 at `:91` — on disjoint lines with no functional dependency between them. This is the one place in the run where two wave-2 MSPs share a file; per the wave rule below, whichever of D3/D4 merges second must rebase onto the first's head and re-run `fullValidationCmd` before its own merge, exactly as C's wave 2 (C3/C5) and wave 3 (C7) required.

```
D1
 |
 +--> D2   (this_week_garden.dart + its test)
 |
 +--> D3   (today_capture_buttons.dart + its test; also
 |          today_screen_test.dart:89)
 |
 +--> D4   (on_this_day_card.dart + its test; also
            today_screen_test.dart:91 — line-adjacent to D3's :89,
            no functional dependency)
```

| Wave | MSPs | Justification |
|---|---|---|
| 1 | D1 | sole owner of the rail container; every other MSP's target surface is nested inside the sections D1 restructures, and D1 is the one that breaks the three title-copy assertions the other three MSPs' own test files carry |
| 2 | D2, D3, D4 | pairwise disjoint source files; each depends only on D1 (already in wave 1) plus A1/A2 (merged); the sole wave-2 contention is the line-disjoint adjacency in `today_screen_test.dart` noted above |

MSPs in the same wave may be planned and implemented concurrently. They must still **ship one at a time**: the repo squash-merges, so once the frontmost PR lands, `main` holds its content under a SHA absent from every sibling branch's history. Each remaining MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. **Never carry a green from one base to another.**

---

## 1. BLUF

Clusters A through C spent the prototype's vocabulary on the app's frame and its primary content surface. **Cluster D is the last cluster on the Today screen**, and the right rail is currently the least aligned part of it: every section is a heavy drop-shadowed card the prototype draws as a bare div, the week is a single 7-wide strip with no cell chrome at all, the capture stack has a fourth button the design does not have, and the on-this-day memory has no hatched band, no serif title and a bloom the design never puts on this card.

**Cluster D's share.** The rail is 34px too wide, has no left seam, and scrolls glued to the centre feed instead of independently (D1). Every day in the week grid is a bare `SizedBox` with no border, no background and no shadow — today, filled and empty days are visually indistinguishable except for a dashed circle painted in the wrong colour — and no cell is tappable (D2). The capture stack shows a primary `Capture` button that opens a chooser modal above three secondary, iconless, oversized buttons, where the design shows exactly three icon-led rows with `Write a note` carrying the coral emphasis (D3). The on-this-day memory sits inside a generic `StickerCard` with a 34px mood bloom, a year-bearing long date and a 2-line italic preview, where the design wants a cross-hatched thumbnail band captioned in tiny monospace, above a small serif title and a one-line micro-meta — no bloom at all (D4).

Unlike every prior cluster, **Cluster D touches no token file and adds no new primitive beyond one declared, additive constructor parameter.** Cluster A pre-provisioned every value D1–D4 need, and the recon that grounds this slice found zero citation errors in its own region. The work here is pure restyle plus one small, real behaviour change (D2's tap-to-Calendar) and one small, real formatter addition (D4's short-date function).

**Aligned means**: every value in the findings table below matches its cited prototype line; every capability in §2 still works and still passes its existing tests, retargeted where a restyle mandates it and unmodified everywhere else; and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set is reproduced below verbatim from the parent spec. Not every row is endangered by Cluster D; §2.7 names which are. The complete set is carried anyway for the same reason C's slice carried it: an implementer who encounters an app-only capability while restyling the rail must be able to tell "preserved by decision" from "leftover to clean up."

**Cluster D has zero exposure to N1–N10 and N24, confirmed by path disjointness.** No MSP in this run edits `lib/features/entry_cards/**` or any file named in the N24 table in §0's fence. N1–N10 and N24 are reproduced below for completeness, not because this run is at risk — the risk they guard against belongs to clusters that touch the playback stack directly (C7 already shipped that work).

### 2.1 Video playback stack

| # | Constraint | Citation |
|---|---|---|
| N1 | **LRU decoder-slot arbitration is untouchable infrastructure.** No alignment change may remove or bypass `VideoSlots` acquisition, the pin-while-playing rule, eviction handling, or the slot-freed wake path. Restyling stays strictly above this layer. | `lib/features/entry_cards/playback/video_slots.dart:11` (cap 6), `:19-32`, `:44-234`, `:79-92`, `:179-188`, `:190-216`; consumed at `lib/features/entry_cards/cards/video_body.dart:306-346`, `:428-437`, `:398-405` |
| N2 | **`VideoScrubber` stays the implementation.** Track, fill and handle may be restyled to prototype tokens. The tap-down seek, horizontal drag with preview, drag-cancel, the `_scrubberShortcuts` keyboard map with its 5-second step, the Semantics slider contract, and `ValueKey('video-scrub-bar')` all survive unchanged. Do not substitute a Material `Slider`. | `lib/features/entry_cards/cards/video_scrubber.dart:36-44`, `:12`, `:46-249`, `:120-146`, `:193-209`, `:251-310`; wired at `lib/features/entry_cards/cards/video_control_bar.dart:46-54` |
| N3 | **The transport keeps its two-state glyph.** Size, fill and border may move to prototype values. The `isPlaying`-driven bars-vs-triangle glyph, keyboard `ActivateIntent`, focus-highlight outline, disabled `Opacity(0.5)`, the `'Pause video'`/`'Play video'` Semantics pair, and `ValueKey('video-play-toggle')` remain. | `lib/features/entry_cards/cards/video_transport.dart:14-85`, `:118-146`, `:48-53`, `:7-9`, `:60`, `:57` |
| N4 | **The live elapsed/total readout stays two-valued and stays bound to the position stream.** A static total-only badge in the prototype's corner-pill style may be added *in addition to*, never as a replacement for, the control-bar readout. | `lib/features/entry_cards/cards/video_control_bar.dart:56-61`; fed by `lib/features/entry_cards/cards/video_body.dart:470-475`, `:206-213` |
| N5 | **Per-video mute is distinct from the global sound-effects setting; both exist.** Keep `VideoMuteToggle`, the volume-restore semantics, `ValueKey('video-mute-toggle')`, and the `'Mute video'`/`'Unmute video'` Semantics pair. | `lib/features/entry_cards/cards/video_control_bar.dart:71-141`, `:143-200`, `:110`, `:108`; logic at `lib/features/entry_cards/cards/video_body.dart:547-563`, `:503`, `:215-224` |
| N6 | **`VideoControlsOverlay` stays the container for transport and control bar.** The 3s hide delay, the macOS-pointer vs touch tap semantics, the focus-within and `accessibleNavigation` suppression rules, and `ValueKey('video-surface-tap')` are behavioural. Only opacity/fade styling and `videoControlInset` (8px) may be retuned. | `lib/features/entry_cards/cards/video_controls_overlay.dart:9`, `:12-17`, `:19-25`, `:33-218`, `:64-70`, `:138-157`, `:159-173`, `:186`, `:193-196` |
| N7 | **The five-phase load state machine and its timing constants are behaviour.** `CorruptMediaPlaceholder` and its Try again button must remain reachable from the unavailable phase for video, voice and photo. The spec defines a prototype-styled error state; it does not assume none is needed. | `lib/features/entry_cards/cards/video_body.dart:18-22`, `:27`, `:243-253`, `:255-262`, `:264-275`, `:372-379`, `:381`, `:646-652`; `lib/features/entry_cards/media/media_placeholders.dart:14-56`, `:58-124`, `:8` |
| N8 | **The slot-contention busy notice keeps its `liveRegion` semantics** and the busy hint stays on the transport. It may be restyled to a pill/toast treatment; it may not be silently removed or downgraded to a non-announcing visual. | `lib/features/entry_cards/cards/video_transport.dart:11-12`, `:87-116`; rendered at `lib/features/entry_cards/cards/video_body.dart:678-685`, `:693`, `:287-297` |
| N9 | **A video card at rest shows the captured poster frame when `thumbnailMediaId` exists**, with the hatched placeholder as fallback only. Preserve the three-layer order and the `_showCapturedPoster` gate. | `lib/features/entry_cards/cards/video_body.dart:505-513`, `:664-677`; `lib/features/entry_cards/media/media_image.dart:9-72` |
| N10 | **The video card's 21:9 / 200px-minimum envelope is a functional constraint, not a style value.** It may only be narrowed toward the prototype's proportions after verifying the scrubber row (48px), the mute target (48px) and the centred transport still fit without clipping. | `lib/features/entry_cards/cards/video_body.dart:23-24`, `:659-663`; `lib/features/entry_cards/cards/video_controls_overlay.dart:10`, `:203-208` |

### 2.2 Voice playback

| # | Constraint | Citation |
|---|---|---|
| N11 | Restyle the voice row to the prototype's 38px coral circle and waveform proportions, but keep the `isPlaying` state, the elapsed/total readout, the completion-resets-to-zero behaviour, the error placeholder, and `ValueKey('voice-play-toggle')`. | `lib/features/entry_cards/cards/voice_body.dart:203`, `:207`, `:213-214`, `:197`, `:157-161`, `:177`, `:235`, `:233` |

**Cluster D does not implement N11.** It is G8's, carried here only for recognition.

### 2.3 Capture

| # | Constraint | Citation |
|---|---|---|
| N12 | **`SettingsFieldRow` and `SettingsSelect` have a consumer outside `lib/features/settings` — the camera picker.** Any restyle of those primitives must keep them functional inside the recorder sheet. The remembered-device provider and the first-camera fallback are untouched. | `lib/features/capture/video/camera_picker.dart:8-52`, `lib/features/capture/video/camera_selection.dart:7-20`, `:22-28`; mounted at `lib/features/capture/video/video_recorder_sheet.dart:105`; primitives at `lib/design/settings_fields/settings_select.dart:46-63` |
| N13 | **The recorder's six-phase machine (preparing/idle/arming/recording/saving/denied), the 5/10/20-minute nudge schedule, and the 30:00 cap hint remain.** Copy and chrome may be restyled; the schedule, the cap and the denied stage may not be removed. | `lib/features/capture/video/video_timeline.dart:3-5`, `:9-40`; `lib/features/capture/video/video_recorder_sheet.dart:11`, `:32`, `:33`, `:204-206`, `:222-228` |
| N14 | **Armed-idle semantics hold**: opening the voice or video composer must never start recording. | `lib/features/capture/video/video_composer.dart:95`, `lib/features/capture/voice/voice_composer.dart:42` |

No MSP in this run touches the composers themselves. N12–N14 are carried for recognition; D3 reads only `captureOptions`'s order and labels from `capture_route.dart`, a file it does not edit.

### 2.4 Settings and data

| # | Constraint | Citation |
|---|---|---|
| N15 | The Sync & storage section is a **superset** of the prototype's four fields by design. **Recovery passphrase stays.** Align its row chrome to the prototype field pattern; do not delete the row. | `lib/features/settings/sections/sync_storage_section.dart:98-105` |
| N16 | **Keep the Pair a device row and its QR placeholder control.** It may be restyled into the prototype card treatment; it may not be dropped for lacking a prototype analogue. | `lib/features/settings/sections/sync_storage_section.dart:106-111`; `lib/features/settings/sync/pairing_qr_placeholder.dart` |
| N17 | The settings screen retains a host for `SettingsNotice` and its dismiss affordance. **Every settings action that can succeed or fail must still report its outcome** after the restyle. | `lib/features/settings/widgets/settings_notice.dart:5-30`, `:22` |
| N18 | **Delete all data stays gated behind `confirmDeleteAll` returning true.** The dialog chrome may be restyled; the confirmation step is non-negotiable. | `lib/features/settings/widgets/delete_all_dialog.dart:5-11`, `:14-45`; invoked at `lib/features/settings/sections/data_section.dart:46-50` |
| N19 | **Keep both export delivery strategies, the platform selector, and the delivered/dismissed outcome distinction.** Export feedback must continue to differentiate cancellation from error. | `lib/features/data/export_delivery.dart:9-21`, `:30-48`, `:50-71`, `:74-79`; `lib/features/data/export_runner.dart:5-21` |
| N20 | **All UI sound cues stay behind `GatedSoundService`** so the per-call enabled check and the error suppression remain in force. The nav-rail sound toggle and the Sound effects settings row drive the same gate. | `lib/features/sound/gated_sound_service.dart:9-31`, `:21-22`, `:26-28`; `lib/features/sound/sound_providers.dart` |

No MSP in this run touches settings or data. N15–N20 are carried for recognition only.

### 2.5 Accessibility, async states and the test contract

| # | Constraint | Citation |
|---|---|---|
| N21 | **Any change to garden motion routes through `resolveGardenMotionProfile`.** The OS `disableAnimations` signal and the bloom-count ceiling must both continue to force the reduced profile. | `lib/features/garden/model/garden_motion.dart:3`, `:6-12`; `lib/features/garden/widgets/garden_view.dart:43-47` |
| N22 | **Search keeps all three async branches** (loading, error, empty-journal). The empty-journal state adopts the prototype's dashed empty-state treatment rather than being removed. | `lib/features/search/search_screen.dart:30`, `:32`, `:34`, `:77-107`; `lib/features/search/search_filter.dart:3-14` |
| N23 | **Inline failure messaging survives** in the day-detail delete path and the note-editor save path. Adopt the prototype's edit/delete button styling and its note-only edit gate, but keep both messages reachable. | `lib/features/day_detail/day_detail_panel.dart:24`, `:53-65`, `:108-110`; `lib/features/day_detail/day_detail_edit_note.dart:12`, `:46-49` |
| N24 | **`ValueKey`s and Semantics labels are a public contract, not implementation detail.** May not be renamed. If a restyle breaks any of the 106 tests enumerated in §0's fence, the correct response is to fix the implementation — **never to delete or weaken the test.** | See the eight-file table in §0's HARD SCOPE FENCE |
| N25 | **Blooms keep their accessible labels** (Semantics image + mood/flower label) and picker tiles keep their button + selected semantics. No prototype counterpart; preserve. | `lib/design/flowers/flower_bloom.dart:35-37`; `lib/features/mood/mood_picker_grid.dart:57-60` |

### 2.6 Additive elements to preserve, not delete

These have no prototype counterpart. They are enrichments or real-hardware states. They are re-homed into prototype chrome, never removed.

| Element | Citation |
|---|---|
| `Palette.sunGlow = Color(0x8CF4C960)` garden sun glow | `lib/design/tokens/palette.dart:70` |
| Entry-card Edit/Delete actions where wired | `lib/features/entry_cards/entry_card.dart:65-77` |
| **On-this-day empty + error states** | `lib/features/today/on_this_day_card.dart:15-17`, `:36-40`, `:116-123` — directly endangered by this run; see D1 and D4 |
| Camera picker (multi-camera selection) | `lib/features/capture/video/camera_picker.dart:33-50` |
| Video permission/error/cap/nudge copy | `lib/features/capture/video/video_recorder_sheet.dart:29-33`, `:113-124` |
| `PhotoTray` / `PhotoThumbnail` (currently dead UI) | `lib/features/capture/photo/photo_tray.dart:9`, `:107-155` |
| **Chooser and its `'Coming soon'` state** — phone entry point only | `lib/features/capture/chooser/capture_chooser_sheet.dart:14`, `:81` — directly endangered by this run; see D3 |
| No grain/noise layer on either side | `grep -rni "grain\|noise\|turbulence" lib/` returns zero hits |

### 2.7 Preserve-to-MSP binding — the rows that bind THIS run

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| On-this-day empty + error states | **D1** (unwraps the section from its outer card), **D4** (rewrites the card) | D1's section-3 nuance + D4 "Must not regress" |
| Chooser + `'Coming soon'` (phone) | **D3** (removes the desktop `Capture` button; must not touch the chooser) | D3 reachability trace + `bottom_bar_shell_test.dart:52` as the standing proof |
| N25 bloom + tile semantics | **D2** (makes the week cell tappable) | D2 "Must not regress" |
| N24 keys, labels, 106 tests | nothing in this run — confirmed by path disjointness | §0's fence, §5.3 gate 2 |

---

## 3. Findings that Cluster D implements

Reproduced from the parent spec's §3.4. **Two cells are corrected**, marked inline — both describe the app's state *before* Cluster A merged and are stale in the parent's own text.

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Rail column | `width:266px; flex:none; overflow-y:auto; padding:24px 20px; border-left:1px dashed rgba(74,59,46,.22); display:flex; flex-direction:column; gap:18px`. Its own `.fn-scroll` column, scrolling independently inside a fixed body | `todayRailWidth = 300`; separated by `SizedBox(width: 24)`; no dashed left border, no rail-local padding. The whole screen is one `SingleChildScrollView` wrapping a `Row`, so the rail scrolls with the feed | medium | proto `:152`, `:87` / `lib/features/today/today_layout.dart:3`, `lib/features/today/today_screen.dart:74-87` |
| Section containers | Each of the three sections is a bare `<div>` with no background, border, radius, shadow or padding. Separation is by two `height:1px; background:rgba(74,59,46,.16)` hairlines and the column's 18px gap | Every section is wrapped in a `StickerCard`: `cardLight` `0xFFFFF5EA`, 1.5px ink outline, radius 16, `Shadows.card`, `EdgeInsets.all(16)`. Sections spaced by `SizedBox(height: 16)`; no separators at all | critical | proto `:153`, `:162`, `:163`, `:171`, `:172` / `lib/features/today/this_week_garden.dart:24`, `today_capture_buttons.dart:71`, `on_this_day_card.dart:94`, `today_right_rail.dart:18-28` |
| Section headers | Lowercase Caveat `600 17px` `#7d8450`: `this week's garden` (`margin-bottom:2px`), `capture a moment` (`margin-bottom:10px`), `on this day` (`margin-bottom:9px`) | **Correction**: the parent's cell here (`Title-case 'This week', 'Quick capture', 'On this day', all eyebrowAccent = Caveat 20 w600 sage`) describes the pre-Cluster-A state. Cluster A already migrated all three headers to `sectionHeaderAccent` (Caveat **17** w600 sage) — confirmed at `this_week_garden.dart:30`, `today_capture_buttons.dart:77`, `on_this_day_card.dart:100`. What remains wrong is **copy** (still title-case: `'This week'`, `'Quick capture'`, `'On this day'`) and **margin** (each followed by a flat `SizedBox(height: 10)`, not the per-section 2/10/9 the prototype specifies) | medium | proto `:154`, `:164`, `:173` / `this_week_garden.dart:14`, `:30`, `today_capture_buttons.dart:14`, `:77`, `on_this_day_card.dart:14`, `:100` |
| Week date range | Subtitle `{{ weekRange }}` e.g. `Jun 30 – Jul 6` (en dash U+2013, 3-letter months, no year) at `400 10px 'Instrument Sans'` `#a08a70` `margin-bottom:11px`, between header and grid | No date-range line; header goes straight to `SizedBox(height: 10)` and the day row | medium | proto `:155` / `lib/features/today/this_week_garden.dart:30-32` |
| Week grid | `display:grid; grid-template-columns:repeat(4,1fr); gap:8px` holding 7 cells — a ragged 4+3 block. Cell width = (266 - 40 - 24) / 4 = 50.5px | A single `Row` with `MainAxisAlignment.spaceBetween` containing all 7 cells — one 7-across strip | critical | proto `:156` / `lib/features/today/this_week_garden.dart:32-38` |
| Week cell chrome | Every day is a tile: `text-align:center; border-radius:10px; padding:6px 0 4px`. **Filled** `background:#f8efe0; border:1.5px solid #4a3b2e; box-shadow:1.5px 1.5px 0 rgba(74,59,46,.18)`. **Today** `background:#fff5ea; border:1.5px solid #c76a54; box-shadow:1.5px 1.5px 0 rgba(199,106,84,.3)`. **Empty** `background:transparent; border:1.5px dashed rgba(74,59,46,.35)`, no shadow, holding a 27x27 circle `border:1.5px dashed #c3b39a` | No cell container of any kind. Each day is a bare `Column` of `SizedBox.square(26)` + label. Filled paints `FlowerBloom.forMood(mood, size: 26)`; empty paints `DashedBorderPainter(color: Palette.placeholder 0xFFB3A58C, radius: 13)` — wrong dash colour, no tile | critical | proto `:1606`, `:1608-1610` / `lib/features/today/this_week_garden.dart:59-84`, `:15`, `:62-72` |
| Week cell label | `font:600 8px 'Instrument Sans'; margin-top:1px`; colour state-dependent — today `#c76a54`, has-bloom `#a08a70`, empty `#c3b39a` | `captionSans` (12 w400 muted) for all non-today; today overrides to coral + w700. Empty days share the has-bloom colour. Spacing above the label is `SizedBox(height: 6)` vs 1px | high | proto `:1611` / `lib/features/today/this_week_garden.dart:73-82` |
| Week cell interaction | Every cell carries `onClick -> this.setView('desktop','calendar')` and `cursor:pointer` | Cells are wrapped only in `Semantics`/`ExcludeSemantics`; no `GestureDetector`, no navigation | medium | proto `:1607` / `lib/features/today/this_week_garden.dart:54-58` |
| Capture stack | Exactly three rows in fixed order: `Write a note` (primary), `Record voice`, `Record video`. Primary `background:#c76a54; color:#fff; box-shadow:2px 2px 0 #4a3b2e`. Outlined rows `background:#f8efe0`, no shadow. Each `display:flex; align-items:center; gap:10px; border-radius:12px; padding:10px 13px` with a 17x17 stroked icon before the label — pencil stroked `#fff`, mic and video stroked `#4a3b2e`, stroke-width 2, round caps. Label `600 12px 'Instrument Sans'` | **Correction**: the parent's cell here (`All carry Shadows.button`) describes the pre-Cluster-A state, before the primary/secondary shadow split existed. Cluster A already split it (`sticker_button.dart:94-109`): the primary `Capture` button carries `Shadows.emphasis`; the three secondary route buttons carry **no shadow**. What remains wrong is that there are **four** buttons — a primary `'Capture'` chooser button, then the three per-type buttons all at `variant: secondary` — where the design has three, no icons are passed to any of them (the `icon` param exists on `StickerButton` since Cluster A but is unused here), and labels are `buttonSans` (15 w600, visibly larger than the target 12px) | high | proto `:165-168`, `:1595-1601` / `lib/features/today/today_capture_buttons.dart:71-88`, `lib/features/capture/core/capture_route.dart:21-36` |
| On-this-day card | Card `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:13px; overflow:hidden; box-shadow:2px 2px 0 rgba(74,59,46,.16)`, with the header outside it. An 82px band `repeating-linear-gradient(45deg,#e2d3ba,#e2d3ba 6px,#ecdfc8 6px,#ecdfc8 12px)` centring `memory · 1 year ago` at `500 7px ui-monospace,monospace` `#a08a70`. Text block `padding:9px 11px`: title `500 12px 'Newsreader'` `#4a3b2e`, meta `Jul 5, 2024 · felt warm` at `400 9px 'Instrument Sans'` `#a08a70` `margin-top:1px`. No glyph, no preview | No hatched band. A `Row` of an optional `FlowerBloom.forMood(mood, size: 34)` plus `yearsAgoLabel` in `labelSans`, `longDateLabel` (full weekday + year) in `captionSans`, and an optional 2-line italic preview capped at 90 chars — inside the generic `StickerCard` (radius 16, `Shadows.card`, padding 16), header inside the card | high | proto `:173-176` / `lib/features/today/on_this_day_card.dart:34-90`, `:93-106`, `lib/features/today/today_date.dart:53-55` |

---

## 4. MSP decomposition — Cluster D

**The governing invariant**: merging any MSP must leave the branch's app fully working. No MSP may depend on a surface a later MSP creates. Ordering is bottom-up, and within this cluster it is the wave order in §0.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster D is in this run.** C's slice dropped this table with no stated rationale; this slice restores it deliberately — Cluster D's file-overlap matrix collides D1 against all three siblings in a way that is easy to misread as "D1 depends only on A", and the eight-cluster context makes the run's place in the overall spec legible at a glance.

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged** |
| B | Window chrome and nav rail | B1 – B4 | **merged** |
| C | Today centre column | C1 – C7 | **merged** |
| D | Today right rail | D1 – D4 | **YES** |
| E | Flower art | E1 – E4 | no |
| F | Mood picker | F1 – F4 | no |
| G | Capture composers | G1 – G8 | no |
| H | Verification infrastructure | H1 | no |

Within Cluster D, dependencies are: D1 depends on A1 and A2 (both merged — an earlier draft's spurious dependency on B2 for `DashedDivider` overrides was removed, since those parameters already existed on the widget); D2, D3 and D4 each depend on A1, A2 and **D1**, plus their own cluster-A prerequisites (D3 additionally A4; D4 additionally A5). See §0's SERIALIZATION note — the D1-to-sibling edges are file-contention edges on both source and test files, not merely declared dependencies.

---

### D1 — Rail container: geometry, separators, bare sections

**Outcome**: the rail is three flat groups of content divided by thin rules, scrolling independently, behind a dashed seam.

**Files**: `lib/features/today/today_layout.dart`, `lib/features/today/today_screen.dart`, `lib/features/today/today_right_rail.dart`, `lib/features/today/this_week_garden.dart`, `lib/features/today/today_capture_buttons.dart`, `lib/features/today/on_this_day_card.dart`, `test/features/today/this_week_garden_test.dart`, `test/features/today/today_capture_buttons_test.dart`, `test/features/today/today_screen_test.dart`, `test/features/today/on_this_day_card_test.dart`

**Depends on**: A1, A2.

**Target values** (`:152`, `:153`, `:162`, `:163`, `:171`, `:172`)

```
rail width         266   (from todayRailWidth 300)
rail padding        24 vertical, 20 horizontal   (currently none; outer scroll applies all(24))
left seam           1px dashed Palette.ink22     (currently a bare SizedBox(width: 24) — see §0 resolution 1
                     for why this is a literal 1.0, never Shapes.outlineWidth)
column gap          18 between every rail child, including the two hairline children themselves
scroll               the rail is its own scrollable, independent of the centre feed
separators           two 1px solid Palette.ink16 hairlines, full rail content width,
                     between section 1|2 and 2|3 — not dashed, and not DashedDivider
section container    NO background, NO border, NO radius, NO shadow, NO padding
                     remove the StickerCard wrapper from sections 1 and 2 (`this_week_garden.dart:24`,
                     `today_capture_buttons.dart:71`) and from the OUTER wrapper of section 3
                     (`on_this_day_card.dart:94`).
                     Section 3 keeps an INNER card — see the nuance note below. Do not read this
                     line as "the on-this-day memory loses its card"; it does not.
```

Section headers move to lowercase copy with per-section bottom margins (the typography role, `sectionHeaderAccent`, is already correct and needs no change):

| Section | Copy | Margin-bottom | Citation |
|---|---|---|---|
| 1 | `this week's garden` | 2 | `:154` |
| 2 | `capture a moment` | 10 | `:164` |
| 3 | `on this day` | 9 | `:173` |

**The section-3 nuance, stated precisely.** Section 3 alone **does** have a card in the prototype (`:174`), but its header (`:173`) sits **outside** that card. The app currently nests the header inside one `StickerCard` that serves as both the section wrapper and the memory card (`on_this_day_card.dart:93-106`, the `_shell` helper). D1 splits them: the header moves out of the INNER memory card and becomes a bare section header like the other two, **still rendered inside the `OnThisDayCard` widget** — it does not migrate to `today_right_rail.dart`; the memory card remains as a card, keeping its current `StickerCard` styling until D4 retargets it to `radius 13 / cardWarm / cardDefault shadow / clipped band`. **All three branches keep the header**: populated (`on_this_day_card.dart:45`), empty (`:37`) and error (`OnThisDayRailCard`, `:117`) all route through the same static `_shell` (`:93-106`), so performing the split in `today_right_rail.dart` instead would silently strip the header from the error state. The receipt is D1's own retarget table below: `on_this_day_card_test.dart:29` and `:40` must still be `findsOneWidget` after retargeting to `'on this day'`, and both cases pump `OnThisDayCard` directly (`:20`, `:38`) — never the rail. **D1 merged alone must not leave the memory content unwrapped** — an on-this-day memory floating on the rail with no card is a visible bug.

Independent scroll: split the single `SingleChildScrollView` wrapping the `Row` (`today_screen.dart:74-87`) into two scrollables — one for the centre column, one for the rail.

**Must not regress**: the desktop-vs-phone split is correct — the rail renders only in the `withRail` layout and the phone layout has no rail (`today_layout.dart:5-11`, `today_screen.dart:67-89`). Keep it. The centre column's scroll position and the feed's 12px card spacing are unaffected. The on-this-day empty and error states (`on_this_day_card.dart:36-40`, `:116-123`) are a preserve item endangered by D1's unwrap — both must keep rendering inside whatever card shell D1 leaves in place, unchanged in content and reachability.

**Slice note — the four test files D1's copy change breaks, undeclared in the parent spec.** D1's title-copy change (title-case to lowercase) reddens an assertion in every one of the four test files below. None of the four is in D1's file list in the parent spec; this slice adds all four, since D1 is the MSP whose change actually breaks them, and D1 lands first (§0 SERIALIZATION).

| File | Line | Current assertion | Required retarget |
|---|---|---|---|
| `test/features/today/this_week_garden_test.dart` | `:37` | `expect(find.text('This week'), findsOneWidget)` | retarget the string to `"this week's garden"` |
| `test/features/today/today_capture_buttons_test.dart` | `:41` | `expect(find.text('Quick capture'), findsOneWidget)` | retarget the string to `'capture a moment'` — independently re-verified during this slice's composition; not named in the recon session's own collision list |
| `test/features/today/today_screen_test.dart` | `:87`, `:88`, `:90` | `'This week'`, `'Quick capture'`, `'On this day'` | retarget all three strings to their lowercase prototype copy |
| `test/features/today/on_this_day_card_test.dart` | `:29`, `:40` | `expect(find.text('On this day'), findsOneWidget)` (twice) | retarget both to `'on this day'` |

This retargeting is permitted under §5.2's rule: each of the above pins a rendering (a title string) that D1 is mandated to change, and the retarget keeps the same behavioural intent — "the section header renders" — while updating only the literal it matches. D3 and D4 separately touch some of these same files afterward for their own reasons; see the SERIALIZATION table in §0.

**Acceptance criteria**: the rail reads as three flat bands of content separated by thin ruled lines, not three heavy outlined drop-shadowed boxes. A dashed vertical seam divides it from the feed. Scrolling the entries leaves the week garden and capture buttons pinned in place.

---

### D2 — Week garden grid and cell chrome

**Outcome**: the week is a two-row 4+3 block of day tiles, each a real tile with a state-appropriate treatment, and tapping one opens the Calendar.

**Files**: `lib/features/today/this_week_garden.dart`, `lib/features/today/today_week.dart` (verify-only, see §0's carve-out), `test/features/today/this_week_garden_test.dart`

**Depends on**: A1, A2, D1

**Target values**

Grid (`:156`): `grid-template-columns: repeat(4, 1fr); gap: 8` holding 7 cells — a ragged 4+3 block (four cells in the top row, the remaining three plus one empty grid slot in the bottom row). Cell width derives to 50.5px at the 266px rail. Implement as two `Row`s of four and three, or a `GridView`/`Wrap` with a fixed 4-column constraint — **not** a single 7-across `Row`.

Date-range subtitle (`:155`), between the header and the grid: `Jun 30 – Jul 6` — en dash U+2013, 3-letter months, no year — in `caption10Sans` (Instrument Sans 10 w400 `#a08a70`), `margin-bottom: 11`.

Cell container, three states, all `text-align: center; border-radius: Shapes.radiusCell 10; padding: 6 top / 0 horizontal / 4 bottom`:

| State | Background | Border | Shadow | Citation |
|---|---|---|---|---|
| today | `Palette.cardLight` `#fff5ea` | `1.5px Palette.coral` | `Shadows.cellToday` `1.5px 1.5px 0 rgba(199,106,84,.3)` | `:1608` |
| filled | `Palette.cardWarm` `#f8efe0` | `1.5px Palette.ink` | `Shadows.cellFilled` `1.5px 1.5px 0 rgba(74,59,46,.18)` | `:1609` |
| empty | transparent | `1.5px DASHED Palette.ink35` | none | `:1610` |

Empty cells additionally hold a **27x27** circle bordered `1.5px dashed Palette.dashMuted` `#c3b39a` (`:1606`) — the current code uses `Palette.placeholder` `0xFFB3A58C`, which is wrong.

Glyph size **27** (from 26, `this_week_garden.dart:15`), matching the empty circle (`:1606`).

Label (`:1611`): `caption8Sans` — Instrument Sans **8** w600 — `margin-top: 1` (from `SizedBox(height: 6)`), with three colour states:

| State | Colour |
|---|---|
| today | `Palette.coral` `#c76a54` |
| has bloom | `Palette.muted` `#a08a70` |
| empty | `Palette.dashMuted` `#c3b39a` |

Interaction (`:1607`): every cell is tappable and navigates to the Calendar destination.

**Must not regress**: `today_week.dart` already produces seven days starting from the configured week start with an `isToday` flag (`daysPerWeek = 7` at `:7`, `weekDateKeys` at `:41-55`, `buildWeekCells` at `:57-76`) and 3-letter title-case weekday labels via `shortWeekdayLabel` (`today_date.dart:57-59`) — both correct against `:1403` and `:1611`. Do not change the week model. N25 — cells keep their existing `Semantics`/`ExcludeSemantics` treatment (`this_week_garden.dart:54-58`), extended with a `button: true` role now that they are tappable. That role must land on the **outer** `Semantics` widget, never inside the `ExcludeSemantics` subtree — `ExcludeSemantics` only strips the child's own semantics, so the outer widget's `button`/`onTap` properties are unaffected by it either way, but placing the new role on the wrong widget is the mistake this note exists to prevent.

**Acceptance criteria**: the week shows as a two-row block of four then three tiles, each with a visible cream card, outline and small offset shadow; today's tile is bordered terracotta with a coral-tinted shadow; empty days are a dashed outline holding a dashed circle, with their weekday label dimmed lighter than the days that have blooms. Labels are a small micro-caption sitting right under the bloom. Tapping any day opens the Calendar. **The tap navigation is a behaviour change and warrants a test.**

---

### D3 — Capture rail buttons

**Outcome**: three capture rows with icons, `Write a note` carrying the coral emphasis.

**Files**: `lib/features/today/today_capture_buttons.dart`, `lib/design/widgets/sticker_button.dart`, new `lib/design/icons/capture_icons.dart`, `test/features/today/today_capture_buttons_test.dart`, `test/features/today/today_screen_test.dart`, `integration_test/capture_ui_flow_test.dart`

**Depends on**: A1, A2, A4, D1

**Decision context — OQ-4 resolved to (a) on 2026-07-27, and implemented in final form here** (the parent spec's earlier draft shipped only an interim state with the button demoted, not removed). Reachability was verified before accepting: `AppShell._openCapture` (`lib/app/shell/app_shell.dart:34-36`) is bound to `onCapture` (`:51`) and passed into `BottomBarShell` (`:70`), which wires it to the phone centre tab at `bottom_bar_shell.dart:116`. The chooser therefore survives the desktop button's removal, and `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof — see §0's verify-only consumers, including the correction to the parent's stale line numbers for this trace.

**Target values** (`:165-168`, `:1595-1601`)

Exactly **three** rows in fixed order, **8px** apart (`:165`, `display:flex;flex-direction:column;gap:8px`). *An earlier draft said 9px; that is the chooser's row gap at `:752`, not the rail's.*

| Row | Variant | Icon | Icon stroke |
|---|---|---|---|
| `Write a note` | **primary** — `#c76a54` fill, `#fff` text, `Shadows.emphasis` `2px 2px 0 #4a3b2e` | pencil | `#fff` |
| `Record voice` | secondary — `#f8efe0` fill, `#4a3b2e` text, **no shadow** | mic | `#4a3b2e` |
| `Record video` | secondary | video camera | `#4a3b2e` |

Icons are 17x17, stroke-width 2, round caps. Geometry per row: `borderRadius: Shapes.radiusControl 12; padding: 10 vertical / 13 horizontal; gap: 10` — the gap is **already correct and needs no change**: `_iconGap` is declared `10` at `lib/design/widgets/sticker_button.dart:16` and applied at `:60`, so D3 states it as a target only to record that it matches, exactly as D1 handled the already-correct header typography role. Label `captureLabelSans` — Instrument Sans **12** w600 — coloured per variant, via the new `labelStyle` parameter (§0 resolution 5).

**Glyph geometry, verbatim from the prototype's `ICONS` map.** D3 authors `capture_icons.dart` wholesale, so the paths are given here rather than left to invention — the parent spec carried only the pencil (`docs/specs/2026-07-26-prototype-design-alignment.md:1054`) and this slice restores all three:

| Glyph | Citation | Path data |
|---|---|---|
| pencil | `:1223` | `M4 17l8-11 8 11` plus `M6 20h12` |
| mic | `:1224` | `rect x=9 y=3 w=6 h=12 rx=3` plus `M6 11a6 6 0 0 0 12 0M12 17v4` |
| video | `:1225` | `rect x=3 y=6 w=13 h=12 rx=2` plus `M16 10l5-3v10l-5-3` |

All three paths are authored in a **24x24 coordinate space** (`:1247`, `viewBox:'0 0 24 24'`) but render into the 17px box above, so a **24-to-17 scale (17/24) is mandatory** — the glyphs are not authored at their render size and will overflow the row if drawn 1:1. Paint with `style: PaintingStyle.stroke`, `strokeWidth: 2`, `StrokeCap.round`, `StrokeJoin.round` (`:1249`), and `fill: none` (`:1248`).

**D3 preserves the registry-driven `orderedRoutes` construction (`today_capture_buttons.dart:62-68`) unchanged.** "Exactly three rows" describes the **production registry**, in which all three of `captureOptions`' types are registered; the rail renders one row per **REGISTERED** type and no more. The `primary` variant binds to the `EntryType.text` row specifically, **not** to "the first row".
**Receipt**: `test/features/today/today_capture_buttons_test.dart`, `'renders a direct button only for registered capture types'` (:53-73), asserts `find.text('Record voice')` and `find.text('Record video')` are `findsNothing` at `:66-67` when only the text route is registered — it must stay green **unmodified**. Hardcoding three rows to satisfy the "exactly three" language reddens it immediately.

Left-aligned content (`MainAxisAlignment.start`) so the icon leads the label, matching `display:flex; align-items:center`. `StickerButton`'s current `Row(mainAxisSize: MainAxisSize.min, ...)` inside an un-centred `Padding` already renders left-aligned by construction (`sticker_button.dart:53-69`); no layout change is required for this property, only the icon and label-style wiring.

**Remove the desktop `Capture` button.** Delete `StickerButton(label: 'Capture', onPressed: _openChooser)` (`today_capture_buttons.dart:79`) and the now-unreferenced `_openChooser` handler (`:42-49`). It is the fourth button that makes the rail read as four rows where the design has three, and it currently absorbs the coral emphasis that `:1598` gives to `Write a note`.

**The chooser itself is NOT deleted, and this MSP must not touch it.** `today_capture_buttons.dart` is the only mount point in `lib/` that this MSP removes, and it is not the phone path. `CaptureChooserSheet`, `capture_chooser_sheet.dart` and the chooser's `'Coming soon'` state all survive untouched as the phone entry point (preserve item, §2.6).

**Three test files carry four rows that go red with the button and must change in this MSP** — omitting any of them is an MSP-shippability failure. A fifth row follows the four: it is the inverse, a case that must stay green **unmodified**.

| File | Line | Current | Required change |
|---|---|---|---|
| `test/features/today/today_capture_buttons_test.dart` | `:29-51` | the whole first test case, `'the primary button opens the chooser and runs the chosen route'`, taps `find.text('Capture')` at `:43` and asserts the chooser's own title `'Capture a moment'` at `:45` | delete this case — it exists solely to exercise the desktop button's chooser round-trip, which no longer exists. **Note**: line `:45`'s `'Capture a moment'` (title-case, the chooser sheet's own heading) is a different string from D1's lowercase `'capture a moment'` rail-section header; the two are not the same collision |
| `test/features/today/today_screen_test.dart` | `:89` | `expect(find.text('Capture'), findsOneWidget)` | assert **three** capture rows and no `Capture` button |
| `integration_test/capture_ui_flow_test.dart` | `:53-67` (helper `_openChooserAndPick`), called at `:87`, `:121`, `:154`, `:196` | taps `find.text('Capture')` at `:54`, asserts `find.byType(CaptureChooserSheet)` at `:57`, and scopes the option tap via `find.descendant(of: find.byType(CaptureChooserSheet), ...)` at `:60-63` | rewrite the helper into a direct-row helper that taps `find.text(optionLabel)` on the rail; DELETE the `CaptureChooserSheet` assertion at `:57` and the `find.descendant` scoping. All four call sites keep their existing parameter values (`Write a note`, `Record voice`, `Record video`) unchanged — the desktop rail now exposes all three labels directly. **The one-line framing this row previously carried ("drive the flow through `Write a note`") was wrong for three of the four flows**: after D3 removes the desktop `Capture` button there is no chooser on the desktop rail, so `:57` and the descendant scoping go red in **all four** flows, and the voice and video flows must tap their own row labels, not `Write a note` |
| `test/features/today/today_capture_buttons_test.dart` | `:41` | `expect(find.text('Quick capture'), findsOneWidget)` | already retargeted by D1 (§0 SERIALIZATION); D3 lands after D1 and inherits the fixed string when it deletes the surrounding test case above |
| `test/features/today/today_capture_buttons_test.dart` | `:53-73` | `'renders a direct button only for registered capture types'` — asserts `find.text('Record voice')` / `find.text('Record video')` are `findsNothing` at `:66-67` when only the text route is registered | **must stay green, UNMODIFIED.** This is the receipt for the registry ruling in D3's target block above; hardcoding three rows reddens it. If the per-widget pin on the rail's section-header copy is wanted after `:29-51` is deleted, move it into **this** surviving case rather than dropping it — `today_screen_test.dart:88` (retargeted by D1) still covers that copy suite-wide either way, so nothing is lost if it is not moved |

`test/app/shell/bottom_bar_shell_test.dart:52` (`'the center capture invokes onCapture'`) covers the **phone** path, asserts through `ValueKey('capture-button')` rather than button text, and must stay green **unchanged** — if it fails, the chooser was wrongly touched.

**Must not regress**: the three route labels and their order are exact against `:1598-1600` and stay (`capture_route.dart:21-36`). The chooser and its `'Coming soon'` state (§2.6) survive on phone, per the reachability trace above.

**Acceptance criteria**: the rail shows **exactly three** capture rows. `Write a note` is a terracotta button with white text, a white pencil icon and a hard ink shadow. `Record voice` and `Record video` are warm cream, shadowless, with ink-stroked mic and video icons. All three labels are visibly smaller than before. On phone, the centre tab still opens the chooser.

---

### D4 — On this day card

**Outcome**: the memory is a hatched thumbnail band above a small serif title and micro-meta line.

**Files**: `lib/features/today/on_this_day_card.dart`, `lib/features/today/today_memory.dart`, `lib/features/today/today_date.dart`, `test/features/today/today_screen_test.dart`, `test/features/today/on_this_day_card_test.dart`, `test/features/today/today_date_test.dart`

**Depends on**: A1, A2, A5, D1

**Target values** (`:174-176`)

```
card           background Palette.cardWarm #f8efe0
               border 1.5px Palette.ink
               borderRadius Shapes.radiusPill 13   (from 16 — see §0 resolution 3 for the naming oddity)
               clipBehavior hardEdge  (overflow:hidden — the band bleeds to the card edge)
               boxShadow Shadows.cardDefault  2px 2px 0 rgba(74,59,46,.16)
               NO padding on the card itself
band           height 82, CrossHatchPlaceholder variant photo
               #e2d3ba / #ecdfc8 at 6px / 12px pitch — the DEFAULT for CrossHatchVariant.photo;
               pass NO hatchColor override (§0 resolution 2)
               centring 'memory · {N} year{s} ago' in monoMicroSans
               monospace 7 w500 #a08a70
text block     padding 9 vertical / 11 horizontal
title          the entry's preview text, repurposed into memoryTitleSerif  Newsreader 12 w500 ink
               (§0 resolution 4 — the 2-line italic preview is restyled, not deleted)
meta           '{Mon D, YYYY} · felt {mood}' in caption9Sans
               Instrument Sans 9 w400 #a08a70, margin-top 1
```

The meta date is a **new short form**, `Jul 5, 2024` — 3-letter month, day, year, no weekday — distinct from both `headerDateLabel` (`Sunday, July 5`, no year) and `longDateLabel` (`Sunday, July 5, 2024`, both already in `today_date.dart:46-55`). `longDateLabel` has exactly one production consumer today, this same file (`on_this_day_card.dart:71`), so D4 is free to stop calling it here and add a new `shortDateLabel`-shaped function in `today_date.dart` without any shared-consumer hazard — unlike C2's `headerDateLabel` addition, which had to coexist with `longDateLabel`'s other caller. **`longDateLabel` is not deleted, and its own test group at `test/features/today/today_date_test.dart:26-32` stays green UNMODIFIED** — D4 stops *calling* the function, it does not remove it, so that group keeps passing untouched. D4's one additive case in this same file (§5.2) covers the new short-date formatter only. The 34px mood bloom is removed from the populated state entirely; the flower is represented by the `felt {mood}` phrase instead.

**Must not regress**: the additive empty and error states (`on_this_day_card.dart:36-40`, `:116-123`) are preserve items with no prototype counterpart. They stay. Restyle them to sit in the same card shell: the empty state keeps its dashed placeholder with copy `No memory from this day in past years yet.`, and the error state keeps `Couldn't load your past-year memory.` in `Palette.danger`. Both must remain reachable.

**Slice note — the test-file changes this MSP owes, independently re-verified against the base and more precise than the recon session's approximate line ranges.**

| File | Line | Current assertion | Required change |
|---|---|---|---|
| `test/features/today/on_this_day_card_test.dart` | `:30` | `expect(find.text('2 years ago'), findsOneWidget)` | retarget to the combined band caption, e.g. `find.textContaining('2 years ago')` matching `'memory · 2 years ago'` |
| `test/features/today/on_this_day_card_test.dart` | `:31` | `expect(find.text('Friday, July 19, 2024'), findsOneWidget)` | retarget to the new short form, `'Jul 19, 2024 · felt Calm'` (or an equivalent partial match on the meta line) |
| `test/features/today/on_this_day_card_test.dart` | `:33` | `expect(find.byType(FlowerBloom), findsOneWidget)` | retarget to `findsNothing` — the populated state no longer renders a bloom |
| `test/features/today/on_this_day_card_test.dart` | `:68`, `:100` | `expect(find.text('1 year ago'), findsOneWidget)` (twice, in the `OnThisDayRailCard` connector tests) | retarget both to the combined band caption |
| `test/features/today/today_screen_test.dart` | `:91` | `expect(find.text('1 year ago'), findsOneWidget)` | retarget to the combined band caption; D4 lands after D1, which has already fixed `:87`, `:88`, `:90` in this same file |

Line `:32`'s `expect(find.text('sun on the deck'), findsOneWidget)` and lines `:42-45`'s empty-state and `:103-119`'s error-state assertions are **not** in this table — they stay green unmodified under §0 resolution 4's repurposing and the preserve-item restyle above, respectively.

**Acceptance criteria**: the memory renders as a cross-hatched band captioned `memory · 1 year ago` in tiny monospace, above a small serif title (the repurposed preview text) and a `Jul 5, 2024 · felt warm` micro-line. The section header sits outside and above the card. On a day with no past-year memory, the dashed empty box still appears.

---

## 5. Verification strategy

### 5.1 What the repo actually has

No golden/screenshot coverage exists. H1 builds it and is **not** dispatched in this run. The automated safety net for Cluster D is therefore the existing widget and unit suite — none of which is the 106-case playback suite this time, since Cluster D has zero exposure to it.

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract.

In this cluster that yields exactly **two** new tests:

| MSP | Test | Why it qualifies |
|---|---|---|
| D2 | New case in `test/features/today/this_week_garden_test.dart` | Behaviour: tapping a week cell now navigates to the Calendar. No cell is tappable today (`Semantics`/`ExcludeSemantics` only, no `GestureDetector`) — this is new behaviour, not a restyle |
| D4 | New case in `test/features/today/today_date_test.dart` | Contract: a new short-date formatter (`'Jul 5, 2024'`) is added to `today_date.dart`. It is additive and does not replace `headerDateLabel` or `longDateLabel`, but it is a new public function and clears the admission gate on that basis |

**Every other change in this run is a restyle, and Cluster D has more restyle-vs-existing-test collisions than any prior cluster** — four test files carry assertions on copy or structure that D1's, D3's or D4's target values directly contradict, enumerated at their point of use in each MSP's body above and consolidated in §0's SERIALIZATION table.

Per `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, **an MSP MAY retarget an existing assertion that pins a rendering it is mandated to change.** Retargeting means updating the literal string or finder inside an existing test so it matches the new target value, while preserving the test's behavioural intent — "the section header renders," "the memory's timeframe is announced," "the capture rail exposes exactly N controls." It is **not** deleting the test, and it is not the same operation as adding a new one; the test admission gate does not apply to it, because no new behaviour is being asserted. This is a correction to this document's own template: the C slice's §5.2 said existing tests must pass "unmodified" and never mentioned retargeting, which contradicts the ledger ruling above and is not carried forward here.

**The hard boundary on this permission is N24.** Retargeting never touches a `ValueKey`, a Semantics label, or any of the eight files enumerated in §0's HARD SCOPE FENCE, under any circumstances — no restyle, however well-motivated, licenses touching them. Cluster D has zero exposure to those eight files by path disjointness, so this boundary is not expected to be tested by this run, but it is stated here as the rule that would apply if that ever changed.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **106 playback tests run unmodified and pass.** This is N24. In this run it is **background**, not acute — no MSP in Cluster D edits any file in the eight-file table in §0, confirmed by path disjointness (the same posture Cluster B held for N1–N10). It still runs before every merge; a diff in that suite from a Cluster D change would itself be the signal that the fence has been breached.
3. The four `integration_test/` flows pass, including `capture_ui_flow_test.dart`, which D3 directly modifies.
4. Diff-scoped verification via the project's verify command; the full suite runs at the cluster boundary and pre-push, not per change.

**CI is not evidence.** Neither GitHub check runs a Dart test: the receipts workflow is node-only and the D6 check has no Dart import grapher and passes vacuously. `receiptsPass` / `d6Pass` are never acceptable as proof that this run is green. Run `fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge.

Baseline at the head of this slice's branch: **904 tests passing, 0 failing, `flutter analyze` clean.**

### 5.4 Manual spot-check

The right rail is a composite of three independently-scrolling sections, so the manual pass is load-bearing for the seams between them. Required human pass at the cluster boundary, on macOS via `flutter run -d macos` — never the standalone binary, which renders a black window:

- **Rail geometry** — the rail is visibly narrower (266px), has a dashed left seam, and scrolls independently of the feed below it.
- **Section headers** — lowercase handwritten copy at three different bottom margins, with thin solid hairlines (not dashed) between sections instead of card outlines.
- **Week grid** — a 4-then-3 block of tiles; today bordered terracotta with a coral-tinted shadow, filled days cream with an ink border and offset shadow, empty days a dashed outline holding a dashed circle. Tapping any day opens the Calendar.
- **Capture rail** — exactly three rows: a terracotta `Write a note` with a white pencil icon and hard shadow, then two shadowless cream rows with mic and video icons. No fourth `Capture` button.
- **On-this-day card** — a cross-hatched band captioned in tiny monospace, above a small serif title and a one-line micro-meta with no mood bloom. Check both a day **with** a past-year memory and a day **without** one (dashed empty box, unchanged copy).
- **Phone layout** — confirm the phone (stacked) Today screen has no rail at all, and its centre capture tab still opens the chooser.
- **Regression sweep** — the centre feed (Cluster C's territory) is visually unchanged by this run; only the rail moved.

### 5.5 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation.

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

The parent spec's §6.1 table lists the prototype elements deliberately excluded from alignment. All remain excluded. Two are reachable-looking from Cluster D and must be handled explicitly:

- **The right rail itself was named as excluded territory in Cluster B's own §6.1** (`docs/specs/2026-07-27-prototype-alignment-cluster-b.md:435`: "The right rail (D1–D4) including the on-this-day card... C2 and C6 both touch code the rail consumes... and must leave its rendering unchanged.") That deferral closes with this run.
- **D2 navigates to the Calendar screen; it does not restyle it.** The Calendar screen's own alignment remains excluded per the parent's §6.1 ("Calendar, Garden, Search and Day Detail screens... Out of scope for this spec beyond the token and flower changes that reach them transitively"). Tapping a week cell opening an unaligned Calendar is the correct, expected outcome of this run.
- **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model) remain open and touch no MSP in this run.

### 6.2 Explicitly not a task

- **No grain or noise overlay.** Neither side has one.
- **No `flutter_svg` / `vector_graphics` dependency.** D3's pencil/mic/video glyphs are hand-drawn `CustomPainter` paths in a new `capture_icons.dart`, matching the pattern already established by `nav_icons.dart` and `flame_icon.dart` — not imported assets.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants.
- **No `FontVariation('wght', …)` calls.** Bind by `fontFamily` string plus explicit `FontWeight`.
- **No deletion or weakening of the 106 playback tests** under any circumstances (N24) — inapplicable in practice to this run, stated for consistency with every prior slice.
- **No renames, removals or additions in the token layer.** It closed with Cluster A. See §0.
- **No extension of `CrossHatchVariant`, no new hatch painter, no `hatchColor` override for D4.** See §0 resolution 2.
- **No rename of `Shapes.radiusPill`, no same-valued alias.** See §0 resolution 3.
- **No change to `StickerButton`'s default label style.** Only the additive, default-`null` `labelStyle` parameter. See §0 resolution 5.
- **No extension of `NavGlyph` (`nav_icons.dart`) and no edit to `flame_icon.dart`** to accommodate D3's capture icons. A new file is the correct shape.
- **No change to `lib/app/shell/**`.** Cluster B closed it; D3 only reads two of its files as verify-only consumers.

### 6.3 Open questions

**OQ-4 is fully resolved and implemented in this run.** D3 ships the button removal in its final form, not the interim placement an earlier parent draft described — three test files change with it, enumerated in D3's body above.

Still open, touching no MSP in this run: **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model).

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Zero citation errors were found in Cluster D's own region.** Every line D1–D4 cite in `docs/prototype/project/Field Notes.dc.html` — `:152-176` (rail geometry and section headers), `:1595-1601` (capture button base and route icons), `:1606-1611` (week cell geometry, colours and label states) — was independently re-opened and confirmed byte-identical while composing this slice, corroborating the dedicated recon session (`.claude/ledger/sessions/2026-07-29-02-prototype-design-alignment.md`), which made the same claim before this document existed. This is the **second** cluster, after C's own `:127-129` -> `:128-130` self-correction, to close verification with zero errors against its own cited region. **The parent spec's running count of wrong-line-number citations stays at three** — `ink08`/`ink12`, `Shadows.chip`, and the phone mood-picker sheet, none of which Cluster D cites — unchanged by this slice.

**A separate, different kind of staleness was found and corrected: in-repo line-number drift, not a prototype citation error.** The parent spec's D3 body cites `app_shell.dart:41` and `:30-32` for the phone capture-chooser's reachability trace. Those lines have moved since Clusters A–C merged; the current lines are `:34-36` (`_openCapture`), `:51` (`onCapture` wiring) and `:70` (passed into `BottomBarShell`) — re-verified directly against this slice's base and corrected in D3's "Decision context" above and in §0's verify-only consumers list. `bottom_bar_shell.dart:116`, the other half of that trace, had not drifted and is unchanged.

**Rule for implementers:** re-open every cited line — both in the prototype HTML and in the app's own source — before adopting any value. This spec family has now been wrong about prototype line numbers three times and, as of this slice, wrong about at least one in-repo line number once; treat every citation as a pointer to verify, not as an authority.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
