# Prototype Design Alignment — Cluster E (Flower art) Run Spec

Slice of: `docs/specs/2026-07-26-prototype-design-alignment.md`
Cluster: **E — Flower art**
MSPs: **E1, E2, E3, E4**
Base: `main` at `1ceb287`
Citation source: `docs/prototype/project/Field Notes.dc.html`

---

## 0. What this document is, and why it exists

This is an **execution slice** of the parent prototype-alignment spec, cut for one cluster. The engine that consumes a spec decomposes the whole document it is given and has no scope parameter, so scoping a run means cutting a document that contains only the target cluster's MSPs plus every constraint that binds them.

**Nothing here contradicts the parent spec on matters of fact.** Where this document reproduces parent text, it reproduces it verbatim. Where this document **corrects** the parent, the correction is marked inline with `CORRECTION` and states what the parent said, what the prototype actually says, and which line proves it. Where a reader needs material this slice omits — findings §3.1–§3.4 and §3.6–§3.7, MSPs A1–D4 and F1–H1, the excluded-elements table §6.1 — the parent spec on `main` is the authority.

**Clusters A, B, C and D are already merged and are this run's base.** The token layer closed with Cluster A and **Cluster E touches no token file**. Two dedicated recon passes ground this slice — one against the prototype, one against the app — and both are reproduced into the resolutions and tables below rather than referenced. Every prototype value in §3 and §4 was independently re-read from `Field Notes.dc.html` while composing this document; every app anchor was independently re-read from the base commit.

### The headline recon result, stated up front

**The parent spec contains zero factual errors in Cluster E's region.** Every line number, hex, radius, rx/ry, rotation and stroke width it quotes is verbatim-correct. What it contains instead are **omissions, over-generalisations and one internal contradiction** — thirteen on the prototype side, nine on the app side. Four of the thirteen are hard blockers: geometry the parent describes in prose but never supplies, which cannot be guessed and cannot be derived. **All twenty-two are resolved in this section.** No implementer should ever meet one of them mid-flight.

This matters because of this project's own history: the C5 caption and three C7 ladder rows were lost precisely because an implementer met an unreachable anchor or a stale target value while executing, and made a judgement call instead of stopping. This section exists so that no such call is ever needed.

### PRIMITIVE RESOLUTIONS — decided at slice time, not left to the implementer

Twenty-two decisions. Each states the problem, the chosen resolution, and what was rejected and why. Where a resolution widens an MSP's fence, the widening is **declared** and carries the standard obligation: every other consumer's tests pass **unmodified** (the precedent is D3's optional `labelStyle` parameter and D2's one-file shell widening).

---

**R1 — The headless transform is a single uniform 44-to-`d` scale. There is no per-flower normalisation and no re-centring.**

*Problem.* The parent's E1 target #3 (`:1137`) contradicts itself in one sentence: "the head is scaled to fill the box edge-to-edge, matching a `0 0 44 44` viewBox rendered 1:1". Those are two different transforms. The same target also says the head centre "moves … to `Offset(width/2, height/2)`". The prototype does the viewBox mapping only — `flower()` (`:1064`) renders `viewBox='0 0 44 44' width=100% height=100%` with no per-flower fitting.

*Resolution.* The headless render path maps viewBox unit `(x, y)` to canvas `(x * d / 44, y * d / 44)`, where `d = size.shortestSide`, with the 44-box centred in a non-square box:

```
canvas.save();
canvas.translate((size.width - d) / 2, (size.height - d) / 2);
canvas.clipRect(Rect.fromLTWH(0, 0, d, d));     // see R2
canvas.scale(d / 44);
... draw every part in raw 44-unit coordinates ...
canvas.restore();
```

Full stop. Nothing else. Stroke widths are authored in 44-units and are scaled by the same `canvas.scale`, which is exactly correct and is why `strokeWidth` must **not** be pre-multiplied.

*Rejected: "fill the box edge-to-edge."* It destroys the designed relative sizing. Measured glyph bounding boxes in the 44-box (geometry only, stroke excluded) are not uniform:

| Flower | bbox w% | bbox h% | bbox centre |
|---|---|---|---|
| Peony | 73 | 68 | (22.00, 22.00) |
| Rose | 64 | 64 | (22.00, 22.00) |
| Sunflower | 91 | 91 | (22.00, 22.00) |
| Poppy | 77 | 75 | (22.00, 21.50) |
| Lavender | 41 | 69 | (22.00, 17.55) |
| Aster | 95 | 95 | (22.00, 22.00) |
| Chrysanthemum | 105 | 105 | (22.00, 22.00) |
| Daffodil | 86 | 98 | (22.00, 22.00) |
| Red Spider Lily | 91 | 51 | (22.00, 14.20) |
| Bleeding Heart | 68 | 50 | (21.00, 17.96) |

Fitting Lavender (41% wide) edge-to-edge inflates it ~2.4x; Rose ~1.56x; Bleeding Heart would be stretched non-uniformly or over-scaled. **CORRECTION to parent `:209`**, which asserts the glyphs are "viewBox `0 0 44 44` filled edge-to-edge by the bloom only": that is false for six of ten. The accurate half of the same row — "headless: no stem, no leaf" — is correct and is the operative claim.

*Rejected: "move the head centre to `Offset(width/2, height/2)`."* Four flowers are not authored centred on (22,22) — Lavender (22, 17.55), Bleeding Heart (21.00, 17.96), Spider Lily (22, 14.20), Poppy (22, 21.50). Re-centring the **drawn art** shifts Spider Lily down 7.8 units, Lavender down 4.45, Bleeding Heart down 4.04 and right 1.0. There is no "head centre" to place: the authored coordinates already encode placement. The parent's sentence is satisfied incidentally and only in the sense that the **viewBox** centre (22,22) maps to `(d/2, d/2)` under R1's transform — which it does.

---

**R2 — The headless path clips to its box. The garden path does not.**

*Problem.* Chrysanthemum overflows its own viewBox: outer-ring petals reach -1.00 and 45.00 on both axes (`r=15` offset + `ry=8` = 23 from the pivot, against a 22 half-box). The prototype's compact `flower()` svg (`:1064`) sets `style:{display:'block'}` with **no** `overflow:'visible'`, and an SVG root defaults to `overflow:hidden` — so the four axis-aligned petal tips are cut flat in the design. Flutter's `CustomPaint` does not clip by default. The parent spec never mentions this.

*Resolution.* The headless path issues `canvas.clipRect(Rect.fromLTWH(0, 0, d, d))` inside the save block, as shown in R1. The garden plant path (E4) issues **no** clip, because `plantSvg` (`:1198`) explicitly sets `overflow:'visible'` — and so do `:1211`, `:1215` and `:1370` (`sprigArt`), which is what makes the compact glyph's omission of it deliberate rather than accidental.

*Rejected: no clip anywhere.* Chrysanthemum then renders four petal tips ~2.3% longer than the source at every size, and overflows its `SizedBox.square` in `FlowerBloom`, which is a layout bug as well as a fidelity one.

---

**R3 — `lib/design/flowers/flower_palette.dart` joins E1's file list. Declared fence widening.**

*Problem.* E1 introduces ten stroke colours. The parent's E1 file list is `flower_spec.dart`, `flower_painter.dart`, `flower_spec_test.dart` — it does not include `flower_palette.dart`, which is where every existing flower colour lives (`FlowerColors`, 51 lines, 36 constants). The token layer (`lib/design/tokens/**`) closed with Cluster A, so `Palette` is not an option either. E1 as written must either inline ten raw `Color(0xFF…)` literals into `flower_spec.dart` — breaking the project's own colour-constant convention, which E2 and E3 would then have to undo — or edit a file outside its fence.

*Resolution.* `flower_palette.dart` is added to **E1's** file list. It is already in E2's and E3's, and this cluster serialises strictly (see SERIALIZATION), so no new merge conflict is introduced. Every colour Cluster E introduces — the ten stroke colours, every new petal/centre fill in E2 and E3, and every garden stem/leaf/bloom colour in E4 — is a named `FlowerColors` constant. No raw `Color(0xFF…)` literal appears in `flower_spec.dart`, `bloom_geometry.dart`, `garden_plant_spec.dart` or either painter.

*Rejected: inline literals.* Convention break, plus E2/E3 rework.
*Rejected: new token-layer constants.* The token layer is closed (§6.2).

---

**R4 — `strokeColor` and `strokeWidth` are REQUIRED on every `FlowerSpec`, including the two legacy kinds. The E1 test asserts over the ten SELECTABLE kinds only.**

*Problem.* The parent's E1 acceptance criterion says "assert **every** spec carries a stroke colour and width and that none matches `Palette.ink` by default", while its "Must not regress" says of `wiltingRose` and `thistle`: "leave them alone; they are not selectable and are out of scope." Those two instructions cannot both be followed if the fields are required — all twelve constructors at `flower_spec.dart:39-173` must then be edited, including lines 150-172. If instead the fields carry a shared default, a single default cannot be per-flower, and the only sane one is `Palette.ink` — which the criterion forbids.

*Ground truth, verified.* There are exactly **12** `FlowerSpec` constructions in the repository, all inside the `flowerSpecFor` switch. **No test anywhere constructs a `FlowerSpec` directly**, so making the fields required breaks no fixture. `moodOrder` (`lib/domain/mood/mood.dart:36-47`) lists exactly ten moods mapping to the ten non-`ambientOnly` kinds. `ambientOnly` is **read nowhere in `lib/`** — nothing filters on it and nothing plants it; the only non-mood `FlowerBloom` constructions are hardcoded `FlowerKind.peony` (`lib/app/shell/sidebar_shell.dart:118`) and `FlowerKind.daffodil` (`lib/features/garden/widgets/garden_view.dart:34`). `wiltingRose` and `thistle` are therefore genuinely never painted, on any screen, today.

*Resolution.* `strokeColor` and `strokeWidth` are **required**. All twelve constructors are edited. The two legacy kinds receive a derived non-ink value each — `FlowerColors.wiltingRoseStroke = Color(0xFF4A5A68)` and `FlowerColors.thistleStroke = Color(0xFF5A3A6A)`, both taken verbatim from the prototype's own `_wiltingRose` (`:1048`, `stroke="#4a5a68"`) and `_thistle` (`:1049`, `stroke="#5a3a6a"`) entries — at width `1.3` and `1.3` respectively (`:1048`, `:1049`). This edit to `flower_spec.dart:150-172` is **additive, changes no pixel anywhere** (neither kind has a render site), and therefore preserves E1's "Garden pixel-unchanged" criterion. The parent's "leave them alone" is honoured in spirit: no style, geometry, colour or behaviour of either legacy kind changes.

*The E1 test assertion, exact wording.* E1 adds this case to `test/design/flowers/flower_spec_test.dart`, verbatim:

```dart
test('every selectable flower carries its own ink, never the shared ink token',
    () {
  for (final mood in moodOrder) {
    final spec = flowerSpecFor(mood.flower);
    expect(spec.strokeColor, isNot(Palette.ink), reason: mood.flower.name);
    expect(spec.strokeWidth, greaterThan(0), reason: mood.flower.name);
  }
});
```

and this second case, which pins the ten values so a transcription slip cannot pass:

```dart
test('each selectable flower is stroked at its prototype weight', () {
  const Map<FlowerKind, double> expected = <FlowerKind, double>{
    FlowerKind.chrysanthemum: 0.8,
    FlowerKind.aster: 0.9,
    FlowerKind.sunflower: 1.0,
    FlowerKind.lavender: 1.0,
    FlowerKind.daffodil: 1.2,
    FlowerKind.rose: 1.3,
    FlowerKind.poppy: 1.3,
    FlowerKind.bleedingHeart: 1.3,
    FlowerKind.peony: 1.4,
    FlowerKind.redSpiderLily: 1.8,
  };
  expected.forEach((kind, width) {
    expect(flowerSpecFor(kind).strokeWidth, width, reason: kind.name);
  });
});
```

*Rejected: iterate `FlowerKind.values`.* It forces the implementer to invent stroke values for two flowers the prototype itself underscore-prefixes as non-selectable and the parent's own stroke table omits. Iterating `moodOrder` is the honest scope; `mood_test.dart:48` already machine-enforces that every mood's flower is non-`ambientOnly`, so the ten/two split cannot silently drift.
*Rejected: optional fields defaulting to `Palette.ink`.* Directly contradicts the acceptance criterion and leaves a live path where a flower silently renders in the old shared brown.

---

**R5 — `lib/design/flowers/bloom_style.dart` joins E2's and E3's file lists, and gains exactly ONE new value: `partList`. Declared fence widening.**

*Problem.* The new render paths are selected by `switch (spec.style)` on `BloomStyle` (`flower_painter.dart:20-39`), and Dart switch exhaustiveness means a new path needs a new enum value. `bloom_style.dart` appears in **no** Cluster E file list — E1, E2, E3 and E4 all omit it. The alternative is overloading the existing seven names to mean something else — leaving Rose as `roundPetals` while it paints a spiral — which is exactly the kind of lie the no-comments rule leaves nothing to correct.

*Resolution.* `bloom_style.dart` is added to E2's and E3's file lists. E2 adds **one** value, `partList`, and no others. Every flower converted to the declarative part list (four in E2, six in E3) carries `style: BloomStyle.partList`; the two legacy kinds keep `roundPetals` and `puff` and keep their existing procedural render paths. `rayPetals`, `broadPetals`, `spiderPetals`, `spike` and `heartPendants` become unreferenced by production specs once E3 lands, but are **not deleted in this cluster** — deleting them is a separate cleanup with no shippable outcome, and `flower_painter.dart` must keep a render path for `roundPetals` and `puff` regardless.

Note `bloom_style.dart` sits in `lib/design/flowers/`, not `lib/design/tokens/`, so the token-layer freeze does not cover it.

*Rejected: five new enum values, one per new silhouette.* The geometry is data, not a code path — one interpreter serves all ten. Five values would each need a hand-written painter method and would re-create exactly the schema problem R6 solves.
*Rejected: overloading existing names.* Unfalsifiable and actively misleading.

---

**R6 — E2/E3 are a `FlowerSpec` SCHEMA replacement, not a value retune. The schema is fixed HERE so E2 and E3 cannot diverge.**

*Problem.* `FlowerSpec`'s current drawing vocabulary is `petalCount` / `petalColor` / `petalShade` / `centerColor` / `centerRadius` / `petalLength` / `petalWidth` / `droop` — seven scalars and two colours, all normalised fractions of `d`. **None of the ten targets is expressible in it.** Every target is a list of explicit `(cx, cy, r)` or `(cx, cy, rx, ry)` tuples, rotated ellipse rings, or literal Bezier path data in a 44-unit box. Worse, E2 lands first and E3 second: if E2 invents a schema that does not anticipate open stroked paths (Rose's arcs, Spider Lily's petals) or per-element stroke overrides (Aster's disc, Daffodil's corona ring 1, Spider Lily's stamens), E3 must redesign it mid-cluster.

*Resolution.* The schema is specified here in full. E2 builds all of it; E3 adds no new part type.

**New file `lib/design/flowers/bloom_part.dart`** — the drawable vocabulary, viewBox-agnostic (coordinates are plain numbers, so E4 reuses it at a 100-wide viewBox):

```dart
sealed class BloomPart {
  const BloomPart({
    this.fill,
    this.strokeColor,
    this.strokeWidth,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
  });

  final Color? fill;
  final Color? strokeColor;
  final double? strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
}

final class BloomDisc extends BloomPart { ... double cx, cy, r ... }

final class BloomOval extends BloomPart {
  ... double cx, cy, rx, ry, rotationDeg, pivotX, pivotY ...
}

final class BloomOvalRing extends BloomPart {
  ... int count; double cx, cy, rx, ry, startDeg, stepDeg, pivotX, pivotY ...
}

final class BloomShape extends BloomPart { ... List<BloomCmd> commands; bool close ... }
```

`BloomCmd` is a small sealed command list — `BloomMoveTo(x, y)`, `BloomLineTo(x, y)`, `BloomQuadTo(cx, cy, x, y)`, `BloomCubicTo(c1x, c1y, c2x, c2y, x, y)`, `BloomArcTo(rx, ry, largeArc, clockwise, x, y)` — mapping one-to-one onto `Path.moveTo` / `lineTo` / `quadraticBezierTo` / `cubicTo` / `arcToPoint`. `BloomArcTo` exists solely for Rose's two SVG `a` commands and maps directly onto `Path.arcToPoint(Offset(x, y), radius: Radius.elliptical(rx, ry), largeArc: …, clockwise: …)`. **No SVG string parser is written; no path-data string is stored.** Geometry is Dart values.

Resolution semantics, fixed:
- `fill == null` means **do not fill** (the SVG `fill="none"` case).
- `strokeColor == null` means **inherit the spec's** `strokeColor`; `strokeWidth == null` means inherit the spec's `strokeWidth`. This is how the SVG group inheritance in the source is expressed.
- A part that must be **unstroked** (Rose's centre, Daffodil's coronas 2 and 3, Chrysanthemum's centre, Spider Lily's centre) sets `strokeWidth: 0`. The painter treats `strokeWidth == 0` as "skip the stroke pass" — it does **not** treat a `null` colour that way.
- Parts are painted in list order. Within one part, fill is painted before stroke.

**`FlowerSpec` gains two named constructors** (`flower_spec.dart`):

```dart
class FlowerSpec {
  const FlowerSpec.parts({
    required this.kind,
    required this.parts,
    required this.strokeColor,
    required this.strokeWidth,
  })  : style = BloomStyle.partList,
        procedural = null;

  const FlowerSpec.procedural({
    required this.kind,
    required this.style,
    required this.procedural,
    required this.strokeColor,
    required this.strokeWidth,
  }) : parts = null;

  final FlowerKind kind;
  final BloomStyle style;
  final List<BloomPart>? parts;
  final ProceduralBloom? procedural;
  final Color strokeColor;
  final double strokeWidth;
}
```

`ProceduralBloom` carries the eight scalars plus `stemColor` / `leafColor` that only `wiltingRose` and `thistle` still need. **The ten selectable specs stop carrying meaningless ring scalars** — that is the point of the split.

**New file `lib/design/flowers/bloom_geometry.dart`** holds the per-flower `List<BloomPart>` constants (`peonyParts`, `roseParts`, …). E2 creates it with four; E3 adds six. `flower_spec.dart` stays a thin switch.

*Rejected: keep the flat schema and leave the scalars in place on converted specs.* It would keep `flower_spec_test.dart:14-22` green with no edit, which is tempting and wrong: ten specs would carry `petalCount: 12` describing art that has no petal ring. The code would state something false about itself, with no comment available to correct it.
*Rejected: nullable scalars with `!` at every legacy use.* Same information, uglier, and it puts a runtime crash where a type error belongs.
*Rejected: an SVG path-string parser.* A parser is a new subsystem with its own failure modes, written to consume constants the implementer types by hand anyway.

---

**R7 — E2 and E3 each keep the whole app green: only their own flowers convert.**

*Problem.* Between E2 and E3, six flowers still carry procedural specs while four carry part lists. If E2 removes the procedural render paths, those six render nothing.

*Resolution.* E2 converts exactly Peony, Rose, Poppy, Sunflower to `FlowerSpec.parts`. The other eight (six selectable + two legacy) keep `FlowerSpec.procedural` and their existing render paths, which E2 does not touch. E3 converts the remaining six. After E3, exactly two specs are procedural. **At every commit, `flowerSpecFor` resolves all twelve kinds and `FlowerPainter` has a live path for every `BloomStyle` value it can receive** — which is also what keeps `meadow_painter.dart:102` compiling and the Garden screen rendering (see the STANDING INVARIANT).

---

**R8 — Red Spider Lily: the centre circle is OUTSIDE the `fill="none"` wrapper, and the six petals are not rotationally generated.**

*Problem, part one.* `:1053` closes the `<g fill="none" stroke-linecap="round">` wrapper **before** `<circle cx="22" cy="23" r="2.4" fill="#7d1a14"/>`. Parent `:215` and E3 `:1278` describe the circle only as "centre `circle(22,23) r2.4` fill `#7d1a14`". An implementer who models the wrapper as inherited group state and puts the circle inside it gets `fill: none` — an **invisible centre**, which is precisely the current app bug this row exists to fix (today the centre is `0xFFC0392B`, identical to the petals, so it disappears).

*Resolution.* The centre disc is a `BloomDisc(cx: 22, cy: 23, r: 2.4, fill: FlowerColors.spiderLilyCore, strokeWidth: 0)` — filled, and explicitly **unstroked**. The prototype gives it no stroke.

*Problem, part two.* Parent `:1276` says "6 recurved quadratic petals" with no coordinates — a **BLOCKER**, and the obvious reading (a rotate-by-60-degree loop) is wrong. The six petals are **not** rotationally symmetric: the left three mirror the right three about `x = 22`, but the three per side differ from each other.

*Resolution.* All ten paths are given verbatim in §4's E3 geometry table. Write them as ten literal `BloomShape`s. Do not loop.

*Also corrected — parent `:215` says "Petal tips reach x=2..42, y=3".* Those extremes belong to the **stamens**, not the petals. Measured: petals span x 4.00..40.00, y 6.00..23.14; the full glyph including stamens spans x 2.00..42.00, y 3.00..25.40. Cosmetic in a findings row, load-bearing if read as a petal-length constant.

---

**R9 — Aster's petal ellipse centre is `cy = 8`. Daffodil's is `cy = 9`. Both were absent from the parent spec.**

*Problem.* Two **BLOCKERS**. Parent `:217` and E3 `:1259` give Aster as "12 ellipse petals rx2.3 ry7 every 30deg" with no `cx`/`cy`. Parent `:219` and E3 `:1233` give Daffodil as "6 petals ellipse rx4 ry8.5 at 60deg steps" with no `cx`/`cy`. `cy = 8` is unique to Aster in the whole set (Sunflower and Daffodil use 9, Chrysanthemum's rings use 7 and 12); it cannot be inferred.

*Resolution.* Verbatim from `:1054` and `:1055`: Aster `cx="22" cy="8"`, Daffodil `cx="22" cy="9"`. Both are in §4's E3 table. Every rotated-ellipse ring in this cluster pivots about **(22, 22)** in the compact set.

---

**R10 — Bleeding Heart's three hearts and three teardrops are literal cubics and literal triangles. They are not translations of one another.**

*Problem.* A **BLOCKER**. Parent E3 `:1264-1270` gives only "three, at x=13, x=22 (hung 3 lower, y=18), x=31" plus one example teardrop. The three hearts are four-segment cubic Beziers whose control points are not derivable from an x-position, and teardrops 2 and 3 are **not** translations of teardrop 1 on a common baseline — t1 and t3 run y 21 to 26, t2 runs y 24 to 29.

*Resolution.* All seven paths (arch + 3 hearts + 3 teardrops) are given verbatim in §4's E3 table, in the source's paint order: arch, then h1, t1, h2, t2, h3, t3 — each teardrop immediately after its own heart.

---

**R11 — Lavender's middle-row centre oval is at `cy = 16`, one unit above its flankers at `cy = 17`.**

*Problem.* Parent `:220` summarises the middle row as "(16/22/28,17)", flattening the asymmetry. Parent E3 `:1247` and `:1255` get it right and flag it as deliberate.

*Resolution.* Implement from §4's table, which carries `cy = 16` for the centre oval. Do not implement from the parent's §3.5 summary row. The asymmetry is what makes the spike read as tapering rather than banded.

---

**R12 — `FlowerPainter.shouldRepaint` is wrong today and must be fixed in E1.**

*Problem.* `flower_painter.dart:234-235` compares only `oldDelegate.spec.kind != spec.kind`. E1 adds a `headless` flag that the comparison would ignore, so a flip would not repaint; E2/E3 change specs whose `kind` is unchanged.

*Resolution.* E1 rewrites it to `oldDelegate.spec != spec || oldDelegate.headless != headless`. Because `FlowerSpec` has no `==` override, that reduces to identity on the const spec instances — which is correct and sufficient, since `flowerSpecFor` returns canonical const instances per kind. E4 drops the `headless` term when it deletes the flag (R15).

---

**R13 — E4's size ladder is TWO rows, not eight. Six rows are out of fence, already satisfied, or both.**

*Problem.* This is the C7 failure mode, and it is present in six of the eight rows of the parent's E4 ladder (`:1303-1312`). An implementer who takes the table at face value will either edit excluded files or report six no-ops as work.

*Row-by-row verdict, every anchor re-read against this base:*

| Parent row | Target | Actual current | Verdict |
|---|---|---|---|
| Today mood card 54 | 54 | **already 54** — `lib/features/mood/mood_banner.dart:35` | Out of fence by design (C2 owns it). Correctly excluded by the parent. |
| Empty-state ghost / day-detail strip 46 | 46 | **already 46** — `mood_banner.dart:86` `_promptBloomSize`, used at `:160` | **DROP.** `mood_banner.dart` is explicitly excluded from E4. No `FlowerBloom` exists in any day-detail strip. The parent's own "46 / varies" hedge is the tell. |
| Picker tile 44 | 44 | 56 — `lib/features/mood/mood_picker_grid.dart:12` | Out of fence by design (F2 owns it). Correctly excluded. |
| Calendar day cell 40 | 40 | **28** — `lib/features/calendar/widgets/calendar_day_cell.dart:51` | **KEEP.** Genuine work; E4 owns it. |
| Day-list / search row 40 | 40 | **already 40** — `lib/features/search/search_day_tile.dart:94` | **DROP.** That file is in no E4 file list, and the row is a no-op. |
| Nav brand lockup 32 | 32 | **already 32** — `lib/app/shell/sidebar_shell.dart:118` | **DROP.** The parent says "absent until B2"; B2 has merged and it is present at target. `sidebar_shell.dart` is not in E4's list and `lib/app/shell/**` is closed by Cluster B. |
| Week-garden cell 27 | 27 | **already 27** — `lib/features/today/this_week_garden.dart:90` (`bloomSize`), landed by `7aabf4b` | **DROP.** Stale *and* out of fence. |
| Garden tally chip 24 | 24 | **18** — `lib/features/garden/widgets/mood_tally_chips.dart:50` | **KEEP.** Genuine work; E4 owns it. |

*Resolution.* **E4's ladder is exactly two changes**: `calendar_day_cell.dart:51` from 28 to 40, and `mood_tally_chips.dart:50` from 18 to 24. `lib/features/search/search_day_tile.dart`, `lib/app/shell/sidebar_shell.dart`, `lib/features/today/this_week_garden.dart` and `lib/features/mood/mood_banner.dart` are **not** in E4's file list and must not be opened.

---

**R14 — `lib/features/garden/widgets/garden_view.dart:34`'s empty-state daffodil stays at 44, and E4 does not touch it.**

*Problem.* `const FlowerBloom(kind: FlowerKind.daffodil, size: 44)` — the garden empty-state icon — appears in **no** ladder row and in **no** Cluster E file list. It is the only `FlowerBloom` in the app the ladder does not account for. Left undecided, an implementer either "fixes" it to some invented value or silently notices the inconsistency and widens scope.

*Resolution.* **Leave it at 44.** The parent's own §3.5 ladder row records "garden empty-state 44 (no counterpart)" — the prototype has no garden empty state, so there is no target value to align to. `garden_view.dart` is not added to E4's file list. It will render its glyph in the new headless art (correctly, via `FlowerBloom`) at its existing size. This is a decision, not an oversight.

---

**R15 — E4 derives the tall plant box INSIDE the painter. `meadow_layout.dart` is not edited.**

*Problem.* `meadow_painter.dart:95-105` paints `Size.square(bloom.size)` after `canvas.translate(-bloom.size * 0.5, -bloom.size * 0.98)`. The bloom **box** is sized upstream at `lib/features/garden/model/meadow_layout.dart:71-80` (`final double bloomSize = …`), and `meadow_layout.dart` is not in E4's file list. A 1:1 square cannot become a 1.9–2.4 tall box without either changing the layout model (out of fence) or deriving the height in the painter (in fence).

*Resolution.* `GardenPlantSpec` carries its own `ratio`. `_paintBloom` computes `final double h = bloom.size * spec.ratio;` and paints `Size(bloom.size, h)`, with the translate becoming `canvas.translate(-bloom.size * 0.5, -h)` so the plant is **bottom-anchored at the sway pivot** — the Flutter equivalent of `preserveAspectRatio='xMidYMax meet'` plus `transformOrigin:'bottom center'` (`:1198`, `:1487`). `meadow_layout.dart` and `PlantedBloom` are unchanged; `bloom.size` keeps meaning **width**. This mirrors the prototype exactly: `_flowerItem` (`:1484`) computes `w` from depth and then `h = Math.round(w * model.ratio)`.

*Rejected: widening to `meadow_layout.dart`.* Unnecessary — one scalar plus a per-spec ratio already carries the information — and it would put a rendering concern into the layout model.

---

**R16 — E4 reuses `BloomPart` at a 100-wide viewBox. `GardenPlantSpec` adds only a viewBox height and a ratio.**

*Problem.* The garden plants are a second, entirely separate art set (`:1069-1070`: "COMPLETE botanical plant models … (garden page only)"), authored at `0 0 100 <h>`. Inventing a second geometry vocabulary for them would double the schema surface.

*Resolution.* `BloomPart` coordinates are plain numbers with no baked-in viewBox, so `garden_plant_spec.dart` reuses it unchanged:

```dart
class GardenPlantSpec {
  const GardenPlantSpec({
    required this.kind,
    required this.viewBoxHeight,
    required this.parts,
    required this.strokeColor,
    required this.strokeWidth,
  });
  double get ratio => viewBoxHeight / 100.0;
  ...
}
```

`GardenPlantPainter` scales by `size.width / 100` and issues **no** clip (R2). The `ratio` is derived, not typed twice, which removes any chance of a spec whose stated ratio disagrees with its viewBox.

**CORRECTION to parent `:1299`.** Its observed-height list "190, 196, 200, 205, 206, 210, 214, 236 and 240" is correct as a set over all twelve prototype entries, but **206 exists only on `_thistle`** (`:1178`) — a legacy kind with no render site, ruled out of scope by the parent's own E1 — and 196 is shared by `grateful` and the equally out-of-scope `_wiltingRose`. For the ten selectable moods the distinct heights are **eight**, not nine: 190, 196, 200, 205, 210, 214, 236, 240. A `GardenPlantSpec` set built from the parent's list would carry one unreachable ratio.

---

**R17 — N21's cited symbol DOES NOT EXIST. The correct name is `resolveGardenMotion`.**

*Problem.* Preserve item N21, quoted in the parent's E4 "Must not regress" and in every prior slice, names `resolveGardenMotionProfile`. **Zero hits in `lib/` and `test/`.** The preserve item fused the return enum's name onto the function's. An implementer who greps the cited symbol to verify the invariant gets nothing and cannot tell whether the invariant is broken or the citation is.

*Resolution, verified against the base:*

| Thing | Real location |
|---|---|
| `GardenMotionProfile` (the enum, `full` / `reduced`) | `lib/features/garden/model/garden_motion.dart:3` |
| `resolveGardenMotion` (the function) | `garden_motion.dart:5-13` — signature `:5-9`, guard body `:10-13` |
| `defaultMaxAnimatedBlooms = 140` (the ceiling) | `garden_motion.dart:1` |
| Call site | `lib/features/garden/widgets/garden_view.dart:43-49` — `:43-44` reads `MediaQuery.maybeOf(context)?.disableAnimations`, `:45-49` calls `resolveGardenMotion(reduceMotion:, bloomCount:)` |

The parent's `garden_motion.dart:6-12` span is off by one and its `garden_view.dart:43-47` span clips the call. **N21 is restated with these anchors throughout this slice.** The motion routing is intact and is unaffected by a painter swap: E4 changes what is drawn per bloom, not whether or how the meadow animates. **E4 must not edit `garden_motion.dart` or the motion block in `garden_view.dart`.**

---

**R18 — E4 deletes the stem path and the `headless` flag; it does NOT delete the procedural render paths.**

*Problem.* The parent says the stem cleanup "belongs to E4, not E1", but does not say how far it goes. Over-reaching deletes render paths `wiltingRose` and `thistle` still need and breaks the `flowerSpecFor` switch.

*Resolution.* Once E4's meadow calls `GardenPlantPainter`, **nothing** calls `FlowerPainter` with a stem. E4 deletes `_straightStem`, `_stemStroke` and the `headless` parameter, and makes the clip-and-scale transform (R1) unconditional. `_paintRadial`, `_paintSpike` and `_paintPuff` **stay** — `flowerSpecFor` must keep resolving all twelve kinds, and `roundPetals` and `puff` must keep a live case. `stemColor` and `leafColor` move to `ProceduralBloom` in E2 (R6) and are consumed only by the two legacy kinds thereafter; they are not deleted.

---

**R19 — `Palette.sunGlow` and the garden palette hexes are preserved, verified.**

`grep -c f4c960` against the prototype returns **0** — `Palette.sunGlow = Color(0x8CF4C960)` (`lib/design/tokens/palette.dart:70`) is a genuine additive enrichment the prototype does not draw. **Keep it** (§2.6, preserve item). The meadow gradient hexes `#D6DBAC`, `#C4CE95`, `#B1BD80`, `#A0B371`, `#96AA69` are all verbatim in the prototype desktop meadow at `:223`, and the soil band `#8A6C44`, `#775A37` at `:229`. They stay.

*Noted so nobody chases it:* the **phone** meadow at `:609` ends on `#9caf6d` instead of `#a0b371`/`#96aa69`. That is not a spec claim and is not Cluster E work.

---

**R20 — The N24 file paths quoted in shorthand are wrong. The real paths are under `test/features/entry_cards/`.**

*Problem.* N24 has been circulated in a shorthand form naming `test/playback/video_slots_test.dart` and seven files "under `test/cards/`". Neither directory exists.

*Resolution.* The eight untouchable files, verified present on this base:

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

**Cluster E has zero exposure to any of them**, confirmed by path disjointness against every E1–E4 file list. Not one appears among the test files referencing `FlowerSpec`, `flowerSpecFor`, `FlowerPainter`, `FlowerBloom`, `BloomStyle`, `FlowerKind`, `MeadowPainter`, the garden, calendar cells or tally chips.

---

**R21 — Chrysanthemum's inner ring is 9 ellipses at a 40-degree step starting at 20 degrees, which does not close the circle. That is correct.**

*Problem.* 9 x 40 = 360, so the ring **does** close — but the naive reading "9 petals evenly spaced" gives a 40-degree step from 0, not from 20. The 20-degree offset is what interleaves the inner ring between the outer ring's 30-degree spokes. An implementer computing `i * 360 / 9` gets 40-degree steps from 0 and a visibly different bloom.

*Resolution.* Inner ring is `startDeg: 20, stepDeg: 40, count: 9`; outer ring is `startDeg: 0, stepDeg: 30, count: 12`. Verified verbatim at `:1056`.

---

**R22 — The compact and garden art sets are genuinely different art. Do not derive one from the other.**

*Problem.* A reasonable optimisation is to reuse the compact bloom head as the garden plant's head and just add a stem. It is wrong, and it would silently discard designed work.

*Resolution, with evidence.* The garden sunflower is **15** petals at 24 degrees, `rx5 ry13.5`, disc `r17` at (50,56), plus 11 seed dots (`:1076-1082`); the compact sunflower is 8 petals at 45 degrees, `rx3.4 ry7`, disc `r7` at (22,22). The garden chrysanthemum has **four** rings (18/15/12/9 at `r` 22/16/11/6) against the compact two. The garden daffodil is 6 petals `rx7 ry14` at `cy43` about pivot (50,60) against the compact `rx4 ry8.5` at `cy9` about (22,22). The garden rose adds thorns (`:1140`) and sepals (`:1146`); the garden poppy adds a nodding bud (`:1162`). E4 ports the garden models from §4's E4 tables, verbatim, and does not scale up the compact set.

---

### HARD SCOPE FENCE

This run ships **exactly four MSPs: E1, E2, E3, E4.** No others.

- Do **not** create MSPs for clusters A, B, C, D, F, G or H. They are named below only so cross-cluster dependencies stay legible. Clusters A–D are already merged; re-implementing any part of them is a defect, not a dependency.
- The complete set of files this run may touch is:

  | File | Owning MSP | New? |
  |---|---|---|
  | `lib/design/flowers/flower_spec.dart` | E1, E2, E3 | no |
  | `lib/design/flowers/flower_painter.dart` | E1, E2, E3, E4 | no |
  | `lib/design/flowers/flower_palette.dart` | E1, E2, E3, E4 | no (**declared fence widening for E1** — R3) |
  | `lib/design/flowers/flower_bloom.dart` | E1 | no |
  | `lib/design/flowers/bloom_style.dart` | E2 | no (**declared fence widening** — R5; adds exactly one value) |
  | `lib/design/flowers/bloom_part.dart` | E2 | **new** (R6) |
  | `lib/design/flowers/bloom_geometry.dart` | E2, E3 | **new** (R6) |
  | `lib/design/flowers/garden_plant_spec.dart` | E4 | **new** |
  | `lib/design/flowers/garden_plant_painter.dart` | E4 | **new** |
  | `lib/features/garden/paint/meadow_painter.dart` | E4 | no |
  | `lib/features/calendar/widgets/calendar_day_cell.dart` | E4 | no |
  | `lib/features/garden/widgets/mood_tally_chips.dart` | E4 | no |
  | `test/design/flowers/flower_spec_test.dart` | E1, E2, E3 | no (**existing**, 5 cases) |

- **Three declared fence widenings**, each bounded and each carrying the standard obligation that every other consumer's tests pass **unmodified**:
  - **E1 gains `flower_palette.dart`** (R3). Bounded to adding `FlowerColors` constants. No existing constant is renamed or removed in E1.
  - **E2 gains `bloom_style.dart`** (R5). Bounded to adding exactly one enum value, `partList`. No existing value is renamed or removed.
  - **E2 and E3 create `bloom_part.dart` and `bloom_geometry.dart`** (R6). Both are new files inside `lib/design/flowers/`, the directory the cluster already owns. Neither is referenced by anything outside it.
- Named traps, each of which an MSP is explicitly forbidden to touch and each of which a reasonable implementer might otherwise edit:
  - `lib/design/tokens/**` — closed by Cluster A. No rename, no removal, no addition. Every colour this cluster introduces goes to `FlowerColors` (R3).
  - `lib/domain/mood/flower_kind.dart` and `lib/domain/mood/mood.dart` — the enum values, their display strings and the mood-to-flower mapping are exact and must not change. Neither file is in any file list above.
  - `lib/features/garden/model/garden_motion.dart` and the motion block at `lib/features/garden/widgets/garden_view.dart:43-49` — N21 (R17). E4 changes what a bloom draws, never how the meadow decides to animate.
  - `lib/features/garden/model/meadow_layout.dart` — R15. The tall box is derived in the painter.
  - `lib/features/mood/mood_banner.dart` (C2's), `lib/features/mood/mood_picker_grid.dart` (F2's), `lib/features/today/this_week_garden.dart`, `lib/features/search/search_day_tile.dart`, `lib/app/shell/sidebar_shell.dart`, `lib/features/garden/widgets/garden_view.dart` — every one of these was a parent-spec ladder row and every one is out of fence, already at target, or both (R13, R14).
  - `lib/features/entry_cards/**` and every file named in R20's table — untouchable infrastructure. **If your diff touches one of those eight files, you have gone out of bounds — stop and report.**
- If decomposition suggests a unit outside E1–E4, that is a signal the parent spec should be re-dispatched for the relevant cluster — **not** a licence to widen this run. Stop and report.

### SERIALIZATION — read before planning parallelism

**There is no parallelism available in this cluster. E1, then E2, then E3, then E4 — strictly sequential, one wave each.**

This is stated flatly because the parent spec invites the opposite: its E3 header says "may run in parallel with E2; both touch the same files, so merges serialize." That is a contradiction — two MSPs that rewrite the same two files are not parallel-safe, they are sequential with extra rebases. This slice removes the invitation.

| Shared file | Claimed by | Edge |
|---|---|---|
| `lib/design/flowers/flower_spec.dart` | E1, E2, E3 | **E1 -> E2 -> E3** |
| `lib/design/flowers/flower_painter.dart` | E1, E2, E3, E4 | **E1 -> E2 -> E3 -> E4** |
| `lib/design/flowers/flower_palette.dart` | E1, E2, E3, E4 | **E1 -> E2 -> E3 -> E4** |
| `lib/design/flowers/bloom_geometry.dart` | E2, E3 | **E2 -> E3** |
| `test/design/flowers/flower_spec_test.dart` | E1, E2, E3 | **E1 -> E2 -> E3** |

Beyond file contention there are two hard **contract** edges, which would force the same order even if the files were disjoint:

- **E2 -> E3**: E2 authors the `BloomPart` vocabulary and the `FlowerSpec.parts` constructor (R6). E3 consumes both and adds no new part type. E3 cannot start against a schema that does not exist.
- **E3 -> E4**: E4's `GardenPlantSpec` reuses `BloomPart` (R16), and E4 deletes the stem path (R18), which is only safe once every selectable flower has been converted and the meadow is the last stemmed consumer.

```
E1  (stroke contract + headless flag)
 |
E2  (BloomPart vocabulary + 4 flowers)
 |
E3  (6 flowers, same vocabulary)
 |
E4  (garden plant set + 2 ladder sites + stem-path deletion)
```

The repo squash-merges, so once an MSP lands, `main` holds its content under a SHA absent from the next branch's history. Each MSP rebases `--onto main` after its predecessor merges and re-runs `fullValidationCmd` on the new base. **Never carry a green from one base to another.**

### THE STANDING INVARIANT — the Garden screen renders correctly at EVERY commit

This governs every MSP in this cluster and outranks any convenience.

`FlowerPainter` has exactly two callers, verified exhaustively — there are no others anywhere in `lib/` or `test/`:

1. `lib/design/flowers/flower_bloom.dart:41` — the compact glyph.
2. `lib/features/garden/paint/meadow_painter.dart:102` — every meadow bloom.

Because the meadow shares the painter, **every geometry change in E2 and E3 is also a Garden change**, and the Garden keeps its stems until E4 replaces the painter entirely. Concretely:

- **E1** adds `FlowerPainter(spec, {bool headless = false})` and sets `headless: true` at `flower_bloom.dart:41` **only**. `meadow_painter.dart:102` keeps the default `false` and therefore keeps its stems and leaves, rendering exactly as it does today. **Deleting `_straightStem` in E1 would leave the Garden full of stemless floating heads — an MSP that ships a visibly broken screen, which the green-branch invariant forbids.**
- **E2 and E3** change petal geometry the still-stemmed meadow also draws. The meadow will look different after each — that is expected and acceptable, because a stemmed plant with the new bloom head is a coherent picture. What is **not** acceptable is a meadow that renders blank, clipped, inverted or overflowing. Check the Garden screen after E2 and after E3, not only the compact glyphs.
- **E4** swaps the meadow to `GardenPlantPainter` and only then deletes the stem path (R18).

An MSP that ships a visibly broken screen violates the green-branch invariant regardless of test results. Tests do not assert pixels here; the manual pass in §5.4 is load-bearing.

---

## 1. BLUF

The flower is this app's signature. It appears on the Today mood card, in every calendar cell, on every day-list row, in the week garden, in the mood picker, on search results, in the nav lockup, on the garden tally chips, and as every plant in the meadow. **Cluster E is the only cluster that touches all of them at once**, and it is the last large art gap between the app and the design.

**Cluster E's share.** Every compact glyph is currently a stemmed, leafed plant squeezed into an icon-sized box, with the bloom head pushed to the top 55% and a stem trailing to the bottom of the frame — where the design draws a headless bloom head filling the box (E1). Every flower is outlined in the same dark brown `Palette.ink` at the same clamped 1.5px, where the design gives each flower its own darkened-relative ink across a 0.8-to-1.8 weight span (E1). Nine of the ten silhouettes are wrong in kind, not in degree: happy is a 24-petal daisy where the design draws a five-blob peony; loved is a coral 16-petal daisy where the design draws a pink spiral rose; anxious is a **blue** 22-ray starburst where the design draws a **violet** 12-petal aster; angry is a solid red eight-armed pinwheel with an invisible centre where the design draws a delicate unfilled six-stroke spider lily (E2, E3). And the garden meadow paints those same icon-sized flowers into a 1:1 box, where the design grows a completely separate set of tall botanical plants — stems, leaves, thorns, sepals, buds — anchored to the soil line at aspect ratios from 1.9 to 2.4 (E4).

**Cluster E touches no token file and adds no token-layer primitive.** It adds colour constants to `FlowerColors`, one `BloomStyle` value, and four new files, all inside `lib/design/flowers/`. Three of those are declared fence widenings (R3, R5, R6), each bounded and each obliged to leave every other consumer's tests passing unmodified.

**Aligned means**: every value in the geometry tables below matches its cited prototype line; every capability in §2 still works and still passes its existing tests, retargeted only where a rewrite mandates it and unmodified everywhere else; and no prototype value has been adopted where doing so would break a preserved behaviour.

---

## 2. Non-negotiables

These are constraints, not suggestions. Every MSP that touches the named files inherits them. Chrome may be restyled; behaviour may not regress.

**Scoping note for this run.** The full non-negotiable set N1–N25 is defined in the parent spec. This slice reproduces in full only the rows Cluster E can reach, and names the rest by number. That is a deliberate departure from the D slice, which carried all twenty-five: Cluster E's exposure is narrow and concentrated (three rows), and padding the document with twenty-two inapplicable rows would bury the three that matter.

**N1–N20, N22 and N23 are unreachable from this run**, confirmed by path disjointness against every file in §0's fence: no MSP here edits `lib/features/entry_cards/**`, `lib/features/capture/**`, `lib/features/settings/**`, `lib/features/data/**`, `lib/features/search/**`, `lib/features/day_detail/**` or `lib/features/sound/**`. They are preserved by non-contact.

### 2.1 The three rows that bind THIS run

| # | Constraint | Verified citation |
|---|---|---|
| **N21** | **Any change to garden motion routes through the garden-motion resolver.** The OS `disableAnimations` signal and the bloom-count ceiling must both continue to force the reduced profile. | **CORRECTED (R17)** — the resolver is `resolveGardenMotion` at `lib/features/garden/model/garden_motion.dart:5-13`; the enum `GardenMotionProfile` is at `:3`; the ceiling `defaultMaxAnimatedBlooms = 140` is at `:1`; the call site is `lib/features/garden/widgets/garden_view.dart:43-49`. The parent's `resolveGardenMotionProfile` does not exist. |
| **N24** | **`ValueKey`s and Semantics labels are a public contract, not implementation detail.** May not be renamed. If a rewrite breaks any test in the eight-file playback suite, the correct response is to fix the implementation — **never to delete or weaken the test.** | The eight files, with **corrected paths**, are tabulated at R20. Cluster E has zero exposure. |
| **N25** | **Blooms keep their accessible labels** — `Semantics(image: true)` plus the mood/flower label wrapper — at **every** size site, and mood picker tiles keep their button + selected semantics. No prototype counterpart; preserve. | `lib/design/flowers/flower_bloom.dart:35-37` (the `Semantics` wrapper, `label: semanticLabel ?? kind.label`, `image: true`); `lib/features/mood/mood_picker_grid.dart:57-60`. |

**N25 in practice, for this cluster.** Every glyph in the app is rendered through `FlowerBloom`, and the `Semantics` wrapper is at `flower_bloom.dart:35-37`, **outside** the `SizedBox`/`CustomPaint` that E1 modifies. No MSP here has a reason to restructure that widget beyond passing `headless: true` into the painter at `:41`. `test/design/flowers/flower_bloom_test.dart:34-36` asserts `find.bySemanticsLabel('Peony')` and is the standing receipt: it must stay green **unmodified** through E1, E2, E3 and E4. E4's two size changes (`calendar_day_cell.dart:51`, `mood_tally_chips.dart:50`) both go through `FlowerBloom.forMood`, which supplies `semanticLabel: mood.label` (`flower_bloom.dart:26`) — so the label survives a size change by construction, and neither call site may be converted to a raw `CustomPaint`.

### 2.2 Additive elements to preserve, not delete

These have no prototype counterpart. They are enrichments. They are re-homed into prototype chrome, never removed.

| Element | Citation | Endangered by |
|---|---|---|
| `Palette.sunGlow = Color(0x8CF4C960)` garden sun glow | `lib/design/tokens/palette.dart:70` | **E4** — see R19. Keep it. |
| Garden empty-state daffodil at size 44 | `lib/features/garden/widgets/garden_view.dart:34` | **E4** — see R14. Leave it at 44; the file is out of fence. |
| The two ambient-only legacy kinds `wiltingRose`, `thistle` | `lib/domain/mood/flower_kind.dart:12-13`; `lib/design/flowers/flower_spec.dart:150-172` | **E1** (required stroke fields), **E2/E3** (schema change) — see R4, R6, R7. They keep resolving and keep a live render path at every commit. |
| No grain/noise layer on either side | `grep -rni "grain\|noise\|turbulence" lib/` returns zero hits | nothing in this run |

### 2.3 Preserve-to-MSP binding — the rows that bind THIS run

| Preserve item | Endangered by | Carried as a constraint in |
|---|---|---|
| **N25** bloom Semantics + picker tile semantics | **E1** (touches `flower_bloom.dart`), **E4** (changes two glyph sizes) | E1 and E4 "Must not regress"; receipt is `flower_bloom_test.dart:34-36`, unmodified |
| **N21** garden motion routing | **E4** (replaces the meadow's per-bloom painter) | E4 "Must not regress", with R17's corrected anchors |
| **N24** keys, labels, the eight playback files | nothing in this run — confirmed by path disjointness | §0's fence, R20, §5.3 gate 2 |
| `Palette.sunGlow` | **E4** (meadow work) | E4 "Must not regress", R19 |
| Legacy kinds keep resolving | **E1, E2, E3** | R4, R7; receipt is `flower_spec_test.dart:8-12`, unmodified |
| Garden empty-state glyph | **E4** (ladder temptation) | R14; the file is out of fence |

---

## 3. Findings that Cluster E implements

Reproduced from the parent spec's §3.5. **Four cells are corrected**, marked inline. Two of the four (`Compact glyph silhouette`, `Glyph size ladder`) are corrections of substance an implementer would otherwise act on.

| Element | Prototype | Current app | Sev | Citations |
|---|---|---|---|---|
| Compact glyph silhouette | `flower(mood)` glyphs are **headless**: no stem, no leaf, on 9 of 10 flowers. Bleeding Heart alone carries an arching branch stroked `#6f8a4e` at width 1.8 — and it is a **short top arc**, not a descending stem. **CORRECTION**: the parent's cell adds "viewBox `0 0 44 44` filled edge-to-edge by the bloom only." That is false for six of ten flowers (bbox table at R1). The glyphs share one viewBox and one uniform scale; they do **not** each fill it | `FlowerPainter.paint()` calls `_straightStem()` before every style except `heartPendants`, drawing a stem to `size.height*0.98` (`spec.stemColor` `#A0B371`, width `max(1.5, d*0.045)`) plus a filled leaf lobe at `y = height*0.72`. The bloom head is pushed to `center = (width/2, height*0.42)`, occupying only the top ~55% | critical | proto `:1044-1057`, `:1064` (the viewBox), `:1052` / `lib/design/flowers/flower_painter.dart:16-40`, `:73-89` |
| Art-set architecture | **Two entirely separate sets.** `flower(mood)` = a 44x44 headless glyph for chips, calendar, week, day shelf and picker (`:1061`). `gardenPlant(mood)` = a separately memoized full botanical plant with its own stem, leaves, thorns, sepals and buds at a **tall** viewBox, rendered `preserveAspectRatio='xMidYMax meet'` (bottom-anchored). The two sets are different art, not two sizes of one (evidence at R22) | **One painter serves both.** The meadow calls `FlowerPainter(flowerSpecFor(bloom.kind)).paint(canvas, Size.square(bloom.size))` — a 1:1 box — and the same painter and spec serve every compact site | critical | proto `:1062-1067`, `:1069-1073`, `:1198` / `lib/features/garden/paint/meadow_painter.dart:95-105`, `lib/design/flowers/flower_bloom.dart:40-43` |
| Per-flower stroke colour | Every flower has its own stroke hue, a darkened relative of its petal | One stroke `Paint` for all 12 specs: `color = Palette.ink` `0xFF4A3B2E`. `FlowerSpec` has no per-flower stroke colour field at all | high | proto `:1045-1056` / `lib/design/flowers/flower_painter.dart:42-47`, `lib/design/flowers/flower_spec.dart:9-37` |
| Per-flower stroke width | Varies across a 0.8–1.8 span in the 44-unit box | `strokeWidth = max(Shapes.outlineWidth 1.5, d * 0.03)` for every flower — at 56px that is 1.68; at 44px and below it clamps to a flat 1.5 | medium | proto `:1045-1056` / `lib/design/flowers/flower_painter.dart:45` |
| Peony (happy) | 6 overlapping circles; stroke `#8a4a4a` width 1.4, linejoin round | `roundPetals`, petalCount 12 -> 12 teardrops plus a second offset ring of 12 = **24 petal shapes**, plus a centre circle. Centre `0xFFEFC7A0` is a peach/tan, not pink | critical | proto `:1045` / `flower_spec.dart:40-50`, `flower_painter.dart:91-124` |
| Rose (love) | Filled disc with **two open spiral arcs** (`fill:none`) and an unstroked centre. A spiral, not a petal ring | `roundPetals`, petalCount 8 -> 16 shapes. **No arc-drawing code anywhere in the painter** — verified: the painter uses only `moveTo`/`lineTo`/`cubicTo`/`quadraticBezierTo`/`drawOval`/`drawCircle`. Petal `0xFFC76A54` (the brand coral) | critical | proto `:1047` / `flower_spec.dart:51-61` |
| Red Spider Lily (angry) | **All-stroke**, `fill='none'` on the wrapper. 6 recurved quadratic petals, **4** thin stamens, centre filled `#7d1a14` **outside** the wrapper and unstroked. **CORRECTION**: the parent's "petal tips reach x=2..42, y=3" describes the **stamens**; petals span x 4.00..40.00, y 6.00..23.14 (R8) | `spiderPetals`, petalCount 8: each petal a **closed** quadratic loop **filled** `0xFFC0392B` and stroked in ink, with one straight stamen per petal (8), plus a centre `r=0.06d` filled `0xFFC0392B` — identical to the petal, **so the centre disappears** — plus a stem and leaf | critical | proto `:1053` / `flower_spec.dart:139-149`, `flower_painter.dart:126-148` |
| Sunflower (warm) | 8 ellipse petals `rx3.4 ry7` at `cx22 cy9` rotated 0/45/…/315 about (22,22); centre disc `r7`; group stroke `#9a6a2a` width 1 | `rayPetals`, petalCount **16**. No rotated-ellipse primitive exists: `drawOval` is axis-aligned and is used only in `_paintSpike`/`_paintPuff` with no `canvas.rotate` | high | proto `:1046` / `flower_spec.dart:62-72` |
| Aster (anxious) | 12 ellipse petals `rx2.3 ry7` at `cx22 cy8` every 30deg, fill `#a892cf` (**violet**); centre `r5.5` with its **own** stroke. **CORRECTION**: `cy=8` is absent from the parent and is unguessable (R9) | `rayPetals`, petalCount **22**. Petal `0xFF7E8FC9` (periwinkle **blue**, hue ~225 vs ~264). Centre gets the shared ink stroke; there is no per-element stroke override anywhere in the painter | high | proto `:1054` / `flower_spec.dart:106-116` |
| Chrysanthemum (grateful) | **Two petal rings** — outer 12 at 30deg from 0, inner 9 at 40deg from **20** (R21) — plus an unstroked centre; stroke `#b9701f` width 0.8, the thinnest glyph in the set. The glyph **overflows its viewBox and is clipped** (R2) | `rayPetals`, petalCount 20 — a **single** ring. The second-ring branch exists at `flower_painter.dart:108-121` but is gated `rounded && petalCount >= 8`, and `rayPetals` sets `rounded: false`, so it is excluded exactly as the parent says. The existing second ring is also a scaled copy (`length*0.6`, `width*0.7`) at a half-step offset, not an independent ring pair | high | proto `:1056` / `flower_spec.dart:73-83`, `flower_painter.dart:108-121` |
| Daffodil (hopeful) | 6 petals `ellipse rx4 ry8.5` at `cx22 cy9`, 60deg steps, then a **three-ring trumpet**. **CORRECTION**: `cy=9` is absent from the parent (R9) | 6 `rayPetals` (count matches) but the corona is a **single flat circle** `r=0.14d` with the generic ink stroke | high | proto `:1055` / `flower_spec.dart:84-94` |
| Lavender (calm) | 9 upright ellipses in a fixed symmetric **1-2-3-2-1** taper, every `rx`/`ry` explicit; middle-row centre at `cy=16`, one unit above its flankers (R11). No centre, no stem, no leaf | `spike`: 9 ovals placed by a loop, alternating strictly left/right (`side = (i.isEven ? -1 : 1) * spread`) with `spread` growing 0.4 to 1.0. A **zig-zag two-column ladder**, not the taper. Nine explicit `(cx, cy, rx, ry)` tuples cannot be expressed by it at all. Plus a stem and leaf | high | proto `:1051` / `flower_spec.dart:95-105`, `flower_painter.dart:150-168` |
| Bleeding Heart (sad) | A short top arch and **three** pendant hearts, each with a white teardrop; all seven paths literal (R10) | `heartPendants` with petalCount **4**. The "arch" is a long cubic from `(0.20w, 0.95h)` to `(0.85w, 0.18h + 0.05d)` — it **descends to the bottom** of the box like a stem. Branch colour is `spec.stemColor 0xFFA0B371` (much lighter, yellower) | high | proto `:1052` / `flower_spec.dart:128-138`, `flower_painter.dart:194-221` |
| Poppy (tired) | 4 equal lobes `circle r8`, centre `circle r5 #3a2420`, stroke `#7d2a24` width 1.3. Structurally the closest of any flower | `broadPetals`, petalCount 4 — but four **teardrop cubics** (`_petal`, `flower_painter.dart:60-71`), not four circles at fixed coordinates. Colour-only correction is not enough; the geometry differs | medium | proto `:1050` / `flower_spec.dart:117-127` |
| Glyph size ladder | Desktop: 54 Today mood card, 46 empty-state ghost, 44 picker tile, 40 calendar cell and day-list row, 32 nav brand, 27 week-garden cell, 24 garden tally chip | **CORRECTION**: six of the eight parent rows are stale, out of fence, or both — the full row-by-row audit is at R13. Genuinely wrong today: calendar cell **28** (target 40) and garden tally chip **18** (target 24). Everything else is already at target or owned by C2/F2 | medium | proto `:94`, `:101`, `:444`, `:203`, `:255`, `:61`, `:158`, `:219` / see R13 for the per-row app anchor |

---

## 4. MSP decomposition — Cluster E

**The governing invariant**: merging any MSP must leave the branch's app fully working, and specifically must leave the **Garden screen** rendering correctly (see §0's STANDING INVARIANT). No MSP may depend on a surface a later MSP creates. Ordering is the strict sequence in §0.

The parent spec's full cluster set, for dependency legibility only. **Only Cluster E is in this run.**

| Cluster | Theme | MSPs | In this run |
|---|---|---|---|
| A | Foundations: tokens, primitives, the dialog Material fix | A1 – A5 | **merged** |
| B | Window chrome and nav rail | B1 – B4 | **merged** |
| C | Today centre column | C1 – C7 | **merged** |
| D | Today right rail | D1 – D4 | **merged** |
| E | Flower art | E1 – E4 | **YES** |
| F | Mood picker | F1 – F4 | no |
| G | Capture composers | G1 – G8 | no |
| H | Verification infrastructure | H1 | no |

Within Cluster E: E1 depends on A1 (merged). E2 depends on E1. E3 depends on E2 (**not** merely on E1 — see §0's SERIALIZATION, which corrects the parent). E4 depends on E3.

---

### E1 — Flower spec contract: headless glyphs and per-flower ink

**Outcome**: the compact glyph is a bloom head drawn at its authored scale in its own box, outlined in its own tinted ink at its own weight. The Garden is pixel-unchanged.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `lib/design/flowers/flower_palette.dart` (**declared widening**, R3), `lib/design/flowers/flower_bloom.dart`, `test/design/flowers/flower_spec_test.dart`

**Depends on**: A1 (merged).

**Target contract changes**

1. **`FlowerSpec` gains required `strokeColor` and `strokeWidth`**, both in 44-unit viewBox units, scaled at paint time by `d / 44`. All twelve constructors are edited (R4). The shared `Paint _stroke(double d)` at `flower_painter.dart:42-47` stops hardcoding `Palette.ink` and stops computing `math.max(Shapes.outlineWidth, d * 0.03)`; it becomes `..color = spec.strokeColor` and `..strokeWidth = spec.strokeWidth * d / 44`.

2. **`FlowerPainter` grows `{bool headless = false}`.** E1 sets `headless: true` at `flower_bloom.dart:41` **only**. `meadow_painter.dart:102` keeps the default and keeps its stems — this is the STANDING INVARIANT and is not optional. `_straightStem` and `_stemStroke` are **not deleted in E1** (R18).

3. **On the headless path only**, the render transform becomes R1's uniform 44-to-`d` map with R2's clip. The stemmed path keeps `center = Offset(width/2, height*0.42)` and its existing per-flower normalised scalars, so the meadow's composition is unchanged. Note that under R1 there is no separate "centre" variable on the headless path at all: geometry is drawn in raw 44-unit coordinates and the transform does the placing.

   In E1 the ten selectable flowers still carry their **existing** procedural geometry (petal rings, spike, hearts). E1 therefore renders them headless at the new scale but with the old silhouettes. That is the intended intermediate state: the head loses its stem and grows to fill its box in E1; it changes shape in E2 and E3.

4. **`shouldRepaint` is fixed** per R12.

**Per-flower stroke values.** Verified verbatim against `:1045-1056`; the parent's table was correct and is reproduced with its secondary values expanded into their own rows so nothing is buried in a parenthesis. `FlowerColors` constant names are prescribed so E2, E3 and E4 reference the same identifiers.

| Flower | `FlowerColors` constant | Hex | `strokeWidth` (44-unit) | Proto |
|---|---|---|---|---|
| Chrysanthemum | `chrysanthemumStroke` | `#B9701F` | 0.8 | `:1056` |
| Aster | `asterStroke` | `#7A68A4` | 0.9 | `:1054` |
| Sunflower | `sunflowerStroke` | `#9A6A2A` | 1.0 | `:1046` |
| Lavender | `lavenderStroke` | `#6A5A8A` | 1.0 | `:1051` |
| Daffodil | `daffodilStroke` | `#D8B84A` | 1.2 | `:1055` |
| Rose | `roseStroke` | `#7D2F3A` | 1.3 | `:1047` |
| Poppy | `poppyStroke` | `#7D2A24` | 1.3 | `:1050` |
| Bleeding Heart | `bleedingHeartStroke` | `#A8536C` | 1.3 | `:1052` |
| Peony | `peonyStroke` | `#8A4A4A` | 1.4 | `:1045` |
| Red Spider Lily | `spiderLilyStroke` | `#D8342A` | 1.8 | `:1053` |

Secondary strokes, needed by E2/E3 as **per-part overrides** (R6), added to `FlowerColors` in E1 so the palette lands in one commit:

| Owner | Constant | Hex | Width | Proto |
|---|---|---|---|---|
| Aster disc | `asterDiscStroke` | `#C98A2A` | 1.2 | `:1054` |
| Daffodil corona ring 1 | `daffodilCoronaStroke` | `#C9821F` | 1.3 | `:1055` |
| Bleeding Heart arch | `bleedingHeartArch` | `#6F8A4E` | 1.8 | `:1052` |
| Spider Lily stamens | `spiderLilyStamen` | `#A82218` | 1.0 | `:1053` |
| `wiltingRose` (legacy, R4) | `wiltingRoseStroke` | `#4A5A68` | 1.3 | `:1048` |
| `thistle` (legacy, R4) | `thistleStroke` | `#5A3A6A` | 1.3 | `:1049` |

**Must not regress**:
- **N25** — `FlowerBloom`'s `Semantics(image: true)` + label wrapper (`flower_bloom.dart:35-37`) is unchanged. Only the `FlowerPainter(...)` argument at `:41` changes. Receipt: `test/design/flowers/flower_bloom_test.dart:34-36` (`find.bySemanticsLabel('Peony')`) stays green **unmodified**.
- **N21 and the Garden screen** — the meadow must render **identically** before and after E1. If any garden bloom loses its stem, E1 is wrong. E1 does not open `garden_motion.dart` or `garden_view.dart`.
- **N24** — zero exposure (R20).
- The two legacy kinds keep resolving with a live render path (R4, R7). Receipt: `flower_spec_test.dart:8-12` (`'returns a spec keyed to every FlowerKind'`) stays green **unmodified**.
- The mood-to-flower mapping and the flower display strings are exact and must not change. `lib/domain/mood/**` is out of fence.
- `flower_spec_test.dart:14-22`, `:24-32`, `:34-41` and `:43-47` all stay green **unmodified** in E1 — E1 adds fields, it does not move or remove any existing one. (E2 and E3 do move them; see their retarget tables.)
- `test/design/flowers/flower_bloom_test.dart:12`, `:28` assert `isA<FlowerPainter>` only; an added optional named parameter leaves the type unchanged. Green, unmodified.

**Tests this MSP owes.** This is a contract change (two new required public fields) and clears the admission gate. E1 adds the **two** cases whose exact wording is fixed at R4 to `test/design/flowers/flower_spec_test.dart`. It adds no others, and it modifies no existing case.

**Acceptance criteria**: mood glyphs throughout the app are bloom heads filling their box, with no stem and no leaf. **The Garden screen is pixel-unchanged by E1** — its plants still have stems and leaves. Each flower is outlined in a darkened relative of its own petal colour rather than the same dark brown, and the fine chrysanthemum is visibly thinner-lined than the bold spider lily.

---

### E2 — Bloom geometry rewrite, part 1: the vocabulary, plus Peony, Rose, Poppy, Sunflower

**Outcome**: a declarative geometry vocabulary exists, and four of the ten blooms match their prototype silhouettes exactly.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `lib/design/flowers/flower_palette.dart`, `lib/design/flowers/bloom_style.dart` (**declared widening**, R5), new `lib/design/flowers/bloom_part.dart` (R6), new `lib/design/flowers/bloom_geometry.dart` (R6), `test/design/flowers/flower_spec_test.dart`

**Depends on**: E1.

**Schema work — build all of it here.** R6 fixes the complete `BloomPart` / `BloomCmd` vocabulary, the `FlowerSpec.parts` / `FlowerSpec.procedural` split, the `ProceduralBloom` holder, and the `partList` `BloomStyle` value. E3 adds no new part type, so anything E3 needs must exist after E2. In particular E2 must build, even though only some are used by its own four flowers: `BloomOvalRing` (E3's Aster, Daffodil, Chrysanthemum), per-part `strokeColor`/`strokeWidth` overrides (E3's Aster disc, Daffodil corona, Spider Lily stamens), `fill: null` for unfilled stroked shapes (E3's Spider Lily, and E2's own Rose arcs), and `strokeWidth: 0` for unstroked fills (E2's Rose centre; E3's Daffodil, Chrysanthemum, Spider Lily centres).

**Painter work.** `FlowerPainter` gains `case BloomStyle.partList: _paintParts(canvas, size);` which applies R1's transform and R2's clip, then walks `spec.parts!` in order. Each part: build a `Path` (or use `drawCircle`/`drawOval` with `canvas.rotate` about the pivot for `BloomOval`/`BloomOvalRing`), fill it if `fill != null`, then stroke it unless its effective `strokeWidth` is 0, using `strokeColor ?? spec.strokeColor` and `strokeWidth ?? spec.strokeWidth`.

**Target geometry**, all in the 44-unit box, all verified verbatim. Paint order is top-to-bottom within each block.

**Peony (happy)** — `:1045`. A cluster of blobs, not a petal ring. Replaces `roundPetals` with 24 teardrops and its peach centre entirely.

| Part | cx | cy | r | Fill | Stroke |
|---|---|---|---|---|---|
| disc | 22 | 15 | 8 | `#F2A9B2` | inherit |
| disc | 14 | 22 | 8 | `#ED97A4` | inherit |
| disc | 30 | 22 | 8 | `#ED97A4` | inherit |
| disc | 18 | 29 | 8 | `#F2A9B2` | inherit |
| disc | 26 | 29 | 8 | `#F2A9B2` | inherit |
| disc | 22 | 23 | 6.5 | `#E4788A` | inherit |

Spec stroke `#8A4A4A` at 1.4, `StrokeJoin.round` (the source group sets `stroke-linejoin="round"`).

**Rose (love)** — `:1047`. A spiral, not a petal ring.

| Part | Geometry | Fill | Stroke |
|---|---|---|---|
| disc | (22, 22) r14 | `#D76A76` | inherit — **the disc IS stroked** |
| shape | `M22 10` then arc `rx12 ry12 largeArc=1 clockwise=1` to `(14, 31)` | **none** | inherit |
| shape | `M22 14` then arc `rx8 ry8 largeArc=1 clockwise=1` to `(17, 28)` | **none** | inherit |
| disc | (22, 22) r3.5 | `#A83F4D` | **`strokeWidth: 0`** |

Spec stroke `#7D2F3A` at 1.3. The source paths are `M22 10a12 12 0 1 1-8 21` and `M22 14a8 8 0 1 1-5 14` — SVG relative arcs; the absolute endpoints above are `(22-8, 10+21)` and `(22-5, 14+14)`. SVG `sweep-flag=1` maps to Flutter's `clockwise: true`. Both arcs are **open and unfilled**; do not `close()` them. There is no arc-drawing code in the painter today — `BloomArcTo` -> `Path.arcToPoint` is how it arrives (R6).

**Poppy (tired)** — `:1050`. Four fixed-radius circles, not four teardrop cubics.

| Part | cx | cy | r | Fill |
|---|---|---|---|---|
| disc | 22 | 13 | 8 | `#E0574A` |
| disc | 13 | 24 | 8 | `#E0574A` |
| disc | 31 | 24 | 8 | `#E0574A` |
| disc | 22 | 30 | 8 | `#E0574A` |
| disc | 22 | 22 | 5 | `#3A2420` |

All five stroked with the spec stroke `#7D2A24` at 1.3. The source group carries **no** `stroke-linejoin`; `StrokeJoin.round` is harmless on circles.

**Sunflower (warm)** — `:1046`. Eight fat rotated ellipses, not sixteen rays.

| Part | Geometry | Fill |
|---|---|---|
| oval ring | count 8, cx 22, cy 9, rx 3.4, ry 7, start 0deg, step 45deg, pivot (22, 22) | `#F2C14E` |
| disc | (22, 22) r7 | `#7A4A24` |

Spec stroke `#9A6A2A` at 1.0, applied to petals **and** disc (in the source the disc sits outside the fill group but inside the stroke group). The first ellipse carries no `transform` in the source, i.e. an implicit `rotate(0)` — the ring starts at 0 degrees.

**New `FlowerColors` constants E2 adds** (R3): `peonyPetalLight #F2A9B2`, `peonyPetalMid #ED97A4`, `peonyCore #E4788A`, `roseDisc #D76A76`, `roseCore #A83F4D`, `poppyLobe #E0574A`, `poppyCore #3A2420`, `sunflowerRay #F2C14E`, `sunflowerDisc #7A4A24`. The nine existing `peony*`/`rose*`/`poppy*`/`sunflower*` constants become unreferenced by the four converted specs; **do not delete them in E2** — `flower_palette.dart` is shared down the chain and a removal here is a merge hazard for E3 and E4 with no shippable benefit.

**Retarget list for E2** — permitted under §5.2. Each pins a rendering or a schema E2 is mandated to change.

| File | Line | Current | Required change |
|---|---|---|---|
| `test/design/flowers/flower_spec_test.dart` | `:14-22` | `'every spec carries drawable parameters'` — reads `spec.petalCount`, `spec.petalLength`, `spec.petalWidth`, `spec.centerRadius` for all 12 kinds | The scalars move to `ProceduralBloom` (R6), so this stops compiling. Retarget to two assertions that hold across the whole schema: every spec resolves to a non-null `parts` **or** a non-null `procedural` (never both, never neither), and every `procedural` spec still carries `petalCount > 0`, `petalLength > 0`, `petalWidth > 0`. Behavioural intent — "every spec is drawable" — is preserved exactly |
| `test/design/flowers/flower_spec_test.dart` | `:24-32` | `'only the wilting rose droops'` — reads `spec.droop` for all 12 kinds | `droop` moves to `ProceduralBloom`. Retarget the accessor to `flowerSpecFor(kind).procedural?.droop ?? false`. **Do not delete `droop`** — `wiltingRose` is its sole user and `_paintRadial` still reads it |

`flower_spec_test.dart:8-12`, `:34-41` and `:43-47` stay green **unmodified** in E2: E2 converts peony, rose, poppy and sunflower, none of which is pinned by the style case at `:34-41` (which pins only `bleedingHeart`, `lavender`, `thistle`, `redSpiderLily`).

**Must not regress**: N25, N24 (zero exposure), and the STANDING INVARIANT — **E2 changes petal geometry the still-stemmed meadow also draws.** Check the Garden screen after E2, not only the compact glyphs; a stemmed plant with a new head is expected and fine, a blank or clipped meadow is not. `FlowerKind` values and display strings unchanged. `flowerSpecFor` keeps resolving all twelve kinds (Dart switch exhaustiveness enforces this mechanically). `test/features/garden/paint/meadow_painter_test.dart` (a smoke test: `expect(() => _render(...), returnsNormally)` plus `shouldRepaint` identity) and `test/features/garden/widgets/meadow_scene_test.dart` both stay green **unmodified**.

**Tests this MSP owes**: none. Every change here is a styling/geometry change, exempt under the admission gate; the schema split is covered by the retargeted `:14-22` case above. Do not add a per-flower geometry test — it would be a change-detector on values the tables above already pin.

**Acceptance criteria**: Happy is a five-blob pink peony with a deep pink heart, not a 24-petal daisy with a peach centre. Loved is a pink spiral rose with two visible open arcs, not a coral 16-petal daisy. Warm has eight fat petals rather than sixteen thin rays. Tired's poppy is four bright red circles with a near-black centre and a red-brown outline. The Garden still renders, still has stems, and its blooms have visibly changed shape.

---

### E3 — Bloom geometry rewrite, part 2: Chrysanthemum, Daffodil, Lavender, Aster, Bleeding Heart, Spider Lily

**Outcome**: the remaining six blooms match their prototype silhouettes exactly, and every selectable flower is on the declarative vocabulary.

**Files**: `lib/design/flowers/flower_spec.dart`, `lib/design/flowers/flower_painter.dart`, `lib/design/flowers/flower_palette.dart`, `lib/design/flowers/bloom_geometry.dart`, `test/design/flowers/flower_spec_test.dart`

**Depends on**: E2. **Not parallel with E2** — see §0's SERIALIZATION, which corrects the parent spec on this point.

E3 adds **no** new `BloomPart` type and **no** new `BloomStyle` value. If E3 finds it needs one, E2 built the vocabulary wrong — stop and report rather than extending it mid-cluster.

**Target geometry**, all in the 44-unit box, all verified verbatim, in paint order.

**Chrysanthemum (grateful)** — `:1056`. Two rings, and it is **clipped** (R2).

| Part | Geometry | Fill | Stroke |
|---|---|---|---|
| oval ring | count 12, cx 22, cy 7, rx 2.2, ry 8, start 0deg, step 30deg, pivot (22, 22) | `#D98A3C` | inherit |
| oval ring | count 9, cx 22, cy 12, rx 2, ry 6, start **20deg**, step **40deg**, pivot (22, 22) | `#EFB663` | inherit |
| disc | (22, 22) r3 | `#A85F18` | **`strokeWidth: 0`** |

Spec stroke `#B9701F` at 0.8 — the thinnest glyph in the set. R21 fixes the inner ring's offset; R2 fixes the clip.

**Daffodil (hopeful)** — `:1055`. Three-ring trumpet, not a flat dot.

| Part | Geometry | Fill | Stroke |
|---|---|---|---|
| oval ring | count 6, cx 22, **cy 9** (R9), rx 4, ry 8.5, start 0deg, step 60deg, pivot (22, 22) | `#F5DF84` | inherit |
| disc | (22, 22) r7 | `#F0A838` | **`#C9821F` at 1.3** |
| disc | (22, 22) r4 | `#E88F22` | **`strokeWidth: 0`** |
| disc | (22, 22) r1.8 | `#8A5A12` | **`strokeWidth: 0`** |

Spec stroke `#D8B84A` at 1.2.

**Lavender (calm)** — `:1051`. A symmetric 1-2-3-2-1 taper at fixed positions, not a zig-zag ladder. Nine explicit ovals, no rotation, no centre, no stem, no leaf.

| # | cx | cy | rx | ry |
|---|---|---|---|---|
| 1 | 22 | 6 | 2.7 | 3.7 |
| 2 | 18 | 11 | 3.0 | 4.0 |
| 3 | 26 | 11 | 3.0 | 4.0 |
| 4 | 16 | 17 | 3.1 | 4.2 |
| 5 | 22 | **16** | 3.1 | 4.2 |
| 6 | 28 | 17 | 3.1 | 4.2 |
| 7 | 18 | 23 | 3.0 | 4.0 |
| 8 | 26 | 23 | 3.0 | 4.0 |
| 9 | 22 | 29 | 2.8 | 3.8 |

All nine fill `#9A86C4`; spec stroke `#6A5A8A` at 1.0. **Row 5's `cy = 16` is one unit above its flankers at 17** — deliberate, and it is what makes the spike read as tapering rather than banded (R11).

**Aster (anxious)** — `:1054`. Violet, twelve petals, self-stroked disc.

| Part | Geometry | Fill | Stroke |
|---|---|---|---|
| oval ring | count 12, cx 22, **cy 8** (R9), rx 2.3, ry 7, start 0deg, step 30deg, pivot (22, 22) | `#A892CF` | inherit |
| disc | (22, 22) r5.5 | `#F2C14E` | **`#C98A2A` at 1.2** |

Spec stroke `#7A68A4` at 0.9. The petal fill is **violet** (hue ~264), replacing the app's periwinkle blue `0xFF7E8FC9` (hue ~225).

**Bleeding Heart (sad)** — `:1052`. Three hearts under a short top arch. Seven literal paths (R10). The wrapper group sets `stroke-linejoin="round"`. Paint order is exactly as listed — each teardrop immediately after its own heart.

| # | Part | Path data (44-unit) | Fill | Stroke |
|---|---|---|---|---|
| 1 | arch | `M6 9 Q 20 4 36 11` | **none** | `#6F8A4E` at **1.8**, `StrokeCap.round` |
| 2 | heart 1 | `M13 15 C 11.5 12 8 12.5 8.7 16 C 9.3 19 13 22.5 13 22.5 C 13 22.5 16.7 19 17.3 16 C 18 12.5 14.5 12 13 15 Z` | `#E07D98` | inherit |
| 3 | tear 1 | `M11.7 21 L13 26 L14.3 21 Z` | `#FBEEF0` | inherit |
| 4 | heart 2 | `M22 18 C 20.5 15 17 15.5 17.7 19 C 18.3 22 22 25.5 22 25.5 C 22 25.5 25.7 22 26.3 19 C 27 15.5 23.5 15 22 18 Z` | `#E07D98` | inherit |
| 5 | tear 2 | `M20.7 24 L22 29 L23.3 24 Z` | `#FBEEF0` | inherit |
| 6 | heart 3 | `M31 15 C 29.5 12 26 12.5 26.7 16 C 27.3 19 31 22.5 31 22.5 C 31 22.5 34.7 19 35.3 16 C 36 12.5 32.5 12 31 15 Z` | `#E07D98` | inherit |
| 7 | tear 3 | `M29.7 21 L31 26 L32.3 21 Z` | `#FBEEF0` | inherit |

Spec stroke `#A8536C` at 1.3 (the heart group's own). **The three teardrops are not translations of one another on a common baseline** — t1 and t3 run y 21 to 26, t2 runs y 24 to 29. Transcribe all three. Four hearts become three; the long descending cubic at `flower_painter.dart:198-201` is replaced by row 1's short arc.

**Red Spider Lily (angry)** — `:1053`. All-stroke, no fill, plus one filled unstroked centre **outside** the wrapper (R8). The wrapper sets `stroke-linecap="round"`.

Petals — six literal quadratics, fill **none**, stroke `#D8342A` at **1.8**:

| # | Path data (44-unit) |
|---|---|
| 1 | `M22 23 Q 30 14 26 6` |
| 2 | `M22 23 Q 34 18 34 9` |
| 3 | `M22 23 Q 37 24 40 18` |
| 4 | `M22 23 Q 14 14 18 6` |
| 5 | `M22 23 Q 10 18 10 9` |
| 6 | `M22 23 Q 7 24 4 18` |

Stamens — four literal quadratics, fill **none**, stroke `#A82218` at **1.0**:

| # | Path data (44-unit) |
|---|---|
| 1 | `M22 23 Q 25 9 21 3` |
| 2 | `M22 23 Q 19 9 23 3` |
| 3 | `M22 23 Q 38 13 42 7` |
| 4 | `M22 23 Q 6 13 2 7` |

Centre — `disc (22, 23) r2.4`, fill `#7D1A14`, **`strokeWidth: 0`**.

Spec stroke `#D8342A` at 1.8 (the petal group's, so petals may inherit; stamens override). **Petals 4, 5, 6 mirror petals 1, 2, 3 about x = 22, but the three per side differ from each other — a rotate-by-60-degree loop reproduces neither the shape nor the asymmetric fan.** Write all ten literally (R8). Every path is **open**; do not `close()` any of them.

**New `FlowerColors` constants E3 adds** (R3): `chrysanthemumOuter #D98A3C`, `chrysanthemumInner #EFB663`, `chrysanthemumCore #A85F18`, `daffodilRay #F5DF84`, `daffodilCorona1 #F0A838`, `daffodilCorona2 #E88F22`, `daffodilCorona3 #8A5A12`, `lavenderFloret #9A86C4`, `asterRay #A892CF`, `asterDisc #F2C14E`, `bleedingHeartLobe #E07D98`, `bleedingHeartTear #FBEEF0`, `spiderLilyCore #7D1A14`. (`asterDiscStroke`, `daffodilCoronaStroke`, `bleedingHeartArch` and `spiderLilyStamen` already landed in E1.)

**Retarget list for E3** — permitted under §5.2.

| File | Line | Current | Required change |
|---|---|---|---|
| `test/design/flowers/flower_spec_test.dart` | `:34-41` | `'bleeding heart uses the heart-pendant silhouette'` — pins `bleedingHeart -> heartPendants`, `lavender -> spike`, `thistle -> puff`, `redSpiderLily -> spiderPetals` | Three of the four flowers convert in E3. Retarget `bleedingHeart`, `lavender` and `redSpiderLily` to `BloomStyle.partList`. **`thistle -> puff` stays exactly as written** — it is the last live procedural style besides `roundPetals` and is the receipt that E3 did not over-reach into the legacy kinds |

`flower_spec_test.dart:8-12`, `:43-47`, and the two cases E1 added stay green **unmodified**. The `:14-22` and `:24-32` cases, as retargeted by E2, also stay green unmodified in E3 — E3 moves six more specs from the `procedural` branch to the `parts` branch, which is exactly what E2's retargeted wording already covers.

**Must not regress**: N25, N24 (zero exposure), and the STANDING INVARIANT — as in E2, the still-stemmed meadow path renders these same specs, so **verify the Garden screen after E3** as well as the compact glyphs. `flowerSpecFor` must keep resolving every `FlowerKind`, including the two ambient-only legacy kinds, so `meadow_painter.dart:102` keeps compiling. `FlowerKind` values and display strings unchanged.

**Tests this MSP owes**: none beyond the retarget above. Pure geometry and colour work, exempt under the admission gate.

**Acceptance criteria**: Grateful is a layered pom-pom with a darker outer ring over a lighter inner one, its four axis-aligned petal tips cut flat at the box edge. Hopeful has a visible three-ring layered trumpet in place of a flat orange dot, on paler yellow petals. Calm is a compact tapering spike rather than florets zig-zagging along a stalk. Anxious is a **violet** 12-petal aster with a yellow disc ringed in its own amber, not a blue 22-ray starburst. Sad is three hearts, each with a white teardrop, hanging under a short dark-green arch. Angry is a delicate unfilled six-stroke spidery outline with **a visible dark centre** and four long stamens, not a solid red eight-armed pinwheel.

---

### E4 — Garden plant art set, the meadow swap, and the two-row size ladder

**Outcome**: the garden meadow grows tall stemmed botanical plants anchored to the soil line, and the two compact sites that are genuinely off-target render at the designed size.

**Files**: new `lib/design/flowers/garden_plant_spec.dart`, new `lib/design/flowers/garden_plant_painter.dart`, `lib/design/flowers/flower_palette.dart`, `lib/design/flowers/flower_painter.dart` (stem-path deletion, R18), `lib/features/garden/paint/meadow_painter.dart`, `lib/features/calendar/widgets/calendar_day_cell.dart`, `lib/features/garden/widgets/mood_tally_chips.dart`

**Depends on**: E3.

**This MSP will exceed 400 LOC. Split it into two commits on the same branch**: (1) the garden plant set, painter and meadow swap; (2) the two ladder sites plus the stem-path deletion. One PR, two commits.

**Architecture** (R16). `GardenPlantSpec` reuses `BloomPart` at a 100-wide viewBox, carries `viewBoxHeight`, and derives `ratio => viewBoxHeight / 100`. `GardenPlantPainter` scales by `size.width / 100`, issues **no** clip (R2, because `plantSvg` at `:1198` sets `overflow:'visible'`), and paints parts in order. `gardenPlantSpecFor(FlowerKind)` resolves the **ten selectable kinds**; it does **not** need a case for `wiltingRose` or `thistle`, which have no meadow render site (R4's reachability finding) — use a `Map` or a switch with a `peony` default mirroring the prototype's own `else` branch (`:1186`).

**Meadow swap** (R15). `meadow_painter.dart:95-105` becomes:

```
final GardenPlantSpec spec = gardenPlantSpecFor(bloom.kind);
final double h = bloom.size * spec.ratio;
canvas.save();
canvas.translate(bloom.dx, bloom.baseY);
canvas.rotate(sway);
canvas.translate(-bloom.size * 0.5, -h);
GardenPlantPainter(spec).paint(canvas, Size(bloom.size, h));
canvas.restore();
```

`bloom.size` keeps meaning **width**. `meadow_layout.dart` is not opened. The sway pivot stays at the plant's bottom centre, matching `transformOrigin:'bottom center'` (`:1487`).

**The twelve prototype viewBox/ratio pairs, exhaustive** (`:1078`, `:1086`, `:1097`, `:1111`, `:1116`, `:1131`, `:1138`, `:1151`, `:1159`, `:1168`, `:1178`, `:1187`). **CORRECTION to parent `:1299`** per R16: only the ten selectable rows are implemented; 206 and one of the two 196s are unreachable.

| Mood | Flower | viewBox | ratio | In scope |
|---|---|---|---|---|
| warm | Sunflower | `0 0 100 240` | 2.4 | yes |
| tired | Poppy | `0 0 100 236` | 2.36 | yes |
| angry | Red Spider Lily | `0 0 100 214` | 2.14 | yes |
| hopeful | Daffodil | `0 0 100 214` | 2.14 | yes |
| anxious | Aster | `0 0 100 210` | 2.1 | yes |
| love | Rose | `0 0 100 205` | 2.05 | yes |
| sad | Bleeding Heart | `0 0 100 200` | 2.0 | yes |
| grateful | Chrysanthemum | `0 0 100 196` | 1.96 | yes |
| happy | Peony | `0 0 100 190` | 1.9 | yes |
| calm | Lavender | `0 0 100 190` | 1.9 | yes |
| — | `_thistle` (legacy) | `0 0 100 206` | 2.06 | **no** — no render site |
| — | `_wiltingRose` (legacy) | `0 0 100 196` | 1.96 | **no** — no render site |

**Garden plant geometry.** Ten models, verbatim from `:1075-1197`. Where the source generates parts with a JS loop, the loop's parameters are given rather than the expansion; where it lists literal paths, the paths are given. Every colour becomes a `FlowerColors` constant (R3). All coordinates are in the model's own `0 0 100 <h>` box.

**Sunflower / warm** — `:1075-1083`, vb 240.
```
stem   M50 240 C 48 182 54 120 50 86      none  #5F7A3E w5.4 cap round
leaf group, stroke #4E6A34 w2.3, join+cap round:
  leaf L  M50 152 C 26 140 9 150 10 172 C 21 177 23 188 34 181 C 41 190 51 182 50 152 Z   fill #82A05A
  vein L  M50 152 Q 28 162 13 170                                            none  w1.3
  leaf R  M52 118 C 76 108 92 120 90 142 C 79 146 78 157 67 151 C 61 159 50 150 52 118 Z  fill #8FAE5C
  vein R  M52 118 Q 72 128 86 138                                            none  w1.3
head group, stroke #9A6A2A w1.3:
  ring   count 15, cx 50, cy 30, rx 5, ry 13.5, start 0deg, step 24deg, pivot (50, 56)  fill #F2C14E
  disc   (50, 56) r17   fill #7A4A24
seeds, fill #5C3618, no stroke, r1.5 each, at:
  (50,50) (44,53) (56,53) (47,59) (53,59) (50,56) (42,57) (58,57) (50,63) (45,63) (55,63)
```

**Aster / anxious** — `:1084-1092`, vb 210.
```
stem     M50 210 C 47 168 52 122 50 60    none  #5F7A3E w3.4 cap round
branch L M50 150 C 34 138 27 120 30 96    none  #6F8A4E w2.5 cap round
branch R M50 138 C 66 128 74 112 72 88    none  #6F8A4E w2.5 cap round
whiskers, stroke #4E6A34 w1.5, join+cap round, fill none:
  M50 168 q -15 -4 -23 -15
  M50 128 q 14 -5 21 -15
leaflets, stroke #4E6A34 w1.4, join round:
  M44 156 l -17 -6 l 5 8 Z   fill #82A05A
  M56 144 l 17 -6 l -5 8 Z   fill #8FAE5C
three daisies at (30,90), (72,84), (50,54):
  the first two use petalLength 8.5, discRadius 4.4; the third 11 and 5.5
  each daisy: 16 ellipses, rx 1.9, ry = petalLength, cx = daisy cx,
              cy = daisyCy - discRadius - petalLength*0.55, step 360/16 = 22.5deg, pivot = daisy centre,
              fill ALTERNATES #A892CF (odd index) / #B6A2DA (even index), stroke #7A68A4 w0.9
  then disc (daisy centre) r = discRadius, fill #F2C14E, stroke #C98A2A w1.2
```
Note the alternating petal fill — the source is `(i%2 ? '#a892cf' : '#b6a2da')`, so index 0 is `#B6A2DA`. `BloomOvalRing` carries one fill, so emit **two** rings of 8 at 45deg step (starts 0deg and 22.5deg), or emit 16 individual `BloomOval`s. Either is faithful; do not collapse to a single colour.

**Bleeding Heart / sad** — `:1093-1102`, vb 200.
```
stem   M30 200 C 26 150 28 100 42 76 C 55 55 74 52 90 60   none  #5F7A3E w3.4 cap round
leaves, stroke #4E6A34 w1.7, join round:
  M32 152 C 16 152 6 160 4 172 C 14 172 14 180 22 174 C 26 180 34 172 32 152 Z   fill #8AA06A
  M34 124 C 20 122 12 128 9 139 C 18 141 17 149 25 144 C 30 149 38 140 34 124 Z  fill #96AC74
five pendants at (45,82) (56,74) (66,71) (76,73) (85,80):
  pedicel  M<x> <y> q 0 6 0 9      none  #6F8A4E w1.6 cap round
  heart    anchored at (x, y+9), scale s = 8, stroke #A8536C w1.3, fill #E07D98
```
The heart at scale `s` about anchor `(cx, cy)` is, with `P(a,b) = (cx + a*s, cy + b*s)`:
```
M P(0,0.3) C P(-0.05,0.0) P(-0.62,-0.05) P(-0.62,0.34)
           C P(-0.62,0.68) P(-0.18,0.88) P(0,1.16)
           C P(0.18,0.88) P(0.62,0.68) P(0.62,0.34)
           C P(0.62,-0.05) P(0.05,0.0) P(0,0.3) Z
```
All five pedicels paint first, then all five hearts (the source builds `peds` and `hearts` as separate strings and concatenates `peds + hearts`).

**Red Spider Lily / angry** — `:1103-1113`, vb 214. Centre `(50, 60)`, `n = 6`.
```
scape  M50 214 C 49 164 51 112 50 66   none  #6A7D46 w3.2 cap round
for i in 0..5, with a = (i*60 - 90) degrees, dx = cos(a), dy = sin(a):
  petal  M50 60 Q (50+dx*14-dy*8) (60+dy*14+dx*8) (50+dx*24) (60+dy*24)
                Q (50+dx*24-dy*4) (60+dy*24+dx*4) (50+dx*24-dy*7) (60+dy*24+dx*7)
         none  #D8342A w2.6 cap round
  stamen M50 60 Q (50+dx*20-dy*4) (60+dy*16-6) (50+dx*30) (60+dy*30-18)
         none  #C22A20 w1.2
  tip    disc (50+dx*30, 60+dy*30-18) r1.7  fill #7D1A14
all six petals paint first, then all six stamens with their tips
centre disc (50, 60) r3.6  fill #A82218
```
Unlike the compact glyph, the **garden** spider lily IS rotationally generated — this loop is the source's own and is correct here. Do not carry the compact glyph's literal-path rule (R8) across; they are different art (R22).

**Daffodil / hopeful** — `:1114-1125`, vb 214.
```
stem   M50 214 C 48 162 52 110 50 66   none  #5F7A3E w3.8 cap round
leaves, stroke #4E6A34 w1.6, join+cap round:
  M50 212 C 40 170 36 122 41 84 C 47 124 49 170 50 212 Z   fill #7F9A4F
  M50 212 C 60 172 64 126 59 90 C 53 128 51 172 50 212 Z   fill #8FAE5C
ring   count 6, cx 50, cy 43, rx 7, ry 14, start 0deg, step 60deg, pivot (50, 60)
       fill #F5DF84, stroke #D8B84A w1.5
disc   (50, 60) r11   fill #F0A838  stroke #C9821F w1.8
disc   (50, 60) r6.5  fill #E88F22  stroke #C9821F w1.3
disc   (50, 60) r2.6  fill #8A5A12  no stroke
```

**Chrysanthemum / grateful** — `:1126-1136`, vb 196. Centre `(50, 64)`.
```
stem   M50 196 C 47 152 53 112 50 88   none  #5F7A3E w4.2 cap round
leaves, stroke #4E6A34 w2, join+cap round:
  M50 152 C 34 152 22 145 13 154 C 22 158 21 166 30 163 C 31 170 40 167 43 160 C 48 163 53 156 50 152 Z  fill #82A05A
  M50 130 C 66 130 78 123 87 132 C 78 136 79 144 70 141 C 69 148 60 145 57 138 C 52 141 47 134 50 130 Z  fill #8FAE5C
four pom rings, every ellipse rx 2.5, pivot (50, 64), all stroked #B9701F w0.8:
  ring 0  count 18, cy 64-22 = 42,   ry 12,  start 0deg,  step 20deg      fill #D98A3C
  ring 1  count 15, cy 64-16 = 48,   ry 10,  start 11deg, step 24deg      fill #E6A04E
  ring 2  count 12, cy 64-11 = 53,   ry 7.5, start 0deg,  step 30deg      fill #EFB663
  ring 3  count 9,  cy 64-6  = 58,   ry 5,   start 11deg, step 40deg      fill #F6CD86
disc   (50, 64) r3.4  fill #A85F18  no stroke
```
The 11-degree offset applies to **odd-indexed rings only** (`ri%2 ? 11 : 0`), i.e. rings 1 and 3.

**Rose / love** — `:1137-1146`, vb 205.
```
stem   M50 205 C 47 165 53 128 50 98   none  #5F7A3E w4 cap round
thorns, fill #5F7A3E, no stroke:
  M49 150 l -9 -4 l 6 7 Z
  M51 128 l 9 -4 l -6 7 Z
leaflets, stroke #4E6A34 w1.9, join+cap round:
  M50 146 q -15 3 -29 -1                                   none
  M36 145 c -4 -7 -12 -7 -15 0 c 4 6 11 6 15 0 Z           fill #82A05A
  M24 146 c -4 -7 -12 -7 -15 0 c 4 6 11 6 15 0 Z           fill #8FAE5C
  M50 130 q 15 3 29 -1                                     none
  M64 129 c 4 -7 12 -7 15 0 c -4 6 -11 6 -15 0 Z           fill #8FAE5C
bloom group, stroke #7D2F3A w2.4, join round:
  disc   (50, 74) r16   fill #D76A76
  M50 60 a13.5 13.5 0 1 1 -9 24     none    (arc to (41, 84), largeArc, clockwise)
  M50 65 a9 9 0 1 1 -6 16           none    (arc to (44, 81), largeArc, clockwise)
  disc   (50, 74) r4    fill #A83F4D   no stroke
sepals  M38 88 q -5 7 -2 13   and   M62 88 q 5 7 2 13    none  #5F7A3E w2
```

**Lavender / calm** — `:1147-1156`, vb 190.
```
basal leaves, stroke #4E6A34 w1.7, join round:
  M50 188 C 40 178 34 166 34 150 C 42 160 48 172 50 188 Z   fill #8FAE5C
  M50 188 C 60 178 66 166 66 150 C 58 160 52 172 50 188 Z   fill #82A05A
  M50 188 C 44 176 41 164 42 150 C 47 162 50 174 50 188 Z   fill #93A35E
five spikes with tips (30,72) (40,56) (50,48) (60,56) (70,72), index i = 0..4:
  bx = 50 + (tipX - 50) * 0.12
  stem  M<bx> 185 Q <((bx+tipX)/2) + (i-2)*3> <(185+tipY)/2> <tipX> <tipY>
        none  #6F8A4E w2.6 cap round
  then 6 florets, k = 0..5:
    ellipse cx = tipX + (k odd ? 0.8 : -0.8), cy = tipY - k*6.2, rx 3.1, ry 4.2
    fill (k odd ? #9A86C4 : #8A74B8), stroke #6A5A8A w1
all five stems paint first, then all five floret sets (source concatenates stems + spikes)
```

**Poppy / tired** — `:1157-1166`, vb 236.
```
stem     M50 236 C 46 180 55 120 50 72   none  #6F8A4E w3 cap round
side stem M50 152 C 62 140 71 120 66 104 none  #6F8A4E w2.3 cap round
nodding bud, rotate 18deg about (66, 100):
  ellipse (66, 98) rx6 ry8.5  fill #7F9A4F  stroke #4E6A34 w1.7
  M62 96 q4 -4 8 0            none          stroke #4E6A34 w1.1
feathery leaves, fill none, cap round:
  #7F9A4F w1.8:  M50 176 q -13 -1 -23 -11    M50 180 q -12 4 -21 3    M50 172 q -11 -8 -17 -18
  #82A05A w1.8:  M50 177 q 13 -1 23 -11      M50 181 q 12 4 21 3
bloom group, stroke #7D2A24 w2.2, join round:
  ellipse (50, 56) rx15   ry13   fill #E0574A
  ellipse (38, 65) rx12   ry11   fill #D84A3D
  ellipse (62, 65) rx12   ry11   fill #D84A3D
  ellipse (50, 70) rx13.5 ry11   fill #E0574A
  disc    (50, 64) r6.5          fill #3A2420   no stroke
stamens: 11 lines from (50, 64) to (50 + cos(a)*9, 64 + sin(a)*9),
         a = i*360/11 degrees, stroke #3A2420 w1.3
```

**Peony / happy** — `:1186-1196`, vb 190. This is the prototype's `else` branch, i.e. also the fallback for any unmapped mood.
```
stem   M50 190 C 46 150 53 116 50 92   none  #5F7A3E w4.6 cap round
leaves, stroke #4E6A34 w2.1, join+cap round:
  M50 148 C 32 148 18 140 9 149 C 19 154 17 162 27 160 C 27 168 37 166 41 159 C 47 163 53 156 50 148 Z  fill #82A05A
  M50 148 Q 30 150 12 150                                                     none  w1.3
  M50 126 C 68 126 82 118 91 127 C 81 132 83 140 73 138 C 73 146 63 144 59 137 C 53 141 47 134 50 126 Z fill #8FAE5C
  M50 126 Q 70 128 88 129                                                     none  w1.3
bloom group, stroke #8A4A4A w2.3, join round:
  disc (50, 64) r15    fill #F2A9B2
  disc (34, 74) r14    fill #ED97A4
  disc (66, 74) r14    fill #ED97A4
  disc (41, 87) r13.5  fill #F2A9B2
  disc (59, 87) r13.5  fill #F2A9B2
  disc (50, 78) r12    fill #E4788A
  M44 78 q6 -7 12 0    none  #C95F72 w1.5
```

**Glyph size ladder — exactly two changes** (R13):

| Site | From | To | Anchor |
|---|---|---|---|
| Calendar day cell | 28 | **40** | `lib/features/calendar/widgets/calendar_day_cell.dart:51` — note the enclosing `SizedBox(height: 28)` at `:49` must move to 40 too, or the glyph is clipped |
| Garden tally chip | 18 | **24** | `lib/features/garden/widgets/mood_tally_chips.dart:50` |

No other size is changed by this MSP. Six parent ladder rows are dropped with reasons at R13; `garden_view.dart:34` stays at 44 by decision at R14.

**Stem-path deletion** (R18). Once the meadow swap has landed, delete `_straightStem` (`flower_painter.dart:73-89`), `_stemStroke` (`:49-53`) and the `headless` parameter, making the clip-and-scale transform unconditional. **Do not** delete `_paintRadial`, `_paintSpike` or `_paintPuff`, and **do not** delete `ProceduralBloom`, `stemColor`, `leafColor` or `droop` — `flowerSpecFor` must keep resolving `wiltingRose` and `thistle` with a live render path.

**Must not regress**:
- **N21** — the motion routing is **unaffected** by a painter swap and E4 must not touch it. Verified anchors (R17): `resolveGardenMotion` at `garden_motion.dart:5-13`, ceiling `defaultMaxAnimatedBlooms = 140` at `:1`, enum at `:3`, call site `garden_view.dart:43-49`. The OS `disableAnimations` signal and the bloom-count ceiling continue to force the reduced profile.
- **N25** — `FlowerBloom`'s Semantics image + mood/flower label survives at **both** retargeted size sites. Both go through `FlowerBloom.forMood`, which supplies the label by construction (`flower_bloom.dart:26`); neither may be converted to a raw `CustomPaint`.
- **N24** — zero exposure (R20).
- `Palette.sunGlow = Color(0x8CF4C960)` is a preserve item — the prototype does not draw it (`grep -c f4c960` returns 0). **Keep it** (R19).
- The garden palette hexes `#D6DBAC`, `#C4CE95`, `#B1BD80`, `#A0B371`, `#96AA69` (meadow gradient, `:223`) and `#8A6C44`, `#775A37` (soil band, `:229`) are all verbatim in the prototype and stay.
- `meadow_layout.dart` is not opened (R15). `bloom.size` keeps meaning width.
- `test/features/garden/paint/meadow_painter_test.dart` is a smoke test (`returnsNormally` plus `shouldRepaint` identity) and stays green **unmodified**. `test/features/garden/widgets/meadow_scene_test.dart` reads `find.byType(CustomPaint).first).painter! as MeadowPainter` and asserts `showInsects` / `t` / `planted.length`; E4 changes `MeadowPainter`'s internals, not its type or fields, so it stays green **unmodified** — but note its `.first` at `:22-23` breaks if E4 introduces any `CustomPaint` **above** the scene's. It does not today; do not add one.
- `test/features/calendar/widgets/calendar_day_cell_test.dart` (findsOneWidget / findsNothing on `FlowerBloom`, no size assertion) and `test/features/garden/widgets/mood_tally_chips_test.dart` (findsNWidgets(2) / findsNothing, no size assertion) both stay green **unmodified** through the two size changes.

**Tests this MSP owes**: none. The garden plant set is art; the two size changes are styling. Both are exempt under the admission gate. Do not add a golden test — no golden infrastructure exists and building it is H1's job (§5.1).

**Acceptance criteria**: the garden meadow shows tall stemmed plants anchored to the soil line — sunflowers with broad leaves and a seeded disc, a thorned rose, a bleeding-heart raceme, a nodding poppy bud — rather than squat icon-sized flowers. Calendar day cells and garden tally chips carry visibly larger blooms. The Today mood card, mood picker, week garden, search rows and nav lockup are **unchanged in size** by this MSP. Reduced-motion behaviour on the Garden screen is identical to before.

---

## 5. Verification strategy

### 5.1 What the repo actually has

No golden or screenshot coverage exists. H1 builds it and is **not** dispatched in this run. The automated safety net for Cluster E is therefore the existing widget and unit suite — which, for flower geometry, is **thin by design and thin in fact**: sixteen test files touch the relevant surface and almost none of them assert geometry.

This has a direct consequence: **the automated suite cannot tell you whether a flower looks right.** It can only tell you the app still builds, still resolves every kind, still exposes every Semantics label, and still renders without throwing. The manual pass in §5.4 is not a formality in this cluster; it is the primary fidelity check.

### 5.2 The testing rule that governs this run

Per the project's test admission gate, a **styling or geometry change warrants no new test**. Tests are added only where a change introduces or changes a *behaviour*, fixes a bug, or defines a public contract.

In this cluster that yields exactly **one** MSP with new tests:

| MSP | Test | Why it qualifies |
|---|---|---|
| E1 | Two new cases in `test/design/flowers/flower_spec_test.dart`, wording fixed at R4 | Contract: `FlowerSpec` gains two new **required** public fields. This is a public contract change, not a restyle |
| E2, E3, E4 | none | Geometry, colour and size are exempt. E2 and E3 retarget existing cases; E4 adds nothing |

Per `decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md`, **an MSP MAY retarget an existing assertion that pins a rendering it is mandated to change.** Retargeting means updating the literal, the accessor or the finder inside an existing test so it matches the new target, while preserving the test's behavioural intent. It is **not** deleting the test, and the admission gate does not apply to it. The three retargets this cluster requires are enumerated at their point of use: E2 owns `flower_spec_test.dart:14-22` and `:24-32`; E3 owns `:34-41`.

**Do not add per-flower geometry tests.** A test asserting that Peony's third disc is at (30, 22) with r8 is a change-detector on a value this document already pins, adds no trust, and would have to be rewritten by every future design change. The tables in §4 are the specification; the manual pass is the check.

**The hard boundary on the retarget permission is N24.** Retargeting never touches a `ValueKey`, a Semantics label, or any of the eight files at R20, under any circumstances. Cluster E has zero exposure to those eight files by path disjointness, so this boundary is not expected to be tested by this run.

### 5.3 The standing regression gate

Before any MSP in this run merges:

1. `flutter analyze` clean.
2. The **playback suite runs unmodified and passes.** This is N24. In this run it is **background**, not acute — no MSP edits any file in R20's table, confirmed by path disjointness. It still runs before every merge; a diff in that suite from a Cluster E change would itself be the signal that the fence has been breached.
3. The four `integration_test/` flows pass. **Never run `flutter test integration_test/` as a directory** — `integration_test/capture_save_persist_test.dart` writes into the real journal container. Name the single file if one is ever needed.
4. Diff-scoped verification via the project's verify command; the full suite runs at the cluster boundary and pre-push, not per change.

**Predict the test count before running.** Every MSP states its expected total before executing `fullValidationCmd`, and compares afterwards. A mismatch that cannot be explained is a defect, not a rounding error. Expected deltas for this cluster, from the baseline of **904**:

| MSP | Delta | Expected total | Reason |
|---|---|---|---|
| E1 | **+2** | **906** | Two new cases in `flower_spec_test.dart` (R4). No case is deleted |
| E2 | **0** | **906** | Two existing cases retargeted in place; no case added or removed |
| E3 | **0** | **906** | One existing case retargeted in place |
| E4 | **0** | **906** | No test change of any kind |

**CI is not evidence.** Neither GitHub check runs a Dart test: the receipts workflow is node-only and the D6 check has no Dart import grapher and passes vacuously. `receiptsPass` / `d6Pass` are never acceptable as proof that this run is green. Run `fullValidationCmd` from `receipts.config.json` locally against the PR head before every merge:

```
flutter pub get && dart run build_runner build --delete-conflicting-outputs \
  && flutter analyze && flutter test
```

Baseline at the head of this slice's branch: **904 tests passing, 0 failing, `flutter analyze` clean.**

### 5.4 Manual spot-check

Cluster E has the weakest automated net of any cluster in this spec and the widest visual blast radius — every screen in the app renders at least one flower. The manual pass is therefore **required per MSP**, not only at the cluster boundary, on macOS via `flutter run -d macos` — never the standalone binary, which renders a black window.

**After E1:**
- Every mood glyph is a bloom head filling its box, with no stem and no leaf trailing below it.
- **The Garden screen is unchanged.** Plants still have stems and leaves. This is the single most important check in the cluster; if any garden bloom lost its stem, E1 is wrong and must not merge.
- Outlines are visibly per-flower: chrysanthemum is finer-lined than spider lily.

**After E2:**
- Happy is a five-blob peony, loved is a spiral rose with two visible arcs, warm has eight fat petals, tired is four red circles with a near-black centre.
- **The Garden still renders**, still stemmed, with the four new heads. Not blank, not clipped, not inverted.

**After E3:**
- Grateful is a two-ring pom-pom with its four axis-aligned tips cut flat at the box edge (that flat cut is correct — R2).
- Anxious is **violet**, not blue. Angry has a **visible dark centre** — if the centre is invisible, R8 was implemented backwards.
- Calm tapers rather than zig-zags; sad is three hearts under a short arch; hopeful shows three concentric trumpet rings.
- **The Garden still renders**, still stemmed, with all ten new heads.

**After E4:**
- The meadow grows tall stemmed plants anchored to the soil line, at visibly varied heights, swaying from their base.
- Calendar day cells and garden tally chips carry visibly larger blooms.
- The Today mood card, mood picker, week garden, search rows and nav lockup are **unchanged in size**.
- Enable reduced motion at the OS level and confirm the Garden's animation stops exactly as it did before (N21).
- Confirm the garden empty state still shows its daffodil at its existing size (R14) and the sun glow is still drawn (R19).

### 5.5 Plan scope-guard rule

Every plan produced from this slice must anchor its scope guard to a SHA captured with `git rev-parse HEAD` **before the MSP's first edit**. Do not use `git merge-base main HEAD` — it attributes every commit already on the branch to the MSP — and do not use a fixed `HEAD~N`. State the expected diff as the MSP's fileScope paths **plus whatever the branch already carried**. Never prescribe `git checkout -- <path>` as an autonomous step; gate any such revert behind human confirmation.

---

## 6. Out of scope

### 6.1 Deferred to later clusters or later specs

- **The mood picker's own chrome, copy and tile size are Cluster F's.** E4 must not touch `lib/features/mood/mood_picker_grid.dart` — F2 owns the 56-to-44 tile size — nor `mood_picker_sheet.dart` or `mood_picker.dart`. Cluster E changes what a picker tile's flower *looks like*, never how big the tile draws it.
- **The Today mood card's glyph size (54) is C2's**, already landed. `mood_banner.dart` is out of fence (R13).
- **Calendar, Garden, Search and Day Detail screen alignment** remains excluded per the parent's §6.1, "beyond the token and flower changes that reach them transitively." E4's two size changes and the meadow swap are exactly such transitive flower changes; nothing else on those screens moves.
- **Golden / screenshot infrastructure is H1's.** Cluster E does not build it and does not add golden tests (§5.2).
- **OQ-3** (entry-card Edit/Delete placement) and **OQ-6** (photo attachment model) remain open and touch no MSP in this run.

### 6.2 Explicitly not a task

- **No `flutter_svg` / `vector_graphics` dependency, and no new dependency of any kind.** Every path in this cluster is a hand-built Flutter `Path` from typed Dart values. The prototype's own blooms are primitive shapes — `<ellipse>`, `<circle>`, simple `<path>` with `rotate()` — not exported vector-tool art, so there is no arbitrary bezier fidelity to preserve and the `CustomPainter` matches the source by construction.
- **No SVG path-string parser and no path-data strings stored in Dart.** R6 fixes the command vocabulary; the tables in §4 are transcribed into typed values.
- **No migration to `ThemeExtension`.** The token layer stays plain `abstract final class` constants.
- **No `FontVariation('wght', …)` calls.** Not applicable to this cluster, restated for consistency.
- **No renames, removals or additions in `lib/design/tokens/**`.** The token layer closed with Cluster A. Every colour Cluster E introduces goes to `FlowerColors` (R3).
- **No rename or removal of any existing `FlowerColors` constant**, including the nine that fall out of use after E2 and E3. Removing them is a merge hazard across a four-MSP serial chain with no shippable benefit.
- **No deletion of `FlowerKind.wiltingRose` or `FlowerKind.thistle`**, their specs, their display strings or their render paths (R4, R7, R18). They are ambient-only and out of scope, not dead code to clean up.
- **No deletion of the unreferenced `BloomStyle` values** (`rayPetals`, `broadPetals`, `spiderPetals`, `spike`, `heartPendants`) after E3 (R5). A separate cleanup with no shippable outcome.
- **No edit to `lib/domain/mood/**`.** The `FlowerKind` enum values, their display strings and the mood-to-flower mapping are exact.
- **No edit to `lib/features/garden/model/garden_motion.dart` or the motion block at `garden_view.dart:43-49`** (N21, R17).
- **No edit to `lib/features/garden/model/meadow_layout.dart`** (R15).
- **No edit to any of the six dropped ladder sites** — `mood_banner.dart`, `mood_picker_grid.dart`, `this_week_garden.dart`, `search_day_tile.dart`, `sidebar_shell.dart`, `garden_view.dart` (R13, R14).
- **No deletion or weakening of the playback suite** under any circumstances (N24, R20) — inapplicable in practice to this run, stated for consistency with every prior slice.
- **No `flutter run` by an implementing agent.** Visual confirmation is a human step on macOS hardware (§5.4).

### 6.3 Open questions

**No open question in the parent spec is answered or affected by this run.** OQ-3 and OQ-6 remain open and touch no MSP here.

---

## 7. Traceability note — READ BEFORE ADOPTING ANY VALUE

**Zero citation errors were found in Cluster E's own region.** Every line number, hex, radius, `rx`/`ry`, rotation and stroke width the parent spec quotes for E1–E4 was independently re-opened in `docs/prototype/project/Field Notes.dc.html` while composing this slice and confirmed byte-identical — the ten per-flower citations `:1045`–`:1056`, the compact renderer at `:1064`, the garden models at `:1075`–`:1197`, `plantSvg` at `:1198`, the meadow scene at `:223`/`:229`, and every size-ladder site. **The parent spec invented nothing.** This is the third cluster, after C's `:127-129` self-correction and D's clean close, to verify with zero prototype-citation errors. **The parent spec's running count of wrong-line-number citations stays at three** — `ink08`/`ink12`, `Shadows.chip`, and the phone mood-picker sheet, none of which Cluster E cites.

**What the parent spec got wrong in this region is different in kind, and there is a lot of it.** Thirteen prototype-side and nine app-side defects, all omission, over-generalisation, staleness or one internal contradiction. Four were hard blockers — geometry described in prose and never supplied (Aster `cy`, Daffodil `cy`, all seven Bleeding Heart paths, all ten Spider Lily paths). Every one is resolved in §0 and carried into §4 as a value an implementer types straight in.

**A third kind of staleness was found and corrected: in-repo drift.** N21's cited symbol `resolveGardenMotionProfile` **does not exist** anywhere in `lib/` or `test/`; the real function is `resolveGardenMotion` (R17). Six of E4's eight size-ladder rows point at files outside E4's fence, values already at target, or both (R13) — three of them stale because Clusters B, C and D landed the work after the parent spec was written. `bloom_style.dart` and `flower_palette.dart` are load-bearing for this cluster and appear in no parent file list (R3, R5). The N24 file paths circulated in shorthand name two directories that do not exist (R20).

**Rule for implementers:** re-open every cited line — both in the prototype HTML and in the app's own source — before adopting any value. This spec family has now been wrong about prototype line numbers three times, wrong about in-repo line numbers twice, and wrong about a symbol's existence once; treat every citation as a pointer to verify, not as an authority. **If you meet an anchor that does not resolve, stop and report. Do not make the call yourself** — that is exactly how the C5 caption and three C7 ladder rows were lost.

`docs/design/prototype-analysis.md` was treated as orientation only. No value in this spec is sourced from it.
