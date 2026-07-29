# Session 2026-07-29-01 — prototype-design-alignment

## Where it started
Resumed via `/resume-project prototype-design-alignment`. The Resumption Brief flagged three drifts against the ledger: PR #82 had ALREADY been merged (the ledger said awaiting merge), local `main` was five behind `origin/main`, and the session-21 ledger branch was pushed with no PR. The user said "Go", merged each PR as it opened, then directed C7 to a PR and a hand-off.

## What shipped

**15 of 39 MSPs are merged** (A1-A5, B1-B4, C1, C4, C2, C6, C5, C3). `origin/main` is `3aa956f`. **Cluster C is one PR from closed.**

| Artifact | Where |
|---|---|
| C5 confirmed merged — drift correction, not work | PR #82 -> `49eaac0` |
| C3 shipped, validated, MERGED | PR #83 -> `3aa956f`; branch `msp-cluster-c/c3-mood-unset-state` `8913867` |
| C7 partial, validated, OPEN | PR #84; branch `msp-cluster-c/c7-video-poster-chrome` `2500926` |
| Ruling: C7's poster chrome is structurally blocked | decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md |

**C3 — mood unset state.** `MoodPromptBorderPainter` gained a `cardWarm` fill and the `heroSoft` hard offset shadow, radius 14 -> 16 (`Shapes.radiusLg`); `_MoodPrompt` became the prototype's row — half-opacity 46px peony bloom, `bannerSerif` question over a `promptAccent` subtitle, filled coral `choose` pill. Two files, +90/-14, zero test files.

**C7 — one of four target rows.** A `_posterBorderRadius` const (`Shapes.radiusCell` = 10) replaced `Shapes.cardBorderRadius` at the four poster render sites. One file, +6/-2. The other three rows are blocked; see below and the decision record.

## Tried and failed

- **C7's hatch, play badge and duration chip could not ship inside C7's fence.** Each was attempted or traced to a specific protected assertion, not assumed. Full reasoning in the decision record. Short form: the hatch swap reds `video_body_test.dart:400`, and the badge and chip anchors are physically occupied by `VideoTransport` and `VideoControlBar`, both of which are on screen at rest because `canAutoHideVideoControls` requires `isPlaying`.
- **The slice's §0 resolution 6 is a DEFECT.** It directs C7 to drop `NeutralMediaPlaceholder` for a direct `CrossHatchPlaceholder` in `video_body.dart`. That edit was made and produced a real red at `video_body_test.dart:400`, an N24 file. Closing the gap needs `media_placeholders.dart` (outside C7's fence) or the test (never editable). Reverted; `NeutralMediaPlaceholder` kept.
- **The brief's own hatch-colour instruction was wrong and was corrected by the implementer.** It said to pass `background` and `hatchColor` overrides. `hatchColor` is alpha-blended at 0.5 over the ground (`cross_hatch_placeholder.dart:73-75`), so passing `hatchMid` yields `#EEE6D7`, not `#E2D3BA`. `CrossHatchVariant.video` already pairs `hatchDark` `#D9C9AE` with `hatchMid` `#E2D3BA` at 6px/12px, 45 degrees — byte-exact for prototype `:128`. **Pass no colour overrides at all.**
- **The ledger's staleness figures were wrong for the FOURTH time**, in the opposite direction this time: PR #82 was recorded as awaiting a human merge and had already merged. Root cause is the same as session 21's — the ledger is written before the merge lands, and nothing reconciles it afterwards. Resume must always re-check `gh pr view` against the recorded state.
- No force-push was needed or attempted this session. C3 and C7 each branched off the current `origin/main` tip, so both first pushes were plain. **The `--force-with-lease` classifier is STILL untested and the granted rule is STILL absent from settings.json.**

## Verification

- **C3, `fullValidationCmd` verbatim: `flutter analyze` "No issues found!", `flutter test` 904 passed / 0 failed.** 904 was predicted before the run (zero test files touched, zero `testWidgets` added) and matched. Baseline re-measured on `49eaac0` before the first edit was also 904.
- **C7, same command: analyze clean, 904 passed / 0 failed.** The eight N24 files were run as a group **before the first edit and after**: `106 passed` both times, unmodified.
- **Four C7 blocking claims were re-verified by the orchestrator at source, not accepted from the agent's report**: `Palette.hatchDark` = `0xFFD9C9AE` and `hatchMid` = `0xFFE2D3BA` (exact); `video_body_test.dart:400` does assert `find.byType(NeutralMediaPlaceholder), findsOneWidget`; `video_controls_overlay_test.dart:326` does assert one reachable play affordance; `canAutoHideVideoControls` does require `isPlaying`.
- **C3's design was decided by a test, not by taste.** `mood_banner_test.dart:43-53` asserts NO `Semantics(button: true)` exists in the unset tree, and the prototype's `choose` div carries no `onClick`. The pill therefore shipped as pure decoration. That existing test passes unmodified.
- **`Opacity(0.5)` does not strip the bloom's semantics** — `RenderOpacity.visitChildrenForSemantics` drops the child only at `_alpha == 0`. Verified by direct read of the Flutter source, not assumed.
- Both PR head SHAs equal the locally validated tips. CI remains not evidence: neither GitHub check runs a Dart test.

## Running state
none. No background shells, no subagents, no `flutter run`.

## Deferred + open

- **PR #84 needs a HUMAN merge.** It ships 1 of C7's 4 target rows and says so in its own body. Merging it closes Cluster C's execution but NOT C7's intent.
- **Three C7 rows need re-scoping before they can ship** — see the decision record for the recommended shapes (hatch into a small `media_placeholders.dart` MSP; badge into an N3 MSP on `video_transport.dart`; chip needs a product ruling on its anchor).
- **Two values have no matching token** if the badge and chip are revived: badge fill `rgba(255,251,244,.92)` = `#FFFBF4` (closest `Palette.cardBright` `#FFFAF1`), chip ground `rgba(42,36,29,.7)` = `#2A241D` (no near token; `Palette.ink` is materially lighter). The chip's text style resolves cleanly to `TypographyTokens.syncPrimarySans` (already Instrument Sans 10 w600) plus a `color` copyWith. `formatMediaDuration` already exists at `lib/features/entry_cards/util/duration_format.dart:1` — do not write a second formatter.
- **The `Bash(git push --force-with-lease:*)` rule remains granted but unwritten and unproven.** It did not bite this session by luck of sequencing.
- **New orphan branch by construction:** `chore/ledger-handoff-session-21` stays at its pre-rebase tip; this hand-off ships from `chore/ledger-handoff-session-22`, which carries session 21's two commits rebased onto `3aa956f`. Joins `msp-cluster-c/c5-card-surface-body-strip`, `msp-cluster-c/c6-feed-empty-state`, `feat/cluster-c-today-centre`, `chore/ledger-handoff-session-16` through `-21`, and three stale stashes. All still need one explicitly confirmed batch removal.
- Standing and unchanged: §5.4's macOS visual pass carries two rulings (C1's flame cusp at (9,8), C5's tilt scatter); the four `integration_test/` flows never run; OQ-3 and OQ-6 open; `receipts.yml` runs unpinned third-party `shaheershoaib/receipts/enforcer@main` (chip `task_e10f4f7e`); A2/A4 blast radius never walked; the five A3 dialogs never opened.

## Demoted from PROJECT.md for cap (files unchanged on disk)

Three mitosis-operational decision index lines, spent now that decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md excludes mitosis for the whole remaining spec. Preserved verbatim:

- `decisions/2026-07-28-parked-ship-resumes-by-re-execution.md — a mitosis unit parked at `ship` resumes by FULL RE-EXECUTION, not by restoring its durable checkpoint; budget it as a re-run of that MSP. Root cause of the park: `builtSha` is sourced from the checkpoint-push agent's return (`mitosis.js:4598`) and that agent family is blocked by the harness safety classifier for authorizing an unconfirmed `git push --force-with-lease` (`:4586`), so the manifest records `"sha":null` for every unit; B1 shipped only by having no unmerged parent and skipping the `requireSha: true` frontier path (`:4306`). The engine exposes NO approve input, so a human "approve this tip" cannot be expressed to it. NEVER wipe `.mitosis/run.json` to force a clean run — shipped-state folding requires the unit in the prior manifest (`:3696`), so a blank manifest re-executes merged MSPs into duplicate PRs; rotate `worktreeRoot` or cut a new slice instead`
- `decisions/2026-07-28-mitosis-requires-serena-activation.md — activate Serena for the repo in the main thread BEFORE any mitosis dispatch; an unactivated Serena halted a whole run with `BLOCKED: needed=serena-activate_project`. The fix is PARTIAL and UNVERIFIED — activation reported `Programming languages: .` (empty, no Dart backend), so if a task blocks this way again the correct response is to stop requiring Serena semantic discovery on this repo and fall back to native grep/Read, NOT to re-activate`
- `decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json` (fold it with fold-run-log.mjs), NOT the harness `resumeFromRunId` cache; re-dispatch fresh with the same spec/baseBranch/sourcePrefix/worktreeRoot and each MSP resumes at its recorded stage; `worktreeRoot` is a REQUIRED input`

## Pick up here
Merge PR #84, then Cluster C's execution is closed and the next move is a decision, not an implementation: re-scope C7's three blocked rows per the decision record, or accept them as deferred and cut the Cluster D slice (D1 -> D2/D3/D4, right rail). Either way the §5.4 macOS visual pass is now due — it is the only check that can confirm this cluster, and it already owes rulings on C1's flame cusp and C5's tilt.
