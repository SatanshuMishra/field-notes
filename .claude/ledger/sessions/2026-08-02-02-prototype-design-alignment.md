# Session 2026-08-02-02 — prototype-design-alignment

## Where it started
Resumed on `origin/main` `dd74688` with Cluster G closed and H1 (goldens) the only MSP left in the
spec, gated on an unverified toolchain question. The user approved the recommended next steps and
directed a dedicated small dynamic workflow to fully implement and ship Cluster H as a stack.

## What shipped
- **CLUSTER H CLOSED. THE SPEC HAS NO MSPs LEFT.** `origin/main` is `712c978`. Stack 127 shipped as
  five PRs #122 (slice) -> #123 h1 -> #124 h2 -> #125 h3 -> #126 h4, all merged by the user.
- **H1 was decomposed into FOUR stacked MSPs** rather than shipped as one PR. The split is by font
  risk, not by convenience: H1 harness + 3 text-free cross-hatch goldens, H2 twelve blooms, H3
  sticker cards + nav icons, H4 the three text-bearing sticker buttons. The text-bearing family
  ships at the TOP of the stack so it can be dropped without losing the harness.
- **24 goldens; the suite went 918 -> 944.** Zero golden coverage existed before this session.
- docs/specs/2026-08-02-prototype-alignment-cluster-h.md — the Cluster H slice, **30 primitive
  resolutions**.
- .github/workflows/goldens.yml — NEW. `macos-latest`, Flutter pinned to the exact string `3.44.8`,
  `flutter test --tags golden`, artifact upload of `test/design/goldens/failures/**` on failure,
  `paths:` filter. **IT HAS NEVER EXECUTED ANYWHERE.**
- Workflow: 11 agents, 0 errors, ~10.3h, 534 tool calls, 2.20M subagent tokens. Run
  `wf_c1090b77-361`; script at
  /Users/satanshumishra/.claude/projects/-Users-satanshumishra-Documents-DevLabs-fireplace/4ba1a409-3497-40cf-849b-e67188b0833d/workflows/scripts/cluster-h-goldens-wf_c1090b77-361.js

## THE TOOLCHAIN GATE — ANSWERED AFFIRMATIVELY, AND CLOSED
`TextStyle.fontWeight` DOES drive a variable font's `wght` axis on the installed toolchain. See
decisions/2026-08-02-font-weight-variation-verdict.md. The load-bearing residue:

- **Weights outside a family's real fvar range are silent no-ops.** Instrument Sans 400-700,
  Newsreader 200-800, Caveat 400-700. In Instrument Sans and Caveat, w100/w200/w300 are ALL
  byte-identical to w400 and w800/w900 identical to w700. A golden or a test intending to
  distinguish those weights passes while asserting nothing.
- `pubspec.yaml:22`'s `sdk: ^3.12.2` is the DART constraint and does NOT constrain Flutter. A
  contributor on Flutter 3.40 satisfies it, sits on the pre-change side, and reds every text-bearing
  golden with no local change to explain it. H1 added `environment: flutter: '>=3.41.0'` as the only
  machine-enforced local pin.
- The golden pixels now depend on the three .ttf files byte-for-byte, because they depend on those
  fvar axis ranges.

## Tried and failed
- **The session-27 ledger was committed onto `msp-cluster-g/g8` (6817f29) and never pushed or
  merged.** Switching HEAD to the Cluster H branches removed it from the working tree, and the
  on-disk ledger silently reverted to the pre-Cluster-G state (`updated: 2026-08-01`, "Cluster F is
  CLOSED"). Caught before writing this session by diffing the on-disk thread file against
  `6817f29`, and recovered by cherry-picking that commit onto `chore/ledger-handoff-session-28`.
  **NEXT TIME: a ledger handoff branches from `origin/main` and never rides on an MSP branch.** Had
  this gone unnoticed, session 28 would have been written on top of a ledger that did not know
  Cluster G shipped.
- **`gh api -f 'pull_requests[]=122'` is rejected by the stacks API with HTTP 422** (`"122" is not
  of type integer`) because `-f` sends strings. The working form is
  `echo '{"pull_requests":[122,123,124,125,126]}' | gh api --method POST repos/OWNER/REPO/stacks --input -`.
  This joins the two existing hard-won stack corrections (no `order` key; address by `number`, never
  the internal `id`).
- My dispatch called `058e0af2c2` the engine revision. It is the FRAMEWORK revision; the engine is
  `0cd610717b`. Do not pin the wrong hash when recording the golden toolchain contract.

## Corrections to the spec family, found by reading code
- **`entry_card.dart:65-77` is STALE.** Edit/Delete render in `EntryCard._header()` at
  `lib/features/entry_cards/entry_card.dart:83-113` (edit `:90-99`, delete `:100-109`). The dead
  anchor is repeated at parent spec `:840` and cluster-C spec 2026-07-28 `:435`.
- **`scripts/d6-check.cjs` cannot block ANY PR on this repo.** Its `detectStack()` recognises only
  package.json, go.mod, pyproject.toml, setup.py and setup.cfg; this repo root has only
  pubspec.yaml, so it degrades and exits 0. The `shaheershoaib/receipts/enforcer@main` half of R15
  remains unconfirmed — a third-party action on a moving ref that cannot be read locally.
- `PhotoTray` is DOUBLY dead: nothing imports it, and nothing imports its barrel either
  (`grep -rn "capture/photo" lib` returns zero).

## Verification
- `fullValidationCmd` at the stack tip `dda82e4`, measured first-hand by an independent validator:
  **944 passed / 0 failed, analyze clean.** The 918 baseline was re-measured first-hand on a
  detached `origin/main`, not inherited.
- **Every one of the four MSPs predicted its own total exactly**: 922, 934, 941, 944. Four for four.
- **THE PERTURBATION RECEIPT HOLDS.** `lib/design/tokens/shadows.dart:54` emphasis offset
  `Offset(2, 2)` -> `Offset(3, 2)` reds exactly `sticker_button_primary` ("Pixel test failed, 1.21%,
  110px diff detected") while siblings `_secondary` (null shadow) and `_danger` (Shadows.control)
  stay GREEN — the harness discriminates rather than merely running. Four real PNGs written to
  `test/design/goldens/failures/` at 168x54 RGBA and OPENED, not trusted by filename. Reverted by
  hand-edit because R17 step 3 forbids `git checkout -- <path>` as an autonomous step; revert proven
  by an empty whole-tree `git diff --stat`. 26/26 green after.
- Determinism: `flutter test --tags golden` run twice consecutively without `--update-goldens`,
  26/26 green both times, no golden PNG mutated.
- N24 PROVEN, not asserted: `git diff origin/main...<branch> -- test/features/entry_cards/playback/`
  is 0 lines on all five branches, and `--name-only -- lib/` is 0 files on all four MSP branches.
- Stack 127 read back live: five PRs bottom-to-top, each PR's recorded base SHA equal to the
  previous PR's head SHA, then all five `closed` with non-null `merged_at`.
- Code review verdict SHIP with ZERO blocking findings.

## Running state
none

## THE TWO OPEN QUESTIONS — researched, recommendations ready, decision NOT taken
The user deferred both to a fresh session. Do not re-derive this; it is verified against code.

**OQ-3 — entry-card Edit/Delete placement. RECOMMENDATION: ratify the status quo, (a) AND (c).**
The spec frames a three-way choice that is not one. (a) answers "where inside the card"; (c) answers
"on which screen". They are ORTHOGONAL and the app already does both: C4's interim placement shipped
at `b8375c1` (`IconStickerGlyph.edit`/`.trash` at `Shapes.radiusIconButton` = 8, 30x30 with a 15px
glyph), and Today stays action-free because `TodayEntryTile` passes neither callback. The only live
question is (b) hover-reveal versus the status quo. Reject (b): the fidelity argument for it is
BACKWARDS — the prototype's Day Detail buttons are unconditionally visible at
`Field Notes.dc.html:406-407`, so hover-reveal is a deviation FROM the prototype, it hides a
destructive action behind a gesture that does not exist on phone, and it is the only option costing a
widget rewrite. Reversibility VERY HIGH: ratifying costs zero lines; reversing later is ~20 lines in
one file; nothing touches the database, domain models, or any cross-cluster contract.
Independent cheap win, needing no OQ-3 resolution: `entry_card.dart:103` `background:
Palette.cardLight` -> `Palette.dangerSurface` gives the delete button the prototype's danger tint.

**OQ-6 — photo attachment model. RECOMMENDATION: the Wrap model, wired, cap 8, caption dropped.**
The spec says the answer "determines whether the work is a restyle or a new subsystem". For the
app's model it is NEITHER — it is a two-touchpoint mount, because the entire pipeline beneath the UI
is already built, wired and tested (`CaptureRequest.photos` exists on every request type). Cap 8
stays: 3 is not a real prototype constraint — the scrapbook engine caps nothing
(`md-scrapbook.js:457`) and 3 is a truncation the demo applies only when writing to its entry model.
Reject the free-manipulation canvas: parent spec 6.1 `:1960` already excludes it as a new subsystem,
so choosing it now would contradict the spec's own out-of-scope table.
**The ledger's "OQ-6 blocks a C5 target value" claim is CORRECT.** The blocked value is exactly one:
the 6px monospace photo-thumbnail caption at parent spec `:877-878`. Recommending it be dropped
permanently rather than adding `EntryPhoto.label`. Record the resolution as an extension of
decisions/2026-07-28-c5-ships-as-is.md, which explicitly left this to be answered deliberately.
Reversibility is MIXED and must be split: the cap (one constant, already a per-mount parameter) and
wire-vs-dead (two touch points) are both cheap and decidable immediately; **the MODEL choice is the
expensive one** and is the only part worth deliberating.

## Deferred + open, in order
1. **OQ-3 and OQ-6** — the ONLY thing standing between this thread and `done`. See above.
2. **goldens.yml has never executed.** The first PR touching its `paths:` filter is its first run.
   If the hosted runner reds the goldens en masse that is an arch/OS mismatch against the macOS
   capture host, and per R16 step 4 it must NOT be answered with `--update-goldens`.
3. Non-blocking review findings on goldens.yml, none fixed (branches were code-frozen and PR bodies
   are immutable after creation here): `macos-latest` is a FLOATING label while the SDK is pinned
   exactly, so a runner-image rotation can red all 24 goldens with no code change; the `paths:`
   filter OMITS `test/flutter_test_config.dart` and `dart_test.yaml`, the two files the whole
   mechanism depends on; no `timeout-minutes` and no `concurrency:` group on a job billing at a 10x
   multiplier (~60-120 billable minutes per run); `upload-artifact` fires on any step failure.
4. Three bloom goldens (`flower_aster`, `flower_chrysanthemum`, `flower_daffodil`) have ink touching
   the 44x44 frame edge under `EdgeInsets.zero`, so the outer half of a boundary stroke is cropped.
   Teeth are preserved but a purely outward silhouette regression would be only partly visible.
5. R11's font guard asserts only "width is not the Ahem advance", so it passes for ANY non-Ahem
   fallback and runs in its own isolate. It diagnoses; it does not gate. What actually makes H4 safe
   is `test/flutter_test_config.dart:16-30` awaiting `FontLoader.load()` before `testMain`.
6. Branch disposal owed: the Cluster G set (`msp-cluster-g/g1..g8`, `docs/cluster-g-slice`), the
   Cluster H set (`msp-cluster-h/h1..h4`, `docs/cluster-h-slice`), and
   `chore/ledger-handoff-session-27` and `-28`. One confirmed batch with an explicit list. The
   standing KEPT set is untouched: legacy `.fireplace-worktrees` (24), `-poster-first` (4), the four
   stashes, the 22 `chore/ledger-handoff-session-*` branches.
7. `test/design/goldens/failures/` holds 16 stale perturbation artifacts from the H2/H3 sessions.
   Correctly gitignored (`.gitignore:51`) and never committed — R10 is demonstrably working — but
   clearing it makes the next R17 clean-tree check read unambiguously.
8. C7's badge/chip anchors and the chip's tokenless `#2A241D` — never shipped, so no visual pass can
   rule on them. Survive Clusters G and H untouched.
9. #119's undeclared `SettingsSelect` `Flexible`/ellipsis ride-along, and #120's failed-save re-arm
   hole (timer half pre-existing on `main`; frozen readout new). A visual pass does not close either.
10. Patching the vendored `camera_macos` for real pause support is its own MSP if ever wanted.
11. Cluster H has had NO macOS visual pass, and by design needs none — it adds test infrastructure
    and touched zero files under `lib/`.

## Demoted from the thread spine and PROJECT.md (cap enforcement; all files unchanged on disk)
Five spine risks demoted because no cluster remains to execute and each is recorded above: the
stacks-API JSON-body correction; "a stacked PR's lower members are NOT independently validated,
merge from the TOP"; "a file-overlap matrix finds edges the spec's `Depends on` lines miss"; "neither
two-dot nor three-dot `git diff` proves a squash-merged branch is safe to delete — use
`gh pr list --state merged`"; and the three edge-cropped bloom goldens (item 4 above). All four
process rules held true again this session and should be re-read from here if a new cluster is ever
cut.

Three PROJECT.md decision-index lines demoted to one pointer: 2026-08-01-macos-visual-pass-confirmed
(the §5.4 pass, superseded in effect by the later E+F and G pass records),
2026-07-29-c7-rows-wait-on-the-visual-pass (the pass happened; C7's surviving open items live in the
thread's Open Risks), and 2026-07-28-force-push-permission-granted (spent — the permission was
granted and used without incident through Clusters D-H).

## Pick up here
Every MSP in the prototype-alignment spec is on `main` at `712c978`; nothing is mid-flight and no PR
is open. Only OQ-3 and OQ-6 remain, both researched with recommendations above. Answering them or
explicitly closing them, then recording the decisions, is all that stands between this thread and
`done`.
