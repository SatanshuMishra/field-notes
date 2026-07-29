---
thread: prototype-design-alignment
status: active
updated: 2026-07-28
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Wave 1 (C1, C2, C4, C6) DISPATCHED as four parallel `implementer` agents on 2026-07-28, one worktree each under `.fireplace-worktrees-cluster-c/`, branches `msp-cluster-c/{c1-streak-card,c2-header-mood-set,c4-eyebrow-card-header,c6-feed-empty-state}` all cut from main `93c6865`. Collect their reports, then per MSP: `fullValidationCmd` locally against the head, one PR via `~/.claude/lib/superpowers-parallel/mitosis-git.mjs pr-create`, human merge, then rebase the next `--onto main` and revalidate. Then Wave 2 (C3 after C2, C5 after C4), then Wave 3 (C7).
branch: msp-cluster-c/* (wave 1 worktrees); ledger on chore/ledger-handoff-session-17
---

## Status
**CLUSTER B IS FULLY CLOSED** — B1-B4 merged (#62-#65) and the §5.4 macOS visual pass passed on 2026-07-28, which was its last gate. **The Cluster C slice is cut and merged** (#71, `93c6865`). 10 of the parent spec's 39 MSPs are shipped (A1-A5, B1-B4, plus the slice itself is infrastructure, not an MSP). `main` is `93c6865`. **Cluster C execution STARTED 2026-07-28**: Wave 1 (C1, C2, C4, C6) dispatched as four parallel `implementer` agents, worktrees under `.fireplace-worktrees-cluster-c/`, branches off `93c6865`. No Cluster C code has merged yet.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Collect the four Wave 1 agent reports; then ship one MSP at a time — `fullValidationCmd` against the head, PR, human merge, rebase the next `--onto main`, revalidate. Waves are declared in the slice's §0 SERIALIZATION: only `mood_banner.dart` (C2+C3) and `entry_card.dart` (C4+C5) are shared files, plus a C5->C7 contract edge on `MediaImage`. Wave 2 is C3 and C5; Wave 3 is C7.

## Open Risks
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` does not include them. Their first run will likely surface pre-existing failures unrelated to Cluster C; triage before blaming an MSP.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Every merge is gated on a local `fullValidationCmd` run against the PR head.
- **C7 lands on the most test-covered file in the repo.** The 106-case playback suite must run unmodified and green before AND after; a diff in it is a blocker, never a test to update.
- **C6 can silently restyle four screens it does not own.** `EmptyStatePlaceholder`'s `padding`/`borderColor` are existing defaults shared by nine call sites; the slice binds C6 to the Today call site only. Calendar, Garden, Search and Day Detail empty states must be checked after it.
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
- sessions/2026-07-28-03-prototype-design-alignment.md
- sessions/2026-07-28-02-prototype-design-alignment.md
- sessions/2026-07-28-01-prototype-design-alignment.md
