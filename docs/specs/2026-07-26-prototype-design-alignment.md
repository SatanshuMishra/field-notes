# Prototype Design Alignment Spec

Date: 2026-07-26
Project: field notes (Flutter desktop + mobile)
Prototype source of truth: `docs/prototype/project/Field Notes.dc.html` (1742 lines)
Status: draft, awaiting decisions on the open questions in the final section
Revision: 2026-07-26 adversarial review pass — 9 execution blockers fixed in place (see section 8 for the change log)

---

## 1. BLUF

The app implements the prototype's *vocabulary* correctly — the ink, coral, sage and warm-paper hexes are exact, the three font families are right, the sticker composition (fill + 1.5px ink border + zero-blur offset shadow) is the correct abstraction, and the mood/flower domain model matches the prototype's `FLOWERS` map one-for-one. What it does not implement is the prototype's *grammar*: the design's distinctions have been collapsed into single tokens. One shadow token stands in for a four-step offset scale, one Caveat token stands in for two different Caveat roles, one flower painter serves both the 44-unit compact glyph and the 190-240-unit garden plant, one button shadow is applied to primary and secondary alike, and one radius ladder is missing the 8px, 12px and 13px steps the prototype uses most. On top of that, three structural regressions are visible today: the app interior paints the *outside-the-window* page colour `#D9CBB2` instead of the `#efe2ce → #e9dcc4` panel wash, every right-rail section is wrapped in a heavy drop-shadowed card the prototype draws as a bare div, and every dialog built through `showGeneralDialog` renders its text with Flutter's yellow double-underline "you forgot a Material ancestor" debug style.

**Aligned means**: every value in the findings tables below matches its cited prototype line; every capability in section 2 still works and still passes its existing tests unchanged; and no prototype value has been adopted where doing so would break a preserved behaviour (the one known collision — the video card's `height:130px` versus the app's 200px control-bar floor — is called out explicitly and resolved by decision, not by silent truncation).

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

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

### 2.3 Capture

| # | Constraint | Citation |
|---|---|---|
| N12 | **`SettingsFieldRow` and `SettingsSelect` have a consumer outside `lib/features/settings` — the camera picker.** Any restyle of those primitives must keep them functional inside the recorder sheet. The remembered-device provider and the first-camera fallback are untouched. | `lib/features/capture/video/camera_picker.dart:8-52`, `lib/features/capture/video/camera_selection.dart:7-20`, `:22-28`; mounted at `lib/features/capture/video/video_recorder_sheet.dart:105`; primitives at `lib/design/settings_fields/settings_select.dart:46-63` |
| N13 | **The recorder's six-phase machine (preparing/idle/arming/recording/saving/denied), the 5/10/20-minute nudge schedule, and the 30:00 cap hint remain.** Copy and chrome may be restyled; the schedule, the cap and the denied stage may not be removed. | `lib/features/capture/video/video_timeline.dart:3-5`, `:9-40`; `lib/features/capture/video/video_recorder_sheet.dart:11`, `:32`, `:33`, `:204-206`, `:222-228` |
| N14 | **Armed-idle semantics hold**: opening the voice or video composer must never start recording. | `lib/features/capture/video/video_composer.dart:95`, `lib/features/capture/voice/voice_composer.dart:42` |

### 2.4 Settings and data

| # | Constraint | Citation |
|---|---|---|
| N15 | The Sync & storage section is a **superset** of the prototype's four fields by design. **Recovery passphrase stays.** Align its row chrome to the prototype field pattern; do not delete the row. | `lib/features/settings/sections/sync_storage_section.dart:98-105` |
| N16 | **Keep the Pair a device row and its QR placeholder control.** It may be restyled into the prototype card treatment; it may not be dropped for lacking a prototype analogue. | `lib/features/settings/sections/sync_storage_section.dart:106-111`; `lib/features/settings/sync/pairing_qr_placeholder.dart` |
| N17 | The settings screen retains a host for `SettingsNotice` and its dismiss affordance. **Every settings action that can succeed or fail must still report its outcome** after the restyle. | `lib/features/settings/widgets/settings_notice.dart:5-30`, `:22` |
| N18 | **Delete all data stays gated behind `confirmDeleteAll` returning true.** The dialog chrome may be restyled; the confirmation step is non-negotiable. | `lib/features/settings/widgets/delete_all_dialog.dart:5-11`, `:14-45`; invoked at `lib/features/settings/sections/data_section.dart:46-50` |
| N19 | **Keep both export delivery strategies, the platform selector, and the delivered/dismissed outcome distinction.** Export feedback must continue to differentiate cancellation from error. | `lib/features/data/export_delivery.dart:9-21`, `:30-48`, `:50-71`, `:74-79`; `lib/features/data/export_runner.dart:5-21` |
| N20 | **All UI sound cues stay behind `GatedSoundService`** so the per-call enabled check and the error suppression remain in force. The nav-rail sound toggle and the Sound effects settings row drive the same gate. | `lib/features/sound/gated_sound_service.dart:9-31`, `:21-22`, `:26-28`; `lib/features/sound/sound_providers.dart` |

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
| `Palette.sunGlow = Color(0x8CF4C960)` garden sun glow (`grep -c f4c960` on the prototype returns 0) | `lib/design/tokens/palette.dart:45` |
| Entry-card Edit/Delete actions where wired | `lib/features/entry_cards/entry_card.dart:65-77` |
| On-this-day empty + error states (prototype `:173-178` is static markup with no empty variant) | `lib/features/today/on_this_day_card.dart:15-17`, `:36-40`, `:116-123` |
| Camera picker (multi-camera selection) | `lib/features/capture/video/camera_picker.dart:33-50` |
| Video permission/error/cap/nudge copy | `lib/features/capture/video/video_recorder_sheet.dart:29-33`, `:113-124`; `lib/features/capture/video/video_timeline.dart:1-41` |
| `PhotoTray` / `PhotoThumbnail` (currently dead UI — nothing in `lib/` mounts it) | `lib/features/capture/photo/photo_tray.dart:9`, `:107-155`; `lib/features/capture/photo/photo_thumbnail.dart:9-38` |
| Chooser and its `'Coming soon'` state — **phone entry point only**; the desktop button at `today_capture_buttons.dart:79` is removed by decision (OQ-4a), the chooser itself is preserved | `lib/features/capture/chooser/capture_chooser_sheet.dart:14`, `:81`; reached via `lib/app/shell/app_shell.dart:30-32`, `lib/app/shell/bottom_bar_shell.dart:116` |
| No grain/noise layer on either side — recorded so no MSP goes looking for one to add or remove | `grep -rni "grain\|noise\|turbulence" lib/` returns zero hits; the prototype's only `noise` hit is an audio buffer at `Field Notes.dc.html:1294` |

### 2.7 Preserve-to-MSP binding

A preserve rule stated only here does not bind anything. Each row below names the MSP that could regress the item and therefore carries it as an explicit constraint. If an item has no owning MSP, that is stated — it means no MSP in this set touches it, which is itself the guarantee.

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| `Palette.sunGlow` garden sun glow | E4 (meadow rewrite) | E4 "Must not regress" |
| Entry-card Edit/Delete actions | C4 (header rewrite), A4 (button restyle) | C4 "Must not regress"; A4 blast-radius list |
| On-this-day empty + error states | D1 (unwraps the section), D4 (card rewrite) | D4 "Must not regress"; D1 section-3 nuance |
| Camera picker (`SettingsFieldRow`/`SettingsSelect` consumer) | G7 (dark viewport), G1 (panel widen), A4 | G7 N12 bullet; G1 "Must not regress" |
| Video permission / error / cap / nudge copy | G7 (chrome replacement) | G7 N13 bullet |
| `PhotoTray` / `PhotoThumbnail` (dead UI, live test) | A4 (button restyle), A5 (`CrossHatchPlaceholder` rewrite) | A4 blast-radius list; A5 "Must not regress" |
| Chooser + `'Coming soon'` (phone) | D3 (removes the **desktop button**, must not touch the chooser), G4 (chooser rewrite) | D3 reachability trace + `bottom_bar_shell_test.dart:52` as the standing proof; G4 "Must not regress" |
| No grain/noise layer | nothing | §6.2 |
| N15–N19 settings capabilities | **A2 and A4 only** (token/button value changes reach Settings; no MSP restyles the screen) | A2 blast-radius note; A4 blast-radius list; §6.1 defers the screen |
| N1–N10 video playback stack | **C7** — since OQ-7 resolved to (a), C7 is the only MSP that edits `entry_cards/cards/video_body.dart`. N3, N4, N5, N9 and N10 are named individually in its "Must not regress" | C7 "Must not regress" (six bullets) + §5.3 gate 2 (the 106 tests) run green before and after |
| N11 voice row | G8 | G8 "Must not regress" |
| N21 garden motion | E4, and E1–E3 transitively via the shared painter | E1/E2/E3 Garden-screen checks; E4 "Must not regress" |
| N22 search async branches | C6 (`EmptyStatePlaceholder` change) | C6 "Must not regress" |
| N23 inline failure messaging | C4, G3 | C4 and G3 "Must not regress" |
| N24 keys, labels, 106 tests | every MSP | §5.3 gate 2, applied before every merge |
| N25 bloom + tile semantics | C3, D2, E1–E4, F1–F3 | each MSP's "Must not regress" |

---

## 3. Findings

Every prototype value below was opened and confirmed. Where the original audit's line number was off by one, the corrected line is used.

### 3.0 Correction carried forward from verification

The audit finding `card-shadow-offset-and-opacity` was **overstated** and is re-scoped here. Its premise — that the prototype has one default card shadow at `2px 2px 0 rgba(74,59,46,.16)` and one emphasis shadow at `2px 2px 0 #4a3b2e` — is false. The hard-offset family splits, by exact occurrence count in the source:

| Offset | Inline translucent | Inline opaque `#4a3b2e` | JS-block |
|---|---|---|---|
| `1.5px` | 9 at `.16`, 4 at `.2`, 1 at `.3` | 9 | 3 opaque, 1 at `rgba(199,106,84,.3)`, 1 at `rgba(74,59,46,.18)` |
| `2px` | 5 at `.16`, 2 at `.2`, 1 at `.22`, 1 at `.18` | 4 | 2 opaque, 1 at `rgba(199,106,84,.28)`, 1 at `rgba(199,106,84,.3)`, 1 at `rgba(74,59,46,.16)` |
| `2.5px` | — | 2 (`:806`, `:809`, phone voice composer buttons) | — |
| `3px` | 4 (`.2`, `.14`, and two others) | — | — |

Verify with `grep -o "box-shadow:1\.5px 1\.5px 0 [^;'\"]*" "Field Notes.dc.html" | sort | uniq -c` and its `boxShadow:'…'` JS counterpart before changing any offset value.

Consequences the implementers must act on:

- `Shadows.card` = `Offset(3, 3)` / `0x334A3B2E` is an **exact match** for the desktop mood banner at `Field Notes.dc.html:93` (`box-shadow:3px 3px 0 rgba(74,59,46,.2)`). "Every card's shadow is mis-offset" is wrong.
- `Shadows.button` = `Offset(1.5, 1.5)` / opaque ink matches the prototype's **most common** opaque button shadow (12 occurrences of 1.5px against 6 of 2px), e.g. the composer save button at `:466` and the Add-memory button at `:470`.
- The real defect is that **the prototype scales shadow offset with element size and the app has two fixed tokens.** The fix is a shadow *scale*, not a corrected offset.

### 3.1 Design tokens and shared primitives

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| App panel background | `radial-gradient(120% 60% at 15% 0%, rgba(199,106,84,.07), transparent 55%), linear-gradient(#efe2ce, #e9dcc4)`. `#d9cbb2` is the page colour **outside** the device frame, with its own `radial-gradient(120% 80% at 50% -10%, #e6d8bf, #cdbd9f)` | `Scaffold(backgroundColor: Palette.page)` = `0xFFD9CBB2`, flat. `pageGradientInner` `0xFFE6D8BF`, `pageGradientOuter` `0xFFCDBD9F`, `panelTop` `0xFFEFE2CE`, `panelBottom` `0xFFE9DCC4`, `panelCoralTint` `0x12C76A54` all declared with correct values, none painted by the shell | high | proto `:56`, `:18` / `lib/app/shell/sidebar_shell.dart:28`, `lib/design/tokens/palette.dart:4-10` |
| Shadow scale | Offset scales with element size: `1.5px` chips and small buttons, `2px` cards and primary buttons, `2.5px` phone FAB, `3px` hero cards. Alpha ladder `.14 / .16 / .18 / .2 / .22 / .3` for translucent, plus fully opaque `#4a3b2e` for emphasis | Two fixed tokens: `Shadows.card` = `Offset(3,3)` `0x334A3B2E`; `Shadows.button` = `Offset(1.5,1.5)` opaque `Palette.ink`. No scale, no alpha ladder | high (re-scoped) | proto `:1582`, `:1595`, `:93`, `:174`, `:1608-1609` / `lib/design/tokens/shadows.dart:6-24` |
| Radius ladder | Observed: 6 · 8 · 9 · 10 · 11 · 12 · 13 · 14 · 15 · 16 · 20 · 22 · 26 · 28 · 36 · 46 · 50%. Cards 14, nav items and buttons 12, icon buttons 8, dashed empty states 16, chips 20, week cells 10, memory card 13, thumbnails 9 | `radiusSm 11`, `radiusMd 14`, `radiusLg 16`, `radiusXl 20`. `cardBorderRadius` = 16 (proto cards are 14); `buttonBorderRadius` = 11 (proto buttons are 12). No 8, no 9, no 10, no 12, no 13 | medium | proto `:1582`, `:1596`, `:1608`, `:174`, `:136`, `:1644` / `lib/design/tokens/shapes.dart:8-16` |
| Ink alpha ladder + 3 unmapped colours | `rgba(74,59,46,…)` at `.35` (input borders, dashed cell borders), `.25`, `.22`, `.2`, `.18`, `.16`, `.12`, `.08`. Named: `#6a5c4a` inactive nav ink and icon stroke, `#a3866a` window title, `#e0574a` record-button fill | `Palette.ink` at full opacity only. The single alpha derivative is `Shadows._cardShadowColor = Color(0x334A3B2E)`, private. No `0xFF6A5C4A`, `0xFFA3866A`, `0xFFE0574A` | medium | proto `:70`, `:1564`, `:52`, `:59`, `:134`, `:1610` / `lib/design/tokens/palette.dart:17` |
| `StickerButton` secondary shadow | Secondary: `background:#f8efe0; color:#4a3b2e; border:1.5px solid #4a3b2e; border-radius:12px; padding:10px 13px; gap:10px` — **explicitly no box-shadow**. The presence/absence of the hard shadow **is** the primary/secondary distinction | `boxShadow: Shadows.button` applied unconditionally in the shared `DecoratedBox` for primary, secondary and danger alike. Secondary fill is `Palette.cardBright` `0xFFFFFAF1`, not `0xFFF8EFE0` | high | proto `:1595-1596` / `lib/design/widgets/sticker_button.dart:40`, `:82-86` |
| `StickerButton` geometry | `border-radius:12px; padding:10px 13px; gap:10px` | `borderRadius` = `radiusSm` 11; `padding` 16h/10v; icon gap `SizedBox(width: 8)` | medium | proto `:1595-1596` / `lib/design/widgets/sticker_button.dart:39-49` |
| Text on accent | `#fff` — pure white on the `#c76a54` accent (active nav item, primary button) | `Palette.cardBright` `0xFFFFFAF1` used as `onPrimary` and as the primary/danger foreground. `#FFFAF1` is the prototype's **input-field surface** colour, not its text-on-accent colour | low | proto `:1595`, `:1564` / `lib/design/widgets/sticker_button.dart:80` |
| `StickerCard` rotation | Entry cards carry `transform:rotate` alternating by id parity — `-.5deg` odd, `.4deg` even. One of only three sources of texture in the prototype | No rotation parameter, no `Transform.rotate` anywhere in the widget | medium | proto `:1582` / `lib/design/widgets/sticker_card.dart:5-19` |
| Serif metrics | Page title `500 32px/1 'Newsreader'` (Today uses `500 34px/1`). Entry body `400 13.5px/1.5`, colour `#4a3b2e`, `white-space:pre-wrap`. Secondary prose `400 12px/1.5`, colour `#8a7358`. Mood banner headline `500 19px`. Picker title `500 21px`. Chooser title `500 17px`. Memory title `500 12px` | `displaySerif` 32 **w600** height **1.15**; `bodySerif` **16** w400 height 1.5; `titleSerif` **24** w600 height 1.2 (no prototype counterpart size). No 34px Today variant, no 19/21/17/12 variants | medium | proto `:89`, `:118`, `:95`, `:440`, `:750`, `:176` / `lib/design/tokens/typography.dart:10-32` |
| Caveat role collision | **Two separate roles.** Page eyebrow `600 16px 'Caveat'` colour `#c76a54`. Section header `600 17px 'Caveat'` colour `#7d8450` | One token: `eyebrowAccent` = Caveat **20px** w600 `Palette.sage`. No terracotta Caveat eyebrow token exists | high | proto `:89`, `:154`, `:164`, `:173`, `:107` / `lib/design/tokens/typography.dart:79-84` |
| `captionSans` weight and size ladder | Caption `400 12px 'Instrument Sans'` colour `#a08a70`. Smaller steps 11 / 10 / 9 / 8 / 7 / 6px all remain weight 400 | `captionSans` = Instrument Sans 12 **w500** `Palette.muted`. Colour and size right, weight one step heavy, and it is the only small-text token so it is reused at every caption size | low | proto `:147`, `:155`, `:176`, `:1611`, `:465` / `lib/design/tokens/typography.dart:64-69` |
| Cross-hatch fill | `repeating-linear-gradient(45deg, #e2d3ba, #e2d3ba Npx, #ecdfc8 Npx, #ecdfc8 2Npx)` for photos; darker `(45deg, #d9c9ae … #e2d3ba …)` for video. A **single-direction** two-tone stripe, no line strokes | `CrossHatchPainter` strokes **two opposing** diagonal line families at spacing 8, strokeWidth 1, in `Palette.placeholder` `0xFFB3A58C` over `cardWarm`, radius 16. No darker video variant | medium | proto `:136`, `:175`, `:127` / `lib/design/widgets/cross_hatch_placeholder.dart:58-71` |

### 3.2 Window chrome and nav rail

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Active nav item | `background:#c76a54; color:#fff; border:1.5px solid #4a3b2e; box-shadow:2px 2px 0 #4a3b2e; border-radius:12px; padding:9px 12px; gap:10px`. Icon stroke/fill `#fff` | `background: Palette.cardBright` `0xFFFFFAF1`; `border: Shapes.outline`; `borderRadius` 11; **no boxShadow**; padding 12h/10v; gap 10. Label and icon stay `Palette.ink` in **both** states | critical | proto `:1564`, `:1562` / `lib/app/shell/sidebar_shell.dart:131-146` |
| Inactive nav item | Icon and label `#6a5c4a`; label `600 14px 'Instrument Sans'` | `Icon(..., color: Palette.ink)` `0xFF4A3B2E`; `labelSans` = Instrument Sans 14 **w500** `Palette.ink`. No `0xFF6A5C4A` in Palette | medium | proto `:1562`, `:1564` / `lib/app/shell/sidebar_shell.dart:141-143` |
| Nav icon glyphs | Custom 24-viewBox paths at 18x18. Home is a **house**, rendered **filled**: `M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z`. Calendar `rect x=4 y=5 w=16 h=16 rx=2` + `M4 9h16M9 3v4M15 3v4`. Garden three circles `(12,9,r3) (8,13,r3) (16,13,r3)` + stem `M12 12v9`. Search `circle(11,11,r7)` + `M21 21l-4-4`. Non-home icons stroked at width 2, round caps/joins | Material at 18px: `Icons.wb_sunny_outlined` (a **sun**), `Icons.calendar_today_outlined`, `Icons.local_florist_outlined`, `Icons.search` | high | proto `:1218-1221`, `:1562` / `lib/app/shell/shell_destination.dart:4-7` |
| Rail geometry | `width:216px; flex:none; padding:22px 16px; border-right:1px dashed rgba(74,59,46,.22)`. Derived content width 184px | `SizedBox(width: 248)` + `EdgeInsets.all(16)`. Derived content width 216px. Divider is `DashedDivider` defaults: thickness **1.5**, `Palette.ink` at **full** opacity, dash 6 / gap 4, `StrokeCap.square` | medium | proto `:59` / `lib/app/shell/sidebar_shell.dart:76-79`, `:37` |
| Brand logo flower | 32x32 span containing `this.flower('happy')` — the Peony SVG, 9px gap to the wordmark, 24px margin-bottom. No tile or background behind it in the rail | Not rendered. The Column's first child is the bare wordmark `Text`. `FlowerBloom` with `FlowerKind.peony` exists but is never used by the shell | high | proto `:61`, `:60`, `:1669` / `lib/app/shell/sidebar_shell.dart:83` |
| Wordmark | `font:700 23px/.85 'Caveat',cursive; color:#c76a54`, broken by a literal `<br>`: `field` / `notes`. The `.85` line-height is load-bearing for the tight two-line stack | `Text('field notes', style: wordmarkAccent)` = Caveat **28**, w700, `Palette.ink`, no height override, single line | high | proto `:62` / `lib/design/tokens/typography.dart:93-98`, `lib/app/shell/sidebar_shell.dart:83` |
| Settings + sound footer | Two **icon-only square** buttons in a horizontal row (`display:flex; align-items:center; gap:9px`). Each `width:30px; height:30px; border-radius:8px; border:1.5px solid #4a3b2e; padding:7px`, **no box-shadow**, 15x15 icon at strokeWidth 1.8. Settings fill `#c76a54` when `view==='settings'` (gear stroked `#fff`) else `#fff5ea`. Sound fill `#fff5ea` on / `#f8efe0` off; the **glyph** swaps: on `M4 9v6h4l5 4V5L8 9z` + `M16 9a4 4 0 0 1 0 6`, off the same speaker + `M17 9l4 6M21 9l-4 6` | Two stacked full-width `StickerButton(secondary)` rows labelled `'Settings'` and `'Sound'`, `SizedBox(height: 8)` between. Each: `cardBright` fill, 1.5px outline, radius 11, `Shadows.button`, padding 16h/10v, 16px Material icon, 8px gap, `buttonSans` label. No dependence on `selected`; `onSound` has no state fed back | critical | proto `:74-76`, `:1644`, `:1682` / `lib/app/shell/sidebar_shell.dart:89-111` |
| Sync footer text | A `line-height:1.15` div, two lines. Line 1 `600 10px 'Instrument Sans'` `#4a3b2e` `Synced to home`. Line 2 `400 8px 'Instrument Sans'` `#a08a70` `your server · just now`. Sits **to the right** of the two icon buttons in the same flex row | Single `Text('On this device only')` in `captionSans` (12 w500 `Palette.muted`), placed **below** the buttons after `SizedBox(height: 12)` | high | proto `:77`, `:74` / `lib/app/shell/sidebar_shell.dart:113-116` |
| Title bar | `height:42px; background:#e4d6bf; padding:0 16px; border-bottom:1px solid rgba(74,59,46,.16)` — **solid**, not dashed | `Container(height: 36, color: Palette.titleBar, padding: 12h)`. No bottom border | medium | proto `:50` / `lib/app/shell/sidebar_shell.dart:48-51` |
| Window title | A `flex:1` centred div — `font:600 14px 'Caveat',cursive; color:#a3866a; text-align:center`, copy `field notes — a journal of days` — followed by a trailing `<div style="width:56px">` balancing the 52px traffic-light cluster | Row contains only the three traffic-light dots, `mainAxisSize.min`, left-aligned. No title, no spacer. No `#A3866A` in Palette | medium | proto `:52`, `:51` / `lib/app/shell/sidebar_shell.dart:53-63` |
| Streak card | `background:#fff5ea; border:1.5px solid #4a3b2e; border-radius:14px; padding:12px 13px; box-shadow:2px 2px 0 #4a3b2e` (opaque); `margin-bottom:14px` | `StickerCard` defaults: `Palette.cardWarm` `0xFFF8EFE0`, radius 16, `Shadows.card` `Offset(3,3)` `0x334A3B2E`; `EdgeInsets.all(12)`; `SizedBox(height: 12)` after | medium | proto `:70` / `lib/features/streak/streak_card.dart:15-17` |
| Streak text | Number `700 24px 'Caveat'` `#c76a54` `line-height:1`, content `{{ streak }} days`. Note `400 10px 'Instrument Sans'` `#a08a70` `margin-top:3px`, literal copy `longest streak yet` | Number `streakAccent` = Caveat **22** w700 coral, no height override. Note `captionSans` (12 w500), copy `longest streak yet: ${summary.longest}` | medium | proto `:71` / `lib/features/streak/streak_card.dart:31-38` |
| Streak flame | 17x17 custom path `M12 3c3 4 5 6 5 9a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3-1-3 1-5 1-8Z`, filled `#c76a54`, no stroke; 7px gap to the count | `Icon(Icons.local_fire_department, size: 18, color: Palette.coral)` + `SizedBox(width: 8)` | low | proto `:71` / `lib/features/streak/streak_card.dart:20-25` |

### 3.3 Today — centre column

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Greeting eyebrow | `font:600 16px 'Caveat',cursive; color:#c76a54`. **Four** branches: `h<12` `Good morning`, `h<17` `Good afternoon`, `h<21` `Good evening`, else `Good night` | `eyebrowAccent` = Caveat 20 w600 `Palette.sage` (olive). `greetingFor` has **three** branches; `Good night` does not exist anywhere in `lib/` | high | proto `:89`, `:1318` / `lib/features/today/today_header.dart:20`, `lib/features/today/today_date.dart:31-40` |
| Long date | `font:500 34px/1 'Newsreader',serif; color:#4a3b2e; margin-top:1px`. Format `<Weekday>, <Month> <D>` with **no year** | `displaySerif` = 32 **w600** height **1.15**; separated from the greeting by `SizedBox(height: 4)`. `longDateLabel` **appends the year** | medium | proto `:89` / `lib/features/today/today_header.dart:21-22`, `lib/features/today/today_date.dart:42-47` |
| Mood banner copy | Headline `Feeling {{moodLabel}} today` at `500 19px 'Newsreader'` `#4a3b2e`; subtitle `{{moodFlowerName}} · your bloom for the day` at `400 12px 'Instrument Sans'` `#a08a70` directly beneath | Renders only `current.label` — the bare word — in `titleSerif` (Newsreader 24 w600). **No second line at all**; `'bloom for the day'` and `'Feeling '` return nothing across `lib/` | critical | proto `:95` / `lib/features/mood/mood_banner.dart:36-38` |
| Mood banner surface | `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:16px; padding:14px 18px; box-shadow:3px 3px 0 rgba(74,59,46,.2); gap:15px`; glyph span 54x54 | `StickerCard` surface `Palette.cardLight` `0xFFFFF5EA` (not `#F8EFE0`), radius 16 (match), `EdgeInsets.all(16)`, `Shadows.card` (**exact match** for `3px 3px 0 rgba(74,59,46,.2)`). Glyph 44px, gap 12 | medium | proto `:93-94` / `lib/features/mood/mood_banner.dart:30-35` |
| Mood "change" control | A lowercase **text pill**: `font:600 11px 'Instrument Sans'; color:#c76a54; border:1.5px solid #c76a54; border-radius:13px; padding:6px 13px`. **No background fill, no shadow.** Copy `change` | `StickerButton(secondary)` labelled `'Change mood'`: `cardBright` fill, ink outline, radius 11, `Shadows.button`, padding 16h/10v, `buttonSans` (15 w600) | high | proto `:96` / `lib/features/mood/mood_banner.dart:16`, `:40-44` |
| Mood unset state | Dashed card: `background:#f8efe0; border:1.5px dashed #4a3b2e; border-radius:16px; padding:16px 18px; box-shadow:3px 3px 0 rgba(74,59,46,.14); gap:15px`. A 46x46 bloom at `opacity:.5`. Headline `How are you feeling today?` `500 19px 'Newsreader'` `#4a3b2e`. Subtitle `tap to plant today's bloom` `600 13px 'Caveat'` `#a08a70`. A **filled** pill `choose`: `color:#fff; background:#c76a54; border:1.5px solid #4a3b2e; border-radius:13px; padding:6px 13px` | `_MoodPrompt` paints only a dashed RRect (`Palette.ink`, 1.5px, radius 14, dash 6/gap 4) over **transparent** — no fill, no shadow — padding 20h/22v, one centred `Text` in `dateSerif` (Newsreader 18 w500 `mutedDeep`). No glyph, no subtitle, no pill | critical | proto `:100-103` / `lib/features/mood/mood_banner.dart:15`, `:27-28`, `:51-79`, `lib/features/mood/mood_prompt_border.dart:8-14` |
| Feed eyebrow | `'today · ' + N + ' log' + (N===1?'':'s')` at `font:600 17px 'Caveat',cursive; color:#7d8450; margin:18px 0 12px` | Nothing renders between `MoodBannerForDate` and `TodayEntryFeed` except `SizedBox(height: 20)`. `'logs'` returns no match in `lib/features/today` | high | proto `:107`, `:1666` / `lib/features/today/today_screen.dart:31-33` |
| Entry card header | Left: timestamp + time-of-day in `600 13px 'Caveat'` `#7d8450`, e.g. `08:12 · morning`. Right: uppercase micro badge `500 8px 'Instrument Sans'; letter-spacing:.08em; text-transform:uppercase; color:#c76a54; background:rgba(199,106,84,.12); border-radius:8px; padding:2px 7px`. `margin-bottom:4px` | Left: type-name eyebrow `'Note'`/`'Voice note'`/`'Video'` in `eyebrowAccent` (Caveat 20 sage). Right: Edit/Delete `StickerButton`s when callbacks supplied. **No timestamp rendered anywhere.** Header followed by `SizedBox(height: 8)` | critical | proto `:113-115`, `:1574-1575` / `lib/features/entry_cards/entry_card.dart:60-80`, `:116-125`, `:49` |
| Entry card surface | `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:14px; padding:13px 15px; box-shadow:2px 2px 0 rgba(74,59,46,.16); transform:rotate(-.5deg | .4deg)` alternating | `StickerCard`: fill matches, border matches, radius **16**, padding **16**, shadow `Offset(3,3)` `0x334A3B2E`. **No rotation** | medium | proto `:112`, `:1582` / `lib/features/entry_cards/entry_card.dart:42`, `:27` |
| Note body | `font:400 13.5px/1.5 'Newsreader',serif; color:#4a3b2e; white-space:pre-wrap`; binds the full text | `bodySerif` = Newsreader **16** w400 height 1.5 ink. Empty text falls back to `'Empty note'` in `bodySerifItalic` muted | medium | proto `:118`, `:1577` / `lib/features/entry_cards/cards/note_body.dart:12-18` |
| Photo strip | Strip `display:flex; gap:8px; margin-top:10px; padding-top:10px; border-top:1px dashed rgba(74,59,46,.25)`. Thumbnail `56x56; border-radius:9px; border:1.5px solid #4a3b2e`, hatched `#e2d3ba/#ecdfc8` at 5px/10px pitch, caption `500 6px ui-monospace` `#8a7358` bottom-centred, `padding-bottom:3px` | Horizontal `ListView.separated` preceded only by `SizedBox(height: 12)` — **no dashed separator**. Thumbnails `72` square, spacing 8, radius 11, via `MediaImage` with no border and no caption | medium | proto `:134`, `:136` / `lib/features/entry_cards/entry_card.dart:51-54`, `lib/features/entry_cards/cards/photo_strip.dart:13-14`, `:26-40` |
| Voice row | Play button 38x38 circle `#c76a54` with `1.5px #4a3b2e` border and a 15x15 white play glyph at `margin-left:2px`; gap 12. Waveform `flex:1`, **14 static bars**, width 3, gap 2.5, container height 24, ratios `[.4,.75,1,.55,.85,.35,.7,.5,.9,.45,.65,.8,.38,.6]`, radius 2, three-tone ramp `#c76a54 / #dcae9a / #e3c4b2`. Duration `600 11px 'Instrument Sans'` `#a08a70` | Play toggle 40x40 coral circle with outline and a 14x14 painted glyph, no optical offset. `WaveformBars` defaults: **5 bars**, width 3, spacing 3, maxHeight 20, minHeightFactor 0.35, single coral, sine-animated while playing. Duration shows elapsed/total | high | proto `:121-124`, `:1579` / `lib/features/entry_cards/cards/voice_body.dart:201-218`, `:240-254`, `lib/design/motion/waveform_bob.dart:9-19` |
| Video tile | `height:130px; border-radius:10px; overflow:hidden`, hatch `(45deg,#d9c9ae,#d9c9ae 6px,#e2d3ba 6px,#e2d3ba 12px)`, `border:1.5px solid #4a3b2e`. Centred 44x44 play badge on `rgba(255,251,244,.92)` with `1.5px #4a3b2e` border and a 17x17 `#4a3b2e` glyph. Duration chip `bottom:8px right:9px`, `600 10px 'Instrument Sans'` `#fff` on `rgba(42,36,29,.7)`, radius 8, padding 2px 8px | Live player at `21/9` with `_videoMinHeight = 200`, plus control bar, scrubber, transport, controls overlay. No 130px still tile, no 44x44 badge, no corner chip | high | proto `:127-129` / `lib/features/entry_cards/cards/video_body.dart:23-25`, `:13-16` |
| Feed empty state | `border:1.5px dashed rgba(74,59,46,.4); border-radius:16px; padding:34px 20px; text-align:center`, no fill, no shadow. Headline `Nothing planted yet today` `500 17px 'Newsreader'` `#4a3b2e`. Sub `Capture a moment — write it, speak it, or film it.` `400 12px 'Instrument Sans'` `#a08a70` `margin-top:3px` | `EmptyStatePlaceholder`, one message `'Nothing captured yet today.'` in `bodySans` (Instrument Sans 14 w400 ink), dashed border at **full-opacity** ink, radius **14**, padding 24h/28v. No serif headline, no sub-line | medium | proto `:145-147` / `lib/features/today/today_entry_feed.dart:14`, `:48`, `lib/design/feedback/empty_state.dart:13-16`, `:42` |

### 3.4 Today — right rail

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Rail column | `width:266px; flex:none; overflow-y:auto; padding:24px 20px; border-left:1px dashed rgba(74,59,46,.22); display:flex; flex-direction:column; gap:18px`. Its own `.fn-scroll` column, scrolling independently inside a fixed 724px body | `todayRailWidth = 300`; separated by `SizedBox(width: 24)`; **no dashed left border**, no rail-local padding. The whole screen is one `SingleChildScrollView` wrapping a Row, so the rail scrolls with the feed | medium | proto `:152`, `:87` / `lib/features/today/today_layout.dart:3`, `lib/features/today/today_screen.dart:44-57` |
| Section containers | Each of the three sections is a bare `<div>` with **no** background, border, radius, shadow or padding. Separation is by two `height:1px; background:rgba(74,59,46,.16)` hairlines and the column's 18px gap | Every section is wrapped in a `StickerCard`: `cardLight` `0xFFFFF5EA`, 1.5px ink outline, radius 16, `Shadows.card`, `EdgeInsets.all(16)`. Sections spaced by `SizedBox(height: 16)`; **no separators at all** | critical | proto `:153`, `:162`, `:163`, `:171`, `:172` / `lib/features/today/this_week_garden.dart:24`, `today_capture_buttons.dart:71`, `on_this_day_card.dart:94`, `today_right_rail.dart:23`, `:25` |
| Section headers | Lowercase Caveat `600 17px` `#7d8450`: `this week's garden` (`margin-bottom:2px`), `capture a moment` (`margin-bottom:10px`), `on this day` (`margin-bottom:9px`) | Title-case `'This week'`, `'Quick capture'`, `'On this day'`, all `eyebrowAccent` = Caveat **20** w600 sage, each followed by `SizedBox(height: 10)` | medium | proto `:154`, `:164`, `:173` / `this_week_garden.dart:14`, `:30`, `today_capture_buttons.dart:15`, `:77`, `on_this_day_card.dart:14`, `:100` |
| Week date range | Subtitle `{{ weekRange }}` e.g. `Jun 30 – Jul 6` (en dash U+2013, 3-letter months, no year) at `400 10px 'Instrument Sans'` `#a08a70` `margin-bottom:11px`, between header and grid | No date-range line; header goes straight to `SizedBox(height: 10)` and the day row | medium | proto `:155` / `lib/features/today/this_week_garden.dart:30-32` |
| Week grid | `display:grid; grid-template-columns:repeat(4,1fr); gap:8px` holding 7 cells — a ragged 4+3 block. Cell width = (266 − 40 − 24) / 4 = 50.5px | A single `Row` with `MainAxisAlignment.spaceBetween` containing all 7 cells — one 7-across strip | critical | proto `:156` / `lib/features/today/this_week_garden.dart:32-38` |
| Week cell chrome | Every day is a tile: `text-align:center; border-radius:10px; padding:6px 0 4px`. **Filled** `background:#f8efe0; border:1.5px solid #4a3b2e; box-shadow:1.5px 1.5px 0 rgba(74,59,46,.18)`. **Today** `background:#fff5ea; border:1.5px solid #c76a54; box-shadow:1.5px 1.5px 0 rgba(199,106,84,.3)`. **Empty** `background:transparent; border:1.5px dashed rgba(74,59,46,.35)`, no shadow, holding a 27x27 circle `border:1.5px dashed #c3b39a` | No cell container of any kind. Each day is a bare Column of `SizedBox.square(26)` + label. Filled paints `FlowerBloom.forMood(mood, size: 26)`; empty paints `DashedBorderPainter(color: Palette.placeholder 0xFFB3A58C, radius: 13)` — wrong dash colour, no tile | critical | proto `:1606`, `:1608-1610` / `lib/features/today/this_week_garden.dart:59-84`, `:15`, `:62-72` |
| Week cell label | `font:600 8px 'Instrument Sans'; margin-top:1px`; colour state-dependent — today `#c76a54`, has-bloom `#a08a70`, empty `#c3b39a` | `captionSans` (12 w500 muted) for all non-today; today overrides to coral + w700. **Empty days share the has-bloom colour.** Spacing above the label is `SizedBox(height: 6)` vs 1px | high | proto `:1611` / `lib/features/today/this_week_garden.dart:73-82` |
| Week cell interaction | Every cell carries `onClick -> this.setView('desktop','calendar')` and `cursor:pointer` | Cells are wrapped only in `Semantics`/`ExcludeSemantics`; no `GestureDetector`, no navigation | medium | proto `:1607` / `lib/features/today/this_week_garden.dart:54-58` |
| Capture stack | Exactly **three** rows in fixed order: `Write a note` (**primary**), `Record voice`, `Record video`. Primary `background:#c76a54; color:#fff; box-shadow:2px 2px 0 #4a3b2e`. Outlined rows `background:#f8efe0`, **no shadow**. Each `display:flex; align-items:center; gap:10px; border-radius:12px; padding:10px 13px` with a 17x17 stroked icon before the label — pencil stroked `#fff`, mic and video stroked `#4a3b2e`, stroke-width 2, round caps. Label `600 12px 'Instrument Sans'` | **Four** buttons: a primary `'Capture'` chooser button, then the three per-type buttons all at `variant: secondary`, each `SizedBox(height: 8)` apart. **No icons passed to any of them.** Labels `buttonSans` (15 w600). All carry `Shadows.button` | high | proto `:165-168`, `:1595-1601` / `lib/features/today/today_capture_buttons.dart:79-88`, `lib/features/capture/core/capture_route.dart:21-36` |
| On-this-day card | Card `background:#f8efe0; border:1.5px solid #4a3b2e; border-radius:13px; overflow:hidden; box-shadow:2px 2px 0 rgba(74,59,46,.16)`, with the header **outside** it. An 82px band `repeating-linear-gradient(45deg,#e2d3ba,#e2d3ba 6px,#ecdfc8 6px,#ecdfc8 12px)` centring `memory · 1 year ago` at `500 7px ui-monospace,monospace` `#a08a70`. Text block `padding:9px 11px`: title `500 12px 'Newsreader'` `#4a3b2e`, meta `Jul 5, 2024 · felt warm` at `400 9px 'Instrument Sans'` `#a08a70` `margin-top:1px`. No glyph, no preview | No hatched band. A Row of an optional `FlowerBloom.forMood(mood, size: 34)` plus `yearsAgoLabel` in `labelSans`, `longDateLabel` (full weekday + year) in `captionSans`, and an optional 2-line italic preview capped at 90 chars — inside the generic `StickerCard` (radius 16, `Shadows.card`, padding 16), header **inside** the card | high | proto `:173-176` / `lib/features/today/on_this_day_card.dart:45-78`, `:54-87`, `:93-106`, `lib/features/today/today_date.dart:53-55` |

### 3.5 Flower art

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Compact glyph silhouette | `flower(mood)` glyphs are **headless**: viewBox `0 0 44 44` filled edge-to-edge by the bloom only. No stem, no leaf, on 9 of 10 flowers. Bleeding Heart alone carries an arching branch stroked `#6f8a4e` at width 1.8 | `FlowerPainter.paint()` calls `_straightStem()` before every style except `heartPendants`, drawing a stem to `size.height*0.98` (`spec.stemColor` `#A0B371`, width `max(1.5, d*0.045)`) plus a filled leaf lobe at `y = height*0.72`. The bloom head is pushed to `center = (width/2, height*0.42)`, occupying only the top ~55% | critical | proto `:1045-:1056`, `:1052` / `lib/design/flowers/flower_painter.dart:18-39`, `:73-89` |
| Art-set architecture | **Two entirely separate sets.** `flower(mood)` = 44x44 headless glyph for chips/calendar/week/day shelf/picker. `gardenPlant(mood)` = a separately memoized full botanical plant with its own stem, leaves, thorns, sepals and buds at a **tall** viewBox (`0 0 100 240` ratio 2.4 sunflower, `0 0 100 190` ratio 1.9 peony/lavender; observed vb values 190, 196, 200, 205, 206, 210, 214, 236, 240 — none square), rendered `preserveAspectRatio='xMidYMax meet'` | **One painter serves both.** The meadow calls `FlowerPainter(flowerSpecFor(bloom.kind)).paint(canvas, Size.square(bloom.size))` — a 1:1 box — and the same painter/spec serves every compact site | critical | proto `:1071`, `:1198` / `lib/features/garden/paint/meadow_painter.dart:95-105`, `lib/design/flowers/flower_bloom.dart:40-43` |
| Per-flower stroke colour | Every flower has its own stroke hue, a darkened relative of its petal: Peony `#8a4a4a`, Sunflower `#9a6a2a`, Rose `#7d2f3a`, Poppy `#7d2a24`, Lavender `#6a5a8a`, Bleeding Heart `#a8536c` (branch `#6f8a4e`), Spider Lily `#d8342a` / stamens `#a82218`, Aster `#7a68a4` (disc `#c98a2a`), Daffodil `#d8b84a` (corona `#c9821f`), Chrysanthemum `#b9701f` | One stroke `Paint` for all 12 specs: `color = Palette.ink` `0xFF4A3B2E`. `FlowerSpec` has no per-flower stroke colour field at all | high | proto `:1045-:1056` / `lib/design/flowers/flower_painter.dart:42-47`, `lib/design/flowers/flower_spec.dart:9-37` |
| Per-flower stroke width | Varies across a 0.8-1.8 span in the 44-unit box: Chrysanthemum 0.8, Aster 0.9, Sunflower 1.0, Lavender 1.0, Daffodil 1.2, Rose / Poppy / Bleeding Heart 1.3, Peony 1.4, Red Spider Lily 1.8 | `strokeWidth = max(Shapes.outlineWidth 1.5, d * 0.03)` for every flower — at 56px that is 1.68; at 44px and below it clamps to a flat 1.5 | medium | proto `:1045-:1056` / `lib/design/flowers/flower_painter.dart:45` |
| Peony (happy) | 6 overlapping circles in paint order: `(22,15,r8) #f2a9b2`, `(14,22,r8) #ed97a4`, `(30,22,r8) #ed97a4`, `(18,29,r8) #f2a9b2`, `(26,29,r8) #f2a9b2`, centre `(22,23,r6.5) #e4788a`. Stroke `#8a4a4a` width 1.4, linejoin round | `roundPetals`, petalCount 12 → 12 teardrop petals plus a second offset ring of 12 (rounded && count>=8) = **24 petal shapes**, plus a centre circle `r=0.12d`. Colours petal `0xFFE6A2B4`, shade `0xFFD07E93`, centre `0xFFEFC7A0` (a peach/tan, not pink) | critical | proto `:1045` / `lib/design/flowers/flower_spec.dart:40-50`, `lib/design/flowers/flower_painter.dart:91-124` |
| Rose (love) | Filled disc `circle(22,22,r14) #d76a76` with **two open spiral arcs** `M22 10a12 12 0 1 1-8 21` and `M22 14a8 8 0 1 1-5 14` (`fill:none`) and centre `circle(22,22,r3.5) #a83f4d` stroke none. Group stroke `#7d2f3a` width 1.3. A spiral, not a petal ring | `roundPetals`, petalCount 8 → 8 petals + the 8-petal shade ring = 16 shapes, centre `r=0.10d`. No arc-drawing code anywhere in the painter. Petal `0xFFC76A54` (the brand coral), shade `0xFF9A4832`, centre `0xFF7D3B2B` | critical | proto `:1047` / `lib/design/flowers/flower_spec.dart:51-61` |
| Red Spider Lily (angry) | **All-stroke**, `fill='none'` on the wrapper. 6 recurved quadratic petals stroked `#d8342a` width 1.8 round caps, **4** thin stamens stroked `#a82218` width 1, centre `circle(22,23,r2.4)` filled `#7d1a14`. Petal tips reach x=2..42, y=3 | `spiderPetals`, petalCount 8: each petal is a **closed** quadratic loop **filled** `0xFFC0392B` and stroked in ink, with one straight stamen per petal (8), plus a centre `r=0.06d` filled `0xFFC0392B` (identical to the petal, so the centre disappears), plus a stem and leaf | critical | proto `:1053` / `lib/design/flowers/flower_spec.dart:139-149`, `lib/design/flowers/flower_painter.dart:126-148` |
| Sunflower (warm) | 8 ellipse petals `rx3.4 ry7` at `cx22 cy9` rotated 0/45/…/315 about `(22,22)`, fill `#f2c14e`; centre disc `circle(22,22,r7) #7a4a24`; group stroke `#9a6a2a` width 1 | `rayPetals`, petalCount **16**, petal length 0.30d width 0.10d; centre `r=0.20d`. Petal `0xFFE6B34D`, centre `0xFF6E4A2A` | high | proto `:1046` / `lib/design/flowers/flower_spec.dart:62-72` |
| Aster (anxious) | 12 ellipse petals `rx2.3 ry7` every 30deg, fill `#a892cf` (**violet**); centre `circle r5.5` fill `#f2c14e` with its **own** stroke `#c98a2a` width 1.2; petal stroke `#7a68a4` width 0.9 | `rayPetals`, petalCount **22**, length 0.34d width 0.06d, centre `r=0.10d`. Petal `0xFF7E8FC9` (periwinkle **blue**, hue ~225 vs ~264), shade `0xFF6374B0` (unreachable for rayPetals), centre `0xFFE6B34D`. Centre gets the shared ink stroke | high | proto `:1054` / `lib/design/flowers/flower_spec.dart:106-116` |
| Chrysanthemum (grateful) | **Two petal rings**: outer 12 ellipses `rx2.2 ry8` at `cy7` every 30deg fill `#d98a3c`; inner 9 ellipses `rx2 ry6` at `cy12` at 20deg offset / 40deg step fill `#efb663`; centre `circle r3 #a85f18`; stroke `#b9701f` width 0.8 (thinnest glyph in the set) | `rayPetals`, petalCount 20 — a **single** ring (the second ring is gated on `rounded == true`, so rayPetals never gets it). `petalShade 0xFFC46E31` is dead for this flower. Petal `0xFFE0894A`, centre `0xFFB25E28` | high | proto `:1056` / `lib/design/flowers/flower_spec.dart:73-83`, `lib/design/flowers/flower_painter.dart:108-121` |
| Daffodil (hopeful) | 6 petals `ellipse rx4 ry8.5` at 60deg steps fill `#f5df84` stroke `#d8b84a` 1.2, then a **three-ring trumpet** all at `(22,22)`: `r7 #f0a838` stroke `#c9821f` 1.3, `r4 #e88f22` stroke none, `r1.8 #8a5a12` stroke none | 6 rayPetals (count matches) but the corona is a **single flat circle** `r=0.14d` filled `0xFFE0894A` with the generic ink stroke. Petal `0xFFF0C64B` (markedly more saturated) | high | proto `:1055` / `lib/design/flowers/flower_spec.dart:84-94` |
| Lavender (calm) | 9 upright ellipses in a fixed tapering arrangement — `(22,6,2.7x3.7)` at the tip, then paired rows `(18/26,11)`, `(16/22/28,17)`, `(18/26,23)`, `(22,29)` — a symmetric **1-2-3-2-1** spike. Fill `#9a86c4`, stroke `#6a5a8a` 1. No centre, no stem, no leaf | `spike`: 9 ovals placed by loop, alternating strictly left/right (`side = (i.isEven ? -1 : 1) * spread`) with spread growing 0.4→1.0; oval `w = spread*0.9`, `h = spread*1.3`. A **zig-zag two-column ladder**, not the taper. Plus a stem and leaf | high | proto `:1051` / `lib/design/flowers/flower_spec.dart:95-105`, `lib/design/flowers/flower_painter.dart:150-168` |
| Bleeding Heart (sad) | Arch `M6 9 Q 20 4 36 11` stroked `#6f8a4e` width 1.8 round cap; **three** pendant hearts at x=13, x=22 (hung 3 lower at y=18), x=31, fill `#e07d98`, stroke `#a8536c` 1.3, each with a white teardrop e.g. `M11.7 21 L13 26 L14.3 21 Z` fill `#fbeef0` | `heartPendants` with petalCount **4** → four hearts. The "arch" is a long cubic from `(0.20w, 0.95h)` to `(0.85w, 0.18h + 0.05d)` — it **descends to the bottom** of the box like a stem. Branch colour `spec.stemColor 0xFFA0B371` (much lighter, yellower). Heart `0xFFCE7A9A`; teardrop `0xFFFFF5EA` | high | proto `:1052` / `lib/design/flowers/flower_spec.dart:128-138`, `lib/design/flowers/flower_painter.dart:194-221` |
| Poppy (tired) | 4 equal lobes `circle r8` at `(22,13),(13,24),(31,24),(22,30)` all `#e0574a`, centre `circle(22,22,r5) #3a2420`, stroke `#7d2a24` width 1.3 | `broadPetals`, petalCount 4 (structure is the closest of any flower), length 0.32d width 0.34d, centre `r=0.14d`. Petal `0xFFC64B3A` (darker/browner), centre `0xFF3A2A22` (near-identical), stroke ink `0xFF4A3B2E` | medium | proto `:1050` / `lib/design/flowers/flower_spec.dart:117-127` |
| Glyph size ladder | Desktop: 54 Today mood card, 46 empty-state ghost and day-detail strip, 44 picker tile, 40 calendar cell and day-list row, 32 nav brand, 27 week-garden cell, 24 garden tally chip | Today banner **44** (proto 54); picker tile **56** (proto 44); calendar cell **28** (proto 40); day-list row 40 (match); week cell **26** (proto 27); garden tally chip **18** (proto 24); garden empty-state 44 (no counterpart) | medium | proto `:94`, `:101`, `:444`, `:61`, `:1606` / `mood_banner.dart:34`, `mood_picker_grid.dart:12`, `calendar_day_cell.dart:51`, `this_week_garden.dart:15`, `mood_tally_chips.dart:50` |

### 3.6 Mood picker

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Text decoration | No `text-decoration` on the title or any tile label | **Every `Text` in the picker is drawn with a yellow double underline.** `MaterialApp` passes `WidgetsApp.textStyle: _errorTextStyle` (`TextStyle(color 0xD0FF0000, monospace, 48px, w900, decoration: underline, decorationColor 0xFFFFFF00, decorationStyle: double, debugLabel 'fallback style; consider putting your text in a Material')`). `showMoodPicker` builds the sheet via `showGeneralDialog`'s `pageBuilder` into the root overlay with **no Material ancestor**, so the ambient `DefaultTextStyle` is that fallback. The tokens leave `decoration` null with `inherit: true`, so `merge()` keeps it | critical | proto `:440` / `lib/features/mood/mood_picker.dart:14-29`, `lib/app/app.dart:20`, Flutter SDK `material/app.dart:45-54`, `:1091` |
| Grid columns | `display:grid; grid-template-columns:repeat(4,1fr); gap:10px; margin-top:16px` — 10 tiles flow **4 + 4 + 2**, last row left-aligned | `Wrap(alignment: center, spacing: 16, runSpacing: 16)`. Tile = 56 glyph + 8 + 8 padding = 72px; available = 360 − 20 − 20 = ~317px. `4*72 + 3*16 = 336 > 317`, so the Wrap breaks at **three** per row: 3 + 3 + 3 + 1, every row centred | critical | proto `:442` / `lib/features/mood/mood_picker_grid.dart:25-39`, `lib/features/mood/mood_picker_sheet.dart:15`, `:29-30` |
| Unselected tile | A visible card: `background:#fffaf1; border:1.5px solid rgba(74,59,46,.2); border-radius:14px; padding:11px 6px` | `color: null`, `border: null` — fully transparent with no outline; only radius 11 and padding 8/8 | high | proto `:1554` / `lib/features/mood/mood_picker_grid.dart:64-76` |
| Selected tile | `background:#fff5ea; border:2px solid #c76a54` (up from 1.5); `border-radius:14px; box-shadow:2px 2px 0 rgba(199,106,84,.3)` | `color: Palette.panelCoralTint 0x12C76A54` (7% coral wash, not `#fff5ea`); `Border.all(Palette.coral, width: 1.5)` — same width as the prototype's **unselected** border; radius 11; **no shadow** | medium | proto `:1553` / `lib/features/mood/mood_picker_grid.dart:64-74` |
| Tile labels | Two lines: mood name `600 11px 'Instrument Sans'` `#4a3b2e` `margin-top:5px`; flower name `400 9px 'Instrument Sans'` `#a08a70`. The second line is present on desktop, omitted only on the phone sheet | `FlowerBloom` + `SizedBox(height: 6)` + a single `Text(mood.label)` in `captionSans` (12 w500 `Palette.muted`). **The flower name is never rendered** although `FlowerKind.label` exists and is correct | high | proto `:444` / `lib/features/mood/mood_picker_grid.dart:77-84`, `:82` |
| Tile glyph | `span 44x44` — the 44-unit viewBox rendered 1:1 | `flowerSize` default **56** | medium | proto `:444` / `lib/features/mood/mood_picker_grid.dart:12` |
| Panel chrome | `width:420px` **fixed**; `background:#f8efe0; border:2px solid #4a3b2e; border-radius:20px; padding:22px; box-shadow:0 20px 50px -16px rgba(50,35,20,.6)` (large soft lift) | `StickerCard` surface `cardBright` `0xFFFFFAF1` (near-white), border 1.5px, radius 16, padding 20, shadow `Offset(3,3)` blur 0 `0x334A3B2E`. Width `ConstrainedBox(maxWidth: 360)`, shrink-wrapping smaller | high | proto `:439` / `lib/features/mood/mood_picker_sheet.dart:15`, `:26-30` |
| Title | `font:500 21px 'Newsreader',serif; color:#4a3b2e; text-align:center`. Copy `How are you feeling?` matches | `titleSerif` = Newsreader **24** w600 height 1.2 ink | low | proto `:440` / `lib/features/mood/mood_picker_sheet.dart:14`, `:34` |
| Subtitle | A Caveat line under the title: `600 14px 'Caveat',cursive; color:#a08a70; text-align:center; margin-top:1px`, copy `choose today's bloom` | No subtitle widget exists; no Caveat-family text appears anywhere in the picker | high | proto `:441` / `lib/features/mood/mood_picker_sheet.dart:31-40` |
| Scrim | `rgba(42,36,29,.28)` (phone sheet uses `.34`) | `Palette.ink.withValues(alpha: 0.32)` = `rgba(74,59,46,.32)` — lighter, warmer, higher opacity | low | proto `:438` / `lib/features/mood/mood_picker.dart:18` |
| Entrance | `@keyframes fn-pop`: opacity 0→1 with `scale(.96)→scale(1)`, `.18s ease-out` | `showGeneralDialog` 220ms, `Curves.easeOutCubic`, fade + scale `0.92 → 1.0` | low | proto `:24`, `:439` / `lib/features/mood/mood_picker.dart:8`, `:19`, `:36-46` |
| Phone form factor | A **bottom sheet**: scrim `align-items:flex-end`; panel `width:100%; border-top:2px solid #4a3b2e` only; `border-radius:22px 22px 0 0; padding:18px 16px 22px; box-shadow:0 -12px 30px -12px rgba(50,35,20,.5)`; `fn-sheet` slide-up `.24s cubic-bezier(.2,.8,.2,1)`; a 38x4 grab handle (radius 3, `rgba(74,59,46,.3)`, `margin:0 auto 12px`); tiles compact at `padding:8px 4px` with 34x34 glyphs and **no** second label line | One centred dialog for every form factor. No bottom-sheet layout, no grab handle, no compact tile variant anywhere in the mood feature | medium | proto `:732` (phone sheet — **not** `:439`, which is the desktop panel), `:1553-1554` (`compact` tile padding) / `lib/features/mood/mood_picker_sheet.dart:25-44` |
| Re-pick confirmation | Picking a mood for a day that already has one opens a confirm first: title `Change today's bloom?` (or `Change this day's bloom?`), message `Set <dayLabel> to <flowerName> · <moodLabel>? Your current bloom will be replaced.`, confirmLabel `Change mood`, `danger:false`. On confirm: `play('pencil')`, set the mood, then toast `Mood planted · <flowerName>` | `_changeMood` awaits the picker and writes immediately via `journalRepository.setMoodForDate` — no confirmation, no toast, no sound. Only a failure path sets an inline error | medium | proto `:1345` / `lib/features/mood/mood_banner_for_date.dart:28-49` |

### 3.7 Capture composers

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Text decoration in composers | No decoration anywhere; title is `600 16px 'Caveat',cursive; color:#c76a54` | Same root cause as the picker: all four capture dialogs are built by `showGeneralDialog` `pageBuilder` with no Material ancestor, so every `Text` renders with a **double yellow underline** | critical | proto `:465` / `text_composer.dart:96-109`, `voice_composer.dart:144-157`, `video_composer.dart:342-355`, `capture_chooser.dart:16-32` |
| Composer panel | **One shared panel for all three modes**: `position:relative; width:760px; background:#fbf3e4; border:2px solid #4a3b2e; border-radius:20px; overflow:hidden; box-shadow:0 44px 96px -30px rgba(30,20,10,.72)` | Three separate cards at different widths — text 420, voice 420, video 460, chooser 360 — each a `StickerCard` with `cardBright` `0xFFFFFAF1`, 1.5px border, radius 16, hard `Offset(3,3)` shadow | high | proto `:460` / `text_composer_sheet.dart:19`, `voice_recorder_sheet.dart:25`, `video_recorder_sheet.dart:40`, `capture_chooser_sheet.dart:15` |
| Scrim | `radial-gradient(120% 100% at 50% 32%, rgba(42,32,22,.36), rgba(28,20,12,.62)); backdrop-filter:blur(7px); animation:fn-fade .22s ease` | Flat `barrierColor: Palette.ink.withValues(alpha: 0.32)`, no gradient, no backdrop blur, on all four dialogs | medium | proto `:459` / `video_composer.dart:347`, `voice_composer.dart:149`, `text_composer.dart:101`, `capture_chooser.dart:20` |
| Corner sprig art | `position:absolute; top:-10px; right:-8px; width:120px; height:150px; opacity:.4; pointer-events:none` — an SVG stem stroked `#8a9a63` at 2.2 with three leaves filled `#9bb078` / `#8fa66c` / `#a3b782` | No decorative art on any composer card | medium | proto `:461` / `text_composer_sheet.dart:62-68` |
| Composer header bar | `padding:14px 18px; border-bottom:1.5px dashed rgba(74,59,46,.25)`: a 22x22 close icon at left; a centred two-line block (`line-height:1.1`) of title `600 16px 'Caveat'` `#c76a54` over meta `{{ longDate }} · {{ clock }}` at `400 9px 'Instrument Sans'` `#a08a70`; save pinned right — `600 12px 'Instrument Sans'; color:#fff; background:#c76a54; border:1.5px solid #4a3b2e; border-radius:13px; padding:7px 15px; box-shadow:1.5px 1.5px 0 #4a3b2e` | A single left-aligned `Text('Write a note')` in `titleSerif` with 12px below it. No close icon, no date/time meta, no dashed rule; the save button lives in a bottom-right row | high | proto `:463-466` / `text_composer_sheet.dart:15`, `:69-70`, `:126-153` |
| Note writing surface | `position:relative; height:440px; margin:0 -18px; border-top:1px dashed rgba(74,59,46,.2)` — bleeding past the body's `padding:0 18px 14px` (the body div is `:468`). Paper background `#fbf3e4`, page padding `44px 54px 120px`, scrolling with a 9px custom scrollbar. Editor `'Newsreader', Georgia, serif; font-size:19px; line-height:38px; color:#4a3b2e` | A bordered inset box: `cardWarm` fill, 1.5px outline, radius 11, padding 12h/10v, containing an `EditableText` in `bodySerif` (Newsreader 16 w400 height 1.5), `minLines: 4`, `maxLines: 8` | high | proto `:469` (surface), `:468` (body) / `text_composer_sheet.dart:71-116` |
| Editor placeholder | `Start writing…  try “# ” for a title, “- ” for a list, “1. ” for steps` (two spaces after the ellipsis, curly quotes), italic Newsreader 19px/38px at ink 34% alpha, `top:44px left:54px`. *(Copy lives in the md-scrapbook editor mounted from the `:469` noteRef, not in inline markup — the copy string itself is `[unverified]` against a `.dc.html` line.)* | `'What happened today?'` in `bodySans` (Instrument Sans 14 w400 height 1.45) recoloured to `Palette.placeholder`, upright, at the top-left of the 12/10 padded box | high | proto `:469` (mount point only) / `text_composer_sheet.dart:15`, `:95-99` |
| Markdown engine | Live block styles (h1 `600 34/44`, h2 `600 26/38`, h3 `600 21/34` at ink 82%, quote with a 3px `#c76a54` left rule and italic ink@72%, ordered-list markers in `#c76a54`, todo check, inline code `ui-monospace` on ink@8%, highlight on accent@28%), a floating selection toolbar (`background:#2a241d`, radius 11, 30x30 buttons, Newsreader glyphs), and a footer legend `# title  - list  1. steps  > quote  [] to-do` at `400 10px 'Instrument Sans'` `#a08a70` with markers bold in `#7d6a52` | Plain `EditableText` — no markdown parsing, no block styles, no selection toolbar, no legend | high | proto `:473` (legend), `:1360-1368` (engine) / `text_composer_sheet.dart:103-112`, `:117-125` |
| Add memory | Footer button `background:#c76a54; color:#fff; border:1.5px solid #4a3b2e; border-radius:11px; padding:8px 13px; box-shadow:1.5px 1.5px 0 #4a3b2e; gap:7px`; 16x16 photo icon; label `Add memory` `600 12px 'Instrument Sans'`. It drops a 210x168 tape-framed photo card (rotation random −4..+4deg) onto a free-manipulation layer over the text | No photo affordance at all; the footer is only Cancel + Save note | high | proto `:471` (button), `:470` (footer row, `gap:10`) / `text_composer_sheet.dart:125-154` |
| Text composer copy | Title `New note` (or `Edit note`, or `New note · <day>`); save label `Save` / `Save changes`; edit-save confirm `Save changes?` / `Update this note with your edits?`; empty-save guard toast `Write something first` | Title fixed at `'Write a note'`; save `'Save note'` with saving label `'Saving...'` (three ASCII periods); no edit variants, no confirm; empty input disables the button at `Opacity(0.5)` | medium | proto `:1694-1695`, `:1387-1388` / `text_composer_sheet.dart:15-18`, `:142-150` |
| Voice record control | 92x92 circle; `border-radius:50%; background:#c76a54; border:2.5px solid #4a3b2e; box-shadow:0 10px 24px -8px rgba(199,106,84,.7)`; 38x38 white mic icon (pause fill `#fff` while recording); centred in a 150x150 stage `margin:14px auto 6px` | `StickerButton('Record')` primary in a bottom-right Row next to `StickerButton('Cancel')`; no circular control, no icon anywhere | critical | proto `:485` (92x92 button), `:483` (150x150 stage) / `voice_recorder_sheet.dart:21-22`, `:76-87`, `:95-103` |
| Voice elapsed time | `font:400 38px 'Newsreader',serif; color:#4a3b2e`, below the record button; value M:SS starting at `0:00`, ticked every 250ms | No timer is rendered. `RecordVoiceRecorder` keeps a private `Stopwatch` and only reports `durationMs` at `stop()` | critical | proto `:487` (readout), `:1396` (`startRec` 250ms interval) / `voice_recorder_sheet.dart:119-167`, `record_voice_recorder.dart:27`, `:56-71` |
| Voice pulse halo | 150x150 absolute circle behind the button: `background:radial-gradient(circle, rgba(199,106,84,.4), transparent 68%); animation:fn-pulse 2.4s ease-in-out infinite`, gated on recording | No halo. A `GlowPulse` widget exists (coral, 1500ms, maxBlur 16, maxSpread 2, maxAlpha .55) with **zero call sites** | high | proto `:484` (halo), `:21` (`fn-pulse` keyframe: `scale(.9)/opacity .5 -> scale(1.25)/opacity .18`) / `voice_recorder_sheet.dart:129-143`, `glow_pulse.dart:6-17` |
| Voice waveform | Row `gap:3px; height:40px; margin:12px 0 4px`; exactly **12** bars, each `width:4px; border-radius:3px`; heights `[.30,.65,.95,.50,.80,.40,1.00,.55,.85,.35,.70,.45]` of 40px; colour `#c76a54` when h>0.6 else `#dcae9a`; `fn-bob` (scaleY .45→1) with per-bar durations 0.7/0.85/1.0/1.15s | `WaveformBars` defaults: 5 bars, width 3, spacing 3, maxHeight 20, minHeightFactor 0.35, single coral, one 700ms controller with a phase-shifted sine; rendered inline between the blink dot and the hint | high | proto `:489` (container), `:490` (mount), `:1261-1263` (bar generator) / `waveform_bob.dart:9-19`, `voice_recorder_sheet.dart:137` |
| Voice idle rule | `width:120px; height:2px; border-radius:2px; background:rgba(74,59,46,.18)` whenever not recording | A 12x12 muted dot with a 1.5px ink border plus hint text; no flat rule | medium | proto `:491` / `voice_recorder_sheet.dart:154-163` |
| Voice header + hints | Header `New voice memo` `600 16px 'Caveat'` `#c76a54` `margin-top:4px`. Hint `tap the mic when you're ready` `600 15px 'Caveat'` `#a08a70`; recording `listening… speak freely`; paused `paused · resume when you're ready` | Title `'Record voice'` in `titleSerif`. Hint `'Tap record when you are ready.'` in `captionSans`; recording `'Recording…'`; saving `'Saving your recording…'` | high | proto `:480` (header), `:488` (hint), `:1703` (hint strings) / `voice_recorder_sheet.dart:17-20`, `:59`, `:140`, `:160` |
| Voice recording status row | `gap:7px`; 8x8 dot `border-radius:50%; background:#c0392b` with `fn-blink 1.2s step-end infinite` (hard on/off) + label `Recording` `600 12px 'Instrument Sans'; letter-spacing:.08em; text-transform:uppercase; color:#c0392b` | 12x12 dot `Palette.danger` with a 1.5px ink border, wrapped in `Blink` (900ms `easeInOut`, fading 1.0→0.2, reversing), 12px gap, label `'Recording…'` in `captionSans` (muted, no letter-spacing, not uppercase) | medium | proto `:481` / `voice_recorder_sheet.dart:130-143`, `blink.dart:9-11`, `:31-33` |
| Voice paused state | `recState 'paused'`: 8x8 **static** `#c9821f` dot + `Paused` `600 12px 'Instrument Sans'; letter-spacing:.08em; uppercase; color:#c9821f`; hint `paused · resume when you're ready` | `VoiceRecorderPhase` has only idle/recording/saving; the interface exposes no pause/resume. `Palette.statusAmber 0xFFC9821F` is the exact hue and is unused here | high | proto `:481-482` / `voice_recorder_sheet.dart:7`, `voice_recorder.dart:30-40`, `palette.dart:36` |
| Voice review pills | Shown while recording is active. Discard: `background:#fbecea; color:#c0392b; border:1.5px solid #c0392b; border-radius:22px; padding:10px 18px`, 15x15 trash icon, label `600 13px 'Instrument Sans'`. Save: `background:#c0392b; color:#fff; border:2px solid #4a3b2e; border-radius:22px; padding:11px 22px; box-shadow:2px 2px 0 #4a3b2e`, leading 15x15 white rounded square (radius 4), label `Save memo` | No pills. The same Cancel / `'Stop & save'` sticker buttons persist through every phase. `StickerButtonVariant.danger` exists but is never used in the voice sheet | high | proto `:495` (Discard), `:496` (Save memo), `:494` (row) / `voice_recorder_sheet.dart:76-103` |
| Video panel | Dark camera viewport filling the shared 760px panel: `position:relative; height:480px; background:repeating-linear-gradient(45deg,#3a352e,#3a352e 8px,#443f37 8px,#443f37 16px)`. No header, no light body. Viewport 760x480 (1.583:1) | Light `StickerCard`: `cardBright` fill, `EdgeInsets.all(20)`, `maxWidth 460`, radius 16, 1.5px outline, `Shadows.card`; the camera preview is a 200px-tall `ClipRRect` inside that light card (~437x200, 2.19:1) | critical | proto `:460` (panel), `:502` (dark viewport) / `video_recorder_sheet.dart:40`, `:84-86`, `:247-260` |
| Video header | **No title text at all.** The only top chrome is a 22x22 light close X at `left:16px; top:16px` and a centred timer pill at `top:16px` | `Text('Record video')` in `titleSerif` (Newsreader 24 w600) stretched across the card top with 16px below | high | proto `:505` (close X), `:506` (timer pill) — the video branch `:502-521` contains no title element / `video_recorder_sheet.dart:27`, `:91-92` |
| Video timer pill | `position:absolute; top:16px; left:50%; translateX(-50%); background:rgba(15,13,11,.5); border-radius:14px; padding:5px 12px; gap:7px`; 8x8 dot (`#e0574a` blinking / `#f0b34a` static / `rgba(255,255,255,.5)` idle) + time `600 13px 'Instrument Sans'; color:#fff`, value `0:00` when armed, format M:SS ticked every 250ms | **No elapsed-time readout exists anywhere in the video UI.** Duration is tracked by a private `Stopwatch` and never surfaced to the widget layer | critical | proto `:506-510` (pill), `:1396` (250ms interval) / `video_recorder_sheet.dart:186-209`, `camera_video_recorder.dart:212` |
| Video shutter | A big circular shutter in a control row at `bottom:22px; gap:30px`: `70x70; border-radius:50%; border:4px solid #fff`, **no background fill**; inner 24x24 circle `background:#e0574a` when not recording, 26x26 light pause icon while recording | A bottom-right `Row` of `StickerButton('Cancel')` + `StickerButton('Record')` (primary; becoming `'Stop & save'` while recording) — bordered sticker buttons, not a shutter | critical | proto `:513` (row), `:515` (shutter), `:516` (pause glyph), `:517` (inner dot) / `video_recorder_sheet.dart:126-137`, `:145-159` |
| Video close X | 22x22 light close X pinned `position:absolute; left:16px; top:16px` inside the dark viewport | `StickerButton('Cancel', secondary)` in the bottom-right row; `barrierDismissible: false` so tapping the scrim does nothing | high | proto `:505` / `video_recorder_sheet.dart:39`, `:129-133`, `video_composer.dart:345` |
| Video instruction line | `position:absolute; bottom:70px`, centred, `font:600 13px 'Caveat',cursive; color:rgba(255,255,255,.72)`; copy `tap the button to start recording` (idle), `recording… tap pause or stop`, `paused · resume or save your clip` | A boxed status strip: `cardWarm` fill, 1.5px outline, radius 11, padding 16h/20v, a 12x12 ink-outlined `mutedDeep` dot + `Text('Tap record when you are ready.')` in `captionSans`. *(Note: only idle/arming/saving/denied route through the boxed strip; the recording branch is a bare Row.)* | high | proto `:512` (line), `:1704` (copy) / `video_recorder_sheet.dart:28-32`, `:231-239`, `:263-288` |
| Video pause/discard/save | State machine `idle -> recording <-> paused`. While recording is active the row shows a 44x44 **Discard** circle (`background:rgba(15,13,11,.5); border:1.5px rgba(255,255,255,.4)`, 18x18 light trash, caption `Discard` `500 10px 'Instrument Sans'` `rgba(255,255,255,.75)`) left of the shutter and a 44x44 **Save** circle (`background:#c76a54; border:1.5px solid #fff`, 18x18 light check, caption `Save` `rgba(255,255,255,.85)`) right of it | `VideoRecorderPhase` has no `paused`; the `VideoRecorder` interface has no pause/resume. Discard is only the generic Cancel; save is fused into `'Stop & save'` | high | proto `:514` (Discard), `:519` (Save), `:513` (row), `:1371-1377` (machine) / `video_recorder_sheet.dart:11`, `:126-137`, `video_recorder.dart:64-78` |
| Video feed placeholder | `repeating-linear-gradient(45deg,#3a352e,#3a352e 8px,#443f37 8px,#443f37 16px)` with a centred label `CAMERA FEED` `500 10px ui-monospace,monospace; color:rgba(255,255,255,.3); letter-spacing:.1em` | `CrossHatchPlaceholder` height 200 (160 denied): `cardWarm` ground, `placeholder`-coloured strokes at 8px spacing in **both** diagonal directions, radius 16, ink outline; no label | medium | proto `:502` (stripes), `:504` (`CAMERA FEED` label) / `video_recorder_sheet.dart:226`, `:245` |
| Video vignette | `position:absolute; inset:0; background:linear-gradient(to bottom, rgba(15,13,11,.5), transparent 22%, transparent 68%, rgba(15,13,11,.72))` | No overlay gradient over the `CameraPreview`; wrapped only in `ClipRRect` + ink outline | medium | proto `:503` (verified) / `video_recorder_sheet.dart:247-260` |
| Discard confirm + toasts | Confirm dialog title `Discard this recording?`, message `This take will be thrown away and nothing will be saved.`, confirmLabel `Discard`, `danger:true` (button `background:#c0392b; border:1.5px solid #4a3b2e; radius 11; padding 9px 16px; shadow 1.5px 1.5px 0 #4a3b2e`). Toasts `Recording discarded`, `Voice memo saved`, `Video saved` on `background:#4a3b2e; color:#f6ead6; border-radius:20px; font:600 11px 'Instrument Sans'` with a 13x13 leading check icon | Cancel discards silently; no success toast after save. The `Toast` widget exists (`StickerCard`, radius 11, `bodySans`) but is used only for the video 5/10/20-minute nudges, rendered **inside** the composer card body | medium | proto `:1376-1377` (confirm copy), `:1692` (confirm-button chrome), `:1377`/`:1394`/`:1395` (toast strings), `:900` (toast chrome) / `voice_composer.dart:122-130`, `video_composer.dart:286-301`, `toast.dart:6-36` |
| Chooser presentation | Phone-only bottom sheet: scrim `rgba(42,36,29,.34)` with `align-items:flex-end`; sheet `width:100%; background:#efe2ce; border-top:2px solid #4a3b2e; border-radius:22px 22px 0 0; padding:16px 16px 22px; box-shadow:0 -14px 34px -14px rgba(50,35,20,.55); animation:fn-sheet .24s cubic-bezier(.2,.8,.2,1)`; 38x4 grab handle `border-radius:3px; background:rgba(74,59,46,.3); margin:0 auto 12px` | A centred dialog card for every layout: `Center` + `maxWidth 360` + `StickerCard(cardBright, padding 20, radius 16)`, fade + 0.92→1.0 scale over 220ms; no sheet edge, no grab handle | high | proto `:747-749` / `capture_chooser_sheet.dart:15`, `:26-31`, `capture_chooser.dart:16-51` |
| Chooser rows | One bordered row per option: `display:flex; align-items:center; gap:12px; border:1.5px solid #4a3b2e; border-radius:14px; padding:13px 15px`, a 20x20 icon, and an **inner** div holding title `600 14px 'Instrument Sans'` over subtitle `400 10px` (`opacity:.85` on the primary, `#a08a70` on the others). Row 1 is primary `background:#c76a54; color:#fff; box-shadow:2px 2px 0 #4a3b2e`; rows 2-3 are `#f8efe0` with no shadow. Container `gap:9px` | Each option is a `StickerButton` (all three **secondary**, radius 11, padding 16h/10v, label 15 w600, centred) with the description as a **separate** `Text` in `captionSans` 6px **below** the button; 12px between options; no icons | high | proto `:752` (container, `gap:9px`), `:753-755` (rows) / `capture_chooser_sheet.dart:66-87` |
| Chooser copy | Sheet subtitle `how do you want to plant today?` `600 12px 'Caveat',cursive` `#a08a70`. Row subtitles `put the day into words`, `speak it, hands-free`, `a moving snapshot`. Title `Capture a moment` `500 17px 'Newsreader',serif; color:#4a3b2e; text-align:center` | No sheet subtitle. Row descriptions `'A few words for today'`, `'Say it out loud'`, `'Up to 30 minutes'`. Title string matches but is `titleSerif` (24 w600), left-aligned in a stretched column | medium | proto `:750` (title), `:751` (subtitle), `:753-755` (row subtitles) / `capture_chooser_sheet.dart:13`, `:32-44`, `capture_route.dart:21-36` |

---

## 4. MSP decomposition

**The governing invariant**: merging any MSP must leave the branch's app fully working. No MSP may depend on a surface a later MSP creates. Ordering is bottom-up — shared tokens and primitives before the screens that consume them.

MSPs are grouped into clusters. Within a cluster, MSPs are sequential unless the dependency column says otherwise. Across clusters, only the stated dependencies bind.

| Cluster | Theme | MSPs |
|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 |
| B | Window chrome and nav rail | B1 – B4 |
| C | Today centre column | C1 – C6 |
| D | Today right rail | D1 – D4 |
| E | Flower art | E1 – E4 |
| F | Mood picker | F1 – F4 |
| G | Capture composers | G1 – G8 |
| H | Verification infrastructure | H1 |

---

### Cluster A — Foundations

#### A1 — Token ladder expansion

**Outcome**: the design system exposes every radius, shadow, ink-alpha and named colour the prototype uses, with no existing consumer changed.

**Files**: `lib/design/tokens/palette.dart`, `lib/design/tokens/shapes.dart`, `lib/design/tokens/shadows.dart`, `test/design/tokens/tokens_test.dart`

**Depends on**: nothing. This is the root MSP.

**Target values**

Palette additions (all confirmed present in the prototype):

| Name | Value | Prototype role | Citation |
|---|---|---|---|
| `inkSoft` | `Color(0xFF6A5C4A)` | inactive nav ink and icon stroke | `:1562` |
| `windowTitle` | `Color(0xFFA3866A)` | window-chrome title text | `:52` |
| `recordFill` | `Color(0xFFE0574A)` | video shutter inner dot, timer-pill recording dot, poppy petal | `:517`, `:507`, `:1050` |
| `ink08` | `Color(0x144A3B2E)` | inert pill backgrounds (settings/garden screens only — **out of scope for this spec**, added for completeness, no MSP consumes it) | `:316`, `:678` |
| `ink12` | `Color(0x1F4A3B2E)` | softest divider (settings/garden/calendar screens only — **out of scope**, no MSP consumes it) | `:223`, `:609`, `:1533` |
| `ink16` | `Color(0x294A3B2E)` | rail hairlines, title-bar rule, default card shadow | `:162`, `:50`, `:1582` |
| `ink18` | `Color(0x2E4A3B2E)` | filled week-cell shadow, idle voice rule | `:1609`, `:491` |
| `ink20` | `Color(0x334A3B2E)` | picker unselected tile border, dashed note rule | `:1554`, `:468` |
| `ink22` | `Color(0x384A3B2E)` | rail dashed borders | `:59`, `:152` |
| `ink25` | `Color(0x404A3B2E)` | photo-strip separator, composer header rule | `:134`, `:463` |
| `ink30` | `Color(0x4D4A3B2E)` | sheet grab handle | `:749` |
| `ink35` | `Color(0x594A3B2E)` | empty week-cell dashed border | `:1610` |
| `ink40` | `Color(0x664A3B2E)` | feed empty-state dashed border | `:145` |
| `coral12` | `Color(0x1FC76A54)` | entry-type chip background | `:115` |
| `coral30` | `Color(0x4DC76A54)` | today week-cell shadow, selected picker tile shadow | `:1608`, `:1553` |
| `dashMuted` | `Color(0xFFC3B39A)` | empty week-cell dashed circle and its label | `:1606`, `:1611` |
| `onAccent` | `Color(0xFFFFFFFF)` | pure white text/icons on the coral accent | `:1564`, `:1595` |
| `hatchLight` | `Color(0xFFECDFC8)` | photo hatch light band | `:136` |
| `hatchMid` | `Color(0xFFE2D3BA)` | photo hatch dark band, video hatch light band | `:136`, `:127` |
| `hatchDark` | `Color(0xFFD9C9AE)` | video hatch dark band | `:127` |
| `viewportDark` | `Color(0xFF3A352E)` | camera viewport stripe A | `:502` |
| `viewportDarkAlt` | `Color(0xFF443F37)` | camera viewport stripe B | `:502` |

Shapes additions — the full observed ladder. Keep the existing names and values so no consumer breaks; add the missing steps.

```
radiusXs = 6
radiusIconButton = 8
radiusThumb = 9
radiusCell = 10
radiusSm = 11   (unchanged)
radiusControl = 12
radiusPill = 13
radiusMd = 14   (unchanged)
radiusLg = 16   (unchanged)
radiusXl = 20
radiusSheet = 22
radiusRound = 50 percent, expressed as BoxShape.circle at call sites
```

Shadows — replace the two fixed tokens with a scale. Keep `Shadows.card` and `Shadows.button` as aliases to their current values during A1 so nothing breaks; A2 retargets consumers.

```
hard(offset, color) -> BoxShadow(color: color, offset: Offset(offset, offset), blurRadius: 0, spreadRadius: 0)

chip        = hard(1.5, Palette.ink16)     proto :219 (garden tally chip), :190-191 (calendar chevrons)
cellFilled  = hard(1.5, Palette.ink18)     proto :1609
cellToday   = hard(1.5, Palette.coral30)   proto :1608
control     = hard(1.5, Palette.ink)       proto :466 (composer save), :471 (Add memory), :1692 (confirm button)
cardDefault = hard(2.0, Palette.ink16)     proto :1582 (entry card), :174 (memory card)
emphasis    = hard(2.0, Palette.ink)       proto :70 (streak card), :1564 (active nav), :1595 (primary capture row)
phoneAction = hard(2.5, Palette.ink)       proto :806, :809 (phone voice composer action buttons)
hero        = hard(3.0, Color(0x334A3B2E)) proto :93
heroSoft    = hard(3.0, Color(0x244A3B2E)) proto :100, alpha .14
tileSelected= hard(2.0, Palette.coral30)   proto :1553

softLift       = BoxShadow(color: Color(0x99322314), offset: Offset(0, 20),  blurRadius: 50, spreadRadius: -16)   proto :439 (desktop picker panel)
panelLift      = BoxShadow(color: Color(0xB81E140A), offset: Offset(0, 44),  blurRadius: 96, spreadRadius: -30)   proto :460 (composer panel)
pickerSheetLift= BoxShadow(color: Color(0x80322314), offset: Offset(0, -12), blurRadius: 30, spreadRadius: -12)   proto :732 (phone MOOD PICKER sheet, alpha .5)
chooserSheetLift=BoxShadow(color: Color(0x8C322314), offset: Offset(0, -14), blurRadius: 34, spreadRadius: -14)   proto :748 (phone CHOOSER sheet, alpha .55)

The two phone-sheet lifts are DIFFERENT values in the prototype and must be two tokens. A single
`sheetLift` would silently ship the chooser's shadow on the mood picker. F3 consumes
`pickerSheetLift`; G4 consumes `chooserSheetLift`.

`phoneAction` (formerly named `fab`) has no consumer in this MSP set — the phone voice composer
is not aligned by any MSP here. It is added for ladder completeness only.
```

**Must not regress**: nothing — A1 is purely additive. `Shadows.card` and `Shadows.button` retain their exact current values so every existing widget renders identically after this MSP. No existing `Palette`, `Shapes` or `Shadows` member is renamed or removed in A1; renames would break unrelated consumers and are out of scope.

**Acceptance criteria**: the app looks pixel-identical to before the change. `flutter analyze` is clean. The existing `test/design/tokens/tokens_test.dart` is extended to assert the new constants exist with the values above, and passes.

---

#### A2 — Typography role system

**Outcome**: the two distinct Caveat roles, the serif metric scale and the caption size ladder exist as named tokens, and every current consumer is retargeted so no text renders differently by accident.

**Files**: `lib/design/tokens/typography.dart`, plus mechanical retargeting at **every** `eyebrowAccent` call site, and `test/design/tokens/tokens_test.dart`.

The complete call-site set, confirmed by `grep -rn "eyebrowAccent" lib/ test/` — **all seven must be retargeted in this MSP or the build does not compile**:

| Call site | Retarget to |
|---|---|
| `lib/features/today/today_header.dart:20` | `pageEyebrowAccent` |
| `lib/features/today/this_week_garden.dart:30` | `sectionHeaderAccent` |
| `lib/features/today/today_capture_buttons.dart:77` | `sectionHeaderAccent` |
| `lib/features/today/on_this_day_card.dart:100` | `sectionHeaderAccent` |
| `lib/features/entry_cards/entry_card.dart:63` | `sectionHeaderAccent` (interim; C4 replaces this line entirely) |
| `lib/design/settings_fields/settings_section.dart:35` | `sectionHeaderAccent` — **out-of-scope screen, but a compile dependency** |
| `lib/features/calendar/widgets/calendar_header.dart:30` | `sectionHeaderAccent` — **out-of-scope screen, but a compile dependency** |

`test/design/tokens/tokens_test.dart:30` asserts `TypographyTokens.eyebrowAccent.fontFamily`. That assertion must be moved to `sectionHeaderAccent` and `pageEyebrowAccent` in the same commit, or `flutter test` fails to compile.

**Depends on**: A1 (uses `Palette.inkSoft`, `Palette.mutedDeep`)

**Target values**

| Token | Value | Prototype | Citation |
|---|---|---|---|
| `pageEyebrowAccent` | Caveat 16, w600, `Palette.coral` | `font:600 16px 'Caveat',cursive; color:#c76a54` | `:89` |
| `sectionHeaderAccent` | Caveat 17, w600, `Palette.sage` | `font:600 17px 'Caveat',cursive; color:#7d8450` | `:154`, `:164`, `:173`, `:107` |
| `stampAccent` | Caveat 13, w600, `Palette.sage` | entry card timestamp | `:114` |
| `promptAccent` | Caveat 13, w600, `Palette.muted` | `tap to plant today's bloom` | `:102` |
| `subtitleAccent` | Caveat 14, w600, `Palette.muted` | `choose today's bloom` | `:441` |
| `composerTitleAccent` | Caveat 16, w600, `Palette.coral` | composer header title | `:465` |
| `windowTitleAccent` | Caveat 14, w600, `Palette.windowTitle` | `field notes — a journal of days` | `:52` |
| `wordmarkAccent` | Caveat 23, w700, height **0.85**, `Palette.coral` | `font:700 23px/.85 'Caveat'; color:#c76a54` | `:62` |
| `streakAccent` | Caveat **24**, w700, height **1.0**, `Palette.coral` | `font:700 24px 'Caveat'; color:#c76a54; line-height:1` | `:71` |
| `displaySerif` | Newsreader 32, **w500**, height **1.0**, ink | `font:500 32px/1 'Newsreader'` | prototype page titles |
| `displaySerifToday` | Newsreader 34, w500, height 1.0, ink | `font:500 34px/1 'Newsreader'` | `:89` |
| `headlineSerif` | Newsreader 21, w500, ink | picker title | `:440` |
| `bannerSerif` | Newsreader 19, w500, ink | mood banner + unset headline | `:95`, `:102` |
| `sectionSerif` | Newsreader 17, w500, ink | chooser title, feed empty headline | `:750`, `:146` |
| `bodySerif` | Newsreader **13.5**, w400, height **1.5**, ink | `font:400 13.5px/1.5 'Newsreader'` | `:118` |
| `bodySerifSecondary` | Newsreader 12, w400, height 1.5, `Palette.mutedDeep` | `font:400 12px/1.5 'Newsreader'; color:#8a7358` | prototype secondary prose |
| `memoryTitleSerif` | Newsreader 12, w500, ink | on-this-day title | `:176` |
| `captionSans` | Instrument Sans 12, **w400**, `Palette.muted` | `font:400 12px 'Instrument Sans'; color:#a08a70` | `:147` |
| `caption11Sans` | Instrument Sans 11, w600, `Palette.coral` | `change` pill, `choose` pill | `:96`, `:103` |
| `caption10Sans` | Instrument Sans 10, w400, `Palette.muted` | week range, streak note | `:155`, `:71` |
| `caption9Sans` | Instrument Sans 9, w400, `Palette.muted` | memory meta, composer meta | `:176`, `:465` |
| `caption8Sans` | Instrument Sans 8, w600 | week-cell label; colour supplied per state | `:1611` |
| `syncPrimarySans` | Instrument Sans 10, w600, ink | `Synced to home` | `:77` |
| `syncSecondarySans` | Instrument Sans 8, w400, `Palette.muted` | `your server · just now` | `:77` |
| `navLabelSans` | Instrument Sans 14, **w600** | nav label; colour supplied per state | `:1564` |
| `chipMicroSans` | Instrument Sans 8, w500, letterSpacing **0.08 em**, `Palette.coral` | entry type badge, uppercased at call site | `:115` |
| `captureLabelSans` | Instrument Sans 12, w600 | capture button label; colour per variant | `:167` |
| `monoMicroSans` | monospace 7, w500, `Palette.muted` | `memory · 1 year ago` | `:175` |
| `monoThumbSans` | monospace 6, w500, `Palette.mutedDeep` | photo thumbnail caption | `:136` |

`eyebrowAccent` is **removed**, per the seven-site table above.

**Blast radius A2 accepts by design.** A2 also changes the *values* of three tokens that are consumed far outside this spec's scope: `bodySerif` 16 -> 13.5, `displaySerif` w600/1.15 -> w500/1.0, `captionSans` w500 -> w400. `bodySerif` alone has nine consumers including `calendar_screen.dart`, `garden_screen.dart`, `garden_view.dart` and `search_screen.dart`; `captionSans` has 33. Those screens are out of scope for *alignment* but will re-render at the new metrics the moment A2 merges. This is intended — the token layer is shared and cannot be forked per screen — but the implementer must eyeball Calendar, Garden, Search, Day Detail and Settings for text overflow after A2, because a 16 -> 13.5 serif drop and a w600 -> w500 display drop change line-break points. Overflow found there is fixed in A2, not deferred: an overflowing Calendar is a user-visible bug that A2 alone would ship.

**Must not regress**: nothing behavioural. `lib/design/tokens/typography.dart` keeps `serif`, `sans` and `accent` as the family strings, bound by name plus explicit `FontWeight` — **do not** introduce `FontVariation('wght', …)` calls. Flutter drives the variable-font `wght` axis from `TextStyle.fontWeight` automatically ([Flutter breaking change: font-weight-variation](https://docs.flutter.dev/release/breaking-changes/font-weight-variation)); hand-rolling the axis would double-apply. Italic must stay routed through the `style: italic` pubspec asset declaration, not through a variation — `Newsreader-Italic-Variable.ttf` is a separate file and the roman file has no italic axis.

**Acceptance criteria**: `flutter analyze` is clean — no dangling `eyebrowAccent` reference in `lib/` or `test/`. Page eyebrows above screen titles render **terracotta at 16px**, and lowercase rail/feed section headers render **sage at 17px** — two visibly different treatments where there was previously one. Journal prose in entry cards is noticeably denser (13.5px, not 16px). Page titles are lighter (w500) and set solid (height 1.0). No text overflows on Calendar, Garden, Search, Day Detail or Settings at the app's minimum supported window size. The existing `test/design/tokens/pubspec_fonts_test.dart` still passes unmodified, confirming the three families stay vendored and `google_fonts` is still absent.

---

#### A3 — Dialog Material ancestor fix

**Outcome**: no dialog in the app renders text with Flutter's yellow double-underline debug style.

**Files**: `lib/features/mood/mood_picker.dart`, `lib/features/capture/text/text_composer.dart`, `lib/features/capture/voice/voice_composer.dart`, `lib/features/capture/video/video_composer.dart`, `lib/features/capture/chooser/capture_chooser.dart`; new shared host under `lib/design/feedback/`; new `test/design/feedback/dialog_host_test.dart`

**Depends on**: nothing. Can land in parallel with A1/A2.

**Root cause, verified end to end**: `lib/app/app.dart:20` builds a plain `MaterialApp` with no `builder`, so nothing re-wraps the overlay subtree. Flutter's `material/app.dart:45-54` defines `_errorTextStyle` as `TextStyle(color: Color(0xD0FF0000), fontFamily: 'monospace', fontSize: 48.0, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: Color(0xFFFFFF00), decorationStyle: TextDecorationStyle.double, debugLabel: 'fallback style; consider putting your text in a Material')` and passes it as `WidgetsApp.textStyle` at `:1091`. Each of the five entry points returns its sheet directly from `showGeneralDialog`'s `pageBuilder` into the root overlay; `StickerCard` is a `DecoratedBox` and introduces no `Material`. Because every `TypographyTokens` style leaves `decoration` null with `inherit` defaulting true, `merge()` preserves the underline while overriding font, size and colour.

**Target implementation**: introduce one shared `DialogHost` widget that wraps the sheet in `Material(type: MaterialType.transparency)` and route all five `pageBuilder`s through it. The precedent already exists and is known-good: `lib/features/capture/video/camera_picker.dart:35` wraps its control in exactly this and its text already escapes the bug.

**Must not regress**: barrier colours, `barrierDismissible` values, semantic barrier labels, and the fade + scale transitions stay exactly as they are (A3 changes only the ancestry). `barrierDismissible: false` on the video composer (`video_composer.dart:345`) is preserved. N24 — no `ValueKey` or Semantics label changes.

**Acceptance criteria**: open the mood picker — the title `How are you feeling?` and all ten mood labels render as plain warm-brown text with **no yellow underline**. Open each of the note, voice and video composers and the capture chooser — same. This is a **behaviour/contract change and warrants a test**: a widget test that pumps each dialog and asserts the resolved `DefaultTextStyle` has `decoration == TextDecoration.none` (or null), i.e. no inherited `_errorTextStyle`.

---

#### A4 — Sticker primitive alignment

**Outcome**: `StickerButton` encodes the prototype's primary/secondary distinction, and `StickerCard` supports the scrapbook tilt.

**Files**: `lib/design/widgets/sticker_button.dart`, `lib/design/widgets/sticker_card.dart`, `test/design/widgets/sticker_card_test.dart`

**Depends on**: A1

**Target values**

`StickerButton`:

| Property | Primary | Secondary | Danger |
|---|---|---|---|
| background | `Palette.coral` `#c76a54` | `Palette.cardWarm` `#f8efe0` | `Palette.danger` `#c0392b` |
| foreground | `Palette.onAccent` `#fff` | `Palette.ink` `#4a3b2e` | `Palette.onAccent` `#fff` |
| border | `1.5px Palette.ink` | `1.5px Palette.ink` | `1.5px Palette.ink` |
| radius | `Shapes.radiusControl` 12 | 12 | `Shapes.radiusSm` 11 |
| padding | `10px vertical, 13px horizontal` | same | `9px vertical, 16px horizontal` |
| icon gap | `10` | `10` | `10` |
| shadow | `Shadows.emphasis` `2px 2px 0 #4a3b2e` | **none** | `Shadows.control` `1.5px 1.5px 0 #4a3b2e` |

Citations: primary and secondary from `Field Notes.dc.html:1595-1596`; the pure-white foreground from `:1564`.

**The danger column is cited separately and was corrected during review.** `:1595-1596` contains no danger variant, so an earlier draft's danger values (`#fbecea` fill with `#c0392b` text on a `Palette.danger` border) were unsourced. The prototype has exactly two danger treatments and they are different objects:

| Prototype object | Line | Values |
|---|---|---|
| **Destructive confirm button** — the true `StickerButton(danger)` analogue | `:1692` | `background:#c0392b; color:#fff; border:1.5px solid #4a3b2e; border-radius:11px; padding:9px 16px; box-shadow:1.5px 1.5px 0 #4a3b2e; font:600 12px 'Instrument Sans'` |
| **Voice Discard pill** — a one-off, *not* the shared variant | `:495` | `background:#fbecea; color:#c0392b; border:1.5px solid #c0392b; border-radius:22px; padding:10px 18px`, **no shadow** |

The table above adopts `:1692`, because the app's three `danger` consumers are all destructive confirms: `settings/sections/data_section.dart:50` (Delete all data), `settings/widgets/delete_all_dialog.dart:50` (N18's confirmation), and `entry_cards/entry_card.dart:75` (Delete). The `:495` pill is a bespoke shape built inside G6 and must **not** be pushed into the shared variant.

`StickerCard`: add an optional `double rotationDegrees` parameter defaulting to `0`, applied via `Transform.rotate(angle: rotationDegrees * pi / 180)`. When zero, no `Transform` is inserted, so nothing changes for existing consumers. Citation: `:1582` (`transform:rotate('+tilt+')`).

**Must not regress**: `StickerCard`'s existing `padding`, `surface`, `borderRadius` and `shadow` parameters keep their names, defaults and semantics — a large number of call sites depend on them. `StickerButton`'s `icon`, `label`, `onPressed`, `variant` and disabled-`Opacity(0.5)` behaviour are unchanged. Every existing widget test under `test/design/widgets/` continues to pass without modification.

**Blast radius A4 accepts by design.** `StickerButton` has 20 call sites across the app, most of them outside this spec's scope. A4 restyles all of them at once. Named preserve items in that set that must still render and still function after A4:

- **N18** — `delete_all_dialog.dart:45`/`:50`: the Cancel/Delete pair must stay legible and the confirm must stay reachable. Danger is now a filled red button with white text, so verify contrast and that Cancel (secondary) is still visually distinct now that it has lost its shadow.
- **N17** — `settings_notice.dart:23`: the dismiss affordance is a secondary button and loses its shadow; it must not become invisible against the notice surface.
- **N12** — `video_recorder_sheet.dart:131` and the camera-picker row: still functional.
- **Preserve item** — `photo_tray.dart:135`, `:141`: `PhotoTray` is dead UI (nothing in `lib/` mounts it) but `test/features/capture/photo/photo_tray_test.dart` compiles against it. A4 must not break that test, and `PhotoTray` must not be deleted for being unreachable.
- `day_detail_header.dart:46`, `settings_screen.dart:72`, `data_section.dart:41`, `mood_banner.dart:42` (superseded by C2), `today_capture_buttons.dart:85` (superseded by D3).

Secondary buttons losing their shadow app-wide is the *intended* outcome, not a regression — but it is the single widest visual change in Cluster A and it lands on screens no later MSP revisits.

**Acceptance criteria**: secondary buttons — Cancel in the composers, the rail's capture rows, the chooser rows — visibly **lose their drop shadow** while primary buttons keep theirs, so the two tiers stop looking equally prominent. Secondary buttons take on the warmer `#f8efe0` fill instead of the near-white `#FFFAF1`. Primary button text is pure white rather than cream. All buttons are a hair rounder (12 vs 11) and 3px tighter on each side.

---

#### A5 — Cross-hatch geometry

**Outcome**: media placeholders render the prototype's single-direction two-tone diagonal stripes, with distinct photo, video and camera-viewport variants.

**Files**: `lib/design/widgets/cross_hatch_placeholder.dart`

**Depends on**: A1

**Target values**: replace the two-direction line-stroke painter with a 45-degree two-tone band fill. Three variants:

| Variant | Bands | Pitch | Citation |
|---|---|---|---|
| `photo` | `#e2d3ba` / `#ecdfc8` | 6px / 12px (thumbnails use 5px / 10px) | `:175`, `:136` |
| `video` | `#d9c9ae` / `#e2d3ba` | 6px / 12px | `:127` |
| `viewport` | `#3a352e` / `#443f37` | 8px / 16px | `:501` |

Implementation: draw the ground colour, then fill parallel 45-degree bands of the second colour at the stated pitch, clipped to the widget's rounded rect. No line strokes. The 1.5px ink outline stays for the photo and video variants; the viewport variant has none.

**Must not regress**: the widget's public constructor surface (`height`, `borderRadius`) is preserved so `video_recorder_sheet.dart:226`, `:245` and `photo_thumbnail.dart`'s error fallback keep compiling. Default variant is `photo`, so untouched call sites keep working.

**Acceptance criteria**: photo placeholders show clean parallel diagonal stripes rather than a woven X-hatch of thin darker lines, and video placeholders are visibly a shade darker than photo ones.

---

### Cluster B — Window chrome and nav rail

#### B1 — App panel gradient and window chrome

**Outcome**: the app interior is the warm cream panel wash with its terracotta corner glow, and the title bar carries its caption and hairline.

**Files**: `lib/app/shell/sidebar_shell.dart`, `lib/app/shell/bottom_bar_shell.dart`

**Depends on**: A1, A2

**Target values**

Panel background — replace `Scaffold(backgroundColor: Palette.page)` with a two-layer paint (`:56`):

```
layer 1  linear gradient top -> bottom, Palette.panelTop #efe2ce -> Palette.panelBottom #e9dcc4
layer 2  radial gradient, Palette.panelCoralTint rgba(199,106,84,.07) -> transparent
         centre at 15% width / 0% height, extent 120% width by 60% height, stop at 55%
```

`Palette.page` `#d9cbb2` and the `pageGradientInner/Outer` pair `#e6d8bf`/`#cdbd9f` describe the **outside-the-device-frame** page (`:18`) and are not painted inside the app panel.

Title bar (`:50-52`): height **42** (from 36); horizontal padding **16** (from 12); a bottom border `1px solid Palette.ink16`; a `flex:1` centred `Text('field notes — a journal of days')` in `windowTitleAccent` (Caveat 14 w600 `#a3866a`); a trailing `SizedBox(width: 56)` balancing the 52px traffic-light cluster.

**Two live consumers of `Palette.page` that B1 must handle deliberately**, or it ships a half-restyled app:

1. `lib/app/theme/app_theme.dart:23` sets `scaffoldBackgroundColor: Palette.page`, and `test/app/theme/app_theme_test.dart:12` asserts it. B1 overrides the colour at the two shell widgets (`sidebar_shell.dart:28`, `bottom_bar_shell.dart:25`), **not** at the theme. Leave `app_theme.dart:23` and its assertion alone — changing them is out of B1's scope and would break a passing test for no gain.
2. `lib/app/shell/bottom_bar_shell.dart:25` is the **phone** shell. If B1 repaints only `sidebar_shell.dart`, the phone build keeps the grey `#d9cbb2` while desktop goes cream — a visibly half-restyled app on merge. Both shells are in B1's file list precisely so this cannot happen; paint both or paint neither.

**Must not regress**: the traffic-light geometry is already exact — three 12x12 circles with 8px gaps in close/minimise/zoom order, no borders or glyphs (`sidebar_shell.dart:56-73` vs `:51`). Do not touch it. `lib/app/shell/shell_layout.dart:5-9`'s sidebar-on-macOS / bottom-bar-elsewhere split is correct and stays.

**Acceptance criteria**: the app interior is a warm cream that is visibly lighter and less grey than before, with a soft terracotta glow in the upper-left. The title bar is 6px taller, its dots start 4px further in, a handwritten `field notes — a journal of days` sits centred in it, and a faint hairline separates it from the body.

---

#### B2 — Nav rail geometry and brand lockup

**Outcome**: the rail is the designed width with the peony mark and the two-line terracotta wordmark.

**Files**: `lib/app/shell/sidebar_shell.dart`

**Depends on**: A1, A2, B1

**Target values** (`:59`, `:60-62`, `:1669`)

```
rail width        216   (from 248)
rail padding      22 vertical, 16 horizontal   (from EdgeInsets.all(16))
right divider     1px dashed Palette.ink22 rgba(74,59,46,.22)   (from 1.5px full-opacity ink)
lockup row        display flex, gap 9, margin-bottom 24
logo flower       32x32 FlowerBloom(FlowerKind.peony), no tile, no border, no background
wordmark          Text('field\nnotes') in wordmarkAccent, Caveat 23 / height 0.85 / w700 / coral
```

`DashedDivider` **already exposes** `thickness` and `color` as named parameters with defaults `1.5` and `Palette.ink` (`lib/design/widgets/dashed_divider.dart:6-19`). No widget change is required — B2 only passes `thickness: 1.0, color: Palette.ink22` at the rail call site. Do not modify `dashed_divider.dart`; it is already faithful.

This removes `dashed_divider.dart` from B2's file list.

**Must not regress**: the rail's vertical structure — wordmark, nav list, flexible `Spacer`, streak card, footer — is already correct against `:69` and stays. The rail must continue to paint no background of its own, letting the B1 panel gradient show through (`sidebar_shell.dart:76-79`).

**Acceptance criteria**: the sidebar is visibly narrower, its content starts further from the top edge, a pink peony sits left of the wordmark, and the wordmark reads as a tight two-line terracotta stack `field` / `notes` rather than one long brown line. The seam between rail and content is a faint hairline instead of a heavy dashed rule.

---

#### B3 — Nav item states and icon glyph set

**Outcome**: the selected nav row is a terracotta sticker with white text and a hard ink shadow; unselected rows recede; the icons are the app's own hand-drawn family.

**Files**: `lib/app/shell/sidebar_shell.dart`, `lib/app/shell/shell_destination.dart`, new `lib/design/icons/nav_icons.dart`

**Depends on**: A1, A2, A4, B2

**Target values**

Active item (`:1564`):
```
background     Palette.coral #c76a54
foreground     Palette.onAccent #fff  (label and icon)
border         1.5px Palette.ink
boxShadow      Shadows.emphasis  2px 2px 0 #4a3b2e
borderRadius   Shapes.radiusControl 12
padding        9 vertical, 12 horizontal
gap            10
```

Inactive item (`:1562`, `:1564`): background none, border none, no shadow; icon and label `Palette.inkSoft` `#6a5c4a`; label `navLabelSans` (Instrument Sans 14 **w600**).

Icon set — custom `CustomPainter` glyphs at 18x18 drawn against a 24-unit viewBox (`:1218-1221`). Per the implementation research, these are procedural primitives, not arbitrary vector art, so they are hand-drawn in Dart exactly like `FlowerPainter` — **no `flutter_svg` or `vector_graphics` dependency is added**.

| Destination | Path | Render |
|---|---|---|
| today | `M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z` | **filled** |
| calendar | `rect x=4 y=5 w=16 h=16 rx=2` + `M4 9h16M9 3v4M15 3v4` | stroked, width 2, round caps/joins |
| garden | `circle(12,9,r3) circle(8,13,r3) circle(16,13,r3)` + `M12 12v9` | stroked, width 2, round caps/joins |
| search | `circle(11,11,r7)` + `M21 21l-4-4` | stroked, width 2, round caps/joins |

**Must not regress**: the four destinations and their order — Today, Calendar, Garden, Search, with Settings correctly excluded from the primary list — match `navDef` at `:1559` and stay (`shell_destination.dart:15-20`). Nav item spacing (4px symmetric vertical padding yielding an 8px gap against the prototype's `gap:7px`) and the 18px icon size are already within a pixel and stay. `ShellDestination` must keep exposing a label for accessibility.

**Acceptance criteria**: the selected nav row is a terracotta sticker with white label and icon and a crisp ink shadow offset down-right — it reads as stuck-on paper, not an outlined box. Unselected rows are a softer brown and no longer compete with it. Today shows a filled **house**, not a sun; Garden shows a three-circle sprout, not a Material florist glyph.

---

#### B4 — Nav rail footer: icon-button pair and sync block

**Outcome**: the rail bottom is a compact 30x30 gear and speaker pair with the two-line sync caption beside them, and both buttons reflect state.

**Files**: `lib/app/shell/sidebar_shell.dart`, `lib/app/shell/app_shell.dart`, new `lib/design/widgets/icon_sticker_button.dart`, new `test/app/shell/sidebar_footer_test.dart`

**Depends on**: A1, A2, B2

**Target values**

Footer row (`:74`): `display:flex; align-items:center; gap:9px` holding — settings button, sound button, sync text block. The sync block sits **to the right** of the buttons, not below them.

Icon button, both instances (`:1644`, `:1682`): `width:30; height:30; borderRadius: Shapes.radiusIconButton 8; border: 1.5px Palette.ink; padding: 7`; **no box-shadow**; icon 15x15 at strokeWidth 1.8.

| Button | State | Fill | Glyph |
|---|---|---|---|
| settings | `selected == ShellDestination.settings` | `Palette.coral` `#c76a54` | gear stroked `#fff` |
| settings | otherwise | `Palette.cardLight` `#fff5ea` | gear stroked `#4a3b2e` |
| sound | `soundOn` | `Palette.cardLight` `#fff5ea` | `M4 9v6h4l5 4V5L8 9z` + `M16 9a4 4 0 0 1 0 6` |
| sound | off | `Palette.cardWarm` `#f8efe0` | same speaker + `M17 9l4 6M21 9l-4 6` |

Note the sound button's **glyph** swaps, not just its fill.

Sync block (`:77`): a Column with `line-height:1.15`; line 1 in `syncPrimarySans` (Instrument Sans 10 w600 ink); line 2 in `syncSecondarySans` (Instrument Sans 8 w400 `#a08a70`).

**Copy — OQ-1 resolved to (a) on 2026-07-27.** Adopt the prototype's two-line *treatment*, not its strings. The prototype's `Synced to home` / `your server · just now` describes a remote-sync product that does not exist and must not ship.

| Line | Style | Copy |
|---|---|---|
| 1 | `syncPrimarySans` | `Stored locally` |
| 2 | `syncSecondarySans` | `on this device only` |

Line 2 preserves the app's existing string (`sidebar_shell.dart:113-116`) verbatim as the detail line; line 1 is the headline the two-tier layout requires. The strings may be reworded without re-opening the decision **provided neither line claims sync, a server, or a sync recency.** Revisit only when remote sync actually ships.

`SidebarShell` already receives `selected` but never compares it to `ShellDestination.settings` — wire it. `AppShell`'s `void _noSound() {}` default must be replaced with a real bound state so the sound glyph can change.

**Must not regress**: N20 — the sound toggle must drive the same `GatedSoundService` gate as the Sound effects settings row. Do not bypass it. Both controls need accessible labels since they lose their visible text.

**Acceptance criteria**: the rail footer is one horizontal strip — a small gear, a small speaker, then two tight lines of caption text — instead of two big labelled buttons stacked like extra nav rows. Opening Settings turns the gear terracotta with a white glyph. Muting sound swaps the speaker to its crossed-out variant. This is a **behaviour change and warrants a test**: a widget test asserting the settings button's fill responds to `selected` and the sound glyph responds to the sound-enabled state.

---

#### Resolved: the question that blocked part of B4

The prototype's sync copy describes a remote-sync product the app does not have. **OQ-1 resolved to (a) on 2026-07-27**: the prototype's two-line 10px/8px treatment is adopted, its strings are not. B4 is unblocked; the exact copy is in B4's target values above.

---

### Cluster C — Today centre column

#### C1 — Streak card

**Outcome**: the streak card reads as the rail's emphasis surface again.

**Files**: `lib/features/streak/streak_card.dart`, new `lib/design/icons/flame_icon.dart`

**Depends on**: A1, A2, A4

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

**Acceptance criteria**: the streak card is a brighter cream panel with a crisp opaque ink shadow and slightly tighter corners, standing out from the rail. The day count is 2px larger and set solid. The sub-line is a quiet 10px `longest streak yet: 3` — restyled, with the number still present.

---

#### C2 — Today header and mood banner (set state)

**Outcome**: the greeting is terracotta handwriting over an undated headline, and the banner speaks a full sentence with its flower named.

**Files**: `lib/features/today/today_header.dart`, `lib/features/today/today_date.dart`, `lib/features/mood/mood_banner.dart`, `test/features/today/today_date_test.dart`

**Depends on**: A1, A2, A4

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

**Must not regress**: `longDateLabel`'s year-bearing form is consumed elsewhere (`on_this_day_card.dart`); introduce a separate short form rather than changing the shared function's output for all callers. Mood label strings and the mood-to-flower mapping are exact against `:1058` and `:1045-1057` — do not touch `lib/domain/mood/mood.dart`.

**Acceptance criteria**: the greeting is terracotta handwriting at a smaller size, tucked right above a larger, lighter date that reads `Saturday, July 5` with no year. At 11pm the greeting says `Good night`. The banner reads `Feeling Happy today` with `Peony · your bloom for the day` beneath it, the bloom is noticeably bigger, and the change control is a small outline-only terracotta pill reading `change`. The **four-branch greeting is a behaviour change and warrants a test** — extend the existing `today_date_test.dart` with the 21:00 boundary.

---

#### C3 — Mood unset state

**Outcome**: before a mood is set, the user sees an inviting cream card, not an empty dashed rectangle.

**Files**: `lib/features/mood/mood_banner.dart`, `lib/features/mood/mood_prompt_border.dart`

**Depends on**: A1, A2, C2

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

**Acceptance criteria**: an unset day shows a cream dashed-border card carrying a faded 46px bloom on the left, the serif question, a handwritten `tap to plant today's bloom` beneath it, and a filled terracotta `choose` pill on the right.

---

#### C4 — Feed eyebrow and entry card header

**Outcome**: the feed is labelled, and each card is headed by its capture time and a small type chip.

**Files**: `lib/features/today/today_screen.dart`, `lib/features/entry_cards/entry_card.dart`

**Depends on**: A1, A2, A4, **B4** — C4's interim Edit/Delete placement consumes `IconStickerButton`, which B4 creates. Without B4 this MSP does not compile.

*(Alternative if Cluster B is not yet merged: C4 may ship the Edit/Delete pair as unstyled `StickerButton(secondary)` in the header row and defer the icon-button treatment to a follow-up commit. Choose one; do not assume `IconStickerButton` exists.)*

**Target values**

Feed eyebrow (`:107`, `:1666`): between the mood banner and the feed, render `'today · ' + N + ' log' + (N == 1 ? '' : 's')` in `sectionHeaderAccent` (Caveat 17 w600 sage) with `margin: 18 top, 12 bottom`. This replaces the bare `SizedBox(height: 20)`.

Entry card header (`:113-115`, `:1574-1575`), `margin-bottom: 4`:

- **Left**: the capture timestamp plus time-of-day, e.g. `08:12 · morning`, in `stampAccent` (Caveat 13 w600 sage). This replaces the type-name eyebrow. No timestamp is currently rendered anywhere on the card — the value must be derived from the entry's capture time.
- **Right**: an uppercase micro badge in `chipMicroSans` (Instrument Sans 8 w500, letterSpacing 0.08em, `Palette.coral`) on `Palette.coral12` `rgba(199,106,84,.12)`, `borderRadius: Shapes.radiusIconButton 8`, `padding: 2 vertical / 7 horizontal`. Copy is the lowercase type name uppercased at render: `NOTE` / `VOICE` / `VIDEO` / `PHOTO`.

**Must not regress**: N23 and the additive Edit/Delete actions (`entry_card.dart:65-77`). The prototype has no per-card action controls, so they have nowhere obvious to go in the new header. They must **not** be deleted. Interim placement: keep them in the header row between the stamp and the type chip, restyled as small icon buttons using the B4 `IconStickerButton` at 8px radius. Their final placement is OQ-3. Note `TodayEntryTile` does not currently pass either callback (`today_entry_feed.dart:100-107`), so on Today they are invisible today — the regression risk is in Day Detail, not Today.

**Acceptance criteria**: an olive handwritten `today · 4 logs` sits above the entry list. Each card is headed by its capture time on the left (`08:12 · morning`) and a small uppercase terracotta chip on the right, replacing the large green word `Note`.

---

#### C5 — Entry card surface, tilt, body and photo strip

**Outcome**: cards sit at a fraction of a degree off-square with denser prose and outlined thumbnails under a dashed rule.

**Files**: `lib/features/entry_cards/entry_card.dart`, `lib/features/entry_cards/cards/note_body.dart`, `lib/features/entry_cards/cards/photo_strip.dart`, `lib/features/entry_cards/media/media_image.dart`

**Depends on**: A1, A2, A4, A5, C4

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

**Acceptance criteria**: cards alternate a barely-perceptible tilt left and right down the feed, giving it a hand-placed scrapbook feel. Note text is visibly denser. Photos are smaller ink-outlined squares sitting below a dashed rule instead of larger borderless ones.

---

#### C6 — Feed empty state

**Outcome**: an empty day invites capture in the design's own voice.

**Files**: `lib/features/today/today_entry_feed.dart`, `lib/design/feedback/empty_state.dart`

**Depends on**: A1, A2

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

**Acceptance criteria**: an empty day shows a lighter dashed box containing a serif headline `Nothing planted yet today` with the invitation line beneath it, replacing the single sans-serif sentence.

---

#### C7 — Video entry card poster chrome

**Outcome**: the video entry card's resting state carries the prototype's hatch, play badge and duration chip, on the app's existing playback envelope.

**Files**: `lib/features/entry_cards/cards/video_body.dart`

**Depends on**: A1, A4, A5, C5

**Decision context — OQ-7 resolved to (a) on 2026-07-27.** The prototype's `height:130px` is **rejected**: it clips the control bar. The app's 21:9 / 200px-minimum envelope (`video_body.dart:23-24`) is load-bearing for the centred transport, the 48px scrubber row and the 48px mute target, and is unchanged. Only the poster chrome is adopted. Option (b) — 130px at rest, expanding on first play — was rejected for the mid-interaction layout jump.

**Target values** (`:128-130`)

> Citation corrected. The audit and the first draft both cited `:127-129`; `:127` is the `<sc-if value="{{ e.isVideo }}">` guard, and the three styled elements are at `:128`, `:129`, `:130`. This is the same systematic off-by-one recorded in §7. Re-open the lines before adopting.

| Element | Value |
|---|---|
| Hatch | `repeating-linear-gradient(45deg, #d9c9ae, #d9c9ae 6px, #e2d3ba 6px, #e2d3ba 12px)` — 45°, 6px bands, two-tone. Route through the A5 `CrossHatchPlaceholder` geometry; do not hand-roll a second painter. |
| Container | `borderRadius: 10`, `border: 1.5px Palette.ink`, clipped |
| Play badge | 44x44 circle, centred; fill `rgba(255,251,244,.92)`; `border: 1.5px Palette.ink`; 17x17 dark play glyph, offset `+2` on x for optical centring |
| Duration chip | bottom 8, right 9; Instrument Sans 10 w600; `#fff` on `rgba(42,36,29,.7)`; `borderRadius: 8`; padding 2 vertical / 8 horizontal |

**Must not regress.** This MSP lands on the most test-covered code in the repo (N23 — 106 cases across eight files). Every item below is a preserve rule, not a preference:

- **N10** — the 21:9 / 200px envelope is unchanged. If the badge or chip does not fit, the badge or chip is wrong; the envelope is not negotiable.
- **N3** — the play/pause transport and its state-dependent glyph. The prototype badge is a **resting-state poster** affordance. It must not replace the live transport, and the two must never render at once.
- **N4** — the live elapsed/total readout on the control bar. The static duration chip is **resting state only** and must be gone whenever the overlay is showing a live readout.
- **N5** — the auto-hiding overlay and its platform-branched interaction model (pointer on macOS, touch elsewhere), untouched.
- **N9** — captured poster-frame gating (`video_body.dart:505-513`): a real `entry.thumbnailMediaId` still wins over the hatch. The hatch remains the **fallback**, exactly as today.
- **N7 / N8** — retry-with-backoff and the slot-contention busy notice keep their current copy and placement, and render **over** the new chrome.

**Acceptance criteria**: a video entry with no captured thumbnail shows a 45° two-tone hatch behind a 44x44 cream play badge with a dark ink outline, and a small dark duration pill bottom-right. Tapping it plays exactly as before — transport, scrubber, mute and auto-hide behave identically, and **the card does not change size at any point in the interaction**. A video entry *with* a captured thumbnail still shows the thumbnail, not the hatch.

**Verification**: this is a styling change on a behaviour-critical surface, so per §5.2 it warrants no new test of its own — but the existing playback suite is the receipt that N3/N4/N5/N9/N10 survived. Run it green before the change and green after; a diff in that suite is a blocker, not a test to update.

---

### Cluster D — Today right rail

#### D1 — Rail container: geometry, separators, bare sections

**Outcome**: the rail is three flat groups of content divided by thin rules, scrolling independently, behind a dashed seam.

**Files**: `lib/features/today/today_layout.dart`, `lib/features/today/today_screen.dart`, `lib/features/today/today_right_rail.dart`, `lib/features/today/this_week_garden.dart`, `lib/features/today/today_capture_buttons.dart`, `lib/features/today/on_this_day_card.dart`

**Depends on**: A1, A2. *(An earlier draft made D1 depend on B2 "for the DashedDivider overrides". Those parameters already exist on the widget, so the dependency was spurious and is removed — Cluster D can now run in parallel with Cluster B.)*

**Target values** (`:152`, `:153`, `:162`, `:163`, `:171`, `:172`)

```
rail width         266   (from todayRailWidth 300)
rail padding       24 vertical, 20 horizontal   (currently none; outer scroll applies all(24))
left border        1px dashed Palette.ink22     (currently a bare SizedBox(width: 24))
column gap         18                            (from SizedBox(height: 16))
scroll             the rail is its own scrollable, independent of the centre feed
separators         two rules, each height 1, colour Palette.ink16, full rail content width,
                   between section 1|2 and 2|3
section container  NO background, NO border, NO radius, NO shadow, NO padding
                   remove the StickerCard wrapper from sections 1 and 2 (`this_week_garden.dart:24`,
                   `today_capture_buttons.dart:71`) and from the OUTER wrapper of section 3
                   (`on_this_day_card.dart:94`).
                   Section 3 keeps an INNER card — see the nuance note below. Do not read this
                   line as "the on-this-day memory loses its card"; it does not.
```

Section headers move to `sectionHeaderAccent` (Caveat 17 w600 sage) with the prototype's lowercase copy and per-section bottom margins:

| Section | Copy | Margin-bottom | Citation |
|---|---|---|---|
| 1 | `this week's garden` | 2 | `:154` |
| 2 | `capture a moment` | 10 | `:164` |
| 3 | `on this day` | 9 | `:173` |

**The section-3 nuance, stated precisely.** Section 3 alone **does** have a card in the prototype (`:174`), but its header (`:173`) sits **outside** that card. The app currently nests the header inside one `StickerCard` that serves as both the section wrapper and the memory card. D1 splits them: the header moves out and becomes a bare section header like the other two; the memory card remains as a card, keeping its current `StickerCard` styling until D4 retargets it to `radius 13 / cardWarm / cardDefault shadow / clipped band`. **D1 merged alone must not leave the memory content unwrapped** — an on-this-day memory floating on the rail with no card is a visible bug.

Independent scroll: split the single `SingleChildScrollView` wrapping the Row into two scrollables — one for the centre column, one for the rail.

**Must not regress**: the desktop-vs-phone split is correct — the rail renders only in the `withRail` layout and the phone layout has no rail (`today_layout.dart:5-11`, `today_screen.dart:37-58`). Keep it. The centre column's scroll position and the feed's 12px card spacing are unaffected.

**Acceptance criteria**: the rail reads as three flat bands of content separated by thin ruled lines, not three heavy outlined drop-shadowed boxes. A dashed vertical seam divides it from the feed. Scrolling the entries leaves the week garden and capture buttons pinned in place.

---

#### D2 — Week garden grid and cell chrome

**Outcome**: the week is a two-row 4+3 block of day tiles, each a real tile with a state-appropriate treatment, and tapping one opens the Calendar.

**Files**: `lib/features/today/this_week_garden.dart`, `lib/features/today/today_week.dart`, new `test/features/today/this_week_garden_test.dart`

**Depends on**: A1, A2, D1

**Target values**

Grid (`:156`): `grid-template-columns: repeat(4, 1fr); gap: 8` holding 7 cells — a ragged 4+3 block (Mon-Thu / Fri-Sun with an empty fourth slot). Cell width derives to 50.5px at the 266px rail. Implement as two `Row`s of four and three, or a `GridView`/`Wrap` with a fixed 4-column constraint — **not** a single 7-across `Row`.

Date-range subtitle (`:155`), between the header and the grid: `Jun 30 – Jul 6` — en dash U+2013, 3-letter months, no year — in `caption10Sans` (Instrument Sans 10 w400 `#a08a70`), `margin-bottom: 11`.

Cell container, three states, all `text-align: center; border-radius: Shapes.radiusCell 10; padding: 6 top / 0 horizontal / 4 bottom`:

| State | Background | Border | Shadow | Citation |
|---|---|---|---|---|
| today | `Palette.cardLight` `#fff5ea` | `1.5px Palette.coral` | `Shadows.cellToday` `1.5px 1.5px 0 rgba(199,106,84,.3)` | `:1608` |
| filled | `Palette.cardWarm` `#f8efe0` | `1.5px Palette.ink` | `Shadows.cellFilled` `1.5px 1.5px 0 rgba(74,59,46,.18)` | `:1609` |
| empty | transparent | `1.5px DASHED Palette.ink35` | none | `:1610` |

Empty cells additionally hold a **27x27** circle bordered `1.5px dashed Palette.dashMuted` `#c3b39a` (`:1606`) — the current code uses `Palette.placeholder` `0xFFB3A58C`, which is wrong.

Glyph size **27** (from 26), matching the empty circle (`:1606`).

Label (`:1611`): `caption8Sans` — Instrument Sans **8** w600 — `margin-top: 1` (from `SizedBox(height: 6)`), with three colour states:

| State | Colour |
|---|---|
| today | `Palette.coral` `#c76a54` |
| has bloom | `Palette.muted` `#a08a70` |
| empty | `Palette.dashMuted` `#c3b39a` |

Interaction (`:1607`): every cell is tappable and navigates to the Calendar destination.

**Must not regress**: `today_week.dart` already produces seven days starting Monday with an `isToday` flag (`:7`, `:47-48`, `:57-76`) and 3-letter title-case weekday labels — both correct against `:1403` and `:1611`. Do not change the week model. N25 — cells keep their existing `Semantics`/`ExcludeSemantics` treatment, extended with a button role now that they are tappable.

**Acceptance criteria**: the week shows as a two-row block of four then three tiles, each with a visible cream card, outline and small offset shadow; today's tile is bordered terracotta with a coral-tinted shadow; empty days are a dashed outline holding a dashed circle, with their weekday label dimmed lighter than the days that have blooms. Labels are a small micro-caption sitting right under the bloom. Tapping any day opens the Calendar. **The tap navigation is a behaviour change and warrants a test.**

---

#### D3 — Capture rail buttons

**Outcome**: three capture rows with icons, `Write a note` carrying the coral emphasis.

**Files**: `lib/features/today/today_capture_buttons.dart`, new `lib/design/icons/capture_icons.dart`, `test/features/today/today_capture_buttons_test.dart`, `test/features/today/today_screen_test.dart`, `integration_test/capture_ui_flow_test.dart`

**Depends on**: A1, A2, A4, D1

**Target values** (`:165-168`, `:1595-1601`)

Exactly **three** rows in fixed order, **8px** apart (`:165`, `display:flex;flex-direction:column;gap:8px`). *An earlier draft said 9px; that is the chooser's row gap at `:752`, not the rail's.*

| Row | Variant | Icon | Icon stroke |
|---|---|---|---|
| `Write a note` | **primary** — `#c76a54` fill, `#fff` text, `Shadows.emphasis` `2px 2px 0 #4a3b2e` | pencil `M4 17l8-11 8 11` + `M6 20h12` | `#fff` |
| `Record voice` | secondary — `#f8efe0` fill, `#4a3b2e` text, **no shadow** | mic | `#4a3b2e` |
| `Record video` | secondary | video camera | `#4a3b2e` |

Icons are 17x17, stroke-width 2, round caps. Geometry per row: `borderRadius: Shapes.radiusControl 12; padding: 10 vertical / 13 horizontal; gap: 10`. Label `captureLabelSans` — Instrument Sans **12** w600 — coloured per variant.

Left-aligned content (`MainAxisAlignment.start`) so the icon leads the label, matching `display:flex; align-items:center`.

**Remove the desktop `Capture` button — OQ-4 resolved to (a) on 2026-07-27.** Delete `StickerButton(label: 'Capture', onPressed: _openChooser)` (`today_capture_buttons.dart:79`) and the now-unreferenced `_openChooser` handler (`:42`). It is the fourth button that makes the rail read as four rows where the design has three, and it currently absorbs the coral emphasis that `:1598` gives to `Write a note`.

**The chooser itself is NOT deleted, and this MSP must not touch it.** Verified reachability after removal: `app_shell.dart:41` resolves `onCapture` to `_openCapture` (`:30-32`), which calls `openCapture(context, ref, …)`; `bottom_bar_shell.dart:116` binds it to the phone centre tab. `today_capture_buttons.dart` is the only mount point in `lib/` that this MSP removes, and it is not the phone path. `CaptureChooser`, `capture_chooser_sheet.dart` and the chooser's `'Coming soon'` state all survive untouched as the phone entry point (preserve item, §2.6).

**Three test files go red with the button and must change in this MSP** — omitting them is an MSP-shippability failure:

| File | Line | Current | Required change |
|---|---|---|---|
| `test/features/today/today_capture_buttons_test.dart` | 43 | `await tester.tap(find.text('Capture'))` | retarget to the chooser's phone entry point, or delete the case if it only covered the desktop button |
| `test/features/today/today_screen_test.dart` | 89 | `expect(find.text('Capture'), findsOneWidget)` | assert **three** capture rows and no `Capture` button |
| `integration_test/capture_ui_flow_test.dart` | 54 | `await tester.tap(find.text('Capture'))` | drive the flow through `Write a note` instead |

`test/app/shell/bottom_bar_shell_test.dart:52` (`the center capture invokes onCapture`) covers the **phone** path and must stay green **unchanged** — if it fails, the chooser was wrongly deleted.

**Must not regress**: the three route labels and their order are exact against `:1598-1600` and stay (`capture_route.dart:21-36`). The chooser and its `'Coming soon'` state (§2.6) survive on phone, per the reachability trace above.

**Acceptance criteria**: the rail shows **exactly three** capture rows. `Write a note` is a terracotta button with white text, a white pencil icon and a hard ink shadow. `Record voice` and `Record video` are warm cream, shadowless, with ink-stroked mic and video icons. All three labels are visibly smaller than before. On phone, the centre tab still opens the chooser.

---

#### D4 — On this day card

**Outcome**: the memory is a hatched thumbnail band above a small serif title and micro-meta line.

**Files**: `lib/features/today/on_this_day_card.dart`, `lib/features/today/today_memory.dart`, `lib/features/today/today_date.dart`

**Depends on**: A1, A2, A5, D1

**Target values** (`:174-176`)

```
card           background Palette.cardWarm #f8efe0
               border 1.5px Palette.ink
               borderRadius Shapes.radiusPill 13   (from 16)
               clipBehavior hardEdge  (overflow:hidden — the band bleeds to the card edge)
               boxShadow Shadows.cardDefault  2px 2px 0 rgba(74,59,46,.16)
               NO padding on the card itself
band           height 82, CrossHatchPlaceholder variant photo
               #e2d3ba / #ecdfc8 at 6px / 12px pitch
               centring 'memory · {N} year{s} ago' in monoMicroSans
               monospace 7 w500 #a08a70
text block     padding 9 vertical / 11 horizontal
title          the entry title in memoryTitleSerif  Newsreader 12 w500 ink
meta           '{Mon D, YYYY} · felt {mood}' in caption9Sans
               Instrument Sans 9 w400 #a08a70, margin-top 1
```

The meta date is the **short** form `Jul 5, 2024`, not `longDateLabel`'s `Saturday, July 5, 2025`. The 34px mood bloom and the 2-line italic preview are removed from the populated state; the flower is represented by the `felt {mood}` phrase.

**Must not regress**: the additive empty and error states (`on_this_day_card.dart:36-40`, `:116-123`) are preserve items with no prototype counterpart. They stay. Restyle them to sit in the same card shell: the empty state keeps its dashed placeholder with copy `No memory from this day in past years yet.`, and the error state keeps `Couldn't load your past-year memory.` in `Palette.danger`. Both must remain reachable.

**Acceptance criteria**: the memory renders as a cross-hatched band captioned `memory · 1 year ago` in tiny monospace, above a small serif title and a `Jul 5, 2024 · felt warm` micro-line. The section header sits outside and above the card. On a day with no past-year memory, the dashed empty box still appears.

---

### Cluster E — Flower art

Per the implementation research, all bloom art stays in `FlowerPainter` as procedural Dart. **No `flutter_svg` or `vector_graphics` dependency is added.** The prototype's own blooms are generated from a JS `FLOWERS` map using primitive shapes (`<ellipse>`, `<circle>`, simple `<path>` with `rotate()`), not exported vector-tool art (`Field Notes.dc.html:1044-1057`), so there is no arbitrary bezier fidelity to preserve and the CustomPainter matches the source by construction. It also keeps per-mood tinting as a runtime `Paint.color` assignment rather than N pre-tinted assets — see the research recommendation for Q1.

#### E1 — Flower spec contract: headless glyphs and per-flower ink

**Outcome**: the compact glyph is a bloom head that fills its box, outlined in its own tinted ink at its own weight.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `test/design/flowers/flower_spec_test.dart`

**Depends on**: A1

**Target contract changes**

1. `FlowerSpec` gains `strokeColor` and `strokeWidth` (expressed in 44-unit viewBox units, scaled at paint time by `d / 44`). The single shared `Paint _stroke(double d)` at `flower_painter.dart:42-47` stops hardcoding `Palette.ink`.
2. **`FlowerPainter` grows an explicit render-path flag, and E1 must add it before removing any stem.** There is today no compact-versus-garden branch: `FlowerPainter.paint` (`lib/design/flowers/flower_painter.dart:16-40`) calls `_straightStem()` for every style except `heartPendants`, and `lib/features/garden/paint/meadow_painter.dart:95-105` calls that same painter for every meadow bloom. Deleting `_straightStem()` outright would leave the Garden screen full of stemless floating heads until E4 lands — **an MSP that ships a visibly broken screen, which the governing invariant forbids.**

   Required shape: `FlowerPainter(spec, {bool headless = false})`. E1 sets `headless: true` at the compact call site (`lib/design/flowers/flower_bloom.dart:40-43`) only. `meadow_painter.dart` keeps the default `false` and therefore keeps its stems and leaves, rendering exactly as it does today, until E4 replaces it with `GardenPlantPainter`. Once E4 has landed and the meadow no longer calls `FlowerPainter`, the stem code and the flag may be deleted — that cleanup belongs to E4, not E1.

   With `headless: true`, all ten selectable glyphs lose stem and leaf. Bleeding Heart keeps its arch, but the arch becomes a **short top arc**, not a descending stem (E3).
3. The bloom head centre moves from `Offset(width/2, height * 0.42)` to `Offset(width/2, height/2)` **on the headless path only**, and the head is scaled to fill the box edge-to-edge, matching a `0 0 44 44` viewBox rendered 1:1. The stemmed path keeps `height * 0.42` so the meadow's composition is unchanged.

Per-flower stroke values (`:1045-:1056`):

| Flower | Stroke colour | Width (44-unit) |
|---|---|---|
| Chrysanthemum | `#b9701f` | 0.8 |
| Aster | `#7a68a4` (disc `#c98a2a` at 1.2) | 0.9 |
| Sunflower | `#9a6a2a` | 1.0 |
| Lavender | `#6a5a8a` | 1.0 |
| Daffodil | `#d8b84a` (corona ring 1 `#c9821f` at 1.3) | 1.2 |
| Rose | `#7d2f3a` | 1.3 |
| Poppy | `#7d2a24` | 1.3 |
| Bleeding Heart | `#a8536c`, branch `#6f8a4e` at 1.8 | 1.3 |
| Peony | `#8a4a4a` | 1.4 |
| Red Spider Lily | `#d8342a`, stamens `#a82218` at 1.0 | 1.8 |

**Must not regress**: N25 — `FlowerBloom`'s Semantics image + mood/flower label wrapper is unchanged. **N21 and the Garden screen** — the meadow must render identically before and after E1; if any garden bloom loses its stem, E1 is wrong. The two ambient-only legacy kinds `wiltingRose` and `thistle` (`flower_kind.dart:12-13`, `flower_spec.dart:150-172`) are absent from the `Mood` enum and `moodOrder` and have no render site — leave them alone; they are not selectable and are out of scope. The mood-to-flower mapping and the flower display strings are exact and must not change.

**Acceptance criteria**: mood icons throughout the app are large bloom heads filling their box, with no stem and no leaf. **The Garden screen is pixel-unchanged by E1** — its plants still have stems and leaves. Each flower is outlined in a darkened relative of its own petal colour rather than the same dark brown, and the fine chrysanthemum is visibly thinner-lined than the bold spider lily. **This is a contract change and warrants a test** — extend `flower_spec_test.dart` to assert every spec carries a stroke colour and width and that none matches `Palette.ink` by default.

---

#### E2 — Bloom geometry rewrite, part 1: Peony, Rose, Poppy, Sunflower

**Outcome**: four of the ten blooms match their prototype silhouettes exactly.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `lib/design/flowers/flower_palette.dart`

**Depends on**: E1

**Target geometry**, all in the 44-unit box:

**Peony (happy)** (`:1045`) — a cluster-of-blobs, not a petal ring. Six overlapping circles in paint order:
```
(22,15) r8   #f2a9b2
(14,22) r8   #ed97a4
(30,22) r8   #ed97a4
(18,29) r8   #f2a9b2
(26,29) r8   #f2a9b2
(22,23) r6.5 #e4788a   centre
stroke #8a4a4a width 1.4, StrokeJoin.round
```
This replaces `roundPetals` with 12 + 12 teardrop petals and its peach `0xFFEFC7A0` centre entirely.

**Rose (love)** (`:1047`) — a spiral, not a petal ring:
```
filled disc  circle(22,22) r14  #d76a76
open arc 1   M22 10 a12 12 0 1 1 -8 21     fill none
open arc 2   M22 14 a8 8 0 1 1 -5 14       fill none
centre       circle(22,22) r3.5  #a83f4d   no stroke
group stroke #7d2f3a width 1.3
```
The two arcs must be rendered as open, unfilled stroked paths. There is no arc-drawing code in the painter today; it must be added.

**Poppy (tired)** (`:1050`) — structure is already the closest of any flower; correct the colours:
```
4 lobes  circle r8 at (22,13) (13,24) (31,24) (22,30)  all #e0574a   (from 0xFFC64B3A)
centre   circle(22,22) r5  #3a2420
stroke   #7d2a24 width 1.3   (from ink #4a3b2e)
```

**Sunflower (warm)** (`:1046`) — eight fat petals, not sixteen rays:
```
8 ellipse petals  rx3.4 ry7 at cx22 cy9, rotated 0/45/90/135/180/225/270/315 about (22,22)
                  fill #f2c14e   (from 0xFFE6B34D, petalCount 16)
centre disc       circle(22,22) r7  #7a4a24
group stroke      #9a6a2a width 1.0
```

**Must not regress**: N25. The `FlowerKind` enum values and their display strings are unchanged. Existing `flower_bloom_test.dart` assertions on `FlowerBloom.forMood` routing must keep passing. **The Garden screen must stay renderable and non-broken at every commit in this cluster** — E2 changes petal geometry that the still-stemmed meadow path also draws, so check the meadow after E2, not only the compact glyphs.

**Acceptance criteria**: Happy is a five-blob pink peony with a deep pink heart, not a 24-petal daisy with a peach centre. Loved is a pink spiral rose, not an orange-coral 16-petal daisy. Warm has eight fat petals rather than sixteen thin rays. Tired's poppy is a brighter red with a red-brown outline.

---

#### E3 — Bloom geometry rewrite, part 2: Chrysanthemum, Daffodil, Lavender, Aster, Bleeding Heart, Spider Lily

**Outcome**: the remaining six blooms match their prototype silhouettes exactly.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `lib/design/flowers/flower_palette.dart`

**Depends on**: E1 (may run in parallel with E2; both touch the same files, so merges serialize)

**Target geometry**

**Chrysanthemum (grateful)** (`:1056`) — two rings. The painter's second-ring gate is currently `rounded && petalCount >= 8`, which excludes `rayPetals`; it must become an explicit per-spec ring list.
```
outer ring  12 ellipses rx2.2 ry8 at cy7, every 30deg   fill #d98a3c
inner ring   9 ellipses rx2 ry6  at cy12, 20deg offset / 40deg step   fill #efb663
centre       circle(22,22) r3  #a85f18   no stroke
stroke       #b9701f width 0.8
```

**Daffodil (hopeful)** (`:1055`) — three-ring trumpet, not a flat dot:
```
6 petals   ellipse rx4 ry8.5 at 60deg steps   fill #f5df84  stroke #d8b84a 1.2
corona 1   circle(22,22) r7   #f0a838  stroke #c9821f 1.3
corona 2   circle(22,22) r4   #e88f22  no stroke
corona 3   circle(22,22) r1.8 #8a5a12  no stroke
```

**Lavender (calm)** (`:1051`) — a symmetric 1-2-3-2-1 taper at fixed positions, not a zig-zag ladder. Replace the loop with explicit placement:
Every oval's `rx`/`ry` is explicit in the source — an earlier draft gave only the tip's, which is not implementable. Full set, in paint order:

```
ellipse cx=22 cy=6   rx=2.7 ry=3.7
ellipse cx=18 cy=11  rx=3.0 ry=4.0
ellipse cx=26 cy=11  rx=3.0 ry=4.0
ellipse cx=16 cy=17  rx=3.1 ry=4.2
ellipse cx=22 cy=16  rx=3.1 ry=4.2
ellipse cx=28 cy=17  rx=3.1 ry=4.2
ellipse cx=18 cy=23  rx=3.0 ry=4.0
ellipse cx=26 cy=23  rx=3.0 ry=4.0
ellipse cx=22 cy=29  rx=2.8 ry=3.8
fill #9a86c4  stroke #6a5a8a 1.0
no centre, no stem, no leaf
```
Note the middle row's centre oval sits at `cy=16`, one unit **above** its two flankers at `cy=17` — that asymmetry is deliberate and is what makes the spike read as tapering rather than banded.

**Aster (anxious)** (`:1054`) — violet, twelve petals, self-stroked disc:
```
12 ellipse petals  rx2.3 ry7 every 30deg   fill #a892cf   (from #7E8FC9 blue, count 22)
centre             circle r5.5  fill #f2c14e  stroke #c98a2a width 1.2
petal stroke       #7a68a4 width 0.9
```

**Bleeding Heart (sad)** (`:1052`) — three hearts under a short top arch:
```
arch     M6 9 Q 20 4 36 11   fill none  stroke #6f8a4e width 1.8  StrokeCap.round
hearts   three, at x=13, x=22 (hung 3 lower, y=18), x=31
         fill #e07d98  stroke #a8536c 1.3
teardrop per heart, e.g. M11.7 21 L13 26 L14.3 21 Z   fill #fbeef0
```
The current long cubic descending to `(0.20w, 0.95h)` is replaced. Four hearts become three.

**Red Spider Lily (angry)** (`:1053`) — all-stroke, no fill:
```
wrapper    fill='none'
6 recurved quadratic petals   stroke #d8342a width 1.8  StrokeCap.round   (from 8 filled loops)
4 thin stamens                stroke #a82218 width 1.0                    (from 8)
centre     circle(22,23) r2.4  fill #7d1a14   (from a coral dot identical to the petals)
```

**Must not regress**: N25. `flowerSpecFor` must keep resolving every `FlowerKind`, including the two ambient-only legacy kinds, so `meadow_painter.dart` keeps compiling until E4 lands. As in E2, the still-stemmed meadow path renders these same specs — verify the Garden screen after E3 as well as the compact glyphs.

**Acceptance criteria**: Grateful is a layered pom-pom with a darker outer ring over a lighter inner one. Hopeful has a visible layered trumpet in place of a flat orange dot, on paler yellow petals. Calm is a compact tapering spike rather than florets zig-zagging along a stalk. Anxious is a violet 12-petal aster with a yellow disc, not a blue 22-ray starburst. Sad is three hearts under a short dark-green arch. Angry is a delicate unfilled six-stroke spidery outline, not a solid red eight-armed pinwheel.

---

#### E4 — Garden plant art set and the glyph size ladder

**Outcome**: the garden meadow grows tall stemmed plants while every compact site renders its glyph at the designed size.

**Files**: new `lib/design/flowers/garden_plant_painter.dart`, new `lib/design/flowers/garden_plant_spec.dart`, `lib/features/garden/paint/meadow_painter.dart`, `lib/features/calendar/widgets/calendar_day_cell.dart`, `lib/features/garden/widgets/mood_tally_chips.dart`, `lib/design/flowers/flower_painter.dart` (remove the now-dead stemmed path)

`lib/features/mood/mood_banner.dart` is **not** in E4's file list — C2 owns the Today mood-card glyph size (54) and F2 owns the picker tile size (44). E4 must not re-touch either, or two MSPs collide on the same lines.

**Depends on**: E1, E2, E3

**Target values**

Art-set split (`:1071`, `:1198`): introduce a second painter for the meadow. `gardenPlant(mood)` in the prototype is a memoized full botanical plant with its own stem, leaves, thorns, sepals and buds at a **tall** viewBox — observed heights 190, 196, 200, 205, 206, 210, 214, 236 and 240 against a width of 100, i.e. aspect ratios 1.9 to 2.4, rendered `preserveAspectRatio='xMidYMax meet'` (bottom-anchored). The meadow currently calls `FlowerPainter(...).paint(canvas, Size.square(bloom.size))` — a 1:1 box (`meadow_painter.dart:95-105`). It must call the new painter with a tall, bottom-anchored box.

Glyph size ladder at compact render sites:

| Site | Target | Current | Citation |
|---|---|---|---|
| Today mood card | 54 | 44 | `:94` |
| Mood empty-state ghost, day-detail strip | 46 | 46 / varies | `:101` |
| Picker tile | 44 | 56 | `:444` |
| Calendar day cell | 40 | 28 | prototype calendar cell |
| Day-list / search row | 40 | 40 (match) | `:255` |
| Nav brand lockup | 32 | absent until B2 | `:61` |
| Week-garden cell | 27 | 26 | `:1606` |
| Garden tally chip | 24 | 18 | prototype tally chip |

The Today mood card size (54) is set in C2; the picker tile size (44) is set in F2; E4 covers calendar, tally chips and any remaining site.

**Must not regress**: N25 — `FlowerBloom`'s Semantics image + mood/flower label survives at every retargeted size site (calendar day cell, garden tally chips). N21 — any change to the meadow must route through `resolveGardenMotionProfile`; the OS `disableAnimations` signal and the bloom-count ceiling continue to force the reduced profile (`garden_motion.dart:3`, `:6-12`, `garden_view.dart:43-47`). The additive `Palette.sunGlow` `Color(0x8CF4C960)` warm glow is a preserve item — the prototype does not draw it (`grep -c f4c960` returns 0) but it is an enrichment, not a defect. Keep it. The garden palette hexes `#D6DBAC`, `#C4CE95`, `#B1BD80`, `#A0B371`, `#96AA69`, `#8A6C44`, `#775A37` are all verbatim in the prototype meadow scene and stay.

**Acceptance criteria**: the garden meadow shows tall stemmed plants anchored to the soil line rather than squat icon-sized flowers. Calendar day cells and garden tally chips carry visibly larger blooms; the mood picker's blooms are smaller. This MSP is likely to exceed 400 LOC on its own — **split the garden plant painter from the size-ladder retargeting into two commits** if the diff runs long.

---

### Cluster F — Mood picker

#### F1 — Picker panel chrome and copy

**Outcome**: the picker is a wide warm panel floating on a soft drop shadow, with its handwritten subtitle restored.

**Files**: `lib/features/mood/mood_picker_sheet.dart`, `lib/features/mood/mood_picker.dart`

**Depends on**: A1, A2, A3

**Target values** (`:438-441`)

```
panel width    420 FIXED   (from ConstrainedBox maxWidth 360, shrink-wrapping)
surface        Palette.cardWarm #f8efe0   (from cardBright #fffaf1)
border         2px Palette.ink            (from 1.5px)
borderRadius   Shapes.radiusXl 20         (from cardBorderRadius 16)
padding        22                          (from 20)
boxShadow      Shadows.softLift  0 20px 50px -16px rgba(50,35,20,.6)
               (from a hard 3px offset, blur 0)
scrim          rgba(42,36,29,.28)  Color(0x472A241D)
               (from Palette.ink at 32% = rgba(74,59,46,.32))
entrance       180ms ease-out, scale 0.96 -> 1.0, fade 0 -> 1
               (from 220ms easeOutCubic, scale 0.92 -> 1.0)
title          'How are you feeling?' in headlineSerif  Newsreader 21 w500 ink, centred
               (from titleSerif 24 w600)
subtitle       "choose today's bloom" in subtitleAccent  Caveat 14 w600 #a08a70
               centred, margin-top 1   (currently absent)
grid margin-top 16
```

Because the panel is a hard 420 rather than a shrink-wrap, it must degrade gracefully below 420 logical px of available width — clamp to available width minus the scrim inset rather than overflowing.

**Must not regress**: N25 — tile button + selected semantics survive. Scrim dismissal behaviour is already correct — tapping outside closes without selecting, with a semantic barrier label (`mood_picker.dart:16-17` vs `:438`) — and stays. A3 must already have landed; do not reintroduce a non-Material `pageBuilder`.

**Acceptance criteria**: the picker is a visibly wider, warmer, thicker-edged panel floating on a soft blurred shadow instead of a narrow near-white card on a hard offset. A handwritten `choose today's bloom` sits under the heading. No yellow underline anywhere.

---

#### F2 — Picker tile grid

**Outcome**: ten tiles in a tidy 4/4/2 grid, each a visible card naming both mood and flower.

**Files**: `lib/features/mood/mood_picker_grid.dart`

**Depends on**: A1, A2, E1, F1

**Target values**

Grid (`:442`): `grid-template-columns: repeat(4, 1fr); gap: 10` — 10 tiles flowing **4 + 4 + 2**, the last row **left-aligned in the first two columns**, not centred. Replace the `Wrap(alignment: center, spacing: 16, runSpacing: 16)`. At the F1 420px panel with 22px padding and a 2px border, the content width is 372px, so a 4-column track is `(372 - 30) / 4 = 85.5px` — comfortably above the 44px glyph plus tile padding, so the 4-column break is achievable.

Tile, unselected (`:1554`):
```
background     Palette.cardBright #fffaf1   (currently null/transparent)
border         1.5px Palette.ink20 rgba(74,59,46,.2)   (currently null)
borderRadius   Shapes.radiusMd 14   (from radiusSm 11)
padding        11 vertical, 6 horizontal   (from 8/8)
```

Tile, selected (`:1553`):
```
background     Palette.cardLight #fff5ea   (from panelCoralTint 0x12C76A54)
border         2px Palette.coral            (from 1.5px)
borderRadius   14
boxShadow      Shadows.tileSelected  2px 2px 0 rgba(199,106,84,.3)   (currently none)
```

Tile content (`:444`):
```
glyph          44x44   (from 56)
line 1         mood.label in Instrument Sans 11 w600 Palette.ink, margin-top 5
               (from captionSans 12 w500 Palette.muted, SizedBox(height: 6))
line 2         flowerKind.label in caption9Sans  Instrument Sans 9 w400 #a08a70
               (currently absent)
```

**Must not regress**: N25 — `Semantics(button: true, selected: …)` per tile stays. The canonical `moodOrder` (happy, love, warm, grateful, hopeful, calm, anxious, tired, sad, angry) is exact against `:1059` and drives the grid order — do not resort.

**Acceptance criteria**: the picker shows four flowers per row over two full rows plus a two-tile row left-aligned underneath, replacing the 3/3/3/1 centred layout. Every tile has a visible near-white card with a faint outline. The selected tile gains a cream fill, a thicker coral border and a hard coral shadow. Each tile names its mood in dark text and its flower — `Peony`, `Rose` — in a smaller muted line beneath.

---

#### F3 — Picker phone bottom-sheet variant

**Outcome**: on a phone the picker slides up from the bottom edge as a sheet.

**Files**: `lib/features/mood/mood_picker.dart`, `lib/features/mood/mood_picker_sheet.dart`, `lib/features/mood/mood_picker_grid.dart`

**Depends on**: F1, F2

**Target values** (`:731-733` phone sheet, `:1553-1554` compact tile). The desktop panel at `:439` is **not** the source for this MSP — an earlier draft cited it by mistake.

```
scrim          rgba(42,36,29,.34)  Color(0x572A241D), align-items flex-end   proto :731
panel width    100%                                                          proto :732
border         2px Palette.ink on the TOP edge only
borderRadius   22 22 0 0
padding        18 top, 16 horizontal, 22 bottom
boxShadow      Shadows.pickerSheetLift  0 -12px 30px -12px rgba(50,35,20,.5)
entrance       fn-sheet slide-up 240ms cubic-bezier(.2,.8,.2,1)
grab handle    38 x 4, borderRadius 3, Palette.ink30 rgba(74,59,46,.3)
               margin 0 auto 12
tile compact   padding 8 vertical / 4 horizontal, glyph 34x34,
               NO second label line (flower name omitted on phone)
```

Branch on the same signal `lib/app/shell/shell_layout.dart:5-9` already uses for the sidebar-vs-bottom-bar split, so form-factor detection stays in one place.

**Must not regress**: N25. The desktop path from F1/F2 is unchanged — this MSP adds a branch, it does not replace the dialog.

**Acceptance criteria**: on a phone the picker slides up from the bottom edge with a grab handle at the top, its tiles compact and showing only the mood name. On desktop nothing changes.

---

#### F4 — Re-pick confirmation and planted toast

**Outcome**: replacing an existing bloom asks first and confirms after.

**Files**: `lib/features/mood/mood_banner_for_date.dart`, new `test/features/mood/mood_repick_test.dart`

**Depends on**: A3, F1

**Target behaviour** (`:1345`)

When a mood is picked for a day that **already has one**, show a confirm dialog before writing:
```
title        'Change today's bloom?'   (or 'Change this day's bloom?' for a past day)
message      'Set {dayLabel} to {flowerName} · {moodLabel}? Your current bloom will be replaced.'
confirmLabel 'Change mood'
danger       false
```
On confirm: play the `pencil` sound cue, write the mood, then toast `Mood planted · {flowerName}`.

Picking a mood for a day with **no** existing mood writes directly with no confirmation, as today.

**Must not regress**: N20 — the `pencil` cue must route through `GatedSoundService` so it respects the Sound effects setting and swallows playback errors. The existing failure path that sets an inline error string on a failed write must survive (`mood_banner_for_date.dart:28-49`).

**Acceptance criteria**: re-picking a mood on a day that already has one opens a confirmation naming the new flower and warning that the current bloom will be replaced; cancelling leaves the existing bloom untouched. Confirming plays a cue, writes, and shows a `Mood planted · Peony` toast. **This is a behaviour change and warrants a test** — assert the confirm gate blocks the write on cancel and permits it on confirm, and that the no-existing-mood path skips the dialog.

---

### Cluster G — Capture composers

This cluster carries the heaviest preserve load. Every MSP here inherits N12, N13 and N14, and G5 through G7 additionally inherit N1 through N10 by proximity — the recorder sheets sit next to the playback stack and share widgets with it.

#### G1 — Shared composer shell

**Outcome**: the **three** capture composers — note, voice, video — share one wide warm panel with the prototype's scrim and sprig art, and the note composer gains the header bar. The capture chooser is **not** part of this shell.

**Files**: new `lib/features/capture/core/composer_shell.dart`, new `lib/design/art/sprig_art.dart`, `lib/features/capture/text/text_composer.dart`, `lib/features/capture/voice/voice_composer.dart`, `lib/features/capture/video/video_composer.dart`

`lib/features/capture/chooser/capture_chooser.dart` is **excluded** — see the scope correction below.

**Depends on**: A1, A2, A3, A4

**Target values**

**Scope correction made during review.** An earlier draft said "all four capture dialogs share one wide warm panel". The prototype does not do this. The 760px panel at `:460` sits inside `<sc-if value="{{ composerOpen }}">` (`:458`) and contains exactly three branches: `isTextComposer` (`:462`), `isVoiceComposer` (`:477`), `isVideoComposer` (`:501`). The **chooser is a separate phone-only bottom sheet** at `:746-756` with its own chrome (`width:100%`, `#efe2ce`, top border only, `22px 22px 0 0`) and no desktop counterpart at all. Forcing the chooser into a 760px panel would ship a design the prototype never had, and would directly contradict G4's own line that the desktop chooser keeps its centred-dialog presentation. G1 therefore covers the three composers only; the chooser is G4's alone.

Panel — one shared shell for the three composer modes (`:460`):
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

Sprig art (`:461`): `position: absolute; top: -10; right: -8; width: 120; height: 150; opacity: 0.4; ignoring pointers` — a stem stroked `#8a9a63` at width 2.2 with three leaves filled `#9bb078`, `#8fa66c`, `#a3b782`. Drawn as a `CustomPainter`, consistent with the Cluster E and B3 approach; **no SVG dependency**.

Header bar (`:463-466`) — **note composer only.** It is wrapped in `<sc-if value="{{ isTextComposer }}">` at `:462`. The voice composer has *no* header bar: its branch opens at `:478` with `padding:40px 22px 44px; text-align:center` and carries only an absolutely-positioned close X at `:479` (`left:18px; top:18px`) plus its own centred stack — that layout is G5's, not G1's. The video composer has no header either (G7). An earlier draft claimed the bar was shared by text and voice and pointed at G5 for video; both were wrong.

Note-composer header bar:
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

**Must not regress**: N14 — opening a composer must still never start recording. `barrierDismissible: false` on the video composer stays. Each mode keeps its own `pageBuilder` return type (`String?` entry id for the composers) so callers are unaffected. A3's Material ancestor stays in place inside the new shell. **N12** — the camera picker mounted at `video_recorder_sheet.dart:105` must still fit and function inside the widened panel. **N13** — the nudge/cap/denied surfaces must still be reachable at 760px; G1 widens the box, it does not remove anything from it. The chooser is untouched by G1 and must render exactly as it does today until G4.

**Acceptance criteria**: the note, voice and video composers are the same wide warm-paper panel with a 2px ink edge and a large soft drop shadow, floating over a blurred warm-vignette background. A faint botanical sprig sits in the top-right corner. The note composer carries a header bar with a corner close X, a handwritten terracotta title over a small date-and-time line, and a terracotta save button pinned right. The voice composer shows a corner close X and its existing centred stack, unmoved. The capture chooser is visually unchanged by this MSP.

---

#### G2 — Note composer writing surface

**Outcome**: writing happens on a full sheet of paper set in large serif, not in a small outlined textarea.

**Files**: `lib/features/capture/text/text_composer_sheet.dart`

**Depends on**: A1, A2, G1

**Target values** (`:467-468`)

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

**Placeholder copy — OQ-5 resolved to (b) on 2026-07-27.** Adopt the prototype's *treatment* (italic serif, 19/38, 34% ink, top 44 / left 54) but **not** its full string. The prototype's `try “# ” for a title, “- ” for a list, “1. ” for steps` advertises a markdown engine that is out of scope (§6.1); shipping it promises behaviour the editor does not have. Ship `Start writing…` alone. When the markdown engine lands, extend the placeholder to the prototype's full string in that spec — the treatment already matches, so it is a one-string change.

The line height is **38px absolute on a 19px font**, i.e. a `height` multiplier of exactly 2.0.

**Must not regress**: the `EditableText` controller, focus node, cursor colour and keyboard type are unchanged — only the style, sizing and chrome move. Save-button enablement based on non-empty input (currently `Opacity(0.5)`) survives until G3 replaces it with the guard toast.

**Acceptance criteria**: the note composer opens onto a tall sheet of warm paper that runs edge to edge under a dashed rule, with generously leaded 19px serif text and an italic serif `Start writing…` placeholder. The placeholder must not mention markdown shortcuts.

---

#### G3 — Note composer copy and edit variants

**Outcome**: the composer names itself correctly for new versus edit, and empty saves are guarded with a message rather than a dead button.

**Files**: `lib/features/capture/text/text_composer_sheet.dart`, `lib/features/capture/text/text_composer.dart`, `lib/features/day_detail/day_detail_edit_note.dart`

**Depends on**: A3, G1, G2

**Target values** (`:1694-1695`, `:1387-1388`)

| Context | Title | Save label |
|---|---|---|
| new note, today | `New note` | `Save` |
| new note, past day | `New note · {day}` | `Save` |
| editing | `Edit note` | `Save changes` |

Editing an existing note and pressing save opens a confirm: title `Save changes?`, message `Update this note with your edits?`.

Attempting to save empty input shows the toast `Write something first` rather than disabling the button.

The saving label becomes an ellipsis character rather than three ASCII periods, matching the app's other in-flight labels.

**Must not regress**: N23 — `editNoteFailedMessage` and its inline failure capture (`day_detail_edit_note.dart:12`, `:46-49`) must stay reachable. The composer's return contract (an entry id, or null on cancel) is unchanged so `day_detail_edit_note.dart` and `capture_route.dart` keep working.

**Acceptance criteria**: opening the composer from Today reads `New note` with a `Save` button; opening it to edit an existing note reads `Edit note` with `Save changes` and confirms before writing. Pressing save with an empty editor shows `Write something first` instead of nothing happening.

---

#### G4 — Capture chooser

**Outcome**: the chooser is a bottom sheet on phone with bordered rows carrying icons and inner subtitles.

**Files**: `lib/features/capture/chooser/capture_chooser_sheet.dart`, `lib/features/capture/chooser/capture_chooser.dart`

**Depends on**: A1, A2, A3, A4, D3 (reuses the capture icon set)

**Target values**

Presentation, phone (`:747-749`):
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

Title and subtitle (`:750`):
```
title      'Capture a moment' in sectionSerif  Newsreader 17 w500 ink, CENTRED
           (from titleSerif 24 w600, left-aligned)
subtitle   'how do you want to plant today?' in Caveat 12 w600 Palette.muted, centred
           (currently absent)
```

Rows (`:752-755`), 9px apart:
```
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

Row subtitle copy: `put the day into words`, `speak it, hands-free`, `a moving snapshot`.

**Must not regress**: the additive `'Coming soon'` unavailable state (`capture_chooser_sheet.dart:14`, `:81`) is a preserve item and must keep rendering for types that are not yet wired. The three route labels and their order are exact and stay. On desktop, the chooser keeps its centred-dialog presentation — the bottom sheet is the phone branch only.

**Acceptance criteria**: on phone the chooser slides up from the bottom edge with a grab handle. Its heading is a centred medium serif line with a handwritten `how do you want to plant today?` beneath it. Each option is one bordered row containing an icon and a stacked title-over-subtitle, with `Write a note` in terracotta with a hard shadow and the other two in warm cream with none.

---

#### G5 — Voice recorder: stage, timer and waveform

**Outcome**: the voice composer is anchored by a big coral mic button with a pulsing halo, a large elapsed-time readout and a twelve-bar wave.

**Files**: `lib/features/capture/voice/voice_recorder_sheet.dart`, `lib/features/capture/voice/record_voice_recorder.dart`, `lib/features/capture/voice/voice_recorder.dart`, `lib/design/motion/waveform_bob.dart`, `lib/design/motion/glow_pulse.dart`

**Depends on**: A1, A2, G1

**Target values**

Header and hints — header `:480`, hint element `:488`, hint strings `:1703`. *(An earlier draft cited `:479`, which is the close X, and `:487`, which is the elapsed-time readout.)*
```
header      'New voice memo' in composerTitleAccent  Caveat 16 w600 Palette.coral,
            margin-top 4   (from 'Record voice' in titleSerif Newsreader 24 w600)
hint idle   "tap the mic when you're ready"   in Caveat 15 w600 Palette.muted
hint rec    'listening… speak freely'
hint paused 'paused · resume when you're ready'
            (from 'Tap record when you are ready.' / 'Recording…' in captionSans)
```

Record control — stage `:483`, halo `:484`, button `:485`. *(An earlier draft cited `:482`/`:484`; `:482` is the paused status row and `:484` is the halo, not the button.)*
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
           i.e. a scale-and-fade pulse, NOT a blur/spread pulse. `GlowPulse`'s current
           maxBlur/maxSpread model must be replaced by a scale+opacity model, not retuned.
```
The existing `GlowPulse` widget has zero call sites (`glow_pulse.dart:6-17`); retune it to these values and use it here rather than adding a second pulse primitive.

Elapsed time (`:487` readout, `:1396` `startRec`'s 250ms `setInterval`): `Newsreader 38 w400 Palette.ink`, placed below the record button, value `M:SS` starting at `0:00`, ticked every **250ms**. `RecordVoiceRecorder`'s private `Stopwatch` (`record_voice_recorder.dart:27`) must be surfaced through the `VoiceRecorder` interface as an elapsed stream or ticking value.

Waveform (container `:489`, mount `:490`, bar generator `:1261-1263`):
```
container  gap 3, height 40, margin 12 top / 4 bottom
bars       exactly 12, each width 4, borderRadius 3
heights    [.30,.65,.95,.50,.80,.40,1.00,.55,.85,.35,.70,.45] of 40px
colour     #c76a54 when the ratio > 0.6, else #dcae9a
motion     fn-bob scaleY .45 -> 1, per-bar durations 700 / 850 / 1000 / 1150 ms
```
`WaveformBars` gains explicit `heights`, `twoToneThreshold` and `perBarDurations` parameters. Its current defaults (5 bars, width 3, spacing 3, maxHeight 20, single coral, one 700ms sine controller) stay as defaults so the entry-card consumer is unaffected until G8.

Idle rule (`:491`): when not recording, render `width 120; height 2; borderRadius 2; background Palette.ink18` in place of the waveform — replacing the current 12x12 dot-and-sentence strip.

Recording status row (`:481`):
```
gap        7
dot        8 x 8 circle, Palette.danger #c0392b, NO border
           fn-blink 1200ms step-end infinite — HARD on/off, not a fade
label      'Recording' UPPERCASE, Instrument Sans 12 w600,
           letterSpacing 0.08em, Palette.danger
           (from 'Recording…' in captionSans muted, 12x12 outlined dot, 900ms easeInOut fade)
```
`Blink` gains a `stepped` mode so the hard on/off is available without a second primitive.

**Must not regress**: N14 — opening the sheet must not start recording. N20 — any cue stays behind `GatedSoundService`. The `VoiceRecorderPhase` idle/recording/saving states and the existing save path are unchanged by G5; the paused state arrives in G6.

**Acceptance criteria**: the voice composer opens on a handwritten `New voice memo` heading above a large coral mic button on a 150px stage, with a flat 120px hairline where the waveform will be and a handwritten coaching line beneath. Tapping record makes the halo pulse, replaces the hairline with a twelve-bar two-tone wave, shows a large serif `0:03` counting up, and shows a hard-blinking red dot beside uppercase `RECORDING`.

---

#### G6 — Voice recorder: pause, review pills and discard confirmation

**Outcome**: a take can be paused and resumed, and ending one is a deliberate discard-or-save decision.

**Files**: `lib/features/capture/voice/voice_recorder_sheet.dart`, `lib/features/capture/voice/voice_recorder.dart`, `lib/features/capture/voice/record_voice_recorder.dart`, `lib/features/capture/voice/voice_composer.dart`, new `test/features/capture/voice/voice_pause_test.dart`

**Depends on**: A3, G5

**Target behaviour and values**

Add `paused` to `VoiceRecorderPhase` and `pause()` / `resume()` to the `VoiceRecorder` interface. State machine: `idle -> recording <-> paused`, with save reachable from both `recording` and `paused`.

Paused status row (`:481-482`): an 8x8 **static** dot in `Palette.statusAmber` `#c9821f` — the token already exists at `palette.dart:36` and is currently unused — plus label `Paused` uppercase, Instrument Sans 12 w600, letterSpacing 0.08em, `#c9821f`. Hint `paused · resume when you're ready`.

Review pills, shown whenever recording is active (`:494-495`):
```
Discard   background Palette.dangerSurface #fbecea
          foreground Palette.danger #c0392b
          border 1.5px Palette.danger
          borderRadius Shapes.radiusSheet 22
          padding 10 vertical / 18 horizontal
          15x15 trash icon, label Instrument Sans 13 w600
Save memo background Palette.danger #c0392b
          foreground #fff
          border 2px Palette.ink
          borderRadius 22
          padding 11 vertical / 22 horizontal
          boxShadow Shadows.emphasis  2px 2px 0 #4a3b2e
          leading 15x15 white rounded square, radius 4
          label 'Save memo'
```
These replace the persistent Cancel / `Stop & save` sticker-button row for the active-recording phase only.

Discard confirmation — copy from `:1376`, discard side-effects and the `Recording discarded` toast from `:1377`: title `Discard this recording?`, message `This take will be thrown away and nothing will be saved.`, confirmLabel `Discard`, `danger: true`. Confirm-button chrome comes from `:1692` (`confirmYesStyle`), **not** from `:1376-1377`: `font:600 12px 'Instrument Sans'; color:#fff; background:#c0392b; border:1.5px solid #4a3b2e; border-radius:11px; padding:9px 16px; box-shadow:1.5px 1.5px 0 #4a3b2e`. That is exactly A4's corrected `danger` variant, so use `StickerButton(danger)` rather than a bespoke button.

Note `:1376` also encodes a behavioural guard the app must copy: if `recState === 'idle'` the composer closes immediately with **no** confirmation. Only a take with recorded content is gated.

Toasts — chrome from `:900` (`background:#4a3b2e; color:#f6ead6; border-radius:20px; padding:8px 16px; font:600 11px 'Instrument Sans'; box-shadow:0 10px 24px -8px rgba(0,0,0,.5); gap:7px`, 13x13 leading check, `fn-rise .22s ease-out`); strings from `:1377` (`Recording discarded`) and `:1394` (`Voice memo saved`). Toast chrome: `background Palette.ink #4a3b2e; foreground #f6ead6; borderRadius Shapes.radiusXl 20; Instrument Sans 11 w600`, with a 13x13 leading check icon. The existing `Toast` widget (`toast.dart:6-36`) is currently a light `StickerCard` used only for the video nudges — restyle it to this dark pill and keep the nudge consumer working.

**Must not regress**: N14. N20 — cues behind `GatedSoundService`. Cancelling out of an armed-but-not-started session must still discard silently with no confirmation; the confirm applies only to a take with recorded content.

**Acceptance criteria**: while recording, the button row becomes a red-outlined `Discard` pill and a filled `Save memo` pill. Pausing shows a static amber dot beside uppercase `PAUSED` and freezes the timer; resuming continues it. Pressing Discard asks for confirmation and, on confirm, shows a dark `Recording discarded` toast. Saving shows `Voice memo saved`. **The pause/resume state machine and the discard gate are behaviour changes and warrant tests.**

---

#### G7 — Video recorder: dark viewport chrome

**Outcome**: the video composer is a full dark camera viewport with overlay chrome, not a cream settings card.

**Files**: `lib/features/capture/video/video_recorder_sheet.dart`, `lib/features/capture/video/camera_video_recorder.dart`, `lib/features/capture/video/camera_picker.dart`

**Depends on**: A1, A2, A5, G1

**Target values**

Viewport (panel `:460`, dark surface `:502`): the dark camera surface fills the shared 760px panel at `height: 480` (1.583:1), bleeding edge to edge under the panel's `overflow: hidden`. It replaces the light `StickerCard` with its 20px padding, `maxWidth 460` and 200px-tall `ClipRRect` preview. **There is no title and no light body** — remove `Text('Record video')` in `titleSerif` entirely (`:502-521` is the entire video branch and contains no header element).

Feed placeholder (stripes `:502`, `CAMERA FEED` label `:504`): `CrossHatchPlaceholder` variant `viewport` — `#3a352e` / `#443f37` at 8px / 16px pitch — centring the label `CAMERA FEED` in `monospace 10 w500`, `rgba(255,255,255,.3)`, `letterSpacing 0.1em`. No ink outline, no radius of its own.

Vignette (`:503`, verified): `position: absolute; inset: 0` linear gradient top to bottom, `rgba(15,13,11,.5) -> transparent 22% -> transparent 68% -> rgba(15,13,11,.72)`, drawn over the preview so overlaid controls never sit on raw video.

Close X (`:505`): 22x22 light close glyph pinned `left: 16; top: 16` inside the viewport, replacing the bottom-right `Cancel` sticker button. `barrierDismissible` stays `false`.

Timer pill (`:506` container, `:507-509` state dots, `:510` readout; tick interval `:1396`):
```
position   absolute, top 16, horizontally centred
background rgba(15,13,11,.5)
borderRadius Shapes.radiusMd 14
padding    5 vertical, 12 horizontal
gap        7
dot        8 x 8 — Palette.recordFill #e0574a blinking while recording,
                   #f0b34a static while paused,
                   rgba(255,255,255,.5) while idle
time       Instrument Sans 13 w600 #fff, value '0:00' when armed, M:SS, ticked every 250ms
```
`CameraMacosVideoRecorder`'s private `_elapsed` `Stopwatch` (`camera_video_recorder.dart:212`) must be surfaced through the `VideoRecorder` interface, mirroring G5's voice change.

Shutter (`:513` control row, `:515` shutter, `:516` pause glyph, `:517` inner dot):
```
control row  bottom 22, gap 30
shutter      70 x 70 circle, borderRadius 50%, border 4px #fff, NO background fill
             inner 24x24 circle Palette.recordFill #e0574a when not recording
             26x26 light pause icon while recording
```
This replaces the `Cancel` + `Record` / `Stop & save` sticker-button row.

Instruction line (`:512` element, `:1704` copy): `position: absolute; bottom: 70`, centred, `Caveat 13 w600 rgba(255,255,255,.72)`. Copy: idle `tap the button to start recording`, recording `recording… tap pause or stop`, paused `paused · resume or save your clip`. This replaces the boxed cream status strip.

**Must not regress**: this is the highest-preserve-load MSP in the spec.

- **N12** — the camera picker must be **re-homed inside the dark viewport chrome, not deleted.** `SettingsFieldRow` + `SettingsSelect` need a dark-surface treatment here; the remembered-device provider and the first-camera fallback are untouched. `camera_picker.dart:35`'s `Material(type: MaterialType.transparency)` wrapper stays.
- **N13** — the six-phase machine, the 5/10/20-minute nudges, the 30:00 cap hint, and the permission-denied stage all keep working. They need dark-viewport treatments: the cap hint and nudges become overlay text or dark toasts rather than cream boxes; the denied stage gets a dark-surface message. **Do not delete them for lack of a prototype counterpart.**
- **N14** — armed idle. Opening must not start recording.
- The error message line, `deniedMessage`, `savingHint` and `armingHint` all survive with dark-surface styling.

**Acceptance criteria**: opening the video composer fills the panel with a dark camera viewport. A corner X sits top-left, a dark timer pill with a state dot sits top-centre showing `0:00`, a handwritten white instruction line floats near the bottom, and a big white-ringed circular shutter with a red inner dot sits below it. The camera dropdown is still present and still remembers the last device. Recording for five minutes still produces the nudge, and the 30:00 cap hint is still visible.

---

#### G8 — Video recorder pause/resume and the entry-card voice row

**Outcome**: a video take can be paused, discarded or saved from the shutter row; the voice entry row matches its designed proportions.

**Files**: `lib/features/capture/video/video_recorder_sheet.dart`, `lib/features/capture/video/video_recorder.dart`, `lib/features/capture/video/video_composer.dart`, `lib/features/entry_cards/cards/voice_body.dart`, new `test/features/capture/video/video_pause_test.dart`

**Depends on**: G6 (reuses the discard confirm and toast), G7

**Target behaviour and values**

Video pause (`:1371` state-machine comment, `:1376-1377` discard path, `:1395` save path): add `paused` to `VideoRecorderPhase` and `pause()` / `resume()` to the `VideoRecorder` interface. Shutter tap semantics: `idle -> beginRec`, `recording -> pauseRec`, `paused -> resumeRec`.

Discard and Save circles flanking the shutter while recording is active (Discard `:514`, Save `:519`, row `:513`):
```
Discard  44 x 44 circle, background rgba(15,13,11,.5), border 1.5px rgba(255,255,255,.4)
         18x18 light trash icon
         caption 'Discard' Instrument Sans 10 w500 rgba(255,255,255,.75)
Save     44 x 44 circle, background Palette.coral #c76a54, border 1.5px #fff
         18x18 light check icon
         caption 'Save' rgba(255,255,255,.85)
```
Discard routes through G6's confirmation dialog and toast; save shows `Video saved`.

Voice entry row (`:121-124`, `:1579`) — restyle only:
```
play button  38 x 38 circle   (from 40 x 40)
             background Palette.coral, border 1.5px Palette.ink
             15x15 white play glyph with margin-left 2 optical offset
gap          12   (already correct)
waveform     flex 1, 14 STATIC bars, width 3, gap 2.5, container height 24, radius 2
             ratios [.4,.75,1,.55,.85,.35,.7,.5,.9,.45,.65,.8,.38,.6]
             three-tone ramp #c76a54 / #dcae9a / #e3c4b2
duration     Instrument Sans 11 w600 Palette.muted
```

**Must not regress**: **N11 is binding on the voice row.** The `isPlaying` state, the **two-valued elapsed/total readout**, the completion-resets-to-zero behaviour, the error placeholder and `ValueKey('voice-play-toggle')` all survive. The prototype shows a single static duration; the app must keep showing `0:03 / 0:12` in the control position. The waveform becomes static in its resting appearance but the widget must keep animating while playing — the 14-bar ratio set defines the resting silhouette, not a removal of motion. N13, N14, N20 all apply to the video half.

**Acceptance criteria**: while recording video, a dark Discard circle and a coral Save circle flank the shutter, and the shutter shows a pause glyph. Tapping it pauses; the timer dot turns static amber and the timer freezes. Tapping Discard confirms before throwing the take away. On the Today feed, voice entries show a slightly smaller coral play circle and a fourteen-bar static wave in three tints, while still displaying a running elapsed/total time and still pausing correctly.

---

### Cluster H — Verification infrastructure

#### H1 — Golden test harness for design-system leaf widgets

**Outcome**: pixel regressions in the sticker primitives and bloom painters are caught automatically.

**Files**: new `test/flutter_test_config.dart`, new `test/design/goldens/` with golden files, `test/design/widgets/`, `test/design/flowers/`

**Depends on**: A4, A5, **B3**, E2, E3 (goldens are only worth capturing once the target geometry has landed). B3 is required because the golden set includes `nav_icon_{today,calendar,garden,search}`; E2 as well as E3 because the flower goldens cover all ten blooms and E2 owns four of them.

**Rationale**: the repo currently has **zero golden coverage** — `grep -rl "golden\|matchesGoldenFile" test/ integration_test/` returns no matches. The existing suite asserts token values and wiring (`test/app/theme/app_theme_test.dart:12-23` asserts `theme.scaffoldBackgroundColor == Palette.page` and `theme.textTheme.bodyMedium?.fontFamily == TypographyTokens.sans`), which structurally cannot catch "the hard shadow got blurry" or "the bloom geometry drifted". Goldens are the only mechanism that verifies pixels ([matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)).

**Target scope** — leaf widgets and painters only, not composite screens:

| Golden | What it guards |
|---|---|
| `sticker_card_default`, `sticker_card_rotated` | fill, 1.5px outline, hard offset shadow, tilt |
| `sticker_button_primary`, `_secondary`, `_danger` | the shadow-presence distinction from A4 |
| `flower_{kind}` x 10 at 44px | every bloom silhouette from E2/E3 |
| `nav_icon_{today,calendar,garden,search}` | the B3 glyph set |
| `cross_hatch_{photo,video,viewport}` | the A5 band geometry |

**Determinism requirements** — non-optional. Golden font rendering is platform-dependent: a file generated on one OS "will likely differ from the one produced by another operating system", and Flutter-version bumps shift subpixel rendering ([Flutter docs](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)). Therefore:

1. A `test/flutter_test_config.dart` loads the three vendored variable fonts via `FontLoader` so text renders with real metrics rather than Ahem.
2. CI pins one OS and one Flutter SDK version for the golden job. Goldens generated on a developer's mac and run in Linux CI will flake on font metrics alone.
3. `--update-goldens` output is reviewed as a visual diff in the PR, never regenerated blind to make a red job green.

**Also pin the SDK for a second reason**: Flutter's behaviour of driving a variable font's `wght` axis from `TextStyle.fontWeight` landed in a specific release ([font-weight-variation breaking change](https://docs.flutter.dev/release/breaking-changes/font-weight-variation), implemented in [flutter/flutter#175771](https://github.com/flutter/flutter/pull/175771)). On an older SDK the same `TypographyTokens` code renders at a different weight. `pubspec.yaml:22` pins `sdk: ^3.12.2`; **the implementer must confirm which side of that behaviour change the installed toolchain sits on before capturing any golden with text in it.** This is currently unverified.

**Known platform limitation to document, not fix**: at fractional device pixel ratios — routine on desktop with 125%/150% display scaling or non-Retina external monitors — a 1.5 logical-px border or a small offset can land on a non-integer physical boundary and antialias into a soft grey line instead of a crisp hairline. This is architectural in Flutter, not a bug in this app ([flutter/flutter#59798](https://github.com/flutter/flutter/issues/59798), [flutter/flutter#117355](https://github.com/flutter/flutter/issues/117355)). Capture goldens at integer DPR and note the limitation; do not attempt an in-app pixel-snapping workaround as part of this spec.

**Must not regress**: N24 — H1 adds tests, it never modifies the 106 existing video/playback tests.

**Acceptance criteria**: `flutter test` produces a golden job that passes on the pinned CI configuration, and deliberately perturbing a shadow offset or a petal count makes it fail with a readable image diff.

---

## 5. Verification strategy

### 5.1 What the repo actually has

| Layer | Present | Character |
|---|---|---|
| Token / theme tests | `test/design/tokens/tokens_test.dart`, `test/design/tokens/pubspec_fonts_test.dart`, `test/app/theme/app_theme_test.dart` | Assert token **values and wiring**, not pixels. E.g. `app_theme_test.dart:12-23` asserts `theme.scaffoldBackgroundColor == Palette.page` and the body font family; `pubspec_fonts_test.dart:13-28` asserts the three families are registered under exact names, point at the vendored variable assets, and that `google_fonts` is absent |
| Design widget tests | `test/design/widgets/sticker_card_test.dart`, `test/design/flowers/flower_spec_test.dart`, `flower_bloom_test.dart`, `test/features/capture/photo/photo_tray_test.dart` | Widget and pure-data assertions |
| Playback behaviour suite | 8 files, **106 tests**, driving the UI through `ValueKey`s and Semantics labels; harnesses at `test/features/entry_cards/support/video_card_harness.dart` and `fake_video_player.dart` | The enforcement layer for the entire preserve list |
| Integration | `integration_test/capture_save_persist_test.dart`, `capture_ui_flow_test.dart`, `media_playback_format_test.dart`, `sandbox_containment_test.dart` | Functional flows, no visual diffing |
| Golden coverage | **None.** `grep -rl "golden\|matchesGoldenFile" test/ integration_test/` returns no matches | — |

### 5.2 The testing rule that governs this spec

This project's testing discipline **exempts styling and visual tweaks from new tests by default**. Most of this spec is styling. Being deliberate about the split matters more here than usual, because a spec this wide could otherwise generate dozens of low-value change-detector tests that break on the next legitimate restyle.

**Changes that get NO new test** — the exemption applies:

- Every colour, radius, padding, shadow-offset, font-size, font-weight and gap change in clusters A, B, C, D and F1–F3.
- The bloom geometry rewrites in E2 and E3 (geometry is verified by H1's goldens, not by per-petal assertions, which would be pure change-detectors).
- All copy changes that do not change a code path — section headers, hint text, empty-state wording.
- The composer chrome in G1, G2, G4, G7 where behaviour is unchanged.

**Changes that DO warrant a test** — behaviour or contract, not appearance:

| MSP | Test | Why it clears the admission gate |
|---|---|---|
| A1 | Extend `test/design/tokens/tokens_test.dart` | Contract: new public constants. Extension of an existing file, not a new one |
| A2 | Existing `pubspec_fonts_test.dart` must keep passing unmodified | Guards the vendored-fonts contract through the typography rewrite |
| A3 | New `test/design/feedback/dialog_host_test.dart` | Contract: asserts no dialog inherits `_errorTextStyle`'s underline. This is a shipped-bug fix, so a red-before/green-after test is mandatory |
| A4 | Extend `test/design/widgets/sticker_card_test.dart` | Contract: the variant-to-shadow mapping is the primary/secondary distinction and must not silently regress |
| B4 | New `test/app/shell/sidebar_footer_test.dart` | Behaviour: settings fill responds to `selected`; sound glyph responds to enabled state. Neither exists today |
| C2 | Extend `test/features/today/today_date_test.dart` | Behaviour: the fourth greeting branch at hour 21 |
| D2 | New `test/features/today/this_week_garden_test.dart` | Behaviour: tapping a day cell navigates to Calendar. New interaction |
| E1 | Extend `test/design/flowers/flower_spec_test.dart` | Contract: every spec carries a per-flower stroke colour and width |
| F4 | New `test/features/mood/mood_repick_test.dart` | Behaviour: the confirm gate blocks the write on cancel, permits on confirm, and is skipped when no mood exists |
| G3 | Extend the text-composer tests | Behaviour: edit-vs-new titles and the empty-save guard |
| G6 | New `test/features/capture/voice/voice_pause_test.dart` | Behaviour: the new pause/resume state machine and the discard gate |
| G8 | New `test/features/capture/video/video_pause_test.dart` | Behaviour: the new video pause/resume state machine |
| H1 | The golden harness | The only pixel-regression net for the restyle |

Every new test must assert observable behaviour through a public surface, must be placed at the lowest layer that can express it (unit before widget before integration), and must have been seen to fail before the implementation lands. Where a similar test already exists, **update it rather than adding a duplicate**.

### 5.3 The standing regression gate

Before any MSP in this spec merges:

1. `flutter analyze` clean.
2. The **106 playback tests run unmodified and pass.** This is N24 and it is the single most important check in the spec — it is the only mechanism that catches the preserve list being quietly dropped. A failing test here is fixed in the implementation, never by editing or deleting the test.
3. The four `integration_test/` flows pass.
4. From H1 onward, the golden job passes on the pinned CI configuration.
5. Diff-scoped verification via the project's `/verify-<project>` command; the full suite runs at cluster boundaries and pre-push, not per change.

### 5.4 Manual spot-check

Retained only for the composite screens where whole-page composition matters more than any single token — Today (desktop with rail, and phone), Garden, Day Detail, and each of the four capture dialogs. It is a spot-check at cluster boundaries, not a substitute for either automated layer, and it does not scale to parallel MSP execution.

---

## 6. Out of scope

### 6.1 Deliberately excluded prototype elements

These appear in the prototype. The team may not want them. Calling them out rather than including them silently:

| Element | Prototype | Why it is excluded |
|---|---|---|
| **The markdown editor engine** | Live block styles (h1 `600 34/44`, h2 `600 26/38`, h3 `600 21/34` at ink 82%, quote with a 3px `#c76a54` left rule, ordered-list markers in coral, todo check, inline code on ink@8%, highlight on accent@28%), a floating selection toolbar on `#2a241d` at radius 11 with 30x30 buttons, and the footer legend `# title  - list  1. steps  > quote  [] to-do` — `:472`, `:1360-1368` | This is a whole editor subsystem, not a restyle. It is a multi-week feature with its own data-model implications (how is markup persisted? does it round-trip through export?). It does not belong in an alignment spec and would blow every MSP size budget. **Route it to its own spec.** G2 delivers the paper surface only. **OQ-5 resolved to (b):** G2 ships the truthful placeholder `Start writing…` in the prototype's italic-serif treatment, so nothing advertises shortcuts that do not work. Extending it to the prototype's full string is a one-line change when the engine lands |
| **Free-manipulation photo cards** | `Add memory` drops a 210x168 tape-framed photo card at a random −4..+4deg rotation onto a draggable, rotatable, resizable layer over the text — `:470`, md-scrapbook | A drag-rotate-resize canvas is a large interaction subsystem. The app already has a simpler, complete photo model in `PhotoTray` (a `Wrap` of 72x72 thumbnails with a remove chip, `maxPhotos 8`) which is a preserve item — but is **currently dead UI**, mounted by nothing in `lib/` (`grep -rn PhotoTray lib test` hits only its own file and its test). See OQ-6 |
| **The video entry card's 130px height** — the hatch, badge and chip are now **in scope** as MSP C7 | `height:130px` — `:128` (the styled elements are `:128-130`; the draft's `:127-129` was off by one) | **Adopting the height breaks N10.** 130px cannot hold a 56px transport, a 48px scrubber row and a 48px mute target; the prototype never modelled playback, so it never had to. **OQ-7 resolved to (a):** C7 adopts the hatch, badge and chip on the app's unchanged 21:9 / 200px envelope. Only the *height* remains excluded |
| **Sync copy `Synced to home` / `your server · just now`** | `:77` | Describes remote sync the app does not have. Shipping it would state something false to the user. **OQ-1 resolved to (a):** B4 adopts the two-line 10px/8px *treatment* with truthful strings (`Stored locally` / `on this device only`). The prototype's strings stay excluded until remote sync ships |
| **The prototype's settings screen layout** | `:263-~380`, which labels itself "A rough layout — placeholder fields the real build can reuse" (`:266`) | The prototype's settings screen is explicitly a non-functional mock with no outcomes, no confirmations and no error states. The app's settings screen is a working superset (N15–N19). Aligning field chrome to the prototype's row pattern is worthwhile but is **its own cluster in a follow-up spec**, and must be planned around N12's shared-primitive hazard: `SettingsFieldRow` and `SettingsSelect` are consumed by the camera picker, so a settings-only restyle will visually corrupt the video recorder if done carelessly |
| **Calendar, Garden, Search and Day Detail screens** | `:183-208`, `:210-244`, `:245-261`, `:406-407` | Out of scope for this spec beyond the token and flower changes that reach them transitively (A1, A2, E1–E4). Their own alignment is a follow-up. Note that several elements a reader might assume are additive are in fact **present in the prototype and therefore not preserve items**: the connection-status pill and `Test connection` button (`:316-317`), the entry edit/delete buttons including the note-only edit gate (`:406-407`, `:869-870`, `canEdit:m.isNote` at `:1436`), calendar month chevrons (`:190-191`), and garden mood-tally chips (`:217-230`) |

### 6.2 Explicitly not a task

- **No grain or noise overlay.** Neither side has one. The prototype's only `noise` match in 1742 lines is `this.noiseBuf(ac, 0.06, …)` at `:1294`, an audio buffer. Recorded so no MSP goes hunting for a texture layer to add or remove.
- **No `flutter_svg` / `vector_graphics` dependency.** All bloom, icon and sprig art stays procedural Dart in `CustomPainter`, per the implementation research. The prototype's own art is primitive shapes composed with rotation, not exported vector-tool paths, so there is no fidelity gain — and the CustomPainter keeps per-mood tinting as a free runtime parameter, which asset-based routes would lose.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants. `ThemeExtension`'s `copyWith`/`lerp` machinery buys animated interpolation across a theme change, and the app has exactly one theme (`app_theme_test.dart:14` asserts `Brightness.light` with no dark branch). Plain constants are also `context`-free and mechanically greppable, which matters when parallel agents are editing them. Revisit only if a second theme ships.
- **No `FontVariation('wght', …)` calls.** Bind by `fontFamily` string plus explicit `FontWeight`, as `typography.dart` already does.
- **No pixel-snapping workaround for fractional-DPR antialiasing.** Documented as a Flutter platform limitation in H1; not fixed in-app.
- **No deletion or weakening of the 106 playback tests** under any circumstances (N24).
- **The two legacy ambient-only flower kinds** `wiltingRose` and `thistle` (`flower_kind.dart:12-13`, `flower_spec.dart:150-172`) are absent from the `Mood` enum and `moodOrder`, have no render site anywhere in the repo, and are not selectable. Leave them alone.

### 6.3 Open questions requiring a user decision

**Five of the seven were resolved by the product owner on 2026-07-27.** The resolutions are binding and are written into the MSPs below; the bodies that follow are retained as the rationale record.

| OQ | Blocks | Resolution | Effect on the MSP set |
|---|---|---|---|
| OQ-1 | B4 | **(a)** keep the app's honest copy in the prototype's two-line treatment | B4 unblocked |
| OQ-2 | C1 | **(b)** keep the `longest` number, accept the copy deviation | C1 unblocked |
| OQ-4 | D3 | **(a)** remove the desktop `Capture` button | D3 promoted from interim to final; **three test files change with it** |
| OQ-5 | G2 | **(b)** truthful placeholder in the prototype's treatment | G2 unblocked |
| OQ-7 | video entry card | **(a)** keep the app's envelope, adopt hatch + badge + chip | **new MSP C7** |

Still open, and touching no MSP: **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model).

**OQ-1 — Sync footer copy. RESOLVED 2026-07-27 → (a).**
The prototype's rail footer reads `Synced to home` / `your server · just now` (`:77`). The app truthfully reads `On this device only`. Adopting the prototype copy verbatim ships a false claim about a capability that does not exist. Options: (a) keep the app's honest copy in the prototype's two-line 10px/8px treatment, splitting it across two lines; (b) adopt the prototype copy only once remote sync ships and use the app copy until then; (c) adopt verbatim now. **Recommendation: (a).** B4 can proceed on (a) or (b) with only the string differing; it cannot proceed without a decision because the two-line layout needs two strings.

**OQ-2 — Streak `longest` value. RESOLVED 2026-07-27 → (b).**
The prototype's sub-line is the literal `longest streak yet` (`:71`); the app renders `longest streak yet: {summary.longest}`. Dropping the number to match the design loses real information the app has and the prototype never modelled. Options: (a) drop it, matching the design exactly; (b) keep the number, accepting a copy deviation; (c) keep the number but move it elsewhere in the card. **Recommendation: (b)** — this is information loss, not visual noise, and the deviation is one appended value in a 10px caption.

**OQ-3 — Entry-card Edit/Delete placement. Blocks: C4 (final form only; C4 can ship with the interim placement).**
The prototype's entry card header holds only a timestamp and a type chip (`:113-115`) and has no per-card action controls. The app's Edit/Delete buttons are a preserve item. The prototype does have edit/delete affordances, but in **Day Detail** (`:406-407`), not on the Today card. Options: (a) interim placement in the header as small icon buttons, as C4 specifies; (b) reveal on hover/focus, keeping the resting card clean; (c) move them out of Today entirely and rely on Day Detail, matching where the prototype puts them. **(c) is the most design-faithful but is a behaviour removal from Today** and needs an explicit decision. Note the buttons are currently invisible on Today anyway because `TodayEntryTile` passes neither callback (`today_entry_feed.dart:100-107`), so the live regression risk is confined to Day Detail.

**OQ-4 — The extra `Capture` chooser button on desktop. RESOLVED 2026-07-27 → (a).**
The prototype's desktop rail has exactly three capture rows and no chooser modal (`:165-168`, `:1597-1601`); the chooser exists only in the phone frame (`:746-756`). The app adds a fourth primary `Capture` button that opens the chooser on desktop, and it currently absorbs the coral emphasis that the design gives to `Write a note`. Options: (a) remove the desktop `Capture` button, leaving the three direct rows with `Write a note` primary — fully design-faithful, and the chooser stays as the phone entry point; (b) keep it but demote it to secondary so `Write a note` gets the emphasis; (c) keep it as-is above the three restyled rows. D3 as written implements (c) as the interim so it can ship green. **Recommendation: (a)** — it is preserved as a *phone* capability either way, and the desktop button is what makes the rail read as four buttons where the design has three.

**RESOLVED 2026-07-27 → (a).** D3 now removes the button in its final form. Reachability was verified before accepting: `app_shell.dart:41` → `_openCapture` (`:30-32`) → `openCapture(...)`, bound to the phone centre tab at `bottom_bar_shell.dart:116`. The chooser therefore survives the removal, and `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof. **This is the one app-only element the product owner elected to drop** — it is a removal by decision, recorded here so it is never mistaken for an accidental regression.

**OQ-5 — Markdown placeholder copy. RESOLVED 2026-07-27 → (b).**
G2 adopts the prototype's placeholder `Start writing…  try “# ” for a title, “- ” for a list, “1. ” for steps` (`:468`), but the markdown engine that would honour those shortcuts is out of scope (6.1). Shipping the placeholder without the engine advertises behaviour that does not exist. Options: (a) ship the prototype placeholder anyway, accepting the mismatch until the editor spec lands; (b) ship a truthful placeholder in the same italic serif treatment until the engine exists. **Recommendation: (b).**

**OQ-6 — Photo attachment model. Blocks: any `Add memory` work; deferred out of the current MSP set entirely.**
The prototype attaches photos as free-manipulation tape-framed cards on the writing surface, capped at 3 (`:470`, md-scrapbook). The app has `PhotoTray`, a simpler `Wrap` of thumbnails capped at 8 — a preserve item, but **currently mounted by nothing in `lib/`**, so it is invisible to users today. Three distinct decisions are entangled: (i) which model ships; (ii) whether `PhotoTray` gets wired into the note composer or stays dead; (iii) which cap applies, 3 or 8. No MSP in this spec touches photo attachment because the answer determines whether the work is a restyle or a new subsystem.

**OQ-7 — Video entry card geometry. RESOLVED 2026-07-27 → (a). Now implemented as MSP C7.**
This is the one place where a faithful prototype value would actively break a preserved capability. The prototype's card is `height:130px` with one 44x44 play badge and a corner duration chip (`:127-129`). The app's is 21:9 with a 200px floor because it must fit a centred transport, a 48px scrubber row, a 48px mute target and the auto-hiding overlay (N10). Options: (a) keep the app's envelope and adopt only the prototype's hatch, badge styling and corner chip — the badge and chip restyle N3 and N4 without shrinking the box; (b) adopt 130px for the **resting/poster** state and expand to the playback envelope on first play, which is more design-faithful but introduces a layout jump mid-interaction and needs the scrubber/mute fit re-verified at the expanded size; (c) adopt 130px outright — **rejected**, it clips the control bar. **Recommendation: (a).**

**RESOLVED 2026-07-27 → (a).** Implemented as **MSP C7**, which adopts the hatch, badge and chip on the app's unchanged 21:9 / 200px envelope. Note the citation correction carried into C7: the values are at `:128-130`, not `:127-129`.

---

## 7. Traceability note

**Status of this claim, corrected.** The first draft asserted that every prototype value had been read at its cited line and confirmed. That was true for the window-chrome, rail, Today and JS-style-block regions, and the review pass re-confirmed those spot by spot — `:1564` active nav, `:1595-1596` capture-button base, `:1582` entry card, `:1553-1554` picker tiles, `:1606-1611` week cells, `:93-96` and `:100-103` mood banner, `:145-147` empty state, `:152-176` rail, `:439-444` picker panel, `:460-466` composer panel and header, `:747-756` chooser, `:1044-1059` flowers, `:1218-1221` nav icons, `:1318` greeting, `:1345` re-pick, `:1403` week model, `:1644`/`:1682` footer buttons, `:1666` feed label, `:1692` confirm button, `:1694-1704` composer copy.

It was **not** true for two regions, both corrected in this revision:

| Region | Symptom | Correction |
|---|---|---|
| Note-composer body, `:467-473` | Systematic **off-by-one** — the writing surface, the Add-memory button and the markdown legend were each cited one line above their actual position | surface `:468` -> `:469`; Add memory `:470` -> `:471`; legend `:472` -> `:473` |
| Voice and video composer, `:479-519` | Systematic **off-by-one or worse** across sixteen citations | header `:479`->`:480`; stage/button `:482`,`:484`->`:483`,`:485`; halo `:483`->`:484`; timer `:486`->`:487`; hint `:487`->`:488`; waveform `:488-490`->`:489-490`; pills `:494-495`->`:495-496`; viewport `:501`->`:502`; label `:503`->`:504`; close X `:504`->`:505`; timer pill `:505-509`->`:506-510`; instruction `:511`->`:512`; shutter `:512-516`->`:513-517`; discard/save `:513`,`:518`->`:514`,`:519`; tick interval `:1395`->`:1396` |

Three further citations were not off-by-one but simply wrong and have been repointed: `ink08`/`ink12` cited `:1560` (a `navDef.map` line containing no colour) and now cite `:316`/`:678` and `:223`/`:609`/`:1533`; `Shadows.chip` cited `:1608` (which is the coral today-cell shadow) and now cites `:219`/`:190-191`; the phone mood-picker sheet cited `:439` (the desktop panel) and now cites `:731-733`. `A4`'s danger variant cited `:1595-1596`, which contains no danger treatment at all, and now cites `:1692`.

Where the source audit's line number was off by one, the corrected line is used — `:1564` (not 1563) for the active nav style, `:1596` (not 1587) for the secondary button, `:1554` (not 1553) for the unselected picker tile, `:1582` (not 1583) for the entry card, `:61` (not 60) for the logo flower span. Where a claim cannot be pinned to a `.dc.html` line because it lives in the vendored md-scrapbook editor rather than inline markup — the note-composer placeholder copy in G2 — the mount point at `:469` is cited and the copy string itself is marked `[unverified]`.

**Rule for implementers:** re-open the cited line before adopting any value. This document has now been wrong about line numbers once; treat a citation as a pointer to verify, not as an authority.

---

## 8. Review change log (2026-07-26 adversarial pass)

Blockers found and fixed in place:

| # | Blocker | Fix |
|---|---|---|
| 1 | **A2 does not compile.** `eyebrowAccent` is removed but two of its seven call sites (`settings_section.dart:35`, `calendar_header.dart:30`) and one test assertion (`tokens_test.dart:30`) were not in A2's file list | Full seven-site retarget table added; test file added to A2's scope |
| 2 | **E1 ships a broken Garden screen.** Removing `_straightStem()` affects the meadow, which uses the same painter until E4 | E1 now introduces a `headless` flag; the meadow keeps stems until E4, which owns the cleanup |
| 3 | **C4 depends on a surface B4 creates** (`IconStickerButton`) but did not declare it | B4 added to C4's dependencies, with a no-B4 fallback stated |
| 4 | **G1 folds the capture chooser into the 760px composer panel.** The prototype's chooser is a separate phone-only sheet; G1 also contradicted G4 | Chooser removed from G1's scope and file list |
| 5 | **G1 claims the header bar is shared by text and voice.** It is inside `sc-if isTextComposer` at `:462`; the voice branch at `:477-478` has no header | Header bar scoped to the note composer; voice layout left to G5 |
| 6 | **F3 and G4 both consume one `Shadows.sheetLift`** with two different prototype values (`:732` vs `:748`) | Split into `pickerSheetLift` and `chooserSheetLift` |
| 7 | **A4's danger variant is unsourced** — the cited `:1595-1596` has no danger treatment, and the stated values match neither prototype danger object | Repointed to `:1692`; the `:495` pill explicitly excluded from the shared variant |
| 8 | **~20 citations off by one or wrong** across `:467-473`, `:479-519`, plus `ink08`/`ink12`, `Shadows.chip`, the F3 phone sheet, `:1395` | All corrected; §7 rewritten to state the failure rather than claim full verification |
| 9 | **D1 instructs "remove the StickerCard wrapper from all three sections"** while section 3 legitimately keeps a card, risking an unwrapped memory on merge | Instruction restated per-section with the wrapper/card split made explicit |

Non-blocking corrections also applied: D3's row gap 9 -> 8 (`:165`); H1's missing B3 and E2 dependencies; B2's instruction to add `DashedDivider` parameters that already exist (widget removed from B2's files, and D1's spurious dependency on B2 dropped); E4's file list overlapping C2's `mood_banner.dart`; E4 missing N25; E3's Lavender geometry missing eight of nine oval sizes; G5's `GlowPulse` retune described against the wrong animation model (`fn-pulse` at `:21` is scale+opacity, not blur+spread); §3.0's shadow inventory counts replaced with a verifiable table; a new §2.7 binding every preserve item to the MSP that endangers it.

Deliberately **not** changed: the open questions OQ-1 through OQ-7 remain open — they are genuine product decisions, not spec defects, and each correctly names the MSP it blocks.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
