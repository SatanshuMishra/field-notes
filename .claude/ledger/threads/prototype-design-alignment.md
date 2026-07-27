---
thread: prototype-design-alignment
status: active
updated: 2026-07-27
priority: high
completion_criteria:
  - Every critical and high gap in the spec's section 3 is either shipped or explicitly re-deferred with a recorded reason
  - The 106-case playback suite is green after the video-touching MSPs (C7, G7, G8), proving preserve items N1-N10 survived
  - No dialog renders Flutter's yellow double-underline debug style (MSP A3)
  - The Today screen, right rail, nav rail, flower set, mood picker and capture surfaces are human-confirmed against the prototype on macOS hardware
  - OQ-3 and OQ-6 are answered or explicitly closed as out of scope
next_step: Mitosis DISPATCHED for Cluster A (spec = the SLICE, baseBranch main, sourcePrefix `msp-cluster-a`, worktreeRoot .fireplace-worktrees-cluster-a, fixLoopMax 2). Retitle every PR the engine opens (`mitosis: <msp-id>` fails pr-title-lint), then shepherd the human-gated merges.
branch: chore/ledger-handoff-session-08
---

## Status
Parent spec, the `docs/prototype/` citation bundle and the Cluster A execution slice are ALL on origin/main (PR #48 `9fb3e7f`; PR #50 squashed as `74d7706`). Local `main` is 2 commits behind origin/main. Nothing in `lib/` has changed; execution has not started.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Reconcile local `main` onto `origin/main` (currently 2 behind; the engine cuts worktrees from the bare LOCAL main ref — decisions/2026-07-16-pre-relaunch-main-reconciliation.md). Then dispatch mitosis: `spec` = the SLICE, `repoRoot` = the repo root, `baseBranch` main, `sourcePrefix` `msp` with NO trailing slash, `verify`/`build` from `receipts.config.json`, `fixLoopMax` 2. A3 is dependency-free and can land in parallel with A1/A2.

## Open Risks
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter and decomposes whatever document it is handed; the parent yields all 39 MSPs.
- `sourcePrefix` is `msp-cluster-a` — bare (never a trailing slash: `msp/` failed run 1) and run-distinct, because 241 refs already live under `msp/` and the engine reuses an existing branch instead of failing. See decisions/2026-07-27-source-prefix-is-run-distinct.md.
- The spec has been wrong about citation line numbers once (two regions systematically off by one, three simply wrong; see §7). Implementers must re-open every cited line rather than trust the document. Two of those corrections land in A1's own target tables.
- A2 and A4 have app-wide blast radius by design: A2 changes `bodySerif` 16 -> 13.5 (nine consumers), `displaySerif` to w500/1.0 and `captionSans` to w400 (33 consumers); A4 strips the shadow from all 20 secondary `StickerButton` call sites. Both require a human pass over Calendar, Garden, Search, Day Detail and Settings — screens no later MSP revisits.
- With H1 undispatched there is no golden coverage, so §5.3 gate 2 (the 106 playback tests, run unmodified) is the only automated pixel-adjacent net in this run.
- Every mitosis PR fails this repo's `pr-title-lint` (the engine hardcodes `mitosis: <msp-id>`); expect to retitle each one before merge. Merges are human-gated by hook.
- OQ-3 and OQ-6 are unanswered. Neither touches Cluster A, and the slice forbids resolving either implicitly.

## Key Decisions
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec; mitosis has no scope parameter
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; Cluster A only; sourcePrefix `msp` with no trailing slash
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer.

## Pointers
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A execution slice; THIS is the `spec` input for the next run
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim

## Recent Sessions
- sessions/2026-07-27-03-prototype-design-alignment.md
- sessions/2026-07-27-02-prototype-design-alignment.md
