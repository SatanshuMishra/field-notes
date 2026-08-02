---
thread: prototype-design-alignment
status: paused
updated: 2026-08-01
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - "[ ] The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware — Clusters A-D MET 2026-08-01 on merged main 9769bba; RE-OPENED by Clusters E and F, whose flower art and mood picker have had ZERO visual confirmation"
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Run ONE macOS visual pass covering BOTH Cluster E's flower art and Cluster F's mood picker (`flutter run -d macos`, handed to the user, never detached). Then cut the Cluster G slice (capture composers, G1-G8) using the Cluster F slice as the template.
branch: `origin/main` `a6cdcc2`. Cluster F CLOSED; its five branches still exist locally and owe a confirmed batch disposal.
---

## Status
**Cluster F is CLOSED: 28 of 39 MSPs are on main** (A1-A5, B1-B4, C1-C7, D1-D4, E1-E4, F1-F4) at `a6cdcc2`. Cluster F shipped as native stack 110 (#106 -> #107 -> #108 -> #109) plus slice #105, the SECOND clean use of the pattern. Remaining: G1-G8 (capture composers) and H1 (goldens). Mitosis stays excluded for the whole remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
One combined macOS visual pass over Cluster E's flower art and Cluster F's mood picker, then cut the Cluster G slice. Full ordered list in sessions/2026-08-01-06-prototype-design-alignment.md's "Deferred + open".

## Open Risks
- **Baseline is 910 on main** — measured 2026-08-01 at `a6cdcc2` (907 before F4 added three cases). The recorded figure has now been stale THREE times running (904 -> 905 -> 907 -> 910). MEASURE it, never inherit it, and always predict the count from your diff BEFORE running `fullValidationCmd`, then compare. Cluster F predicted and observed identically on all four MSPs.
- **N21's `resolveGardenMotionProfile` DOES NOT EXIST.** Real symbol is `resolveGardenMotion` at `lib/features/garden/model/garden_motion.dart:5` (verified 2026-08-01; the recon's corrected path also dropped the `model/` segment). The preserve item fused the enum name onto the function name. `meadow_painter.dart` likewise lives at `lib/features/garden/paint/meadow_painter.dart`.
- **N24's eight untouchable files are under `test/features/entry_cards/`, NOT `test/cards/`** — the shorthand circulated for weeks named two directories that do not exist. Plus `test/playback/video_slots_test.dart`. Cluster E touched none.
- **STACKED PRs ARE THE PROVEN PATTERN for G-H — now used twice cleanly** (stack 103, stack 110). Open with `--base` the branch below, then link via `gh api --method POST /repos/SatanshuMishra/field-notes/stacks -F 'pull_requests[]=<n>'` ordered bottom-to-top; the typed `-F` form was accepted first try. Base-chaining ALONE is not a stack. The cascade retargets WITHOUT branch deletion. Merge bottom-up. The slice always ships as its own docs PR OUTSIDE the stack.
- **`defaultTargetPlatform` is forced to ANDROID under `flutter test`** by an SDK assert in `_platform_io.dart` keyed on `FLUTTER_TEST`. Any widget test exercising a form-factor branch hits the PHONE path unless the harness overrides it. This bit F3 and will bite Cluster G's composers. Keep direct-pump widget defaults desktop or desktop coverage is silently lost.
- **Cluster F is visually UNCONFIRMED** — picker chrome, a grid relayout and a bottom sheet, all heavily visual, and every F PR carries an explicit not-verified line saying no agent can run the app.
- **Reading `soundServiceProvider` in a widget test needs two extra provider overrides** (`appSettingsProvider`, `soundPlayerProvider`) or drift's `StreamQueryStore.markAsClosed` leaves a pending Timer and the test fails with nothing in the stack naming the feature under test. A Timer cancelled in `dispose()` satisfies the invariant.
- **Pass Workflow `args` as an actual JSON value, never a stringified one** — a stringified object reaches the script with every `args.*` undefined. It silently produced a slice named `undefined-...` this session.
- **The ledger's branch/merge state has been wrong NINE times.** On resume, always re-check `gh pr view` and `git log origin/main` before acting. Compare branches against `origin/main`, NEVER the local `main` ref — it goes stale and gives false unmerged counts.
- **`git switch main` has now aborted TWICE on uncommitted ledger edits.** Use `git switch -c <handoff-branch> origin/main` as the default move, not a fallback.
- **Do not launch the app detached.** `flutter run -d macos` under `nohup` builds then logs `Failed to foreground app` and loses the device; it needs a TTY. Hand the user the command. Never fall back to the raw `.app` bundle.
- **Long commands run FOREGROUND inside a subagent with a 600000ms timeout** — a subagent's background shells are swept at teardown, which burned two earlier attempts.
- **`pr-create` caps every free-text field at 200 chars and the title at 72, and rejects non-ASCII**, naming neither the field nor the character. Describe copy in prose, never quote it. The tool is at `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`, NOT the repo-relative path the global rule states.
- **`gh pr merge` is denied globally.** Every merge is a human action. `git push --force-with-lease` is classifier-blocked for the MAIN THREAD and the granted rule is still absent from every settings file.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **Never run `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into the real journal container (the `post-ship-hardening` thread's bug). Name the single file.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- The `.fireplace-worktrees-cluster-a/b/c`, poster-first and legacy checkouts, their `msp-cluster-*` branches and FOUR stashes are KEPT by standing directive and still owe a confirmed batch removal with an explicit list. Do not propose removing them unprompted.
- C7's badge/chip anchors and the chip's tokenless `#2A241D` are still open — never shipped, so no visual pass can rule on them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. Section 7 says re-open rather than trust inherited citations.
- C4's restyled Edit/Delete are only observable in Day Detail (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- OQ-3 and OQ-6 unanswered. **OQ-6 blocks a C5 target value.**

## Key Decisions
- decisions/2026-08-01-f4-cue-precedes-the-write.md — the pencil cue fires BEFORE the write, so a failed write cues and shows no toast; only the dialog is gated
- decisions/2026-08-01-meadow-keeps-the-shared-stroke.md — the meadow keeps E1's shared stroke; no amendment, no second path
- decisions/2026-08-01-cluster-e-ships-as-a-native-github-stack.md — SUPERSEDES the base-always-main ban; Cluster E shipped as native stack 103; base-chaining alone is not a stack; REST linking, no `gh stack` extension
- decisions/2026-08-01-d2-shell-destination-promoted-to-riverpod.md — D2's tap-to-Calendar is implemented, not dropped; one-file shell widening, provider in `lib/state/`, `keepAlive` mandatory
- decisions/2026-08-01-macos-visual-pass-confirmed.md — section 5.4 passed on cfa04c7 for Clusters A-D; Cluster E re-opens the criterion
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — resolve a target value whose anchor is unreachable inside its fence AT SLICE TIME; the direct precedent for Cluster E's 22 primitive resolutions
- decisions/2026-07-28-c5-ships-as-is.md — C5 shipped knowingly incomplete on its 6px caption
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — every remaining cluster has an in-cluster chain, so mitosis is excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it must change; N24 stays carved out
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary
- decisions/2026-07-20-keep-stale-worktrees.md — the A/B/C, poster-first and legacy worktrees are kept; never propose removal unprompted

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height, its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.

## Pointers
- docs/specs/2026-08-01-prototype-alignment-cluster-f.md — **the Cluster F slice, 955 lines, 20 primitive resolutions. THE template for G-H: it deleted two rows as already-satisfied and resolved an unreachable border in-fence**
- docs/specs/2026-08-01-prototype-alignment-cluster-e.md — the Cluster E slice, 1236 lines, 22 primitive resolutions
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. Clusters F-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is **910** passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-01-06-prototype-design-alignment.md — **Cluster F CLOSED as native stack 110 (#105-#109 merged); baseline measured 910; the recon findings and the ordered next actions live here**
- sessions/2026-08-01-05- (meadow question settled) / -04- (Cluster E closed) / -03- / -02- / -01- / 2026-07-29-02- through 2026-07-27-01-prototype-design-alignment.md
