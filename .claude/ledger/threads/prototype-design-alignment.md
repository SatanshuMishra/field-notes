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
next_step: Dispatch mitosis on docs/specs/2026-07-26-prototype-design-alignment.md scoped to Cluster A (A1-A5), baseBranch main, sourcePrefix `msp` (NO trailing slash).
branch: chore/ledger-handoff-session-08
---

## Status
Spec approved and now ON MAIN (PR #48, `9fb3e7f`), together with the `docs/prototype/` citation bundle. The dispatch precondition is cleared. Nothing in `lib/` has changed; execution has not started.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Dispatch mitosis against `docs/specs/2026-07-26-prototype-design-alignment.md`, scoped to Cluster A (A1-A5). Inputs: `baseBranch` main, `sourcePrefix` `msp` with NO trailing slash, `verify`/`build` from `receipts.config.json`, `fixLoopMax` 2. A3 is dependency-free and can land in parallel with A1/A2.

## Open Risks
- `sourcePrefix` must be `msp`, never `msp/` — the engine appends the slash itself and the trailing-slash form failed run 1 with the invalid ref `msp//...`.
- The spec has been wrong about citation line numbers once (two regions systematically off by one, three simply wrong; see its section 7). Implementers must re-open every cited line rather than trust the document.
- C7, G7 and G8 land on the most test-covered code in the repo (106 cases, eight files). The suite is the receipt that preserve items N1-N10 survived — a diff there is a blocker, not a test to update.
- D3 removes the desktop `Capture` button and takes three test files with it. Shipping D3 without those edits is an MSP-shippability failure.
- Every mitosis PR fails this repo's `pr-title-lint` (the engine hardcodes `mitosis: <msp-id>`); expect to retitle each one before merge. Merges are human-gated by hook.
- OQ-3 and OQ-6 are unanswered and block any entry-card action-placement or photo-attachment work. Neither touches Cluster A.

## Key Decisions
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; Cluster A only; sourcePrefix `msp` with no trailing slash
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the spec; section 2.7 binds preserve items to MSPs, section 7 is the citation-trust warning
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- docs/design/prototype-analysis.md — the original high-altitude extraction; orientation only, the source wins on conflict
- receipts.config.json — the verify/build commands mitosis consumes verbatim

## Recent Sessions
- sessions/2026-07-27-02-prototype-design-alignment.md
- sessions/2026-07-27-01-prototype-design-alignment.md
