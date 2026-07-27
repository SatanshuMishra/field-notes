# Prototype Design Alignment — Cluster A (Foundations) Run Spec

Date: 2026-07-27
Project: field notes (Flutter desktop + mobile)
Parent spec: `docs/specs/2026-07-26-prototype-design-alignment.md` (approved, on main at `9fb3e7f`)
Prototype source of truth: `docs/prototype/project/Field Notes.dc.html` (1742 lines)
Status: approved for execution — Cluster A only

---

## 0. What this document is, and why it exists

This is an **execution slice** of the approved parent spec, not a new spec. It carries MSPs **A1 through A5** verbatim, together with every constraint, finding and verification rule that binds them. It exists because the parent spec decomposes into 39 MSPs across eight clusters, and the run contract (`.claude/ledger/decisions/2026-07-27-prototype-alignment-run-contract.md`) rules that Cluster A ships and is reviewed **before** clusters B–H are dispatched. A single 39-MSP run was rejected: it offers no inspection point before 39 PRs land. Every other cluster depends on A, so A-first costs nothing in ordering.

**Nothing here contradicts the parent spec.** Where this document reproduces parent text, it reproduces it verbatim. Where a reader needs material this slice omits — findings §3.2–§3.7, MSPs B1–H1, the excluded-elements table §6.1 — the parent spec on main is the authority.

### HARD SCOPE FENCE

This run ships **exactly five MSPs: A1, A2, A3, A4, A5.** No others.

- Do **not** create MSPs for clusters B, C, D, E, F, G or H. They are named in §4 only so cross-cluster dependencies stay legible.
- Do **not** create an MSP that edits any file under `lib/features/entry_cards/cards/`, `lib/features/entry_cards/playback/`, `lib/features/capture/**` (beyond the five dialog entry points A3 names), `lib/features/garden/**`, `lib/features/mood/**` (beyond the A3 entry point), `lib/features/today/**` (beyond A2's mechanical retargets), or `lib/app/shell/**`. Those surfaces belong to later clusters.
- If decomposition suggests a unit outside A1–A5, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

Cluster A touches the token layer and two shared primitives. Its blast radius is app-wide by design (see A2 and A4). That blast radius is **not** a reason to pull later clusters forward.

---

## 1. BLUF

The app implements the prototype's *vocabulary* correctly — the ink, coral, sage and warm-paper hexes are exact, the three font families are right, the sticker composition (fill + 1.5px ink border + zero-blur offset shadow) is the correct abstraction, and the mood/flower domain model matches the prototype's `FLOWERS` map one-for-one. What it does not implement is the prototype's *grammar*: the design's distinctions have been collapsed into single tokens. One shadow token stands in for a four-step offset scale, one Caveat token stands in for two different Caveat roles, one flower painter serves both the 44-unit compact glyph and the 190-240-unit garden plant, one button shadow is applied to primary and secondary alike, and one radius ladder is missing the 8px, 12px and 13px steps the prototype uses most. On top of that, three structural regressions are visible today: the app interior paints the *outside-the-window* page colour `#D9CBB2` instead of the `#efe2ce → #e9dcc4` panel wash, every right-rail section is wrapped in a heavy drop-shadowed card the prototype draws as a bare div, and every dialog built through `showGeneralDialog` renders its text with Flutter's yellow double-underline "you forgot a Material ancestor" debug style.

**Cluster A's share of that**: build the token ladder the rest of the alignment consumes (A1), split the collapsed typography roles (A2), fix the shipped dialog debug-underline defect (A3), encode the primary/secondary button distinction and the card tilt (A4), and replace the cross-hatch geometry (A5). After Cluster A the design system can *express* the prototype's grammar; later clusters spend it.

**Aligned means**: every value in the findings tables below matches its cited prototype line; every capability in §2 still works and still passes its existing tests unchanged; and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set is reproduced below verbatim from the parent spec. Not every row is endangered by Cluster A — §2.7 names which are. The complete set is carried anyway, for one reason: an implementer who encounters an app-only capability while restyling a shared token must be able to tell "preserved by decision" from "leftover to clean up". Every row below is preserved by decision. **N24 binds every MSP in this run without exception.**

**No MSP in this run touches the video playback stack (N1–N10) or the voice row (N11).** If a plan proposes to, the plan is out of scope — stop and report rather than planning around it.

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
| Chooser and its `'Coming soon'` state — **phone entry point only**; the desktop button at `today_capture_buttons.dart:79` is removed by decision (OQ-4a) in MSP D3, **not in this run**; the chooser itself is preserved | `lib/features/capture/chooser/capture_chooser_sheet.dart:14`, `:81`; reached via `lib/app/shell/app_shell.dart:30-32`, `lib/app/shell/bottom_bar_shell.dart:116` |
| No grain/noise layer on either side — recorded so no MSP goes looking for one to add or remove | `grep -rni "grain\|noise\|turbulence" lib/` returns zero hits; the prototype's only `noise` hit is an audio buffer at `Field Notes.dc.html:1294` |

### 2.7 Preserve-to-MSP binding — the rows that bind THIS run

A preserve rule stated only in §2 does not bind anything. The parent spec's §2.7 names, for every preserve item, the MSP that could regress it. Filtered to Cluster A, these are the live bindings:

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| Entry-card Edit/Delete actions | **A4** (button restyle); C4 later | A4 blast-radius list |
| Camera picker (`SettingsFieldRow`/`SettingsSelect` consumer, N12) | **A4**; G1/G7 later | A4 blast-radius list |
| `PhotoTray` / `PhotoThumbnail` (dead UI, live test) | **A4** (button restyle), **A5** (`CrossHatchPlaceholder` rewrite) | A4 blast-radius list; A5 "Must not regress" |
| N15–N19 settings capabilities | **A2 and A4 only** (token/button value changes reach Settings; no MSP restyles the screen) | A2 blast-radius note; A4 blast-radius list; parent §6.1 defers the screen |
| N24 keys, labels, 106 tests | **every MSP** | §5.3 gate 2, applied before every merge |

Rows bound only to later clusters — `Palette.sunGlow` (E4), on-this-day states (D1/D4), video permission copy (G7), N1–N10 (C7), N11 (G8), N21 (E1–E4), N22 (C6), N23 (C4/G3), N25 (C3/D2/E1–E4/F1–F3) — are **not** endangered by this run. They are listed in §2 above so no implementer mistakes a preserved capability for dead weight.

---

## 3. Findings that Cluster A implements

Every prototype value below was opened and confirmed. Where the original audit's line number was off by one, the corrected line is used. **Read §7 before adopting any value.**

Findings §3.2 (window chrome and nav rail), §3.3–§3.4 (Today), §3.5 (flower art), §3.6 (mood picker) and §3.7 (capture composers) belong to later clusters and are omitted here; they are in the parent spec.

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

---

## 4. MSP decomposition — Cluster A

**The governing invariant**: merging any MSP must leave the branch's app fully working. No MSP may depend on a surface a later MSP creates. Ordering is bottom-up — shared tokens and primitives before the screens that consume them.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster A is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **YES** |
| B | Window chrome and nav rail | B1 – B4 | no |
| C | Today centre column | C1 – C7 | no |
| D | Today right rail | D1 – D4 | no |
| E | Flower art | E1 – E4 | no |
| F | Mood picker | F1 – F4 | no |
| G | Capture composers | G1 – G8 | no |
| H | Verification infrastructure | H1 | no |

Within Cluster A, dependencies are: A1 depends on nothing; A2, A4 and A5 each depend on A1; A3 depends on nothing and may land in parallel with A1/A2.

---

### A1 — Token ladder expansion

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

### A2 — Typography role system

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

**Must not regress**: nothing behavioural. `lib/design/tokens/typography.dart` keeps `serif`, `sans` and `accent` as the family strings, bound by name plus explicit `FontWeight` — **do not** introduce `FontVariation('wght', …)` calls. Flutter drives the variable-font `wght` axis from `TextStyle.fontWeight` automatically ([Flutter breaking change: font-weight-variation](https://docs.flutter.dev/release/breaking-changes/font-weight-variation)); hand-rolling the axis would double-apply. Italic must stay routed through the `style: italic` pubspec asset declaration, not through a variation — `Newsreader-Italic-Variable.ttf` is a separate file and the roman file has no italic axis. N15–N19 settings capabilities must still function after the token value changes reach the Settings screen.

**Acceptance criteria**: `flutter analyze` is clean — no dangling `eyebrowAccent` reference in `lib/` or `test/`. Page eyebrows above screen titles render **terracotta at 16px**, and lowercase rail/feed section headers render **sage at 17px** — two visibly different treatments where there was previously one. Journal prose in entry cards is noticeably denser (13.5px, not 16px). Page titles are lighter (w500) and set solid (height 1.0). No text overflows on Calendar, Garden, Search, Day Detail or Settings at the app's minimum supported window size. The existing `test/design/tokens/pubspec_fonts_test.dart` still passes unmodified, confirming the three families stay vendored and `google_fonts` is still absent.

---

### A3 — Dialog Material ancestor fix

**Outcome**: no dialog in the app renders text with Flutter's yellow double-underline debug style.

**Files**: `lib/features/mood/mood_picker.dart`, `lib/features/capture/text/text_composer.dart`, `lib/features/capture/voice/voice_composer.dart`, `lib/features/capture/video/video_composer.dart`, `lib/features/capture/chooser/capture_chooser.dart`; new shared host under `lib/design/feedback/`; new `test/design/feedback/dialog_host_test.dart`

**Depends on**: nothing. Can land in parallel with A1/A2.

**Root cause, verified end to end**: `lib/app/app.dart:20` builds a plain `MaterialApp` with no `builder`, so nothing re-wraps the overlay subtree. Flutter's `material/app.dart:45-54` defines `_errorTextStyle` as `TextStyle(color: Color(0xD0FF0000), fontFamily: 'monospace', fontSize: 48.0, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: Color(0xFFFFFF00), decorationStyle: TextDecorationStyle.double, debugLabel: 'fallback style; consider putting your text in a Material')` and passes it as `WidgetsApp.textStyle` at `:1091`. Each of the five entry points returns its sheet directly from `showGeneralDialog`'s `pageBuilder` into the root overlay; `StickerCard` is a `DecoratedBox` and introduces no `Material`. Because every `TypographyTokens` style leaves `decoration` null with `inherit` defaulting true, `merge()` preserves the underline while overriding font, size and colour.

**Target implementation**: introduce one shared `DialogHost` widget that wraps the sheet in `Material(type: MaterialType.transparency)` and route all five `pageBuilder`s through it. The precedent already exists and is known-good: `lib/features/capture/video/camera_picker.dart:35` wraps its control in exactly this and its text already escapes the bug.

**Must not regress**: barrier colours, `barrierDismissible` values, semantic barrier labels, and the fade + scale transitions stay exactly as they are (A3 changes only the ancestry). `barrierDismissible: false` on the video composer (`video_composer.dart:345`) is preserved. N24 — no `ValueKey` or Semantics label changes. N14 — opening the voice or video composer must still never start recording.

**Acceptance criteria**: open the mood picker — the title `How are you feeling?` and all ten mood labels render as plain warm-brown text with **no yellow underline**. Open each of the note, voice and video composers and the capture chooser — same. This is a **behaviour/contract change and warrants a test**: a widget test that pumps each dialog and asserts the resolved `DefaultTextStyle` has `decoration == TextDecoration.none` (or null), i.e. no inherited `_errorTextStyle`. The test must be seen to FAIL before the fix lands — this is a shipped-bug fix, so red-before/green-after is mandatory.

---

### A4 — Sticker primitive alignment

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
- **Preserve item** — `entry_cards/entry_card.dart:65-77`: the entry-card Edit/Delete actions must still render and still function where wired.
- `day_detail_header.dart:46`, `settings_screen.dart:72`, `data_section.dart:41`, `mood_banner.dart:42` (superseded by C2, **not in this run**), `today_capture_buttons.dart:85` (superseded by D3, **not in this run**).

Secondary buttons losing their shadow app-wide is the *intended* outcome, not a regression — but it is the single widest visual change in Cluster A and it lands on screens no later MSP revisits.

**Acceptance criteria**: secondary buttons — Cancel in the composers, the rail's capture rows, the chooser rows — visibly **lose their drop shadow** while primary buttons keep theirs, so the two tiers stop looking equally prominent. Secondary buttons take on the warmer `#f8efe0` fill instead of the near-white `#FFFAF1`. Primary button text is pure white rather than cream. All buttons are a hair rounder (12 vs 11) and 3px tighter on each side. `test/design/widgets/sticker_card_test.dart` is extended to assert the variant-to-shadow mapping.

---

### A5 — Cross-hatch geometry

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

**Must not regress**: the widget's public constructor surface (`height`, `borderRadius`) is preserved so `video_recorder_sheet.dart:226`, `:245` and `photo_thumbnail.dart`'s error fallback keep compiling. Default variant is `photo`, so untouched call sites keep working. `PhotoTray` / `PhotoThumbnail` remain intact and `test/features/capture/photo/photo_tray_test.dart` continues to pass.

**Acceptance criteria**: photo placeholders show clean parallel diagonal stripes rather than a woven X-hatch of thin darker lines, and video placeholders are visibly a shade darker than photo ones.

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

### 5.2 The testing rule that governs this run

This project's testing discipline **exempts styling and visual tweaks from new tests by default**. Most of this spec is styling. Being deliberate about the split matters more here than usual, because a spec this wide could otherwise generate dozens of low-value change-detector tests that break on the next legitimate restyle.

**Changes that get NO new test** — the exemption applies:

- Every colour, radius, padding, shadow-offset, font-size, font-weight and gap change in Cluster A.

**Changes that DO warrant a test** — behaviour or contract, not appearance:

| MSP | Test | Why it clears the admission gate |
|---|---|---|
| A1 | Extend `test/design/tokens/tokens_test.dart` | Contract: new public constants. Extension of an existing file, not a new one |
| A2 | Existing `pubspec_fonts_test.dart` must keep passing unmodified | Guards the vendored-fonts contract through the typography rewrite |
| A3 | New `test/design/feedback/dialog_host_test.dart` | Contract: asserts no dialog inherits `_errorTextStyle`'s underline. This is a shipped-bug fix, so a red-before/green-after test is mandatory |
| A4 | Extend `test/design/widgets/sticker_card_test.dart` | Contract: the variant-to-shadow mapping is the primary/secondary distinction and must not silently regress |
| A5 | none | Pure visual geometry change; the exemption applies |

Every new test must assert observable behaviour through a public surface, must be placed at the lowest layer that can express it (unit before widget before integration), and must have been seen to fail before the implementation lands. Where a similar test already exists, **update it rather than adding a duplicate**.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **106 playback tests run unmodified and pass.** This is N24 and it is the single most important check in the spec — it is the only mechanism that catches the preserve list being quietly dropped. A failing test here is fixed in the implementation, never by editing or deleting the test.
3. The four `integration_test/` flows pass.
4. Diff-scoped verification via the project's verify command; the full suite runs at the cluster boundary and pre-push, not per change.

There is no golden coverage in this run — H1 builds it and is not dispatched here. Gate 2 is therefore the only automated pixel-adjacent safety net, which is why it is non-negotiable.

### 5.4 Manual spot-check

Retained only for the composite screens where whole-page composition matters more than any single token — Today (desktop with rail, and phone), Garden, Day Detail, and each of the four capture dialogs. It is a spot-check at the cluster boundary, not a substitute for either automated layer, and it does not scale to parallel MSP execution.

Cluster A specifically requires a human pass over **Calendar, Garden, Search, Day Detail and Settings** after A2 (text overflow at the minimum supported window size) and after A4 (secondary buttons losing their shadow on screens no later MSP revisits).

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

The parent spec's §6.1 table lists the prototype elements deliberately excluded from alignment: the markdown editor engine, free-manipulation photo cards, the video card's 130px height, the prototype's sync copy, the prototype's settings-screen layout, and the Calendar / Garden / Search / Day Detail screens. All remain excluded. None is reachable from Cluster A.

Note in particular: **the settings screen layout is not aligned by this run.** A2 and A4 change its *tokens and buttons*, which is why N15–N19 bind them, but no MSP here restyles the screen. A settings restyle must be planned around N12's shared-primitive hazard — `SettingsFieldRow` and `SettingsSelect` are consumed by the camera picker — and is a follow-up spec.

### 6.2 Explicitly not a task

- **No grain or noise overlay.** Neither side has one. The prototype's only `noise` match in 1742 lines is `this.noiseBuf(ac, 0.06, …)` at `:1294`, an audio buffer. Recorded so no MSP goes hunting for a texture layer to add or remove.
- **No `flutter_svg` / `vector_graphics` dependency.** All bloom, icon and sprig art stays procedural Dart in `CustomPainter`, per the implementation research. The prototype's own art is primitive shapes composed with rotation, not exported vector-tool paths, so there is no fidelity gain — and the CustomPainter keeps per-mood tinting as a free runtime parameter, which asset-based routes would lose.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants. `ThemeExtension`'s `copyWith`/`lerp` machinery buys animated interpolation across a theme change, and the app has exactly one theme (`app_theme_test.dart:14` asserts `Brightness.light` with no dark branch). Plain constants are also `context`-free and mechanically greppable, which matters when parallel agents are editing them. Revisit only if a second theme ships.
- **No `FontVariation('wght', …)` calls.** Bind by `fontFamily` string plus explicit `FontWeight`, as `typography.dart` already does.
- **No pixel-snapping workaround for fractional-DPR antialiasing.** Documented as a Flutter platform limitation in H1; not fixed in-app.
- **No deletion or weakening of the 106 playback tests** under any circumstances (N24).
- **The two legacy ambient-only flower kinds** `wiltingRose` and `thistle` (`flower_kind.dart:12-13`, `flower_spec.dart:150-172`) are absent from the `Mood` enum and `moodOrder`, have no render site anywhere in the repo, and are not selectable. Leave them alone.
- **No renames or removals in the existing token layer.** A1 is purely additive; `Shadows.card` and `Shadows.button` keep their exact current values through this run.

### 6.3 Open questions

Five of the parent spec's seven open questions were resolved by the product owner on 2026-07-27 (OQ-1 → a, OQ-2 → b, OQ-4 → a, OQ-5 → b, OQ-7 → a). All five bind MSPs in clusters B, C, D and G — **none binds Cluster A.**

Still open: **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model). Neither touches an MSP in this run. Neither may be resolved implicitly by a Cluster A implementer: A4 preserves the entry-card actions and A4/A5 preserve `PhotoTray` exactly as they are today, leaving both decisions open.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Status of this claim, corrected.** The parent spec's first draft asserted that every prototype value had been read at its cited line and confirmed. That was true for the window-chrome, rail, Today and JS-style-block regions, and the review pass re-confirmed those spot by spot — `:1564` active nav, `:1595-1596` capture-button base, `:1582` entry card, `:1553-1554` picker tiles, `:1606-1611` week cells, `:93-96` and `:100-103` mood banner, `:145-147` empty state, `:152-176` rail, `:439-444` picker panel, `:460-466` composer panel and header, `:747-756` chooser, `:1044-1059` flowers, `:1218-1221` nav icons, `:1318` greeting, `:1345` re-pick, `:1403` week model, `:1644`/`:1682` footer buttons, `:1666` feed label, `:1692` confirm button, `:1694-1704` composer copy.

It was **not** true for two regions, both corrected:

| Region | Symptom | Correction |
|---|---|---|
| Note-composer body, `:467-473` | Systematic **off-by-one** — the writing surface, the Add-memory button and the markdown legend were each cited one line above their actual position | surface `:468` -> `:469`; Add memory `:470` -> `:471`; legend `:472` -> `:473` |
| Voice and video composer, `:479-519` | Systematic **off-by-one or worse** across sixteen citations | header `:479`->`:480`; stage/button `:482`,`:484`->`:483`,`:485`; halo `:483`->`:484`; timer `:486`->`:487`; hint `:487`->`:488`; waveform `:488-490`->`:489-490`; pills `:494-495`->`:495-496`; viewport `:501`->`:502`; label `:503`->`:504`; close X `:504`->`:505`; timer pill `:505-509`->`:506-510`; instruction `:511`->`:512`; shutter `:512-516`->`:513-517`; discard/save `:513`,`:518`->`:514`,`:519`; tick interval `:1395`->`:1396` |

Three further citations were not off-by-one but simply wrong and have been repointed: `ink08`/`ink12` cited `:1560` (a `navDef.map` line containing no colour) and now cite `:316`/`:678` and `:223`/`:609`/`:1533`; `Shadows.chip` cited `:1608` (which is the coral today-cell shadow) and now cites `:219`/`:190-191`; the phone mood-picker sheet cited `:439` (the desktop panel) and now cites `:731-733`. `A4`'s danger variant cited `:1595-1596`, which contains no danger treatment at all, and now cites `:1692`.

Where the source audit's line number was off by one, the corrected line is used — `:1564` (not 1563) for the active nav style, `:1596` (not 1587) for the secondary button, `:1554` (not 1553) for the unselected picker tile, `:1582` (not 1583) for the entry card, `:61` (not 60) for the logo flower span.

**Rule for implementers:** re-open the cited line in `docs/prototype/project/Field Notes.dc.html` before adopting any value. This spec has been wrong about line numbers once; treat a citation as a pointer to verify, not as an authority. Two of the corrections above (`ink08`/`ink12` and `Shadows.chip`) land directly in A1's target tables.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
