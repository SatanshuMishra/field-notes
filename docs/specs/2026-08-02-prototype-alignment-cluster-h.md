# Prototype Design Alignment — Cluster H (Verification infrastructure) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **H — Verification infrastructure**
MSPs: **H1, H2, H3, H4** (the parent declares one MSP; §0 decomposes it — R1)
Base: `origin/main` at `dd74688`
Toolchain: Flutter **3.44.8** stable, framework revision **058e0af2c2**, Dart **3.12.2**

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec on matters of fact.** Where this document reproduces parent text, it reproduces it verbatim. Where this document **corrects** the parent, the correction is marked inline with `CORRECTION` and states what the parent said, what the code actually says, and which line proves it. Where this document **adds** a value the parent omitted, it is marked `ADDITION` and carries its own anchor. Where a reader needs material this slice omits — findings §3.1–§3.6, MSPs A1–G8, the excluded-elements table §6.1 — the parent spec on `main` is the authority.

**Clusters A through G are already merged and are this run's base.** Cluster H is the last cluster in the spec and the only one that ships no application code at all: every file it writes is a test file, a golden image, a test-tooling config, or a CI workflow. `lib/` is opened by exactly **zero** MSPs in this run — and that fact is itself a fence (see HARD SCOPE FENCE).

**Base SHA, re-read first-hand.** `git fetch origin && git rev-parse origin/main` returns **`dd74688db49ae051bba373254334ef7736c79093`** (`feat(video): add pause/resume, discard and save circles, and the fourteen-bar voice row (#120)`). Every measurement and every line citation in this document is against `dd74688`. The dispatching session's `HEAD` sat on `msp-cluster-g/g8`, ten commits ahead of `origin/main` and carrying an unpushed ledger commit; **no branch in this run is cut from `HEAD`.** Every branch names its start point explicitly.

### The headline recon result, stated up front

**H1's single blocking unknown is now closed, affirmatively, and it changes nothing about the plan except to unblock it.**

The parent spec's H1 block ends on an explicit unverified: *"the implementer must confirm which side of that behaviour change the installed toolchain sits on before capturing any golden with text in it. This is currently unverified."* It is now verified, empirically, on this base:

- **The installed toolchain is on the POST-change side.** Flutter drives each variable font's `wght` axis from `TextStyle.fontWeight`, and it clamps to each family's own declared `fvar` range. Measured advance widths across the full w100–w900 ladder plateau at exactly Instrument Sans 400–700, Newsreader 200–800, Caveat 400–700 — three different per-family boundaries that synthetic bold cannot produce. A negative control (unresolvable family, falling back to FlutterTest/Ahem) returned a flat 928.0 px at all nine weights, proving the probe can report a genuine null. **Text-bearing goldens can be captured safely. H1 may proceed.**

Four further findings reshape the run, and none of them is discoverable from the parent spec:

- **`test/flutter_test_config.dart` already exists and already satisfies determinism requirement #1 in full.** The parent lists it as a **new** file. It is 30 lines at `dd74688`, registers all three vendored variable families through `FontLoader`, and 918 currently-green tests depend on it. **H1 owes nothing here and must not touch it** (R2, deleted row 1).
- **CI runs no Dart at all.** `.github/workflows/receipts.yml` is 32 lines with no Flutter setup, no `pub get`, no `flutter test`, no `flutter analyze`; `scripts/d6-check.cjs` is JS/TS-only by regex construction and can never match a `.dart` path. The 918-test suite has never executed on a GitHub runner. **A golden job is a new CI surface, not an addition to an existing pipeline** (R12).
- **No Flutter version pin exists anywhere in the repo.** No `.fvmrc`, no `.fvm/`, no tool-versions file, no version field in any workflow. `pubspec.yaml:22` pins `sdk: ^3.12.2`, which is the **Dart** constraint and does not constrain Flutter at all. A contributor on Flutter 3.40 satisfies that constraint, sits on the pre-change side, and gets mass golden failures with no local diff to explain them (R14).
- **The spec's ten-flower set leaves more than half of `FlowerPainter` with zero pixel coverage.** All ten non-ambient kinds route through the single part-list branch. The two ambient kinds — `wiltingRose`, `thistle` — are the *only* entry points into `_paintProcedural` and its four style branches (`flower_painter.dart:42-61`, `:88`, `:125`, `:151`, `:172`). Capturing only ten is not "two missing pictures"; it is a whole painter half unguarded (R21).

**Thirty resolutions are decided in this section.** No implementer should ever meet one of them mid-flight.

This matters because of this project's own history: the C5 caption and three C7 ladder rows were lost precisely because an implementer met an unreachable anchor or a stale target value while executing and made a judgement call instead of stopping. **For a golden suite the failure mode is worse than a lost row.** A golden captured against a collapsed `SizedBox`, a font that silently fell back to Ahem, or a weight outside its `fvar` range passes forever and asserts nothing. A suite that cannot fail is worse than no suite, because it manufactures confidence. Every resolution below exists to keep that from happening.

---

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Thirty decisions. Each states the problem, the chosen resolution, and what was rejected and why.

#### Cross-cutting — the shape of the run

**R1 — H1 decomposes into FOUR stacked MSPs, not one and not three. The family-to-MSP map is set by text-bearingness, and by nothing else.**

*Problem.* The parent declares a single MSP that ships a harness, a CI job, an SDK pin and 22 golden captures at once. That is one reviewable change of roughly the wrong size, and it couples the only genuinely risky part of the work — text metrics — to the harness that everything else depends on. If the text-bearing goldens turn out to be unstable, the whole MSP reverts and the harness goes with it.

*Resolution.* Four MSPs, one linear stack, each independently green and strictly additive:

| MSP | Ships | Goldens | Text-bearing? |
|---|---|---|---|
| **H1** | the harness, the tag, the CI job, the pin, the fallback guard, plus `cross_hatch_{photo,video,viewport}` as the harness's own proof | 3 | no |
| **H2** | the bloom set at 44px | 12 | no |
| **H3** | `sticker_card_{default,rotated}` and `nav_icon_{home,calendar,garden,search}` | 6 | no |
| **H4** | `sticker_button_{primary,secondary,danger}` | 3 | **yes — all three** |

Cross-hatch is the first golden family because it is a text-free `CustomPainter` with the simplest geometry in the set: two colours and two band metrics (`cross_hatch_placeholder.dart:25-46`). A failure there is a harness failure and cannot be anything else.

*Deviation from the dispatched three-MSP shape, declared.* The dispatch proposed H3 as `sticker_card_* + sticker_button_* + nav_icon_*` on the stated reasoning that this "isolates font risk to the top of the stack, where it can be dropped without losing the harness". **Recon shows two of those three families are text-free**, which means the three-MSP shape does not isolate anything:

- `NavIcon` is a pure `CustomPainter` over four hand-built `Path`s (`nav_icons.dart:68-114`). It contains no `Text`, reads no `TextStyle`, and cannot be affected by a font.
- `StickerCard` renders no text of its own. Its only required parameter is `child` (`sticker_card.dart:10`), and R24 resolves that child to a text-free `SizedBox` — so it is text-free by construction, not by accident.
- `StickerButton` is the only widget in the whole target set that lays out a glyph run: `Text(label, style: (labelStyle ?? TypographyTokens.buttonSans)…)` at `sticker_button.dart:64-68`.

Splitting them keeps the dispatch's stated *goal* exactly, at the cost of one extra MSP: **H4 is the only MSP in this cluster whose goldens can be invalidated by an SDK bump, and it is the only one that can be dropped or reverted without losing a single text-free capture.** Each MSP also lands in the 3–12 golden range, which is a reviewable image diff; a 21-image diff is not.

*Rejected: fold `nav_icon_*` and `sticker_card_*` into H2 to keep three MSPs.* It preserves the MSP count and the isolation property, but produces an 18-golden H2 spanning three unrelated widget families, reviewed as one diff. Count is not the constraint; reviewability and drop-safety are.

*Rejected: keep the parent's single H1.* One MSP, 21 goldens, a new CI surface, a pubspec edit and an SDK pin in a single diff, with the highest-risk family welded to the foundation.

---

**R2 — `test/flutter_test_config.dart` is NOT opened by any MSP in this cluster. It already satisfies determinism requirement #1 in full.**

*Problem.* The parent's H1 Files list opens with **"new `test/flutter_test_config.dart`"**. The file is not new. At `dd74688` it is 30 lines: `_fontFamilies` (`:7-14`) declares `'Newsreader'` with both `Newsreader-Variable.ttf` and `Newsreader-Italic-Variable.ttf`, `'Instrument Sans'` with `InstrumentSans-Variable.ttf`, and `'Caveat'` with `Caveat-Variable.ttf`; `testExecutable` (`:16-30`) calls `TestWidgetsFlutterBinding.ensureInitialized()`, builds a `FontLoader` per family and awaits `load()` before delegating to `testMain`. The family names match `pubspec.yaml:91-102` exactly, and `test/design/tokens/pubspec_fonts_test.dart` already pins that registration.

*Resolution.* **Read-only, in every MSP.** This file is the config for the entire `test/` tree; 918 currently-green tests depend on it. Editing `testExecutable` to add a `goldenFileComparator` override or an `autoUpdateGoldenFiles` guard puts all 918 at risk for the benefit of 21. Anything golden-specific goes in the new helper at R3, imported only by the golden tests.

*Provenance, CORRECTED.* The dispatch attributes this file to commit `24bd746` (`chore(test): load the vendored fonts for the whole test suite`). That commit exists and its content is byte-identical to `HEAD`'s, **but it is not an ancestor of `HEAD`** — it was squash-merged. The file's actual history on `main` is the single commit **`38c2826`** (`fix(settings): stop the sync section overflowing at phone width (#70)`), confirmed by `git log --oneline -1 -- test/flutter_test_config.dart` on this base. Cite `38c2826`.

*Two fragilities recorded, not fixed here.*
1. Fonts are read as `File('assets/fonts/…')` (`:22`) — a path relative to the **process CWD**, not an asset-bundle lookup, and not wrapped in `try`/`catch`. **Any `flutter test` invocation, local or CI, must run from the repo root.** From a subdirectory it throws a `FileSystemException` inside `testExecutable` and fails all 918 tests with an error that reads nothing like a font problem. R12's workflow runs from the repo root for exactly this reason.
2. There is no guard against silent fallback. R11 adds one, as a separate test file.

---

**R3 — The golden pump helper is a NEW file that WRAPS `stickerHarness`. It does not replace it, and the two existing harnesses are not refactored into one.**

*Problem.* `test/design/widgets/widget_harness.dart` is 14 lines and exports one function, `stickerHarness(Widget child)` (`:3`), returning `Directionality(ltr) > MediaQuery(const MediaQueryData()) > Align(topLeft) > child`. It supplies three things the goldens need and none of them by accident:

| What it gives | Why goldens need it |
|---|---|
| `const MediaQueryData()` → `devicePixelRatio` 1.0 | the integer-DPR requirement, free (R6 pins it explicitly anyway) |
| `const MediaQueryData()` → `textScaler` `TextScaler.noScaling` | removes accessibility scaling as a variable |
| no `MaterialApp`, no `Theme`, no `ProviderScope` | nothing injects a surface colour or a default text theme into the capture |

None of the five target widgets reads `Theme.of(context)` or any inherited widget beyond `Directionality`/`MediaQuery`/`DefaultTextStyle` — verified by reading all five files. Every colour comes from the `const` `Palette`/`Shapes`/`Shadows`/`TypographyTokens` tokens.

What it does **not** give: a `RepaintBoundary`, explicit sizing, or padding.

*Resolution.* H1 creates `test/design/goldens/golden_harness.dart`, roughly ten lines, exporting one function that wraps `stickerHarness` and adds the boundary:

```dart
Widget goldenHarness(Widget subject, {EdgeInsets padding = EdgeInsets.zero}) {
  return stickerHarness(
    RepaintBoundary(child: Padding(padding: padding, child: subject)),
  );
}
```

It is imported across directories as `'../widgets/widget_harness.dart'`.

*Rejected: a third local copy of the harness function.* The repo's existing convention **is** a per-directory copy — `test/design/feedback/harness.dart:3` holds a byte-identical `feedbackHarness`. A third copy would be consistent with that convention and would avoid the cross-directory import. It is rejected because the golden helper is not a copy of `stickerHarness`; it is a strict extension of it, and a copy would let the two drift on the one property (DPR, text scaling) the goldens depend on.

*Rejected: refactor `stickerHarness` and `feedbackHarness` into one shared file.* That edits tests outside the golden scope for no shippable outcome, and it is precisely the kind of drive-by that N24's fence exists to prevent. **Out of bounds in this cluster.**

---

**R4 — Directory layout: test files in `test/design/goldens/`, PNGs in `test/design/goldens/images/`. `matchesGoldenFile` resolves relative to the TEST FILE's directory.**

*Problem.* `matchesGoldenFile(key)` resolves a `String` key as a URI **relative to the directory containing the test file**, via `goldenFileComparator.basedir`. Get this wrong and the first `--update-goldens` writes PNGs into an unintended directory that then compares clean forever.

*Resolution.* One flat golden directory holding four test files, one helper, one guard, and one image subdirectory:

```
test/design/goldens/
  golden_harness.dart               R3 — the pump helper (no tests)
  font_loading_test.dart            R11 — the anti-fallback guard
  cross_hatch_golden_test.dart      H1
  flower_golden_test.dart           H2
  sticker_card_golden_test.dart     H3
  nav_icon_golden_test.dart         H3
  sticker_button_golden_test.dart   H4
  images/
    cross_hatch_photo.png
    …
```

Every call is therefore `await expectLater(find.byType(RepaintBoundary), matchesGoldenFile('images/<name>.png'))`, and `test/design/goldens/cross_hatch_golden_test.dart` resolves that to `test/design/goldens/images/cross_hatch_photo.png`.

*Rejected: `matchesGoldenFile('goldens/<name>.png')` under `test/design/goldens/`.* The conventional Flutter subdirectory name, which here produces `test/design/goldens/goldens/`. Rejected on legibility alone.

*Rejected: PNGs alongside the test files with no subdirectory.* Seven Dart files and 21 PNGs in one flat listing; the images subdirectory keeps the diff and the directory readable.

---

**R5 — Golden filenames are snake_case, and the `FlowerKind` slug comes from an EXPLICIT map, never from `.name`.**

*Problem.* Two `FlowerKind` values are camelCase in the enum — `bleedingHeart` (`flower_kind.dart:10`) and `redSpiderLily` (`:11`). `kind.name` yields `bleedingHeart`, which would produce `flower_bleedingHeart.png` sitting beside `flower_peony.png`. Worse, deriving the filename from `.name` means a future enum rename silently orphans a golden: the test regenerates under a new filename, the old PNG stays on disk, and nothing is red.

*Resolution.* All golden filenames are lowercase snake_case: `flower_bleeding_heart.png`, `flower_red_spider_lily.png`. The mapping is an explicit `const` list of `(FlowerKind, String)` pairs declared in `flower_golden_test.dart`, so a rename produces a compile-time change in a reviewable place rather than a silent file orphan.

*Rejected: `kind.name` with a runtime camelCase-to-snake_case conversion.* A derivation with no reviewer-visible surface, solving a problem twelve literal strings solve outright.

---

**R6 — Device pixel ratio is pinned EXPLICITLY to 1.0, and the surface to 800x600 logical, with a tear-down reset. Inheriting the default is not acceptable.**

*Problem.* The parent is explicit: *"Capture goldens at integer DPR."* `RenderRepaintBoundary.toImage` currently defaults to `pixelRatio: 1.0`, and `const MediaQueryData()` reports `devicePixelRatio` 1.0 — so the requirement is satisfied today by two independent defaults, neither of which this repo controls and neither of which is written down anywhere. `tester.view.devicePixelRatio` meanwhile defaults to **3.0** under `flutter_test`, so the three values do not even agree with each other. A requirement satisfied only by defaults is a requirement that silently unsatisfies itself on an SDK bump.

*Resolution.* The golden helper's `setUp` pins both, and registers the reset:

```dart
tester.view.physicalSize = const Size(800, 600);
tester.view.devicePixelRatio = 1.0;
addTearDown(tester.view.reset);
```

800x600 logical at DPR 1.0 is the `flutter_test` default logical surface, so no existing expectation changes; every golden subject is at most 136x80 logical and self-sizes under `Align(topLeft)`, so the surface is never the binding constraint. The `addTearDown` is not hygiene: `tester.view` mutations leak across tests in the same file, and a leaked DPR would make a later golden capture at a different scale than the one it was recorded at.

**The fractional-DPR limitation is documented, NOT worked around.** At fractional device pixel ratios — routine on desktop at 125%/150% scaling, or on a non-Retina external monitor — a 1.5 logical-px border (`Shapes.outlineWidth = 1.5`, `shapes.dart:6`) or a 1.5px shadow offset (`Shadows.control`, `shadows.dart:36`) lands on a non-integer physical boundary and antialiases into a soft grey line instead of a crisp hairline. This is architectural in Flutter, not a defect in this app ([flutter/flutter#59798](https://github.com/flutter/flutter/issues/59798), [flutter/flutter#117355](https://github.com/flutter/flutter/issues/117355)). **No in-app pixel-snapping workaround is in scope for this cluster, or for this spec.** Capturing at DPR 1.0 sidesteps it for the goldens and for nothing else.

---

**R7 — Exactly one `pumpWidget` per golden. `pumpAndSettle` is FORBIDDEN in this cluster.**

*Problem.* `pumpAndSettle` is the reflex, and here it is both unnecessary and actively harmful: on a widget carrying a repeating animation it does not settle, it times out, and the failure names a timeout rather than the thing that is wrong.

*Resolution.* Every golden test is a single `await tester.pumpWidget(goldenHarness(subject))` followed directly by `expectLater`. No `pump(Duration)`, no `pumpAndSettle`.

*This is not a stylistic preference; it is a determinism proof obligation.* Nothing in the target set animates or varies by run, and each MSP re-confirms this for its own family before capturing: no `AnimationController`, no `Ticker`, no `Random`, no `DateTime.now` anywhere in the widget or the painters it reaches. All five targets are `StatelessWidget` with `const` constructors over `const` tokens. **If a future golden subject does animate, it must be driven to a single named, pinned frame with an explicit `pump(Duration)` — never settled**, because "whatever frame the settle happened to stop on" is not a value a golden may encode.

---

**R8 — Every golden subject gets an explicit `RepaintBoundary`, and the rotated card's boundary is PADDED. A tight boundary silently crops the thing the golden exists to guard.**

*Problem.* `matchesGoldenFile` on a finder captures the nearest enclosing `RenderRepaintBoundary`; without an explicit one it walks up to whatever boundary the harness happens to provide, which is not a stable capture region. Separately, `Transform.rotate` (`sticker_card.dart:44`) does **not** enlarge the layout box. A tight boundary around a rotated card crops exactly the displaced corners — which are the only pixels that differ from the unrotated capture.

*Resolution.* `goldenHarness` always inserts a `RepaintBoundary` (R3), and the finder is always `find.byType(RepaintBoundary)`. `sticker_card_rotated` and `sticker_card_default` both pass `padding: EdgeInsets.all(8)` so the pair differs by the tilt alone (R25). The repo's own precedent for an explicit boundary is `test/design/widgets/cross_hatch_placeholder_test.dart:30-43`, which wraps its pixel probe the same way before calling `boundary.toImage()`.

---

**R9 — Golden tests carry `@Tags(<String>['golden'])`, and H1 creates a root `dart_test.yaml` that DECLARES the tag WITHOUT excluding it by default.**

*Problem.* The golden job needs to run the goldens and nothing else, which needs a selector. There is no `dart_test.yaml` in this repo and no `/verify-<project>` command (`.claude/commands/` does not exist), so no selector exists. Separately, `package:test` emits a warning for tags used but not declared in `dart_test.yaml`, which would add noise to all 918 tests' output.

*Resolution.* Each golden test file opens with the library-level annotation, above the imports:

```dart
@Tags(<String>['golden'])
library;
```

and H1 adds a root `dart_test.yaml` whose entire content declares the tag and nothing else:

```yaml
tags:
  golden:
```

**No `skip`, no default exclusion, no timeout override.** The declaration exists to make `--tags golden` a first-class selector and to silence the undeclared-tag warning. `@Tags` is a tooling directive, not a comment, and is permitted under the standard carve-out.

*The consequence is deliberate: `flutter test` with no arguments — the local `fullValidationCmd` — RUNS the goldens.* The local macOS gate stays the primary gate for this cluster and every future one (R12). A contributor who cannot run them opts out explicitly with `flutter test --exclude-tags golden`, which is a visible choice rather than a silent default.

*Rejected: `tags: {golden: {skip: "run explicitly"}}`.* It would make the goldens invisible to the only gate on this project that actually runs Dart, leaving them enforced by CI alone on a path-filtered job. That inverts the project's own "CI is not evidence" rule.

---

**R10 — `.gitignore` gains `test/design/goldens/failures/`. A perturbation receipt must never be committable.**

*Problem.* A failed `matchesGoldenFile` writes four PNGs per failure into a `failures/` directory beside the golden — `<name>_masterImage.png`, `_testImage.png`, `_isolatedDiff.png`, `_maskedDiff.png`. Every perturbation receipt in this cluster (R17) produces them deliberately. Untracked, they show up in `git status` at exactly the moment the implementer is verifying that the perturbation was fully reverted, which is the moment a stray `git add -A` does the most damage.

*Resolution.* H1 appends one line to the existing `.gitignore` (present at the repo root, 730 bytes at `dd74688`):

```
test/design/goldens/failures/
```

Then the revert check in R17 — `git status --porcelain` clean, `git diff --stat <file>` empty — is a real signal rather than one perpetually polluted by expected artifacts.

---

**R11 — H1 adds ONE anti-fallback guard test. Its predicate is derived from a measured Ahem advance, not from a guess.**

*Problem.* `flutter_test_config.dart` has no guard against silent fallback (R2). If a family ever fails to register — a renamed `.ttf`, a subset re-export, a `flutter test` invoked from a subdirectory — text falls back to the FlutterTest/Ahem font and **every text-bearing golden regenerates uniformly wrong but internally self-consistent**. Nothing is red. This is the exact "suite that cannot fail" failure this cluster exists to prevent.

*Resolution.* `test/design/goldens/font_loading_test.dart`, one case, tagged `golden` so it runs in both the local gate and the CI job. It lays out a fixed string with a `TextPainter` under `'Instrument Sans'` at a fixed `fontSize` and asserts the measured width is **not** the Ahem advance.

The predicate is exact, not approximate. Ahem glyphs are square: its advance is `fontSize` per character. The toolchain gate measured this first-hand — an unresolvable family fell back to a flat **928.0 px** for a 29-character string at `fontSize: 32`, and `29 × 32 = 928` exactly, at every one of nine weights. So:

```dart
expect(painter.width, isNot(closeTo(probe.length * fontSize, 0.01)));
```

A real Instrument Sans render of the same string is 472.0 px at w400 and 488.41608 px at w700 — nowhere near 928.0, and the assertion has margin in the hundreds of pixels.

*Why this qualifies under the test admission gate.* It defines the public contract of a new mechanism (the golden harness's font guarantee) and no existing test covers it — `pubspec_fonts_test.dart` asserts the pubspec *declaration*, which is a different claim from "the font loaded into the test binding". One case, at the lowest layer that can express the behaviour.

*Rejected: assert a specific expected width.* A change-detector that reds on any legitimate font update, which is the opposite of what this guard is for. The Ahem predicate reds only when the font is genuinely missing.

---

**R12 — The CI resolution: ONE golden job, `macos-latest`, pinned to Flutter `3.44.8` stable, path-filtered, running `--tags golden` from the repo root. The local `fullValidationCmd` remains the primary gate.**

*Problem, and it is the largest decision in this cluster.* Determinism requirement #2 is non-optional in the parent — *"CI pins one OS and one Flutter SDK version for the golden job"* — and the acceptance criterion is that *"`flutter test` produces a golden job that passes on the pinned CI configuration."* But this repo's CI runs **zero Dart** and runs on `ubuntu-latest`, while every gate on this project is local macOS. There is no Flutter pipeline to extend.

*The OS constraint is hard and forces the runner.* Flutter's default comparator is `LocalFileComparator`, an exact-pixel comparison at zero tolerance. macOS and Linux differ in Skia rasterization and in font hinting; byte-identical PNGs across the two are not achievable. This is the case the parent quotes directly. It bites the H4 text goldens hardest, but it also reaches the antialiased strokes everywhere else: `NavIcon` at scale 0.75, the 0.8–1.8px bloom strokes, the 1.5px `Shapes.outline`, the 1.5px `Shadows.control` offset.

*Three options were weighed:*

| Option | What it buys | What it costs | Verdict |
|---|---|---|---|
| **(a)** capture on macOS, run the job on `macos-latest`, pinned | matches the developer host and every visual pass on record; zero regeneration churn | GitHub-hosted macOS bills at a **10x** minute multiplier; a cold Flutter setup + `build_runner` + a 21-golden suite is realistically 6–12 min wall clock, so **~60–120 billable minutes per run** | **CHOSEN** |
| **(b)** capture inside a pinned Linux container locally, run on `ubuntu-latest` at 1x | cheapest CI | every contributor must regenerate through the container; a real workflow tax on the one operation that must not be got wrong | rejected |
| **(c)** no CI job; the local gate is the only enforcement | free | **fails H1's acceptance criterion outright** — "passes on the pinned CI configuration" has no configuration to pass on | rejected |

*Resolution — option (a).* H1 adds `.github/workflows/goldens.yml`, a second workflow beside `receipts.yml`, never a modification of it:

- runner `macos-latest`;
- `subosito/flutter-action@v2` with `flutter-version: 3.44.8`, `channel: stable`, `cache: true` — **an exact version string, never a floating channel alone**;
- `flutter pub get`, then `dart run build_runner build` (drift and riverpod codegen; the suite does not compile without it), then `flutter test --tags golden`;
- **run from the repo root**, which R2's relative-path font loading makes mandatory;
- `actions/upload-artifact` with `if: failure()` for `test/design/goldens/failures/**`, which is what makes determinism requirement #3's "reviewed as a visual diff" physically possible on a red job;
- a `paths:` filter on `lib/design/**`, `test/design/goldens/**`, `assets/fonts/**`, `pubspec.yaml`, `.github/workflows/goldens.yml`, so the 10x runner does not fire on unrelated PRs.

The YAML carries **no comments**, per the standing rule.

*What this protects against, stated exactly:* a pixel regression in any design leaf, on any PR that touches `lib/design/**` or the golden set or the fonts, caught on a machine whose OS and SDK are pinned, with the visual diff downloadable from the failed run.

*What it does NOT protect against, stated just as exactly:*
1. **A design-leaf regression reached through a path outside the filter.** Every token lives under `lib/design/`, so the filter covers the realistic cases — but a `pubspec.yaml` font-asset change is covered only because `pubspec.yaml` is listed, and a *transitive* change (a new `flutter_lints` rule that rewrites a painter) is not. The local full gate is the backstop.
2. **A blind regeneration.** Nothing mechanical distinguishes "regenerated because the design changed" from "regenerated to make a red job green". Only R16's review discipline does.
3. **A contributor on the wrong local Flutter.** CI catches it at PR time, not at edit time. R14 narrows that window; it does not close it.
4. **Anything outside `lib/design/**`.** This job is not a test suite. The 918-test suite still runs only on the developer's macOS host, and that has not changed.

**CI IS STILL NOT EVIDENCE.** This job proves one thing on one path. `receiptsPass` and `d6Pass` prove nothing about the Dart suite and never will. Before every merge in this run, `fullValidationCmd` runs locally, in the foreground, against the PR head.

---

**R13 — No golden package is added. Raw `matchesGoldenFile`, and `dev_dependencies` does not grow.**

`pubspec.yaml:60-75` carries `flutter_test`, `integration_test`, `flutter_lints`, `path_provider_platform_interface`, `drift_dev`, `riverpod_generator`, `build_runner` — no `golden_toolkit`, no `alchemist`. Adding one would buy device-frame presets and multi-scenario grids this cluster does not want: **a grid golden fails as one image**, so a single-widget regression forces a whole-grid re-review, which is the opposite of R1's per-family reviewability. It would also add an unpinned third-party dependency to the one mechanism whose entire value is determinism. `matchesGoldenFile` plus R3's ten-line helper covers the whole target set.

---

**R14 — `pubspec.yaml` gains `environment: flutter: '>=3.41.0'`. This is the ONLY `pubspec.yaml` edit in the cluster, and the only pin that is enforced on a developer's machine.**

*Problem.* `pubspec.yaml:21-22` is `environment: sdk: ^3.12.2` — the **Dart** constraint. It does not constrain Flutter at all. A contributor on Flutter 3.40 satisfies it exactly, sits on the pre-`font-weight-variation` side, renders every `TypographyTokens` weight from the single default face, and gets mass golden failures with no local diff to explain them. The CI pin in R12 catches this at PR time; nothing catches it at `pub get` time.

*Resolution.* Add the Flutter constraint beside the existing Dart one:

```yaml
environment:
  sdk: ^3.12.2
  flutter: '>=3.41.0'
```

`flutter pub get` validates this and fails resolution below the floor, which converts a silent class of wrong-pixel failure into a loud one at setup.

*Why `>=3.41.0` and not `>=3.44.8`.* 3.41 is the stable release in which `TextStyle.fontWeight` began driving the `wght` axis ([font-weight-variation breaking change](https://docs.flutter.dev/release/breaking-changes/font-weight-variation), implemented in [flutter/flutter#175771](https://github.com/flutter/flutter/pull/175771)). Below it, **the shipped app renders every weight wrong**, not just the goldens — so 3.41 is an app-wide correctness floor and the constraint is honest at that value. Pinning the pubspec to 3.44.8 would block contributors from the entire repository for the benefit of a 21-golden subset; a contributor on 3.42 will still see byte-exact golden drift, and that is what the CI pin and the failure artifact are for. **The constraint is the weakest claim that is actually true.**

*Recorded risk.* `pubspec.yaml` is a historical parallel-conflict hotspot on this project (`decisions/2026-07-19-pubspec-parallel-conflict.md`). Cluster H is a single linear stack with no parallel MSPs, so the hazard does not apply to this run — but H1 owns this edit alone and no later MSP reopens the file.

---

**R15 — The `receipts` enforcer's contract for a test-only PR is confirmed BEFORE the first PR is opened, not after it goes red.**

`.github/workflows/receipts.yml:18` runs `shaheershoaib/receipts/enforcer@main` on every PR, and its contract is not visible in this repository. Every PR in this cluster is subject to it, and every PR in this cluster is **test-only** — `lib/` is untouched by all four MSPs, which is an input shape the enforcer may never have seen here. The ledger records that `pr-title-lint` is not merge-blocking (`.claude/ledger/decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md`) but says nothing about the enforcer. `scripts/d6-check.cjs:10-11` is JS/TS-only by regex (`/\.(test|spec)\.[cm]?[jt]sx?$/`, `/\.[cm]?[jt]sx?$/`) and cannot match a `.dart` path, so the D6 step is a no-op for every MSP here. **Confirm the enforcer's requirement for H1 before opening H1's PR.** Discovering it on a red check after the fact costs a round-trip on every one of four stacked PRs.

---

**R16 — `--update-goldens` regenerates ONLY when the design deliberately changed, and never to turn a red job green.**

Determinism requirement #3 verbatim: *"`--update-goldens` output is reviewed as a visual diff in the PR, never regenerated blind to make a red job green."* The operative protocol:

1. A red golden is **read first**, from `test/design/goldens/failures/<name>_isolatedDiff.png`, or from the CI artifact R12 uploads.
2. If the diff shows a change the PR intended, the golden is regenerated with `flutter test --tags golden --update-goldens` **from the repo root**, and the new PNG is reviewed in the PR as an image diff.
3. If the diff shows anything the PR did not intend, **the code is wrong, not the golden.** Fix the code.
4. If the diff is a uniform soft blur across every text-bearing golden at once, the font fell back or the SDK moved (R11, R30). Regenerating is the wrong response to both.

A regenerated golden without a stated reason in the PR body is a defect on its own terms.

---

**R17 — Each golden-bearing MSP owes a PERTURBATION RECEIPT: an exact edit, an exact expected red set, an exact revert, and a proof of revert. It is never committed.**

*Problem.* H1's acceptance criterion in the parent is that *"deliberately perturbing a shadow offset or a petal count makes it fail with a readable image diff."* Left unspecified, this becomes an assertion in a PR body rather than an observation. And a golden suite that has never been observed to fail is exactly the false-confidence artifact this cluster exists to prevent.

*Resolution.* One perturbation per MSP, each chosen so the expected red set is a **strict subset** of that MSP's goldens. That is the point: a perturbation that reds everything proves the harness runs; a perturbation that reds exactly one golden and leaves its siblings green proves the harness **discriminates**.

| MSP | Exact edit | Expected RED | Expected GREEN, and why that matters |
|---|---|---|---|
| **H1** | `lib/design/widgets/cross_hatch_placeholder.dart:31` — photo `bandPitch: 12` → `13` | `cross_hatch_photo` | `cross_hatch_video`, `cross_hatch_viewport` — proves per-variant isolation, since video shares photo's exact band geometry and differs only in colour |
| **H2** | `lib/design/flowers/bloom_geometry.dart:46` — sunflower `BloomOvalRing(count: 8, …)` → `count: 7` | `flower_sunflower` | the other eleven blooms — this is the parent's own "petal count" case, literally |
| **H3** | `lib/design/icons/nav_icons.dart:36` — `strokeWidth = 2` → `2.5` | `nav_icon_calendar`, `nav_icon_garden`, `nav_icon_search` | `nav_icon_home`, `sticker_card_*` — proves the fill/stroke split, since `home` is the only glyph drawn with `_fill()` (`nav_icons.dart:44`) |
| **H4** | `lib/design/tokens/shadows.dart:54` — `emphasis` `offset: Offset(2, 2)` → `Offset(3, 2)` | `sticker_button_primary` | `_secondary` (shadow `null`, `sticker_button.dart:110`), `_danger` (`Shadows.control`, `:118`) — this is the parent's own "shadow offset" case, and it proves A4's shadow-presence distinction is what the goldens are actually holding |

*The protocol, in full, and it is the same four steps every time:*

1. Make the single-value edit. Run `flutter test --tags golden` from the repo root.
2. **Read the failure output and open `failures/<name>_isolatedDiff.png`.** Confirm the red set matches the table exactly — both that the expected golden failed and that the expected siblings passed. Exit code alone is not the receipt.
3. **Restore the value by editing it back.** Confirm with `git diff --stat <file>` returning empty and `git status --porcelain` clean. **Never `git checkout -- <path>`** as an autonomous step; a revert that discards more than it restored is the failure mode that rule exists for.
4. Re-run `flutter test --tags golden` and confirm green, then run the full `fullValidationCmd`.

The perturbation is **never committed**, and `test/design/goldens/failures/` is gitignored by R10 so step 3's clean-tree check is meaningful. The receipt is recorded in the MSP's PR body as a `--verified` line naming what was perturbed and what went red — a real observation, never a claim.

---

#### H1 — the harness and the cross-hatch proof

**R18 — All three cross-hatch goldens pass EXPLICIT `width` and `height`, and the SAME ones: 120 x 90.**

*Problem, and it is the "golden that asserts nothing" case in its purest form.* `CrossHatchPlaceholder.width` and `.height` both default to `null` (`cross_hatch_placeholder.dart:60-61`). With a null `child`, the `SizedBox` at `:77-79` collapses, `CrossHatchPainter.paint` early-returns on `size.isEmpty` (`:126`), and the golden captures an empty image — **which then compares clean forever.** No test is red. Nothing reports it.

*Resolution.* `width: 120, height: 90` on all three, explicitly, and **identical across the three**. Non-square is required for the 45-degree band rotation (`:135-136`) to be legible; identical is required because the band phase depends on the box (`:138-146` walks `step * bandPitch` from a centre translate), so a size difference would move the stripes for reasons unrelated to geometry. 120x90 is the existing in-repo precedent, at `test/design/widgets/cross_hatch_placeholder_test.dart:13-14`.

---

**R19 — The viewport golden passes `child: null` and KEEPS the default `borderRadius`. It does not mirror production.**

*Problem.* Production passes a `Text` child and `BorderRadius.zero` (`video_recorder_sheet.dart:194-198`). Copying that would put a text run into H1 — the one MSP whose whole purpose is to be text-free — and would change the corner treatment on the one variant that already differs from the other two by having **no outline border** (`cross_hatch_placeholder.dart:88-89`).

*Resolution.* `child: null`, default `borderRadius` (`Shapes.cardBorderRadius`, radius 16). With a null child the `Center` at `:101` wraps nothing and paints nothing, which is the intended text-free capture. Keeping the default radius means the three cross-hatch goldens differ **only** in the two colours and the two band metrics — which is exactly the surface `_geometryFor` (`:25-46`) declares, and exactly what H1's perturbation receipt (R17) exercises.

*Recorded, so it is not rediscovered later:* the photo and video variants share `bandWidth: 6, bandPitch: 12` and differ only in colour (`:27-38`). **Viewport is the only variant with a different band metric** (`bandWidth: 8, bandPitch: 16`, `:39-44`). So the photo/video pair guards the palette and the viewport golden guards the geometry — not, as the parent's one-line table suggests, three interchangeable captures of "the A5 band geometry".

---

**R20 — `background` and `hatchColor` stay null on all three cross-hatch goldens.**

Passing `hatchColor` routes the band through the `Color.alphaBlend(tint.withValues(alpha: 0.5), ground)` branch at `:73-75`, which changes what the golden guards from "the declared variant geometry" to "the blend maths". That blend already has dedicated non-golden coverage at `cross_hatch_placeholder_test.dart:172-199`, asserting the blended luminance sits between the two inputs — a better test for that behaviour than a picture would be. One behaviour, one home.

---

#### H2 — the bloom goldens

**R21 — The flower set is TWELVE, not ten. ADDITION over the parent's `flower_{kind} x 10`, and the reason is a painter half, not two pictures.**

*Which ten the parent means is exact, not a judgement call.* `FlowerKind` declares twelve values (`flower_kind.dart:1-19`). Exactly two carry `ambientOnly: true` — `wiltingRose` (`:12`) and `thistle` (`:13`). The remaining ten are precisely the ten reachable from the mood picker: `Mood` has ten values, each mapping 1:1 onto one of them (`mood.dart:5-16`), with `test/domain/mood/mood_test.dart:48` already asserting every `Mood`'s flower is non-ambient.

*The gap the parent's ten leaves.* All ten non-ambient kinds are `FlowerSpec.parts` (`flower_spec.dart:63-122`), and every one routes through the single part-list branch of `FlowerPainter` (`flower_painter.dart:31-38`, delegating to `BloomPartPainter`). The two ambient kinds are `FlowerSpec.procedural` (`:123-153`) and are **the only entry points into `_paintProcedural`** (`flower_painter.dart:42-61`) and therefore the only exercise of `_paintRadial` (`:88`), `_paintSpider` (`:125`), `_paintSpike` (`:151`) and `_paintPuff` (`:172`) — roughly 150 lines, more than half the painter. Both render real blooms and neither is a no-op: `wiltingRose` is `BloomStyle.roundPetals` with `petalCount: 6` and `droop: true` (`flower_spec.dart:123-138`), `thistle` is `BloomStyle.puff` with `petalCount: 11` (`:139-153`), and `test/design/flowers/flower_bloom_test.dart:46-55` already proves both paint without throwing.

*Resolution.* H2 captures **twelve**: the parent's ten, plus `flower_wilting_rose` and `flower_thistle`, at the same 44px, under the same harness. Cost: two PNGs and two test cases. They are the only thing in the whole cluster that would catch a regression in the procedural bloom path.

*Rejected: ship the parent's ten and note the gap in the PR.* That was the alternative recon flagged, and it is the weaker half of its own recommendation. A noted gap is a gap; two PNGs close it for less than the cost of writing the note.

---

**R22 — `size: 44` is passed EXPLICITLY on all twelve. The constructor default is 48.**

`FlowerBloom.size` defaults to **48** (`flower_bloom.dart:12`), and the parent's table says 44. Forgetting the argument silently captures at 48. 44 is not an arbitrary number: `FlowerPainter.viewBox` is exactly 44 (`flower_painter.dart:15`) and the painter scales by `d / viewBox` (`:25`), so 44 is the scale-1.0 point and the least antialiasing-fragile capture size in the set. It is also a real shipped instance — `garden_view.dart:34` renders at 44.

---

**R23 — The bloom goldens use the bare `goldenHarness`. The existing flower test's `MaterialApp` wrapper is NOT followed.**

`test/design/flowers/flower_bloom_test.dart:7-8` wraps its subject in a `MaterialApp`. That is unnecessary — `FlowerBloom` reads no inherited widget beyond what `Semantics` and `SizedBox.square` need — and for a golden it is actively wrong: `MaterialApp` injects a `Material` surface colour and a default text theme that would both land in the captured pixels. **This is not a change to that file.** It stays exactly as it is; H2 simply does not copy its wrapper.

`SizedBox.square` is built into `FlowerBloom.build` (`flower_bloom.dart:38-39`), so no external sizing is needed. `Semantics(label:)` (`:35`) is metadata and paints nothing.

---

#### H3 — the sticker card and the nav glyphs

**R24 — `StickerCard.child` is a TEXT-FREE `SizedBox(width: 120, height: 64)`. This is the decision that keeps two goldens out of the font-risk class.**

*Problem.* `child` is the only required parameter (`sticker_card.dart:10`) and the parent's table declares no value for it. This single unmade decision determines whether two of the 21 goldens carry the SDK/font-metric risk at all.

*Resolution.* `const SizedBox(width: 120, height: 64)`. With the constructor's other defaults — `padding: EdgeInsets.all(16)`, `surface: Palette.cardWarm`, `borderRadius: Shapes.cardBorderRadius`, `shadow: Shadows.card` — the capture guards exactly what the parent's table says it should: *"fill, 1.5px outline, hard offset shadow, tilt"*. `Shadows.card` aliases `Shadows.hero` (`shadows.dart:141`) = `Palette.ink20` at `Offset(3, 3)`, blur 0 (`:78-85`); the border is `Shapes.outline`, 1.5px `Palette.ink` (`shapes.dart:25-27`), hardcoded in `build` at `sticker_card.dart:30` and not exposed on the constructor.

**Consequence, and it is R1's whole basis:** with this resolution the only text-bearing goldens in the entire cluster are H4's three sticker buttons.

---

**R25 — `sticker_card_rotated` uses `rotationDegrees: -0.5`, and H3 owes a byte-difference receipt proving the tilt golden is not a duplicate of the default one.**

*Problem.* The parent declares no angle. Production tilts are `-0.5` and `+0.4` degrees (`entry_card.dart:24-25`, applied at `:62`), and the existing unit test uses `-0.5` (`sticker_card_test.dart:75`). At -0.5 degrees on a 120x64 card at DPR 1 the two captures are visually near-identical — the corner displacement is under one logical pixel. A golden that matches the default proves nothing about tilt, which is the same failure class as capturing a weight outside a font's `fvar` range.

*Resolution.* Use **-0.5**, the shipped odd-card tilt. A golden's job is to guard pixels that can actually ship; a synthetic 15-degree tilt would guard a rendering that appears nowhere in the app. Both card goldens use `padding: EdgeInsets.all(8)` on the boundary (R8) so the pair differs by the tilt alone.

*And H3 owes the receipt that makes the pair meaningful:* one non-golden case in `sticker_card_golden_test.dart` that pumps both cards, captures both boundaries via `RenderRepaintBoundary.toImage()` → `toByteData(format: ui.ImageByteFormat.rawRgba)`, and asserts the two byte buffers are **not** equal. The repo's precedent for this exact capture pattern is `cross_hatch_placeholder_test.dart:42-48`. The rotated border antialiases where the unrotated one is a crisp 1.5px line, so the buffers differ decisively even at sub-pixel displacement — but the assertion is what proves it, not this paragraph.

*Why this qualifies under the admission gate:* it asserts a contract of the golden pair itself (that the two captures are distinguishable), and no existing test covers it. One case.

---

**R26 — CORRECTION: the golden is `nav_icon_home`, not `nav_icon_today`. `NavGlyph` has no `today` member.**

*Problem.* The parent's table reads `nav_icon_{today,calendar,garden,search}`. The enum is `NavGlyph { home, calendar, garden, search }` (`nav_icons.dart:3`). There is no `NavGlyph.today`. The name comes from `ShellDestination.today`, which maps to `NavGlyph.home` (`shell_destination.dart:6`). **An implementer who trusts the table looks for `NavGlyph.today`, does not find it, and guesses.**

*Resolution.* Name the golden after the **enum**: `nav_icon_home.png`, capturing `NavGlyph.home`.

*Why this and not the parent's name.* Three of the four glyph names — `calendar`, `garden`, `search` — are already enum members, and naming the fourth after a destination would make it the single odd one out in a directory listing whose other three mirror the enum exactly. A future reader who greps `NavGlyph.today` finds nothing, which is the trap restated rather than removed. Naming after the enum makes all four files a direct, uniform mirror of the thing they guard and deletes the trap at its source. A golden guards a widget, not a destination.

*Rejected: keep `nav_icon_today` and pin the mapping in a test comment.* No comments, and a mapping pinned in prose is a mapping that drifts.

---

**R27 — `NavIcon` goldens capture at `size: 18` with `color: Palette.ink`. Both are undeclared by the parent and both are load-bearing.**

*Problem.* `NavIcon.color` is **required with no default** (`nav_icons.dart:9`) and `size` defaults to 18 (`:10`), which the parent's table never states. `size` is not cosmetic: `NavIconPainter.paint` does `canvas.scale(size.shortestSide / viewBox)` with `viewBox = 24` (`:35`, `:41`), so 18 gives scale 0.75 and puts the nominal 2px stroke (`:36`) at 1.5 physical px at DPR 1. **These four are the most antialiasing-fragile goldens in the cluster.**

*Resolution.* `size: 18`, `color: Palette.ink`.

- **18, because that is what ships.** `sidebar_shell.dart:211` renders `NavIcon(glyph: glyph, color: foreground, size: 18)`. Capturing at 24 would give scale 1.0 and crisp edges — and would guard a rendering that exists nowhere in the app, while a regression at the fragile 0.75 scale is exactly the one that could ship. The antialiasing is deterministic on a pinned toolchain, and pinning the toolchain is what R12 and R14 are for.
- **`Palette.ink`, because it is the unselected rail foreground** and it renders. The selected foreground is `Palette.onAccent` (white), which on the harness's transparent background would produce a near-invisible PNG that a reviewer cannot read as a visual diff.

*Recorded caveat, worth eyeballing on the first capture:* `_search()` runs its handle to `(21, 21)` inside a 24 `viewBox` with a 2px round cap (`:111-114`), so at scale 0.75 the cap sits very close to the box edge and can clip. Look at the first `nav_icon_search.png` before accepting it.

---

#### H4 — the text-bearing goldens

**R28 — All three sticker-button goldens use ONE shared label string, with identical everything else. The only permitted pixel delta between them is the variant.**

`sticker_button_secondary` exists to guard exactly one thing the parent names: *"the shadow-presence distinction from A4"* — `secondary`'s `shadow` is `null` (`sticker_button.dart:110`) where `primary`'s is `Shadows.emphasis` (`:102`). That distinction is only legible if the three captures are otherwise identical. A different label per variant would change the advance width and confound the comparison with a text difference.

**And `danger` is not merely a recolour** — it differs from `primary` on three independent axes, which the parent's one-line table hides:

| | primary | secondary | danger |
|---|---|---|---|
| background | `Palette.coral` | `Palette.cardWarm` | `Palette.danger` |
| borderRadius | `radiusControl` 12 | `radiusControl` 12 | **`buttonBorderRadius` = `radiusSm` 11** |
| padding | 13 / 10 | 13 / 10 | **16 / 9** |
| shadow | `emphasis` `Offset(2,2)` | **`null`** | **`control` `Offset(1.5,1.5)`** |

Anchors: `sticker_button.dart:96-119`, `shapes.dart:13-14`, `:22-23`, `shadows.dart:33-40`, `:51-58`.

*Recorded, not chased:* `danger`'s 1.5px shadow offset at DPR 1 lands on a half-pixel boundary and antialiases into a soft edge. That is R6's documented platform limitation, it is deterministic on a pinned toolchain, and it is captured as-is. **Do not chase the soft edge and do not adjust the token.**

---

**R29 — `onPressed` is a non-null callback and `icon` stays null.**

`StickerButton` wraps its content in `Opacity(opacity: isEnabled ? 1.0 : 0.5)` (`sticker_button.dart:43-44`), where `isEnabled` is `onPressed != null` (`:34`). Passing `null` would capture every button at half opacity, guarding the disabled treatment on all three and the enabled treatment on none. Pass a no-op callback. Leave `icon` null — the icon slot inserts a 10px gap (`:16`, `:60-63`) and would put a second widget's pixels inside a golden named for the button. `Row(mainAxisSize: MainAxisSize.min)` (`:58`) means the button self-sizes; no `SizedBox` is needed.

---

**R30 — THE STANDING FONT-WEIGHT CONSTRAINT. H4's three goldens are valid only on a pinned toolchain, and this is the constraint a future SDK bump will violate silently.**

*The verdict, measured first-hand on this base.* Flutter drives each variable font's `wght` axis from `TextStyle.fontWeight` and clamps to that family's declared `fvar` range. Observed advance widths for one fixed 29-character string at `fontSize: 32`, swept across the full w100–w900 ladder:

| Family | Distinct widths across nine weights | Plateau boundaries | Published `fvar` wght range |
|---|---|---|---|
| Instrument Sans | 4 of 9 | w100–w400 flat, w500, w600, w700–w900 flat | **400–700** |
| Newsreader | 7 of 9 | w100/w200 flat, then monotonic, w800/w900 flat | **200–800** |
| Caveat | 4 of 9 | w100–w400 flat, w500, w600, w700–w900 flat | **400–700** |
| *negative control* (unresolvable family → FlutterTest/Ahem) | **1 of 9** — flat 928.0 at every weight | — | not variable |

The decisive detail is not that widths differ but **where they stop differing**: each family plateaus at exactly its own published `fvar` limits. Synthetic bold cannot produce three different per-family boundaries that each coincide with that font's own axis range, and the flat negative control rules out synthetic-bold advance widening as the cause. A positive control (same family and weight at `fontSize` 20 → 295.0 vs 40 → 590.0, exactly 2x) proves the measurement was live. Corroborated documentarily: *"Setting the fontWeight property of objects such as TextStyle will now also set the value of the wght variation axis of fonts that support it"* — [font-weight-variation breaking change](https://docs.flutter.dev/release/breaking-changes/font-weight-variation), landed 3.39.0-0.0.pre, stable in **3.41**. The installed toolchain is **3.44.8**, three stable minors past the cutover. The two evidence lines agree; there is no conflict to flag.

*The consequences, as standing constraints on this cluster and on every future change to it:*

1. **`TypographyTokens.buttonSans` is w600 in Instrument Sans** (`typography.dart:192-197`), and w600 sits **inside** Instrument Sans's 400–700 range. So all three H4 goldens render a genuine variable-axis instance distinct from w400, and they are fully exposed to the pin.
2. **Weights outside a family's range are no-ops.** w100/w200/w300 are all identical to w400 in Instrument Sans and Caveat, and w800/w900 are identical to w700. **A golden that intends to distinguish those weights will pass while asserting nothing.** Any future text-bearing golden must pick a weight inside the target family's real range, or the test is a no-op by construction.
3. **Three things are part of the golden contract and none of them is currently pinned by `pubspec.yaml`:** the Flutter SDK version (R14 sets the floor, R12 sets the exact CI version); the three `.ttf` files at `assets/fonts/`, **byte-for-byte** (a subset, re-export or upstream bump that shifts an `fvar` range silently reflows text); and the `FontLoader` registration at `flutter_test_config.dart:16-30` (R2, R11).
4. **Any SDK downgrade below 3.41 reverts to flat single-face rendering** and reds every H4 golden at once with no local diff to explain it. R11's guard catches the font-missing case; only reading the diff catches this one (R16 step 4).
5. **Skia and engine text-shaping changes shift subpixel metrics across engine revisions**, independent of this specific change. Goldens are engine-sensitive on principle, not only font-sensitive.

*CORRECTION to the dispatch and to the toolchain record.* The dispatch describes *"engine revision 058e0af2c2"*. `flutter --version`, re-run first-hand this session, reports **058e0af2c2 as the FRAMEWORK revision**; the engine revision is **0cd610717b** (hash `13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939`). Both are dated 2026-07-23, so the two adjacent fields were conflated. **Pin the framework revision or the `3.44.8` version string; do not pin `058e0af2c2` as an engine hash.**

---

### ROWS DELETED AS ALREADY SATISFIED

Four items read in the parent spec as work to be done. Each already ships. An implementer who authors one a second time produces a duplicate mechanism or, worse, edits a file 918 tests depend on.

| # | Row, as the parent writes it | Proof it already shipped |
|---|---|---|
| 1 | **"new `test/flutter_test_config.dart`"** in H1's Files list, and determinism requirement #1 (*"loads the three vendored variable fonts via `FontLoader`"*) | The file exists at `dd74688`, 30 lines, and does exactly this: `_fontFamilies` `:7-14` covers all three families including `Newsreader-Italic-Variable.ttf`; `testExecutable` `:16-30` awaits a `FontLoader` per family before `testMain`. Provenance `38c2826`. **Read-only — R2** |
| 2 | the three vendored `.ttf` files and their registration | `assets/fonts/` holds `InstrumentSans-Variable.ttf`, `Newsreader-Variable.ttf`, `Newsreader-Italic-Variable.ttf`, `Caveat-Variable.ttf`, each with its OFL. `pubspec.yaml:91-102` declares them; `test/design/tokens/pubspec_fonts_test.dart` pins that declaration. **Apply, do not author** |
| 3 | a test harness supplying `devicePixelRatio` 1.0 and `TextScaler.noScaling` | `stickerHarness` (`test/design/widgets/widget_harness.dart:3`) already gives both through `const MediaQueryData()`. R3 wraps it; R6 pins the same values explicitly anyway, because a requirement met only by a default is not met |
| 4 | *"Capture goldens at integer DPR"* | `RenderRepaintBoundary.toImage` defaults to `pixelRatio: 1.0` today, so this is satisfied by an SDK default this repo does not control. **Pinned explicitly regardless — R6.** Recorded here so nobody treats the existing behaviour as the mechanism |

**Confirmed absent, first-hand, on this base** — so the cluster's premise holds: `grep -rl "matchesGoldenFile" test/ integration_test/` returns **no matches**; `test/design/goldens/` does not exist; there is no `dart_test.yaml`; there is no `.fvmrc`, no `.fvm/`, no tool-versions file; `dev_dependencies` (`pubspec.yaml:60-75`) carries no golden package.

---

### TOOLCHAIN LEDGER — everything this cluster pins, and where the pin lives

The parent's determinism requirements reduce to a list of things that must not move. Each row names the single place the pin is enforced, and what happens when it is violated.

| Pinned | Value | Enforced at | Symptom if violated |
|---|---|---|---|
| Flutter SDK, exact | `3.44.8` stable | `.github/workflows/goldens.yml` (R12) | CI golden job red; artifact shows uniform subpixel drift |
| Flutter SDK, floor | `>=3.41.0` | `pubspec.yaml` `environment:` (R14) | `flutter pub get` fails at setup — loud, by design |
| Framework revision | `058e0af2c2` (2026-07-23) | recorded here; **not** the engine hash (R30) | wrong hash pinned in a future harness |
| Engine revision | `0cd610717b` / `13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939` | recorded here | subpixel drift independent of the weight change |
| Dart SDK | `^3.12.2` | `pubspec.yaml:22`, already shipped | — |
| Runner OS | `macos-latest` | `.github/workflows/goldens.yml` (R12) | exact-pixel mismatch on every antialiased edge |
| Device pixel ratio | `1.0`, integer | the golden helper's `setUp` (R6) | fractional-DPR softening on 1.5px edges |
| Logical surface | `800 x 600` | the golden helper's `setUp` (R6) | subjects self-size, so silent — which is why it is pinned |
| Font families | three variable `.ttf` files, byte-for-byte | `flutter_test_config.dart` (read-only), guarded by R11 | uniformly wrong, internally consistent goldens |
| Working directory | repo root | R12's workflow; R16's regeneration protocol | `FileSystemException` failing all 918 tests, with a misleading message |
| Comparator | default `LocalFileComparator`, zero tolerance | no override anywhere (R13) | a tolerance wide enough to hide a 1px shadow regression |

**No tolerance-based comparator, under any circumstances.** A tolerance loose enough to absorb cross-OS font rendering is also loose enough to absorb a one-pixel shadow-offset regression, which is the exact defect class this cluster exists to catch. If cross-OS validation is ever wanted, the answer is a second pinned runner, never a looser comparator.

---

### HARD SCOPE FENCE

This run ships **exactly four MSPs: H1 through H4.** No others.

- Do **not** create MSPs for clusters A through G. They are merged; re-implementing any part of them is a defect, not a dependency.
- **`lib/` is opened by ZERO MSPs in this cluster.** Every permanent file this run writes is a test file, a golden PNG, a test-tooling config, or a workflow. The only `lib/` edits that occur at all are R17's four perturbations, each of which is made, observed, reverted and **never committed**. **If an MSP's final diff contains a change under `lib/`, that MSP is wrong — stop and report.**
- The complete set of files this run may touch:

| File | Owning MSP | New? |
|---|---|---|
| `test/design/goldens/golden_harness.dart` | H1 | **new** (R3) |
| `test/design/goldens/font_loading_test.dart` | H1 | **new** (R11) |
| `test/design/goldens/cross_hatch_golden_test.dart` | H1 | **new** |
| `test/design/goldens/images/cross_hatch_{photo,video,viewport}.png` | H1 | **new** |
| `dart_test.yaml` | H1 | **new** (R9) |
| `.gitignore` | H1 | no — one line appended (R10) |
| `pubspec.yaml` | H1 | no — one `environment:` key added (R14) |
| `.github/workflows/goldens.yml` | H1 | **new** (R12) |
| `test/design/goldens/flower_golden_test.dart` | H2 | **new** |
| `test/design/goldens/images/flower_*.png` (12) | H2 | **new** (R21) |
| `test/design/goldens/sticker_card_golden_test.dart` | H3 | **new** |
| `test/design/goldens/nav_icon_golden_test.dart` | H3 | **new** |
| `test/design/goldens/images/sticker_card_{default,rotated}.png` | H3 | **new** |
| `test/design/goldens/images/nav_icon_{home,calendar,garden,search}.png` | H3 | **new** (R26) |
| `test/design/goldens/sticker_button_golden_test.dart` | H4 | **new** |
| `test/design/goldens/images/sticker_button_{primary,secondary,danger}.png` | H4 | **new** |

- **Zero fence widenings.** Unlike Cluster G, no MSP here needs a file its parent block did not imply. The parent's H1 Files list named `test/design/widgets/` and `test/design/flowers/`; **neither is written to** — R3 imports `widget_harness.dart` read-only, and R23 declines to follow `flower_bloom_test.dart`'s wrapper without editing it.
- Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - **`test/flutter_test_config.dart` — READ ONLY, absolutely.** 918 green tests depend on it and it already satisfies determinism requirement #1 (R2). A golden comparator override or an `autoUpdateGoldenFiles` guard goes in R3's new helper. **If your diff touches this file, stop and report.**
  - `test/design/widgets/widget_harness.dart` and `test/design/feedback/harness.dart` — **no refactor into a shared file** (R3). Imported, never edited.
  - `test/design/widgets/cross_hatch_placeholder_test.dart`, `test/design/widgets/sticker_card_test.dart`, `test/design/widgets/sticker_button_test.dart`, `test/design/flowers/flower_bloom_test.dart` — the existing non-golden coverage of the same widgets. **H adds goldens; it does not consolidate, replace or delete these.** Their assertions (band metrics, blend luminance, tilt geometry, paints-without-throwing) sit at a lower layer than a picture and remain the correct home for those behaviours.
  - `.github/workflows/receipts.yml` — **not modified.** R12 adds a second workflow file beside it. Editing the receipts job is out of bounds in this cluster.
  - `lib/design/**` — read to verify anchors, edited only under R17's perturbation protocol, and reverted before commit every time.
  - `test/features/entry_cards/playback/` — N24. See below.
  - `integration_test/**` — untouched. No MSP here changes a label, so §5.4's named-file caveat does not arise.
- If decomposition suggests a unit outside H1–H4, that is a signal the parent spec should be re-dispatched — **not** a licence to widen this run. Stop and report.

---

### DEPENDENCY CHAIN and SHIP ORDER

**The chain is strictly linear.** H2, H3 and H4 each depend on H1 and on nothing else: the helper (R3), the tag and its declaration (R9), the DPR pin (R6), the failures ignore (R10) and the CI job (R12) are all H1's, and every later MSP consumes them unchanged. H2, H3 and H4 share no file with each other — separate test files, separate PNGs.

```
slice -> H1 -> H2 -> H3 -> H4
```

**H2, H3 and H4 are mutually independent and could in principle run in parallel.** They are shipped in series anyway, for two reasons and neither is scheduling:

1. **The stack's whole purpose is that font risk sits at the top and can be dropped** (R1). Parallel merges would let H4 land before H2 or H3, which is the one ordering the decomposition exists to prevent.
2. Each MSP's golden PNGs are captured on a base that already contains its predecessor's. Serial merges mean each capture happens on a tree one merge away from `main`, which keeps the rebase-and-recapture surface at zero.

The repo squash-merges, so once an MSP lands, `main` holds its content under a SHA absent from the next branch's history. **Each MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. Never carry a green from one base to another** — and for this cluster that rule has extra force: a golden PNG is a binary artifact whose validity is a property of the toolchain and the source tree it was captured against.

**Branch discipline, reproduced because it has burned this project.** Every branch is cut with an explicit start point: `git switch -c msp-cluster-h/h1 origin/main`, and each successor from its predecessor's merged `main`. **Never branch from `HEAD`** — the dispatching session's `HEAD` was ten commits ahead of `origin/main` with an unpushed ledger commit. **Never `git switch main`** — it has aborted twice on uncommitted ledger edits. `msp-cluster-g/*`, `docs/cluster-g-slice`, every `chore/ledger-handoff-session-*`, the `.fireplace-worktrees*` directories and every stash are under a standing keep directive: not touched, not rebased, not deleted, not pushed. `.serena/` is untracked and stays untracked.

---

### THE STANDING INVARIANT — every MSP leaves the branch green, and none of them can break the app

This governs every MSP in this cluster.

**Cluster H cannot regress the application, because it does not ship application code** (HARD SCOPE FENCE). That is a real property, not a comfort: the green-branch invariant is satisfied structurally by every MSP here, and the only ways an MSP in this cluster can leave a branch red are:

1. **A golden that fails on the machine that captured it** — a harness defect, and the reason H1 ships cross-hatch as its own proof.
2. **An uncommitted perturbation** — R17 step 3's clean-tree check exists solely for this, and R10's gitignore exists so that check means something.
3. **A `dart_test.yaml` or `pubspec.yaml` edit that breaks resolution for the whole suite** — H1's two config edits are the highest-blast-radius lines in the cluster and are the reason both live in H1, where a revert costs nothing downstream.
4. **A golden that passes while asserting nothing** — a collapsed `CrossHatchPlaceholder` (R18), a bloom captured at 48 instead of 44 (R22), a disabled button at half opacity (R29), a rotated card indistinguishable from its default (R25), a weight outside its `fvar` range (R30). **Every one of these is green.** They are the real failure mode of this cluster and each has its own resolution above.

Concretely, per MSP:

- **H1** stands up the mechanism and proves it can fail, on the simplest possible subject. If `cross_hatch_photo` does not go red on a one-value band-pitch change, nothing later in the stack is worth capturing.
- **H2** proves the mechanism scales to twelve captures of one widget family and covers both halves of `FlowerPainter`.
- **H3** proves it discriminates within a family — `nav_icon_home` stays green while its three stroked siblings go red — and that a sub-pixel geometric change is captured at all.
- **H4** is the only MSP whose captures can be invalidated by a toolchain move, and the only one that can be reverted without losing a text-free golden.

---

## 1. BLUF

The repo has **zero golden coverage**. The existing 918-test suite asserts token values, labels and wiring — `test/app/theme/app_theme_test.dart:12-23` asserts `theme.scaffoldBackgroundColor == Palette.page` and `theme.textTheme.bodyMedium?.fontFamily == TypographyTokens.sans` — which structurally cannot catch "the hard shadow got blurry" or "the bloom geometry drifted". Seven clusters of pixel work have shipped with no pixel net under them. Goldens are the only mechanism that verifies pixels ([`matchesGoldenFile`](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)).

**Cluster H's share.** H1 stands up the harness — a ten-line pump helper over the existing `stickerHarness`, an explicit DPR-1 pin, a `golden` tag and its declaration, a `failures/` ignore, an anti-Ahem fallback guard, a Flutter floor in `pubspec.yaml`, and the repo's **first CI job that runs a single line of Dart** — and proves it with the three cross-hatch captures, the simplest text-free painter in the set. H2 captures the bloom set at 44px, twelve rather than the parent's ten, closing the procedural half of `FlowerPainter` that the ten leave entirely unguarded. H3 captures the sticker card in both its flat and tilted forms and the four nav glyphs at their shipped 18px, and proves the tilt golden is not a duplicate of its sibling. H4 captures the three sticker-button variants — the only text-bearing goldens in the cluster — on a harness two MSPs have already proven.

**Cluster H opens no application file, adds no dependency, and adds twenty-one golden images across four MSPs.** It is the smallest cluster in the spec by diff and the only one whose entire output is a safety net.

**Aligned means**: every one of the 21 goldens captures a rendering that actually ships, on a toolchain pinned in a place a machine reads; every family has been observed to fail on a deliberate one-value perturbation and observed to leave its siblings green; and no golden in the set can pass while asserting nothing.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP inherits them.

**Scoping note for this run.** The full non-negotiable set N1–N25 is defined in the parent spec. Cluster H ships no application code, so **almost none of N1–N23 or N25 is reachable by any MSP here.** One row binds this run, and it binds it absolutely.

### 2.1 N24 — the preserve fence, reproduced in full

**Cluster H ADDS tests. It NEVER modifies the 106 existing video/playback tests.**

The untouchable path is **`test/features/entry_cards/playback/`**.

**CORRECTION, and it matters because both wrong forms appear in older documents on this project:** the path is **not** `test/cards/` and **not** `test/playback/`. **Neither of those directories exists.** An implementer who greps for either finds nothing, concludes the fence is vacuous, and proceeds without it.

**Proof is a path-scoped diff, never an assertion.** Before any MSP in this run merges:

```
git diff origin/main...<your-branch> -- test/features/entry_cards/playback/
```

**must be EMPTY.** A non-empty result is a fence breach regardless of what the change was or how green the suite is. This is run per MSP, on that MSP's own branch, against a freshly-fetched `origin/main`.

The fence is background rather than acute in this cluster — no MSP here writes anywhere near `test/features/`, and path disjointness is total — but it is proven mechanically every time anyway, because "we did not go near it" is exactly the claim the diff exists to replace.

### 2.2 The two rules that outrank convenience in this cluster

1. **A golden that cannot fail is worse than no golden.** Every golden-bearing MSP owes an observed perturbation receipt (R17), and every "silently passes" trap has a named resolution (R18, R22, R25, R29, R30).
2. **`test/flutter_test_config.dart` is read-only** (R2). 918 green tests depend on it; 21 goldens do not justify the risk.

---

## 3. Findings that Cluster H implements

The parent's H1 rationale, reproduced, with each claim re-verified first-hand on `dd74688`:

| Parent claim | Verified? |
|---|---|
| *"the repo currently has zero golden coverage — `grep -rl "golden\|matchesGoldenFile" test/ integration_test/` returns no matches"* | **YES.** Re-run on this base; no matches. `test/design/goldens/` does not exist |
| *"The existing suite asserts token values and wiring … which structurally cannot catch 'the hard shadow got blurry'"* | **YES.** `app_theme_test.dart:12-23` asserts exactly the two named properties |
| *"a `test/flutter_test_config.dart` loads the three vendored variable fonts via `FontLoader`"* — listed as **new** | **ALREADY SHIPPED** (deleted row 1, R2) |
| *"CI pins one OS and one Flutter SDK version for the golden job"* | **NO CI EXISTS TO PIN.** `receipts.yml` runs zero Dart. R12 stands the job up from nothing |
| *"the implementer must confirm which side of that behaviour change the installed toolchain sits on … This is currently unverified"* | **NOW VERIFIED, affirmatively.** Post-change; three per-family `fvar` plateaus measured (R30) |
| the fractional-DPR softening is *"architectural in Flutter, not a bug in this app"* | **YES**, and it is documented, not worked around (R6) |
| `flower_{kind} x 10` | **TEN IS EXACT** (the non-ambient kinds) **but leaves half of `FlowerPainter` unguarded.** Twelve (R21) |
| `nav_icon_{today,…}` | **`NavGlyph` has no `today`.** Renamed to `nav_icon_home` (R26) |

**One structural finding the parent does not carry:** the target set is five widgets, and **every one of them is a `StatelessWidget` with a `const` constructor whose entire visual output is a function of `const` tokens**. No `Theme.of`, no provider, no `Ticker`, no `Random`, no `DateTime.now`, anywhere in the five files or the painters they reach. That is why R7's single-pump rule is sound and why the whole set can share one ten-line harness. It is also the reason this cluster is cheap: the hard part of goldens is usually pinning nondeterminism, and there is none here to pin.

---

## 4. MSP decomposition — Cluster H

**The governing invariant**: merging any MSP must leave the branch's app fully working. In this cluster that is structural — no MSP opens `lib/` (HARD SCOPE FENCE) — so the real per-MSP obligation is the one in §0's STANDING INVARIANT: the goldens the MSP adds must have been **observed to fail** on a deliberate perturbation and observed to leave their siblings green.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster H is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged** |
| B | Window chrome and nav rail | B1 – B4 | **merged** |
| C | Today centre column | C1 – C7 | **merged** |
| D | Today right rail | D1 – D4 | **merged** |
| E | Flower art | E1 – E4 | **merged** |
| F | Mood picker | F1 – F4 | **merged** |
| G | Capture composers | G1 – G8 | **merged** |
| H | Verification infrastructure | H1 – H4 (parent: H1) | **YES** |

---

### H1 — Golden harness, CI pin, and the cross-hatch proof

**Outcome**: the repo gains a working pixel-regression mechanism, pinned to one OS and one exact SDK, proven by three captures of the simplest painter in the design system and by an observed deliberate failure.

**Files**: new `test/design/goldens/golden_harness.dart`, new `test/design/goldens/font_loading_test.dart`, new `test/design/goldens/cross_hatch_golden_test.dart`, new `test/design/goldens/images/cross_hatch_{photo,video,viewport}.png`, new `dart_test.yaml`, new `.github/workflows/goldens.yml`, `.gitignore` (one line), `pubspec.yaml` (one `environment:` key).

**Depends on**: A4, A5 (merged). Root of this cluster's chain.

**Target scope** — reproduced from the parent's table, this MSP's row only:

| Golden | What it guards |
|---|---|
| `cross_hatch_{photo,video,viewport}` | the A5 band geometry |

**CORRECTION to that row (R19)**: photo and video share `bandWidth: 6, bandPitch: 12` and differ **only** in colour (`cross_hatch_placeholder.dart:27-38`). Viewport is the only variant with different band metrics (`8` / `16`, `:39-44`) and the only one with no outline border (`:88-89`). So the pair guards the palette and the third guards the geometry — the parent's single phrase covers two different claims.

**Capture parameters, all explicit:**

```
harness        goldenHarness (R3) over stickerHarness — no MaterialApp, no Theme
surface        800 x 600 logical, devicePixelRatio 1.0, reset in tearDown   R6
subject        CrossHatchPlaceholder(variant: <v>, width: 120, height: 90)  R18
child          null                                                        R19
background     null   hatchColor  null                                     R20
borderRadius   default Shapes.cardBorderRadius on all three                R19
boundary       RepaintBoundary, padding EdgeInsets.zero                    R8
pump           one pumpWidget, no pumpAndSettle                            R7
key            matchesGoldenFile('images/cross_hatch_<variant>.png')       R4
tag            @Tags(<String>['golden'])                                   R9
```

**Fifteen resolutions bind H1 and none is optional**: R2 (`flutter_test_config.dart` read-only), R3 (the helper wraps, never replaces), R4 (layout and path resolution), R5 (snake_case naming), R6 (the DPR and surface pin), R7 (one pump), R8 (explicit boundary), R9 (the tag and `dart_test.yaml`, no default exclusion), R10 (the `failures/` ignore), R11 (the anti-Ahem guard), R12 (the CI resolution), R13 (no golden package), R14 (the `pubspec.yaml` floor), R15 (confirm the enforcer first), R16 (the regeneration protocol), plus R17's receipt.

**The CI job**, whose shape R12 fixes and whose YAML carries **no comments**: `macos-latest`; `subosito/flutter-action@v2` with `flutter-version: 3.44.8`, `channel: stable`, `cache: true`; `flutter pub get`; `dart run build_runner build`; `flutter test --tags golden` **from the repo root**; `actions/upload-artifact` with `if: failure()` over `test/design/goldens/failures/**`; `paths:` filtered to `lib/design/**`, `test/design/goldens/**`, `assets/fonts/**`, `pubspec.yaml`, `.github/workflows/goldens.yml`. Added as a **new** workflow file; `receipts.yml` is not modified.

**Must not regress**:
- N24 — the path-scoped diff over `test/features/entry_cards/playback/` is empty.
- **`test/flutter_test_config.dart` is byte-identical to `origin/main`** (R2). Prove it the same way: `git diff origin/main...HEAD -- test/flutter_test_config.dart` is empty.
- All 918 existing tests pass **unmodified**. `dart_test.yaml` and the `pubspec.yaml` `environment:` key are the two edits with suite-wide blast radius; both are verified by the full `fullValidationCmd`, not by the golden job.
- `flutter test` with no arguments still runs everything, goldens included (R9).
- No `lib/` change survives into the commit (R17 step 3).

**Tests this MSP owes**: three golden cases in `cross_hatch_golden_test.dart`, one per variant, **one golden per `testWidgets`** so a failure names exactly one image; plus one case in `font_loading_test.dart` (R11). **Four cases.** One golden per case is not a style choice — a grouped case fails as a unit and forces a whole-family re-review for a single-image regression.

**Acceptance criteria**: `flutter test --tags golden` passes locally on macOS from the repo root; the same command passes on the pinned `macos-latest` job; and the R17 perturbation — `bandPitch: 12` → `13` on the photo variant — reds **`cross_hatch_photo` alone**, writes a readable `failures/cross_hatch_photo_isolatedDiff.png`, and leaves `cross_hatch_video` and `cross_hatch_viewport` green. The perturbation is reverted by re-editing, `git diff --stat` on the file is empty, and the suite is re-run green.

**Predicted reds**: **none among the 918.** The two suite-wide edits are the only risk: an over-tight `pubspec.yaml` Flutter constraint would fail `flutter pub get` before any test runs (a total of zero, not a reduced count), and a `dart_test.yaml` with a `skip` would silently remove the goldens from the default run. Both are pinned by R14 and R9 respectively.

---

### H2 — The bloom goldens

**Outcome**: every bloom silhouette from E2/E3 is pinned at its scale-1.0 size, including the two procedural blooms the parent's set omits.

**Files**: new `test/design/goldens/flower_golden_test.dart`, new `test/design/goldens/images/flower_*.png` (twelve).

**Depends on**: E2, E3 (merged), **H1**.

**Target scope** — reproduced from the parent's table, with the ADDITION marked:

| Golden | What it guards |
|---|---|
| `flower_{kind}` x 10 at 44px | every bloom silhouette from E2/E3 |
| **`flower_wilting_rose`, `flower_thistle` at 44px** | **ADDITION (R21)** — the only pixel coverage of `FlowerPainter._paintProcedural` and its four style branches |

The twelve, with their anchors and stroke widths, all resolved through `flowerSpecFor` (`flower_spec.dart:62-154`):

| Golden file | `FlowerKind` | Anchor | Stroke |
|---|---|---|---|
| `flower_peony.png` | `peony` | `flower_spec.dart:63` | 1.4 |
| `flower_rose.png` | `rose` | `:69` | 1.3 |
| `flower_sunflower.png` | `sunflower` | `:75` | 1.0 |
| `flower_poppy.png` | `poppy` | `:81` | 1.3 |
| `flower_chrysanthemum.png` | `chrysanthemum` | `:87` | **0.8** — thinnest, most antialiasing-sensitive |
| `flower_daffodil.png` | `daffodil` | `:93` | 1.2 |
| `flower_lavender.png` | `lavender` | `:99` | 1.0 |
| `flower_aster.png` | `aster` | `:105` | 0.9 |
| `flower_bleeding_heart.png` | `bleedingHeart` | `:111` | 1.3 |
| `flower_red_spider_lily.png` | `redSpiderLily` | `:117` | **1.8** — thickest |
| `flower_wilting_rose.png` | `wiltingRose` | `:123` — procedural, `roundPetals`, `petalCount: 6`, `droop: true` | 1.3 |
| `flower_thistle.png` | `thistle` | `:139` — procedural, `puff`, `petalCount: 11` | 1.3 |

**Capture parameters:**

```
subject   FlowerBloom(kind: <k>, size: 44)      R22 — the default is 48; 44 is scale 1.0
harness   goldenHarness, no MaterialApp          R23
sizing    none needed — SizedBox.square is inside FlowerBloom (flower_bloom.dart:38)
naming    explicit const (kind, slug) pairs      R5 — never kind.name
```

**Three resolutions bind H2**: R21 (twelve, not ten), R22 (explicit `size: 44`), R23 (bare harness, and the existing flower test is not edited), plus R17's receipt.

**Must not regress**: N24, proven by the path-scoped diff. `test/design/flowers/flower_bloom_test.dart` stays green **unmodified** — H2 adds pictures at a different layer, it does not consolidate the existing paints-without-throwing coverage. No `lib/` change survives into the commit.

**Tests this MSP owes**: twelve golden cases, one per bloom.

**Acceptance criteria**: twelve goldens pass locally and on the pinned job; the R17 perturbation — sunflower `BloomOvalRing(count: 8, …)` → `count: 7` at `bloom_geometry.dart:46` — reds **`flower_sunflower` alone** with a readable diff showing the missing 45-degree ray, and leaves the other eleven green. Reverted, verified empty, re-run green.

**Predicted reds**: none.

---

### H3 — The sticker card and the nav glyphs

**Outcome**: the sticker primitive's fill, outline, hard shadow and tilt are pinned, and the four B3 nav glyphs are pinned at the size and colour the rail actually renders.

**Files**: new `test/design/goldens/sticker_card_golden_test.dart`, new `test/design/goldens/nav_icon_golden_test.dart`, new `test/design/goldens/images/sticker_card_{default,rotated}.png`, new `test/design/goldens/images/nav_icon_{home,calendar,garden,search}.png`.

**Depends on**: A4, B3 (merged), **H1**.

**Target scope** — reproduced, with the CORRECTION marked:

| Golden | What it guards |
|---|---|
| `sticker_card_default`, `sticker_card_rotated` | fill, 1.5px outline, hard offset shadow, tilt |
| ~~`nav_icon_today`~~ **`nav_icon_home`**, `nav_icon_calendar`, `nav_icon_garden`, `nav_icon_search` | the B3 glyph set. **CORRECTION (R26): `NavGlyph` has no `today` member** (`nav_icons.dart:3`); the parent's name comes from `ShellDestination.today`, which maps to `NavGlyph.home` (`shell_destination.dart:6`) |

**Capture parameters:**

```
card subject     StickerCard(child: SizedBox(120, 64))                  R24 — text-free by construction
                 all other params default: padding 16, surface cardWarm,
                 borderRadius cardBorderRadius, shadow Shadows.card
                 (= Shadows.hero, ink20 @ Offset(3,3) blur 0, shadows.dart:78-85,141)
                 border Shapes.outline 1.5px ink, hardcoded at sticker_card.dart:30
rotated          rotationDegrees: -0.5                                  R25 — the shipped odd-card tilt
card boundary    padding EdgeInsets.all(8) on BOTH captures             R8, R25 — Transform.rotate
                 does not enlarge the layout box; a tight boundary crops the tilt
nav subject      NavIcon(glyph: <g>, color: Palette.ink, size: 18)      R27
                 18 => painter scale 18/24 = 0.75 (nav_icons.dart:41);
                 nominal 2px stroke lands at 1.5 physical px at DPR 1
```

**Four resolutions bind H3**: R24 (the text-free child), R25 (the angle and the difference receipt), R26 (`nav_icon_home`), R27 (size 18, colour `Palette.ink`), plus R17's receipt.

**Recorded caveat**: `_search()`'s handle runs to `(21, 21)` in a 24 `viewBox` with a 2px round cap (`nav_icons.dart:111-114`), so at scale 0.75 the cap sits near the box edge and can clip. **Look at the first `nav_icon_search.png` before accepting it.**

**Must not regress**: N24, proven by the path-scoped diff. `test/design/widgets/sticker_card_test.dart` stays green unmodified. No `lib/` change survives into the commit.

**Tests this MSP owes**: two golden cases in `sticker_card_golden_test.dart` plus **one non-golden case** asserting the two card captures differ byte-wise (R25); four golden cases in `nav_icon_golden_test.dart`. **Seven cases.**

**Acceptance criteria**: six goldens pass locally and on the pinned job; the byte-difference case passes, proving `sticker_card_rotated` is not a re-encoding of `sticker_card_default`; and the R17 perturbation — `NavIconPainter.strokeWidth = 2` → `2.5` at `nav_icons.dart:36` — reds **`nav_icon_calendar`, `nav_icon_garden` and `nav_icon_search`** and leaves **`nav_icon_home` green** (it is the only filled glyph, drawn with `_fill()` at `:44`) and both card goldens green. Reverted, verified empty, re-run green.

**Predicted reds**: none.

---

### H4 — The sticker-button goldens

**Outcome**: A4's shadow-presence distinction is pinned in pixels — and the cluster's only text-bearing captures land last, on a harness three MSPs have already proven.

**Files**: new `test/design/goldens/sticker_button_golden_test.dart`, new `test/design/goldens/images/sticker_button_{primary,secondary,danger}.png`.

**Depends on**: A4 (merged), **H1**. Independent of H2 and H3, shipped after both by design (R1, SHIP ORDER).

**Target scope** — reproduced:

| Golden | What it guards |
|---|---|
| `sticker_button_primary`, `_secondary`, `_danger` | the shadow-presence distinction from A4 |

**Capture parameters:**

```
subject   StickerButton(label: <one shared string>, onPressed: <non-null>,
                        variant: <v>, icon: null, labelStyle: null)     R28, R29
label     IDENTICAL across all three                                    R28
sizing    none — Row(mainAxisSize: min) self-sizes (sticker_button.dart:58)
text      TypographyTokens.buttonSans: Instrument Sans, 15, w600
          (typography.dart:192-197), recoloured per variant at :66-67
```

**The three variants differ on four axes, not one** (`sticker_button.dart:96-119`):

| | primary | secondary | danger |
|---|---|---|---|
| background | `Palette.coral` | `Palette.cardWarm` | `Palette.danger` |
| foreground | `Palette.onAccent` | `Palette.ink` | `Palette.onAccent` |
| borderRadius | `radiusControl` 12 | `radiusControl` 12 | `buttonBorderRadius` = `radiusSm` **11** |
| padding | 13 / 10 | 13 / 10 | **16 / 9** |
| shadow | `emphasis` `Offset(2,2)` | **`null`** | `control` `Offset(1.5,1.5)` |

**Three resolutions bind H4**: R28 (one shared label, identical everything else), R29 (`onPressed` non-null, `icon` null), R30 (the standing font-weight constraint), plus R17's receipt.

**THE STANDING CONSTRAINT, restated here because these three goldens are the only ones it reaches** (R30). `buttonSans` is w600 in Instrument Sans, whose `fvar` wght range is 400–700, so w600 renders as a genuine variable-axis instance on this toolchain and these goldens are fully exposed to the pin. Their validity depends on: Flutter `3.44.8` (CI, R12) at or above the 3.41 cutover (`pubspec.yaml`, R14); the three `.ttf` files byte-for-byte; and the `FontLoader` registration at `flutter_test_config.dart:16-30`, guarded by R11. **A uniform soft change across all three at once means the font fell back or the SDK moved — never regenerate that away** (R16 step 4). And any future text-bearing golden must pick a weight **inside** its family's range, or it passes while asserting nothing.

**Recorded, not chased**: `danger`'s 1.5px shadow offset lands on a half-pixel boundary at DPR 1 and antialiases. That is R6's documented Flutter platform limitation ([#59798](https://github.com/flutter/flutter/issues/59798), [#117355](https://github.com/flutter/flutter/issues/117355)); it is deterministic on a pinned toolchain and is captured as-is. **Do not adjust the token and do not add a pixel-snapping workaround.**

**Must not regress**: N24, proven by the path-scoped diff. `test/design/widgets/sticker_button_test.dart` stays green unmodified. `test/flutter_test_config.dart` byte-identical. No `lib/` change survives into the commit.

**Tests this MSP owes**: three golden cases, one per variant.

**Acceptance criteria**: three goldens pass locally and on the pinned job; and the R17 perturbation — `Shadows.emphasis` `offset: Offset(2, 2)` → `Offset(3, 2)` at `shadows.dart:54` — reds **`sticker_button_primary` alone** with a readable diff, and leaves `_secondary` (shadow `null`) and `_danger` (`Shadows.control`) **green**. That green pair is the receipt that these goldens hold A4's shadow-presence distinction and not merely three coloured rectangles. Reverted, verified empty, re-run green.

**Predicted reds**: none. `sticker_button_test.dart` asserts variant style properties through the widget tree, not pixels, and is unaffected.

---

## 5. Verification strategy

### 5.1 What the repo actually has

**Nothing, in this dimension.** `grep -rl "matchesGoldenFile" test/ integration_test/` returns no matches on `dd74688`. There is no `test/design/goldens/`, no `dart_test.yaml`, no golden helper package in `dev_dependencies` (`pubspec.yaml:60-75`), no `/verify-<project>` command, and no CI step that executes Dart.

What the repo does have, and which this cluster consumes read-only:

| Asset | Anchor | What it gives Cluster H |
|---|---|---|
| suite-wide font loading | `test/flutter_test_config.dart:7-30` | determinism requirement #1, complete (R2) |
| the pump harness | `test/design/widgets/widget_harness.dart:3` | DPR 1.0, `noScaling`, no theme (R3) |
| the boundary-capture precedent | `test/design/widgets/cross_hatch_placeholder_test.dart:30-48` | the exact `RepaintBoundary` → `toImage` → `toByteData` pattern R25 reuses |
| the font-declaration pin | `test/design/tokens/pubspec_fonts_test.dart` | the pubspec side of the font contract |

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling, layout or copy change warrants no new test**. Cluster H is unusual: it adds 25 test cases and changes no behaviour at all. Every one of them qualifies, and it is worth being precise about why rather than waving at the gate:

| Category | Cases | Why it qualifies |
|---|---|---|
| the 21 golden cases | 21 | Each **defines a public contract**: the rendered pixel output of a public design-system widget at a fixed configuration. Nothing in the existing suite asserts pixels, so criterion 2 (no existing coverage) holds for every one. They assert observable output through a public surface — a rendered image — which is criterion 3 in its most literal form |
| the anti-Ahem guard (R11) | 1 | Defines the contract of a **new** mechanism (the harness's font guarantee). `pubspec_fonts_test.dart` asserts the pubspec declaration, which is a different claim |
| the card byte-difference receipt (R25) | 1 | Asserts a contract of the golden **pair** — that the two captures are distinguishable. Without it, `sticker_card_rotated` can silently be a duplicate |
| new files created, existing test files modified | 7 new, **0 modified** | No retargets. No case is deleted, renamed or weakened anywhere in the suite |

**These goldens are not change-detectors.** A change-detector fails on a refactor that preserves behaviour; a golden fails only when rendered output changes, which for a design system **is** the behaviour. The distinction the parent already drew holds: per-petal geometry assertions would be change-detectors, which is why E2/E3's geometry is verified here in pixels rather than in numbers.

**Placement.** Every golden sits at the lowest layer that can express it — a single leaf widget under a bare harness, never a composite screen. **No golden in this cluster captures a screen, a dialog, a route or a scrollable.** That is the parent's own *"leaf widgets and painters only, not composite screens"*, and it is what keeps a red golden diagnostic rather than merely alarming.

**No existing test is deleted or consolidated.** The lower-layer assertions in `cross_hatch_placeholder_test.dart`, `sticker_card_test.dart`, `sticker_button_test.dart` and `flower_bloom_test.dart` remain the correct home for band metrics, blend luminance, tilt geometry and paints-without-throwing. A picture does not supersede them; it covers a different question.

### 5.3 Baseline and per-MSP test-count prediction

**Predict the test count before running.** Every MSP states its expected total **in writing** before executing `fullValidationCmd`, and compares afterwards. A mismatch that cannot be explained is a defect, not a rounding error. Clusters F and G both predicted and observed exactly.

Baseline, **measured first-hand on a tree byte-identical to `origin/main` at `dd74688`**: `flutter analyze` → **`No issues found!`**; `flutter test` → **918 passed, 0 failed**. This matches the recorded figure exactly and matches a written pre-run prediction of 918/0 derived from a zero net diff. `build_runner` emitted a non-fatal `W These options have been removed and were ignored` for `--delete-conflicting-outputs` and wrote 0 outputs, so generated code on `main` is already current. **This figure was measured, not inherited; the recorded figure on this project has been stale three times historically, so measure it again on your own base.**

| MSP | Delta | Expected total | Reason |
|---|---|---|---|
| H1 | **+4** | **922** | 3 cross-hatch goldens (one case each) + 1 anti-Ahem guard (R11) |
| H2 | **+12** | **934** | 12 bloom goldens, one case each (R21) |
| H3 | **+7** | **941** | 2 card goldens + 1 byte-difference receipt (R25) + 4 nav goldens |
| H4 | **+3** | **944** | 3 sticker-button goldens |

**Cluster close: 944.** A result above 944 means a golden was split into more cases than the tables name — report it rather than absorbing it. A result below 918 at any point means a case was lost, which is the failure this discipline exists to catch.

**Three categories of failure that are NOT test-count movements and must not be mistaken for them:**
1. **A `pubspec.yaml` resolution failure** (R14). An over-tight Flutter constraint fails `flutter pub get` before a single test runs, producing a total of **zero**, not a reduced count.
2. **A `dart_test.yaml` default exclusion** (R9). A `skip` on the `golden` tag silently removes every golden from the default run — the total **drops back toward 918 while every golden reports as skipped**, which reads like success if only the pass count is checked. Read the skip count.
3. **A working-directory error** (R2). `flutter test` from a subdirectory throws a `FileSystemException` in `testExecutable` and fails all 918 with a message that reads nothing like a font problem.

### 5.4 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. **N24, proven mechanically**: `git diff origin/main...<your-branch> -- test/features/entry_cards/playback/` is **EMPTY**. Against a freshly-fetched `origin/main`, per MSP, on that MSP's own branch. The shorthand paths `test/cards/` and `test/playback/` **do not exist** and must not be substituted (§2.1).
3. **`git diff origin/main...<your-branch> -- test/flutter_test_config.dart` is EMPTY** (R2). Same form, same reason.
4. **`git status --porcelain` is clean and no `lib/` path appears in the MSP's diff** (R17 step 3, HARD SCOPE FENCE). This is the perturbation-revert proof and it is per-MSP.
5. **Never run `flutter test integration_test/` as a directory.** `integration_test/capture_save_persist_test.dart` writes into the real journal container. Name a single file if one is ever needed — **no MSP in this cluster needs one**, since no MSP changes a label or a widget.
6. Diff-scoped verification during the work; the full suite at the MSP boundary and pre-push.

**CI is not evidence.** Neither existing GitHub check runs a Dart test, and R12's new golden job proves exactly one thing on one path filter — it is not a substitute for the suite. `receiptsPass` and `d6Pass` are never acceptable as proof that this run is green. Run `verify.fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge — verbatim:

```
export PATH="/opt/homebrew/bin:$PATH" && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test
```

Run it in the **foreground** with an explicit long timeout. Never background it: a subagent's background shells are swept at teardown, and two earlier attempts on this project were lost that way. `--delete-conflicting-outputs` is ignored by this repo's `build_runner` version (`W These options have been removed and were ignored`); the build still completes and that warning is expected.

**And run `flutter test --tags golden` separately, reading its output**, before and after each perturbation. `fullValidationCmd`'s bare `flutter test` includes the goldens (R9), so the pass/fail is covered — but the perturbation receipt requires reading a specific red set, and the tagged run is what makes that readable.

### 5.5 Manual spot-check — REQUIRED, and OWED BY A HUMAN on the first capture of each family

**Unlike Cluster G, this pass needs no running app** — every subject renders in a test binding, and the artifact under review is a PNG on disk. But it cannot be skipped, because **the one failure mode this cluster is built to prevent is a golden that looks fine to a machine and is wrong**.

On the first capture of each family, before the PNG is committed, **open the image and look at it**:

- **After H1:** three cross-hatch PNGs, each 120x90, each showing 45-degree bands. **Confirm none is blank** — a blank image is R18's collapsed-`SizedBox` trap and it would pass forever. Photo and video must differ in colour only; viewport must show visibly wider, more widely spaced bands and **no ink outline**.
- **After H2:** twelve blooms, each 44x44. Confirm chrysanthemum's 0.8px strokes are visible and not lost, and confirm `flower_wilting_rose` and `flower_thistle` render actual blooms — they are the only two exercising the procedural painter and the only two whose emptiness would go unnoticed.
- **After H3:** `sticker_card_default` and `sticker_card_rotated` side by side. **They must be visibly distinguishable at the border**, even if barely; the byte-difference case (R25) is the machine proof, this is the human one. Then the four nav glyphs: `nav_icon_home` filled, the other three stroked, and **`nav_icon_search`'s handle cap not clipped at the edge** (R27).
- **After H4:** the three buttons at identical label and size. **`primary` has a hard 2px offset shadow, `secondary` has none, `danger` has a soft-edged 1.5px one.** If `secondary` shows any shadow, or if the three labels are different widths, stop — the first is a variant bug and the second means R28 was not followed.

And after every perturbation in R17: **open `failures/<name>_isolatedDiff.png` and confirm it is readable.** A diff nobody can read is not a diff; determinism requirement #3 depends on a reviewer being able to see what changed.

### 5.6 Red-test register

**Empty.** No MSP in this cluster retargets, renames, weakens or deletes an existing assertion. No MSP changes a label, a `ValueKey`, a Semantics label, a widget or a token. All 918 existing tests pass **unmodified** at every commit in this run, and the only permitted movement in the count is upward, by the exact deltas in §5.3.

This is unusual and it is worth stating plainly rather than leaving the section blank: **Cluster H is purely additive, in the strongest sense the project has a name for.** If any existing test goes red during this run, that is not a permitted retarget and it is not a rounding error — it is a defect in the MSP, most likely one of the three non-count failures in §5.3. Stop and diagnose; do not retarget.

### 5.7 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**.

**Never prescribe `git checkout -- <path>` as an autonomous step.** In this cluster that rule has a specific target: R17's perturbation revert is done by **editing the value back**, then proving it with `git diff --stat <file>` and `git status --porcelain`. A `checkout` that discards more than it restored is exactly the failure that rule exists for, and here it would be discarding uncommitted golden work.

---

## 6. Out of scope

### 6.1 Deferred to later specs

- **Cross-OS golden validation.** The goldens are macOS-only by construction (R12). Validating them on Linux needs a second pinned runner or Linux-captured duplicates, and is a materially different piece of work. **It is never solved by loosening the comparator.**
- **Golden coverage of composite screens, dialogs, routes or scrollables.** The parent scopes this cluster to *"leaf widgets and painters only"*, and §5.2 explains why: a screen golden fails as one image and is not diagnostic.
- **Golden coverage of the capture composers** — the entire Cluster G surface. Every one of them is a modal over a state machine with a live recorder; capturing them needs a fixture layer this cluster does not build.
- **Migrating `stickerHarness` and `feedbackHarness` into one shared harness** (R3). A refactor with no shippable outcome that touches tests outside the golden scope.
- **A `/verify-fireplace` scoped verification command.** `.claude/commands/` does not exist; the project runs `fullValidationCmd` directly. Standing one up is a project-tooling change, not a Cluster H MSP.
- **An `fvm`/`.fvmrc` pin.** R14 pins the floor in `pubspec.yaml` and R12 pins the exact version in CI. A third pinning mechanism would add a tool every contributor must install for a marginal gain over the two that already exist.

### 6.2 Explicitly not a task

- **No edit to `test/flutter_test_config.dart`, for any reason** (R2). 918 green tests depend on it and it already satisfies determinism requirement #1. **Stop and report** if an MSP appears to need one.
- **No edit to any file under `lib/` that survives into a commit.** R17's perturbations are made, observed and reverted; nothing else opens `lib/` at all.
- **No edit to `.github/workflows/receipts.yml`.** R12 adds a second workflow beside it.
- **No refactor, consolidation or deletion of the existing non-golden coverage** of the five target widgets (§5.2). H adds a layer; it removes nothing.
- **No new dependency of any kind** — no `golden_toolkit`, no `alchemist` (R13).
- **No custom `GoldenFileComparator` and no tolerance of any size.** The default `LocalFileComparator`'s zero tolerance is the mechanism, not an obstacle to it (TOOLCHAIN LEDGER).
- **No in-app pixel-snapping workaround** for fractional-DPR antialiasing. Documented as a Flutter platform limitation and left alone (R6) — this is the parent's own instruction.
- **No `--update-goldens` to turn a red job green** (R16). Ever.
- **No golden captured at a configuration the app does not render** — no `NavIcon` at 24 (R27), no synthetic tilt angle (R25), no weight outside a font's `fvar` range (R30).
- **No `pumpAndSettle` anywhere in this cluster** (R7).
- **No `flutter test integration_test/` as a directory** (§5.4).
- **No deletion or weakening of the protected playback suite** under any circumstances (N24, §2.1).
- **No `gh pr create` and no `gh pr merge`.** Both are denied globally. PRs go through the centralized `pr-create` tool; merging is a human action and is not part of this workflow.

### 6.3 Open questions

**One, and it is operational rather than technical.** R15: the `receipts` enforcer's contract for a **test-only, `lib/`-untouched** PR is not visible in this repository, and every one of the four PRs in this run has that shape. `pr-title-lint` is known not to be merge-blocking (`.claude/ledger/decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md`); the enforcer's requirement is not recorded anywhere. **Confirm it before opening H1's PR**, not after it goes red — the cost of discovering it late is a round-trip on four stacked PRs rather than one.

**One cost the orchestrator should see explicitly before H1's workflow is written** (R12): GitHub-hosted macOS runners bill at a **10x** minute multiplier against Linux's 1x. A cold Flutter setup plus `build_runner` plus a 21-golden suite is realistically 6–12 minutes wall clock, so **~60–120 billable minutes per golden-job run**. The `paths:` filter is what keeps that from firing on every PR, and the SDK/pub cache is what keeps the wall clock at the low end. This is the single largest ongoing cost consequence of this cluster, and it is accepted deliberately: option (b) shifts the cost onto every contributor's local workflow, and option (c) fails the acceptance criterion.

**Nothing in the parent's OQ set (OQ-3, OQ-5, OQ-6) touches any MSP in this run.**

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Every app anchor this cluster cites was independently re-opened from `dd74688` while composing this slice** — not carried from recon, and not inherited from the parent. Read byte for byte: `test/flutter_test_config.dart` (all 30 lines), `test/design/widgets/widget_harness.dart` (all 14), `test/design/feedback/harness.dart`, `test/design/widgets/cross_hatch_placeholder_test.dart` (all 233), `lib/design/widgets/cross_hatch_placeholder.dart` (all 158), `lib/design/widgets/sticker_card.dart` (all 49), `lib/design/widgets/sticker_button.dart` (all 122), `lib/design/icons/nav_icons.dart` (all 119), `lib/design/flowers/flower_bloom.dart` (all 47), `lib/design/flowers/flower_painter.dart:1-65`, `lib/design/flowers/flower_spec.dart:58-155`, `lib/domain/mood/flower_kind.dart` (all 19), `lib/design/tokens/shapes.dart` (all 31), `lib/design/tokens/shadows.dart:30-91`, `lib/design/tokens/typography.dart:192-197`, `lib/design/flowers/bloom_geometry.dart:44-60`, `lib/features/entry_cards/entry_card.dart:20-30,60-64`, `lib/app/shell/sidebar_shell.dart:205-215`, `.github/workflows/receipts.yml` (all 32), `pubspec.yaml:18-26`, `.gitignore`.

**The parent's H1 block is unusually accurate on values and unusually wrong on availability.** Four defect classes, in descending order of danger:

1. **A file listed as new that already exists and is load-bearing for 918 tests.** `test/flutter_test_config.dart` (R2, deleted row 1). An implementer who authors it "new" either overwrites a working file or creates a duplicate `testExecutable`, and either outcome is discovered as a suite-wide failure with a misleading message.
2. **An enum member that does not exist.** `NavGlyph.today` (R26). The parent's golden name is a destination name, and the enum it must be captured from has no such member.
3. **Infrastructure assumed to exist and absent in every respect.** No CI runs Dart; no Flutter version is pinned anywhere; no tag mechanism and no `dart_test.yaml`; no golden helper package. Determinism requirement #2 is not an addition to a pipeline — it is the pipeline (R12).
4. **A default that silently defeats the test.** `FlowerBloom.size` is 48 where the table says 44 (R22); `CrossHatchPlaceholder.width`/`height` are both `null` and collapse to an empty capture (R18); `StickerButton.onPressed: null` captures every button at half opacity (R29); `StickerCard.child` has no declared value at all (R24). Each of these produces a golden that **passes**.

**And the class this cluster fears most, which is neither a wrong value nor a missing file:** a golden that is green and vacuous. R11 (font fallback), R18 (collapsed box), R22 (wrong scale), R25 (indistinguishable pair), R29 (wrong state), R30 (clamped weight) each exist to close one instance of it, and R17's perturbation receipt exists because none of those six resolutions proves the *mechanism* has teeth — only an observed failure does.

**Rule for implementers:** re-open every cited line before adopting any value, and **open the widget the capture has to pass through before assuming the capture means anything.** A golden's assertion is invisible: there is no expression to read, only an image that either matches or does not. That makes every unstated capture parameter a silent assumption, which is why this document states all of them. If you meet an anchor that does not resolve, a default this document did not declare, or a golden you cannot make fail on purpose, **stop and report. Do not make the call yourself** — that is exactly how the C5 caption and three C7 ladder rows were lost, and a vacuous golden is harder to find later than a lost row, because it looks like coverage.
