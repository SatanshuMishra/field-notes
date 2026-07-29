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
next_step: Read the outcome of mitosis run 3 `wf_8567a217-c50` (in flight at hand-off) via /workflows or by folding .mitosis/run.json. Nothing else should start before that result is known.
branch: main
---

## Status
**CLUSTER B IS ONE-QUARTER SHIPPED AFTER THREE DISPATCHES.** B1 merged as #62; `main` is `9a53222`. B2, B3 and B4 are all unshipped. Run 1 parked B2 at `ship` (no `builtSha`, root-caused to a classifier-blocked checkpoint-push agent); run 2 re-executed B2 and halted at `execute` on an unactivated Serena; run 3 `wf_8567a217-c50` was dispatched after activating Serena and is IN FLIGHT. 6 of the parent spec's 39 MSPs are shipped. Three runs have cost ~7.4M subagent tokens for one MSP.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Read run 3's outcome first — it is the only thing that can have changed since hand-off. If it shipped B2-B4, validate each PR head locally with `fullValidationCmd` before merging. If it blocked on Serena again, stop requiring Serena semantic discovery on this Dart repo rather than re-activating. If it parked elsewhere, cut a fresh B2-B4 slice rather than re-dispatching the same manifest a fourth time.

## Open Risks
- **B2's approved work is unshipped and unvalidated.** The user approved shipping tip `97d91a8` as-is; the engine has no approve input, so the approval never took effect. `97d91a8` is `+21/-5` in `sidebar_shell.dart`, inside the fence, and no Dart has ever run against it.
- **The checkpoint-push classifier block recurs on every cluster C-H** until `mitosis.js:4586` stops authorizing an unconfirmed `--force-with-lease`. It nulls `builtSha` run-wide.
- **Serena activation is a partial, unverified fix** — it reported no language backend for Dart. See decisions/2026-07-28-mitosis-requires-serena-activation.md.
- **B4 has no durable checkpoint ref** (its push was the blocked one); its relaunch behavior is unpredictable.
- Run 2 ran `git reset --hard origin/main` on the b2 integration worktree without a clean-status check. Checked: no durable loss, all three checkpoint refs intact. Watch for it again.
- **`sourcePrefix` and the manifest were deliberately not rotated for run 3** — wiping the manifest would re-execute merged B1 into a duplicate PR. Only `worktreeRoot` rotated.
- **`.mitosis/run.json` is JSONL**, one record per line; the pretty-print warning in decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md does not describe it. Do not "fix" it.
- A2 and A4's app-wide blast radius was never walked (Calendar, Garden, Search, Day Detail, Settings). Cluster B's §5.4 five-screen desktop pass is the natural place to catch it.
- The five A3 dialogs were never separately opened. The slice's ~40 inherited citations are unverified beyond three spot-checks — §7 says re-open rather than trust.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- **CI is not evidence.** Neither GitHub check runs a Dart test; #62 merged without `fullValidationCmd` ever running against it.
- Do NOT edit a spec mid-run — `specContentHash` binds the resume record. Fetch before reporting divergence. With H1 undispatched there is no golden coverage.
- `pr-title-lint` passed clean on #62; the long-standing prediction that Cluster B would park red on it did not materialise.
- OQ-3 and OQ-6 unanswered; neither touches Cluster B. OQ-1 binds B4 and IS resolved.

## Key Decisions
- decisions/2026-07-28-parked-ship-resumes-by-re-execution.md — a park at `ship` resumes by full re-execution, not checkpoint restore; the engine has no approve input; never wipe run.json to force a clean run
- decisions/2026-07-28-mitosis-requires-serena-activation.md — activate Serena before any mitosis dispatch; the fix is partial and Dart may be unsupported
- decisions/2026-07-27-shared-file-cluster-serializes.md — a shared file across a cluster's MSPs is a hard dependency edge, declared in the slice, not inferred by the engine
- decisions/2026-07-27-primitives-cluster-confirms-by-regression.md — a primitives-only cluster is confirmed by REGRESSION, never by prototype match
- decisions/2026-07-27-pr-title-lint-fix-belongs-at-the-title.md — the lint is right and the title is wrong; #58 landed the `edited` trigger
- decisions/2026-07-27-ship-stage-ci-wait-portability.md — darwin has no `timeout`; CI waits use bounded `until` loops and MUST check the exit code
- decisions/2026-07-27-mitosis-resume-contract.md — the engine resumes from `.mitosis/run.json`; `worktreeRoot` is required
- decisions/2026-07-27-scope-guard-authorship-oracle.md — anchor a plan's scope guard to a captured SHA; never prescribe an autonomous `git checkout -- <path>`
- decisions/2026-07-27-source-prefix-is-run-distinct.md — the prefix is a bare token AND normally run-distinct; deliberately held constant for run 3
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
- docs/specs/2026-07-27-prototype-alignment-cluster-b.md — the IN-FLIGHT run's `spec` input. Carries B1-B4, a 7-file scope fence, the SERIALIZATION section, the base-state token table, and §5.5's plan scope-guard rule
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A slice, fully executed; the reference shape for later slices
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim; `fullValidationCmd` is the local gate
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard
- Durable checkpoints on origin under `refs/mitosis/55d6da7a/` — b1 `749ed67`, b2 `97d91a8` (B2's approved artifact), b3 `54fd9ef`; b4 has none

## Recent Sessions
- sessions/2026-07-28-01-prototype-design-alignment.md
- sessions/2026-07-27-08-prototype-design-alignment.md
