---
thread: prototype-design-alignment
status: paused
updated: 2026-08-01
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - "[x] The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware — MET 2026-08-01, re-confirmed on merged main 9769bba covering all of Cluster D"
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Cut the Cluster E slice (flower art, E1-E4) from the parent spec, using docs/specs/2026-07-29-prototype-alignment-cluster-d.md as the template. E has an in-cluster chain (E2/E3 depend on E1; E4 on E1+E2+E3), so it runs as direct `implementer` waves, one PR per MSP, every PR `--base main`. Never mitosis.
branch: `origin/main` `9769bba`. Cluster D CLOSED and cleaned; no MSP branch or worktree remains for it. Nothing is stranded for the first time since Cluster C.
---

## Status
**Cluster D is CLOSED: 20 of 39 MSPs are on main** (A1-A5, B1-B4, C1-C7, D1-D4) at `9769bba`. D4 (#95) and D2 (#96) were re-landed as fresh cuts off main, never by PRing D1's branch. D2's tap-to-Calendar — the one criterion Cluster D had left unfixed — is IMPLEMENTED, not dropped. The macOS visual pass passed again on merged main, covering both. Mitosis stays excluded for the whole remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Cut the Cluster E slice. Full ordered list in sessions/2026-08-01-03-prototype-design-alignment.md's "Deferred + open".

## Open Risks
- **`@riverpod` is autoDispose BY DEFAULT in Riverpod 3.** Any provider holding state that must outlive its watchers needs `@Riverpod(keepAlive: true)`. D2's shell destination silently reset without it; the tap test caught it red. Check this on every new stateful provider in E-H.
- **Baseline is now 904** after Cluster D (903 before D4/D2, each adding one case). Always predict the count from the diff BEFORE running `fullValidationCmd`, then compare.
- **The ledger's branch/merge state has been wrong EIGHT times.** On resume, always re-check `gh pr view` and `git log origin/main` before acting.
- **N24's eight untouchable files**: `playback/video_slots_test.dart` (29), and under `cards/`: `video_body_lifecycle_test.dart` (20), `video_controls_overlay_test.dart` (18), `video_body_test.dart` (16), `video_body_slots_test.dart` (11), `video_body_poster_gate_test.dart` (7), `video_body_attempt_identity_test.dart` (4), `video_scrubber_test.dart` (1). Cluster D touched none.
- **C7's badge/chip anchors and the chip's tokenless `#2A241D` are still open** — the visual pass could not settle them because they were never shipped (structurally blocked). Everything that IS on screen is confirmed.
- **Do not launch the app detached.** `flutter run -d macos` under `nohup` builds then logs `Failed to foreground app` and loses the device; it needs a TTY. Hand the user the command. Never fall back to the raw `.app` bundle.
- **For one long command, background it from the main thread** rather than wrapping it in a subagent (a dispatched agent returned empty twice and its shell was swept with teardown). `pr-create` caps every free-text field at 200 chars and the title at 72; it names the constraint but not which value broke it.
- **`git push --force-with-lease` is classifier-blocked for the MAIN THREAD** and the granted rule is still absent from every settings file. Workaround remains a new `-rebased` ref.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Describe copy in prose in PR fields, never quote it.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **Never run `flutter test integration_test/` as a directory** — `capture_save_persist_test.dart` writes into the real journal container (the `post-ship-hardening` thread's bug). Name the single file.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- **Cluster D is fully cleaned:** zero cluster-d worktrees, zero `msp-cluster-d/*` branches, local and remote. The Cluster A/B/C, poster-first and legacy worktrees plus FOUR stashes remain and still owe a confirmed batch removal with an explicit list.
- The `.fireplace-worktrees-cluster-a/b/c` checkouts and their `msp-cluster-*` branches are KEPT by standing directive. Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- C4's restyled Edit/Delete are only observable in Day Detail (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- OQ-3 and OQ-6 unanswered. **OQ-6 blocks a C5 target value**; D4's title was deliberately resolved WITHOUT answering it.

## Key Decisions
- decisions/2026-08-01-d2-shell-destination-promoted-to-riverpod.md — D2's tap-to-Calendar is implemented, not dropped; one-file shell widening, provider in `lib/state/`, `keepAlive` mandatory
- decisions/2026-08-01-d3-chooser-test-deletion-is-correct.md — the 903 is correct, not a regression; baseline is now 903
- decisions/2026-08-01-macos-visual-pass-confirmed.md — §5.4 passes on cfa04c7; completion criterion 4 MET; C7's unshipped rows unaffected
- decisions/2026-08-01-msp-prs-target-main-never-another-msp-branch.md — an MSP PR's base is ALWAYS main; downstream MSPs wait, rebase `--onto main`, revalidate, then open
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — D4 repurposes the preview as its serif title; D3 gets an optional `labelStyle` param on `StickerButton` as a declared one-file fence widening
- decisions/2026-07-29-c7-rows-wait-on-the-visual-pass.md — C7's three blocked rows deferred to §5.4; see also -c7-poster-chrome-blocked-by-protected-anchors.md for why they are blocked
- decisions/2026-07-28-c5-ships-as-is.md — C5 shipped knowingly incomplete on its 6px caption
- decisions/2026-07-28-direct-implementer-waves-for-all-remaining-clusters.md — every remaining cluster has an in-cluster chain, so mitosis is excluded for the whole spec
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it must change; N24 stays carved out
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — rebase `--onto main` after each merge, revalidate on the new base
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height, its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.

## Pointers
- docs/specs/2026-07-29-prototype-alignment-cluster-d.md — **the Cluster D slice, landed on main.** The binding contract for D1-D4
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. Clusters E-H still need slices cut
- docs/prototype/project/Field Notes.dc.html — the authoritative design source. D1-D4's citations verified clean, zero errors
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is **903** passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-08-01-03-prototype-design-alignment.md — **Cluster D CLOSED (D4 #95, D2 #96 merged); tap-to-Calendar shipped; worktrees and branches cleaned. Next actions live here**
- sessions/2026-08-01-02- / 2026-08-01-01- / 2026-07-29-02- / 2026-07-29-01- / 2026-07-28-07- through -01-prototype-design-alignment.md
