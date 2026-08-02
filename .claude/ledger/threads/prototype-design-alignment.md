---
thread: prototype-design-alignment
status: paused
updated: 2026-08-02
priority: high
completion_criteria:
  - "[ ] Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason — BLOCKED ONLY BY H1 (goldens); C7's three rows are re-deferred with a recorded reason"
  - "[x] The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived — MET, 918 passed at dd74688 with the N24 path-scoped diff empty"
  - "[x] No dialog renders Flutter's yellow double-underline debug style (MSP A3) — MET, A3's DialogHost shipped"
  - "[x] The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware — MET for Clusters A-G, per the two visual-pass decision records. H1 has no visual surface"
  - "[ ] OQ-3 and OQ-6 are answered or explicitly closed as out of scope — STILL OPEN; OQ-6 blocks a C5 target value"
next_step: Cut and ship H1 (goldens), the LAST MSP in the spec. Read parent spec lines 1854-1888. FIRST confirm which side of Flutter's font-weight-variation breaking change the installed toolchain sits on — every text-bearing golden depends on it and it is currently unverified. Then answer or explicitly close OQ-3 and OQ-6, which is all that stands between this thread and `done`.
branch: `origin/main` `dd74688`. RE-READ this at dispatch time, never trust this line — it went stale mid-session when a ledger PR merged underneath a running workflow.
---

## Status
**Cluster G is CLOSED: 36 of 39 MSPs are on main** (A1-A5, B1-B4, C1-C7, D1-D4, E1-E4, F1-F4, G1-G8) at `dd74688`. Cluster G shipped as native stack 121 (#112 slice, then #113-#120), merged top-down in one cascade — the THIRD clean use of the pattern and the first at nine PRs. H1 (goldens) is the only MSP left. Mitosis stays excluded for the remainder.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
H1 (goldens), gated on a toolchain check. Full ordered list in sessions/2026-08-02-01-prototype-design-alignment.md's "Deferred + open".

## Open Risks
- **H1's determinism is unverified and it is the whole point of the MSP.** Golden font rendering is platform- and SDK-dependent; `pubspec.yaml:22` pins `sdk: ^3.12.2`, and Flutter's driving of a variable font's `wght` axis from `TextStyle.fontWeight` landed in a specific release. Confirm which side of that change the installed toolchain sits on BEFORE capturing any golden with text in it. Capture at integer DPR; do NOT attempt an in-app pixel-snapping workaround.
- **G8's video pause is UNREACHABLE on macOS** — `camera_macos` has no pause in its Dart or Swift layer. Shipped as a `supportsPause` degradation; the criterion is met on Android only and the user accepted the degraded path on hardware. Patching the vendored plugin is its own MSP, not a G8 defect.
- **The GitHub stacks API has NO `order` key.** `GET /stacks/121` returns `['base','created_at','id','node_id','number','open','pull_requests','url']`; ordering lives in the `pull_requests` array. The addressable id is the `number` (121), not the internal `id`. CORRECTS the stack-110 record in sessions/2026-08-01-06.
- **Baseline is 918 on main**, measured at `cf4242f` (910 before Cluster G). MEASURE it, never inherit it — the recorded figure has been stale three times historically. Always predict from your own diff BEFORE running `fullValidationCmd`, then compare. Clusters F and G both predicted and observed identically.
- **A stacked PR's lower members are NOT independently validated.** Only the tip carried a first-hand green in Cluster G; #113-#119 each disclosed this. Merge stacks from the TOP so the cascade takes the unvalidated intermediates together, never mid-stack.
- Two risks a visual pass does NOT close, still open: #119's undeclared `SettingsSelect` `Flexible`/ellipsis ride-along, and #120's failed-save re-arm hole (timer half pre-existing on `main`; frozen readout new).
- **A file-overlap matrix finds edges the spec's `Depends on` lines miss** — Cluster G's real graph needed G6 -> G7 (`toast.dart` variant plus the shared close glyph), which no `Depends on` line declared. Compute the matrix per cluster; the declared chain is not sufficient.
- **N21's `resolveGardenMotionProfile` DOES NOT EXIST.** Real symbol is `resolveGardenMotion` at `lib/features/garden/model/garden_motion.dart:5`. `meadow_painter.dart` is at `lib/features/garden/paint/meadow_painter.dart`.
- **N24's untouchable files are under `test/features/entry_cards/playback/`, NOT `test/cards/` or `test/playback/`** — both shorthands name directories that do not exist. Prove N24 with a path-scoped diff, never by assertion.
- **The ledger's branch/merge state has been wrong NINE times, and `branch:` above went stale a TENTH.** Always re-check `gh pr list` and `git log origin/main` before acting. Compare against `origin/main`, never the local `main` ref.
- **Neither two-dot nor three-dot `git diff` proves a squash-merged branch is safe to delete.** Two-dot counts main's newer work as deletions; three-dot's merge base predates the squash. Use the merged-PR record (`gh pr list --state merged`).
- **`git switch main` has aborted TWICE on uncommitted ledger edits.** Use `git switch -c <branch> origin/main` as the default move.
- **Do not launch the app detached.** `flutter run -d macos` under `nohup` loses the device; it needs a TTY. Hand the user the command. Never fall back to the raw `.app` bundle.
- **`gh pr merge` is denied globally.** Every merge is a human action. **CI is not evidence** — neither GitHub check runs a Dart test; the only gate is a local `fullValidationCmd` against the PR head.
- **Never run `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into the real journal container. Name the single file.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- Branch disposal owed for the Cluster G set (`msp-cluster-g/g1..g8`, `docs/cluster-g-slice`, `chore/ledger-handoff-session-27`). KEPT by standing directive and NOT to be proposed unprompted: the legacy `.fireplace-worktrees` (24) and `-poster-first` (4), the four stashes, the 22 `chore/ledger-handoff-session-*` branches.
- C7's badge/chip anchors and the chip's tokenless `#2A241D` are still open — never shipped, so no visual pass can rule on them. They survive Cluster G untouched.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. Section 7 says re-open rather than trust inherited citations.
- C4's restyled Edit/Delete are only observable in Day Detail (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.

## Key Decisions
- decisions/2026-08-02-cluster-g-visually-confirmed.md — Cluster G's pass PASSED; G8's macOS pause degradation accepted as shipped
- decisions/2026-08-01-cluster-e-and-f-visually-confirmed.md — the combined E+F pass PASSED; criterion 4 met for all 28 MSPs merged at that point
- decisions/2026-08-01-f4-cue-precedes-the-write.md — the pencil cue fires BEFORE the write; only the dialog is gated
- decisions/2026-08-01-meadow-keeps-the-shared-stroke.md — the meadow keeps E1's shared stroke; no amendment, no second path
- decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md — SUPERSEDES the base-always-main ban; base-chaining alone is not a stack; REST linking, merge bottom-up
- decisions/2026-08-01-d2-shell-destination-promoted-to-riverpod.md — D2's tap-to-Calendar implemented, not dropped; provider in `lib/state/`, `keepAlive` mandatory
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — resolve an unreachable target value in-fence AT SLICE TIME; the precedent for E's 22, F's 20 and G's 59 resolutions
- decisions/2026-07-28-c5-ships-as-is.md — C5 shipped knowingly incomplete on its 6px caption
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — mitosis excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget assertions pinning a rendering it must change; N24 stays carved out
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary
- decisions/2026-07-20-keep-stale-worktrees.md — the legacy and poster-first worktrees are kept; never propose removal unprompted

## Out of Scope
- The markdown editor engine (its own spec; G2 shipped the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height, its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.
- Patching the vendored `camera_macos` plugin for real pause support.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. **H1 is at lines 1854-1888.** Section 7's citation warning is understated: the spec family has been wrong about line numbers three times
- docs/specs/2026-08-02-prototype-alignment-cluster-g.md — the Cluster G slice, 1833 lines, 59 primitive resolutions, 28 deleted rows. THE template for H1 and any future slice
- docs/specs/2026-08-01-prototype-alignment-cluster-f.md / -cluster-e.md — the earlier slices, 955 and 1236 lines
- docs/prototype/project/Field Notes.dc.html — the authoritative design source
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is **918** passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-02-01-prototype-design-alignment.md — **Cluster G CLOSED as stack 121 (#112-#120 merged); A-F worktrees disposed; baseline 918; the demoted spine risks and the ordered next actions live here**
- sessions/2026-08-01-06- (Cluster F closed) / -05- / -04- / -03- / -02- / -01- / 2026-07-29-02- through 2026-07-27-01-prototype-design-alignment.md
