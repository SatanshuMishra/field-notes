---
thread: prototype-design-alignment
status: paused
updated: 2026-08-01
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - "[ ] The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware — Clusters A-D MET 2026-08-01 on merged main 9769bba; RE-OPENED by Cluster E, whose flower art has had ZERO visual confirmation"
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Run the macOS visual pass on Cluster E's flower art (`flutter run -d macos`, handed to the user, never detached). Then settle the meadow-stroke question in Open Risks. Then cut the Cluster F slice (mood picker, F1-F4) using the Cluster E slice as the template.
branch: `origin/main` `93de164`. Cluster E CLOSED and cleaned; no Cluster E branch or worktree remains, local or remote.
---

## Status
**Cluster E is CLOSED: 24 of 39 MSPs are on main** (A1-A5, B1-B4, C1-C7, D1-D4, E1-E4) at `93de164`. Cluster E shipped as the project's first NATIVE GITHUB STACK (stack 103: #99 -> #100 -> #101 -> #102), plus slice #98. Mitosis stays excluded for the whole remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
macOS visual pass on the flower art, then the meadow-stroke question, then cut the Cluster F slice. Full ordered list in sessions/2026-08-01-04-prototype-design-alignment.md's "Deferred + open".

## Open Risks
- **UNRESOLVED DESIGN QUESTION: the meadow's stroke colour and width changed in E1.** There is exactly one shared `_stroke(d)` and E1's mandate was that it stop hardcoding `Palette.ink`. Composition IS preserved literally (every plant kept its stem, leaf, centre at `height*0.42`, byte-identical geometry); only outline hue and weight moved (at d=44: chrysanthemum 1.5 -> 0.8, spider lily 1.5 -> 1.8). Reverting the meadow to `Palette.ink` needs a spec amendment plus a second stroke path.
- **Baseline is 905 on main, not 904** — measured directly, three implementers flagged it, one proved it by stashing its diff. The old 904 predates #95/#96. Cluster E's branch head was 907. Always predict the count from the diff BEFORE running `fullValidationCmd`, then compare.
- **N21's `resolveGardenMotionProfile` DOES NOT EXIST.** Real symbol is `resolveGardenMotion` at `lib/features/garden/garden_motion.dart:5-13`; the preserve item fused the enum name onto the function name.
- **N24's eight untouchable files are under `test/features/entry_cards/`, NOT `test/cards/`** — the shorthand circulated for weeks named two directories that do not exist. Plus `test/playback/video_slots_test.dart`. Cluster E touched none.
- **STACKED PRs ARE THE PROVEN PATTERN for F-H.** Open with `--base` the branch below, then link via `POST /repos/SatanshuMishra/field-notes/stacks` (ordered bottom-to-top). Base-chaining ALONE is not a stack. Verified empirically: the cascade retargets WITHOUT branch deletion. Merge bottom-up; a mid-stack merge takes everything below it in one operation.
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
- docs/specs/2026-08-01-prototype-alignment-cluster-e.md — **the Cluster E slice, 1236 lines, landed on main. The strongest slice template yet; its 22 PRIMITIVE RESOLUTIONS section is the pattern to copy for F-H**
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. Clusters F-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is **905** passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-01-04-prototype-design-alignment.md — **Cluster E CLOSED as native stack 103 (#98-#102 merged); baseline corrected to 905; N21/N24 anchors corrected; branches cleaned. Next actions live here**
- sessions/2026-08-01-03- / -02- / -01- / 2026-07-29-02- through 2026-07-27-01-prototype-design-alignment.md
