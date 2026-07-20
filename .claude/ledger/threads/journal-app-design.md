---
thread: journal-app-design
status: paused
updated: 2026-07-20
priority: high
completion_criteria:
  - Design spec written to docs/superpowers/specs/ and user-approved
  - 4 starred reconciliation decisions resolved (E2EE/pairing UX, app name, v1 scope, dark mode)
  - Implementation plan produced via the writing-plans skill
next_step: Re-run the fold pre-flight and confirm main is 0/0, then launch the mitosis relaunch using the block in sessions/2026-07-11-03 lines 38-62 with mergePolicy "human-gated". reminders resumes at plan-review off the rewritten plan.
branch: main
---

## Status
PAUSED at 20/31 merged (origin/main 153e7eb + ledger commits), no open PRs. This session did NOT build code:
it reconciled main, proved a relaunch safe, recovered the lost plan-review findings, ruled on a scope grant,
and rewrote .mitosis/reminders.plan.md. The run is fully staged but deliberately NOT launched (context hit 80%
and the project's fresh-context discipline forbids starting a ~3h run there).

## Active Goal
Ship all 31 Field Notes v1 MSPs to origin/main by building downstream dependents in session-sized batches via
human-gated mitosis (agents publish green PRs; main thread merges under consent). Immediate: land reminders
to reach 21/31.

## Next Step
Launch the relaunch. Everything is verified; it is one Workflow call. Re-run the fold pre-flight first.

## Open Risks
- THE GUARD FIX IS UNCOMMITTED in /Users/satanshumishra/Documents/DevLabs/.windful-ocean. If that tree is
  reverted, every mitosis launch silently full-re-decomposes with NO log line.
- Exit code 0 is NOT evidence a Node CLI ran. Pre-flight the fold CLI's stdout before every launch.
- Do NOT hand-edit run.json's base line before a launch. It must stay valid single-line JSON or all 21 units
  full-re-decompose and the manifest is overwritten. Editing fileScope there is also INERT for a plan-review
  resume — the plan document on disk is the only surface that reaches the reviewer.
- No Android SDK on this machine, so `flutter build apk` cannot verify the new Task 2 desugaring change, and
  receipts CI never builds Android. File-content assertion is the only available receipt; do not add an
  Android build to receipts.config.json (it would break every gate for every MSP).
- pubspec.yaml conflicts are SYSTEMIC. reminders adds flutter_local_notifications + timezone onto a main that
  now carries just_audio + video_player; apply the union procedure at merge.
- Classifier blocks DELEGATED `gh pr create`/`gh pr merge`; the main thread creates and merges them.
- `result.shipped` is MISLEADING; truth = `gh pr list` + `git ls-remote`.
- 16 stale worktrees remain on disk (left by user choice). Harmless for a reminders-only run; cleanup is
  destructive and must happen between runs, never mid-run.
- batch-tooling MERGED set is stale at 18 (must be 20 before batch 3); verify_manifest.js misreports
  capture-core/entry-cards as "will BUILD". Trust the live engine, not that preview.
- 3 files still carry the symlink guard defect (task chip task_ecab775c), incl. a hook that FAILS OPEN.

## Key Decisions
- decisions/2026-07-20-reminders-android-desugaring-scope.md — reminders' fileScope expanded by one file
  (android/app/build.gradle.kts) so it ships the desugaring config in the same PR; CI cannot catch this
- decisions/2026-07-19-symlink-guard-defect.md — all 7 CLIs were silent no-ops; pre-flight the fold CLI
- decisions/2026-07-19-entry-cards-fix-and-batch-2.md — batch 2 scope; entry-cards fixed-and-included
- decisions/2026-07-19-pubspec-parallel-conflict.md — systemic pubspec conflict; serial union merges
- decisions/2026-07-16-manifest-fold-defect-and-batch-scoping.md — run.json one compact line
- decisions/2026-07-16-pre-relaunch-main-reconciliation.md — reconcile local main before EVERY relaunch
- decisions/2026-07-12-human-gated-merge-policy.md — human-gated + main-thread merge under consent
- decisions/2026-07-10-client-implementation-stack.md — Riverpod 3.x + drift; v1 schema conventions
- decisions/2026-07-10-reconciliation-resolutions.md — all 14 points; v1 = prototype minus sync

## Out of Scope
- iOS; server-side search/thumbnails; CRDTs/Postgres/MinIO/Cloudflare Tunnel; multi-user; pooled Memories
  gallery. All sync/server work is v2 (settings-screen ships an inert disabled sync shell).

## Pointers
- .claude/ledger/sessions/2026-07-11-03-journal-app-design.md — VERBATIM launch block at lines 38-62
  (change mergePolicy to "human-gated")
- .claude/ledger/plans/2026-07-19-next-round.md — Stages A-G done for batch 2; G3/H still apply
- docs/superpowers/specs/2026-07-10-field-notes-design.md — v1 spec (§0 = implementation status)
- .mitosis/run.json — batch-2 manifest (21 msps); reminders parked at plan-review; do NOT re-trim or hand-edit
- .mitosis/run.json.pristine-backup — durable untouched 31-MSP manifest (gitignored)
- .mitosis/reminders.plan.md — REWRITTEN this session (1372 lines, 7 tasks); ready for re-review
- .mitosis/batch-tooling/ — trim + verify scripts (MERGED set must be bumped 18 -> 20 next batch)
- GitHub: SatanshuMishra/field-notes (PRIVATE; renamed from fireplace; local dir still "fireplace")

## Recent Sessions
- sessions/2026-07-20-01-journal-app-design.md
- sessions/2026-07-19-03-journal-app-design.md
- sessions/2026-07-19-02-journal-app-design.md
- sessions/2026-07-19-01-journal-app-design.md
