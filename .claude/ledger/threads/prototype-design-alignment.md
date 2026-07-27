---
thread: prototype-design-alignment
status: paused
updated: 2026-07-27
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Re-dispatch mitosis for A2/A4/A5 with spec `docs/specs/2026-07-27-prototype-alignment-cluster-a.md`, baseBranch main, sourcePrefix `msp-cluster-a`, worktreeRoot `/Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a`, and verify from receipts.config.json. Fold `.mitosis/run.json` first to confirm the reconstructed stages.
branch: chore/ledger-handoff-session-10
---

## Status
**A1 and A3 are both SHIPPED AND MERGED.** A3 = PR #51 (`55d8ffc`); A1 = PR #53 (`22ba7fe`), carrying the three `lib/design/tokens/` files plus `test/design/tokens/tokens_test.dart`. Two of Cluster A's five MSPs are on main. A2, A4 and A5 parked as "blocked by a parked prerequisite" and were never planned — A1's merge now clears them. Run `wf_1543a2d6-49e` returned `partial` in 81 minutes.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Re-dispatch mitosis to run A2, A4 and A5. Fold `.mitosis/run.json` via `node ~/.claude/lib/superpowers-parallel/fold-run-log.mjs` BEFORE dispatching and let the reconstructed stages, not this note, decide the args. Confirm local `main` equals `origin/main` first — the engine cuts worktrees from the LOCAL ref. Expect each MSP to park at `ship` on `pr-title-lint`, which is not merge-blocking.

## Open Risks
- **A1 and A3 are UNVALIDATED locally.** A green `receipts` check is not evidence a Dart test ran (decisions/2026-07-20-ci-gates-are-hollow-for-dart.md). Run `fullValidationCmd` against main and hardware-confirm the five dialogs.
- **The A1 plan fix survives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** Not committed, not committable; `.mitosis/` does not survive a fresh clone or new worktree. Losing that file loses the fix.
- Every MSP parks at `ship` on `pr-title-lint` because the engine dictates a verbatim `mitosis: <id>` title. Merging is a human action; #51 and #53 both merged red, leaving two non-conventional squash messages permanently in main's history.
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter; the parent yields all 39 MSPs.
- `worktreeRoot` is a REQUIRED dispatch input. Omitting it fails input validation in 24ms.
- A2 and A4 have app-wide blast radius by design: A2 changes `bodySerif` 16 -> 13.5 (nine consumers), `displaySerif` to w500/1.0 and `captionSans` to w400 (33 consumers); A4 strips the shadow from all 20 secondary `StickerButton` call sites. Both require a human pass over Calendar, Garden, Search, Day Detail and Settings — screens no later MSP revisits.
- With H1 undispatched there is no golden coverage, so §5.3 gate 2 (the 106 playback tests, run unmodified) is the only automated pixel-adjacent net in this run.
- The spec has been wrong about citation line numbers once (§7). Implementers must re-open every cited line rather than trust the document.
- OQ-3 and OQ-6 are unanswered. Neither touches Cluster A, and the slice forbids resolving either implicitly.

## Key Decisions
- decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json`, not the harness cache; fold it before dispatching; `worktreeRoot` is required
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA, never `merge-base`; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND run-distinct; `msp-cluster-a` for this run
- decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md — observed on #51 and again on #53; retitling is squash-message hygiene, not a gate
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; Cluster A only
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer.

## Pointers
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A execution slice; THIS is the `spec` input
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard

## Recent Sessions
- sessions/2026-07-27-05-prototype-design-alignment.md
- sessions/2026-07-27-04-prototype-design-alignment.md
