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
next_step: Edit `.mitosis/a1-token-ladder.plan.md` Task 4 Step 4 per decisions/2026-07-27-scope-guard-authorship-oracle.md (three changes, one step), then re-dispatch mitosis for A1/A2/A4/A5 with sourcePrefix `msp-cluster-a`.
branch: chore/ledger-handoff-session-09
---

## Status
**A3 is SHIPPED and MERGED** — PR #51, `55d8ffc` on main; `lib/design/feedback/dialog_host.dart` plus its test are on main. First MSP of this spec to land. A1 is PARKED at plan-review (3 iterations, 1 HIGH unresolved); A2, A4 and A5 never planned — blocked by A1. Run `wf_e96d3f94-e03` returned `failed` with `shipped: []`.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Edit `.mitosis/a1-token-ladder.plan.md` Task 4 Step 4 per decisions/2026-07-27-scope-guard-authorship-oracle.md: capture a `git rev-parse HEAD` SHA before Task 1's first edit as the authorship anchor, restate the expected diff as A1's fileScope paths plus what the branch already carried, and gate `git checkout -- <path>` behind human confirmation. Then re-dispatch: `resumeFromRunId` `wf_e96d3f94-e03` replays A3 from cache; failing that, dispatch fresh with the same args. Confirm local `main` == `origin/main` first — the engine cuts worktrees from the LOCAL ref.

## Open Risks
- **A3 is UNVALIDATED locally.** The green `receipts` check on #51 is not evidence a Dart test ran (decisions/2026-07-20-ci-gates-are-hollow-for-dart.md). Run `fullValidationCmd` against main, and hardware-confirm the five dialogs.
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter; the parent yields all 39 MSPs.
- `sourcePrefix` is `msp-cluster-a` — bare (no trailing slash) and run-distinct, because 241 refs live under `msp/` and the engine reuses an existing branch instead of failing. decisions/2026-07-27-source-prefix-is-run-distinct.md.
- The spec has been wrong about citation line numbers once (§7). Implementers must re-open every cited line rather than trust the document. Two corrections land in A1's own target tables.
- A2 and A4 have app-wide blast radius by design: A2 changes `bodySerif` 16 -> 13.5 (nine consumers), `displaySerif` to w500/1.0 and `captionSans` to w400 (33 consumers); A4 strips the shadow from all 20 secondary `StickerButton` call sites. Both require a human pass over Calendar, Garden, Search, Day Detail and Settings — screens no later MSP revisits.
- With H1 undispatched there is no golden coverage, so §5.3 gate 2 (the 106 playback tests, run unmodified) is the only automated pixel-adjacent net in this run.
- The engine's ship stage assumed a `timeout` binary, absent on macOS. It self-recovered on #51; expect it again.
- OQ-3 and OQ-6 are unanswered. Neither touches Cluster A, and the slice forbids resolving either implicitly.

## Key Decisions
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA, never `merge-base`; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND run-distinct; `msp-cluster-a` for this run
- decisions/2026-07-27-pr-title-lint-is-not-merge-blocking.md — observed on #51; retitling is squash-message hygiene, not a gate
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; Cluster A only
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer.

## Pointers
- .mitosis/a1-token-ladder.plan.md — the parked plan; Task 4 Step 4 (lines 727-745) is what must change before re-dispatch
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A execution slice; THIS is the `spec` input
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim

## Recent Sessions
- sessions/2026-07-27-04-prototype-design-alignment.md
- sessions/2026-07-27-03-prototype-design-alignment.md
