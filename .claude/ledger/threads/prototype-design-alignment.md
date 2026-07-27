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
next_step: Run `fullValidationCmd` (receipts.config.json) against main at `81039f3` from a worktree pinned to that SHA — five MSPs are merged with zero local validation. Then hardware-confirm the dialogs and the token/typography/sticker surfaces on macOS.
branch: chore/ledger-handoff-session-11
---

## Status
**CLUSTER A IS COMPLETE — all five MSPs merged.** A3 = PR #51 (`55d8ffc`), A1 = PR #53 (`22ba7fe`), A4 = PR #54 (`74477e7`), A5 = PR #55 (`d58602d`), A2 = PR #56 (`81039f3`, current main tip). Run `wf_0f8cd32e-818` returned `partial` in 101 minutes (64 agents, 0 errors, 4.39M subagent tokens), but every park was `pr-title-lint` only — `receipts` and D6 were green on all three new MSPs, and each PR landed exactly its declared `fileScope`. 5 of the parent spec's 39 MSPs are now shipped.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Run `fullValidationCmd` against main at `81039f3` from a worktree pinned to that SHA (the repo root carries a ledger branch). Then hardware-confirm on macOS. Only after that, decide the `pr-title-lint` durable fix and cut the Cluster B execution slice.

## Open Risks
- **ALL FIVE Cluster A MSPs are UNVALIDATED locally.** A green `receipts` check is not evidence a Dart test ran (decisions/2026-07-20-ci-gates-are-hollow-for-dart.md). Nothing has run the Dart suite against `81039f3`.
- **A1/A2/A4/A5 were never tested against each other's merged state.** Every PR's CI computed against base `22ba7fe`; A4 and A5 merged 39 seconds apart, A2 four minutes later. File scopes do not overlap, but no run saw the combined tree.
- **A2 and A4 have app-wide blast radius and are now ON MAIN.** A2 moved `bodySerif` 16 -> 13.5 (9 consumers), `displaySerif` to w500/1.0 and `captionSans` to w400 (33 consumers); A4 stripped the shadow from 20 secondary `StickerButton` sites. Calendar, Garden, Search, Day Detail and Settings need a human pass — no later MSP revisits them.
- **`pr-title-lint` needs a durable fix.** The lint predates the first mitosis merge (`7e47cd3` is an ancestor of `55d8ffc`), so it has failed EVERY mitosis PR and main now carries five non-conventional squash messages. Fix the workflow's type alternation (.github/workflows/receipts.yml:26-30) or the engine's title template before the next cluster, or all of Cluster B parks identically.
- **The A1 plan fix survives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** Not committed, not committable; `.mitosis/` does not survive a fresh clone or new worktree. It is the reference shape for every later plan's scope guard.
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter; the parent yields all 39 MSPs. `worktreeRoot` is a REQUIRED dispatch input.
- Do NOT edit a spec mid-run to inject guidance — `specContentHash` binds the resume record and editing orphans `.mitosis/run.json` into a full re-decompose.
- With H1 undispatched there is no golden coverage, so the 106 playback tests remain the only automated pixel-adjacent net.
- The spec has been wrong about citation line numbers once (§7). Re-open every cited line rather than trusting the document.
- OQ-3 and OQ-6 are unanswered. Neither touches Cluster A.

## Key Decisions
- decisions/2026-07-27-ship-stage-ci-wait-portability.md — darwin has no `timeout`; CI waits use bounded `until` loops and MUST check the exit code, or a 127 reads as a completed wait
- decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json`, not the harness cache; fold it before dispatching; `worktreeRoot` is required
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA, never `merge-base`; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND run-distinct; `msp-cluster-a` for this run
- decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md — observed on #51, #53, #54, #55 and #56; retitling is squash-message hygiene, not a gate
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; one cluster at a time
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning. Clusters B-H each need their own slice cut from it
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A slice, now fully executed; the reference shape for later slices
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim; `fullValidationCmd` is the local gate
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard

## Recent Sessions
- sessions/2026-07-27-06-prototype-design-alignment.md
- sessions/2026-07-27-05-prototype-design-alignment.md
