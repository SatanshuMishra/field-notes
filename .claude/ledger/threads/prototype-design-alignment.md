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
next_step: Merge PR #58, then cut the Cluster B execution slice (B1-B4) from docs/specs/2026-07-26-prototype-design-alignment.md using the Cluster A slice as the reference shape, land it on main, and dispatch mitosis with a run-distinct sourcePrefix and the REQUIRED worktreeRoot.
branch: fix/pr-title-lint-retitle-trigger
---

## Status
**CLUSTER A IS COMPLETE, VALIDATED AND USER-ACCEPTED.** All five MSPs merged (A3 #51, A1 #53, A4 #54, A5 #55, A2 #56 = `81039f3`); main is now `488b48a` (PR #57, ledger markdown only). `fullValidationCmd` ran GREEN against a worktree pinned to `81039f3`: `flutter analyze` "No issues found", `flutter test` 899/899 passed, exit 0. The user hardware-confirmed the result. 5 of the parent spec's 39 MSPs are shipped.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Merge PR #58 (so Cluster B's parks are clearable), then cut the Cluster B slice (B1-B4) from the parent spec, land it on main, and dispatch mitosis.

## Open Risks
- **The `mitosis: <slug>` title source is UNLOCATED.** It is not in `~/.claude/skills/mitosis/SKILL.md`, `prompt-snapshots/`, or any `lib/superpowers-parallel/*.mjs` (only under `tests/`). Cluster B will park at `pr-title-lint` exactly as Cluster A did; with #58 merged a retitle can at least green it.
- **`.github/workflows/receipts.yml` has UNPINNED actions** — `actions/checkout@v4`, `setup-node@v4`, and `shaheershoaib/receipts/enforcer@main` against the skill template's three SHA pins. The `@main` third-party action executes whatever that branch holds, on every PR, with the workflow token. Chip `task_e10f4f7e`.
- **A2 and A4 have app-wide blast radius and are on main.** A2 moved `bodySerif` 16 -> 13.5 (9 consumers), `displaySerif` to w500/1.0 and `captionSans` to w400 (33 consumers); A4 stripped the shadow from 20 secondary `StickerButton` sites. The user's confirmation followed a Today-screen screenshot; Calendar, Garden, Search, Day Detail and Settings were not individually walked, and no later MSP revisits them.
- **The five A3 dialogs were not separately opened.** That completion criterion rests on the merged diff and the green suite, not on a visual check.
- **The A1 plan fix survives only in gitignored `.mitosis/a1-token-ladder.plan.md`.** Not committed, not committable; `.mitosis/` does not survive a fresh clone or new worktree. It is the reference shape for every later plan's scope guard.
- **Pass the SLICE as `spec`, never the parent.** Mitosis has no scope parameter; the parent yields all 39 MSPs. `worktreeRoot` is a REQUIRED dispatch input.
- Do NOT edit a spec mid-run to inject guidance — `specContentHash` binds the resume record and editing orphans `.mitosis/run.json` into a full re-decompose.
- **Fetch before reporting divergence.** A local `origin/*` ref is only as fresh as the last fetch; a stale one made merged PR #57 look stranded this session.
- With H1 undispatched there is no golden coverage, so the playback suite remains the only automated pixel-adjacent net.
- The spec has been wrong about citation line numbers once (§7). Re-open every cited line rather than trusting the document.
- OQ-3 and OQ-6 are unanswered. Neither touches Cluster A or B.

## Key Decisions
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match; Cluster A holds no screen-composition MSP
- decisions/2026-07-27-pr-title-lint-fix-belongs-at-the-title.md — the lint is right and the title is wrong; loosening the alternation REJECTED; PR #58 landed the `edited` trigger
- decisions/2026-07-27-ship-stage-ci-wait-portability.md — darwin has no `timeout`; CI waits use bounded `until` loops and MUST check the exit code, or a 127 reads as a completed wait
- decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json`, not the harness cache; fold it before dispatching; `worktreeRoot` is required
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA, never `merge-base`; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND run-distinct; `msp-cluster-a` was this run's
- decisions/2026-07-27-cluster-a-scoped-spec.md — scope a mitosis run by cutting an execution slice of the spec
- decisions/2026-07-27-prototype-alignment-run-contract.md — land the spec on base before dispatch; one cluster at a time
- decisions/2026-07-27-prototype-alignment-open-questions.md — five of seven open questions resolved; adopt the prototype's form, never its promises

## Out of Scope
- The markdown editor engine (its own spec; G2 ships the paper surface and a truthful placeholder only).
- Free-manipulation photo cards; the settings screen layout; Calendar, Garden, Search and Day Detail beyond what tokens and flowers reach transitively.
- The prototype's 130px video card height (rejected — it clips the control bar), its sync copy, and its markdown placeholder string.
- No `flutter_svg`/`vector_graphics` dependency, no `ThemeExtension` migration, no `FontVariation` calls, no renames or removals in the existing token layer.

## Pointers
- docs/specs/2026-07-26-prototype-design-alignment.md — the parent spec and standing authority; §2.7 binds preserve items to MSPs, §7 is the citation-trust warning. Clusters B-H each need their own slice cut from it. MSP map: B1-B4 nav rail and window chrome, C1-C7 Today, D1-D4 right rail, E1-E4 flower art, F1-F4 mood picker, G1-G8 composers, H1 goldens
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A slice, fully executed; the reference shape for later slices
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim; `fullValidationCmd` is the local gate
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard
- /Users/satanshumishra/Documents/DevLabs/.fireplace-worktrees-cluster-a/validate-81039f3 — the validation worktree, kept per decisions/2026-07-20-keep-stale-worktrees.md

## Recent Sessions
- sessions/2026-07-27-07-prototype-design-alignment.md
- sessions/2026-07-27-06-prototype-design-alignment.md
