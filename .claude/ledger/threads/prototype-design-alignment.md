---
thread: prototype-design-alignment
status: paused
updated: 2026-08-02
priority: high
completion_criteria:
  - "[x] Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason — MET at 712c978; C7's three rows are re-deferred with a recorded reason"
  - "[x] The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived — MET, and re-proven at 944 with the N24 path-scoped diff empty on all five Cluster H branches"
  - "[x] No dialog renders Flutter's yellow double-underline debug style (MSP A3) — MET, A3's DialogHost shipped"
  - "[x] The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware — MET for Clusters A-G. Cluster H adds only test infrastructure and touches zero files under lib/, so it has no visual surface"
  - "[ ] OQ-3 and OQ-6 are answered or explicitly closed as out of scope — THE ONLY UNMET CRITERION"
next_step: Answer or explicitly close OQ-3 and OQ-6, then record each as a decision record. Both are researched with verified-against-code recommendations in sessions/2026-08-02-02-prototype-design-alignment.md — read that section rather than re-deriving. Nothing else blocks `done`.
branch: `origin/main` `712c978`. RE-READ this at dispatch time, never trust this line — it has gone stale eleven times.
---

## Status
**CLUSTER H IS CLOSED AND THE SPEC HAS NO MSPs LEFT.** Every MSP is on main at `712c978`. Cluster H shipped as native stack 127 (#122 slice, #123-#126), merged top-down; H1 was decomposed into four stacked MSPs ordered by font risk. The suite went 918 -> 944 with 24 goldens where there was previously zero golden coverage. Mitosis stayed excluded for the whole spec, as decided.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Answer or explicitly close OQ-3 and OQ-6. Recommendations are ready in sessions/2026-08-02-02.

## Open Risks
- **A ledger handoff must branch from `origin/main`, never ride on an MSP branch.** Session 27's ledger was committed onto `msp-cluster-g/g8` (6817f29) and never merged; switching HEAD for Cluster H silently reverted the on-disk ledger to the pre-Cluster-G state. Caught by diffing on-disk against the commit, recovered by cherry-pick.
- **`goldens.yml` HAS NEVER EXECUTED ANYWHERE.** The next PR touching its `paths:` filter is its first run. A mass red there is an arch/OS mismatch against the macOS capture host and must NOT be answered with `--update-goldens` (R16 step 4).
- **Golden weights outside a font's fvar range are silent no-ops** — Instrument Sans 400-700, Newsreader 200-800, Caveat 400-700. w100-w300 are identical to w400 in two of the three families.
- goldens.yml carries four known non-blocking defects, none fixed: `macos-latest` FLOATS while the SDK is pinned exactly; the `paths:` filter OMITS `test/flutter_test_config.dart` and `dart_test.yaml`; no `timeout-minutes`/`concurrency` on a job billing at 10x (~60-120 billable min/run); `upload-artifact` fires on any step failure.
- **`scripts/d6-check.cjs` cannot block ANY PR here** — its `detectStack()` knows nothing about pubspec.yaml, so it degrades and exits 0. The `receipts/enforcer@main` half of R15 stays unconfirmed.
- **The `entry_card.dart:65-77` anchor is STALE** — Edit/Delete are at `:83-113`. Repeated dead at parent spec `:840` and cluster-C spec `:435`.
- **Baseline is 944 on main.** MEASURE it, never inherit it — the figure has been stale three times historically. Predict from your own diff BEFORE running `fullValidationCmd`. Clusters F, G and all four of H predicted and observed identically.
- **N24's untouchable files are under `test/features/entry_cards/playback/`**, NOT `test/cards/` or `test/playback/` — both shorthands name directories that DO NOT EXIST. Prove N24 with a path-scoped diff, never by assertion.
- **`git switch main` has aborted TWICE on uncommitted ledger edits.** Use `git switch -c <branch> origin/main`.
- **Do not launch the app detached** — `flutter run -d macos` needs a TTY. Hand the user the command; never fall back to the raw `.app` bundle.
- **`gh pr merge` and `gh pr create` are BOTH denied globally.** Every merge is a human action; every PR goes through the pr-create tool. **CI is not evidence** — no GitHub check runs a Dart test.
- **Never run `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into the real journal container. Name the single file.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- Branch disposal owed for the Cluster G AND Cluster H sets plus `chore/ledger-handoff-session-27` and `-28`. KEPT by standing directive and never proposed unprompted: the legacy `.fireplace-worktrees` (24) and `-poster-first` (4), the four stashes, the 22 `chore/ledger-handoff-session-*` branches.
- C7's badge/chip anchors and the chip's tokenless `#2A241D` are still open — never shipped, so no visual pass can rule on them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened.
- C4's restyled Edit/Delete are only observable in Day Detail. Do not wire them into Today — that pre-empts OQ-3.

## Key Decisions
- decisions/2026-08-02-font-weight-variation-verdict.md — fontWeight DOES drive the wght axis on 3.44.8; out-of-range weights are silent no-ops
- decisions/2026-08-02-goldens-pin-macos-ci.md — goldens.yml on macos-latest pinned to 3.44.8; macOS is forced, not preferred; a tolerance comparator is rejected
- decisions/2026-08-02-h1-splits-by-font-risk.md — H1 decomposes into four stacked MSPs ordered by font risk; blooms cover twelve kinds, not ten
- decisions/2026-08-02-cluster-g-visually-confirmed.md — Cluster G's pass PASSED; G8's macOS pause degradation accepted as shipped
- decisions/2026-08-01-cluster-e-and-f-visually-confirmed.md — the combined E+F pass PASSED
- decisions/2026-08-01-f4-cue-precedes-the-write.md — the pencil cue fires BEFORE the write; only the dialog is gated
- decisions/2026-08-01-meadow-keeps-the-shared-stroke.md — the meadow keeps E1's shared stroke
- decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md — SUPERSEDES the base-always-main ban; base-chaining alone is not a stack; REST linking
- decisions/2026-08-01-d2-shell-destination-promoted-to-riverpod.md — D2's tap-to-Calendar implemented; provider in `lib/state/`, `keepAlive` mandatory
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — resolve unreachable target values in-fence AT SLICE TIME; the precedent for E's 22, F's 20, G's 59 and H's 30 resolutions
- decisions/2026-07-28-c5-ships-as-is.md — C5 shipped knowingly incomplete on its 6px caption; **OQ-6 is what unblocks that value**
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — mitosis excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — N24 stays carved out
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`
- decisions/2026-07-20-keep-stale-worktrees.md — the legacy and poster-first worktrees are kept

## Out of Scope
- The markdown editor engine (its own spec; G2 shipped the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height, its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.
- Patching the vendored `camera_macos` plugin for real pause support.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. **OQ-3 is at :1996, OQ-6 at :2007.** Section 7's citation warning is understated: the spec family has been wrong about line numbers four times
- docs/specs/2026-08-02-prototype-alignment-cluster-h.md — the Cluster H slice, 30 resolutions. Its R17 defines the perturbation receipt and FORBIDS `git checkout -- <path>` as an autonomous revert
- docs/specs/2026-08-02-prototype-alignment-cluster-g.md — the Cluster G slice, 1833 lines, 59 resolutions. THE template for any future slice
- .github/workflows/goldens.yml — the pinned golden job, never yet executed
- docs/prototype/project/Field Notes.dc.html — the authoritative design source
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is **944** passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-02-02-prototype-design-alignment.md — **Cluster H CLOSED as stack 127; the toolchain gate answered; the OQ-3/OQ-6 recommendations and the demoted risks live here**
- sessions/2026-08-02-01- (Cluster G closed) / 2026-08-01-06- (Cluster F closed) / -05- / -04- / -03- / -02- / -01- / 2026-07-29-02- through 2026-07-27-01-prototype-design-alignment.md
