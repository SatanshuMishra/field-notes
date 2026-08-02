# Prototype Design Alignment — Cluster F (Mood picker) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **F — Mood picker**
MSPs: **F1, F2, F3, F4**
Base: `origin/main` at `e778dd6`
Citation source: `docs/prototype/project/Field Notes.dc.html`

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec on matters of fact.** Where this document reproduces parent text, it reproduces it verbatim. Where this document **corrects** the parent, the correction is marked inline with `CORRECTION` and states what the parent said, what the source actually says, and which line proves it. Where this document **adds** a value the parent omitted, it is marked `ADDITION` and carries its own prototype citation. Where a reader needs material this slice omits — findings §3.1–§3.5 and §3.7, MSPs A1–E4 and G1–H1, the excluded-elements table §6.1 — the parent spec on `main` is the authority.

**Clusters A, B, C, D and E are already merged and are this run's base.** The token layer closed with Cluster A and **Cluster F adds no token and renames no token**. Two recon passes ground this slice — one against the prototype, one against the app — and both are reproduced into the resolutions and tables below rather than referenced. Every prototype value in §3 and §4 was independently re-read from `Field Notes.dc.html` while composing this document; every app anchor was independently re-read from the base commit.

### The headline recon result, stated up front

**Cluster F is small in diff and unusually hostile in its seams.** Its four MSPs touch five files and roughly 400 lines, and yet three of the four cannot be executed from the parent spec as written:

- **F1's target border is unreachable through the widget the panel is built from.** `StickerCard` hardcodes `Shapes.outline` at 1.5px and exposes no border parameter (R1).
- **F3's target block is missing five prototype values** that are on the same four source lines the block already cites, and its transition, scrim and duration all have to be chosen *before* `showGeneralDialog` is called rather than inside it (R4, R5, R6).
- **F4's two headline behaviours — a transient toast and a gated sound cue — have no mechanism anywhere in the app.** There is no toast presenter, and no code has ever played a `SoundCue`. Wiring the cue naively **reds two existing tests** with a failure whose stack trace names `drift`, not the mood feature (R11, R12).

**All twenty are resolved in this section.** No implementer should ever meet one of them mid-flight.

This matters because of this project's own history: the C5 caption and three C7 ladder rows were lost precisely because an implementer met an unreachable anchor or a stale target value while executing, and made a judgement call instead of stopping. This section exists so that no such call is ever needed.

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Twenty decisions. Each states the problem, the chosen resolution, and what was rejected and why. Where a resolution widens an MSP's fence, the widening is **declared** and carries the standard obligation: every other consumer's tests pass **unmodified**.

---

**R1 — The picker panel stops being a `StickerCard`. `mood_picker_sheet.dart` composes its own `DecoratedBox`. `lib/design/widgets/sticker_card.dart` is NOT opened.**

*Problem.* F1's target is `border 2px Palette.ink (from 1.5px)`. The panel is built with the shared `StickerCard` (`mood_picker_sheet.dart:28-30`), whose `build()` hardcodes `border: Shapes.outline` — `Border.fromBorderSide(BorderSide(color: Palette.ink, width: outlineWidth))` with `outlineWidth = 1.5` (`lib/design/tokens/shapes.dart:6`, `:25-27`; `sticker_card.dart:30`). `StickerCard` exposes `padding`, `surface`, `borderRadius`, `shadow` and `rotationDegrees` — and no border. **The 2px border is not reachable through its API.** There is no 2px-ink precedent anywhere in `lib/` to copy.

F3 makes the same problem strictly worse: its sheet needs `border-top: 2px` on the **top edge only** plus `border-radius: 22px 22px 0 0`. A one-sided border is not expressible by `StickerCard` under any parameterisation short of a full `border` field.

*Resolution.* `MoodPickerSheet` stops wrapping its content in `StickerCard` and composes the panel itself, inside `mood_picker_sheet.dart` (F1's own declared file):

```dart
DecoratedBox(
  decoration: BoxDecoration(
    color: Palette.cardWarm,
    border: Border.all(color: Palette.ink, width: _kPanelBorderWidth),
    borderRadius: BorderRadius.circular(Shapes.radiusXl),
    boxShadow: Shadows.softLift,
  ),
  child: Padding(padding: const EdgeInsets.all(22), child: ...),
)
```

F3 then swaps three fields on the same decoration for the sheet branch — `Border(top: BorderSide(...))`, `BorderRadius.vertical(top: Radius.circular(Shapes.radiusSheet))`, `Shadows.pickerSheetLift` — with no new abstraction. In-repo precedents for both shapes: one-sided `Border(bottom: BorderSide(...))` at `lib/app/shell/sidebar_shell.dart:69` and `lib/app/shell/bottom_bar_shell.dart:64`; `BorderRadius.vertical(top: ...)` at `lib/features/today/on_this_day_card.dart:24`.

*Rejected: add a `border` parameter to `StickerCard`.* That is a genuine fence widening onto a shared primitive with **21 call sites across 16 files** (`grep -rn "StickerCard(" lib test`), it re-opens A4's sticker contract mid-spec, and it buys nothing F1 and F3 cannot do locally in a file they already own.
*Rejected: accept the 1.5px shared outline.* `:439` says `border:2px solid #4a3b2e` verbatim. Silently shipping 1.5 is the C7 failure mode.

---

**R2 — The fixed 420 degrades with `LayoutBuilder` + `min(420, available)`. No gutter constant is invented.**

*Problem.* `mood_picker_sheet.dart:15` declares `this.maxWidth = 360` and `:26-27` wraps a shrink-wrapping `Column` in `ConstrainedBox(maxWidth: maxWidth)` — genuinely shrink-to-content today, exactly as the parent's "from" note says. F1 wants a **hard** 420 that "must degrade gracefully below 420 logical px of available width — clamp to available width minus the scrim inset rather than overflowing." Bumping the constant to 420 delivers a *ceiling*, not a fixed width; and there is no "scrim inset" anywhere in the app or the prototype to subtract.

*Resolution.*

```dart
LayoutBuilder(
  builder: (BuildContext context, BoxConstraints constraints) {
    return SizedBox(
      width: math.min(maxWidth, constraints.maxWidth),
      child: panel,
    );
  },
)
```

The existing public `maxWidth` parameter (`mood_picker_sheet.dart:15`, `:21`) is **kept**, its default raised 360 -> 420, and becomes the ceiling fed to `math.min` — so no call site breaks and the ceiling stays injectable. The panel is exactly 420 whenever there is room and exactly the available width when there is not; it never overflows.

**The scrim inset resolves to zero**, because neither the prototype (`:439` is `width:420px` inside a centring flex with no padding) nor the current app has one, and inventing a gutter would put an unsourced number into a spec whose whole discipline is sourced values.

*Rejected: `BoxConstraints(minWidth: 420, maxWidth: 420)`.* It throws when the incoming maximum is below 420, which is the exact case the requirement is about.

---

**R3 — Under `flutter test`, `defaultTargetPlatform` is `android`, NOT `macOS`. F3's phone branch is therefore the branch the existing picker tests exercise.**

*Problem.* The natural reading — "the suite runs on a macOS host, so a macOS-vs-other branch resolves to macOS in tests" — is **false**, and every red-assertion prediction for F3 depends on it.

*Ground truth, read from the SDK.* `/opt/homebrew/share/flutter/packages/flutter/lib/src/foundation/_platform_io.dart` computes `defaultTargetPlatform` and then runs, inside an `assert` (i.e. in every debug-mode test):

```dart
  assert(() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      result = platform.TargetPlatform.android;
    }
    return true;
  }());
```

`flutter test` sets `FLUTTER_TEST`. `flutter_test` itself installs no `debugDefaultTargetPlatformOverride` (the only writes are in `TargetPlatformVariant`, `widget_tester.dart:306-313`), and this repo sets none — there is no `test/flutter_test_config.dart`. `ThemeData.platform` defaults to `defaultTargetPlatform`, so `Theme.of(context).platform` is `android` too. Therefore `resolveShellLayout(...)` returns **`ShellLayout.bottomBar`** in every widget test in this repo.

*Resolution.* Every F3 prediction in this slice is computed on the phone branch, and R4 gives the sheet the structure that keeps the existing assertions green there. Two consequences carried forward:

| Test file | Branch it drives after F3 | Verdict |
|---|---|---|
| `test/features/mood/mood_picker_test.dart` | **phone sheet** (goes through `showMoodPicker`) | green — the phone sheet keeps the title (`:734`) and the mood labels (`:737`); the scrim still covers `Offset(5, 5)` because the sheet is bottom-aligned |
| `test/features/mood/mood_banner_for_date_test.dart` | **phone sheet** (opens the picker by tapping the banner) | green — taps `find.text('Calm')`, which the compact tile still renders |
| `test/features/mood/mood_picker_sheet_test.dart` | **desktop panel** (pumps `MoodPickerSheet` directly, takes the parameter default) | green — R4 requires the default to stay desktop |
| `test/features/mood/mood_picker_grid_test.dart` | **desktop grid** (pumps `MoodPickerGrid` directly) | green — same reason |

*Also corrected:* the recon pass that seeded this slice asserted "`flutter test` on this macOS host resolves as `sidebar`, so F3's bottom-sheet branch is never exercised by the existing suite." The **conclusion** (no red assertions) survives; the **reason** is wrong and would have mis-scoped any future F-cluster change. The reason is that the phone sheet keeps the title and the labels, not that the branch is unreachable.

---

**R4 — F3 branches inside `showMoodPicker`, BEFORE `showGeneralDialog`, and takes an injectable `ShellLayout?` override. `MoodPickerSheet` and `MoodPickerGrid` gain a variant parameter that defaults to DESKTOP.**

*Problem.* Three of the phone sheet's target values are arguments of `showGeneralDialog` itself, not of anything the `pageBuilder` returns: `barrierColor` (`.28` desktop vs `.34` phone), `transitionDuration` (180ms vs 240ms) and the transition itself (fade+scale vs pure slide). A branch placed inside `pageBuilder` cannot reach any of them. Separately, `mood_picker_sheet_test.dart` and `mood_picker_grid_test.dart` pump their widgets **directly**, so whatever default those widgets carry is what those two tests render.

*Resolution.* `mood_picker.dart` resolves the layout first and drives all four decisions from it:

```dart
Future<Mood?> showMoodPicker(
  BuildContext context, {
  Mood? selected,
  ShellLayout? layout,
}) {
  final ShellLayout resolved =
      layout ?? resolveShellLayout(Theme.of(context).platform);
  ...
}
```

- `Theme.of(context).platform` is the argument the only production caller of `resolveShellLayout` already passes (`lib/app/shell/app_shell.dart:48`). Form-factor detection stays in `resolveShellLayout` (`lib/app/shell/shell_layout.dart:5-9`), exactly as F3 requires.
- The optional `layout` override mirrors the repo's established seam for a platform-branched widget: `TodayScreen({this.layout})` with `layout ?? resolveTodayLayout(defaultTargetPlatform)` (`lib/features/today/today_screen.dart:47`, `:56`), pinned by tests at `test/features/today/today_screen_test.dart:72` and `:91`.
- `mood_picker.dart` importing `package:field_notes/app/shell/shell_layout.dart` follows the one existing feature-to-shell precedent, `lib/features/today/this_week_garden.dart:3`.
- `MoodPickerSheet` and `MoodPickerGrid` each gain **one** parameter carrying the variant, **defaulting to the desktop value**. `MoodPickerSheet` maps it to surface geometry; `MoodPickerGrid` maps it to `flowerSize`, tile padding, label style and whether line 2 renders. `mood_picker.dart` is the only caller that ever passes a non-default.

*Rejected: `defaultTargetPlatform` as the argument.* It works identically here, but `Theme.of(context).platform` is what the shell already uses and it honours a `Theme` override.
*Rejected: a second enum for form factor.* `ShellLayout` already names this exact split; a parallel `MoodPickerFormFactor` would need a mapping function and could drift out of step.

---

**R5 — F3's target block is INCOMPLETE. Five phone-sheet values the parent omits are supplied here, verbatim from the four lines the block already cites.**

*Problem.* The parent's F3 block gives the scrim, width, border, radius, padding, shadow, entrance, grab handle and compact-tile padding — and stops. The prototype's phone sheet also restyles the title, the subtitle, the grid and the tile label, on `:734`–`:737`, the lines immediately after the ones already quoted. An implementer who builds only what the block lists ships a phone sheet with desktop-sized type inside phone-sized chrome.

*Resolution — ADDITION, five values, all verbatim:*

| Element | Phone value | Desktop value (F1/F2) | Proto |
|---|---|---|---|
| Title | `font:500 18px 'Newsreader'` `#4a3b2e` centred | 21px | `:734` |
| Subtitle | `font:600 12px 'Caveat'` `#a08a70` centred, margin-top 1 | 14px | `:735` |
| Grid gap | 8 | 10 | `:736` |
| Grid margin-top | 14 | 16 | `:736` |
| Tile line 1 | `font:600 9px 'Instrument Sans'` `#4a3b2e`, margin-top 4 | 11px, margin-top 5 | `:737` |

Expressed against existing tokens, with no token added or changed (R18): title `TypographyTokens.headlineSerif.copyWith(fontSize: 18)`; subtitle `TypographyTokens.subtitleAccent.copyWith(fontSize: 12)`; tile line 1 `TypographyTokens.caption9Sans.copyWith(fontWeight: FontWeight.w600, color: Palette.ink)`.

The sheet surface is `#f8efe0` at `:732` — the same `Palette.cardWarm` F1 adopts, so the two branches share it. The phone sheet **keeps the title and the subtitle**; only the tile's second line is dropped (`:737` renders one label div where `:444` renders two).

---

**R6 — The phone entrance is a PURE SLIDE. It has no fade and no scale.**

*Problem.* F3 says `entrance fn-sheet slide-up 240ms cubic-bezier(.2,.8,.2,1)`. The current transition builder wraps the child in `FadeTransition` + `ScaleTransition` (`mood_picker.dart:43-49`) and F1 retunes those same two. Reusing them for the phone branch adds a fade and a scale the design does not have.

*Resolution, verbatim from the keyframes at `:24-25`:*

| Branch | Keyframe | Transition | Duration | Curve |
|---|---|---|---|---|
| Desktop | `fn-pop` — `opacity 0->1`, `scale(.96)->scale(1)` | `FadeTransition` + `ScaleTransition` | **180ms** (`:439` `.18s`) | ease-out |
| Phone | `fn-sheet` — `translateY(100%)->translateY(0)` | `SlideTransition` only, `begin: Offset(0, 1)` | **240ms** (`:732` `.24s`) | `Cubic(0.2, 0.8, 0.2, 1)` |

`transitionDuration` is a single top-level argument of `showGeneralDialog`, which is the second reason the branch must be resolved before the call (R4).

---

**R7 — F2's tile line 1 is `caption11Sans.copyWith(color: Palette.ink)`, applied locally. The token may NOT be recoloured.**

*Problem.* F2's target is `mood.label in Instrument Sans 11 w600 Palette.ink`. `TypographyTokens.caption11Sans` (`lib/design/tokens/typography.dart:201-206`) is 11 / w600 — matching — but `color: Palette.coral`.

*Resolution.* `TypographyTokens.caption11Sans.copyWith(color: Palette.ink)`, inline in `mood_picker_grid.dart` (F2's only declared file). The token itself is untouchable on two independent grounds: `test/design/tokens/tokens_test.dart:315` asserts `caption11Sans.color == Palette.coral`, and `lib/features/mood/mood_banner.dart:110` renders the change pill's coral label through it. Line 2 needs **no** `copyWith`: `caption9Sans` (`typography.dart:222-227`) is 9 / w400 / `Palette.muted` = `0xFFA08A70`, an exact match for `:444`'s `400 9px 'Instrument Sans'; color:#a08a70`.

---

**R8 — CORRECTION: `captionSans` is w400, not w500.**

The parent's F2 block documents the tile's current line 1 as `from captionSans 12 w500 Palette.muted, SizedBox(height: 6)`. `typography.dart:188-193` declares `captionSans` at `fontSize: 12, fontWeight: FontWeight.w400, color: Palette.muted`. The `SizedBox(height: 6)` half is correct (`mood_picker_grid.dart:81`). Non-blocking — a brand-new 11 / w600 style replaces it either way — but recorded so the error stops recirculating.

---

**R9 — The 4/4/2 grid is a `Column` of `Row`s with `Expanded` cells and two fillers. `Wrap` cannot express it and `GridView` must not be used.**

*Problem.* The target is `grid-template-columns: repeat(4, 1fr); gap: 10` with ten tiles flowing 4 + 4 + 2 and **the last row left-aligned in the first two columns** (`:442`). The current `Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16)` (`mood_picker_grid.dart:25-28`) centres every row and sizes each child to its intrinsic width — it can reproduce neither the equal `1fr` tracks nor the left-aligned remainder.

*Resolution.* Three `Row`s in a `Column`, each `Row` holding four cells separated by `SizedBox(width: gap)`, each cell an `Expanded`. The final row carries two tiles and **two `Expanded(child: SizedBox.shrink())` fillers**, which is what reproduces `1fr` tracks and a left-aligned remainder in one construct. Row gaps are `SizedBox(height: gap)` between the rows.

*Arithmetic, verified.* At F1's panel: `420 - 2*22 padding - 2*2 border = 372` content; three 10px gaps leave `342`; `342 / 4 = 85.5` per column, against a 44 glyph plus 6+6 tile padding = 56. Fits with 29.5 to spare. On the phone sheet at a 390pt width: `390 - 16 - 16 = 358` (the sheet's border is top-only, so it costs no horizontal space), three 8px gaps leave `334`, `334 / 4 = 83.5` against a 34 glyph plus 4+4 = 42. Fits.

`Expanded` requires a bounded width. The panel is bounded by R2's `SizedBox`; the direct-pump grid test is bounded by the 800px test surface through `Center` (`test/features/mood/support/mood_harness.dart:9-11`).

*Rejected: `GridView.count`.* It needs a `childAspectRatio` the design does not specify, it introduces scroll semantics inside a modal, and `shrinkWrap: true` inside a `Column` is the standard performance trap.
*Rejected: `Wrap(alignment: WrapAlignment.start)`.* Left-aligns the last row but still sizes tiles to content, so the columns are unequal and the break point depends on text width.

---

**R10 — The cue and the toast fire on EVERY successful mood write, not only after a confirm. Only the DIALOG is gated on an existing mood.**

*Problem.* F4's target reads "On confirm: play the `pencil` sound cue, write the mood, then toast `Mood planted · {flowerName}`" followed by "Picking a mood for a day with **no** existing mood writes directly with no confirmation, as today." Read literally, the first pick of the day — the common case — gets no cue and no toast, and only a *replacement* gets feedback.

*Ground truth, `:1344-1348`:*

```
if(existing){ this.askConfirm(dev,{ ...onYes:()=>this.doPickMood(dev,day,m) }); }
else { this.doPickMood(dev,day,m); }
doPickMood(dev, day, m){ this.play('pencil'); this.setDayMood(day,m);
                         this.flash(dev,'Mood planted · '+this.FLOWERS[m].name); }
```

Both branches converge on `doPickMood`. The cue and the toast belong to **planting a mood**, not to confirming a replacement. The parent's "as today" attaches to "no confirmation" — its own acceptance criterion contrasts only the dialog ("the no-existing-mood path skips the dialog").

*Resolution.* `_changeMood` gates only the dialog on `current != null`. The write, the cue and the toast are one path that both branches reach. The inline error path (`mood_banner_for_date.dart:41-48`) stays exactly as it is, and a failed write produces **no** cue and **no** toast.

**CORRECTION to the parent's citation.** F4 cites `:1345` for its whole target behaviour. `:1345` is the `askConfirm` config only — title, message, confirmLabel, danger. The on-confirm behaviour is at **`:1348`** and the toast's lifetime at **`:1323`**. Cite `:1344-1348` for the branch and `:1323` for the dismissal.

---

**R11 — The toast is the existing `Toast` widget, rendered from local state, auto-cleared after 1900 ms, and its `Timer` MUST be cancelled in `dispose()`.**

*Problem.* The app has **no transient notification mechanism**: `grep -rln "OverlayEntry|SnackBar|Overlay.of" lib` returns zero files. `lib/design/feedback/toast.dart` is a static visual component, and both of its consumers mount it permanently inline (`lib/features/settings/widgets/settings_notice.dart:19`, `lib/features/capture/video/video_recorder_sheet.dart:115`). Nothing shows-then-hides anything.

*Resolution.* A `String? _toastMessage` field on `_MoodBannerForDateState`, rendered by the same conditional-append pattern the file already uses for `_writeError` (`mood_banner_for_date.dart:26`, `:73-79`), and cleared by a `Timer` of **1900 ms** — the prototype's own value at `:1323`: `this._t[dev]=setTimeout(()=>this.patch(dev,{toast:null}),1900)`. The same line also fixes the re-entry rule: `if(this._t[dev]) clearTimeout(this._t[dev])` — a second plant **restarts** the timer rather than stacking.

**The timer must be cancelled in `State.dispose()`.** This is not hygiene, it is a hard test requirement: `AutomatedTestWidgetsFlutterBinding._verifyInvariants` asserts `!timersPending` after the tree is disposed (`flutter_test/src/binding.dart:2529-2542`, message `A Timer is still pending even after the widget tree was disposed.`). Measured on this base: a 1900 ms timer created in a widget and cancelled in `dispose()` does **not** trip the invariant; the same timer left uncancelled fails the test.

*Rejected: a new Overlay-based toast presenter in `lib/design/feedback/`.* A new cross-cutting primitive and a new file for one call site, neither in F4's file list.
*Rejected: adopting the prototype's toast chrome.* `:453` is a dark ink pill — `background:#4a3b2e; color:#f6ead6; border-radius:22px; padding:10px 20px; font:600 13px 'Instrument Sans'` — bottom-centred with a check icon. The app's `Toast` is a light `StickerCard`. Restyling it is a fence widening onto a shared widget with two other consumers, authorised by no MSP in the parent spec. **Declared deviation:** F4 ships the app's existing `Toast` treatment with the prototype's copy and lifetime; the pill chrome and the bottom-centre placement are deferred (§6.1).

---

**R12 — Playing the cue pulls the real database into two EXISTING tests and fails them. Both get two provider overrides. Declared, bounded, measured.**

*Problem.* `soundServiceProvider` (`lib/features/sound/sound_providers.dart:26-34`) is built from `soundPlayerProvider` (a real `AudioPlayersSoundPlayer`) and `soundEnabledProvider`, and `soundEnabledProvider` watches `appSettingsProvider` -> `settingsRepositoryProvider` -> `databaseProvider` -> `AppDatabase.open()`. `test/features/mood/mood_banner_for_date_test.dart` overrides `journalRepositoryProvider` only. Under R10 both of its cases reach the cue.

*Measured on this base, not inferred.* A probe widget reading `soundServiceProvider` under exactly that override set fails the test:

```
Pending timers:
Timer (duration: 0:00:00.000000, periodic: false), created:
#6      StreamQueryStore.markAsClosed (package:drift/src/runtime/executor/stream_queries.dart:156:11)
#7      QueryStream._onCancelOrPause (package:drift/src/runtime/executor/stream_queries.dart:305:14)
#24     $StreamProviderElement.dispose (package:riverpod/src/providers/stream_provider.dart:163:11)
...
A Timer is still pending even after the widget tree was disposed.
'package:flutter_test/src/binding.dart': Failed assertion: line 2542 pos 12: '!timersPending'
```

The failing timer is scheduled by **drift**, during container teardown, from the `appSettingsProvider` stream element. Nothing in the trace names the mood feature. No database file is written — `openConnection()` (`lib/data/database/connection.dart:10-16`) is a `LazyDatabase` whose `getApplicationDocumentsDirectory()` has no plugin under `flutter test` — but the query-stream machinery is constructed regardless, and that is enough to fail the test.

Adding two overrides makes the same probe pass, and `FakeSoundPlayer.played` reads `['sounds/pencil.wav']`:

```dart
appSettingsProvider.overrideWith(
  (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
),
soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
```

*Resolution.* Both existing cases in `test/features/mood/mood_banner_for_date_test.dart` (`:18-20` and `:49-51`) gain those two overrides. **No assertion in either case changes, no case is added, renamed, weakened or removed** — this is harness maintenance forced by a mandated change, the same species as the retarget permission in `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, and it is declared here so the implementer does not have to interpret it. `AppSettings.defaults.soundEnabled` is `true` (`lib/domain/settings/app_settings.dart:14-20`), so the gate is open and the assertion is meaningful.

The same two overrides are the standing pattern for F4's new test file. `FakeSoundPlayer` already exists at `test/features/sound/support/fake_sound_player.dart` and is imported, not copied and not modified — which means the assertion runs through the **real `GatedSoundService`**, satisfying N20 by exercise rather than by stub. Do **not** override `soundServiceProvider` itself; that would assert the call and skip the gate the constraint is about.

---

**R13 — F4's confirm dialog is a private widget inside `mood_banner_for_date.dart`. No shared confirm primitive exists and no new file is authorised.**

*Problem.* F4 implies a dialog with title / message / confirmLabel / danger. No generic `showConfirmDialog` helper exists in `lib/design/**` or `lib/features/**`; the only precedent is the fully bespoke `confirmDeleteAll` + `DeleteAllConfirmDialog` (`lib/features/settings/widgets/delete_all_dialog.dart:5-62`), which lives in its own file. F4's file list is `mood_banner_for_date.dart` plus the new test — extracting a new widget file would leave the fence.

*Resolution.* A private `Future<bool> _confirmMoodChange(...)` plus a private dialog widget, both inside `mood_banner_for_date.dart`, shaped exactly like `delete_all_dialog.dart:5-62`: `showDialog<bool>` with `barrierDismissible: true`, a `Center` + `Material(type: MaterialType.transparency)` + `ConstrainedBox(maxWidth: 420)` + `StickerCard`, a title in `titleSerif`, a message in `bodySans`, and two `StickerButton`s. Because F4 specifies `danger: false`, the pair is `StickerButtonVariant.secondary` for the cancel and `StickerButtonVariant.primary` for `Change mood` — the danger variant (`sticker_button.dart:5`) is not used. A `null` result (barrier dismissal) means cancel.

Note this dialog is a `StickerCard` and stays one: R1 removes `StickerCard` from the *picker panel* only, because only the picker panel needs a border the widget cannot express.

---

**R14 — `{dayLabel}` and the two title variants resolve against `todayDateProvider`.**

*Problem.* F4's title is `'Change today's bloom?'` "(or `'Change this day's bloom?'` for a past day)" and its message interpolates `{dayLabel}`. `MoodBannerForDate` holds only `widget.date`, a `YYYY-MM-DD` key (`mood_banner_for_date.dart:18`). Nothing in the widget knows whether that key is today, and the prototype's own `dayLabel` (`:1333`) is a fixture lookup with no app counterpart.

*Resolution.* `isToday` is `widget.date == ref.read(todayDateProvider)` — the app's single source of truth for the current date key (`lib/features/today/today_providers.dart:17-18`, `todayDate(Ref) => captureDateKey(ref.watch(todayClockProvider)())`), already consumed cross-feature at `lib/app/shell/app_shell.dart:34`, and injectable through `todayClockProvider` for tests. Import the file directly (`package:field_notes/features/today/today_providers.dart`), not the `today.dart` barrel, which re-exports `today_screen.dart` and would import the mood feature back into itself.

| Field | Today | Any other day |
|---|---|---|
| Title | `Change today's bloom?` | `Change this day's bloom?` |
| `{dayLabel}` | `today` | `headerDateLabel(parsed)` — `Sunday, July 19` (`lib/features/today/today_date.dart:48-53`) |

`parsed` is `parseDateKey(widget.date)` (`today_date.dart:74-84`), which returns `null` for a malformed key; on `null` the label falls back to the raw `widget.date` rather than throwing. `today_date.dart` is a leaf with one import.

`{flowerName}` is `chosen.flower.label` and `{moodLabel}` is `chosen.label` (`lib/domain/mood/mood.dart:5-21`, `lib/domain/mood/flower_kind.dart:2-13`). Verified against the prototype's own `FLOWERS[m].name` values at `:1045-1056`: `Peony`, `Rose`, `Sunflower`, `Chrysanthemum`, `Daffodil`, `Lavender`, `Aster`, `Poppy`, `Bleeding Heart`, `Red Spider Lily` — byte-identical to `FlowerKind.label` for all ten selectable kinds. The separator is U+00B7 MIDDLE DOT in both the message and the toast.

---

**R15 — `Shadows.pickerSheetLift` ALREADY EXISTS. F3 neither adds it nor renames anything.**

Review change-log item 6 (`docs/specs/2026-07-26-prototype-design-alignment.md:2047`) split one `Shadows.sheetLift` into `pickerSheetLift` and `chooserSheetLift` because F3 and G4 wanted two different values. That split **landed in A1**: `lib/design/tokens/shadows.dart:114-121` declares `pickerSheetLift = BoxShadow(color: Color(0x80322314), offset: Offset(0, -12), blurRadius: 30, spreadRadius: -12)` — `0x80/255 = .502`, exactly `0 -12px 30px -12px rgba(50,35,20,.5)`. An unqualified `Shadows.sheetLift` does not exist. Both split names have **zero consumers** in `lib/`, so F3 consuming `pickerSheetLift` carries no collision risk and requires no token work at all.

---

**R16 — The two scrims are inline `Color` literals in `mood_picker.dart`. The other six dialogs keep theirs and are out of fence.**

*Problem.* F1's scrim is `rgba(42,36,29,.28)` = `Color(0x472A241D)` and F3's is `rgba(42,36,29,.34)` = `Color(0x572A241D)`. Neither literal appears anywhere in `lib/` today. `Palette.ink.withValues(alpha: 0.32)` is the current value and is **shared, by idiom, across seven dialogs**: `mood_picker.dart:19`, `capture_chooser.dart:21`, `text_composer.dart:102`, `voice_composer.dart:150`, `video_composer.dart:348`, `day_detail_edit_note.dart:72`, `show_day_detail.dart:21`.

*Resolution.* Introduce both as inline `const Color` literals in `mood_picker.dart`, matching the existing inline-scrim idiom. **Do not promote them to `Palette`** — the token layer closed with Cluster A (§6.2) — and **do not touch the other six dialogs**; the composers' scrims are Cluster G's and the day-detail ones are out of this spec entirely. The picker's scrim being the only one at `.28` after F1 is correct, not an inconsistency to tidy.

*Arithmetic:* `0x47 = 71`, `71/255 = .278`; `0x57 = 87`, `87/255 = .341`; `0x2A241D = rgb(42, 36, 29)`. Both match.

---

**R17 — CORRECTION: the scrim-and-barrier citation is `mood_picker.dart:17-19`, not `:16-17`.**

F1's "Must not regress" reads "Scrim dismissal behaviour is already correct — tapping outside closes without selecting, with a semantic barrier label (`mood_picker.dart:16-17` vs `:438`)". The real anchors are `:17` `barrierDismissible: true`, `:18` `barrierLabel: 'Dismiss mood picker'`, `:19` `barrierColor`. The pair is `:17-18` and F1 changes `:19`, so the useful span is **`:17-19`**. This is a fifth instance of the citation drift the parent's §7 and §8 already document — treat every remaining line citation as a pointer to verify (§7).

---

**R18 — Cluster F adds no token, renames no token, and removes no token. It is the FIRST consumer of six that A1 shipped unused.**

Verified by `grep -rn <name> lib | grep -v tokens/` on this base — every one of these has zero production consumers today, and Cluster F is what A1 shipped them for:

| Token | Value | First consumed by |
|---|---|---|
| `Shapes.radiusXl` | 20 | F1 |
| `Shadows.softLift` | `0 20 50 -16` `0x99322314` | F1 |
| `Palette.ink20` | `0x334A3B2E` | F2 |
| `Shadows.tileSelected` | `2 2 0` `Palette.coral30` | F2 |
| `Shapes.radiusSheet` | 22 | F3 |
| `Shadows.pickerSheetLift` | `0 -12 30 -12` `0x80322314` | F3 |

Every other value Cluster F needs also already exists at target: `Palette.cardWarm` `0xFFF8EFE0`, `Palette.cardBright` `0xFFFFFAF1`, `Palette.cardLight` `0xFFFFF5EA`, `Palette.ink` `0xFF4A3B2E`, `Palette.ink30` `0x4D4A3B2E`, `Palette.coral` `0xFFC76A54`, `Shapes.radiusMd` 14, `Shapes.outlineWidth` 1.5, `TypographyTokens.headlineSerif` (Newsreader 21 w500 ink), `subtitleAccent` (Caveat 14 w600 muted), `caption11Sans` (11 w600), `caption9Sans` (9 w400 muted). **No MSP in this cluster opens `lib/design/tokens/**`.**

---

**R19 — Glyph sizes: F2 takes the picker tile 56 -> 44, F3 takes the compact tile to 34, and `mood_banner.dart` is not opened.**

`mood_picker_grid.dart:12` still declares `flowerSize = 56`; E4 correctly left it alone, and the parent's E4 ladder row for the picker tile is annotated "F2 owns the picker tile size (44)" (`:1293`, `:1314`). `lib/features/mood/mood_banner.dart:35` renders `FlowerBloom.forMood(current, size: 54)` — C2's, landed, and **read-only for this entire cluster**. The two are independent constants in different files; F2 changes one and never the other.

---

**R20 — CORRECTION: the N24 shorthand paths are wrong. Cluster F has zero exposure either way.**

The shorthand naming `test/playback/video_slots_test.dart` and seven files "under `test/cards/`" names two directories that do not exist. The eight untouchable files, verified present on this base:

| # | Test file |
|---|---|
| 1 | `test/features/entry_cards/playback/video_slots_test.dart` |
| 2 | `test/features/entry_cards/cards/video_body_lifecycle_test.dart` |
| 3 | `test/features/entry_cards/cards/video_controls_overlay_test.dart` |
| 4 | `test/features/entry_cards/cards/video_body_test.dart` |
| 5 | `test/features/entry_cards/cards/video_body_slots_test.dart` |
| 6 | `test/features/entry_cards/cards/video_body_poster_gate_test.dart` |
| 7 | `test/features/entry_cards/cards/video_body_attempt_identity_test.dart` |
| 8 | `test/features/entry_cards/cards/video_scrubber_test.dart` |

**Cluster F has zero exposure to any of them**, confirmed by path disjointness against every F1–F4 file list and by `grep` in both directions: no F-cluster symbol (`MoodPicker*`, `MoodBanner*`, `showMoodPicker`, `FlowerBloom`) appears in those eight files, and none of their keys or labels appears in the mood feature.

---

### HARD SCOPE FENCE

This run ships **exactly four MSPs: F1, F2, F3, F4.** No others.

- Do **not** create MSPs for clusters A, B, C, D, E, G or H. They are named below only so cross-cluster dependencies stay legible. Clusters A–E are already merged; re-implementing any part of them is a defect, not a dependency.
- The complete set of files this run may touch is:

  | File | Owning MSP | New? |
  |---|---|---|
  | `lib/features/mood/mood_picker_sheet.dart` | F1, F3 | no |
  | `lib/features/mood/mood_picker.dart` | F1, F3 | no |
  | `lib/features/mood/mood_picker_grid.dart` | F2, F3 | no |
  | `lib/features/mood/mood_banner_for_date.dart` | F4 | no |
  | `test/features/mood/mood_repick_test.dart` | F4 | **new** — the only new test file this cluster authorises |
  | `test/features/mood/mood_banner_for_date_test.dart` | F4 | no (**declared, bounded**: two provider overrides per case, zero assertion changes — R12) |

- **One declared edit outside an MSP's stated file list**, bounded and carrying the standard obligation that every other consumer's tests pass **unmodified**:
  - **F4 gains `test/features/mood/mood_banner_for_date_test.dart`** (R12). Bounded to adding `appSettingsProvider` and `soundPlayerProvider` overrides to the two existing cases. No assertion is added, changed, weakened or removed; no case is renamed.
  - There is **no** production-code widening in this cluster. R1 exists precisely to avoid one.
- Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/design/widgets/sticker_card.dart` — 21 call sites across 16 files, and A4's contract, pinned by `test/design/widgets/sticker_card_test.dart`. F1's border is solved locally (R1). **Adding a `border` parameter is out of bounds — stop and report.**
  - `lib/design/tokens/**` — closed by Cluster A. No rename, no removal, **no addition**. Every value Cluster F needs already exists (R18); the two scrims are inline literals (R16).
  - `lib/design/feedback/toast.dart` — shared, two other consumers. F4 uses it as-is (R11).
  - `lib/features/mood/mood_banner.dart` — **READ ONLY for this cluster.** C2 owns the Today mood card and its 54px glyph (`:35`); `caption11Sans`'s coral is load-bearing there (`:110`, R7).
  - `lib/domain/mood/mood.dart` and `lib/domain/mood/flower_kind.dart` — `moodOrder`, the enum values and the display strings are exact and drive both the grid order and F4's copy. Neither file is in any file list above.
  - The six other dialogs' `barrierColor` lines (R16) — out of fence; the composers' scrims are Cluster G's.
  - `lib/features/entry_cards/**` and every file named in R20's table — untouchable infrastructure. **If your diff touches one of those eight files, you have gone out of bounds — stop and report.**
- If decomposition suggests a unit outside F1–F4, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

### SERIALIZATION — read before planning parallelism

**The run order is F1, then F2, then F3, then F4 — strictly sequential, one wave each.**

Per `decisions/2026-07-27-shared-file-cluster-serializes.md`, a shared file is a HARD dependency edge that the slice **declares** rather than leaving to the engine's graph to infer.

| Shared file | Claimed by | Edge |
|---|---|---|
| `lib/features/mood/mood_picker.dart` | F1, F3 | **F1 -> F3** |
| `lib/features/mood/mood_picker_sheet.dart` | F1, F3 | **F1 -> F3** |
| `lib/features/mood/mood_picker_grid.dart` | F2, F3 | **F2 -> F3** |
| `lib/features/mood/mood_banner_for_date.dart` | F4 | none |
| `test/features/mood/mood_banner_for_date_test.dart` | F4 | none |

The parent's own declared dependencies add three contract edges: F1 depends on A1, A2, A3 (`:1330`); F2 on A1, A2, E1, F1 (`:1367`); F3 on F1, F2 (`:1410`); F4 on A3, F1 (`:1442`). A1, A2, A3 and E1 are merged.

```
F1  (panel chrome, copy, scrim, entrance)
 |
F2  (tile grid: 4/4/2, tile cards, two label lines, 44 glyph)
 |
F3  (phone bottom-sheet branch + compact tile variant)
 |
F4  (re-pick confirm gate, pencil cue, planted toast)
```

**F4's only hard edge is F1** — it shares no file with F2 or F3 and no contract with either. It is nonetheless ordered **last**, deliberately: F3 changes which picker branch runs under `flutter test` (R3), so F4's new test file silently changes what it drives depending on merge order. Authoring F4 last means its predicted behaviour is its observed behaviour. If wall-clock pressure ever forces F4 to be authored alongside F2/F3, it **must** rebase onto `main` after F3 merges and re-run `fullValidationCmd` on that base before it ships.

The repo squash-merges, so once an MSP lands, `main` holds its content under a SHA absent from the next branch's history. Each MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. **Never carry a green from one base to another.**

### THE STANDING INVARIANT — the mood picker opens, picks and dismisses at EVERY commit

This governs every MSP in this cluster and outranks any convenience.

The picker is the only way to set a mood, and setting a mood is the app's headline interaction. Three receipts hold the whole chain and must be green at every commit, on every branch:

1. `test/features/mood/mood_picker_test.dart` — opens the picker, picks `Calm`, gets `Mood.calm` back; dismisses by barrier and gets `null`.
2. `test/features/mood/mood_picker_sheet_test.dart` — the title renders, the grid renders, all ten labels render, a tap forwards the mood.
3. `test/features/mood/mood_banner_for_date_test.dart` — the end-to-end write, and the inline error on a failed write.

Concretely, per MSP:

- **F1** changes the panel's chrome, copy, scrim and entrance. It does not change what the panel contains or what a tap does. If any of the three receipts goes red, F1 is wrong.
- **F2** rewrites the grid's layout and adds a second label line. Mood labels and flower labels are **disjoint sets** — `{Happy, Loved, Warm, Grateful, Hopeful, Calm, Anxious, Tired, Sad, Angry}` versus `{Peony, Rose, Sunflower, Chrysanthemum, Daffodil, Lavender, Aster, Poppy, Bleeding Heart, Red Spider Lily}` — so `find.text(mood.label)` still resolves to exactly one widget after line 2 lands. If it does not, F2 has rendered the wrong string.
- **F3** adds a branch; it does not replace the dialog. The desktop path from F1/F2 must be reachable and unchanged, and the direct-pump defaults must stay desktop (R4). Under `flutter test` the phone branch is what runs (R3), so **both** branches are covered only if the desktop default is preserved.
- **F4** wraps the write in a gate. The no-existing-mood path must still write directly, and the failed-write path must still surface its inline error, unchanged.

An MSP that ships a picker that cannot be opened, cannot be dismissed, or writes on a cancel violates the green-branch invariant regardless of test results. Tests do not assert pixels here; the manual pass in §5.4 is load-bearing and is owed by a human.

---

## 1. BLUF

The mood picker is the app's single most-used modal and the only route to the data every flower in the app renders. It is also the least aligned surface left: a narrow near-white card on a hard 3px offset shadow, holding ten oversized glyphs that wrap 3/3/3/1 into centred rows of invisible tiles, opening on a scrim that is the wrong colour at the wrong opacity, with no subtitle, one form factor, and no feedback of any kind when a mood is planted or replaced.

**Cluster F's share.** F1 makes the panel what the design draws: 420 wide and fixed, warm cream rather than near-white, a 2px edge, a 20 radius, 22 of padding, and a large soft drop shadow in place of the hard offset — plus the handwritten `choose today's bloom` under a heading that drops from 24 w600 to the designed 21 w500. F2 replaces the `Wrap` with the design's four-column grid so the ten tiles flow 4 + 4 + 2 with the last row left-aligned, gives every tile a visible card with a faint outline, gives the selected tile a cream fill with a thicker coral border and a hard coral shadow, shrinks the glyph 56 -> 44, and adds the flower's own name under the mood's. F3 adds the phone form factor the app has never had: a bottom sheet with a grab handle, a top-only border, compact tiles and a slide-up entrance. F4 closes the interaction: replacing an existing bloom asks first, and planting one plays the pencil cue and says so.

**Cluster F adds no token, renames no token and removes no token.** It is the first consumer of six tokens A1 shipped for exactly this cluster (R18), and it touches four production files, all inside `lib/features/mood/`.

**Aligned means**: every value in §4 matches its cited prototype line; every capability in §2 still works and still passes its existing tests, unmodified except for the two declared provider overrides (R12); and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set N1–N25 is defined in the parent spec. This slice reproduces in full only the rows Cluster F can reach, and names the rest by number.

**N1–N19 and N21–N23 are unreachable from this run**, confirmed by path disjointness against every file in §0's fence: no MSP here edits `lib/features/entry_cards/**`, `lib/features/capture/**`, `lib/features/settings/**`, `lib/features/data/**`, `lib/features/search/**`, `lib/features/day_detail/**` or `lib/features/garden/**`. They are preserved by non-contact.

### 2.1 The three rows that bind THIS run

| # | Constraint | Verified citation |
|---|---|---|
| **N20** | **All UI sound cues stay behind `GatedSoundService`** so the per-call enabled check and the error suppression remain in force. F4's `pencil` cue is the app's **first** cue of any kind. | `lib/features/sound/gated_sound_service.dart:9-31` (the gate at `:22-24`, the swallow at `:27-29`); provider at `lib/features/sound/sound_providers.dart:26-34`; cue at `lib/domain/services/sound_service.dart:3`. `grep -rn "SoundCue\." lib` returns **zero** production call sites today — read `play`'s signature directly rather than pattern-matching a caller that does not exist. |
| **N24** | **`ValueKey`s and Semantics labels are a public contract, not implementation detail.** May not be renamed. If a rewrite breaks any test in the eight-file playback suite, the correct response is to fix the implementation — **never to delete or weaken the test.** | The eight files, with **corrected paths**, are tabulated at R20. Cluster F has zero exposure. |
| **N25** | **Blooms keep their accessible labels** — `Semantics(image: true)` plus the mood/flower label wrapper — and **mood picker tiles keep their button + selected semantics**. No prototype counterpart; preserve. | `lib/design/flowers/flower_bloom.dart:35-37`; `lib/features/mood/mood_picker_grid.dart:57-60`. |

**N25 in practice, for this cluster.** `mood_picker_grid.dart:57-60` wraps each tile's `GestureDetector` in `Semantics(button: true, selected: isSelected, label: mood.label)` — exactly one wrapper per tile, nothing more. F2 rewrites the tile's decoration, padding, glyph size and label lines **inside** that wrapper and must not restructure it; F3 does the same for the compact variant. The standing receipt is `test/features/mood/mood_picker_grid_test.dart:30-43`, which finds a `Semantics` widget whose `properties.selected == true` and asserts exactly one — it must stay green **unmodified** through F2 and F3. Adding a second `Text` per tile does not add a `Semantics` node; if that assertion goes to `findsNWidgets(2)`, a tile has been wrapped twice.

**A3 is a standing constraint, not a dependency to re-do.** F1's "Must not regress" says "A3 must already have landed; do not reintroduce a non-Material `pageBuilder`." A3 shipped `DialogHost` (`lib/design/feedback/dialog_host.dart`), a `Material(type: MaterialType.transparency)` wrapper, and `mood_picker.dart:26` mounts the sheet inside it. **Both** of F3's branches keep that wrapper. Removing it re-opens the yellow-double-underline defect at §3.6's first row, which is the single worst-looking bug this spec fixed.

### 2.2 Additive elements to preserve, not delete

| Element | Citation | Endangered by |
|---|---|---|
| The inline write-failure message on a failed mood write | `lib/features/mood/mood_banner_for_date.dart:41-48`, rendered at `:73-79` | **F4** — the confirm gate wraps this path. The `catch` block survives byte-identical; a failed write produces no cue and no toast (R10) |
| The barrier's semantic label `'Dismiss mood picker'` | `lib/features/mood/mood_picker.dart:18` | **F1, F3** — both branches keep `barrierDismissible: true` and the label; only `barrierColor` changes (R16) |
| The `maxWidth` parameter on `MoodPickerSheet` | `lib/features/mood/mood_picker_sheet.dart:15` | **F1** — kept, default raised 360 -> 420, repurposed as the ceiling for R2's clamp |

### 2.3 Preserve-to-MSP binding — the rows that bind THIS run

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| **N25** picker tile button + selected semantics | **F2** (tile rewrite), **F3** (compact variant) | F2 and F3 "Must not regress"; receipt is `mood_picker_grid_test.dart:30-43`, unmodified |
| **N20** cues route through `GatedSoundService` | **F4** (the app's first cue) | F4 "Must not regress"; asserted through the real service, not a stub (R12) |
| **N24** keys, labels, the eight playback files | nothing in this run — confirmed by path disjointness | §0's fence, R20, §5.3 gate 2 |
| A3's Material ancestor | **F1, F3** (both touch `pageBuilder`) | §2.1 closing note; F1 and F3 "Must not regress" |
| Inline write-failure message | **F4** | F4 "Must not regress", R10 |

---

## 3. Findings that Cluster F implements

Reproduced from the parent spec's §3.6. **Two cells are corrected** and one row is **dropped as already satisfied**, each marked inline.

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| ~~Text decoration~~ | ~~No `text-decoration` on the title or any tile label~~ | **DROP — already fixed.** A3 landed `DialogHost` and `mood_picker.dart:26` mounts the sheet inside it, so the ambient `DefaultTextStyle` is no longer `_errorTextStyle`. No yellow underline remains. F1's acceptance criterion "No yellow underline anywhere" is therefore a **regression check**, not work | — | proto `:440` / `lib/design/feedback/dialog_host.dart`, `lib/features/mood/mood_picker.dart:26` |
| Grid columns | `display:grid; grid-template-columns:repeat(4,1fr); gap:10px; margin-top:16px` — 10 tiles flow **4 + 4 + 2**, last row left-aligned | `Wrap(alignment: center, spacing: 16, runSpacing: 16)`; tile = 56 glyph + 8 + 8 padding = 72px, available = 360 − 20 − 20 = ~317px, so the Wrap breaks at **three** per row: 3 + 3 + 3 + 1, every row centred | critical | proto `:442` / `mood_picker_grid.dart:25-28`, `mood_picker_sheet.dart:15`, `:26-30`; construction fixed at R9 |
| Unselected tile | A visible card: `background:#fffaf1; border:1.5px solid rgba(74,59,46,.2); border-radius:14px; padding:11px 6px` | `color: null`, `border: null` — fully transparent with no outline; only radius 11 and padding 8/8 | high | proto `:1554` / `mood_picker_grid.dart:64-76` |
| Selected tile | `background:#fff5ea; border:2px solid #c76a54` (up from 1.5); `border-radius:14px; box-shadow:2px 2px 0 rgba(199,106,84,.3)` | `color: Palette.panelCoralTint 0x12C76A54` (7% coral wash, not `#fff5ea`); `Border.all(Palette.coral, width: 1.5)` — the prototype's **unselected** width; radius 11; **no shadow** | medium | proto `:1553` / `mood_picker_grid.dart:64-74` |
| Tile labels | Two lines: mood name `600 11px 'Instrument Sans'` `#4a3b2e` `margin-top:5px`; flower name `400 9px 'Instrument Sans'` `#a08a70`. Present on desktop, omitted on the phone sheet | `FlowerBloom` + `SizedBox(height: 6)` + a single `Text(mood.label)` in `captionSans`. **CORRECTION**: the parent calls `captionSans` "12 w500"; it is 12 **w400** (R8). The flower name is never rendered although `FlowerKind.label` exists and is correct | high | proto `:444`, `:737` / `mood_picker_grid.dart:77-84`, `:82`; `typography.dart:188-193` |
| Tile glyph | `span 44x44` — the 44-unit viewBox rendered 1:1; `34x34` on the phone sheet | `flowerSize` default **56** | medium | proto `:444`, `:737` / `mood_picker_grid.dart:12` |
| Panel chrome | `width:420px` **fixed**; `background:#f8efe0; border:2px solid #4a3b2e; border-radius:20px; padding:22px; box-shadow:0 20px 50px -16px rgba(50,35,20,.6)` | `StickerCard` surface `cardBright`, border 1.5px (hardcoded, **unreachable** — R1), radius 16, padding 20, shadow `Offset(3,3)` blur 0. Width `ConstrainedBox(maxWidth: 360)`, shrink-wrapping smaller | high | proto `:439` / `mood_picker_sheet.dart:15`, `:26-30`; `sticker_card.dart:13-14`, `:30`; `shadows.dart:132` (`card = hero`) |
| Title | `font:500 21px 'Newsreader',serif; color:#4a3b2e; text-align:center`. Copy `How are you feeling?` matches. Phone: **18px** (R5) | `titleSerif` = Newsreader **24** w600 height 1.2 ink | low | proto `:440`, `:734` / `mood_picker_sheet.dart:14`, `:34`; `typography.dart:27-33` |
| Subtitle | `600 14px 'Caveat',cursive; color:#a08a70; text-align:center; margin-top:1px`, copy `choose today's bloom`. Phone: **12px** (R5) | No subtitle widget exists; no Caveat text appears anywhere in the picker | high | proto `:441`, `:735` / `mood_picker_sheet.dart:31-40` |
| Scrim | `rgba(42,36,29,.28)`; phone sheet `.34` | `Palette.ink.withValues(alpha: 0.32)` = `rgba(74,59,46,.32)` — lighter, warmer, higher opacity; shared by idiom with six other dialogs (R16) | low | proto `:438`, `:731` / `mood_picker.dart:19`. **CORRECTION**: the barrier trio is `:17-19`, not `:16-17` (R17) |
| Entrance | `fn-pop`: opacity 0->1 with `scale(.96)->scale(1)`, `.18s ease-out`. Phone `fn-sheet`: `translateY(100%)->translateY(0)`, `.24s cubic-bezier(.2,.8,.2,1)` — **slide only, no fade, no scale** (R6) | `showGeneralDialog` 220ms, `Curves.easeOutCubic`, fade + scale `0.92 -> 1.0` | low | proto `:24`, `:25`, `:439`, `:732` / `mood_picker.dart:9`, `:20`, `:39-49` |
| Phone form factor | A **bottom sheet**: scrim `align-items:flex-end`; panel `width:100%; border-top:2px solid #4a3b2e` only; `border-radius:22px 22px 0 0; padding:18px 16px 22px; box-shadow:0 -12px 30px -12px rgba(50,35,20,.5)`; a 38x4 grab handle (radius 3, `rgba(74,59,46,.3)`, `margin:0 auto 12px`); tiles compact at `padding:8px 4px` with 34x34 glyphs and **no** second label line | One centred dialog for every form factor. No bottom-sheet layout, no grab handle, no compact tile variant anywhere in the mood feature | medium | proto `:731-737` (**not** `:439`, the desktop panel), `:1553-1554` (`compact` tile padding) / `mood_picker_sheet.dart:25-44` |
| Re-pick confirmation | Picking a mood for a day that already has one opens a confirm first: title `Change today's bloom?` (or `Change this day's bloom?`), message `Set <dayLabel> to <flowerName> · <moodLabel>? Your current bloom will be replaced.`, confirmLabel `Change mood`, `danger:false`. On confirm: `play('pencil')`, set the mood, then toast `Mood planted · <flowerName>` for 1900ms. **CORRECTION**: the on-confirm behaviour is `:1348`, not `:1345`; the toast lifetime is `:1323`; both branches converge on it (R10) | `_changeMood` awaits the picker and writes immediately — no confirmation, no toast, no sound. Only a failure path sets an inline error | medium | proto `:1344-1348`, `:1323` / `mood_banner_for_date.dart:28-49` |

---

## 4. MSP decomposition — Cluster F

**The governing invariant**: merging any MSP must leave the branch's app fully working, and specifically must leave the **mood picker** openable, pickable and dismissible (see §0's STANDING INVARIANT). No MSP may depend on a surface a later MSP creates. Ordering is the strict sequence in §0.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster F is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged** |
| B | Window chrome and nav rail | B1 – B4 | **merged** |
| C | Today centre column | C1 – C7 | **merged** |
| D | Today right rail | D1 – D4 | **merged** |
| E | Flower art | E1 – E4 | **merged** |
| F | Mood picker | F1 – F4 | **YES** |
| G | Capture composers | G1 – G8 | no |
| H | Verification infrastructure | H1 | no |

---

### F1 — Picker panel chrome and copy

**Outcome**: the picker is a wide warm panel floating on a soft drop shadow, with its handwritten subtitle restored.

**Files**: `lib/features/mood/mood_picker_sheet.dart`, `lib/features/mood/mood_picker.dart`

**Depends on**: A1, A2, A3 (all merged).

**Target values** (`:438-441`) — reproduced verbatim from the parent spec:

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

**Every value above verified against the base.** `Palette.cardWarm = 0xFFF8EFE0` (`palette.dart:12`), `Palette.ink = 0xFF4A3B2E` (`:17`), `Shapes.radiusXl = 20` (`shapes.dart:17`), `Shadows.softLift = BoxShadow(0x99322314, Offset(0, 20), 50, -16)` (`shadows.dart:96-103`), `headlineSerif` = Newsreader 21 w500 ink (`typography.dart:35-40`), `subtitleAccent` = Caveat 14 w600 `Palette.muted` = `0xFFA08A70` (`typography.dart:132-137`, `palette.dart:39`). The "from" column is equally verified: `mood_picker_sheet.dart:15` `maxWidth = 360`, `:29` `surface: Palette.cardBright`, `:30` `padding: EdgeInsets.all(20)`, `:34` `titleSerif` (24 w600, `typography.dart:27-33`), and — via `StickerCard`'s defaults — `Shapes.cardBorderRadius` -> `radiusLg 16` and `Shadows.card = hero = BoxShadow(ink20, Offset(3, 3), 0, 0)` (`sticker_card.dart:13-14`, `shapes.dart:16`/`:21`, `shadows.dart:78-85`/`:132`). Entrance: `mood_picker.dart:9` 220ms, `:41` `Curves.easeOutCubic`, `:46` `Tween(0.92 -> 1.0)`.

**Three resolutions bind F1 and are not optional**: R1 (the panel is a local `DecoratedBox`, not a `StickerCard`), R2 (the 420 clamp), R16 (the scrim is an inline literal and only this dialog's changes). R6 fixes the desktop transition as fade + scale at 180ms, so F1's transition builder keeps its shape and retunes two numbers: `_kMoodPickerEntrance` 220 -> 180 and the scale tween `0.92` -> `0.96`. `Curves.easeOut` replaces `Curves.easeOutCubic` to match `:439`'s `ease-out`.

**Structure after F1** — `mood_picker_sheet.dart`:

```
Center
  LayoutBuilder                                        R2
    SizedBox(width: min(maxWidth, constraints.maxWidth))
      DecoratedBox                      R1: cardWarm, 2px ink, radiusXl, softLift
        Padding(all: 22)
          Column(mainAxisSize: min)
            Text(title, headlineSerif, center)
            SizedBox(height: 1)
            Text("choose today's bloom", subtitleAccent, center)
            SizedBox(height: 16)
            MoodPickerGrid(...)
```

**Must not regress** — reproduced verbatim, with corrected anchors:
- N25 — tile button + selected semantics survive. F1 does not open `mood_picker_grid.dart`.
- Scrim dismissal behaviour is already correct — tapping outside closes without selecting, with a semantic barrier label (`mood_picker.dart:16-17` vs `:438`) — and stays. **CORRECTED (R17)**: the anchors are `:17` `barrierDismissible: true`, `:18` `barrierLabel: 'Dismiss mood picker'`, `:19` `barrierColor`. Keep `:17` and `:18` byte-identical; change only `:19`.
- A3 must already have landed; do not reintroduce a non-Material `pageBuilder`. `DialogHost` at `mood_picker.dart:26` stays.
- The three receipts in §0's STANDING INVARIANT stay green **unmodified**. F1 changes no rendered string and no callback.
- `lib/design/widgets/sticker_card.dart` is not opened (R1); its 21 other call sites and `test/design/widgets/sticker_card_test.dart` are untouched.

**Tests this MSP owes**: none. Colour, radius, padding, shadow, width, duration and font-size changes are exempt under §5.2's admission gate, plus one added copy line that changes no code path.

**Acceptance criteria** — reproduced verbatim: the picker is a visibly wider, warmer, thicker-edged panel floating on a soft blurred shadow instead of a narrow near-white card on a hard offset. A handwritten `choose today's bloom` sits under the heading. No yellow underline anywhere. *(The last sentence is a regression check on A3, not new work — see §3.)*

---

### F2 — Picker tile grid

**Outcome**: ten tiles in a tidy 4/4/2 grid, each a visible card naming both mood and flower.

**Files**: `lib/features/mood/mood_picker_grid.dart`

**Depends on**: A1, A2, E1 (merged), F1.

**Target values** — reproduced verbatim from the parent spec:

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

**CORRECTION (R8)**: the current line 1 is `captionSans` 12 **w400**, not w500 (`typography.dart:188-193`). Non-blocking; the target is unaffected.

**Every value above verified against the base.** `Palette.cardBright = 0xFFFFFAF1` (`palette.dart:14`), `Palette.ink20 = 0x334A3B2E` (`:24`), `Palette.cardLight = 0xFFFFF5EA` (`:13`), `Palette.coral = 0xFFC76A54` (`:31`), `Shapes.radiusMd = 14` (`shapes.dart:15`), `Shapes.radiusSm = 11` (`:12`), `Shapes.outlineWidth = 1.5` (`:6`), `Shadows.tileSelected = BoxShadow(Palette.coral30, Offset(2, 2), 0, 0)` with `coral30 = 0x4DC76A54` (`shadows.dart:60-67`, `palette.dart:35`), `caption9Sans` = Instrument Sans 9 w400 muted (`typography.dart:222-227`). Current state: `mood_picker_grid.dart:12` `flowerSize = 56`, `:13-14` spacing 16 / runSpacing 16, `:25-28` the `Wrap`, `:64-74` the selected-only decoration, `:76` padding 8/8, `:80-82` glyph + `SizedBox(height: 6)` + one `Text`.

**Two resolutions bind F2**: R9 (the grid is a `Column` of `Row`s with `Expanded` cells and two fillers) and R7 (line 1 is `caption11Sans.copyWith(color: Palette.ink)`; the token is not recoloured). Line 2 is `caption9Sans` with no `copyWith`. The parameters `spacing` and `runSpacing` both become 10 by default and keep their names.

**Must not regress** — reproduced verbatim: N25 — `Semantics(button: true, selected: …)` per tile stays. The canonical `moodOrder` (happy, love, warm, grateful, hopeful, calm, anxious, tired, sad, angry) is exact against `:1059` and drives the grid order — do not resort.

Verified: `moodOrder` at `lib/domain/mood/mood.dart:36-47` lists exactly those ten in that order, and `mood_picker_grid.dart:30` iterates it. Adding a second `Text` inside the tile adds **no** `Semantics` node, so `mood_picker_grid_test.dart:30-43` (`findsOneWidget` on a selected `Semantics`) stays green **unmodified**. `find.text(mood.label)` still resolves uniquely because mood labels and flower labels are disjoint (§0's STANDING INVARIANT).

Additionally: `lib/features/mood/mood_banner.dart` is **not** opened. Its 54px glyph is C2's (`:35`) and its coral `caption11Sans` pill label (`:110`) is why R7 forbids recolouring the token.

**Tests this MSP owes**: none. Layout, colour, radius, padding, size and font changes are exempt, plus one added label line that changes no code path. Do not add a tile-geometry test — it would be a change-detector on values this document already pins.

**Acceptance criteria** — reproduced verbatim: the picker shows four flowers per row over two full rows plus a two-tile row left-aligned underneath, replacing the 3/3/3/1 centred layout. Every tile has a visible near-white card with a faint outline. The selected tile gains a cream fill, a thicker coral border and a hard coral shadow. Each tile names its mood in dark text and its flower — `Peony`, `Rose` — in a smaller muted line beneath.

---

### F3 — Picker phone bottom-sheet variant

**Outcome**: on a phone the picker slides up from the bottom edge as a sheet.

**Files**: `lib/features/mood/mood_picker.dart`, `lib/features/mood/mood_picker_sheet.dart`, `lib/features/mood/mood_picker_grid.dart`

**Depends on**: F1, F2.

**Target values** (`:731-733` phone sheet, `:1553-1554` compact tile) — reproduced verbatim from the parent spec. The desktop panel at `:439` is **not** the source for this MSP — an earlier draft cited it by mistake.

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

**ADDITION (R5) — five values the parent's block omits, all on `:734-737`:**

```
title          'How are you feeling?' in headlineSerif at 18   proto :734
               (desktop 21)
subtitle       "choose today's bloom" in subtitleAccent at 12  proto :735
               (desktop 14)
grid gap       8                                               proto :736
               (desktop 10)
grid margin-top 14                                             proto :736
               (desktop 16)
tile line 1    mood.label in Instrument Sans 9 w600 Palette.ink, margin-top 4
                                                               proto :737
               (desktop 11 w600, margin-top 5)
surface        #f8efe0 = Palette.cardWarm, same as desktop      proto :732
```

**Every value above verified against the base.** `Shapes.radiusSheet = 22` (`shapes.dart:18`), `Palette.ink30 = 0x4D4A3B2E` (`palette.dart:27`), `Shadows.pickerSheetLift = BoxShadow(0x80322314, Offset(0, -12), 30, -12)` (`shadows.dart:114-121`) — **already exists with zero consumers** (R15). `resolveShellLayout` and `ShellLayout` are exactly at `shell_layout.dart:3` and `:5-9`. `Color(0x572A241D)` appears nowhere in `lib/` and is genuinely new (R16). Radius 3 on the grab handle has no `Shapes` counterpart and is a literal.

**Four resolutions bind F3**: R3 (the phone branch is what runs under `flutter test`), R4 (branch before `showGeneralDialog`; injectable `layout`; widget defaults stay desktop), R5 (the five added values), R6 (slide only, no fade, no scale). R1's `DecoratedBox` is what makes the top-only border and the asymmetric radius expressible.

**Structure after F3** — `mood_picker.dart` resolves once and drives four arguments:

| Argument | Desktop | Phone |
|---|---|---|
| `barrierColor` | `Color(0x472A241D)` | `Color(0x572A241D)` |
| `transitionDuration` | 180ms | 240ms |
| `transitionBuilder` | `FadeTransition` + `ScaleTransition(0.96 -> 1.0)`, `Curves.easeOut` | `SlideTransition(Offset(0, 1) -> Offset.zero)`, `Cubic(0.2, 0.8, 0.2, 1)` |
| `pageBuilder` child | `DialogHost(MoodPickerSheet(...))` centred | `DialogHost(MoodPickerSheet(... sheet variant))` bottom-aligned |

Both branches keep `barrierDismissible: true`, `barrierLabel: 'Dismiss mood picker'` and `DialogHost`.

**Must not regress** — reproduced verbatim: N25. The desktop path from F1/F2 is unchanged — this MSP adds a branch, it does not replace the dialog.

Concretely, and this is the load-bearing half: **the variant parameters on `MoodPickerSheet` and `MoodPickerGrid` must default to the desktop values**, because `test/features/mood/mood_picker_sheet_test.dart` and `test/features/mood/mood_picker_grid_test.dart` pump those widgets directly and pass no variant. If the default flips to phone, those two files silently stop covering the desktop rendering — the suite would stay green while losing the coverage. Under `flutter test` the branch taken through `showMoodPicker` is the phone one (R3), so desktop coverage exists **only** through those two direct pumps.

Also: F3 must not open `lib/app/shell/shell_layout.dart`. It consumes `resolveShellLayout`; it does not change it. `test/app/shell/shell_layout_test.dart` stays green unmodified.

**Tests this MSP owes**: none. A new layout branch built entirely from styling values is exempt under §5.2, and `resolveShellLayout` — the only new logic F3 could test — is already pinned by `test/app/shell/shell_layout_test.dart:9`, `:13`, `:24`. Do **not** add a `TargetPlatformVariant` sweep over the picker; it would be a second home for a behaviour that file already owns (one behaviour, one home).

**Acceptance criteria** — reproduced verbatim: on a phone the picker slides up from the bottom edge with a grab handle at the top, its tiles compact and showing only the mood name. On desktop nothing changes.

**Note on verifying the phone half.** `resolveShellLayout(TargetPlatform.macOS)` is `sidebar`, so the phone sheet **never renders in the macOS build**. The §5.4 macOS pass can only confirm the second half of the criterion ("on desktop nothing changes"); the first half needs an iOS simulator or Android emulator, or a temporary `layout: ShellLayout.bottomBar` at the call site. Both are human steps (§5.4).

---

### F4 — Re-pick confirmation and planted toast

**Outcome**: replacing an existing bloom asks first and confirms after.

**Files**: `lib/features/mood/mood_banner_for_date.dart`, new `test/features/mood/mood_repick_test.dart`; plus the declared, bounded override edit to `test/features/mood/mood_banner_for_date_test.dart` (R12).

**Depends on**: A3 (merged), F1. Ordered last (§0's SERIALIZATION).

**Target behaviour** (`:1345`) — reproduced verbatim from the parent spec:

When a mood is picked for a day that **already has one**, show a confirm dialog before writing:
```
title        'Change today's bloom?'   (or 'Change this day's bloom?' for a past day)
message      'Set {dayLabel} to {flowerName} · {moodLabel}? Your current bloom will be replaced.'
confirmLabel 'Change mood'
danger       false
```
On confirm: play the `pencil` sound cue, write the mood, then toast `Mood planted · {flowerName}`.

Picking a mood for a day with **no** existing mood writes directly with no confirmation, as today.

**CORRECTION (R10)**: `:1345` is the `askConfirm` config only. The on-confirm behaviour is `doPickMood` at **`:1348`**, which **both** branches call — so the cue and the toast fire on every successful write, and only the dialog is gated. The toast's 1900ms lifetime and its restart-on-re-entry rule are at **`:1323`**.

**Six resolutions bind F4**: R10 (both branches get the cue and the toast), R11 (the `Toast` widget from local state, 1900ms, timer cancelled in `dispose`), R12 (the two provider overrides, and assert through the real `GatedSoundService`), R13 (a private dialog inside the file), R14 (`{dayLabel}` and the title variants via `todayDateProvider`), R20 (zero N24 exposure).

**Control flow after F4** — `_changeMood` becomes:

```
chosen = await showMoodPicker(context, selected: current)
if (chosen == null || !mounted) return
if (current != null) {
  confirmed = await _confirmMoodChange(chosen)     R13
  if (!confirmed || !mounted) return               no write, no cue, no toast
}
try {
  await ref.read(soundServiceProvider).play(SoundCue.pencil)    N20, R10
  await ref.read(journalRepositoryProvider).setMoodForDate(...)
  if (!mounted) return
  setState(() { _writeError = null; _toastMessage = 'Mood planted · ${chosen.flower.label}'; })
  _restartToastTimer()                             R11
} catch (_) {
  if (!mounted) return
  setState(() => _writeError = "Couldn't save your mood. Please try again.")
}
```

`dispose()` cancels the timer (R11, mandatory). The cue is played before the write so a failed write still respects N20's "swallows playback errors" contract without leaving a half-state; `GatedSoundService.play` never throws (`gated_sound_service.dart:25-29`), so it cannot itself trigger the `catch`.

**Must not regress** — reproduced verbatim: N20 — the `pencil` cue must route through `GatedSoundService` so it respects the Sound effects setting and swallows playback errors. The existing failure path that sets an inline error string on a failed write must survive (`mood_banner_for_date.dart:28-49`).

Verified: `:28-49` is exactly `_changeMood`; the `catch` at `:41-48` and its render at `:73-79` survive byte-identical. N20's receipt is F4's own new test asserting `FakeSoundPlayer.played == ['sounds/pencil.wav']` **through** the real service (R12) — not a stubbed `soundServiceProvider`, which would assert the call and skip the gate.

Additionally:
- `lib/features/mood/mood_banner.dart` is not opened. `MoodBannerForDate` keeps calling `MoodBanner(mood:, promptText:, onChangeMood:)` with the same shape (`mood_banner_for_date.dart:61-65`), so `test/features/mood/mood_banner_test.dart` stays green **unmodified**.
- The two existing cases in `mood_banner_for_date_test.dart` keep every assertion. Only the override lists at `:18-20` and `:49-51` change (R12).
- N24 — zero exposure (R20).

**Tests this MSP owes.** This is a behaviour change and it clears the admission gate. It is the **only** MSP in this cluster authorised to add a test file, per §5.2 and the parent's own table (`:1927`). `test/features/mood/mood_repick_test.dart` contains exactly **three** cases, one per named behaviour in the acceptance criteria:

| # | Case | Asserts |
|---|---|---|
| 1 | the confirm gate blocks the write on cancel | day starts with a mood; pick a different one; tap the cancel button; `fake.moodWrites` is empty, `player.played` is empty, no toast text is found, the original mood still renders |
| 2 | confirming plants the mood | same setup; tap `Change mood`; `fake.moodWrites` holds the one write, `player.played == ['sounds/pencil.wav']`, `find.text('Mood planted · <FlowerKind.label>')` finds one widget |
| 3 | a day with no existing mood skips the dialog | day starts with `mood: null`; pick a mood; the dialog title is never found and the write lands directly |

Every case builds its `ProviderScope` with the three overrides — `journalRepositoryProvider`, `appSettingsProvider`, `soundPlayerProvider` — per R12, and reuses `FakeJournalRepository` / `testDay` from `test/features/mood/support/mood_harness.dart` and `FakeSoundPlayer` from `test/features/sound/support/fake_sound_player.dart`. **Neither support file is modified.** Case 2 must let the 1900ms timer run out or rely on `dispose()` cancelling it; either is fine because the timer is cancelled (R11), but do not `pump(Duration(seconds: 2))` and then assert the toast is gone — that is a second behaviour and it belongs to no acceptance criterion here.

**Acceptance criteria** — reproduced verbatim: re-picking a mood on a day that already has one opens a confirmation naming the new flower and warning that the current bloom will be replaced; cancelling leaves the existing bloom untouched. Confirming plays a cue, writes, and shows a `Mood planted · Peony` toast. **This is a behaviour change and warrants a test** — assert the confirm gate blocks the write on cancel and permits it on confirm, and that the no-existing-mood path skips the dialog.

---

## 5. Verification strategy

### 5.1 What the repo actually has

No golden or screenshot coverage exists. H1 builds it and is **not** dispatched in this run. The automated safety net for Cluster F is the existing widget suite, which for this feature is five files and eleven cases:

| File | Cases | What it actually pins |
|---|---|---|
| `test/features/mood/mood_picker_test.dart` | 2 | Opens, picks, returns; barrier dismissal returns `null` |
| `test/features/mood/mood_picker_sheet_test.dart` | 2 | Title, grid presence, all ten labels; a tap forwards the mood |
| `test/features/mood/mood_picker_grid_test.dart` | 2 | All ten labels, tap reports the mood; exactly one selected `Semantics` |
| `test/features/mood/mood_banner_for_date_test.dart` | 2 | End-to-end write and render; inline error on a failed write |
| `test/features/mood/mood_banner_test.dart` | 3 | The banner's own set/unset rendering — **outside Cluster F's blast radius entirely** |

**Not one of them asserts a colour, a radius, a padding, a shadow, a width, a font size or a layout arrangement.** That is the whole automated net for a cluster whose diff is almost entirely those things. The suite can tell you the picker still opens, still lists ten moods, still returns the tapped one, still writes, and still exposes its semantics. It cannot tell you the panel is 420 wide, warm, or 4 columns. **The manual pass in §5.4 is the primary fidelity check, and no agent can run it.**

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling or layout change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract.

In this cluster that yields exactly **one** MSP with new tests:

| MSP | Test | Why it qualifies |
|---|---|---|
| F4 | New `test/features/mood/mood_repick_test.dart`, three cases fixed in F4's table | Behaviour: a gate that can block a write, a cue that must route through `GatedSoundService`, and a toast. None has any existing coverage |
| F1, F2, F3 | none | Colour, radius, padding, shadow, width, font, layout arrangement, one copy line and one platform branch. All exempt |

This matches the parent spec's own authorised-test table (`:1927`), which lists F4 and no other F-cluster MSP.

Per `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, an MSP MAY retarget an existing assertion that pins a rendering it is mandated to change, and the admission gate does not apply to it. **This cluster needs no retarget**: every existing assertion is on text content, widget type or semantics, and none of those is a rendering Cluster F changes. The one existing-test edit this run makes — R12's two provider overrides — is harness maintenance of the same species: it changes **no assertion**, adds no case and removes none.

**The hard boundary on that permission is N24.** It never touches a `ValueKey`, a Semantics label, or any of the eight files at R20, under any circumstances. Cluster F has zero exposure to those eight files by path disjointness.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **playback suite runs unmodified and passes.** This is N24. In this run it is **background**, not acute — no MSP edits any file in R20's table, confirmed by path disjointness. It still runs before every merge; a diff in that suite from a Cluster F change would itself be the signal that the fence has been breached.
3. **Never run `flutter test integration_test/` as a directory** — `integration_test/capture_save_persist_test.dart` writes into the real journal container. Name the single file if one is ever needed. No MSP in this cluster needs one.
4. Diff-scoped verification during the work; the full suite runs at the cluster boundary and pre-push.

**Predict the test count before running.** Every MSP states its expected total before executing `fullValidationCmd`, and compares afterwards. A mismatch that cannot be explained is a defect, not a rounding error.

Baseline, **measured on this base** (`origin/main` at `e778dd6`, with `git diff origin/main -- lib/ test/` empty): **907 passing, 0 failing, `flutter analyze` clean.**

| MSP | Delta | Expected total | Reason |
|---|---|---|---|
| F1 | **0** | **907** | No test added, removed or retargeted. No existing assertion pins a value F1 changes |
| F2 | **0** | **907** | Same. The added label line adds no `Semantics` node, so the selected-tile count assertion is unchanged |
| F3 | **0** | **907** | Same. Existing tests flip to the phone branch (R3) but every assertion survives it |
| F4 | **+3** | **910** | Three new cases in `mood_repick_test.dart`. The two override edits add no case |

A result above 910 means F4 split a behaviour into more cases than the three the acceptance criteria name — report it rather than absorbing it. A result below 907 at any point means a case was lost.

**CI is not evidence.** Neither GitHub check runs a Dart test: the receipts workflow is node-only and the D6 check has no Dart import grapher. `receiptsPass` / `d6Pass` are never acceptable as proof that this run is green. Run `verify.fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge — verbatim:

```
export PATH="/opt/homebrew/bin:$PATH" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

Run it in the **foreground** with an explicit long timeout. Never background it: a subagent's background shells are swept at teardown, and two earlier attempts on this project were lost that way.

Note that `--delete-conflicting-outputs` is ignored by this repo's `build_runner` version (`W These options have been removed and were ignored`); the build still completes. That warning is expected and is not a failure.

### 5.4 Manual spot-check — REQUIRED, and OWED BY A HUMAN

**No agent can run this pass. It is owed by the human after merge, and it is the only fidelity check this cluster has.**

This is not a policy preference, it is a capability fact. Every surface Cluster F changes sits behind a modal that must be **clicked open** — the picker opens from a banner tap, the confirm dialog opens from a tile tap, the toast appears only after a write. Screenshotting a running app is possible via the engine RPC (`decisions/2026-07-21-vm-rpc-screenshot-for-visual-verification.md`), but **click-driving is not**: that decision records that Accessibility TCC is ungranted and needs a Claude Desktop quit-and-reopen. An agent can therefore photograph the Today screen and nothing else in this cluster. Add to that the standing rule that a visible app requires `flutter run -d macos` and never the standalone binary, which renders a black window (`decisions/2026-07-22-black-window-standalone-binary.md`).

The pass is per-MSP, on macOS via `flutter run -d macos`:

**After F1:**
- The picker is a visibly wider, warmer panel with a thicker edge, floating on a soft blurred shadow rather than a hard offset square.
- `choose today's bloom` sits under the heading in the handwritten face.
- No yellow double underline on any text in the picker (the A3 regression check).
- Narrow the window below ~460 logical px and confirm the panel shrinks with it rather than overflowing (R2).

**After F2:**
- Four flowers per row over two full rows, then a two-tile row **left-aligned** underneath. Not centred, not 3/3/3/1.
- Every tile is a visible near-white card with a faint outline; the selected one is cream with a thicker coral border and a hard coral shadow to its lower right.
- Each tile shows its mood name in dark text and its flower name — `Peony`, `Rose` — smaller and muted beneath.
- The glyphs are visibly smaller than before.

**After F3:**
- **On desktop, nothing changes.** This is the half of F3's acceptance criterion the macOS pass can actually verify.
- The phone sheet needs an iOS simulator or Android emulator, or a temporary `layout: ShellLayout.bottomBar` at the call site. Confirm the sheet rises from the bottom edge, has a grab handle, a top-only border, rounded top corners only, compact tiles with smaller glyphs and **no** flower-name line, and that it **slides** without fading or scaling.

**After F4:**
- On a day that already has a mood, picking a different one opens a confirmation naming the new flower and warning the current bloom will be replaced. Cancel leaves the original bloom in place.
- Confirm plays the pencil cue, writes, and shows `Mood planted · <Flower>` which disappears on its own after about two seconds.
- On a day with no mood, picking one writes immediately with no dialog — and still plays the cue and shows the toast (R10).
- Turn Sound effects off in Settings and confirm the cue is silent while the write and the toast still happen (N20).
- Confirm the inline `Couldn't save your mood` path is still reachable and unchanged.

### 5.5 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation.

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

- **The prototype's toast chrome and placement.** `:453` is a dark ink pill at the bottom centre with a check icon and an `fn-rise` entrance. F4 ships the app's existing light `Toast` widget with the prototype's copy and its 1900ms lifetime (R11). Restyling `lib/design/feedback/toast.dart` would reach two other consumers and is authorised by no MSP in the parent spec.
- **A general transient-notification primitive.** Nothing in the app has one and F4 does not build one; its toast is local state in one widget (R11). If a second consumer ever appears, that is when the primitive is justified.
- **A general confirm-dialog primitive.** Two bespoke confirm dialogs will exist after F4 (`DeleteAllConfirmDialog` and F4's). Two is not three; extracting a shared one is a separate refactor with no shippable outcome (R13).
- **The composer scrims and sheets.** `capture_chooser.dart`, the three composer entry points and both day-detail dialogs keep `Palette.ink.withValues(alpha: 0.32)`. Their prototype values are Cluster G's (R16). `Shadows.chooserSheetLift` stays unconsumed until G4.
- **The Today mood card, the calendar, the garden and the week grid.** Cluster F changes what the picker looks like, never what any other surface renders. `mood_banner.dart` is C2's and is read-only here (R19).
- **Golden / screenshot infrastructure is H1's.** Cluster F does not build it and adds no golden test (§5.2).
- **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model) remain open and touch no MSP in this run.

### 6.2 Explicitly not a task

- **No renames, removals or additions in `lib/design/tokens/**`.** The token layer closed with Cluster A. Every value Cluster F needs already exists (R18); the two scrims are inline literals matching the existing inline idiom (R16).
- **No change to `lib/design/widgets/sticker_card.dart`**, including adding a `border` parameter (R1). 21 call sites, 16 files, plus A4's contract.
- **No change to `lib/design/feedback/toast.dart` or `lib/design/feedback/dialog_host.dart`.** Both are consumed as-is.
- **No edit to `lib/features/mood/mood_banner.dart`.** Read-only for this cluster (R19).
- **No edit to `lib/domain/mood/**`.** `moodOrder`, the `Mood` and `FlowerKind` enum values and their display strings are exact — they drive the grid order, the tile's second line and F4's copy.
- **No edit to `lib/app/shell/shell_layout.dart`.** F3 consumes `resolveShellLayout`; it does not change it (R4).
- **No new dependency of any kind**, and no `showModalBottomSheet`. F3's sheet is `showGeneralDialog` with a bottom alignment and a slide transition, which is what keeps `DialogHost`, the barrier label and the shared dismissal path intact.
- **No promotion of the two scrim values to `Palette`** (R16), and no unification of the seven dialogs' barrier colours.
- **No golden test and no per-tile geometry test.** Change-detectors on values this document already pins.
- **No `flutter run` by an implementing agent.** Visual confirmation is a human step on macOS hardware (§5.4).
- **No deletion or weakening of the playback suite** under any circumstances (N24, R20) — inapplicable in practice to this run, stated for consistency with every prior slice.

### 6.3 Open questions

**No open question in the parent spec is answered or affected by this run.** OQ-3 and OQ-6 remain open and touch no MSP here.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Every prototype line this cluster cites was re-opened while composing this slice, and the parent spec's F-region values are correct where they exist.** `:438`–`:444` (desktop panel, title, subtitle, grid, tile content), `:731`–`:737` (phone sheet), `:1553`–`:1554` (the tile style block, including the `compact` padding ternary), `:24`–`:25` (the `fn-pop` and `fn-sheet` keyframes), `:1044`–`:1056` (the flower names), `:1323` (the toast lifetime) and `:1344`–`:1348` (the re-pick branch) were all read byte-for-byte. **No value the parent quotes for Cluster F is wrong.**

**What the parent gets wrong in this region is omission and mis-citation, and there is a specific pattern to it.** Three kinds:

1. **Omission of values on lines already cited.** F3's block cites `:731-733` and stops, while the sheet's title, subtitle, grid and tile label are restyled on `:734-737` — five values, supplied at R5.
2. **Citation drift, now at five instances.** The parent's §7 documents two corrected regions and three repointed citations; §8 item 8 counts "~20 citations off by one or wrong". This slice adds two more from its own re-reading: `mood_picker.dart:16-17` should be `:17-19` (R17), and F4's `:1345` names only the dialog config while the behaviour it describes is at `:1348` with the toast lifetime at `:1323` (R10).
3. **One factual error about the app**, not the prototype: `captionSans` is w400, not w500 (R8).

**And a fourth kind this slice found that no prior slice met: values that are unreachable through the widget the target is built from.** F1's 2px border cannot be expressed through `StickerCard` at all (R1); F4's toast and cue have no mechanism anywhere in the app (R11, R12). Those are not citation problems — every cited value is correct — they are gaps between a correct target and a codebase that has no way to hold it. **Recon that only verifies citations does not find them.** Both were found by opening the widget the value would have to pass through.

**One environmental fact is load-bearing and was not in any prior slice**: under `flutter test`, `defaultTargetPlatform` is forced to `android` by an assert in the Flutter SDK (R3). Every F3 prediction, and any future platform-branched MSP in this repo, depends on it.

**Rule for implementers:** re-open every cited line — both in the prototype HTML and in the app's own source — before adopting any value, and open the widget the value has to pass through before assuming it can hold it. **If you meet an anchor that does not resolve, or a target the code has no way to express, stop and report. Do not make the call yourself** — that is exactly how the C5 caption and three C7 ladder rows were lost.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
