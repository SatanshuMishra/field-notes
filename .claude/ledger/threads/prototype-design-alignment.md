---
thread: prototype-design-alignment
status: paused
updated: 2026-07-29
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Compose docs/specs/2026-07-29-prototype-alignment-cluster-d.md from the verified recon in sessions/2026-07-29-02-prototype-design-alignment.md. Format, values, fence, wave graph and both rulings are settled — do NOT re-run the recon. Land it on main, then dispatch D1 alone, then D2/D3/D4 in parallel.
branch: main `5f51c07`; working branch `docs/cluster-d-slice` at `e70bf25` (ledger only, slice not yet written)
---

## Status
**Cluster C is CLOSED — 16 of the parent spec's 39 MSPs are merged** (A1-A5, B1-B4, C1-C7). `origin/main` is `5f51c07`; zero open PRs. Two MSPs shipped knowingly incomplete: C5's 6px caption (OQ-6) and three of C7's four poster-chrome rows. Cluster D's slice inputs are fully verified but the slice itself is unwritten. Mitosis is excluded for the WHOLE remaining spec.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Write the Cluster D slice from the verified recon, land it on `main`, then run D1 -> {D2, D3, D4} as direct `implementer` dispatches.

## Open Risks
- **Do NOT re-run the Cluster D recon.** It cost ~460k subagent tokens and is captured in full in sessions/2026-07-29-02-prototype-design-alignment.md: citations, token map, four traps, stale claims, file-overlap matrix, undeclared test collisions, preserve bindings, slice format and the corrections to make rather than inherit.
- **The slice's §5.2 contradicts the ledger and must be corrected, not copied.** It says existing tests pass "unmodified"; decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md rules an MSP MAY retarget assertions pinning a rendering it is mandated to change.
- **Every §0 primitive resolution must name the test that would red if it is wrong.** C's resolution 6 was reasoned rather than receipted and cost C7 three rows.
- **D1 collides with D2, D3 AND D4 on source files**, so the wave graph is D1 -> {D2, D3, D4}. D1's stated `Depends on` line does not say this; the edges come from the file matrix.
- **Three test files have undeclared cross-MSP collisions** (`today_screen_test.dart` D1+D3+D4, `this_week_garden_test.dart` D1+D2 and mislabelled "new" when it exists, `on_this_day_card_test.dart` D1+D4 and declared under neither). Fix in the slice's fence.
- **The spec's §3.4 "Current app" column is STALE, not merely unreliable** — it predates Cluster A. Section headers, the button shadow split and `StickerButton`'s `icon` param already ship. Verify every claim at the call site.
- **The ledger's own branch/merge state has now been wrong FIVE times.** On resume, always re-check `gh pr view` and `git log origin/main` before acting.
- **Predict the expected test count from the diff BEFORE running `fullValidationCmd`.** Baseline on `main` is **904**.
- **N24's eight untouchable files**: `playback/video_slots_test.dart` (29), and under `cards/`: `video_body_lifecycle_test.dart` (20), `video_controls_overlay_test.dart` (18), `video_body_test.dart` (16), `video_body_slots_test.dart` (11), `video_body_poster_gate_test.dart` (7), `video_body_attempt_identity_test.dart` (4), `video_scrubber_test.dart` (1). Cluster D touches none of them.
- **`git push --force-with-lease` is classifier-blocked for the MAIN THREAD** and the granted rule is STILL absent from every settings file (re-verified this session). Workaround remains a new `-rebased` ref.
- **§5.4's macOS visual pass now owes FOUR rulings**: C1's flame cusp at (9,8), C5's tilt scatter, C7's badge/chip anchors, and the chip's tokenless ground `#2A241D`. It is the only check that can confirm Clusters C and D.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Describe copy in prose in PR fields, never quote it.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` excludes them. Triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **Serena has no Dart backend on this repo.** Use native grep/Read.
- **C4's restyled Edit/Delete are only observable in Day Detail** (`day_detail_entry_tile.dart:36-37`). Do not wire them into Today — that pre-empts OQ-3.
- **Orphan branches now number ten**, plus three stale stashes: `msp-cluster-c/c5-card-surface-body-strip`, `msp-cluster-c/c6-feed-empty-state`, `feat/cluster-c-today-centre`, `chore/ledger-handoff-session-16` through `-22`. All need one explicitly confirmed batch removal.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b/c` checkouts and their `msp-cluster-*` branches are KEPT by standing directive. Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- OQ-3 and OQ-6 unanswered. **OQ-6 blocks a C5 target value**; D4's title was deliberately resolved WITHOUT answering it.

## Key Decisions
- decisions/2026-07-29-cluster-d-fence-defects-resolved-pre-dispatch.md — D4 repurposes the preview as its serif title; D3 gets an optional `labelStyle` param on `StickerButton` as a declared one-file fence widening
- decisions/2026-07-29-c7-rows-wait-on-the-visual-pass.md — C7's three blocked rows deferred to §5.4, Cluster D cut first
- decisions/2026-07-29-c7-poster-chrome-blocked-by-protected-anchors.md — C7 shipped 1 of 4 rows; badge belongs to N3, hatch to `media_placeholders.dart`, chip needs a product ruling
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
- sessions/2026-07-29-02-prototype-design-alignment.md — **the Cluster D slice's verified inputs.** Read this before writing the slice
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. D1-D4 at `:952-1115`. Clusters D-H still need slices cut
- docs/specs/2026-07-28-prototype-alignment-cluster-c.md — the executed Cluster C slice; the structural template for D. Its §0 resolution 6 and §5.2 are DEFECTIVE — see Open Risks
- docs/prototype/project/Field Notes.dc.html — the authoritative design source. D1-D4's citations verified clean this session
- receipts.config.json — `fullValidationCmd` is the local gate; baseline on `main` is 904 passed, 0 failed, analyze clean

## Recent Sessions
- sessions/2026-07-29-02-prototype-design-alignment.md — **Cluster C closed; C7 rows deferred; Cluster D recon completed and both fence defects resolved pre-dispatch**
- sessions/2026-07-29-01-prototype-design-alignment.md — C3 shipped and merged; C7 partial as PR #84 with its three blocked rows evidenced
- sessions/2026-07-28-07- / -06- / -05- / -04- / -03- / -02- / -01-prototype-design-alignment.md
