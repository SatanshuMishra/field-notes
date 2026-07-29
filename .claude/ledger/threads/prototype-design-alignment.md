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
next_step: Ship C6, then C5 (`86ad8f4`, rebase first). C6 is the last unmerged Wave 1 MSP — `git -C .fireplace-worktrees-cluster-c/c6-feed-empty-state rebase main` (it is two merges behind), run `fullValidationCmd` verbatim against the new head, open ONE PR via `~/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create`, wait for the human merge. PREDICT the expected test count from the diff before running and check the result against it. Then dispatch C3 off the post-C2 main; C7 last, after C5. Put C5's two open rulings (unshipped caption behind OQ-6, tilt scatter) to the user before Wave 3. Never two MSP PRs open at once.
branch: main `8f711e9`; unmerged work on msp-cluster-c/{c6-feed-empty-state, c5-card-surface-body-strip}
---

## Status
Cluster B fully closed; the Cluster C slice merged (#71). **THREE CLUSTER C MSPs ARE NOW MERGED — C1 (#74), C4 (#75), C2 (#77) — putting 12 of the parent spec's 39 MSPs shipped** (A1-A5, B1-B4, C1, C4, C2). `main` is `8f711e9`, zero open PRs. Each was rebased `--onto main` and REVALIDATED on its new base before its PR opened; both squashes were confirmed to reproduce their validated tips exactly (`git diff main <tip> -- lib test` empty). **C6 `179e4b8` is the last unmerged Wave 1 MSP** — implemented and green, but on a base two merges stale. **C5 completed late in the session and pushed `86ad8f4`** (green, no retargets needed, `MediaImage` gained one null-defaulting `border` param as C7's contract edge) — unvalidated, no PR, and knowingly incomplete on its caption. **The real baseline is 903, not the 902 the slice records** (#70 added tests after that figure was measured); C2 correctly moved it to 904.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Ship C6 (rebase, revalidate, one PR, human merge). Then ship C5 (`86ad8f4`) the same way, then dispatch C3 off the post-C2 main; C7 last, after C5. The slice's §0 SERIALIZATION declares the lib-file edges but does NOT cover test files — C2 and C4 also shared `today_screen_test.dart`, so compute test overlap yourself before any parallel dispatch.

## Open Risks
- **A clean rebase is NOT proof of a coherent widget.** Git merges two rewrites of one region textually without complaint. C2 and C4 both rewrote the `today_screen.dart` column; the merged composition was read by hand before validating. Do this for every remaining rebase, above all C5 -> C7 on `video_body.dart`.
- **Predict the expected test count from the diff BEFORE running `fullValidationCmd`.** An unexplained number is not a green. Baseline on `main` is 904 after C2.
- **`pr-create` rejects non-ASCII and names neither the field nor the character.** Copy strings in this cluster use U+00B7 (middle dot) and U+2014 (em dash) — describe them in prose in PR fields, never quote them. C5's photo caption and C3's subtitle are the next tripwires.
- **C1's flame glyph is unverifiable by any automated check.** `flame_icon.dart` hand-transcribes a 24-viewBox SVG path; the test asserts only `find.byType(FlameIcon)`, never the rendered shape. Re-derivation confirmed the arc (perfect semicircle, `clockwise: true`, bulb bulges down — fails loudly, not subtly, if inverted) and nonZero fill. **Residual risk is the cusp at (9,8), the flame's inner notch** — a one-digit error there renders as a lumpy flame, not a broken one, and at 0.708 scale it is ~2px of detail that antialiasing may smudge. §5.4 must check: the inner curl on the flame's left side reads as a NOTCH, not a blob or a nick. **§5.4 must also rule on C5's card tilt** — `Entry.id` is a ULID string, not the prototype's integer, so id-parity tilt reads as pseudo-random scatter, not the strict L-R-L-R the spec describes; strict alternation would need a feed index outside C5's fence.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` does not include them. Their first run will likely surface pre-existing failures unrelated to Cluster C; triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **C7 lands on the most test-covered file in the repo.** The 106-case playback suite must run unmodified and green before AND after; a diff in it is a blocker, never a test to update.
- **The slice's §3 "Current app" column is unreliable — verify base state at the call site before trusting a delta.** Its base-state audit checked that tokens exist at value, never what the code USES. Confirmed wrong at slice lines `:272` (greeting already at target), `:273` (`displaySerif` is 32 w500 h1.0), and `:276` (four of seven `StickerButton(secondary)` values). `:274`/`:275` are accurate. Prototype citations, by contrast, were accurate everywhere checked this session — the §7 discipline is clearing; this is a different defect class.
- **`Shadows.card = hero` and `Shadows.button = control`** (`shadows.dart:132`, `:134`) are direct aliases. That is why `StickerCard`'s DEFAULT shadow already matches the prototype exactly for C1/C2/C5 — true for a reason no reader would guess from the token name.
- **C6's blast radius was closed, not merely reasoned about**: all eight other `EmptyStatePlaceholder` call sites green by actual test run, and `empty_state_test.dart` has FOUR cases (the slice says three; the omitted one is the `DashedBorderPainter` `shouldRepaint` unit test).
- **C4's restyled Edit/Delete are only observable in Day Detail** (`day_detail_entry_tile.dart:36-37` is the sole caller passing the callbacks). Do not wire them into Today to see them — that pre-empts OQ-3.
- **The `pr-create` tool is NOT at the repo-relative path the global rule states.** Use `~/.claude/lib/superpowers-parallel/mitosis-git.mjs`; the in-repo path does not exist and fails `MODULE_NOT_FOUND`.
- **Mitosis-engine hazards are parked, not gone** — the checkpoint-push classifier block (`mitosis.js:4586`), `.mitosis/run.json` being JSONL (never pretty-print it), and the rule against editing a spec mid-run (`specContentHash` binds resume). All recur the moment mitosis is used again; detail in decisions/2026-07-28-cluster-c-skips-mitosis.md and sessions/2026-07-28-01.
- **Serena has no Dart backend on this repo** — it reported no language backend and every agent this session was told to use native grep/Read instead, successfully. Do not require Serena semantic discovery here.
- **`feat/cluster-c-today-centre` and `chore/ledger-handoff-session-16` are superseded** and still on origin; three stale stashes remain. Both need explicit confirmation to remove.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- The `.fireplace-worktrees-cluster-a/b` checkouts and their `msp-cluster-*` branches are KEPT by standing directive (decisions/2026-07-20-keep-stale-worktrees.md). Do not propose removing them.
- A2 and A4's app-wide blast radius was never walked; the five A3 dialogs were never separately opened. §7 says re-open rather than trust inherited citations.
- OQ-3 and OQ-6 unanswered. OQ-3 shipped its interim placement in C4. **OQ-6 now BLOCKS a C5 target value**: the 6px monospace thumbnail caption is deliberately unshipped because the domain has no photo label (`entry_photo.dart:12-18`) and inventing one would resolve OQ-6 unilaterally — so C5 is knowingly incomplete against its own table, and `Type.monoThumbSans` is unconsumed. Put this to the user before Wave 3.

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
- sessions/2026-07-28-05-prototype-design-alignment.md — **read its Running state before touching C5**
- sessions/2026-07-28-04-prototype-design-alignment.md
- sessions/2026-07-28-03-prototype-design-alignment.md
- sessions/2026-07-28-02-prototype-design-alignment.md
- sessions/2026-07-28-01-prototype-design-alignment.md
