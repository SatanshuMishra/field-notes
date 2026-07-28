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
next_step: Dispatch mitosis on docs/specs/2026-07-27-prototype-alignment-cluster-b.md with baseBranch main, sourcePrefix msp-cluster-b, and a run-distinct worktreeRoot. Nothing is needed before it — the slice is on main and local main is reconciled to b4c5634.
branch: main
---

## Status
**CLUSTER A SHIPPED AND ACCEPTED; THE CLUSTER B SLICE IS ON MAIN, UNDISPATCHED.** A1-A5 merged (#51/#53/#54/#55/#56 = `81039f3`), `fullValidationCmd` green against the combined tree (analyze clean, 899/899, exit 0), user hardware-confirmed. PR #58 (pr-title-lint `edited` trigger) and #60 (the Cluster B slice) both merged; main is `b4c5634` and local main matches. 5 of the parent spec's 39 MSPs are shipped; 4 more are cut and ready to dispatch.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Dispatch mitosis on the Cluster B slice. Inputs: `spec` = `docs/specs/2026-07-27-prototype-alignment-cluster-b.md`, `baseBranch` = `main`, `sourcePrefix` = `msp-cluster-b` (bare token, run-distinct), `worktreeRoot` = REQUIRED and run-distinct, `verify`/`build` from `receipts.config.json`.

## Open Risks
- **All four B MSPs edit `lib/app/shell/sidebar_shell.dart`.** The chain `B1 -> B2 -> {B3, B4}` is a file-contention chain, not just a dependency chain; the slice declares it, but the engine may still fan B3/B4 from the same base. Watch the second of the two at integration.
- **The `mitosis: <slug>` title source is UNLOCATED.** Not in `~/.claude/skills/mitosis/SKILL.md`, `prompt-snapshots/`, or any `lib/superpowers-parallel/*.mjs`. Cluster B will park at `pr-title-lint` as Cluster A did; with #58 merged a retitle now clears it.
- **`.github/workflows/receipts.yml` has UNPINNED actions** — `actions/checkout@v4`, `setup-node@v4`, and third-party `shaheershoaib/receipts/enforcer@main`, which executes whatever that branch holds on every PR with the workflow token. #58 widened the trigger to `edited`, increasing exposure. Chip `task_e10f4f7e`.
- **A2 and A4's app-wide blast radius was never walked.** Calendar, Garden, Search, Day Detail and Settings were not individually checked after the `bodySerif` 16 -> 13.5 / `displaySerif` w500 / `captionSans` w400 changes and the 20-site secondary-button shadow strip. No Cluster B MSP revisits them; Cluster B's §5.4 five-screen desktop pass is the natural place to catch it.
- **The five A3 dialogs were not separately opened.** That criterion rests on the merged diff and the green suite.
- **The slice's inherited citations are unverified.** Only the three it ADDS were opened. §7 is carried verbatim for exactly this reason — re-open every cited line rather than trusting the document.
- **The A1 plan fix survives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** Not committable; does not survive a fresh clone. It is the reference shape for every later plan's scope guard, now also written into the B slice as §5.5.
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter; the parent yields all 39 MSPs.
- Do NOT edit a spec mid-run — `specContentHash` binds the resume record and editing orphans `.mitosis/run.json` into a full re-decompose.
- **Fetch before reporting divergence.** A stale local `origin/*` ref produced a false "stranded commits" report two sessions running.
- **CI is not evidence.** Neither GitHub check runs a Dart test. Run `fullValidationCmd` locally against the PR head before every merge.
- With H1 undispatched there is no golden coverage; the 106-case playback suite is the only automated pixel-adjacent net.
- OQ-3 and OQ-6 unanswered. Neither touches Cluster B. OQ-1 binds B4 and IS resolved.

## Key Decisions
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice, not inferred by the engine
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match
- decisions/2026-07-27-pr-title-lint-fix-belongs-at-the-title.md — the lint is right and the title is wrong; loosening the alternation REJECTED; #58 landed the `edited` trigger
- decisions/2026-07-27-ship-stage-ci-wait-portability.md — darwin has no `timeout`; CI waits use bounded `until` loops and MUST check the exit code
- decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json`, not the harness cache; `worktreeRoot` is required
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA, never `merge-base`; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND run-distinct; Cluster A used `msp-cluster-a`
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; one cluster at a time
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer — which CLOSED with Cluster A.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning. MSP map: B1-B4 nav rail and window chrome, C1-C7 Today, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens
- docs/specs/2026-07-27-prototype-alignment-cluster-b.md — THE NEXT RUN'S `spec` INPUT. Carries B1-B4, a hard scope fence (7 touchable files), the SERIALIZATION section, the base-state token table, and §5.5's plan scope-guard rule
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A slice, fully executed; the reference shape for later slices
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim; `fullValidationCmd` is the local gate
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard
- /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a/validate-81039f3 — the Cluster A validation worktree, kept per decisions/2026-07-20-keep-stale-worktrees.md

## Recent Sessions
- sessions/2026-07-27-08-prototype-design-alignment.md
- sessions/2026-07-27-07-prototype-design-alignment.md
