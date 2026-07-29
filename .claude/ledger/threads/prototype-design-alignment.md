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
next_step: Run the §5.4 macOS visual pass — Today, Calendar, Garden, Search, Settings on desktop plus the phone shell — via `flutter run -d macos`, never the standalone binary. It is the gate before Cluster C and the only check Cluster B has left; there is no golden coverage until H1 and the app cannot be agent-driven here. Then dispatch Cluster C, checking `refs/mitosis/*` for stranded artifacts first.
branch: main
---

## Status
**CLUSTER B IS COMPLETE.** B1-B4 merged as #62/#63/#64/#65; ledger closeout #66/#68 and the codegen chip #67 also merged; `main` is `f804e97` with zero open PRs and no stray branches. 9 of the parent spec's 39 MSPs are shipped (A1-A5, B1-B4). The fourth mitosis dispatch was never needed: `refs/mitosis/55d6da7a/b3-nav-states-icons` at `54fd9ef` already held B2 AND B3 complete and rebased onto post-B1 main, so both were recovered, validated locally and hand-shipped. Only B4 lacked an artifact; it took one `implementer` dispatch. Cluster B's remaining gate is the §5.4 human macOS visual pass, which has not been run.

## Active Goal
Align the shipped Flutter app with the Claude Design prototype's aesthetic without regressing any app-only capability, above all the video playback stack.

## Next Step
Run the §5.4 macOS visual pass. It is Cluster B's only remaining gate and cannot be delegated — the app is not agent-drivable here (a backgrounded `flutter run` loses stdin and dies; the VM-service screenshot path is unavailable). Use `flutter run -d macos`, never the standalone binary, which renders a black window. Then Cluster C.

## Open Risks
- **The §5.4 macOS visual pass is UNRUN and is the gate before Cluster C.** Cluster B is the chrome framing every screen and there is no automated pixel net until H1. Check the panel wash and corner glow, the 42px title bar with centred caption, the 216px rail, the peony and two-line wordmark, the active/inactive treatment on each of the four destinations in turn, and the footer strip with Settings open (gear terracotta) and sound toggled both ways. The streak card is expected to look unfinished — it is C1's, not a Cluster B defect.
- **A live phone bug, found in passing and NOT fixed:** `lib/features/settings/sections/sync_storage_section.dart:115` overflows 219px at 440px width. Proven pre-existing at `54fd9ef`. `app_shell_test.dart` only passed because `appSettingsProvider` resolved late and `SettingsScreen` rendered its loading placeholder — any earlier subscription exposes it. Chip `task_31a15276`.
- **The four `integration_test/` flows (§5.3 gate 3) have never been run** — `fullValidationCmd` does not include them.
- **CI is not evidence.** Neither GitHub check runs a Dart test. All four Cluster B MSPs were gated on local `fullValidationCmd` runs only.
- **The checkpoint-push classifier block will recur on any future mitosis run** until `mitosis.js:4586` stops authorizing an unconfirmed `--force-with-lease`. It nulls `builtSha` run-wide. It is why B2-B4 stranded.
- **Serena activation is a partial, unverified fix** — it reported no language backend for Dart, and no run has since reached semantic discovery. See decisions/2026-07-28-mitosis-requires-serena-activation.md.
- Session scratch cleaned up 2026-07-28: the six `feat/*` Cluster B branches and the two session worktrees are gone, local and remote. **The `.fireplace-worktrees-cluster-a/b` checkouts and their `msp-cluster-*` branches were deliberately KEPT** — decisions/2026-07-20-keep-stale-worktrees.md is a standing user directive to retain them for manual testing, reconfirmed when cleanup scope was put to the user. Do not propose removing them.
- A stale `stash@{0}` ("WIP on feat/b4-rail-footer-state") holds only codegen churn that #67 superseded. Droppable; left because stash drops need confirmation.
- **`.mitosis/run.json` is JSONL**, one record per line, now 15 lines; the pretty-print warning in decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md does not describe it. Do not "fix" it.
- A2 and A4's app-wide blast radius was never walked (Calendar, Garden, Search, Day Detail, Settings). The §5.4 pass is the natural place to catch it.
- The five A3 dialogs were never separately opened. The slice's ~40 inherited citations are unverified beyond spot-checks — §7 says re-open rather than trust. B4's implementer re-verified its four cited lines and found no drift.
- **`receipts.yml` has UNPINNED actions** including third-party `shaheershoaib/receipts/enforcer@main` running with the workflow token. Chip `task_e10f4f7e`.
- Do NOT edit a spec mid-run — `specContentHash` binds the resume record.
- OQ-3 and OQ-6 unanswered; neither touched Cluster B. OQ-1 bound B4 and IS resolved — truthful sync copy shipped.

## Key Decisions
- decisions/2026-07-28-stacked-msps-ship-sequentially.md — MSPs stacked on a shared file ship one at a time: rebase `--onto main` after each merge, revalidate on the new base, never open parallel stacked PRs
- decisions/2026-07-28-recover-stranded-checkpoints-over-redispatch.md — recover finished work from `refs/mitosis/*` and hand-ship it; never re-dispatch mitosis to re-implement what already exists. A single remaining MSP is not mitosis-shaped
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
- docs/specs/2026-07-27-prototype-alignment-cluster-b.md — FULLY EXECUTED (B1-B4 merged). Its shape is the reference for the Cluster C slice: a 7-file scope fence, the SERIALIZATION section, a base-state token table, and §5.5's plan scope-guard rule
- docs/specs/2026-07-27-prototype-alignment-cluster-a.md — the Cluster A slice, fully executed; the reference shape for later slices
- docs/prototype/project/Field Notes.dc.html — the authoritative design source every value cites
- receipts.config.json — the verify/build commands mitosis consumes verbatim; `fullValidationCmd` is the local gate
- .mitosis/a1-token-ladder.plan.md — the fixed A1 plan; gitignored and local-only, the reference shape for every later plan's scope guard
- Durable checkpoints on origin under `refs/mitosis/55d6da7a/` — b1 `749ed67`, b2 `97d91a8`, b3 `54fd9ef` (held B2+B3 finished; the source of the recovery). All now shipped and superseded by main, but KEEP the refs: they are the precedent for checking `refs/mitosis/*` before any future dispatch

## Recent Sessions
- sessions/2026-07-28-02-prototype-design-alignment.md
- sessions/2026-07-28-01-prototype-design-alignment.md
- sessions/2026-07-27-08-prototype-design-alignment.md
