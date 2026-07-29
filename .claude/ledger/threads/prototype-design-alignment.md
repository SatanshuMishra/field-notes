---
thread: prototype-design-alignment
status: paused
updated: 2026-07-28
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Merge PR #73 (ledger) and #74 (C1). Then run the ship loop once per remaining MSP, ONE AT A TIME, never two PRs open — rebase `--onto main`, re-run `fullValidationCmd` against the new head, open one PR via `~/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create`, wait for the human merge. All three are implemented, green and pushed: C4 `6938034`, C2 `b02c842`, C6 `179e4b8` (suggested order C4 -> C2 -> C6; they share `today_screen.dart`, C6 is disjoint). Then Wave 2 — C3 on merged C2, C5 on merged C4 — then Wave 3 (C7).
branch: msp-cluster-c/{c1-streak-card,c2-header-mood-set,c4-eyebrow-card-header,c6-feed-empty-state}; ledger on chore/ledger-handoff-session-17
---

## Status
**CLUSTER B IS FULLY CLOSED** — B1-B4 merged (#62-#65) and the §5.4 macOS visual pass passed on 2026-07-28, which was its last gate. **The Cluster C slice is cut and merged** (#71, `93c6865`). 10 of the parent spec's 39 MSPs are shipped (A1-A5, B1-B4, plus the slice itself is infrastructure, not an MSP). `main` is `93c6865`. **ALL FOUR WAVE 1 MSPs ARE IMPLEMENTED, GREEN AND PUSHED** (C1 `a0904d3`, C2 `b02c842`, C4 `6938034`, C6 `179e4b8`), worktrees under `.fireplace-worktrees-cluster-c/`. **Nothing has merged**: C1 is PR #74, the other three hold per the one-PR-at-a-time rule. PR #73 lands the orphaned session-03 ledger. Both PRs need a human merge. **The real baseline is 903, not the 902 the slice records** — #70 added tests after that figure was measured.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Merge #73 and #74, then ship C4, C2, C6 one at a time — rebase `--onto main`, `fullValidationCmd` on the new head, one PR, human merge, repeat. Then Wave 2 (C3 after C2, C5 after C4), then Wave 3 (C7). The slice's §0 SERIALIZATION declares the lib-file edges; note it does NOT cover test files, and C2+C4 also share `today_screen_test.dart`.

## Open Risks
- **C1's flame glyph is unverifiable by any automated check.** `flame_icon.dart` hand-transcribes a 24-viewBox SVG path; the test asserts only `find.byType(FlameIcon)`, never the rendered shape. Re-derivation confirmed the arc (perfect semicircle, `clockwise: true`, bulb bulges down — fails loudly, not subtly, if inverted) and nonZero fill. **Residual risk is the cusp at (9,8), the flame's inner notch** — a one-digit error there renders as a lumpy flame, not a broken one, and at 0.708 scale it is ~2px of detail that antialiasing may smudge. §5.4 must check: the inner curl on the flame's left side reads as a NOTCH, not a blob or a nick.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` does not include them. Their first run will likely surface pre-existing failures unrelated to Cluster C; triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **C7 lands on the most test-covered file in the repo.** The 106-case playback suite must run unmodified and green before AND after; a diff in it is a blocker, never a test to update.
- **The slice's §3 "Current app" column is unreliable — verify base state at the call site before trusting a delta.** Its base-state audit checked that tokens exist at value, never what the code USES. Confirmed wrong at slice lines `:272` (greeting already at target), `:273` (`displaySerif` is 32 w500 h1.0), and `:276` (four of seven `StickerButton(secondary)` values). `:274`/`:275` are accurate. Prototype citations, by contrast, were accurate everywhere checked this session — the §7 discipline is clearing; this is a different defect class.
- **`Shadows.card = hero` and `Shadows.button = control`** (`shadows.dart:132`, `:134`) are direct aliases. That is why `StickerCard`'s DEFAULT shadow already matches the prototype exactly for C1/C2/C5 — true for a reason no reader would guess from the token name.
- **C6's blast radius was closed, not merely reasoned about**: all eight other `EmptyStatePlaceholder` call sites green by actual test run, and `empty_state_test.dart` has FOUR cases (the slice says three; the omitted one is the `DashedBorderPainter` `shouldRepaint` unit test).
- **C4's restyled Edit/Delete are only observable in Day Detail** (`day_detail_entry_tile.dart:36-37` is the sole caller passing the callbacks). Do not wire them into Today to see them — that pre-empts OQ-3.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`; the in-repo path does not exist and fails `MODULE_NOT_FOUND`.
- **The checkpoint-push classifier block still stands** (`mitosis.js:4586`) and will recur on any future mitosis run, for any cluster. It is why Cluster C does not use mitosis.
- **Serena has no Dart backend on this repo** — it reported no language backend and every agent this session was told to use native grep/Read instead, successfully. Do not require Serena semantic discovery here.
- **`feat/cluster-c-today-centre` and `chore/ledger-handoff-session-16` are superseded** and still on origin; three stale stashes remain. Both need explicit confirmation to remove.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b` checkouts and their `msp-cluster-*` branches are KEPT by standing directive (decisions/2026-07-20-keep-stale-worktrees.md). Do not propose removing them.
- **`.mitosis/run.json` is JSONL**, one record per line, 15 lines. Do not "fix" it to pretty-print.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- Do NOT edit a spec mid-run — `specContentHash` binds the resume record.
- OQ-3 and OQ-6 unanswered. **OQ-3 touches C4 and must not be resolved implicitly** — C4 ships the interim placement or stops and reports.

## Key Decisions
- decisions/2026-07-28-retargeting-an-existing-test-is-not-fence-widening.md — an MSP may retarget existing assertions pinning a rendering it is mandated to change, without that test file being in its fence; N24's playback files stay carved out
- decisions/2026-07-28-cluster-c-skips-mitosis.md — Cluster C runs as direct `implementer` waves, not mitosis; the engine's ship stage parks any unit with an unmerged parent
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — MSPs stacked on a shared file ship one at a time: rebase `--onto main` after each merge, revalidate on the new base, never open parallel stacked PRs
- decisions/2026-07-28-recover-stranded-checkpoints-over-redispatch.md — recover finished work from `refs/mitosis/*` and hand-ship it; never re-dispatch mitosis to re-implement what already exists
- decisions/2026-07-28-parked-ship-resumes-by-re-execution.md — a park at `ship` resumes by full re-execution, not checkpoint restore; never wipe run.json to force a clean run
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice, not inferred by the engine
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec and landing it on base
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; one cluster at a time
- decisions/2026-07-27-prototype-alignment-open-questions.md — adopt the prototype's form, never its promises; OQ-2 and OQ-7 bind Cluster C
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-22-black-window-standalone-binary.md — always run via `flutter run -d macos`, never the raw binary

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the token layer — which CLOSED with Cluster A.
- Within Cluster C specifically: no edit to `sticker_card.dart`, `media_placeholders.dart` or `lib/app/shell/**` beyond C1's one-line margin carve-out; no second hatch painter; no unifying the two dashed-border painters.

## Pointers
- docs/specs/2026-07-28-prototype-alignment-cluster-c.md — **the live slice.** §0 carries the verified token table, the hard scope fence over 16 files, seven binding primitive resolutions and the wave graph; §5.3 the regression gate; §7 the citation-trust note
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority. MSP map: C1-C7 Today centre, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens. **Its §3.3 video-tile citation `:127-129` is WRONG**; the slice corrects it to `:128-130`
- docs/specs/2026-07-27-prototype-alignment-cluster-b.md — FULLY EXECUTED; the shape the Cluster C slice mirrors
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — `fullValidationCmd` is the local gate. Baseline at `3842948`: 902 passed, 0 failed, analyze clean
- Durable checkpoints under `refs/mitosis/` — A `02c68b83`, B `55d6da7a`, original run `5385f00d`, video `da41a247`. **Checked 2026-07-28: none holds any C-series artifact.** Keep the refs as the precedent for checking before any dispatch

## Recent Sessions
- sessions/2026-07-28-04-prototype-design-alignment.md
- sessions/2026-07-28-03-prototype-design-alignment.md
- sessions/2026-07-28-02-prototype-design-alignment.md
- sessions/2026-07-28-01-prototype-design-alignment.md
