# Prototype Design Alignment — Cluster B (Window chrome and nav rail) Run Spec

Date: 2026-07-27
Project: field notes (Flutter desktop + mobile)
Parent spec: `docs/specs/2026-07-26-prototype-design-alignment.md` (approved, landed on main at `9fb3e7f`)
Sibling slice, fully executed: `docs/specs/2026-07-27-prototype-alignment-cluster-a.md`
Prototype source of truth: `docs/prototype/project/Field Notes.dc.html` (1742 lines)
Status: approved for execution — Cluster B only

---

## 0. What this document is, and why it exists

This is an **execution slice** of the approved parent spec, not a new spec. It carries MSPs **B1 through B4** verbatim, together with every constraint, finding and verification rule that binds them. It exists because the parent spec decomposes into 39 MSPs across eight clusters, and the run contract (`.claude/ledger/decisions/2026-07-27-prototype-alignment-run-contract.md`) rules that clusters ship and are reviewed one at a time. Mitosis has no scope parameter — it decomposes the whole document it is handed — so a run is scoped by cutting a slice, never by an input flag (`.claude/ledger/decisions/2026-07-27-cluster-a-scoped-spec.md`).

**Nothing here contradicts the parent spec.** Where this document reproduces parent text, it reproduces it verbatim. Where a reader needs material this slice omits — findings §3.1 and §3.3–§3.7, MSPs A1–A5 and C1–H1, the excluded-elements table §6.1 — the parent spec on main is the authority.

**Cluster A is already merged and is this run's base.** A1 (token ladder), A2 (typography roles), A3 (dialog Material host), A4 (sticker primitives) and A5 (cross-hatch geometry) shipped as PRs #51/#53/#54/#55/#56, and `fullValidationCmd` ran green against the combined tree at `81039f3`. Every token B1–B4 consumes therefore **already exists on base** and was confirmed present before this slice was cut:

| Needed by | Symbol | Confirmed at |
|---|---|---|
| B1 | `Palette.panelTop`, `Palette.panelBottom`, `Palette.panelCoralTint`, `Palette.ink16` | `lib/design/tokens/palette.dart` |
| B1 | `TypographyTokens.windowTitleAccent` | `lib/design/tokens/typography.dart` |
| B2 | `Palette.ink22`, `TypographyTokens.wordmarkAccent` | `lib/design/tokens/palette.dart`, `typography.dart` |
| B3 | `Palette.inkSoft`, `Palette.onAccent`, `Shapes.radiusControl`, `Shadows.emphasis`, `TypographyTokens.navLabelSans` | `palette.dart`, `shapes.dart`, `shadows.dart`, `typography.dart` |
| B4 | `Palette.cardLight`, `Palette.cardWarm`, `Shapes.radiusIconButton`, `TypographyTokens.syncPrimarySans`, `syncSecondarySans` | `palette.dart`, `shapes.dart`, `typography.dart` |

**No MSP in this run may add, rename or remove a token.** If a value appears to be missing, re-read the token file before concluding it is absent; if it is genuinely absent, stop and report rather than adding it — the token layer closed with Cluster A.

### HARD SCOPE FENCE

This run ships **exactly four MSPs: B1, B2, B3, B4.** No others.

- Do **not** create MSPs for clusters A, C, D, E, F, G or H. They are named in §4 only so cross-cluster dependencies stay legible. Cluster A is already merged; re-implementing any part of it is a defect, not a dependency.
- The complete set of files this run may touch is:

  | File | Owning MSP | New? |
  |---|---|---|
  | `lib/app/shell/sidebar_shell.dart` | B1, B2, B3, B4 | no |
  | `lib/app/shell/bottom_bar_shell.dart` | B1 | no |
  | `lib/app/shell/shell_destination.dart` | B3 | no |
  | `lib/app/shell/app_shell.dart` | B4 | no |
  | `lib/design/icons/nav_icons.dart` | B3 | **new** |
  | `lib/design/widgets/icon_sticker_button.dart` | B4 | **new** |
  | `test/app/shell/sidebar_footer_test.dart` | B4 | **new** |

- Any edit outside that table is out of scope. Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/app/theme/app_theme.dart` — B1 overrides the background at the two shell widgets, **not** at the theme. `app_theme.dart:23` and its assertion in `test/app/theme/app_theme_test.dart:12` stay exactly as they are.
  - `lib/design/widgets/dashed_divider.dart` — already faithful and already parameterised. B2 passes arguments at the call site and changes nothing in the widget.
  - `lib/design/tokens/*` — closed by Cluster A (see above).
  - `lib/features/streak/**` — the streak card, its text and its flame are §3.2 rows owned by **C1**, not by this run, even though they sit in the rail.
  - `lib/features/**` generally, `lib/features/entry_cards/**`, `lib/features/capture/**`, `lib/features/mood/**`, `lib/features/garden/**` — later clusters.
- If decomposition suggests a unit outside B1–B4, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

### SERIALIZATION — read before planning parallelism

**All four MSPs edit `lib/app/shell/sidebar_shell.dart`.** This is unlike Cluster A, whose MSPs owned mostly disjoint files. The declared dependency chain is therefore also a file-contention chain and must be executed as one:

```
B1  ->  B2  ->  B3
             \-> B4
```

B3 and B4 both depend on B2 and both edit `sidebar_shell.dart`. They may be planned concurrently, but the second to reach integration **must** rebase onto the first and re-verify; they must not be merged from stale bases. If the engine's dependency graph does not already serialise them on that file, treat the shared file as a hard edge and serialise anyway. A silent textual merge of two independent rewrites of the same rail widget is the most likely failure mode in this run.

---

## 1. BLUF

The app implements the prototype's *vocabulary* correctly — the ink, coral, sage and warm-paper hexes are exact, the three font families are right, the sticker composition (fill + 1.5px ink border + zero-blur offset shadow) is the correct abstraction, and the mood/flower domain model matches the prototype's `FLOWERS` map one-for-one. What it does not implement is the prototype's *grammar*. Cluster A built the vocabulary for that grammar — the radius, shadow and ink-alpha ladders, the split Caveat roles, the primary/secondary button distinction. Cluster B is the **first cluster that spends it on a screen.**

**Cluster B's share**: the app interior still paints `#D9CBB2`, the *outside-the-window* page colour, instead of the `#efe2ce → #e9dcc4` panel wash with its terracotta corner glow (B1). The rail is 32px too wide, has no brand lockup at all, and its wordmark is a single brown line where the prototype sets a tight two-line terracotta stack (B2). The selected nav row is an outlined near-white box with brown text — the prototype's is a terracotta sticker with white text and a hard ink shadow — and all four icons are Material glyphs, including a **sun** where the prototype draws a filled house (B3). The rail footer is two big labelled buttons stacked like extra nav rows where the prototype has a compact 30x30 gear/speaker pair with a two-line caption beside them, and neither button reflects any state (B4).

After Cluster B the app's chrome reads as the prototype's chrome. Cluster C and D then rebuild what sits inside it.

**Aligned means**: every value in the findings table below matches its cited prototype line; every capability in §2 still works and still passes its existing tests unchanged; and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set is reproduced below verbatim from the parent spec. Not every row is endangered by Cluster B — §2.7 names which are. The complete set is carried anyway, for one reason: an implementer who encounters an app-only capability while restyling the shell must be able to tell "preserved by decision" from "leftover to clean up". Every row below is preserved by decision. **N24 binds every MSP in this run without exception.**

**No MSP in this run touches the video playback stack (N1–N10) or the voice row (N11).** If a plan proposes to, the plan is out of scope — stop and report rather than planning around it. The one live behavioural binding in this run is **N20** (B4's sound toggle).

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

A preserve rule stated only in §2 does not bind anything. The parent spec's §2.7 names, for every preserve item, the MSP that could regress it. Filtered to Cluster B, these are the live bindings:

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| **N20 — the `GatedSoundService` gate** | **B4** (the sound button gains real state for the first time) | B4 "Must not regress" |
| **Chooser phone entry point** (`app_shell.dart:30-32`, `bottom_bar_shell.dart:116`) | **B1** (edits `bottom_bar_shell.dart`), **B4** (edits `app_shell.dart`) | B1 and B4 "Must not regress"; `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof |
| **`ShellDestination` accessible labels** | **B3** (rewrites the destination glyph set) | B3 "Must not regress" |
| N24 keys, labels, 106 tests | **every MSP** | §5.3 gate 2, applied before every merge |

Rows bound only to other clusters — `Palette.sunGlow` (E4), entry-card Edit/Delete (A4 done, C4 later), on-this-day states (D1/D4), camera picker (G1/G7), video permission copy (G7), `PhotoTray`/`PhotoThumbnail` (A4/A5 done), N15–N19 settings (A2/A4 done), N1–N10 (C7), N11 (G8), N21 (E1–E4), N22 (C6), N23 (C4/G3), N25 (C3/D2/E1–E4/F1–F3) — are **not** endangered by this run. They are listed in §2 above so no implementer mistakes a preserved capability for dead weight.

**The two shell files B1 and B4 touch outside the sidebar are the reason the chooser row is live.** `bottom_bar_shell.dart` and `app_shell.dart` are the phone chooser's only reachability path. Neither MSP has any business changing that path, and `bottom_bar_shell_test.dart:52` fails if either does.

---

## 3. Findings that Cluster B implements

Every prototype value below was opened and confirmed. Where the original audit's line number was off by one, the corrected line is used. **Read §7 before adopting any value.**

Finding §3.1 (design tokens and shared primitives) was implemented by Cluster A and is already on main. Findings §3.3–§3.4 (Today), §3.5 (flower art), §3.6 (mood picker) and §3.7 (capture composers) belong to later clusters and are omitted here; they are in the parent spec.

### 3.2 Window chrome and nav rail

**Three rows of the parent's §3.2 table are omitted from this slice** — *Streak card*, *Streak text* and *Streak flame*. They live physically in the rail but are owned by **C1**, they edit `lib/features/streak/streak_card.dart`, and the scope fence forbids that file. Do not implement them here; a rail that looks unfinished at the streak card after this run is the correct outcome.

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

The two "No `#6a5c4a` in Palette" / "No `#A3866A` in Palette" notes in the *Current app* column describe the state **before Cluster A**. Both colours now exist as `Palette.inkSoft` and `Palette.windowTitle`. The rows are reproduced verbatim; read those two cells as historical.

---

## 4. MSP decomposition — Cluster B

**The governing invariant**: merging any MSP must leave the branch's app fully working. No MSP may depend on a surface a later MSP creates. Ordering is bottom-up — shared tokens and primitives before the screens that consume them.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster B is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged — this run's base** |
| B | Window chrome and nav rail | B1 – B4 | **YES** |
| C | Today centre column | C1 – C7 | no |
| D | Today right rail | D1 – D4 | no |
| E | Flower art | E1 – E4 | no |
| F | Mood picker | F1 – F4 | no |
| G | Capture composers | G1 – G8 | no |
| H | Verification infrastructure | H1 | no |

Within Cluster B, dependencies are: B1 depends on A1 and A2 (both merged); B2 depends on A1, A2 and **B1**; B3 depends on A1, A2, A4 and **B2**; B4 depends on A1, A2 and **B2**. Every A dependency is satisfied by the base branch. See §0's SERIALIZATION note — the B-to-B edges are also file-contention edges on `sidebar_shell.dart`.

---

### B1 — App panel gradient and window chrome

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

**Must not regress**: the traffic-light geometry is already exact — three 12x12 circles with 8px gaps in close/minimise/zoom order, no borders or glyphs (`sidebar_shell.dart:56-73` vs `:51`). Do not touch it. `lib/app/shell/shell_layout.dart:5-9`'s sidebar-on-macOS / bottom-bar-elsewhere split is correct and stays. **Preserve item** — `bottom_bar_shell.dart:116` is the phone capture chooser's entry point; B1 repaints the shell's background and must not disturb it. `test/app/shell/bottom_bar_shell_test.dart:52` is the standing proof and must still pass.

**Acceptance criteria**: the app interior is a warm cream that is visibly lighter and less grey than before, with a soft terracotta glow in the upper-left. The title bar is 6px taller, its dots start 4px further in, a handwritten `field notes — a journal of days` sits centred in it, and a faint hairline separates it from the body.

---

### B2 — Nav rail geometry and brand lockup

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

**Must not regress**: the rail's vertical structure — wordmark, nav list, flexible `Spacer`, streak card, footer — is already correct against `:69` and stays. The rail must continue to paint no background of its own, letting the B1 panel gradient show through (`sidebar_shell.dart:76-79`). The streak card in that stack is **C1's** and is not restyled here; narrowing the rail from 248 to 216 must not clip or overflow it.

**Acceptance criteria**: the sidebar is visibly narrower, its content starts further from the top edge, a pink peony sits left of the wordmark, and the wordmark reads as a tight two-line terracotta stack `field` / `notes` rather than one long brown line. The seam between rail and content is a faint hairline instead of a heavy dashed rule.

---

### B3 — Nav item states and icon glyph set

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

**Must not regress**: the four destinations and their order — Today, Calendar, Garden, Search, with Settings correctly excluded from the primary list — match `navDef` at `:1559` and stay (`shell_destination.dart:15-20`). Nav item spacing (4px symmetric vertical padding yielding an 8px gap against the prototype's `gap:7px`) and the 18px icon size are already within a pixel and stay. `ShellDestination` must keep exposing a label for accessibility. Replacing `IconData` with a painter must not drop the accessible name of any destination — if the label was previously carried by the `Icon` widget's semantics, it is re-supplied explicitly.

**Acceptance criteria**: the selected nav row is a terracotta sticker with white label and icon and a crisp ink shadow offset down-right — it reads as stuck-on paper, not an outlined box. Unselected rows are a softer brown and no longer compete with it. Today shows a filled **house**, not a sun; Garden shows a three-circle sprout, not a Material florist glyph.

---

### B4 — Nav rail footer: icon-button pair and sync block

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

**Must not regress**: N20 — the sound toggle must drive the same `GatedSoundService` gate as the Sound effects settings row. Do not bypass it. Both controls need accessible labels since they lose their visible text. **Preserve item** — `app_shell.dart:30-32` is the phone capture chooser's entry point; wiring real sound state into `AppShell` must not disturb it, and `test/app/shell/bottom_bar_shell_test.dart:52` must still pass.

**Acceptance criteria**: the rail footer is one horizontal strip — a small gear, a small speaker, then two tight lines of caption text — instead of two big labelled buttons stacked like extra nav rows. Opening Settings turns the gear terracotta with a white glyph. Muting sound swaps the speaker to its crossed-out variant. This is a **behaviour change and warrants a test**: a widget test asserting the settings button's fill responds to `selected` and the sound glyph responds to the sound-enabled state.

---

### Resolved: the question that blocked part of B4

The prototype's sync copy describes a remote-sync product the app does not have. **OQ-1 resolved to (a) on 2026-07-27**: the prototype's two-line 10px/8px treatment is adopted, its strings are not. B4 is unblocked; the exact copy is in B4's target values above.

---

## 5. Verification strategy

### 5.1 What the repo actually has

| Layer | Present | Character |
|---|---|---|
| Token / theme tests | `test/design/tokens/tokens_test.dart`, `test/design/tokens/pubspec_fonts_test.dart`, `test/app/theme/app_theme_test.dart` | Assert token **values and wiring**, not pixels. `app_theme_test.dart:12` asserts `theme.scaffoldBackgroundColor == Palette.page` — **B1 must leave this passing**, which is why B1 overrides at the shells and not at the theme |
| Shell tests | `test/app/shell/bottom_bar_shell_test.dart` | `:52` is the standing proof that the phone capture chooser stays reachable — the one existing test this run can most easily break |
| Design widget tests | `test/design/widgets/sticker_card_test.dart`, `test/design/flowers/flower_spec_test.dart`, `flower_bloom_test.dart`, `test/features/capture/photo/photo_tray_test.dart` | Widget and pure-data assertions |
| Playback behaviour suite | 8 files, **106 tests**, driving the UI through `ValueKey`s and Semantics labels; harnesses at `test/features/entry_cards/support/video_card_harness.dart` and `fake_video_player.dart` | The enforcement layer for the entire preserve list |
| Integration | `integration_test/capture_save_persist_test.dart`, `capture_ui_flow_test.dart`, `media_playback_format_test.dart`, `sandbox_containment_test.dart` | Functional flows, no visual diffing |
| Golden coverage | **None.** `grep -rl "golden\|matchesGoldenFile" test/ integration_test/` returns no matches | — |

### 5.2 The testing rule that governs this run

This project's testing discipline **exempts styling and visual tweaks from new tests by default**. Most of this spec is styling. Being deliberate about the split matters more here than usual, because a spec this wide could otherwise generate dozens of low-value change-detector tests that break on the next legitimate restyle.

**Changes that get NO new test** — the exemption applies:

- Every colour, radius, padding, shadow-offset, font-size, font-weight and gap change in Cluster B. That is the whole of B1, B2 and B3.
- The nav icon glyph rewrite in B3. Per-path geometry assertions are pure change-detectors; geometry is H1's job and H1 is not dispatched here.
- Copy changes that do not change a code path — the window-bar caption, the two sync lines.

**Changes that DO warrant a test** — behaviour or contract, not appearance:

| MSP | Test | Why it clears the admission gate |
|---|---|---|
| B1 | none new; existing `app_theme_test.dart` and `bottom_bar_shell_test.dart` must keep passing unmodified | Visual change only; the two existing tests are the guard rails |
| B2 | none | Pure geometry and layout change; the exemption applies |
| B3 | none | Pure visual change; see the glyph note above |
| B4 | New `test/app/shell/sidebar_footer_test.dart` | Behaviour: settings fill responds to `selected`; sound glyph responds to enabled state. Neither exists today |

Every new test must assert observable behaviour through a public surface, must be placed at the lowest layer that can express it (unit before widget before integration), and must have been seen to fail before the implementation lands. Where a similar test already exists, **update it rather than adding a duplicate**.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **106 playback tests run unmodified and pass.** This is N24 and it is the single most important check in the spec — it is the only mechanism that catches the preserve list being quietly dropped. A failing test here is fixed in the implementation, never by editing or deleting the test.
3. The four `integration_test/` flows pass.
4. Diff-scoped verification via the project's verify command; the full suite runs at the cluster boundary and pre-push, not per change.

There is no golden coverage in this run — H1 builds it and is not dispatched here. Gate 2 is therefore the only automated pixel-adjacent safety net, which is why it is non-negotiable.

**CI is not evidence.** Neither GitHub check runs a Dart test: the receipts workflow is node-only and the D6 check has no Dart import grapher and passes vacuously. `receiptsPass` / `d6Pass` are never acceptable as proof that this run is green. Run `fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge.

### 5.4 Manual spot-check

Retained only for the composite screens where whole-page composition matters more than any single token. **Cluster B is a chrome cluster, so its manual pass is unusually load-bearing** — the rail and title bar frame every screen in the app, and there is no automated pixel net.

Required human pass at the cluster boundary:

- **Desktop (macOS, sidebar shell)** — Today, Calendar, Garden, Search and Settings, checking each of: the cream panel wash and its corner glow, the 42px title bar with its centred caption and hairline, the 216px rail, the peony + two-line wordmark, the active/inactive nav treatment on **each** of the four destinations in turn, and the footer strip with Settings open (gear terracotta) and sound toggled both ways.
- **Phone (bottom-bar shell)** — confirm the panel wash is painted there too and the capture chooser still opens. B1 is the only MSP that touches the phone shell; a half-restyled app is its named failure mode.
- **The streak card is expected to look unfinished** after this run — it is C1's. Do not treat it as a Cluster B defect.

Note the app cannot currently be agent-driven on macOS: a backgrounded `flutter run` loses stdin and dies, and the VM-service screenshot path is unavailable. The visual pass is the user's, run through `flutter run -d macos` — never the standalone binary, which renders a black window.

### 5.5 Plan scope-guard rule (learned in the Cluster A run)

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation. This finding parked A1 through three review iterations and blocked A2, A4 and A5; the corrected A1 plan is the reference shape (`.mitosis/a1-token-ladder.plan.md`, local and gitignored).

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

The parent spec's §6.1 table lists the prototype elements deliberately excluded from alignment: the markdown editor engine, free-manipulation photo cards, the video card's 130px height, the prototype's sync copy, the prototype's settings-screen layout, and the Calendar / Garden / Search / Day Detail screens. All remain excluded.

Two are reachable-looking from Cluster B and must be handled explicitly:

- **The prototype's sync copy** is excluded by OQ-1a. B4 adopts the two-line treatment with truthful strings. An implementer who "restores fidelity" by shipping `Synced to home` has shipped a false capability claim.
- **The settings screen** is not aligned by this run. B4 makes the gear button *reflect* that Settings is open; it does not touch the screen behind it.

### 6.2 Explicitly not a task

- **No grain or noise overlay.** Neither side has one. The prototype's only `noise` match in 1742 lines is `this.noiseBuf(ac, 0.06, …)` at `:1294`, an audio buffer. Recorded so no MSP goes hunting for a texture layer to add or remove.
- **No `flutter_svg` / `vector_graphics` dependency.** All bloom, icon and sprig art stays procedural Dart in `CustomPainter`, per the implementation research. This binds B3 directly — the four nav glyphs are hand-drawn paths in Dart, not imported assets.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants.
- **No `FontVariation('wght', …)` calls.** Bind by `fontFamily` string plus explicit `FontWeight`, as `typography.dart` already does.
- **No pixel-snapping workaround for fractional-DPR antialiasing.** Documented as a Flutter platform limitation in H1; not fixed in-app.
- **No deletion or weakening of the 106 playback tests** under any circumstances (N24).
- **No renames, removals or additions in the token layer.** It closed with Cluster A. See §0.
- **No change to `app_theme.dart` or `dashed_divider.dart`.** Both are correct; see the scope fence.

### 6.3 Open questions

Five of the parent spec's seven open questions were resolved by the product owner on 2026-07-27 (OQ-1 → a, OQ-2 → b, OQ-4 → a, OQ-5 → b, OQ-7 → a). **OQ-1 binds B4 and is resolved**; its resolution is written into B4's target values. The other four bind clusters C, D and G.

Still open: **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model). Neither touches an MSP in this run, and neither may be resolved implicitly by a Cluster B implementer.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Status of this claim, corrected.** The parent spec's first draft asserted that every prototype value had been read at its cited line and confirmed. That was true for the window-chrome, rail, Today and JS-style-block regions — the regions this slice draws on — and the review pass re-confirmed them spot by spot: `:1564` active nav, `:1562` inactive nav ink, `:1218-1221` nav icons, `:59` rail geometry, `:61` logo flower span, `:62` wordmark, `:74-77` footer row and sync block, `:1644`/`:1682` footer buttons, `:50-52` title bar and window title, `:56`/`:18` panel versus page background, `:1669` peony.

It was **not** true for two regions — the note-composer body `:467-473` and the voice/video composer `:479-519` — both systematically off by one or worse, and both corrected in the parent spec. **Neither region is cited by Cluster B**, but the lesson is what matters:

Three further citations were not off-by-one but simply wrong and were repointed in the parent: `ink08`/`ink12`, `Shadows.chip`, and the phone mood-picker sheet. Where the source audit's line number was off by one, the corrected line is used — `:1564` (not 1563) for the active nav style, `:61` (not 60) for the logo flower span.

**Rule for implementers:** re-open the cited line in `docs/prototype/project/Field Notes.dc.html` before adopting any value. This spec has been wrong about line numbers once; treat a citation as a pointer to verify, not as an authority.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
