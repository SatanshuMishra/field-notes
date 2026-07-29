# Prototype Design Alignment — Cluster C (Today centre column) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **C — Today centre column**
MSPs: **C1, C2, C3, C4, C5, C6, C7**
Base: `main` at `f804e97`
Citation source: `docs/prototype/project/Field Notes.dc.html`

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec.** Where this document reproduces parent text, it reproduces it verbatim. Where a reader needs material this slice omits — findings §3.1, §3.2 and §3.4–§3.7, MSPs A1–B4 and D1–H1, the excluded-elements table §6.1 — the parent spec on main is the authority.

**Clusters A and B are already merged and are this run's base.** A1–A5 shipped as PRs #51/#53/#54/#55/#56; B1–B4 shipped as PRs #62/#63/#64/#65. The §5.4 macOS visual pass for Cluster B was run by the product owner on 2026-07-28 and passed, which is the gate that releases this cluster.

Every token, typography role and primitive that C1–C7 consume was confirmed present on this base, at value, before this slice was cut:

| Token | path:line | Value | Consumed by |
|---|---|---|---|
| `Palette.cardLight` | `lib/design/tokens/palette.dart:13` | `0xFFFFF5EA` | C1 |
| `Palette.cardWarm` | `palette.dart:12` | `0xFFF8EFE0` | C2, C3, C5 |
| `Palette.ink` | `palette.dart:17` | `0xFF4A3B2E` | C1, C2, C3, C5, C7 |
| `Palette.coral` | `palette.dart:31` | `0xFFC76A54` | C1, C2, C3, C4 |
| `Palette.coral12` | `palette.dart:34` | `0x1FC76A54` | C4 |
| `Palette.ink25` | `palette.dart:26` | `0x404A3B2E` | C5 |
| `Palette.ink40` | `palette.dart:29` | `0x664A3B2E` | C6 |
| `Palette.onAccent` | `palette.dart:47` | `0xFFFFFFFF` | C3 |
| `Palette.mutedDeep` | `palette.dart:40` | `0xFF8A7358` | C5 |
| `Shapes.radiusMd` | `lib/design/tokens/shapes.dart:15` | `14` | C1, C5 |
| `Shapes.radiusLg` | `shapes.dart:16` | `16` | C6 |
| `Shapes.radiusPill` | `shapes.dart:14` | `13` | C2, C3 |
| `Shapes.radiusThumb` | `shapes.dart:10` | `9` | C5 |
| `Shapes.radiusIconButton` | `shapes.dart:9` | `8` | C4 |
| `Shadows.emphasis` | `lib/design/tokens/shadows.dart:51-58` | ink opaque, offset (2,2), blur 0 | C1 |
| `Shadows.hero` | `shadows.dart:78-85` | `ink20` `0x334A3B2E`, offset (3,3), blur 0 | C2 |
| `Shadows.heroSoft` | `shadows.dart:87-94` | `0x244A3B2E`, offset (3,3), blur 0 | C3 |
| `Shadows.cardDefault` | `shadows.dart:42-49` | `ink16` `0x294A3B2E`, offset (2,2), blur 0 | C5 |
| `Type.streakAccent` | `lib/design/tokens/typography.dart:103-109` | Caveat 24 w700 h1.0 coral | C1 |
| `Type.caption10Sans` | `typography.dart:208-213` | Instrument Sans 10 w400 muted | C1 |
| `Type.pageEyebrowAccent` | `typography.dart:118-123` | Caveat 16 w600 coral | C2 |
| `Type.displaySerifToday` | `typography.dart:11-17` | Newsreader 34 w500 h1.0 ink | C2 |
| `Type.bannerSerif` | `typography.dart:42-47` | Newsreader 19 w500 ink | C2, C3 |
| `Type.captionSans` | `typography.dart:188-193` | Instrument Sans 12 w400 muted | C2, C6 |
| `Type.caption11Sans` | `typography.dart:201-206` | Instrument Sans 11 w600 coral | C2, C3 |
| `Type.promptAccent` | `typography.dart:153-158` | Caveat 13 w600 muted | C3 |
| `Type.sectionHeaderAccent` | `typography.dart:111-116` | Caveat 17 w600 sage | C4 |
| `Type.stampAccent` | `typography.dart:146-151` | Caveat 13 w600 sage | C4 |
| `Type.chipMicroSans` | `typography.dart:242-248` | Instrument Sans 8 w500, `letterSpacing: 0.64` | C4 |
| `Type.bodySerif` | `typography.dart:63-69` | Newsreader 13.5 w400 h1.5 ink | C5 |
| `Type.sectionSerif` | `typography.dart:56-61` | Newsreader 17 w500 ink | C6 |
| `Type.monoThumbSans` | `typography.dart:257-262` | monospace 6 w500 mutedDeep | C5 |

`chipMicroSans.letterSpacing` is stored as the absolute `0.64`, which is the prototype's `.08em` resolved at the role's own 8px size. It is correct as stored. Do not "fix" it to an em value; Flutter has no em unit for `letterSpacing`.

**No MSP in this run may add, rename or remove a token.** If a value appears to be missing, re-read the token file before concluding it is absent; if it is genuinely absent, stop and report rather than adding it — the token layer closed with Cluster A.

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Four primitives this cluster consumes do not express the required treatment through their current API. Each is resolved here so that seven implementers do not each invent a different answer.

1. **`CrossHatchPlaceholder` needs no change for C7.** Its band geometry is hardcoded per variant (`lib/design/widgets/cross_hatch_placeholder.dart:27-44`) and the rotation is a fixed 45° (`:136`). The `video` variant is **6px band / 12px pitch**, which is exactly the prototype's `repeating-linear-gradient(45deg, #d9c9ae, #d9c9ae 6px, #e2d3ba 6px, #e2d3ba 12px)` at `:128`. C7 therefore uses `CrossHatchVariant.video` and supplies only the two colour overrides (`background`, `hatchColor`), both of which are already optional constructor params. **Extending `CrossHatchVariant` or adding geometry params is out of scope and is a defect if proposed.**

2. **`FlowerBloom` has no `opacity` parameter** (`lib/design/flowers/flower_bloom.dart:8-14`). C3's 46px ghost bloom is produced by wrapping `FlowerBloom(kind: ..., size: 46)` in an `Opacity(opacity: 0.5, ...)` **at the C3 call site**. Do not add an `opacity` param to the primitive. `Opacity` does not strip the subtree's semantics, so the N25 accessible label survives the wrap — which is the point of C3's "must not regress" bullet.

3. **`EmptyStatePlaceholder`'s `padding` and `borderColor` are existing parameters with defaults** (`lib/design/feedback/empty_state.dart:7-16`) and it has **nine** call sites: `day_detail_panel.dart:132`, `calendar_screen.dart:115`, `on_this_day_card.dart:39`, `today_entry_feed.dart:48`, `garden_screen.dart:55`, `garden_view.dart:33`, and `search_screen.dart:54`, `:85`, `:116`. **C6 must apply its new padding, border colour and radius at the Today call site**, not by changing the widget's defaults — changing a default silently restyles Calendar, Garden, Search and Day Detail, none of which this run aligns. The new `headline` slot and any new `borderRadius` parameter must default to today's rendering so all eight other consumers are byte-identical after C6. This is the same opt-in rule C5 carries for `MediaImage`, and for the same reason.

4. **`IconStickerGlyph` currently has only `{ gear, soundOn, soundOff }`** (`lib/design/widgets/icon_sticker_button.dart:5`). C4's interim Edit/Delete treatment consumes `IconStickerButton`, so C4 **extends that enum with `edit` and `trash` cases and their painter paths**, and `lib/design/widgets/icon_sticker_button.dart` is therefore inside C4's file scope. This is a primitive extension, not a token change, and it is additive — the three existing cases and every B4 call site are untouched. The parent spec's stated fallback (ship the pair as unstyled `StickerButton(secondary)`) was conditioned on Cluster B not yet being merged; B4 **is** merged, so the primary path applies.

5. **`StickerCard` is a shared surface used by C1, C2 and C5, and it is not in any MSP's file list — deliberately.** `StreakCard`, `MoodBanner`'s set state and `EntryCard` all wrap it. Its `surface`, `borderRadius`, `shadow` and `padding` are constructor parameters and are overridden **at the call site**; its **`border` is hardcoded to `Shapes.outline`** (`lib/design/widgets/sticker_card.dart:30`) and is not overridable per instance. That hardcoded border is `BorderSide(color: Palette.ink, width: 1.5)`, which is exactly what C1, C2 and C5 target — so **no MSP needs to edit `sticker_card.dart`, and editing it is a defect**: a change there restyles every card in the app at once. C3's unset state does not use `StickerCard` at all (it is a `CustomPaint`), which is why its dashed border is achievable where `StickerCard`'s is not.

6. **`NeutralMediaPlaceholder` cannot express C7's hatch.** It already delegates to `CrossHatchPlaceholder` (`lib/features/entry_cards/media/media_placeholders.dart:140-145`) but forwards only `width`, `height` and `borderRadius` — **not** `variant`, `background` or `hatchColor`. C7's base layer at `video_body.dart:667` is currently `const NeutralMediaPlaceholder()`. C7 therefore **composes `CrossHatchPlaceholder` directly inside `video_body.dart`**, supplying `CrossHatchVariant.video` and the two colour overrides. **`media_placeholders.dart` is not edited**: it is shared with the photo and voice surfaces and it is where N7's `CorruptMediaPlaceholder` lives.

7. **`MoodPromptBorderPainter` (C3) and `DashedBorderPainter` (C6) are near-duplicate dashed-rect painters** drawing on the same `Shapes` tokens. Consolidating them would widen both MSPs and couple two otherwise independent waves. **Unifying them is out of scope for this run.** Recorded so neither implementer does it as a courtesy.

### HARD SCOPE FENCE

This run ships **exactly seven MSPs: C1, C2, C3, C4, C5, C6, C7.** No others.

- Do **not** create MSPs for clusters A, B, D, E, F, G or H. They are named in §4 only so cross-cluster dependencies stay legible. Clusters A and B are already merged; re-implementing any part of either is a defect, not a dependency.
- The complete set of files this run may touch is:

  | File | Owning MSP | New? |
  |---|---|---|
  | `lib/features/streak/streak_card.dart` | C1 | no |
  | `lib/design/icons/flame_icon.dart` | C1 | **new** |
  | `lib/features/today/today_header.dart` | C2 | no |
  | `lib/features/today/today_date.dart` | C2 | no |
  | `test/features/today/today_date_test.dart` | C2 | no (extended) |
  | `lib/features/mood/mood_banner.dart` | C2, C3 | no |
  | `lib/features/mood/mood_prompt_border.dart` | C3 | no |
  | `lib/features/today/today_screen.dart` | C4 | no |
  | `lib/features/entry_cards/entry_card.dart` | C4, C5 | no |
  | `lib/design/widgets/icon_sticker_button.dart` | C4 | no (additive enum + painter) |
  | `lib/features/entry_cards/cards/note_body.dart` | C5 | no |
  | `lib/features/entry_cards/cards/photo_strip.dart` | C5 | no |
  | `lib/features/entry_cards/media/media_image.dart` | C5 | no |
  | `lib/features/today/today_entry_feed.dart` | C6 | no |
  | `lib/design/feedback/empty_state.dart` | C6 | no |
  | `lib/features/entry_cards/cards/video_body.dart` | C7 | no |
  | `lib/features/mood/mood_banner_for_date.dart` | C2, C3 — **call site only** | no |
  | `lib/app/shell/sidebar_shell.dart` | C1 — **one line only, see carve-out** | no |

- **Two narrow carve-outs**, both found by auditing the parent spec's file lists against the tree, and both bounded to a single call site:
  - **C1's bottom margin is not in `streak_card.dart`.** The 12px gap below the streak card lives in its consumer, `lib/app/shell/sidebar_shell.dart:130` (`const SizedBox(height: 12)` immediately after `streak,`). C1's target value is 14. C1 may change **that one literal and nothing else in that file.** Cluster B is fully merged, so there is no concurrent editor, but the rest of the shell remains closed. If C1's diff touches any other line of `sidebar_shell.dart`, it is out of scope.
  - **`mood_banner_for_date.dart:61` constructs the `MoodBanner` that C2 and C3 restyle**, and the parent spec lists it under no MSP. If and only if C2 or C3 changes `MoodBanner`'s constructor signature, that call site is updated in the same MSP. Prefer not changing the signature at all.
- **Two consumers are verify-only — read them, do not edit them:**
  - `lib/features/day_detail/day_detail_entry_tile.dart:29` constructs `EntryCard` and is the **only** place that passes `onEdit`/`onDelete` (`:36-37`). It is therefore the sole surface where C4's restyled Edit/Delete controls actually render, and it belongs to no MSP in this cluster. C4 and C5 must confirm it still renders correctly — `test/features/day_detail/day_detail_entry_tile_test.dart` is the standing proof — without editing it.
  - `lib/features/today/on_this_day_card.dart:71` is the one production caller of `longDateLabel` that must keep receiving the year-bearing output after C2 adds its short form.

- Any edit outside that table is out of scope. Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/design/tokens/*` — closed by Cluster A. See above.
  - `lib/app/shell/**` — closed by Cluster B. C1 restyles the streak card, which sits *inside* the rail but lives in `lib/features/streak/`. Narrowing, repainting or re-laying-out the rail itself is B2's shipped work.
  - `lib/domain/mood/mood.dart` and `lib/domain/mood/flower_kind.dart` — the mood label strings and the mood-to-flower mapping are exact against the prototype (`:1058`, `:1045-1057`). C2 resolves `moodFlowerName` through the existing `FlowerKind.label`; it does not edit the domain.
  - `lib/features/today/on_this_day_card.dart` — D4's. It is named twice here as a **consumer**: C2 must not change `longDateLabel`'s output for it, and C6 must not break its empty and error states.
  - `lib/features/entry_cards/cards/voice_body.dart` — G8's. The voice row is not restyled by this run even though it renders inside the entry card C5 restyles.
  - `lib/features/entry_cards/playback/**` — N1. Untouchable infrastructure.
  - `lib/features/entry_cards/cards/video_scrubber.dart`, `video_transport.dart`, `video_control_bar.dart`, `video_controls_overlay.dart` — N2, N3, N5, N6. **C7 touches `video_body.dart` and nothing else in that directory.**
  - `test/features/entry_cards/playback/**` and the eight playback test files named in N24 — never edited, under any circumstances.
  - `lib/features/search/**`, `lib/features/calendar/**`, `lib/features/garden/**`, `lib/features/day_detail/**` — later clusters or out of alignment scope entirely. They appear here only as `EmptyStatePlaceholder` consumers C6 must not disturb.
- If decomposition suggests a unit outside C1–C7, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

### SERIALIZATION — read before planning parallelism

A file shared between two MSPs is a **hard dependency edge**, declared here, never left to a dependency graph to infer. The engine catches overlapping hunks; it does not catch two coherent-but-incompatible rewrites of the same widget.

The computed file-overlap matrix for this cluster has exactly two shared files:

| Shared file | Claimed by | Edge |
|---|---|---|
| `lib/features/mood/mood_banner.dart` | C2, C3 | **C2 -> C3** |
| `lib/features/entry_cards/entry_card.dart` | C4, C5 | **C4 -> C5** |

There is one further edge that is **not** a file edge and must not be dropped for that reason:

- **C5 -> C7 is a contract edge.** C5 adds opt-in border and caption parameters to `lib/features/entry_cards/media/media_image.dart`, and C7's poster path consumes `MediaImage` at `video_body.dart:673`. If C7 lands first, C5's parameter work retrofits a file C7 has already reasoned about. Serialise on the contract even though the two MSPs share no file.

```
C1                          (independent)
C6                          (independent)
C2  ->  C3                  shared mood_banner.dart
C4  ->  C5  ->  C7          C4/C5 share entry_card.dart; C5/C7 share the MediaImage contract
```

Unlike Cluster B — where all four MSPs edited one file and the run was effectively serial — **Cluster C has genuine parallelism**. The three wave groups are:

| Wave | MSPs | Justification |
|---|---|---|
| 1 | C1, C2, C4, C6 | pairwise disjoint file sets; every dependency (A1–A5, B4) already on main |
| 2 | C3, C5 | C3 after C2; C5 after C4 |
| 3 | C7 | after C5 |

MSPs in the same wave may be planned and implemented concurrently. They must still **ship one at a time**: the repo squash-merges, so once the frontmost PR lands, `main` holds its content under a SHA absent from every sibling branch's history. Each remaining MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. **Never carry a green from one base to another.**

---

## 1. BLUF

Clusters A and B built and then spent the prototype's vocabulary on the app's *frame* — the panel wash, the title bar, the rail, its nav states and its footer. **Cluster C is the first cluster that spends it on the app's primary content surface.** Today is the screen the user opens into, and it is currently the least aligned screen in the app: it carries two `critical` findings and four `high` ones, more than any other region of the parent spec.

**Cluster C's share.** The streak card is a dull cream box with a translucent shadow where the prototype has the rail's brightest emphasis surface (C1). The greeting is olive Caveat at 20px above a year-bearing date, and `Good night` does not exist anywhere in `lib/` despite the prototype defining four time branches (C2). The mood banner renders the bare word `Happy` and **no second line at all** — neither `Feeling ` nor `bloom for the day` returns a match across `lib/` — and its change control is a full sticker button reading `Change mood` where the prototype has an outline-only text pill reading `change` (C2). Before a mood is set the user gets a transparent dashed rectangle with one muted sentence: no fill, no shadow, no bloom, no subtitle, no pill (C3). Nothing labels the feed (C4). Each card is headed by a large green type-name where the prototype puts a capture timestamp and a micro badge, and **no timestamp is rendered anywhere on the card today** (C4). Cards sit dead square with 16px padding and oversized borderless photo thumbnails under a bare gap (C5). An empty day says `Nothing captured yet today.` in one sans-serif line (C6). And a video card at rest shows neither hatch, badge nor duration chip (C7).

**Aligned means**: every value in the findings table below matches its cited prototype line; every capability in §2 still works and still passes its existing tests unchanged; and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set is reproduced below verbatim from the parent spec. Not every row is endangered by Cluster C — §2.7 names which are. The complete set is carried anyway, for one reason: an implementer who encounters an app-only capability while restyling the Today column must be able to tell "preserved by decision" from "leftover to clean up". Every row below is preserved by decision.

**N24 binds every MSP in this run without exception.** Unlike Cluster B, this run *does* touch the video playback stack: **C7 edits `video_body.dart`**, the most test-covered file in the repo. N1–N10 are live constraints here, not background.

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

**Cluster C does not implement N11.** The voice row is G8's. It is carried here because C5 restyles the card that *contains* it, and an implementer who sees an unaligned voice row inside a freshly aligned card must know it is deferred work, not an oversight.

### 2.3 Capture

| # | Constraint | Citation |
|---|---|---|
| N12 | **`SettingsFieldRow` and `SettingsSelect` have a consumer outside `lib/features/settings` — the camera picker.** Any restyle of those primitives must keep them functional inside the recorder sheet. The remembered-device provider and the first-camera fallback are untouched. | `lib/features/capture/video/camera_picker.dart:8-52`, `lib/features/capture/video/camera_selection.dart:7-20`, `:22-28`; mounted at `lib/features/capture/video/video_recorder_sheet.dart:105`; primitives at `lib/design/settings_fields/settings_select.dart:46-63` |
| N13 | **The recorder's six-phase machine (preparing/idle/arming/recording/saving/denied), the 5/10/20-minute nudge schedule, and the 30:00 cap hint remain.** Copy and chrome may be restyled; the schedule, the cap and the denied stage may not be removed. | `lib/features/capture/video/video_timeline.dart:3-5`, `:9-40`; `lib/features/capture/video/video_recorder_sheet.dart:11`, `:32`, `:33`, `:204-206`, `:222-228` |
| N14 | **Armed-idle semantics hold**: opening the voice or video composer must never start recording. | `lib/features/capture/video/video_composer.dart:95`, `lib/features/capture/voice/voice_composer.dart:42` |

No MSP in this run touches capture. N12–N14 are carried for recognition only.

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
| N24 | **`ValueKey`s and Semantics labels are a public contract, not implementation detail.** `'video-play-toggle'`, `'video-scrub-bar'`, `'video-mute-toggle'`, `'video-surface-tap'`, `'voice-play-toggle'`, and the `'Play video'`/`'Pause video'`, `'Mute video'`/`'Unmute video'`, `'Video position'` labels may not be renamed. If a restyle breaks any of the 106 tests listed below, the correct response is to fix the implementation — **never to delete or weaken the test.** | `test/features/entry_cards/playback/video_slots_test.dart` (29), `.../cards/video_body_lifecycle_test.dart` (20), `.../cards/video_controls_overlay_test.dart` (18), `.../cards/video_body_test.dart` (16), `.../cards/video_body_slots_test.dart` (11), `.../cards/video_body_poster_gate_test.dart` (7), `.../cards/video_body_attempt_identity_test.dart` (4), `.../cards/video_scrubber_test.dart` (1) |
| N25 | **Blooms keep their accessible labels** (Semantics image + mood/flower label) and picker tiles keep their button + selected semantics. No prototype counterpart; preserve. | `lib/design/flowers/flower_bloom.dart:35-37`; `lib/features/mood/mood_picker_grid.dart:57-60` |

### 2.6 Additive elements to preserve, not delete

These have no prototype counterpart. They are enrichments or real-hardware states. They are re-homed into prototype chrome, never removed.

| Element | Citation |
|---|---|
| `Palette.sunGlow = Color(0x8CF4C960)` garden sun glow | `lib/design/tokens/palette.dart:45` |
| Entry-card Edit/Delete actions where wired | `lib/features/entry_cards/entry_card.dart:65-77` |
| On-this-day empty + error states | `lib/features/today/on_this_day_card.dart:15-17`, `:36-40`, `:116-123` |
| Camera picker (multi-camera selection) | `lib/features/capture/video/camera_picker.dart:33-50` |
| Video permission/error/cap/nudge copy | `lib/features/capture/video/video_recorder_sheet.dart:29-33`, `:113-124` |
| `PhotoTray` / `PhotoThumbnail` (currently dead UI) | `lib/features/capture/photo/photo_tray.dart:9`, `:107-155` |
| Chooser and its `'Coming soon'` state — phone entry point only | `lib/features/capture/chooser/capture_chooser_sheet.dart:14`, `:81` |
| No grain/noise layer on either side | `grep -rni "grain\|noise\|turbulence" lib/` returns zero hits |

### 2.7 Preserve-to-MSP binding — the rows that bind THIS run

A preserve rule stated only here does not bind anything. Each row below names the MSP in **this run** that could regress the item, and therefore carries it as an explicit constraint in §4.

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| **N1–N10 video playback stack** | **C7** — the only MSP in the parent spec that edits `entry_cards/cards/video_body.dart`. N3, N4, N5, N9 and N10 are named individually in its "Must not regress" | C7 "Must not regress" (six bullets) + §5.3 gate 2, the 106 tests, green before and after |
| Entry-card Edit/Delete actions | **C4** (header rewrite) | C4 "Must not regress" |
| N23 inline failure messaging | **C4** | C4 "Must not regress" |
| N22 search async branches | **C6** (`EmptyStatePlaceholder` change) | C6 "Must not regress" + §0 resolution 3 |
| On-this-day empty + error states | **C6** (shares `EmptyStatePlaceholder`), **C2** (shares `longDateLabel`) | C6 and C2 "Must not regress" |
| N25 bloom + tile semantics | **C3** (46px ghost bloom) | C3 "Must not regress" + §0 resolution 2 |
| N24 keys, labels, 106 tests | every MSP; **acutely C7** | §5.3 gate 2, applied before every merge |
| `PhotoTray` / `PhotoThumbnail` | **C5** transitively, if it changes `MediaImage` defaults | C5 "Must not regress" |
| N11 voice row | nothing in this run — G8 owns it | §6.1 |

---

## 3. Findings that Cluster C implements

Reproduced verbatim from the parent spec's §3.3. **One correction is applied**, marked inline and explained in §7.

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Greeting eyebrow | `font:600 16px 'Caveat',cursive; color:#c76a54`. **Four** branches: `h<12` `Good morning`, `h<17` `Good afternoon`, `h<21` `Good evening`, else `Good night` | `eyebrowAccent` = Caveat 20 w600 `Palette.sage` (olive). `greetingFor` has **three** branches; `Good night` does not exist anywhere in `lib/` | high | proto `:89`, `:1318` / `lib/features/today/today_header.dart:20`, `lib/features/today/today_date.dart:31-40` |
| Long date | `font:500 34px/1 'Newsreader',serif; color:#4a3b2e; margin-top:1px`. Format `<Weekday>, <Month> <D>` with **no year** | `displaySerif` = 32 **w600** height **1.15**; separated from the greeting by `SizedBox(height: 4)`. `longDateLabel` **appends the year** | medium | proto `:89` / `lib/features/today/today_header.dart:21-22`, `lib/features/today/today_date.dart:42-47` |
| Mood banner copy | Headline `Feeling {{moodLabel}} today` at `500 19px 'Newsreader'` `#4a3b2e`; subtitle `{{moodFlowerName}} · your bloom for the day` at `400 12px 'Instrument Sans'` `#a08a70` directly beneath | Renders only `current.label` — the bare word — in `titleSerif` (Newsreader 24 w600). **No second line at all**; `'bloom for the day'` and `'Feeling '` return nothing across `lib/` | critical | proto `:95` / `lib/features/mood/mood_banner.dart:36-38` |
| Mood banner surface | `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:16px; padding:14px 18px; box-shadow:3px 3px 0 rgba(74,59,46,.2); gap:15px`; glyph span 54x54 | `StickerCard` surface `Palette.cardLight` `0xFFFFF5EA` (not `#F8EFE0`), radius 16 (match), `EdgeInsets.all(16)`, `Shadows.card` (**exact match**). Glyph 44px, gap 12 | medium | proto `:93-94` / `lib/features/mood/mood_banner.dart:30-35` |
| Mood "change" control | A lowercase **text pill**: `font:600 11px 'Instrument Sans'; color:#c76a54; border:1.5px solid #c76a54; border-radius:13px; padding:6px 13px`. **No background fill, no shadow.** Copy `change` | `StickerButton(secondary)` labelled `'Change mood'`: `cardBright` fill, ink outline, radius 11, `Shadows.button`, padding 16h/10v, `buttonSans` (15 w600) | high | proto `:96` / `lib/features/mood/mood_banner.dart:16`, `:40-44` |
| Mood unset state | Dashed card: `background:#f8efe0; border:1.5px dashed #4a3b2e; border-radius:16px; padding:16px 18px; box-shadow:3px 3px 0 rgba(74,59,46,.14); gap:15px`. A 46x46 bloom at `opacity:.5`. Headline `How are you feeling today?` `500 19px 'Newsreader'` `#4a3b2e`. Subtitle `tap to plant today's bloom` `600 13px 'Caveat'` `#a08a70`. A **filled** pill `choose`: `color:#fff; background:#c76a54; border:1.5px solid #4a3b2e; border-radius:13px; padding:6px 13px` | `_MoodPrompt` paints only a dashed RRect (`Palette.ink`, 1.5px, radius 14, dash 6/gap 4) over **transparent** — no fill, no shadow — padding 20h/22v, one centred `Text` in `dateSerif` (Newsreader 18 w500 `mutedDeep`). No glyph, no subtitle, no pill | critical | proto `:100-103` / `lib/features/mood/mood_banner.dart:15`, `:27-28`, `:51-79`, `lib/features/mood/mood_prompt_border.dart:8-14` |
| Feed eyebrow | `'today · ' + N + ' log' + (N===1?'':'s')` at `font:600 17px 'Caveat',cursive; color:#7d8450; margin:18px 0 12px` | Nothing renders between `MoodBannerForDate` and `TodayEntryFeed` except `SizedBox(height: 20)`. `'logs'` returns no match in `lib/features/today` | high | proto `:107`, `:1666` / `lib/features/today/today_screen.dart:31-33` |
| Entry card header | Left: timestamp + time-of-day in `600 13px 'Caveat'` `#7d8450`, e.g. `08:12 · morning`. Right: uppercase micro badge `500 8px 'Instrument Sans'; letter-spacing:.08em; text-transform:uppercase; color:#c76a54; background:rgba(199,106,84,.12); border-radius:8px; padding:2px 7px`. `margin-bottom:4px` | Left: type-name eyebrow `'Note'`/`'Voice note'`/`'Video'` in `eyebrowAccent` (Caveat 20 sage). Right: Edit/Delete `StickerButton`s when callbacks supplied. **No timestamp rendered anywhere.** Header followed by `SizedBox(height: 8)` | critical | proto `:113-115`, `:1574-1575` / `lib/features/entry_cards/entry_card.dart:60-80`, `:116-125`, `:49` |
| Entry card surface | `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:14px; padding:13px 15px; box-shadow:2px 2px 0 rgba(74,59,46,.16); transform:rotate(-.5deg | .4deg)` alternating | `StickerCard`: fill matches, border matches, radius **16**, padding **16**, shadow `Offset(3,3)` `0x334A3B2E`. **No rotation** | medium | proto `:112`, `:1582` / `lib/features/entry_cards/entry_card.dart:42`, `:27` |
| Note body | `font:400 13.5px/1.5 'Newsreader',serif; color:#4a3b2e; white-space:pre-wrap`; binds the full text | `bodySerif` = Newsreader **16** w400 height 1.5 ink. Empty text falls back to `'Empty note'` in `bodySerifItalic` muted | medium | proto `:118`, `:1577` / `lib/features/entry_cards/cards/note_body.dart:12-18` |
| Photo strip | Strip `display:flex; gap:8px; margin-top:10px; padding-top:10px; border-top:1px dashed rgba(74,59,46,.25)`. Thumbnail `56x56; border-radius:9px; border:1.5px solid #4a3b2e`, caption `500 6px ui-monospace` `#8a7358` bottom-centred, `padding-bottom:3px` | Horizontal `ListView.separated` preceded only by `SizedBox(height: 12)` — **no dashed separator**. Thumbnails `72` square, spacing 8, radius 11, via `MediaImage` with no border and no caption | medium | proto `:134`, `:136` / `lib/features/entry_cards/entry_card.dart:51-54`, `lib/features/entry_cards/cards/photo_strip.dart:13-14`, `:26-40` |
| Video tile | `height:130px` (**rejected, see C7**); `border-radius:10px; overflow:hidden`, hatch `(45deg,#d9c9ae,#d9c9ae 6px,#e2d3ba 6px,#e2d3ba 12px)`, `border:1.5px solid #4a3b2e`. Centred 44x44 play badge on `rgba(255,251,244,.92)` with `1.5px #4a3b2e` border and a 17x17 `#4a3b2e` glyph at `margin-left:2px`. Duration chip `bottom:8px right:9px`, `600 10px 'Instrument Sans'` `#fff` on `rgba(42,36,29,.7)`, radius 8, padding 2px 8px | Live player at `21/9` with `_videoMinHeight = 200`, plus control bar, scrubber, transport, controls overlay. No hatch, no 44x44 badge, no corner chip | high | **proto `:128-130`** (corrected from the parent's `:127-129` — see §7) / `lib/features/entry_cards/cards/video_body.dart:23-25`, `:13-16` |
| Feed empty state | `border:1.5px dashed rgba(74,59,46,.4); border-radius:16px; padding:34px 20px; text-align:center`, no fill, no shadow. Headline `Nothing planted yet today` `500 17px 'Newsreader'` `#4a3b2e`. Sub `Capture a moment — write it, speak it, or film it.` `400 12px 'Instrument Sans'` `#a08a70` `margin-top:3px` | `EmptyStatePlaceholder`, one message `'Nothing captured yet today.'` in `bodySans` (Instrument Sans 14 w400 ink), dashed border at **full-opacity** ink, radius **14**, padding 24h/28v. No serif headline, no sub-line | medium | proto `:145-147` / `lib/features/today/today_entry_feed.dart:14`, `:48`, `lib/design/feedback/empty_state.dart:13-16`, `:42` |

Two rows of the parent's §3.3 table are **omitted from this slice**: *Voice row* is owned by **G8**, and the streak rows sit in §3.2 and are owned by **C1** (carried below). A voice row that still looks unaligned after this run is the correct outcome.

---

## 4. MSP decomposition — Cluster C

**The governing invariant**: merging any MSP must leave the branch's app fully working. No MSP may depend on a surface a later MSP creates. Ordering is bottom-up, and within this cluster it is the wave order in §0.

### C1 — Streak card

**Outcome**: the streak card reads as the rail's emphasis surface again.

**Files**: `lib/features/streak/streak_card.dart`, new `lib/design/icons/flame_icon.dart`

**Depends on**: A1, A2, A4 — all merged.

**Target values** (`:70-71`)

```
surface        Palette.cardLight #fff5ea    (from cardWarm #f8efe0)
border         1.5px Palette.ink
borderRadius   Shapes.radiusMd 14           (from 16)
padding        12 vertical, 13 horizontal   (from EdgeInsets.all(12))
boxShadow      Shadows.emphasis  2px 2px 0 #4a3b2e opaque   (from 3px translucent)
margin-bottom  14                           (from SizedBox(height: 12))
flame          17x17 custom path, filled Palette.coral, no stroke
               M12 3c3 4 5 6 5 9a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3-1-3 1-5 1-8Z
gap flame->count  7                          (from SizedBox(width: 8))
count          streakAccent  Caveat 24 w700 coral height 1.0   (from 22, no height)
note           caption10Sans  Instrument Sans 10 w400 #a08a70, margin-top 3
note copy      'longest streak yet: {summary.longest}'  — UNCHANGED, see OQ-2
               the prototype's bare 'longest streak yet' is deliberately NOT adopted
```

**Must not regress**: the card's internal structure — flame-then-count row above a sub-note, sitting directly above the footer — is already correct against `:70-72` and stays. **OQ-2 resolved to (b) on 2026-07-27: `summary.longest` keeps rendering.** This MSP restyles the sub-line and must not drop the value — the prototype never modelled a longest-streak number, so matching it here would delete real information. C1 is a pure restyle of a line whose content is unchanged.

**Slice note**: the card is mounted inside the nav rail, which B2 narrowed to 216px. C1 must not widen it back. The card currently sets only `padding: EdgeInsets.all(12)` (`streak_card.dart:17`); every other value falls through to `StickerCard`'s defaults, so C1 supplies `surface`, `borderRadius`, `shadow` and `padding` at that call site and leaves `sticker_card.dart` alone (§0 resolution 5). The flame is currently `Icon(Icons.local_fire_department, size: 18)` (`streak_card.dart:20-24`) — a Material built-in, which `flame_icon.dart` replaces with the cited 17x17 path. The sub-note is currently `captionSans` (12) at `:37` and moves to `caption10Sans` (10). **The `margin-bottom` value is the one carve-out**: it is not in this file at all — see the scope fence.

**Acceptance criteria**: the streak card is a brighter cream panel with a crisp opaque ink shadow and slightly tighter corners, standing out from the rail. The day count is 2px larger and set solid. The sub-line is a quiet 10px `longest streak yet: 3` — restyled, with the number still present.

---

### C2 — Today header and mood banner (set state)

**Outcome**: the greeting is terracotta handwriting over an undated headline, and the banner speaks a full sentence with its flower named.

**Files**: `lib/features/today/today_header.dart`, `lib/features/today/today_date.dart`, `lib/features/mood/mood_banner.dart`, `test/features/today/today_date_test.dart`

**Depends on**: A1, A2, A4 — all merged.

**Target values**

Header (`:89`): greeting in `pageEyebrowAccent` (Caveat 16 w600 **coral**); long date in `displaySerifToday` (Newsreader 34 w500 **height 1.0**) with `margin-top: 1` — replace `SizedBox(height: 4)`. `longDateLabel` for the header drops the year: format `<Weekday>, <Month> <D>` e.g. `Saturday, July 5`.

Greeting branches (`:1318`) — **four**, not three:
```
hour < 12   Good morning
hour < 17   Good afternoon
hour < 21   Good evening
otherwise   Good night
```

Mood banner set state (`:93-96`):
```
surface        Palette.cardWarm #f8efe0     (from cardLight #fff5ea)
border         1.5px Palette.ink
borderRadius   16                            (already correct)
padding        14 vertical, 18 horizontal    (from EdgeInsets.all(16))
boxShadow      Shadows.hero  3px 3px 0 rgba(74,59,46,.2)   (already an exact match)
margin-top     16
glyph          54x54                          (from 44)
gap glyph->text 15                            (from 12)
headline       'Feeling {moodLabel} today' in bannerSerif  Newsreader 19 w500 ink
subtitle       '{moodFlowerName} · your bloom for the day' in captionSans
               Instrument Sans 12 w400 #a08a70
change control a text pill, not a button:
               caption11Sans  Instrument Sans 11 w600 Palette.coral
               border 1.5px Palette.coral, borderRadius Shapes.radiusPill 13
               padding 6 vertical / 13 horizontal
               NO background fill, NO shadow
               copy exactly 'change'  (from 'Change mood')
```

`moodFlowerName` resolves through the existing `FlowerKind.label`, which already carries the correct strings including `Bleeding Heart` and `Red Spider Lily` (`lib/domain/mood/flower_kind.dart:2-11`).

**Must not regress**: `longDateLabel`'s year-bearing form is consumed elsewhere (`on_this_day_card.dart`); introduce a **separate short form** rather than changing the shared function's output for all callers. Mood label strings and the mood-to-flower mapping are exact against `:1058` and `:1045-1057` — do not touch `lib/domain/mood/mood.dart`.

**Slice note**: `MoodBanner` is constructed at `mood_banner_for_date.dart:61`, a file the parent spec assigns to no MSP. Prefer restyling without changing the constructor signature; if the signature must change, update that call site in the same MSP (see the scope fence). The set state currently overrides only `surface` on `StickerCard` (`mood_banner.dart:30`) and takes padding, radius and shadow from defaults — C2 supplies padding at the call site and leaves `sticker_card.dart` alone. The headline is currently `titleSerif` at `:37`; there is no second line to restyle, so the subtitle is net-new. C2 owns the Today mood-card glyph size (54). E4 and F2 own the calendar and picker sizes respectively and must not re-touch this file — that constraint binds *them*, and is recorded here so C2 does not pre-emptively "fix" sizes it does not own.

**Acceptance criteria**: the greeting is terracotta handwriting at a smaller size, tucked right above a larger, lighter date that reads `Saturday, July 5` with no year. At 11pm the greeting says `Good night`. The banner reads `Feeling Happy today` with `Peony · your bloom for the day` beneath it, the bloom is noticeably bigger, and the change control is a small outline-only terracotta pill reading `change`. The **four-branch greeting is a behaviour change and warrants a test** — extend the existing `today_date_test.dart` with the 21:00 boundary.

---

### C3 — Mood unset state

**Outcome**: before a mood is set, the user sees an inviting cream card, not an empty dashed rectangle.

**Files**: `lib/features/mood/mood_banner.dart`, `lib/features/mood/mood_prompt_border.dart`

**Depends on**: A1, A2, **C2** — shares `mood_banner.dart`. Hard edge; see §0 SERIALIZATION.

**Target values** (`:100-103`)

```
surface        Palette.cardWarm #f8efe0     (currently transparent)
border         1.5px DASHED Palette.ink
borderRadius   16                            (from Shapes.radiusMd 14)
padding        16 vertical, 18 horizontal    (from 22/20)
boxShadow      Shadows.heroSoft  3px 3px 0 rgba(74,59,46,.14)   (currently none)
gap            15
margin-top     16
glyph          46x46 bloom at opacity 0.5    (currently absent)
headline       'How are you feeling today?' in bannerSerif  Newsreader 19 w500 Palette.ink
               (currently dateSerif  Newsreader 18 w500 Palette.mutedDeep)
subtitle       "tap to plant today's bloom" in promptAccent  Caveat 13 w600 #a08a70
               (currently absent)
pill           'choose' — FILLED:
               caption11Sans recoloured to Palette.onAccent #fff
               background Palette.coral, border 1.5px Palette.ink
               borderRadius Shapes.radiusPill 13, padding 6 / 13
```

`MoodPromptBorderPainter` gains a fill and a hard offset shadow; it currently paints stroke-only (`mood_prompt_border.dart:22-54`).

**Must not regress**: the whole box stays the tap target, as it is today. The 46px ghost bloom is drawn from the same `FlowerBloom` used elsewhere and inherits N25's Semantics labelling — it must not be marked decorative in a way that loses the mood name.

**Slice resolution (binding)**: `FlowerBloom` has **no `opacity` parameter**. Produce the ghost bloom by wrapping `FlowerBloom(kind: ..., size: 46)` in `Opacity(opacity: 0.5, ...)` at the C3 call site. **Do not add an `opacity` parameter to the primitive.** `Opacity` preserves the subtree's semantics, so the N25 label survives — verify that it does rather than assuming it.

**Acceptance criteria**: an unset day shows a cream dashed-border card carrying a faded 46px bloom on the left, the serif question, a handwritten `tap to plant today's bloom` beneath it, and a filled terracotta `choose` pill on the right.

---

### C4 — Feed eyebrow and entry card header

**Outcome**: the feed is labelled, and each card is headed by its capture time and a small type chip.

**Files**: `lib/features/today/today_screen.dart`, `lib/features/entry_cards/entry_card.dart`, `lib/design/widgets/icon_sticker_button.dart`

**Depends on**: A1, A2, A4, **B4** — all merged. B4 created `IconStickerButton`, which C4's interim Edit/Delete placement consumes.

**Target values**

Feed eyebrow (`:107`, `:1666`): between the mood banner and the feed, render `'today · ' + N + ' log' + (N == 1 ? '' : 's')` in `sectionHeaderAccent` (Caveat 17 w600 sage) with `margin: 18 top, 12 bottom`. This replaces the bare `SizedBox(height: 20)`.

Entry card header (`:113-115`, `:1574-1575`), `margin-bottom: 4`:

- **Left**: the capture timestamp plus time-of-day, e.g. `08:12 · morning`, in `stampAccent` (Caveat 13 w600 sage). This replaces the type-name eyebrow. No timestamp is currently rendered anywhere on the card — the value must be derived from the entry's capture time.
- **Right**: an uppercase micro badge in `chipMicroSans` (Instrument Sans 8 w500, `letterSpacing 0.64`, `Palette.coral`) on `Palette.coral12` `rgba(199,106,84,.12)`, `borderRadius: Shapes.radiusIconButton 8`, `padding: 2 vertical / 7 horizontal`. Copy is the lowercase type name uppercased at render: `NOTE` / `VOICE` / `VIDEO` / `PHOTO`.

**Must not regress**: N23 and the additive Edit/Delete actions (`entry_card.dart:65-77`). The prototype has no per-card action controls, so they have nowhere obvious to go in the new header. They must **not** be deleted. Interim placement: keep them in the header row between the stamp and the type chip, restyled as small icon buttons using the B4 `IconStickerButton` at 8px radius. Their final placement is OQ-3. Note `TodayEntryTile` does not currently pass either callback (`today_entry_feed.dart:100-107`), so on Today they are invisible today — the regression risk is in **Day Detail**, not Today, and Day Detail must be checked before this MSP is called done. Confirmed at audit: `day_detail_entry_tile.dart:36-37` is the **only** call site in the repo that passes either callback, so it is the single surface on which C4's restyled controls are observable. **Do not wire `onEdit`/`onDelete` into `TodayEntryTile` to make them visible on Today** — that adds behaviour and pre-empts OQ-3.

**Slice resolution (binding)**: `IconStickerGlyph` currently has only `{ gear, soundOn, soundOff }` (`icon_sticker_button.dart:5`). C4 **adds `edit` and `trash` cases and their painter paths** — additively. The three existing cases and every B4 call site are untouched, and `icon_sticker_button.dart` is inside C4's file scope for this reason. This is a primitive extension, not a token change; §0's token rule is not engaged. The parent spec's `StickerButton(secondary)` fallback was conditioned on Cluster B not being merged and therefore does not apply.

**Acceptance criteria**: an olive handwritten `today · 4 logs` sits above the entry list. Each card is headed by its capture time on the left (`08:12 · morning`) and a small uppercase terracotta chip on the right, replacing the large green word `Note`. Day Detail still renders working Edit and Delete controls, and their failure messages are still reachable.

---

### C5 — Entry card surface, tilt, body and photo strip

**Outcome**: cards sit at a fraction of a degree off-square with denser prose and outlined thumbnails under a dashed rule.

**Files**: `lib/features/entry_cards/entry_card.dart`, `lib/features/entry_cards/cards/note_body.dart`, `lib/features/entry_cards/cards/photo_strip.dart`, `lib/features/entry_cards/media/media_image.dart`

**Depends on**: A1, A2, A4, A5, **C4** — shares `entry_card.dart`. Hard edge; see §0 SERIALIZATION.

**Target values**

Card surface (`:112`, `:1582`):
```
surface        Palette.cardWarm #f8efe0   (already correct)
border         1.5px Palette.ink          (already correct)
borderRadius   Shapes.radiusMd 14         (from 16)
padding        13 vertical, 15 horizontal (from EdgeInsets.all(16))
boxShadow      Shadows.cardDefault  2px 2px 0 rgba(74,59,46,.16)   (from 3px at .2)
rotation       alternating by entry id parity: odd -0.5deg, even +0.4deg
feed spacing   12 between cards   (already correct, :110)
```

Note body (`:118`, `:1577`): `bodySerif` — Newsreader **13.5** w400 height 1.5 ink — with `pre-wrap` preserved via `softWrap` and no text truncation. The full text binds.

Photo strip (`:134`, `:136`):
```
separator      1px DASHED Palette.ink25 above the strip
               margin-top 10, padding-top 10   (from a bare SizedBox(height: 12))
gap            8   (already correct)
thumbnail      56x56   (from 72)
               borderRadius Shapes.radiusThumb 9   (from 11)
               border 1.5px Palette.ink   (currently none)
               caption in monoThumbSans, monospace 6 w500 #8a7358,
               bottom-centred with padding-bottom 3
```

**Must not regress**: `MediaImage` is shared with the video poster layer (N9). Adding a border and caption must be **opt-in parameters** used by `PhotoStrip`, not new defaults, or the video poster gains an outline it should not have. The `CorruptMediaPlaceholder` fallback path (N7) stays reachable from the thumbnail.

**Slice note**: `MediaImage` has exactly three call sites — `photo_strip.dart:33`, `video_body.dart:673` and `test/features/entry_cards/media/media_image_test.dart:30`. The second is C7's surface and the third is a live test. All three must render identically after C5 unless C5 deliberately opts the first in.

**Acceptance criteria**: cards alternate a barely-perceptible tilt left and right down the feed, giving it a hand-placed scrapbook feel. Note text is visibly denser. Photos are smaller ink-outlined squares sitting below a dashed rule instead of larger borderless ones.

---

### C6 — Feed empty state

**Outcome**: an empty day invites capture in the design's own voice.

**Files**: `lib/features/today/today_entry_feed.dart`, `lib/design/feedback/empty_state.dart`

**Depends on**: A1, A2 — both merged.

**Target values** (`:145-147`)

```
border         1.5px DASHED Palette.ink40 rgba(74,59,46,.4)   (from full-opacity ink)
borderRadius   Shapes.radiusLg 16   (from radiusMd 14)
padding        34 vertical, 20 horizontal   (from 28/24)
fill           none, shadow none
headline       'Nothing planted yet today' in sectionSerif  Newsreader 17 w500 ink
sub            'Capture a moment — write it, speak it, or film it.'
               in captionSans  Instrument Sans 12 w400 #a08a70, margin-top 3
alignment      centred
```

`EmptyStatePlaceholder` gains an optional `headline` slot above the existing `message`; when `headline` is null it renders exactly as today, so the other consumers (N22's search empty-journal state, the on-this-day empty state) are unaffected.

**Must not regress**: N22 — the search screen's empty-journal branch must keep rendering through this widget. The on-this-day empty and error states (`on_this_day_card.dart:36-40`, `:116-123`) must keep working, including the danger-coloured error variant.

**Slice resolution (binding)**: `padding` and `borderColor` are **already constructor parameters with defaults** (`empty_state.dart:7-16`), and the widget has **nine** call sites: `day_detail_panel.dart:132`, `calendar_screen.dart:115`, `on_this_day_card.dart:39`, `today_entry_feed.dart:48`, `garden_screen.dart:55`, `garden_view.dart:33`, `search_screen.dart:54`, `:85`, `:116`. **C6 applies its new padding, border colour and radius at the Today call site**, and any new parameter (`headline`, a radius override, a headline style) defaults to today's rendering. Changing a default is a defect: it silently restyles Calendar, Garden, Search and Day Detail, none of which this run aligns. Verify by asserting the other eight call sites are visually unchanged, not by inspection alone — `test/design/feedback/empty_state_test.dart` has three existing cases that must pass unmodified.

**Acceptance criteria**: an empty day shows a lighter dashed box containing a serif headline `Nothing planted yet today` with the invitation line beneath it, replacing the single sans-serif sentence. Every other empty state in the app is pixel-identical to before.

---

### C7 — Video entry card poster chrome

**Outcome**: the video entry card's resting state carries the prototype's hatch, play badge and duration chip, on the app's existing playback envelope.

**Files**: `lib/features/entry_cards/cards/video_body.dart`

**Depends on**: A1, A4, A5, **C5** — contract edge on `MediaImage`, not a file edge. See §0 SERIALIZATION.

**Decision context — OQ-7 resolved to (a) on 2026-07-27.** The prototype's `height:130px` is **rejected**: it clips the control bar. The app's 21:9 / 200px-minimum envelope (`video_body.dart:23-24`) is load-bearing for the centred transport, the 48px scrubber row and the 48px mute target, and is unchanged. Only the poster chrome is adopted. Option (b) — 130px at rest, expanding on first play — was rejected for the mid-interaction layout jump.

**Target values** (`:128-130`)

> **Citation verified at source on 2026-07-28.** The parent spec's §3.3 findings row cites `:127-129`; that row is **wrong** and is corrected in §3 above. `:127` is the `<sc-if value="{{ e.isVideo }}">` guard; the three styled elements are at `:128`, `:129` and `:130`. Every value in the table below was read at its line and confirmed. This is the same systematic off-by-one recorded in §7.

| Element | Value |
|---|---|
| Hatch | `repeating-linear-gradient(45deg, #d9c9ae, #d9c9ae 6px, #e2d3ba 6px, #e2d3ba 12px)` — 45°, 6px bands, two-tone. Route through the A5 `CrossHatchPlaceholder`; do not hand-roll a second painter. |
| Container | `borderRadius: 10`, `border: 1.5px Palette.ink`, clipped |
| Play badge | 44x44 circle, centred; fill `rgba(255,251,244,.92)`; `border: 1.5px Palette.ink`; 17x17 dark play glyph, offset `+2` on x for optical centring (`margin-left:2px` at `:129`) |
| Duration chip | bottom 8, right 9; Instrument Sans 10 w600; `#fff` on `rgba(42,36,29,.7)`; `borderRadius: 8`; padding 2 vertical / 8 horizontal |

**Slice resolution (binding)**: `CrossHatchPlaceholder`'s rotation is a fixed 45° (`cross_hatch_placeholder.dart:136`) and its band geometry is hardcoded per variant (`:27-44`). **`CrossHatchVariant.video` is 6px band / 12px pitch — an exact match for `:128`.** C7 therefore uses that variant and supplies only the `background` and `hatchColor` overrides, both existing optional parameters. **Extending `CrossHatchVariant`, adding geometry parameters, or writing a second hatch painter is out of scope and is a defect if proposed.**

The base layer at `video_body.dart:667` is currently `const NeutralMediaPlaceholder()`, which forwards only `width`, `height` and `borderRadius` to `CrossHatchPlaceholder` and cannot carry a variant or a colour override. **C7 composes `CrossHatchPlaceholder` directly in `video_body.dart` and does not edit `media_placeholders.dart`** (§0 resolution 6). The three-layer order at `:665-684` — hatch base, video surface, conditional poster — is N9 and is preserved exactly; C7 restyles the base layer and adds the badge and chip to the resting state, and changes no gating.

**Must not regress.** This MSP lands on the most test-covered code in the repo (106 cases across eight files). Every item below is a preserve rule, not a preference:

- **N10** — the 21:9 / 200px envelope is unchanged. If the badge or chip does not fit, the badge or chip is wrong; the envelope is not negotiable.
- **N3** — the play/pause transport and its state-dependent glyph. The prototype badge is a **resting-state poster** affordance. It must not replace the live transport, and the two must never render at once.
- **N4** — the live elapsed/total readout on the control bar. The static duration chip is **resting state only** and must be gone whenever the overlay is showing a live readout.
- **N5** — the auto-hiding overlay and its platform-branched interaction model (pointer on macOS, touch elsewhere), untouched.
- **N9** — captured poster-frame gating (`video_body.dart:505-513`): a real `entry.thumbnailMediaId` still wins over the hatch. The hatch remains the **fallback**, exactly as today.
- **N7 / N8** — retry-with-backoff and the slot-contention busy notice keep their current copy and placement, and render **over** the new chrome.

**Acceptance criteria**: a video entry with no captured thumbnail shows a 45° two-tone hatch behind a 44x44 cream play badge with a dark ink outline, and a small dark duration pill bottom-right. Tapping it plays exactly as before — transport, scrubber, mute and auto-hide behave identically, and **the card does not change size at any point in the interaction**. A video entry *with* a captured thumbnail still shows the thumbnail, not the hatch.

**Verification**: this is a styling change on a behaviour-critical surface, so per §5.2 it warrants no new test of its own — but the existing playback suite is the receipt that N3/N4/N5/N9/N10 survived. Run it green before the change and green after; **a diff in that suite is a blocker, not a test to update.**

---

## 5. Verification strategy

### 5.1 What the repo actually has

No golden/screenshot coverage exists. H1 builds it and is **not** dispatched in this run. The automated safety net for Cluster C is therefore the existing widget and unit suite, of which the 106-case playback suite is the load-bearing part.

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract.

In this cluster that yields exactly one new test:

| MSP | Test | Why it qualifies |
|---|---|---|
| C2 | Extend `test/features/today/today_date_test.dart` | Behaviour: the fourth greeting branch at hour 21. `Good night` does not exist in `lib/` today, so this is new behaviour, not a restyle. |

Every other MSP in this run is a restyle and adds **no** test. C6 is the near-miss: adding an optional `headline` slot changes a widget's public surface, but the three existing cases in `test/design/feedback/empty_state_test.dart` already assert the default rendering, and C6's obligation is that they pass **unmodified** — which is a stronger receipt than a new test would be.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **106 playback tests run unmodified and pass.** This is N24 and it is the single most important check in the spec. **In this run it is not background** — C7 edits `video_body.dart` directly. A failing test here is fixed in the implementation, never by editing or deleting the test.
3. The four `integration_test/` flows pass. **Note: `fullValidationCmd` does not include them**; they must be run separately, and they have never been run on this project. Their first run is expected to surface pre-existing failures unrelated to this cluster — triage before treating one as a Cluster C regression.
4. Diff-scoped verification via the project's verify command; the full suite runs at the cluster boundary and pre-push, not per change.

**CI is not evidence.** Neither GitHub check runs a Dart test: the receipts workflow is node-only and the D6 check has no Dart import grapher and passes vacuously. `receiptsPass` / `d6Pass` are never acceptable as proof that this run is green. Run `fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge.

Baseline at the head of this slice's branch: **902 tests passing, 0 failing, `flutter analyze` clean.**

### 5.4 Manual spot-check

Today is a composite screen and this cluster rewrites all of it, so the manual pass is load-bearing. Required human pass at the cluster boundary, on macOS via `flutter run -d macos` — never the standalone binary, which renders a black window:

- **Mood set state** — headline reads `Feeling {mood} today`, subtitle names the flower, 54px bloom, outline-only `change` pill.
- **Mood unset state** — cream dashed card, 46px ghost bloom at half opacity, handwritten subtitle, filled `choose` pill.
- **Header** — terracotta greeting above an undated 34px date. Check the 21:00 branch if the hour allows; otherwise trust the new test.
- **Feed with entries** — the `today · N logs` eyebrow; per-card timestamp and uppercase type chip; alternating tilt down the feed; denser note text; 56px outlined photo thumbnails under a dashed rule.
- **Feed empty** — serif headline plus invitation line in a lighter dashed box.
- **Video card, both states** — one entry *with* a captured thumbnail (must still show the poster) and one *without* (must show hatch + badge + chip). Then play it: transport, scrubber, mute and auto-hide unchanged, and **no size change at any point**.
- **Streak card** — brighter panel, opaque shadow, `longest streak yet: N` still showing its number.
- **Regression sweep** — Calendar, Garden, Search and Day Detail empty states must look **exactly as they did before this run**. This is C6's named failure mode and it is invisible from the Today screen.

### 5.5 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation.

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

The parent spec's §6.1 table lists the prototype elements deliberately excluded from alignment. All remain excluded. Four are reachable-looking from Cluster C and must be handled explicitly:

- **The video card's 130px height.** Excluded by OQ-7a. C7 adopts the hatch, badge and chip on the app's unchanged envelope. An implementer who "completes the fidelity" by adopting the height has broken N10.
- **The voice row (N11).** G8's. It renders inside the card C5 restyles and will look unaligned after this run. That is correct.
- **The right rail (D1–D4)** including the on-this-day card. C2 and C6 both touch code the rail consumes (`longDateLabel`, `EmptyStatePlaceholder`) and must leave its rendering unchanged.
- **The markdown editor engine and free-manipulation photo cards.** Neither is reachable from this cluster; recorded so no MSP goes looking.

### 6.2 Explicitly not a task

- **No grain or noise overlay.** Neither side has one.
- **No `flutter_svg` / `vector_graphics` dependency.** All bloom, icon and hatch art stays procedural Dart in `CustomPainter`. This binds C1 directly — the 17x17 flame is a hand-drawn path in Dart, not an imported asset.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants.
- **No `FontVariation('wght', …)` calls.** Bind by `fontFamily` string plus explicit `FontWeight`.
- **No deletion or weakening of the 106 playback tests** under any circumstances (N24).
- **No renames, removals or additions in the token layer.** It closed with Cluster A. See §0.
- **No second hatch painter.** See C7's slice resolution.
- **No change to `EmptyStatePlaceholder`'s existing defaults.** See C6's slice resolution.
- **No change to `lib/app/shell/**`.** Cluster B closed it.

### 6.3 Open questions

Five of the parent spec's seven open questions were resolved by the product owner on 2026-07-27. **Two of those resolutions bind this run and are written into the MSPs**: OQ-2 → (b) binds C1 (`summary.longest` keeps rendering); OQ-7 → (a) binds C7 (envelope kept, chrome adopted).

Still open: **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model).

**OQ-3 touches C4 and must not be resolved implicitly.** C4 ships the *interim* placement the parent spec specifies — the pair kept in the header row as icon buttons. An implementer who instead removes them from Today "to match the prototype" has resolved OQ-3 unilaterally and deleted a preserve item. If the interim placement proves unworkable, stop and report; do not choose.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

The parent spec's first draft asserted that every prototype value had been read at its cited line and confirmed. That was **not** true for two regions — the note-composer body `:467-473` and the voice/video composer `:479-519` — both systematically off by one or worse, and both corrected in the parent. Three further citations were not off-by-one but simply wrong and were repointed: `ink08`/`ink12`, `Shadows.chip`, and the phone mood-picker sheet.

**A third instance was found while cutting this slice, and it is in Cluster C's own region.** The parent's §3.3 findings row for the video tile cites `:127-129`. Re-opening the file shows `:127` is the `<sc-if value="{{ e.isVideo }}">` guard and the three styled elements are at `:128-130`. C7's MSP body already carried the corrected citation; the findings table did not. **The table is corrected in §3 of this document.** Both now agree, and every value in C7's target table was verified at its line on 2026-07-28.

**Rule for implementers:** re-open the cited line in `docs/prototype/project/Field Notes.dc.html` before adopting any value. This spec family has now been wrong about line numbers three times; treat a citation as a pointer to verify, not as an authority.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
